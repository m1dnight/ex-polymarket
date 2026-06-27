defmodule Polymarket.Schemas.BestBidAskEvent do
  @moduledoc """
  Best bid/ask event.
  """

  use TypedEctoSchema

  import Ecto.Changeset

  alias Polymarket.Schemas.BestBidAskEvent

  @primary_key false

  typed_embedded_schema do
    field(:market, :string)
    field(:asset_id, :string)
    field(:best_bid, :float)
    field(:best_ask, :float)
    field(:spread, :float)
    # Unix epoch in milliseconds, delivered as a string (e.g. "1779660673012").
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
      :best_bid,
      :best_ask,
      :spread,
      :timestamp,
      :event_type
    ])
  end

  @doc """
  Create a `BestBidAskEvent` from the given map of attributes. Returns an error
  if the attributes are not valid.
  """
  @spec from_attrs(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def from_attrs(attrs) do
    %BestBidAskEvent{}
    |> changeset(attrs)
    |> case do
      %{valid?: true} = changeset ->
        {:ok, apply_changes(changeset)}

      changeset ->
        {:error, changeset}
    end
  end
end
