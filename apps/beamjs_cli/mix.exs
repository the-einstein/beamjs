defmodule BeamjsCli.MixProject do
  use Mix.Project

  def project do
    [
      app: :beamjs_cli,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      escript: [main_module: BeamjsCli],
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:beamjs_core, in_umbrella: true}
    ]
  end
end
