defmodule BeamjsNif do
  @moduledoc """
  Low-level NIF bindings for QuickJS.
  All JS evaluation NIFs use dirty CPU schedulers.
  """
  @on_load :load_nif

  def load_nif do
    path = :filename.join(:code.priv_dir(:beamjs_nif), 'beamjs_nif')
    :erlang.load_nif(path, 0)
  end

  @doc "Create a new QuickJS runtime+context."
  def new_context(_opts \\ []), do: :erlang.nif_error(:not_loaded)

  @doc "Destroy a QuickJS context."
  def destroy_context(_ctx_ref), do: :erlang.nif_error(:not_loaded)

  @doc "Evaluate JS source code. Runs on dirty CPU scheduler."
  def eval(_ctx_ref, _source, _filename \\ "<eval>"), do: :erlang.nif_error(:not_loaded)

  @doc "Call a JS function by global name with args list."
  def call_function(_ctx_ref, _fn_name, _args), do: :erlang.nif_error(:not_loaded)

  @doc "Set a global JS variable from an Erlang term."
  def set_global(_ctx_ref, _name, _value), do: :erlang.nif_error(:not_loaded)

  @doc "Get a global JS variable as an Erlang term."
  def get_global(_ctx_ref, _name), do: :erlang.nif_error(:not_loaded)

  @doc "Execute pending JS async jobs (microtask queue)."
  def execute_pending_jobs(_ctx_ref), do: :erlang.nif_error(:not_loaded)

  @doc "Deliver a reply to a blocked host function call."
  def deliver_host_reply(_ctx_ref, _reply), do: :erlang.nif_error(:not_loaded)
end
