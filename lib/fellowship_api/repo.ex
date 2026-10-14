defmodule FellowshipApi.Repo do
  use Ecto.Repo,
    otp_app: :fellowship_api,
    adapter: Ecto.Adapters.Postgres
end
