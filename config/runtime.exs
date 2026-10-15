import Config

config :fellowship_api, :check_in_qr_token, System.get_env("CHECK_IN_QR_TOKEN")

if config_env() == :prod do
  database_url = System.get_env("DATABASE_URL") || raise "DATABASE_URL is required"
  secret_key_base = System.get_env("SECRET_KEY_BASE") || raise "SECRET_KEY_BASE is required"
  port = String.to_integer(System.get_env("PORT", "4000"))

  config :fellowship_api, FellowshipApi.Repo,
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "5")),
    ssl: System.get_env("DATABASE_SSL", "false") == "true"

  host = System.get_env("PHX_HOST") || "localhost"

  config :fellowship_api, FellowshipApiWeb.Endpoint,
    server: true,
    http: [ip: {0, 0, 0, 0}, port: port],
    url: [host: host, port: 443, scheme: "https"],
    secret_key_base: secret_key_base,
    check_origin: System.get_env("CHECK_ORIGIN", "//localhost") |> String.split(",")
end
