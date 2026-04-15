defmodule Beamjs.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      releases: releases()
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"}
    ]
  end

  defp aliases do
    [
      beamjs: "run --no-halt -e 'BeamjsCli.main(System.argv())' --"
    ]
  end

  defp releases do
    [
      beamjs: [
        applications: [
          beamjs_nif: :permanent,
          beamjs_core: :permanent,
          beamjs_cli: :permanent
        ],
        steps: [:assemble, :tar],
        include_erts: true,
        include_executables_for: [:unix],
        strip_beams: true
      ]
    ]
  end
end
