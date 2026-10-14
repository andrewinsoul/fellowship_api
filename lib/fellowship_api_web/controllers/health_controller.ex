defmodule FellowshipApiWeb.HealthController do
  use FellowshipApiWeb, :controller

  def show(conn, _params), do: json(conn, %{status: "ok", service: "fellowship_api"})
end
