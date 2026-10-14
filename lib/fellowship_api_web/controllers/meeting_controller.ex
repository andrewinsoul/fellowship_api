defmodule FellowshipApiWeb.MeetingController do
  use FellowshipApiWeb, :controller
  alias FellowshipApi.Meetings

  def next(conn, _params) do
    case Meetings.next_meeting() do
      nil -> json(conn, %{data: nil})
      meeting -> json(conn, %{data: meeting_json(meeting)})
    end
  end

  def check_in_session(conn, _params) do
    meeting = Meetings.current_check_in_meeting()

    json(conn, %{
      data: %{
        check_in_open: not is_nil(meeting),
        meeting: if(meeting, do: meeting_json(meeting), else: nil)
      }
    })
  end

  def meeting_json(meeting) do
    %{
      id: meeting.id,
      title: meeting.title,
      starts_at: meeting.starts_at,
      ends_at: meeting.ends_at,
      status: meeting.status,
      timezone: Meetings.timezone()
    }
  end
end
