defmodule Polymarket.Schemas.BookEvent do
  @moduledoc """
  Book event. A full order book snapshot for an asset.
  """

  use TypedEctoSchema

  import Ecto.Changeset

  alias Polymarket.Schemas.Ask
  alias Polymarket.Schemas.Bid
  alias Polymarket.Schemas.BookEvent

  @primary_key false

  typed_embedded_schema do
    field(:market, :string)
    field(:asset_id, :string)
    field(:hash, :string)
    # Unix epoch in milliseconds, delivered as a string (e.g. "1779658820355").
    field(:timestamp, :integer)
    field(:event_type, :string)
    field(:last_trade_price, :float)
    field(:tick_size, :float)

    embeds_many(:bids, Bid)
    embeds_many(:asks, Ask)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:market, :asset_id, :hash, :timestamp, :event_type, :tick_size, :last_trade_price])
    |> validate_required([:market, :asset_id, :hash, :timestamp, :event_type])
    |> cast_embed(:bids)
    |> cast_embed(:asks)
  end

  @doc """
  Create a `BookEvent` from the given map of attributes. Returns an error
  if the attributes are not valid.
  """
  @spec from_attrs(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def from_attrs(attrs) do
    %BookEvent{}
    |> changeset(attrs)
    |> case do
      %{valid?: true} = changeset ->
        {:ok, apply_changes(changeset)}

      changeset ->
        {:error, changeset}
    end
  end
end
