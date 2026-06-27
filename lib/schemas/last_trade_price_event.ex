defmodule Polymarket.Schemas.LastTradePriceEvent do
  @moduledoc """
  Last trade price event. Reports the price, size and side of the most recent
  trade executed against an asset.
  """

  use TypedEctoSchema

  import Ecto.Changeset

  alias Polymarket.Schemas.LastTradePriceEvent

  @primary_key false

  typed_embedded_schema do
    field(:market, :string)
    field(:asset_id, :string)
    field(:price, :float)
    field(:size, :float)
    # Maker fee in basis points, delivered as a string (e.g. "0").
    field(:fee_rate_bps, :integer)
    field(:side, :string)
    field(:transaction_hash, :string)
    # Unix epoch in milliseconds, delivered as a string (e.g. "1782553200051").
    field(:timestamp, :integer)
    field(:event_type, :string)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(event, attrs) do
    castable = __MODULE__.__schema__(:fields) -- __MODULE__.__schema__(:embeds)

    event
    |> cast(attrs, castable)
    |> validate_required([
      :market,
      :asset_id,
      :price,
      :size,
      :side,
      :transaction_hash,
      :timestamp,
      :event_type
    ])
  end

  @doc """
  Create a `LastTradePriceEvent` from the given map of attributes. Returns an error
  if the attributes are not valid.
  """
  @spec from_attrs(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def from_attrs(attrs) do
    %LastTradePriceEvent{}
    |> changeset(attrs)
    |> case do
      %{valid?: true} = changeset ->
        {:ok, apply_changes(changeset)}

      changeset ->
        {:error, changeset}
    end
  end
end
