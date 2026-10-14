defmodule FellowshipApiWeb.Router do
  use FellowshipApiWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authenticated do
    plug FellowshipApiWeb.Plugs.Authenticate
  end

  scope "/api/v1", FellowshipApiWeb do
    pipe_through :api

    get "/health", HealthController, :show
    post "/auth/register", AuthController, :register_and_check_in
    post "/auth/login", AuthController, :login
    post "/auth/forgot-password", AuthController, :forgot_password
    get "/meetings/next", MeetingController, :next
    get "/check-in/session", MeetingController, :check_in_session
    get "/quotations", QuotationController, :index
    get "/quotations/latest", QuotationController, :latest
  end

  scope "/api/v1", FellowshipApiWeb do
    pipe_through [:api, :authenticated]

    get "/home", HomeController, :show
    post "/auth/logout", AuthController, :logout
    get "/profile", ProfileController, :show
    patch "/profile", ProfileController, :update
    get "/attendance", AttendanceController, :index
    post "/attendance/check-in", AttendanceController, :check_in
    get "/notification-preferences", ProfileController, :notification_preferences
    patch "/notification-preferences", ProfileController, :update_notification_preferences
  end
end
