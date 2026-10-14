defmodule FellowshipApiWeb.HomeController do
  use FellowshipApiWeb, :controller
  alias FellowshipApi.Meetings
  alias FellowshipApi.Quotations
  alias FellowshipApiWeb.MeetingsJson
  alias FellowshipApi.Attendance
  alias FellowshipApiWeb.AuthController

  def show(conn, _params) do
    member = conn.assigns.current_member
    meeting = Meetings.next_meeting()
    latest_quote = Quotations.latest()
    current_meeting = Meetings.current_check_in_meeting()

    already_checked_in =
      if current_meeting,
        do: not is_nil(Attendance.get_attendance(member.id, current_meeting.id)),
        else: false

    json(conn, %{
      data: %{
        member: AuthController.member_json(member),
        next_meeting: if(meeting, do: MeetingsJson.render(meeting), else: nil),
        check_in: %{open: not is_nil(current_meeting), already_checked_in: already_checked_in},
        latest_quotation:
          if(latest_quote,
            do: %{
              id: latest_quote.id,
              text: latest_quote.text,
              source: latest_quote.source,
              published_at: latest_quote.published_at
            },
            else: nil
          ),
        notification_preferences: %{
          push_enabled: member.notification_push_enabled,
          email_enabled: member.notification_email_enabled,
          reminder_minutes: member.notification_reminder_minutes
        }
      }
    })
  end
end

defmodule FellowshipApiWeb.MeetingsJson do
  def render(meeting),
    do: %{
      id: meeting.id,
      title: meeting.title,
      starts_at: meeting.starts_at,
      ends_at: meeting.ends_at,
      timezone: "Africa/Lagos",
      status: meeting.status
    }
end
