defmodule Polymarket.Schemas.PriceChangeEvent do
  @moduledoc """
  Price change event.
  """

  use TypedEctoSchema

  import Ecto.Changeset

  alias Polymarket.Schemas.PriceChange
  alias Polymarket.Schemas.PriceChangeEvent

  @primary_key false

  typed_embedded_schema do
    field(:market, :string)
    # Unix epoch in milliseconds, delivered as a string (e.g. "1779656681214").
    field(:timestamp, :integer)
    field(:event_type, :string)

    embeds_many(:price_changes, PriceChange)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:market, :timestamp, :event_type])
    |> validate_required([:market, :timestamp, :event_type])
    |> cast_embed(:price_changes)
  end

  @doc """
  Create a `PriceChangeEvent` from the given map of attributes. Returns an error
  if the attributes are not valid.
  """
  @spec from_attrs(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def from_attrs(attrs) do
    %PriceChangeEvent{}
    |> changeset(attrs)
    |> case do
      %{valid?: true} = changeset ->
        {:ok, apply_changes(changeset)}

      changeset ->
        {:error, changeset}
    end
  end
end
