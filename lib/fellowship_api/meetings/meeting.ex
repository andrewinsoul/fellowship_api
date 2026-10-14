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
    |> validate_change(:ends_at, fn :ends_at, ends_at ->
      case get_field(meeting, :starts_at) do
        %DateTime{} = starts_at ->
          if DateTime.compare(ends_at, starts_at) == :gt,
            do: [],
            else: [ends_at: "must be after the start time"]

        _ ->
          []
      end
    end)
    |> unique_constraint(:starts_at)
  end
end
