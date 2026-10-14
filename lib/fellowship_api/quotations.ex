defmodule FellowshipApi.Quotations do
  import Ecto.Query, warn: false
  alias FellowshipApi.Repo
  alias FellowshipApi.Quotations.Quotation

  def list_published(page, page_size) do
    now = DateTime.utc_now()

    query =
      from q in Quotation,
        where: q.published == true and (is_nil(q.published_at) or q.published_at <= ^now)

    total_entries = Repo.aggregate(query, :count, :id)
    offset = (page - 1) * page_size

    entries =
      Repo.all(
        from q in query,
          order_by: [desc: q.published_at, desc: q.inserted_at, desc: q.id],
          limit: ^page_size,
          offset: ^offset
      )

    {entries, total_entries}
  end

  def latest do
    now = DateTime.utc_now()

    Repo.one(
      from q in Quotation,
        where: q.published == true and (is_nil(q.published_at) or q.published_at <= ^now),
        order_by: fragment("RANDOM()"),
        limit: 1
    )
  end
end
