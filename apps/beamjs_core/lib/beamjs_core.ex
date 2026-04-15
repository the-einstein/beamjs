defmodule BeamjsCore do
  @moduledoc """
  BeamJS Core Runtime - JavaScript/TypeScript on the BEAM VM.
  """

  @doc "Evaluate JS source code in a new process."
  def eval(source, opts \\ []) do
    {:ok, pid} = BeamjsCore.Process.start_link(Keyword.merge([source: source], opts))
    pid
  end

  @doc "Evaluate JS source code synchronously, returning the result."
  def eval_sync(source, opts \\ []) do
    BeamjsCore.Process.eval_sync(source, opts)
  end
end
