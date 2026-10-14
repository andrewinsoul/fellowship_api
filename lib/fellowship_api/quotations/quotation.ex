defmodule FellowshipApi.Quotations.Quotation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "quotations" do
    field :text, :string
    field :source, :string
    field :published, :boolean, default: true
    field :published_at, :utc_datetime
    timestamps(type: :utc_datetime)
  end

  def changeset(quotation, attrs) do
    quotation
    |> cast(attrs, [:text, :source, :published, :published_at])
    |> validate_required([:text])
    |> validate_length(:text, max: 2000)
  end
end
