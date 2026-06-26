defmodule Polymarket.Schemas.NewMarketEvent do
  @moduledoc """
  New market event. Announces a freshly created market on the websocket feed.
  """

  use TypedEctoSchema

  import Ecto.Changeset

  alias Polymarket.Schemas.EventMessage
  alias Polymarket.Schemas.FeeSchedule
  alias Polymarket.Schemas.NewMarketEvent

  @primary_key false

  typed_embedded_schema do
    field(:id, :string)
    field(:active, :boolean)
    field(:line, :string)
    field(:description, :string)
    field(:question, :string)
    field(:market, :string)
    field(:condition_id, :string)
    field(:slug, :string)
    # Assumed to be an array of tag strings; only seen empty so far.
    field(:tags, {:array, :string})
    field(:clob_token_ids, {:array, :string})
    field(:assets_ids, {:array, :string})
    field(:outcomes, {:array, :string})
    field(:taker_base_fee, :integer)
    field(:order_price_min_tick_size, :float)
    field(:fees_enabled, :boolean)
    field(:group_item_title, :string)
    # Empty string in samples; kept as a string since the populated format is
    # unknown (Gamma models the equivalent field as a datetime).
    field(:game_start_time, :string)
    field(:sports_market_type, :string)
    # Unix epoch in milliseconds, delivered as a string (e.g. "1779660930454").
    field(:timestamp, :integer)
    field(:event_type, :string)

    embeds_one(:fee_schedule, FeeSchedule)
    embeds_one(:event_message, EventMessage)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :id,
      :active,
      :line,
      :description,
      :question,
      :market,
      :condition_id,
      :slug,
      :tags,
      :clob_token_ids,
      :assets_ids,
      :outcomes,
      :taker_base_fee,
      :order_price_min_tick_size,
      :fees_enabled,
      :group_item_title,
      :game_start_time,
      :sports_market_type,
      :timestamp,
      :event_type
    ])
    |> validate_required([:id, :market, :condition_id, :timestamp, :event_type])
    |> cast_embed(:fee_schedule)
    |> cast_embed(:event_message)
  end

  @doc """
  Create a `NewMarketEvent` from the given map of attributes. Returns an error
  if the attributes are not valid.
  """
  @spec from_attrs(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def from_attrs(attrs) do
    %NewMarketEvent{}
    |> changeset(attrs)
    |> case do
      %{valid?: true} = changeset ->
        {:ok, apply_changes(changeset)}

      changeset ->
        {:error, changeset}
    end
  end
end
