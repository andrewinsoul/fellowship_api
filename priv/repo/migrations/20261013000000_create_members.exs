defmodule FellowshipApi.Repo.Migrations.CreateMembers do
  use Ecto.Migration

  def change do
    create table(:members) do
      add :full_name, :string, null: false
      add :email, :string, null: false
      add :phone_number, :string, null: false
      add :password_hash, :string, null: false
      add :status, :string, null: false, default: "active"
      add :gender, :string, null: false
      add :residence_address, :string
      add :notification_push_enabled, :boolean, null: false, default: true
      add :notification_email_enabled, :boolean, null: false, default: true
      add :notification_reminder_minutes, :integer, null: false, default: 60
      timestamps(type: :utc_datetime)
    end

    create unique_index(:members, ["lower(email)"], name: :members_lower_email_index, where: "email IS NOT NULL")
    create unique_index(:members, [:phone_number])
    create constraint(:members, :members_gender_check, check: "gender IN ('male', 'female')")
  end
end
