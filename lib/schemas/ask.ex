defmodule Polymarket.Schemas.Ask do
  @moduledoc """
  A single ask price level in an order book. Part of a BookEvent.
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
  def changeset(ask, attrs) do
    ask
    |> cast(attrs, [:price, :size])
    |> validate_required([:price, :size])
  end
end
