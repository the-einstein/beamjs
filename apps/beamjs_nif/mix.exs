defmodule BeamjsNif.MixProject do
  use Mix.Project

  def project do
    [
      app: :beamjs_nif,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      compilers: Mix.compilers(),
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    []
  end

  defp aliases do
    [
      compile: ["compile", &compile_nif/1]
    ]
  end

  defp compile_nif(_) do
    c_src = Path.join(__DIR__, "c_src")
    if File.dir?(c_src) do
      {result, exit_code} = System.cmd("make", [], cd: c_src, stderr_to_stdout: true)
      IO.puts(result)
      if exit_code != 0 do
        Mix.raise("NIF compilation failed")
      end
    end
  end
end
