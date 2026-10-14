defmodule FellowshipApiWeb.ProfileController do
  use FellowshipApiWeb, :controller
  alias FellowshipApi.Accounts
  alias FellowshipApiWeb.AuthController

  def show(conn, _params),
    do: json(conn, %{data: AuthController.member_json(conn.assigns.current_member)})

  def update(conn, params) do
    case Accounts.update_member(conn.assigns.current_member, params) do
      {:ok, member} ->
        json(conn, %{data: AuthController.member_json(member)})

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: %{
            code: "validation_failed",
            details: Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
          }
        })
    end
  end

  def notification_preferences(conn, _params) do
    member = conn.assigns.current_member

    json(conn, %{
      data: %{
        push_enabled: member.notification_push_enabled,
        email_enabled: member.notification_email_enabled,
        reminder_minutes: member.notification_reminder_minutes
      }
    })
  end

  def update_notification_preferences(conn, params) do
    allowed =
      %{
        "notification_push_enabled" => params["push_enabled"],
        "notification_email_enabled" => params["email_enabled"],
        "notification_reminder_minutes" => params["reminder_minutes"]
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    case Accounts.update_member(conn.assigns.current_member, allowed) do
      {:ok, member} ->
        json(conn, %{
          data: %{
            push_enabled: member.notification_push_enabled,
            email_enabled: member.notification_email_enabled,
            reminder_minutes: member.notification_reminder_minutes
          }
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: %{
            code: "validation_failed",
            details: Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)
          }
        })
    end
  end
end
