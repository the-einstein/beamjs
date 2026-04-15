defmodule BeamjsCore.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: BeamjsCore.ProcessRegistry},
      {DynamicSupervisor, name: BeamjsCore.ProcessSupervisor, strategy: :one_for_one}
    ]

    opts = [strategy: :one_for_one, name: BeamjsCore.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
