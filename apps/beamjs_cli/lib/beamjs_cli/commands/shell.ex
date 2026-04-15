defmodule BeamjsCli.Commands.Shell do
  @moduledoc "Interactive REPL for BeamJS."

  def run(_args, _opts) do
    Application.ensure_all_started(:beamjs_core)
    BeamjsCli.Repl.start()
  end
end
