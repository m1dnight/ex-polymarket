defmodule Polymarket.GeoblockTest do
  use ExUnit.Case, async: true

  alias Polymarket.Geoblock
  alias Polymarket.Schemas.Geoblock, as: GeoblockSchema

  # Kept as string-keyed maps so Req.Test can re-encode them as the API would.
  # Expectations are derived from them.
  @fixtures "test/fixtures/geoblock.txt"
            |> File.read!()
            |> String.split("\n", trim: true)
            |> Enum.map(&Jason.decode!/1)

  @allowed Enum.find(@fixtures, &(&1["blocked"] == false))
  @blocked Enum.find(@fixtures, &(&1["blocked"] == true))

  describe "get_geoblock/0" do
    test "requests /api/geoblock and parses an allowed response" do
      Req.Test.stub(Polymarket.Geoblock, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/api/geoblock"
        Req.Test.json(conn, @allowed)
      end)

      assert {:ok, %GeoblockSchema{} = result} = Geoblock.get_geoblock()
      refute result.blocked
      assert result.ip == @allowed["ip"]
      assert result.country == @allowed["country"]
      assert result.region == @allowed["region"]
    end

    test "parses a blocked response" do
      Req.Test.stub(Polymarket.Geoblock, fn conn ->
        Req.Test.json(conn, @blocked)
      end)

      assert {:ok, %GeoblockSchema{} = result} = Geoblock.get_geoblock()
      assert result.blocked
      assert result.ip == @blocked["ip"]
      assert result.country == @blocked["country"]
      assert result.region == @blocked["region"]
    end

    test "returns an error on a non-200 response" do
      Req.Test.stub(Polymarket.Geoblock, fn conn ->
        Plug.Conn.send_resp(conn, 403, ~s({"error":"forbidden"}))
      end)

      assert {:error, :get_geoblock_failed} = Geoblock.get_geoblock()
    end

    test "returns an error when the body is missing the blocked flag" do
      Req.Test.stub(Polymarket.Geoblock, fn conn ->
        Req.Test.json(conn, %{"ip" => "1.2.3.4", "country" => "IE", "region" => "L"})
      end)

      assert {:error, :get_geoblock_failed} = Geoblock.get_geoblock()
    end
  end
end
