defmodule Polymarket.Schemas.MarketTest do
  use ExUnit.Case, async: true

  alias Polymarket.Schemas.FeeSchedule
  alias Polymarket.Schemas.Market
  alias Polymarket.Schemas.MarketMetadata
  alias Polymarket.Schemas.Tag

  @fixtures File.read!("test/fixtures/gamma/markets.txt")
            |> String.trim()
            |> String.split("\n", trim: true)
            |> Enum.map(&Jason.decode!(&1, keys: :atoms))

  test "every fixture parses into a Market" do
    for fixture <- @fixtures do
      assert {:ok, %Market{}} = Market.from_attrs(fixture)
    end
  end

  @doc """
  Each fixture key (after camelCase -> snake_case normalisation) must map to a
  field on the schema. This guarantees we never silently drop a field coming from
  the Gamma API.
  """
  test "schemas are complete" do
    for fixture <- @fixtures do
      {:ok, market} = Market.from_attrs(fixture)
      market_keys = market |> Map.from_struct() |> Map.keys() |> MapSet.new()

      normalized = Polymarket.JsonUtil.snake_case_keys(fixture)

      # assert top level fields
      fixture_keys = normalized |> Map.keys() |> MapSet.new(&String.to_atom/1)
      assert MapSet.difference(fixture_keys, market_keys) == MapSet.new()

      # assert fee schedule fields
      if fee_schedule = normalized["fee_schedule"] do
        fee_schedule_keys = FeeSchedule.__schema__(:fields) |> MapSet.new()
        fixture_keys = fee_schedule |> Map.keys() |> MapSet.new(&String.to_atom/1)
        assert MapSet.difference(fixture_keys, fee_schedule_keys) == MapSet.new()
      end

      # assert market metadata fields
      if market_metadata = normalized["market_metadata"] do
        metadata_keys = MarketMetadata.__schema__(:fields) |> MapSet.new()
        fixture_keys = market_metadata |> Map.keys() |> MapSet.new(&String.to_atom/1)
        assert MapSet.difference(fixture_keys, metadata_keys) == MapSet.new()
      end

      # assert tag fields
      tag_keys = Tag.__schema__(:fields) |> MapSet.new()

      for tag <- normalized["tags"] || [] do
        fixture_keys = tag |> Map.keys() |> MapSet.new(&String.to_atom/1)
        assert MapSet.difference(fixture_keys, tag_keys) == MapSet.new()
      end
    end
  end

  test "decodes JSON-encoded array fields and parses dates" do
    fixture = Enum.find(@fixtures, &(&1.slug == "sol-updown-5m-1782566100"))
    {:ok, market} = Market.from_attrs(fixture)

    assert market.outcomes == ["Up", "Down"]
    assert market.outcome_prices == [0.505, 0.495]
    assert [token_id | _] = market.clob_token_ids
    assert is_binary(token_id)
    assert %DateTime{} = market.end_date
    assert %Date{} = market.end_date_iso
    assert %FeeSchedule{taker_only: true} = market.fee_schedule
  end
end
