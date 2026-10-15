defmodule FellowshipApiWeb.AuthController do
  use FellowshipApiWeb, :controller
  alias FellowshipApi.Accounts

  def register_and_check_in(conn, params) do
    case Accounts.create_member(params) do
      {:ok, member} ->
        conn
        |> put_status(:created)
        |> json(%{
          data: %{
            member: member_json(member),
            token: issue_token(member),
            attendance: nil,
            message:
              "Your account has been created. You can check in when a meeting is accepting attendance."
          }
        })

      {:error, changeset} ->
        if unique_constraint_error?(changeset) do
          conn
          |> put_status(:conflict)
          |> json(%{
            error: %{
              code: "unique_constraint_violation",
              message: "A record with these details already exists."
            }
          })
        else
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{
            error: %{
              code: "validation_failed",
              message: "Please check the submitted details...",
              details: errors_on(changeset)
            }
          })
        end
    end
  end

  defp unique_constraint_error?(changeset) do
    Enum.any?(changeset.errors, fn {_field, {_message, opts}} ->
      opts[:constraint] == :unique
    end)
  end

  def login(conn, %{"login" => login, "password" => password}) do
    case Accounts.authenticate(login, password) do
      {:ok, member} ->
        json(conn, %{data: %{member: member_json(member), token: issue_token(member)}})

      {:error, _} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{
          error: %{
            code: "invalid_credentials",
            message: "The details provided could not be verified."
          }
        })
    end
  end

  def login(conn, _),
    do:
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{
        error: %{code: "missing_credentials", message: "Login and password are required."}
      })

  def logout(conn, _params),
    do: json(conn, %{data: %{message: "Signed out. Discard the token on this device."}})

  def forgot_password(conn, _params) do
    # Password reset delivery is intentionally not implemented in this starter.
    json(conn, %{
      data: %{
        message:
          "If an account matches those details, recovery instructions will be sent when password recovery is configured."
      }
    })
  end

  def issue_token(member),
    do: Phoenix.Token.sign(FellowshipApiWeb.Endpoint, "member auth", member.id)

  def member_json(member) do
    %{
      id: member.id,
      full_name: member.full_name,
      email: member.email,
      phone_number: member.phone_number,
      status: member.status
    }
  end

  def attendance_json(attendance, meeting) do
    %{
      id: attendance.id,
      checked_in_at: attendance.checked_in_at,
      meeting: %{
        id: meeting.id,
        title: meeting.title,
        starts_at: meeting.starts_at,
        ends_at: meeting.ends_at
      }
    }
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
