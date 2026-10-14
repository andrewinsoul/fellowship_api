alias FellowshipApi.Repo
alias FellowshipApi.Quotations.Quotation

quotes = [
  {"Your word is a lamp for my feet, a light on my path.", "Psalm 119:105"},
  {"Be strong and courageous. Do not be afraid; do not be discouraged, for the Lord your God will be with you wherever you go.", "Joshua 1:9"},
  {"Let all that you do be done in love.", "1 Corinthians 16:14"}
]

Enum.each(quotes, fn {text, source} ->
  unless Repo.get_by(Quotation, text: text) do
    %Quotation{}
    |> Quotation.changeset(%{text: text, source: source, published: true, published_at: DateTime.utc_now()})
    |> Repo.insert!()
  end
end)
