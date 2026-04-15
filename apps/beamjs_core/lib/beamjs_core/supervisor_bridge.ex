defmodule BeamjsCore.SupervisorBridge do
  @moduledoc """
  Translates JS supervisor specifications into OTP Supervisor child specs.
  """
  use Supervisor

  def start_link(js_spec, base_dir) do
    Supervisor.start_link(__MODULE__, {js_spec, base_dir}, name: via_name(js_spec))
  end

  @impl true
  def init({js_spec, base_dir}) do
    strategy = map_strategy(js_spec["strategy"])
    children = Enum.map(js_spec["children"] || [], fn child ->
      to_child_spec(child, base_dir)
    end)

    Supervisor.init(children,
      strategy: strategy,
      max_restarts: js_spec["maxRestarts"] || 3,
      max_seconds: js_spec["maxSeconds"] || 5
    )
  end

  defp via_name(%{"name" => name}) when is_binary(name) do
    {:via, Registry, {BeamjsCore.ProcessRegistry, "sup:" <> name}}
  end
  defp via_name(_), do: nil

  defp map_strategy("one_for_one"), do: :one_for_one
  defp map_strategy("one_for_all"), do: :one_for_all
  defp map_strategy("rest_for_one"), do: :rest_for_one
  defp map_strategy(_), do: :one_for_one

  defp to_child_spec(spec, base_dir) do
    id = spec["id"] || System.unique_integer([:positive])
    restart = map_restart(spec["restart"])

    case spec["type"] do
      "supervisor" ->
        %{
          id: id,
          start: {__MODULE__, :start_link, [spec, base_dir]},
          type: :supervisor,
          restart: restart
        }
      _ ->
        source = spec["source"] || build_source(spec)
        %{
          id: id,
          start: {BeamjsCore.Process, :start_link, [[
            source: source,
            filename: spec["filename"] || "<child:#{id}>",
            base_dir: base_dir,
            name: spec["name"]
          ]]},
          restart: restart,
          shutdown: spec["shutdown"] || 5000
        }
    end
  end

  defp build_source(%{"module" => module_source, "args" => args}) do
    """
    #{module_source}
    var __gs_class = #{extract_class_name(module_source)};
    var __gs_instance = new __gs_class();
    var __genserver_state = __gs_instance.init(#{Jason.encode!(args || %{})});
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
  end
  defp build_source(%{"source" => source}), do: source
  defp build_source(_), do: ""

  defp extract_class_name(source) do
    case Regex.run(~r/class\s+(\w+)/, source) do
      [_, name] -> name
      _ -> "GenServer"
    end
  end

  defp map_restart("permanent"), do: :permanent
  defp map_restart("temporary"), do: :temporary
  defp map_restart("transient"), do: :transient
  defp map_restart(_), do: :permanent
end
