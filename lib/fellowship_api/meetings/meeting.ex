defmodule FellowshipApi.Meetings.Meeting do
  use Ecto.Schema
  import Ecto.Changeset

  schema "meetings" do
    field :title, :string, default: "Monday Fellowship"
    field :starts_at, :utc_datetime
    field :ends_at, :utc_datetime
    field :status, :string, default: "scheduled"
    timestamps(type: :utc_datetime)
  end


def changeset(meeting, attrs) do
  meeting
  |> cast(attrs, [:title, :starts_at, :ends_at, :status])
  |> validate_required([:title, :starts_at, :ends_at, :status])
  |> validate_inclusion(:status, ["scheduled", "cancelled"])
  |> validate_meeting_time_order()
  |> unique_constraint(:starts_at)
end

defp validate_meeting_time_order(changeset) do
  starts_at = get_field(changeset, :starts_at)
  ends_at = get_field(changeset, :ends_at)

  if starts_at && ends_at && DateTime.compare(ends_at, starts_at) != :gt do
    add_error(changeset, :ends_at, "must be after the start time")
  else
    changeset
  end
end

end
