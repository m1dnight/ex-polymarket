defmodule Polymarket.Schemas.Market do
  @moduledoc """
  A market returned by the Gamma REST API (e.g. `GET /markets/:id`).

  The Gamma API delivers its keys in `camelCase`; `from_attrs/1` normalises them
  to the `snake_case` fields below. A handful of fields are delivered as
  JSON-encoded strings (e.g. `outcomes` arrives as `"[\\"Up\\", \\"Down\\"]"`);
  these use the `Polymarket.JsonUtil.JsonStringArray` and
  `Polymarket.JsonUtil.JsonFloatArray` Ecto types, which decode them on cast.

  Field coverage follows the Gamma OpenAPI `Market` schema. The remaining nested
  relational objects (`events`, `categories`, `imageOptimized`, `iconOptimized`)
  are intentionally omitted: `GET /markets/:id` does not return them, and
  `events` is a large, self-referential `Market` <-> `Event` graph.
  """

  use TypedEctoSchema

  import Ecto.Changeset

  alias Polymarket.JsonUtil
  alias Polymarket.JsonUtil.JsonFloatArray
  alias Polymarket.JsonUtil.JsonStringArray
  alias Polymarket.Schemas.FeeSchedule
  alias Polymarket.Schemas.Market
  alias Polymarket.Schemas.MarketMetadata
  alias Polymarket.Schemas.Tag

  @primary_key false

  typed_embedded_schema do
    # Identity / description
    field(:id, :string)
    field(:question, :string)
    field(:question_id, :string)
    field(:condition_id, :string)
    field(:slug, :string)
    field(:description, :string)
    field(:resolution_source, :string)
    field(:image, :string)
    field(:icon, :string)
    field(:market_maker_address, :string)
    field(:submitted_by, :string)
    field(:resolved_by, :string)
    field(:creator, :string)
    field(:created_by, :integer)
    field(:updated_by, :integer)
    field(:category, :string)
    field(:subcategory, :string)
    field(:market_type, :string)
    field(:format_type, :string)
    field(:market_group, :integer)
    field(:curation_order, :integer)
    field(:score, :integer)
    field(:twitter_card_image, :string)
    field(:twitter_card_location, :string)
    field(:twitter_card_last_refreshed, :string)
    field(:twitter_card_last_validated, :string)
    field(:sponsor_name, :string)
    field(:sponsor_image, :string)
    field(:chart_color, :string)
    field(:series_color, :string)
    field(:mailchimp_tag, :string)
    field(:category_mailchimp_tag, :string)
    field(:disqus_thread, :string)
    field(:past_slugs, :string)
    field(:game_id, :string)
    field(:team_aid, :string)
    field(:team_bid, :string)
    field(:group_item_range, :string)

    # Scalar / range markets
    field(:amm_type, :string)
    field(:fee, :string)
    field(:denomination_token, :string)
    field(:lower_bound, :string)
    field(:upper_bound, :string)
    field(:lower_bound_date, :string)
    field(:upper_bound_date, :string)
    field(:x_axis_value, :string)
    field(:y_axis_value, :string)

    # Status flags
    field(:active, :boolean)
    field(:closed, :boolean)
    field(:archived, :boolean)
    field(:new, :boolean)
    field(:featured, :boolean)
    field(:restricted, :boolean)
    field(:ready, :boolean)
    field(:funded, :boolean)
    field(:approved, :boolean)
    field(:cyom, :boolean)
    field(:deploying, :boolean)
    field(:pending_deployment, :boolean)
    field(:automatically_active, :boolean)
    field(:automatically_resolved, :boolean)
    field(:manual_activation, :boolean)
    field(:accepting_orders, :boolean)
    field(:enable_order_book, :boolean)
    field(:clear_book_on_start, :boolean)
    field(:has_reviewed_dates, :boolean)
    field(:fees_enabled, :boolean)
    field(:holding_rewards_enabled, :boolean)
    field(:rfq_enabled, :boolean)
    field(:requires_translation, :boolean)
    field(:pager_duty_notification_enabled, :boolean)
    field(:neg_risk, :boolean)
    field(:neg_risk_other, :boolean)
    field(:show_gmp_series, :boolean)
    field(:show_gmp_outcome, :boolean)
    field(:wide_format, :boolean)
    field(:ready_for_cron, :boolean)
    field(:comments_enabled, :boolean)
    field(:notifications_enabled, :boolean)
    field(:sent_discord, :boolean)
    field(:fpmm_live, :boolean)

    # Dates
    field(:start_date, :utc_datetime_usec)
    field(:end_date, :utc_datetime_usec)
    field(:start_date_iso, :date)
    field(:end_date_iso, :date)
    field(:created_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
    field(:closed_time, :utc_datetime_usec)
    field(:accepting_orders_timestamp, :utc_datetime_usec)
    field(:deploying_timestamp, :utc_datetime_usec)
    field(:event_start_time, :utc_datetime_usec)
    field(:game_start_time, :utc_datetime_usec)
    field(:ready_timestamp, :utc_datetime_usec)
    field(:funded_timestamp, :utc_datetime_usec)
    field(:scheduled_deployment_timestamp, :utc_datetime_usec)
    # The spec types both of these as plain strings (no `date-time` format).
    # `GET /markets` returns ISO timestamps for `uma_end_date`, but the events
    # endpoint returns free-form dates (e.g. "April 25, 2022") for older markets,
    # so it is kept a string. The `*_iso` fields, by contrast, the fixtures prove
    # are dates.
    field(:uma_end_date, :string)
    field(:uma_end_date_iso, :string)

    # Pricing / order book state
    field(:best_bid, :float)
    field(:best_ask, :float)
    field(:spread, :float)
    field(:last_trade_price, :float)
    field(:one_hour_price_change, :float)
    field(:one_day_price_change, :float)
    field(:one_week_price_change, :float)
    field(:one_month_price_change, :float)
    field(:one_year_price_change, :float)
    field(:competitive, :float)
    field(:line, :float)

    # Order configuration
    field(:order_min_size, :integer)
    field(:order_price_min_tick_size, :float)
    field(:combo_status, :string)
    field(:custom_liveness, :integer)
    field(:seconds_delay, :integer)
    field(:group_item_threshold, :string)
    field(:group_item_title, :string)
    field(:sports_market_type, :string)

    # Liquidity / volume (the `*_num`/`*_clob` variants are numeric; the bare
    # `liquidity`/`volume` fields arrive as strings and are kept verbatim).
    field(:liquidity, :string)
    field(:liquidity_num, :float)
    field(:liquidity_amm, :float)
    field(:liquidity_clob, :float)
    field(:volume, :string)
    field(:volume_num, :float)
    field(:volume_clob, :float)
    field(:volume24hr, :float)
    field(:volume24hr_clob, :float)
    field(:volume1wk, :float)
    field(:volume1wk_clob, :float)
    field(:volume1mo, :float)
    field(:volume1mo_clob, :float)
    field(:volume1yr, :float)
    field(:volume1yr_clob, :float)
    field(:volume_amm, :float)
    field(:volume24hr_amm, :float)
    field(:volume1wk_amm, :float)
    field(:volume1mo_amm, :float)
    field(:volume1yr_amm, :float)

    # Fees / rewards
    field(:fee_type, :string)
    field(:maker_base_fee, :integer)
    field(:taker_base_fee, :integer)
    field(:maker_rebates_fee_share_bps, :integer)
    field(:rewards_min_size, :integer)
    field(:rewards_max_spread, :float)

    # UMA resolution
    field(:uma_bond, :string)
    field(:uma_reward, :string)
    field(:uma_resolution_status, :string)
    field(:neg_risk_request_id, :string)

    # Array fields. `outcomes`/`outcome_prices`/`clob_token_ids`/
    # `uma_resolution_statuses` arrive as JSON-encoded strings; `position_ids`
    # arrives as a real array.
    field(:outcomes, JsonStringArray)
    field(:short_outcomes, JsonStringArray)
    field(:outcome_prices, JsonFloatArray)
    field(:clob_token_ids, JsonStringArray)
    field(:uma_resolution_statuses, JsonStringArray)
    field(:position_ids, {:array, :string})

    embeds_one(:fee_schedule, FeeSchedule)
    embeds_one(:market_metadata, MarketMetadata)
    embeds_many(:tags, Tag)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(market, attrs) do
    castable = __MODULE__.__schema__(:fields) -- __MODULE__.__schema__(:embeds)

    market
    |> cast(attrs, castable)
    |> validate_required([:id, :condition_id, :slug])
    |> cast_embed(:fee_schedule)
    |> cast_embed(:market_metadata)
    |> cast_embed(:tags)
  end

  @doc """
  Create a `Market` from the raw (JSON-decoded) attributes returned by the Gamma
  API. Keys may be in `camelCase` (atom or string); they are normalised to the
  `snake_case` schema fields. Returns an error if the attributes are not valid.
  """
  @spec from_attrs(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def from_attrs(attrs) do
    attrs
    |> JsonUtil.snake_case_keys()
    |> then(&changeset(%Market{}, &1))
    |> case do
      %{valid?: true} = changeset ->
        {:ok, apply_changes(changeset)}

      changeset ->
        {:error, changeset}
    end
  end
end
