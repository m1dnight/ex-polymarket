defmodule Polymarket.Schemas.MarketResolvedEvent do
  @moduledoc """
  Market resolved event. Announces that a market has settled, naming the
  winning asset and its outcome.
  """

  use TypedEctoSchema

  import Ecto.Changeset

  alias Polymarket.Schemas.EventMessage
  alias Polymarket.Schemas.MarketResolvedEvent

  @primary_key false

  typed_embedded_schema do
    field(:id, :string)
    field(:market, :string)
    field(:assets_ids, {:array, :string})
    field(:winning_asset_id, :string)
    # Free-form outcome label, e.g. "Yes", "No", "Over", or a team name.
    field(:winning_outcome, :string)
    field(:tags, {:array, :string})
    # Unix epoch in milliseconds, delivered as a string (e.g. "1782494011246").
    field(:timestamp, :integer)
    field(:event_type, :string)

    embeds_one(:event_message, EventMessage)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :id,
      :market,
      :assets_ids,
      :winning_asset_id,
      :winning_outcome,
      :tags,
      :timestamp,
      :event_type
    ])
    |> validate_required([
      :id,
      :market,
      :winning_asset_id,
      :winning_outcome,
      :timestamp,
      :event_type
    ])
    |> cast_embed(:event_message)
  end

  @doc """
  Create a `MarketResolvedEvent` from the given map of attributes. Returns an error
  if the attributes are not valid.
  """
  @spec from_attrs(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def from_attrs(attrs) do
    %MarketResolvedEvent{}
    |> changeset(attrs)
    |> case do
      %{valid?: true} = changeset ->
        {:ok, apply_changes(changeset)}

      changeset ->
        {:error, changeset}
    end
  end
end
