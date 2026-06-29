defmodule Polymarket.Schemas.Event do
  @moduledoc """
  An event returned by the Gamma REST API (e.g. `GET /events/keyset`).

  An event groups one or more `Polymarket.Schemas.Market`s under a single
  question/title (e.g. an NBA game with its various betting markets). The Gamma
  API delivers its keys in `camelCase`; `from_attrs/1` normalises them to the
  `snake_case` fields below.

  The `markets`, `series`, `tags`, and `event_metadata` relations are always
  returned by the keyset endpoint and are parsed into their respective schemas.
  Field coverage follows what the keyset endpoint returns; the remaining nested
  relational objects documented in the OpenAPI spec (`collections`,
  `eventCreators`, `chats`, `templates`, `imageOptimized`, ...) are intentionally
  omitted as the keyset endpoint does not return them.
  """

  use TypedEctoSchema

  import Ecto.Changeset

  alias Polymarket.JsonUtil
  alias Polymarket.Schemas.Event
  alias Polymarket.Schemas.EventMetadata
  alias Polymarket.Schemas.Market
  alias Polymarket.Schemas.Series
  alias Polymarket.Schemas.Tag

  @primary_key false

  typed_embedded_schema do
    # Identity / description
    field(:id, :string)
    field(:ticker, :string)
    field(:slug, :string)
    field(:title, :string)
    field(:description, :string)
    field(:resolution_source, :string)
    field(:category, :string)
    field(:subcategory, :string)
    field(:series_slug, :string)
    field(:sort_by, :string)
    field(:image, :string)
    field(:icon, :string)
    field(:updated_by, :string)

    # Status flags
    field(:active, :boolean)
    field(:closed, :boolean)
    field(:archived, :boolean)
    field(:new, :boolean)
    field(:featured, :boolean)
    field(:restricted, :boolean)
    field(:cyom, :boolean)
    field(:deploying, :boolean)
    field(:pending_deployment, :boolean)
    field(:comments_enabled, :boolean)
    field(:enable_neg_risk, :boolean)
    field(:neg_risk_augmented, :boolean)
    field(:requires_translation, :boolean)
    field(:show_all_outcomes, :boolean)
    field(:show_market_images, :boolean)

    # Counts / volume / liquidity
    field(:comment_count, :integer)
    field(:competitive, :float)
    field(:liquidity, :float)
    field(:liquidity_amm, :float)
    field(:liquidity_clob, :float)
    field(:open_interest, :float)
    field(:volume, :float)
    field(:volume24hr, :float)
    field(:volume1wk, :float)
    field(:volume1mo, :float)
    field(:volume1yr, :float)

    # Dates
    field(:start_date, :utc_datetime_usec)
    field(:end_date, :utc_datetime_usec)
    field(:creation_date, :utc_datetime_usec)
    field(:created_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
    field(:closed_time, :utc_datetime_usec)
    field(:published_at, :utc_datetime_usec)

    embeds_one(:event_metadata, EventMetadata)
    embeds_many(:markets, Market)
    embeds_many(:series, Series)
    embeds_many(:tags, Tag)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(event, attrs) do
    castable = __MODULE__.__schema__(:fields) -- __MODULE__.__schema__(:embeds)

    event
    |> cast(attrs, castable)
    |> validate_required([:id, :slug])
    |> cast_embed(:event_metadata)
    |> cast_embed(:markets)
    |> cast_embed(:series)
    |> cast_embed(:tags)
  end

  @doc """
  Create an `Event` from the raw (JSON-decoded) attributes returned by the Gamma
  API. Keys may be in `camelCase` (atom or string); they are normalised to the
  `snake_case` schema fields. Returns an error if the attributes are not valid.
  """
  @spec from_attrs(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def from_attrs(attrs) do
    attrs
    |> JsonUtil.snake_case_keys()
    |> then(&changeset(%Event{}, &1))
    |> case do
      %{valid?: true} = changeset ->
        {:ok, apply_changes(changeset)}

      changeset ->
        {:error, changeset}
    end
  end
end
