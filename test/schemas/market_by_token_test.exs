defmodule Polymarket.Schemas.MarketByTokenTest do
  use ExUnit.Case, async: true

  alias Polymarket.Schemas.MarketByToken

  @fixtures "test/fixtures/gamma/market_ids.txt"
            |> File.read!()
            |> String.trim()
            |> String.split("\n", trim: true)
            |> Enum.map(&Jason.decode!(&1, keys: :atoms))

  test "every fixture parses into a MarketByToken" do
    for fixture <- @fixtures do
      assert {:ok, %MarketByToken{}} = MarketByToken.from_attrs(fixture)
    end
  end

  @doc """
  Each fixture key (after camelCase -> snake_case normalisation) must map to a
  field on the schema, so we never silently drop a field from the CLOB API.
  """
  test "the schema is complete" do
    schema_keys = MarketByToken.__schema__(:fields) |> MapSet.new()

    for fixture <- @fixtures do
      fixture_keys =
        fixture
        |> Polymarket.JsonUtil.snake_case_keys()
        |> Map.keys()
        |> MapSet.new(&String.to_atom/1)

      assert MapSet.difference(fixture_keys, schema_keys) == MapSet.new()
    end
  end

  test "requires all token fields" do
    assert {:error, changeset} = MarketByToken.from_attrs(%{"condition_id" => "0xabc"})
    refute changeset.valid?
  end
end
