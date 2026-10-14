defmodule FellowshipApi.Accounts.Member do
  use Ecto.Schema
  import Ecto.Changeset

  schema "members" do
    field :full_name, :string
    field :email, :string
    field :phone_number, :string
    field :password, :string, virtual: true, redact: true
    field :password_hash, :string, redact: true
    field :status, :string, default: "active"
    field :gender, Ecto.Enum, values: [male: "male", female: "female"]
    field :residence_address, :string
    field :notification_push_enabled, :boolean, default: true
    field :notification_email_enabled, :boolean, default: true
    field :notification_reminder_minutes, :integer, default: 60
    timestamps(type: :utc_datetime)
  end

  def registration_changeset(member, attrs) do
    member
    |> cast(attrs, [:full_name, :email, :phone_number, :password, :gender, :residence_address])
    |> update_change(:email, &String.downcase(String.trim(&1)))
    |> validate_required([:full_name, :phone_number, :password, :gender, :residence_address])
    |> validate_length(:full_name, min: 2, max: 120)
    |> validate_length(:phone_number, min: 7, max: 30)
    |> validate_length(:password, min: 8, max: 72)
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/,
      message: "must be a valid email",
      allow_nil: true
    )
    |> unique_constraint(:email, name: :members_lower_email_index)
    |> unique_constraint(:phone_number)
    |> put_password_hash()
  end

  def profile_changeset(member, attrs) do
    member
    |> cast(attrs, [
      :full_name,
      :email,
      :phone_number,
      :notification_push_enabled,
      :notification_email_enabled,
      :notification_reminder_minutes
    ])
    |> update_change(:email, &String.downcase(String.trim(&1)))
    |> validate_required([:full_name, :phone_number])
    |> validate_number(:notification_reminder_minutes,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 10080
    )
    |> unique_constraint(:email, name: :members_lower_email_index)
    |> unique_constraint(:phone_number)
  end

  defp put_password_hash(changeset) do
    case get_change(changeset, :password) do
      password when is_binary(password) ->
        put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))

      _ ->
        changeset
    end
  end
end
