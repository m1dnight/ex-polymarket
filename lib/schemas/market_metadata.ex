defmodule Polymarket.Schemas.MarketMetadata do
  @moduledoc """
  Sports metadata for a market. Part of a `Market` returned by the Gamma API.

  Links a market to its corresponding fixture/market in the Optic Odds feed.
  """

  use TypedEctoSchema

  import Ecto.Changeset

  @primary_key false

  typed_embedded_schema do
    field(:optic_odds_fixture_id, :string)
    field(:optic_odds_market_id, :string)
    field(:optic_odds_market_name, :string)
    field(:optic_odds_selection, :string)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(metadata, attrs) do
    castable = __MODULE__.__schema__(:fields) -- __MODULE__.__schema__(:embeds)

    cast(metadata, attrs, castable)
  end
end
