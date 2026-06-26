defmodule Polymarket.Schemas.PriceChange do
  @moduledoc """
  Price change struct. Part of a PriceChangeEvent.
  """

  use TypedEctoSchema

  import Ecto.Changeset

  @primary_key false

  typed_embedded_schema do
    field(:asset_id, :string)
    field(:price, :float)
    field(:size, :float)
    field(:side, :string)
    field(:hash, :string)
    field(:best_bid, :float)
    field(:best_ask, :float)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(price_change, attrs) do
    price_change
    |> cast(attrs, [:asset_id, :price, :size, :side, :hash, :best_bid, :best_ask])
    |> validate_required([:asset_id, :price, :size, :side, :hash, :best_bid, :best_ask])
  end
end
