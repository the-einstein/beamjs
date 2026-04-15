defmodule BeamjsCore.Process do
  @moduledoc """
  A GenServer that owns a QuickJS context and executes JS code.
  Each instance is a lightweight BEAM process with its own JS runtime.
  """
  use GenServer
  require Logger

  defstruct [
    :ctx_ref,
    :source,
    :filename,
    :base_dir,
    mailbox: :queue.new(),
    awaiting_receive: false,
    js_state: nil
  ]

  # --- Public API ---

  def start_link(opts) do
    name = case opts[:name] do
      nil -> []
      n when is_binary(n) -> [name: {:via, Registry, {BeamjsCore.ProcessRegistry, n}}]
      n -> [name: n]
    end

    GenServer.start_link(__MODULE__, opts, name)
  end

  def start_supervised(opts) do
    DynamicSupervisor.start_child(
      BeamjsCore.ProcessSupervisor,
      {__MODULE__, opts}
    )
  end

  @doc "Evaluate JS source in a temporary context and return the result."
  def eval_sync(source, opts \\ []) do
    {:ok, ctx_ref} = BeamjsNif.new_context([])
    filename = Keyword.get(opts, :filename, "<eval>")
    result = BeamjsNif.eval(ctx_ref, source, filename)
    BeamjsNif.destroy_context(ctx_ref)
    result
  end

  @doc "Evaluate JS source in an existing process's context."
  def eval(pid, source) do
    GenServer.call(pid, {:eval, source}, :infinity)
  end

  @doc "Send a message to a JS process."
  def send_message(pid, message) do
    Kernel.send(pid, {:js_message, message})
  end

  @doc "GenServer.call equivalent for JS processes."
  def call(pid, request, timeout \\ 5000) do
    GenServer.call(pid, {:js_call, request}, timeout)
  end

  @doc "GenServer.cast equivalent for JS processes."
  def cast(pid, request) do
    GenServer.cast(pid, {:js_cast, request})
  end

  # --- GenServer Callbacks ---

  @impl true
  def init(opts) do
    {:ok, ctx_ref} = BeamjsNif.new_context([])

    filename = Keyword.get(opts, :filename, "<spawn>")
    base_dir = case Keyword.get(opts, :base_dir) do
      nil ->
        if filename != "<spawn>" and filename != "<eval>" do
          Path.dirname(Path.expand(filename))
        else
          File.cwd!()
        end
      dir -> dir
    end

    state = %__MODULE__{
      ctx_ref: ctx_ref,
      source: Keyword.get(opts, :source),
      filename: filename,
      base_dir: base_dir
    }

    # If source provided, evaluate it
    if state.source do
      case BeamjsNif.eval(ctx_ref, state.source, filename) do
        {:ok, _} -> {:ok, state}
        {:error, reason} ->
          Logger.error("JS process init failed: #{inspect(reason)}")
          {:stop, {:js_error, reason}}
      end
    else
      {:ok, state}
    end
  end

  @impl true
  def handle_call({:eval, source}, _from, state) do
    result = BeamjsNif.eval(state.ctx_ref, source, "<eval>")
    {:reply, result, state}
  end

  def handle_call({:js_call, request}, from, state) do
    # Store the from reference so JS can reply
    BeamjsNif.set_global(state.ctx_ref, "__pending_call_from",
      :erlang.term_to_binary(from) |> Base.encode64())

    BeamjsNif.set_global(state.ctx_ref, "__pending_call_request", request)

    case BeamjsNif.eval(state.ctx_ref, """
      if (typeof __genserver_handle_call === 'function') {
        __genserver_handle_call(__pending_call_request, __pending_call_from, __genserver_state);
      } else {
        ({error: 'no_handler'});
      }
    """, "<internal:call>") do
      {:ok, %{"reply" => reply, "state" => new_state}} ->
        BeamjsNif.set_global(state.ctx_ref, "__genserver_state", new_state)
        {:reply, reply, %{state | js_state: new_state}}
      {:ok, %{"noreply" => true, "state" => new_state}} ->
        BeamjsNif.set_global(state.ctx_ref, "__genserver_state", new_state)
        {:noreply, %{state | js_state: new_state}}
      {:ok, %{"stop" => reason, "reply" => reply}} ->
        {:stop, reason, reply, state}
      {:ok, %{"error" => "no_handler"}} ->
        {:reply, {:error, :no_handler}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_cast({:js_cast, request}, state) do
    BeamjsNif.set_global(state.ctx_ref, "__pending_cast_request", request)

    case BeamjsNif.eval(state.ctx_ref, """
      if (typeof __genserver_handle_cast === 'function') {
        __genserver_handle_cast(__pending_cast_request, __genserver_state);
      } else {
        ({noreply: true, state: __genserver_state});
      }
    """, "<internal:cast>") do
      {:ok, %{"noreply" => true, "state" => new_state}} ->
        BeamjsNif.set_global(state.ctx_ref, "__genserver_state", new_state)
        {:noreply, %{state | js_state: new_state}}
      {:ok, %{"stop" => reason}} ->
        {:stop, reason, state}
      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:js_message, message}, state) do
    if state.awaiting_receive do
      # Deliver to blocked receive call
      BeamjsNif.deliver_host_reply(state.ctx_ref, message)
      {:noreply, %{state | awaiting_receive: false}}
    else
      {:noreply, %{state | mailbox: :queue.in(message, state.mailbox)}}
    end
  end

  def handle_info({:host_call, "receive", _args}, state) do
    # Special: check mailbox or await
    case :queue.out(state.mailbox) do
      {{:value, message}, new_mailbox} ->
        BeamjsNif.deliver_host_reply(state.ctx_ref, message)
        {:noreply, %{state | mailbox: new_mailbox}}
      {:empty, _} ->
        {:noreply, %{state | awaiting_receive: true}}
    end
  end

  def handle_info({:host_call, fn_name, args}, state) do
    {reply, new_state} = dispatch_host_call(fn_name, args, state)
    BeamjsNif.deliver_host_reply(state.ctx_ref, reply)
    {:noreply, new_state}
  end

  def handle_info({:load_module, module_name}, state) do
    result = BeamjsCore.ModuleResolver.resolve_and_load(module_name, state.base_dir)
    BeamjsNif.deliver_host_reply(state.ctx_ref, result)
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    if state.ctx_ref do
      BeamjsNif.destroy_context(state.ctx_ref)
    end
    :ok
  end

  # --- Host Function Dispatch ---

  defp dispatch_host_call("send", [pid_data, message], state) do
    case deserialize_pid(pid_data) do
      {:ok, pid} ->
        Kernel.send(pid, {:js_message, message})
        {:ok, state}
      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  defp dispatch_host_call("self", _args, state) do
    {serialize_pid(self()), state}
  end

  defp dispatch_host_call("spawn", [source | rest], state) do
    opts = case rest do
      [opts_map] when is_map(opts_map) -> opts_map
      _ -> %{}
    end

    spawn_opts = [
      source: source,
      base_dir: state.base_dir,
      name: Map.get(opts, "name")
    ]

    case start_supervised(spawn_opts) do
      {:ok, pid} -> {serialize_pid(pid), state}
      {:error, reason} -> {%{"error" => inspect(reason)}, state}
    end
  end

  defp dispatch_host_call("spawn_link", [source | rest], state) do
    opts = case rest do
      [opts_map] when is_map(opts_map) -> opts_map
      _ -> %{}
    end

    spawn_opts = [
      source: source,
      base_dir: state.base_dir,
      name: Map.get(opts, "name")
    ]

    case start_supervised(spawn_opts) do
      {:ok, pid} ->
        Process.link(pid)
        {serialize_pid(pid), state}
      {:error, reason} ->
        {%{"error" => inspect(reason)}, state}
    end
  end

  defp dispatch_host_call("receive", _args, state) do
    case :queue.out(state.mailbox) do
      {{:value, message}, new_mailbox} ->
        # Message already in queue, return immediately
        BeamjsNif.deliver_host_reply(state.ctx_ref, message)
        {:noreply_already_replied, %{state | mailbox: new_mailbox}}
      {:empty, _} ->
        # No message yet, mark as awaiting and don't reply yet
        {:noreply_await, %{state | awaiting_receive: true}}
    end
  end

  defp dispatch_host_call("register", [name], state) do
    Registry.register(BeamjsCore.ProcessRegistry, name, [])
    {:ok, state}
  end

  defp dispatch_host_call("whereis", [name], state) do
    case Registry.lookup(BeamjsCore.ProcessRegistry, name) do
      [{pid, _}] -> {serialize_pid(pid), state}
      [] -> {nil, state}
    end
  end

  defp dispatch_host_call("monitor", [pid_data], state) do
    case deserialize_pid(pid_data) do
      {:ok, pid} ->
        ref = Process.monitor(pid)
        {inspect(ref), state}
      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  defp dispatch_host_call("link", [pid_data], state) do
    case deserialize_pid(pid_data) do
      {:ok, pid} ->
        Process.link(pid)
        {:ok, state}
      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  defp dispatch_host_call("exit", [reason], state) do
    Process.exit(self(), reason || :normal)
    {:ok, state}
  end

  defp dispatch_host_call("call", [pid_data, request, timeout], state) do
    timeout = if is_integer(timeout), do: timeout, else: 5000
    case deserialize_pid(pid_data) do
      {:ok, pid} ->
        try do
          result = GenServer.call(pid, {:js_call, request}, timeout)
          {result, state}
        catch
          :exit, reason -> {%{"error" => inspect(reason)}, state}
        end
      {:error, reason} ->
        {%{"error" => inspect(reason)}, state}
    end
  end

  defp dispatch_host_call("cast", [pid_data, request], state) do
    case deserialize_pid(pid_data) do
      {:ok, pid} ->
        GenServer.cast(pid, {:js_cast, request})
        {:ok, state}
      {:error, reason} ->
        {{:error, reason}, state}
    end
  end

  defp dispatch_host_call("reply", [from_encoded, response], state) do
    try do
      from = from_encoded |> Base.decode64!() |> :erlang.binary_to_term()
      GenServer.reply(from, response)
      {:ok, state}
    rescue
      _ -> {{:error, "invalid_from"}, state}
    end
  end

  defp dispatch_host_call("start_gen_server", [class_name, source, args | rest], state) do
    opts = case rest do
      [opts_map] when is_map(opts_map) -> opts_map
      _ -> %{}
    end

    # Build a JS source that defines the GenServer and wires up callbacks
    full_source = """
    #{source}
    var __gs_instance = new #{class_name}();
    var __genserver_state = __gs_instance.init(#{Jason.encode!(args)});
    function __genserver_handle_call(request, from, state) {
      __genserver_state = state;
      return __gs_instance.handleCall(request, from, __genserver_state);
    }
    function __genserver_handle_cast(request, state) {
      __genserver_state = state;
      return __gs_instance.handleCast(request, __genserver_state);
    }
    function __genserver_handle_info(message, state) {
      __genserver_state = state;
      return __gs_instance.handleInfo(message, __genserver_state);
    }
    """

    spawn_opts = [
      source: full_source,
      base_dir: state.base_dir,
      name: Map.get(opts, "name")
    ]

    case start_supervised(spawn_opts) do
      {:ok, pid} ->
        if Map.get(opts, "link") do
          Process.link(pid)
        end
        {%{"ok" => serialize_pid(pid)}, state}
      {:error, reason} ->
        {%{"error" => inspect(reason)}, state}
    end
  end

  defp dispatch_host_call("start_supervisor", [spec], state) do
    case BeamjsCore.SupervisorBridge.start_link(spec, state.base_dir) do
      {:ok, pid} ->
        if Map.get(spec, "link") do
          Process.link(pid)
        end
        {%{"ok" => serialize_pid(pid)}, state}
      {:error, reason} ->
        {%{"error" => inspect(reason)}, state}
    end
  end

  defp dispatch_host_call("log", [level, message], state) do
    case level do
      "debug" -> Logger.debug(message)
      "info" -> Logger.info(message)
      "warn" -> Logger.warn(message)
      "error" -> Logger.error(message)
      _ -> Logger.info(message)
    end
    {:ok, state}
  end

  defp dispatch_host_call("task_async", [source], state) do
    task = Task.async(fn ->
      {:ok, ctx_ref} = BeamjsNif.new_context([])
      result = BeamjsNif.eval(ctx_ref, source, "<task>")
      BeamjsNif.destroy_context(ctx_ref)
      case result do
        {:ok, val} -> val
        {:error, reason} -> {:error, reason}
      end
    end)
    {%{"pid" => serialize_pid(task.pid), "ref" => inspect(task.ref)}, state}
  end

  defp dispatch_host_call("task_await", [_ref_str, _timeout], state) do
    # Note: simplified; in production would need to track Task refs
    {:ok, state}
  end

  defp dispatch_host_call("agent_start", [initial_value, opts], state) do
    name = case Map.get(opts || %{}, "name") do
      nil -> []
      n -> [name: {:via, Registry, {BeamjsCore.ProcessRegistry, n}}]
    end

    case Agent.start_link(fn -> initial_value end, name) do
      {:ok, pid} -> {%{"ok" => serialize_pid(pid)}, state}
      {:error, reason} -> {%{"error" => inspect(reason)}, state}
    end
  end

  defp dispatch_host_call("agent_get", [pid_data, _fn_source], state) do
    case deserialize_pid(pid_data) do
      {:ok, pid} ->
        value = Agent.get(pid, & &1)
        {value, state}
      {:error, reason} ->
        {%{"error" => inspect(reason)}, state}
    end
  end

  defp dispatch_host_call("agent_update", [pid_data, fn_source], state) do
    case deserialize_pid(pid_data) do
      {:ok, pid} ->
        # Evaluate the update function in a temporary context
        Agent.update(pid, fn current_state ->
          {:ok, ctx_ref} = BeamjsNif.new_context([])
          BeamjsNif.set_global(ctx_ref, "__agent_state", current_state)
          case BeamjsNif.eval(ctx_ref, "var __fn = #{fn_source}; __fn(__agent_state);", "<agent>") do
            {:ok, new_state} ->
              BeamjsNif.destroy_context(ctx_ref)
              new_state
            {:error, _} ->
              BeamjsNif.destroy_context(ctx_ref)
              current_state
          end
        end)
        {:ok, state}
      {:error, reason} ->
        {{:error, inspect(reason)}, state}
    end
  end

  defp dispatch_host_call("agent_stop", [pid_data], state) do
    case deserialize_pid(pid_data) do
      {:ok, pid} ->
        Agent.stop(pid)
        {:ok, state}
      {:error, reason} ->
        {{:error, inspect(reason)}, state}
    end
  end

  defp dispatch_host_call(fn_name, _args, state) do
    Logger.warn("Unknown host function: #{fn_name}")
    {%{"error" => "unknown_function: #{fn_name}"}, state}
  end

  # --- PID Serialization ---

  defp serialize_pid(pid) when is_pid(pid) do
    %{
      "__beamjs_type" => "pid",
      "__beamjs_data" => :erlang.term_to_binary(pid) |> Base.encode64()
    }
  end

  defp deserialize_pid(%{"__beamjs_type" => "pid", "__beamjs_data" => data}) do
    try do
      pid = data |> Base.decode64!() |> :erlang.binary_to_term()
      {:ok, pid}
    rescue
      _ -> {:error, :invalid_pid}
    end
  end

  defp deserialize_pid(pid) when is_pid(pid), do: {:ok, pid}
  defp deserialize_pid(_), do: {:error, :invalid_pid}
end
