defmodule Polymarket.Schemas.TagTest do
  use ExUnit.Case, async: true

  alias Polymarket.Schemas.Tag

  # The fixture has one JSON array of tags per line (the shape returned by
  # `GET /markets/:id/tags`); flatten them into a single list of tag maps.
  @fixtures "test/fixtures/gamma/tags.txt"
            |> File.read!()
            |> String.trim()
            |> String.split("\n", trim: true)
            |> Enum.flat_map(&Jason.decode!(&1, keys: :atoms))

  test "every fixture tag parses into a Tag" do
    for fixture <- @fixtures do
      assert {:ok, %Tag{}} = Tag.from_attrs(fixture)
    end
  end

  @doc """
  Each fixture key (after camelCase -> snake_case normalisation) must map to a
  field on the schema, so we never silently drop a field from the Gamma API.
  """
  test "the Tag schema is complete" do
    tag_keys = Tag.__schema__(:fields) |> MapSet.new()

    for fixture <- @fixtures do
      fixture_keys =
        fixture
        |> Polymarket.JsonUtil.snake_case_keys()
        |> Map.keys()
        |> MapSet.new(&String.to_atom/1)

      assert MapSet.difference(fixture_keys, tag_keys) == MapSet.new()
    end
  end

  test "parses tag dates" do
    {:ok, tag} = Tag.from_attrs(hd(@fixtures))

    assert %DateTime{} = tag.created_at
    assert %DateTime{} = tag.updated_at
  end
end
