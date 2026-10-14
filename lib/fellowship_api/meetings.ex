defmodule FellowshipApi.Meetings do
  import Ecto.Query, warn: false
  alias FellowshipApi.Repo
  alias FellowshipApi.Meetings.Meeting

  @timezone "Africa/Lagos"
  def timezone, do: @timezone

  def get_meeting(id), do: Repo.get(Meeting, id)

  def next_meeting do
    now = DateTime.utc_now()

    Repo.one(
      from m in Meeting,
        where: m.status == "scheduled" and m.ends_at >= ^now,
        order_by: [asc: m.starts_at],
        limit: 1
    )
  end

  def current_check_in_meeting do
    now = DateTime.utc_now()

    Repo.one(
      from m in Meeting,
        where: m.status == "scheduled" and m.starts_at <= ^now and m.ends_at >= ^now,
        order_by: [asc: m.starts_at],
        limit: 1
    )
  end

  def list_upcoming(limit \\ 12) do
    now = DateTime.utc_now()

    Repo.all(
      from m in Meeting,
        where: m.status == "scheduled" and m.ends_at >= ^now,
        order_by: [asc: m.starts_at],
        limit: ^limit
    )
  end

  def ensure_meetings_for_dates(dates) when is_list(dates) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    rows =
      Enum.map(dates, fn %Date{} = date ->
        %{
          title: "Monday Fellowship",
          starts_at: local_datetime_to_utc!(date, ~T[19:00:00]),
          ends_at: local_datetime_to_utc!(date, ~T[21:00:00]),
          status: "scheduled",
          inserted_at: now,
          updated_at: now
        }
      end)

    {inserted_count, _returned_rows} =
      Repo.insert_all(Meeting, rows,
        on_conflict: :nothing,
        conflict_target: [:starts_at]
      )

    {:ok, inserted_count}
  end

  defp local_datetime_to_utc!(date, time) do
    naive = NaiveDateTime.new!(date, time)
    {:ok, local_dt} = DateTime.from_naive(naive, @timezone)
    DateTime.shift_zone!(local_dt, "Etc/UTC")
  end
end
