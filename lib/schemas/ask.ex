defmodule Polymarket.Schemas.Ask do
  @moduledoc """
  A single ask price level in an order book. Part of a BookEvent.
  """

  use TypedEctoSchema

  import Ecto.Changeset

  @primary_key false

  @derive Jason.Encoder
  typed_embedded_schema do
    field(:price, :float)
    field(:size, :float)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(ask, attrs) do
    castable = __MODULE__.__schema__(:fields) -- __MODULE__.__schema__(:embeds)

    ask
    |> cast(attrs, castable)
    |> validate_required([:price, :size])
  end
end
