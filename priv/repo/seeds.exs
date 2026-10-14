alias FellowshipApi.Repo
alias FellowshipApi.Quotations.Quotation

# The World English Bible British Edition (WEBBE) is public domain and contains
# the Protestant 66-book canon. We download the official verse-per-line archive
# only when seeding; the running application reads verses from PostgreSQL and
# never calls an external Bible API.
archive_dir = Path.join(:code.priv_dir(:fellowship_api) |> List.to_string(), "repo/data")
File.mkdir_p!(archive_dir)
archive_path = Path.join(archive_dir, "engwebpb_vpl.zip")
archive_url = "https://ebible.org/Scriptures/engwebpb_vpl.zip"

unless File.exists?(archive_path) do
  {output, status} = System.cmd("curl", ["--fail", "--location", "--silent", "--show-error", "--output", archive_path, archive_url], stderr_to_stdout: true)

  if status != 0 do
    File.rm(archive_path)
    raise "Could not download the official World English Bible archive: #{output}"
  end
end

{entries_output, 0} = System.cmd("unzip", ["-Z1", archive_path])
entries = String.split(entries_output, "\n", trim: true)

vpl_entry =
  Enum.find(entries, &(String.ends_with?(String.downcase(&1), ".vpl"))) ||
    Enum.find(entries, &(String.ends_with?(String.downcase(&1), ".txt")))

if is_nil(vpl_entry) do
  raise "Could not find a VPL or TXT file inside #{archive_path}; remove the cached archive and rerun seeds."
end

{vpl_text, 0} = System.cmd("unzip", ["-p", archive_path, vpl_entry], max_size: 100_000_000)

verses =
  vpl_text
  |> String.split("\n", trim: true)
  |> Enum.reduce([], fn line, acc ->
    # VPL lines have the form: Genesis 1:1 Verse text
    case Regex.run(~r/^(.+?)\s+(\d+):(\d+)\s+(.+)$/, String.trim(line)) do
      [_, book, chapter, verse, text] ->
        book = String.trim(book)
        text = String.trim(text)

        if book != "" and text != "" do
          [%{text: text, source: "#{book} #{chapter}:#{verse}"} | acc]
        else
          acc
        end

      _ ->
        acc
    end
  end)
  |> Enum.reverse()

book_count = verses |> Enum.map(fn verse -> verse.source |> String.replace(~r/\s+\d+:\d+$/, "") end) |> Enum.uniq() |> length()

# Fail loudly rather than silently seeding a partial or malformed Bible.
if book_count != 66 or length(verses) < 30_000 do
  raise "Expected the complete 66-book Bible (at least 30,000 verses), parsed #{book_count} books and #{length(verses)} verses. Check #{archive_path}."
end

now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

# This table now represents scripture quotations. Re-seeding is deterministic
# and replaces the old sample quotations instead of accumulating duplicates.
Repo.delete_all(Quotation)

verses
|> Enum.map(fn verse ->
  Map.merge(verse, %{
    published: true,
    published_at: now,
    inserted_at: now,
    updated_at: now
  })
end)
|> Enum.chunk_every(1_000)
|> Enum.each(fn batch ->
  Repo.insert_all(Quotation, batch)
end)

IO.puts("Seeded #{length(verses)} Bible verses from #{book_count} books (World English Bible British Edition).")
