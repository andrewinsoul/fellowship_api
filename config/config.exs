import Config

config :fellowship_api,
  ecto_repos: [FellowshipApi.Repo],
  generators: [timestamp_type: :utc_datetime]

config :fellowship_api, FellowshipApiWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [formats: [json: FellowshipApiWeb.ErrorJSON], layout: false],
  pubsub_server: FellowshipApi.PubSub,
  live_view: [signing_salt: "fellowship-live-salt"]

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase
config :phoenix, :json_library, Jason
config :bcrypt_elixir, log_rounds: 12

config :fellowship_api, Oban,
  repo: FellowshipApi.Repo,
  queues: [default: 5, notifications: 5],
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       # Runs every Tuesday shortly after midnight in the server timezone.
       # The worker itself always calculates dates in Africa/Lagos.
       {"15 0 * * 2", FellowshipApi.Workers.EnsureUpcomingMeetings}
     ]}
  ]

import_config "#{config_env()}.exs"
