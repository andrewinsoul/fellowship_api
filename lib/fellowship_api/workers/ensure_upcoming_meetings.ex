defmodule FellowshipApi.Workers.EnsureUpcomingMeetings do
  use Oban.Worker, queue: :default, max_attempts: 5
  alias FellowshipApi.Meetings

  @impl Oban.Worker
  def perform(_job) do
    # Keep a rolling 12-week window of Monday occurrences. This makes the
    # schedule resilient to a missed weekly job and keeps meetings available
    # for reminders well ahead of time.
    today = DateTime.now!("Africa/Lagos") |> DateTime.to_date()
    next_monday = Date.add(Date.beginning_of_week(today, :monday), 7)

    dates = for offset <- 0..11, do: Date.add(next_monday, offset * 7)

    {:ok, _inserted_count} = Meetings.ensure_meetings_for_dates(dates)

    :ok
  end
end
