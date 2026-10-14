defmodule FellowshipApiWeb.QuotationController do
  use FellowshipApiWeb, :controller
  alias FellowshipApi.Quotations
  alias FellowshipApiWeb.Pagination

  def index(conn, params) do
    %{page: page, page_size: page_size} = Pagination.parse(params)
    {quotations, total_entries} = Quotations.list_published(page, page_size)

    json(conn, %{
      data: Enum.map(quotations, &quotation_json/1),
      meta: Pagination.metadata(page, page_size, total_entries)
    })
  end

  def latest(conn, _params) do
    case Quotations.latest() do
      nil -> json(conn, %{data: nil})
      quotation -> json(conn, %{data: quotation_json(quotation)})
    end
  end

  defp quotation_json(q),
    do: %{id: q.id, text: q.text, source: q.source, published_at: q.published_at}
end
