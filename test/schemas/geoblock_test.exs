defmodule Polymarket.Schemas.GeoblockTest do
  use ExUnit.Case, async: true

  alias Polymarket.Schemas.Geoblock

  @fixtures "test/fixtures/geoblock.txt"
            |> File.read!()
            |> String.trim()
            |> String.split("\n", trim: true)
            |> Enum.map(&Jason.decode!(&1, keys: :atoms))

  test "every fixture parses into a Geoblock" do
    for fixture <- @fixtures do
      assert {:ok, %Geoblock{}} = Geoblock.from_attrs(fixture)
    end
  end

  @doc """
  Each fixture key (after camelCase -> snake_case normalisation) must map to a
  field on the schema, so we never silently drop a field from the endpoint.
  """
  test "the schema is complete" do
    schema_keys = Geoblock.__schema__(:fields) |> MapSet.new()

    for fixture <- @fixtures do
      fixture_keys =
        fixture
        |> Polymarket.JsonUtil.snake_case_keys()
        |> Map.keys()
        |> MapSet.new(&String.to_atom/1)

      assert MapSet.difference(fixture_keys, schema_keys) == MapSet.new()
    end
  end

  test "requires the blocked flag" do
    assert {:error, changeset} = Geoblock.from_attrs(%{"ip" => "1.2.3.4"})
    refute changeset.valid?
  end
end
