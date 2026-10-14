defmodule FellowshipApiWeb.Pagination do
  @moduledoc """
  Shared pagination parsing and response metadata for collection endpoints.

  Defaults to page 1 with 20 records per page and caps page_size at 100.
  Invalid, zero, or negative values fall back to the defaults.
  """

  @default_page 1
  @default_page_size 20
  @max_page_size 100

  def parse(params) do
    %{
      page: positive_integer(params["page"], @default_page),
      page_size:
        params["page_size"]
        |> positive_integer(@default_page_size)
        |> min(@max_page_size)
    }
  end

  def metadata(page, page_size, total_entries) do
    %{
      page: page,
      page_size: page_size,
      total_entries: total_entries,
      total_pages:
        if(total_entries == 0,
          do: 0,
          else: div(total_entries + page_size - 1, page_size)
        ),
      has_previous_page: page > 1,
      has_next_page: page * page_size < total_entries
    }
  end

  defp positive_integer(value, _default)
       when is_integer(value) and value > 0,
       do: value

  defp positive_integer(value, default) when is_binary(value) do
    case Integer.parse(value) do
      {number, ""} when number > 0 -> number
      _ -> default
    end
  end

  defp positive_integer(_value, default), do: default
end
