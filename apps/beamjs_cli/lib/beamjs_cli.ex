defmodule BeamjsCli do
  @moduledoc """
  BeamJS CLI - JavaScript/TypeScript runtime on the BEAM VM.
  """

  def main(args) do
    {opts, args, _} = OptionParser.parse(args,
      switches: [version: :boolean, help: :boolean, verbose: :boolean, supervised: :boolean],
      aliases: [v: :version, h: :help, s: :supervised]
    )

    if opts[:version] do
      BeamjsCli.Commands.Version.run()
    else
      case args do
        ["new" | rest] -> BeamjsCli.Commands.New.run(rest, opts)
        ["run" | rest] -> BeamjsCli.Commands.Run.run(rest, opts)
        ["shell" | rest] -> BeamjsCli.Commands.Shell.run(rest, opts)
        ["test" | rest] -> BeamjsCli.Commands.Test.run(rest, opts)
        ["version"] -> BeamjsCli.Commands.Version.run()
        [] -> print_usage()
        _ -> print_usage()
      end
    end
  end

  defp print_usage do
    IO.puts("""
    BeamJS v0.1.0 - JavaScript/TypeScript on the BEAM VM

    Usage: beamjs <command> [args]

    Commands:
      new <name>       Create a new BeamJS project
      run <file>       Run a JavaScript/TypeScript file
      shell            Start interactive REPL
      test             Run tests
      version          Print version info

    Options:
      -h, --help       Show help
      -v, --version    Show version

    Examples:
      beamjs new myapp
      beamjs run src/main.js
      beamjs shell
      beamjs test
    """)
  end
end
