defmodule FellowshipApiWeb.Plugs.Authenticate do
  import Plug.Conn
  alias FellowshipApi.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, member_id} <-
           Phoenix.Token.verify(FellowshipApiWeb.Endpoint, "member auth", token,
             max_age: 60 * 60 * 24 * 30
           ),
         member when not is_nil(member) <- Accounts.get_member(member_id) do
      assign(conn, :current_member, member)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{
          error: %{code: "unauthorized", message: "Please sign in to continue."}
        })
        |> halt()
    end
  end
end
