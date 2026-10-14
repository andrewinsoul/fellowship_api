defmodule FellowshipApi.Attendance do
  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias FellowshipApi.Repo
  alias FellowshipApi.Accounts.Member
  alias FellowshipApi.Accounts
  alias FellowshipApi.Meetings
  alias FellowshipApi.Attendance.AttendanceRecord

  def check_in(%Member{} = member) do
    case Meetings.current_check_in_meeting() do
      nil -> {:error, :check_in_closed}
      meeting -> insert_attendance(member, meeting)
    end
  end

  def register_and_check_in(attrs) do
    Multi.new()
    |> Multi.run(:meeting, fn _repo, _changes ->
      case Meetings.current_check_in_meeting() do
        nil -> {:error, :check_in_closed}
        meeting -> {:ok, meeting}
      end
    end)
    |> Multi.run(:member, fn _repo, _changes -> Accounts.create_member(attrs) end)
    |> Multi.insert(:attendance, fn %{member: member, meeting: meeting} ->
      AttendanceRecord.changeset(%AttendanceRecord{}, %{
        member_id: member.id,
        meeting_id: meeting.id,
        checked_in_at: DateTime.utc_now()
      })
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{member: member, meeting: meeting, attendance: attendance}} ->
        {:ok, member, meeting, attendance}

      {:error, :meeting, :check_in_closed, _} ->
        {:error, :check_in_closed}

      {:error, :member, changeset, _} ->
        {:error, changeset}

      {:error, :attendance, changeset, _} ->
        {:error, changeset}
    end
  end

  defp insert_attendance(member, meeting) do
    %AttendanceRecord{}
    |> AttendanceRecord.changeset(%{
      member_id: member.id,
      meeting_id: meeting.id,
      checked_in_at: DateTime.utc_now()
    })
    |> Repo.insert()
    |> case do
      {:ok, record} ->
        {:ok, :checked_in, meeting, record}

      {:error, %Ecto.Changeset{} = changeset} ->
        if unique_attendance_conflict?(changeset),
          do: {:ok, :already_checked_in, meeting, get_attendance(member.id, meeting.id)},
          else: {:error, changeset}
    end
  end

  defp unique_attendance_conflict?(changeset) do
    Enum.any?(changeset.errors, fn
      {:member_id, {_message, metadata}} -> metadata[:constraint] == :unique
      {:meeting_id, {_message, metadata}} -> metadata[:constraint] == :unique
      _ -> false
    end)
  end

  def get_attendance(member_id, meeting_id),
    do: Repo.get_by(AttendanceRecord, member_id: member_id, meeting_id: meeting_id)

  def list_for_member(member_id, page, page_size) do
    query =
      from a in AttendanceRecord,
        where: a.member_id == ^member_id

    total_entries = Repo.aggregate(query, :count, :id)
    offset = (page - 1) * page_size

    entries =
      Repo.all(
        from a in query,
          join: m in assoc(a, :meeting),
          order_by: [desc: a.checked_in_at, desc: a.id],
          limit: ^page_size,
          offset: ^offset,
          preload: [meeting: m]
      )

    {entries, total_entries}
  end
end
