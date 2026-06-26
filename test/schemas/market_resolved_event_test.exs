defmodule Polymarket.Schemas.MarketResolvedEventTest do
  use ExUnit.Case, async: true

  alias Polymarket.Schemas.EventMessage
  alias Polymarket.Schemas.MarketResolvedEvent

  @fixtures File.read!("test/fixtures/websocket_events/market_resolved_events.txt")
            |> String.trim()
            |> String.split("\n", trim: true)
            |> Enum.map(&Jason.decode!(&1, keys: :atoms))

  @doc """
  The raw events are parsed, and the keys from the schema must match the ones from the event struct.
  This test assures that we dont miss any events coming from the websocket.
  """
  test "schemas are complete" do
    for fixture <- @fixtures do
      {:ok, event} = MarketResolvedEvent.from_attrs(fixture)
      event = Map.from_struct(event)

      # assert top level fields
      event_keys = event |> Map.keys() |> MapSet.new()
      fixture_keys = Map.keys(fixture) |> MapSet.new()
      assert MapSet.difference(fixture_keys, event_keys) == MapSet.new()

      # assert event message fields
      if event_message_fixture = fixture[:event_message] do
        event_message_keys = EventMessage.__schema__(:fields) |> MapSet.new()
        fixture_keys = Map.keys(event_message_fixture) |> MapSet.new()
        assert MapSet.difference(fixture_keys, event_message_keys) == MapSet.new()
      end
    end
  end
end
