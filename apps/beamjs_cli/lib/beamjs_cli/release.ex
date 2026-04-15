defmodule BeamjsCli.Release do
  @moduledoc """
  Entry point for the BeamJS release binary.
  Called via: beamjs eval "BeamjsCli.Release.cli()"
  with BEAMJS_ARGS set to the original CLI arguments.
  """

  def cli do
    args = System.get_env("BEAMJS_ARGS", "")
    argv = if args == "", do: [], else: OptionParser.split(args)
    BeamjsCli.main(argv)
  end
end
