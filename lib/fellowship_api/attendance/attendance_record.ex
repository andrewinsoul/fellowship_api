defmodule FellowshipApi.Attendance.AttendanceRecord do
  use Ecto.Schema
  import Ecto.Changeset
  alias FellowshipApi.Meetings.Meeting

  schema "attendance" do
    field :checked_in_at, :utc_datetime
    belongs_to :member, FellowshipApi.Accounts.Member
    belongs_to :meeting, Meeting
    timestamps(type: :utc_datetime)
  end

  def changeset(record, attrs) do
    record
    |> cast(attrs, [:member_id, :meeting_id, :checked_in_at])
    |> validate_required([:member_id, :meeting_id, :checked_in_at])
    |> foreign_key_constraint(:member_id)
    |> foreign_key_constraint(:meeting_id)
    |> unique_constraint([:member_id, :meeting_id], name: :attendance_member_id_meeting_id_index)
  end
end
