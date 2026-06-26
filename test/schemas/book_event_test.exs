defmodule Polymarket.Schemas.BookEventTest do
  use ExUnit.Case, async: true

  alias Polymarket.Schemas.Ask
  alias Polymarket.Schemas.Bid
  alias Polymarket.Schemas.BookEvent

  @fixtures File.read!("test/fixtures/websocket_events/book_events.txt")
            |> String.trim()
            |> String.split("\n")
            |> Enum.map(&Jason.decode!(&1, keys: :atoms))
            |> List.flatten()

  @doc """
  The raw events are parsed, and the keys from the schema must match the ones from the event struct.
  This test assures that we dont miss any events coming from the websocket.
  """
  test "schemas are complete" do
    for fixture <- @fixtures do
      {:ok, event} = BookEvent.from_attrs(fixture)
      event = Map.from_struct(event)

      # asser top level fields
      event_keys = event |> Map.keys() |> MapSet.new()
      fixture_keys = Map.keys(fixture) |> MapSet.new()
      assert MapSet.difference(fixture_keys, event_keys) == MapSet.new()

      # assert bid fields
      for bid_fixture <- fixture.bids do
        bid_keys = Bid.__schema__(:fields) |> MapSet.new()
        fixture_keys = Map.keys(bid_fixture) |> MapSet.new()
        assert MapSet.difference(fixture_keys, bid_keys) == MapSet.new()
      end

      # assert ask fields
      for ask_fixture <- fixture.asks do
        ask_keys = Ask.__schema__(:fields) |> MapSet.new()
        fixture_keys = Map.keys(ask_fixture) |> MapSet.new()
        assert MapSet.difference(fixture_keys, ask_keys) == MapSet.new()
      end
    end
  end
end
