defmodule Polymarket.GammaTest do
  use ExUnit.Case, async: true

  alias Polymarket.Gamma
  alias Polymarket.Schemas.FeeSchedule
  alias Polymarket.Schemas.Market
  alias Polymarket.Schemas.Tag

  # First market in the fixtures, kept as a (camelCase, string-keyed) map so
  # Req.Test can re-encode it as the API would. Expectations are derived from it
  # rather than hard-coded, so refreshing the fixtures can't stale the test.
  @market_attrs "test/fixtures/gamma/markets.txt"
                |> File.read!()
                |> String.split("\n", trim: true)
                |> hd()
                |> Jason.decode!()

  @market_id @market_attrs["id"]
  @market_slug @market_attrs["slug"]

  describe "get_market_by_id/1" do
    test "requests the right URL and parses the market on a 200 response" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/markets/#{@market_id}"
        Req.Test.json(conn, @market_attrs)
      end)

      assert {:ok, %Market{} = market} = Gamma.get_market_by_id(@market_id)
      assert market.id == @market_id
      assert market.slug == @market_attrs["slug"]
      assert market.outcomes == Jason.decode!(@market_attrs["outcomes"])
      assert Enum.all?(market.outcome_prices, &is_float/1)
      assert %DateTime{} = market.end_date
      assert %FeeSchedule{} = market.fee_schedule
      assert [%Tag{} | _] = market.tags
    end

    test "forwards query options like include_tag to the request" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        assert URI.decode_query(conn.query_string) == %{"include_tag" => "true"}
        Req.Test.json(conn, @market_attrs)
      end)

      assert {:ok, %Market{}} = Gamma.get_market_by_id(@market_id, include_tag: true)
    end

    test "sends no query string when no options are given" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        assert conn.query_string == ""
        Req.Test.json(conn, @market_attrs)
      end)

      assert {:ok, %Market{}} = Gamma.get_market_by_id(@market_id)
    end

    test "accepts an integer id" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        assert conn.request_path == "/markets/#{@market_id}"
        Req.Test.json(conn, @market_attrs)
      end)

      assert {:ok, %Market{}} = Gamma.get_market_by_id(String.to_integer(@market_id))
    end

    test "returns an error on a non-200 response" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        Plug.Conn.send_resp(conn, 404, "Not Found")
      end)

      assert {:error, :get_market_failed} = Gamma.get_market_by_id("does-not-exist")
    end

    test "returns an error when the payload is not a valid market" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        Req.Test.json(conn, %{"unexpected" => "shape"})
      end)

      assert {:error, :get_market_failed} = Gamma.get_market_by_id(@market_id)
    end
  end

  describe "get_market_by_slug/1" do
    test "requests the right URL and parses the market on a 200 response" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/markets/slug/#{@market_slug}"
        Req.Test.json(conn, @market_attrs)
      end)

      assert {:ok, %Market{} = market} = Gamma.get_market_by_slug(@market_slug)
      assert market.id == @market_id
      assert market.slug == @market_slug
      assert market.outcomes == Jason.decode!(@market_attrs["outcomes"])
      assert Enum.all?(market.outcome_prices, &is_float/1)
      assert %DateTime{} = market.end_date
      assert %FeeSchedule{} = market.fee_schedule
      assert [%Tag{} | _] = market.tags
    end

    test "forwards query options like include_tag to the request" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        assert conn.request_path == "/markets/slug/#{@market_slug}"
        assert URI.decode_query(conn.query_string) == %{"include_tag" => "true"}
        Req.Test.json(conn, @market_attrs)
      end)

      assert {:ok, %Market{}} = Gamma.get_market_by_slug(@market_slug, include_tag: true)
    end

    test "sends no query string when no options are given" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        assert conn.query_string == ""
        Req.Test.json(conn, @market_attrs)
      end)

      assert {:ok, %Market{}} = Gamma.get_market_by_slug(@market_slug)
    end

    test "returns an error on a non-200 response" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        Plug.Conn.send_resp(conn, 404, "Not Found")
      end)

      assert {:error, :get_market_failed} = Gamma.get_market_by_slug("does-not-exist")
    end

    test "returns an error when the payload is not a valid market" do
      Req.Test.stub(Polymarket.Gamma, fn conn ->
        Req.Test.json(conn, %{"unexpected" => "shape"})
      end)

      assert {:error, :get_market_failed} = Gamma.get_market_by_slug(@market_slug)
    end
  end
end
