defmodule FellowshipApi.Accounts do
  import Ecto.Query, warn: false
  alias FellowshipApi.Repo
  alias FellowshipApi.Accounts.Member

  def get_member(id), do: Repo.get(Member, id)

  def get_member_by_login(login) when is_binary(login) do
    normalized = String.trim(login)

    Repo.one(
      from m in Member,
        where:
          fragment("lower(?) = lower(?)", m.email, ^normalized) or m.phone_number == ^normalized
    )
  end

  def create_member(attrs) do
    %Member{}
    |> Member.registration_changeset(attrs)
    |> Repo.insert()
  end

  def update_member(%Member{} = member, attrs) do
    member
    |> Member.profile_changeset(attrs)
    |> Repo.update()
  end

  def authenticate(login, password) when is_binary(login) and is_binary(password) do
    case get_member_by_login(login) do
      %Member{password_hash: hash, status: "active"} = member when is_binary(hash) ->
        if Bcrypt.verify_pass(password, hash),
          do: {:ok, member},
          else: {:error, :invalid_credentials}

      _ ->
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}
    end
  end
end
