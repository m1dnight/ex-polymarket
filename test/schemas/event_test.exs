defmodule Polymarket.Schemas.EventTest do
  use ExUnit.Case, async: true

  alias Polymarket.Schemas.Event
  alias Polymarket.Schemas.EventMetadata
  alias Polymarket.Schemas.Market
  alias Polymarket.Schemas.Series
  alias Polymarket.Schemas.Tag

  # The keyset endpoint (`GET /events/keyset`) wraps its events in an `events`
  # array; the single-event endpoints (`GET /events/:id`, `/events/slug/:slug`)
  # return one event per line in a JSONL fixture. Their shapes differ (e.g. only
  # the single-event payload carries the event-level `negRisk` flag), so the
  # completeness check folds in both.
  @keyset_fixtures "test/fixtures/gamma/events_keyset.txt"
                   |> File.read!()
                   |> Jason.decode!(keys: :atoms)
                   |> Map.fetch!(:events)

  @single_fixtures "test/fixtures/gamma/events.txt"
                   |> File.read!()
                   |> String.split("\n", trim: true)
                   |> Enum.map(&Jason.decode!(&1, keys: :atoms))

  @fixtures @keyset_fixtures ++ @single_fixtures

  test "every fixture parses into an Event" do
    for fixture <- @fixtures do
      assert {:ok, %Event{}} = Event.from_attrs(fixture)
    end
  end

  @doc """
  Each fixture key (after camelCase -> snake_case normalisation) must map to a
  field on the schema, recursively for the nested relations. This guarantees we
  never silently drop a field coming from the Gamma API.
  """
  test "schemas are complete" do
    event_keys = Event.__schema__(:fields) |> MapSet.new()
    market_keys = Market.__schema__(:fields) |> MapSet.new()
    series_keys = Series.__schema__(:fields) |> MapSet.new()
    tag_keys = Tag.__schema__(:fields) |> MapSet.new()
    metadata_keys = EventMetadata.__schema__(:fields) |> MapSet.new()

    for fixture <- @fixtures do
      normalized = Polymarket.JsonUtil.snake_case_keys(fixture)

      assert_subset(normalized, event_keys)

      for market <- normalized["markets"] || [], do: assert_subset(market, market_keys)
      for series <- normalized["series"] || [], do: assert_subset(series, series_keys)
      for tag <- normalized["tags"] || [], do: assert_subset(tag, tag_keys)

      if metadata = normalized["event_metadata"], do: assert_subset(metadata, metadata_keys)
    end
  end

  test "parses nested relations and dates" do
    fixture =
      Enum.find(
        @fixtures,
        &(&1.slug == "nba-will-the-mavericks-beat-the-grizzlies-by-more-than-5pt5-points-in-their-december-4-matchup")
      )

    {:ok, event} = Event.from_attrs(fixture)

    assert event.id == "2890"
    assert is_float(event.volume)
    assert %DateTime{} = event.created_at
    assert [%Market{} | _] = event.markets
    assert [%Series{} | _] = event.series
    assert [%Tag{} | _] = event.tags
    assert %EventMetadata{} = event.event_metadata
  end

  # Keys we deliberately don't map:
  #   * `$schema` — a JSON-Schema self-reference URL the single-event endpoint
  #     tacks onto every object; metadata, not domain data.
  #   * `event_creators` — a relational object the single-event endpoint returns
  #     but the keyset endpoint omits; intentionally not modelled (see Event docs).
  @ignored_keys MapSet.new([:"$schema", :event_creators])

  @spec assert_subset(map(), MapSet.t()) :: true
  defp assert_subset(map, schema_keys) do
    fixture_keys =
      map |> Map.keys() |> MapSet.new(&String.to_atom/1) |> MapSet.difference(@ignored_keys)

    assert MapSet.difference(fixture_keys, schema_keys) == MapSet.new()
  end
end
