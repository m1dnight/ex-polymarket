defmodule Polymarket.Schemas.Bid do
  @moduledoc """
  A single bid price level in an order book. Part of a BookEvent.
  """

  use TypedEctoSchema

  import Ecto.Changeset

  @primary_key false

  typed_embedded_schema do
    field(:price, :float)
    field(:size, :float)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(bid, attrs) do
    castable = __MODULE__.__schema__(:fields) -- __MODULE__.__schema__(:embeds)

    bid
    |> cast(attrs, castable)
    |> validate_required([:price, :size])
  end
end
