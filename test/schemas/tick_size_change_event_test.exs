defmodule Polymarket.Schemas.TickSizeChangeEventTest do
  use ExUnit.Case, async: true

  alias Polymarket.Schemas.TickSizeChangeEvent

  @fixtures File.read!("test/fixtures/websocket_events/tick_size_change_events.txt")
            |> String.trim()
            |> String.split("\n", trim: true)
            |> Enum.map(&Jason.decode!(&1, keys: :atoms))

  @doc """
  The raw events are parsed, and the keys from the schema must match the ones from the event struct.
  This test assures that we dont miss any events coming from the websocket.
  """
  test "schemas are complete" do
    for fixture <- @fixtures do
      {:ok, event} = TickSizeChangeEvent.from_attrs(fixture)

      event_keys = Map.from_struct(event) |> Map.keys()
      fixture_keys = Map.keys(fixture)
      assert Enum.sort(event_keys) == Enum.sort(fixture_keys)
    end
  end
end
