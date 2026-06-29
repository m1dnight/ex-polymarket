defmodule Polymarket.ClobTest do
  use ExUnit.Case, async: true

  alias Polymarket.Clob
  alias Polymarket.Schemas.MarketByToken

  # First entry in the fixtures, kept as a string-keyed map so Req.Test can
  # re-encode it as the API would. Expectations are derived from it.
  @attrs "test/fixtures/gamma/market_ids.txt"
         |> File.read!()
         |> String.split("\n", trim: true)
         |> hd()
         |> Jason.decode!()

  @token_id @attrs["primary_token_id"]

  describe "get_market_by_token/1" do
    test "requests the right URL and parses the market on a 200 response" do
      Req.Test.stub(Polymarket.Clob, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/markets-by-token/#{@token_id}"
        Req.Test.json(conn, @attrs)
      end)

      assert {:ok, %MarketByToken{} = market} = Clob.get_market_by_token(@token_id)
      assert market.condition_id == @attrs["condition_id"]
      assert market.primary_token_id == @attrs["primary_token_id"]
      assert market.secondary_token_id == @attrs["secondary_token_id"]
    end

    test "returns an error on a non-200 response" do
      Req.Test.stub(Polymarket.Clob, fn conn ->
        Plug.Conn.send_resp(conn, 404, ~s({"error":"market not found"}))
      end)

      assert {:error, :get_market_by_token_failed} = Clob.get_market_by_token("does-not-exist")
    end

    test "returns an error when the payload is missing required fields" do
      Req.Test.stub(Polymarket.Clob, fn conn ->
        Req.Test.json(conn, %{"condition_id" => "0xabc"})
      end)

      assert {:error, :get_market_by_token_failed} = Clob.get_market_by_token(@token_id)
    end
  end

  describe "get_server_time/0" do
    test "requests /time and parses the string timestamp on a 200 response" do
      Req.Test.stub(Polymarket.Clob, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/time"
        Req.Test.json(conn, "1234567890")
      end)

      assert {:ok, 1_234_567_890} = Clob.get_server_time()
    end

    test "also accepts a bare integer timestamp" do
      Req.Test.stub(Polymarket.Clob, fn conn ->
        Req.Test.json(conn, 1_234_567_890)
      end)

      assert {:ok, 1_234_567_890} = Clob.get_server_time()
    end

    test "returns an error on a non-200 response" do
      Req.Test.stub(Polymarket.Clob, fn conn ->
        Plug.Conn.send_resp(conn, 400, ~s({"error":"bad request"}))
      end)

      assert {:error, :get_server_time_failed} = Clob.get_server_time()
    end

    test "returns an error when the body is not a numeric timestamp" do
      Req.Test.stub(Polymarket.Clob, fn conn ->
        Req.Test.json(conn, "not-a-number")
      end)

      assert {:error, :get_server_time_failed} = Clob.get_server_time()
    end

    test "returns an error when the body is an object" do
      Req.Test.stub(Polymarket.Clob, fn conn ->
        Req.Test.json(conn, %{"time" => 1_234_567_890})
      end)

      assert {:error, :get_server_time_failed} = Clob.get_server_time()
    end
  end

  describe "get_server_time_utc/0" do
    test "returns the server time as a UTC DateTime" do
      Req.Test.stub(Polymarket.Clob, fn conn ->
        assert conn.request_path == "/time"
        Req.Test.json(conn, "1234567890")
      end)

      assert {:ok, %DateTime{} = datetime} = Clob.get_server_time_utc()
      assert datetime == ~U[2009-02-13 23:31:30Z]
      assert datetime.time_zone == "Etc/UTC"
    end

    test "propagates the error when the request fails" do
      Req.Test.stub(Polymarket.Clob, fn conn ->
        Plug.Conn.send_resp(conn, 400, ~s({"error":"bad request"}))
      end)

      assert {:error, :get_server_time_failed} = Clob.get_server_time_utc()
    end
  end
end
