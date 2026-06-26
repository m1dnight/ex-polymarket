defmodule Polymarket.Schemas.PriceChangeEventTest do
  use ExUnit.Case, async: true

  alias Polymarket.Schemas.PriceChange
  alias Polymarket.Schemas.PriceChangeEvent

  @fixtures File.read!("test/fixtures/websocket_events/price_change_event.txt")
            |> String.trim()
            |> String.split("\n", trim: true)
            |> Enum.map(&Jason.decode!(&1, keys: :atoms))

  @doc """
  The raw events are parsed, and the keys from the schema must match the ones from the event struct.
  This test assures that we dont miss any events coming from the websocket.
  """
  test "schemas are complete" do
    for fixture <- @fixtures do
      {:ok, event} = PriceChangeEvent.from_attrs(fixture)
      event = Map.from_struct(event)

      # assert top level fields
      event_keys = event |> Map.keys() |> MapSet.new()
      fixture_keys = Map.keys(fixture) |> MapSet.new()
      assert MapSet.difference(fixture_keys, event_keys) == MapSet.new()

      # assert price change fields
      for price_change_fixture <- fixture.price_changes do
        price_change_keys = PriceChange.__schema__(:fields) |> MapSet.new()
        fixture_keys = Map.keys(price_change_fixture) |> MapSet.new()
        assert MapSet.difference(fixture_keys, price_change_keys) == MapSet.new()
      end
    end
  end
end
