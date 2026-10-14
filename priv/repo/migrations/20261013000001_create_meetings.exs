defmodule FellowshipApi.Repo.Migrations.CreateMeetings do
  use Ecto.Migration

  def change do
    create table(:meetings) do
      add :title, :string, null: false, default: "Monday Fellowship"
      add :starts_at, :utc_datetime, null: false
      add :ends_at, :utc_datetime, null: false
      add :status, :string, null: false, default: "scheduled"
      timestamps(type: :utc_datetime)
    end

    create unique_index(:meetings, [:starts_at])
    create index(:meetings, [:status, :starts_at])
  end
end
