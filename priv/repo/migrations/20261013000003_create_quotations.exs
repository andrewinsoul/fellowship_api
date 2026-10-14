defmodule FellowshipApi.Repo.Migrations.CreateQuotations do
  use Ecto.Migration

  def change do
    create table(:quotations) do
      add :text, :text, null: false
      add :source, :string
      add :published, :boolean, null: false, default: true
      add :published_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create index(:quotations, [:published, :published_at])
  end
end
