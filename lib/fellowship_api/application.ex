defmodule FellowshipApi.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FellowshipApiWeb.Telemetry,
      FellowshipApi.Repo,
      {Phoenix.PubSub, name: FellowshipApi.PubSub},
      {Oban, Application.fetch_env!(:fellowship_api, Oban)},
      FellowshipApiWeb.Endpoint
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: FellowshipApi.Supervisor)
  end

  @impl true
  def config_change(changed, _new, removed) do
    FellowshipApiWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
