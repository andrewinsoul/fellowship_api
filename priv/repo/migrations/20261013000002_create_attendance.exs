defmodule FellowshipApi.Repo.Migrations.CreateAttendance do
  use Ecto.Migration

  def change do
    create table(:attendance) do
      add :member_id, references(:members, on_delete: :delete_all), null: false
      add :meeting_id, references(:meetings, on_delete: :delete_all), null: false
      add :checked_in_at, :utc_datetime, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:attendance, [:member_id, :meeting_id])
    create index(:attendance, [:meeting_id])
  end
end
