defmodule FellowshipApiWeb.AttendanceController do
  use FellowshipApiWeb, :controller
  alias FellowshipApi.Attendance
  alias FellowshipApiWeb.AuthController
  alias FellowshipApiWeb.Pagination

  def check_in(conn, _params) do
    case Attendance.check_in(conn.assigns.current_member) do
      {:ok, :checked_in, meeting, record} ->
        conn
        |> put_status(:created)
        |> json(%{
          data: %{
            status: "checked_in",
            attendance: AuthController.attendance_json(record, meeting),
            message: "Check-in successful!"
          }
        })

      {:ok, :already_checked_in, meeting, record} ->
        json(conn, %{
          data: %{
            status: "already_checked_in",
            attendance:
              if(record, do: AuthController.attendance_json(record, meeting), else: nil),
            message: "You have already checked in for this meeting."
          }
        })

      {:error, :check_in_closed} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: %{
            code: "check_in_closed",
            message: "There is no meeting accepting check-ins right now."
          }
        })

      {:error, _} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          error: %{
            code: "check_in_failed",
            message: "We could not record your attendance. Please try again."
          }
        })
    end
  end

  def index(conn, params) do
    %{page: page, page_size: page_size} = Pagination.parse(params)

    {records, total_entries} =
      Attendance.list_for_member(conn.assigns.current_member.id, page, page_size)

    json(conn, %{
      data:
        Enum.map(records, fn record ->
          %{
            id: record.id,
            checked_in_at: record.checked_in_at,
            meeting: %{
              id: record.meeting.id,
              title: record.meeting.title,
              starts_at: record.meeting.starts_at,
              ends_at: record.meeting.ends_at
            }
          }
        end),
      meta: Pagination.metadata(page, page_size, total_entries)
    })
  end
end
