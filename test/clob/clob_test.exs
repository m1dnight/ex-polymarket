defmodule Polymarket.ClobTest do
  use ExUnit.Case, async: true

  alias Polymarket.Clob
  alias Polymarket.Clob.HmacAuth
  alias Polymarket.Clob.OrderSigner
  alias Polymarket.Schemas.ClobError
  alias Polymarket.Schemas.Credentials
  alias Polymarket.Schemas.MarketByToken
  alias Polymarket.Schemas.Order
  alias Polymarket.Schemas.SendOrder
  alias Polymarket.Schemas.SendOrderResponse

  # First entry in the fixtures, kept as a string-keyed map so Req.Test can
  # re-encode it as the API would. Expectations are derived from it.
  @attrs "test/fixtures/gamma/market_ids.txt"
         |> File.read!()
         |> String.split("\n", trim: true)
         |> hd()
         |> Jason.decode!()

  @token_id @attrs["primary_token_id"]

  # Foundry/Anvil well-known test key #0 (address 0xf39Fd6...2266).
  @anvil_key Base.decode16!(
               "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
               case: :lower
             )
  @anvil_address Base.decode16!("f39Fd6e51aad88F6F4ce6aB8827279cffFb92266", case: :mixed)
  @secret "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
  @credentials %Credentials{
    api_key: "11111111-2222-3333-4444-555555555555",
    secret: @secret,
    passphrase: "a-passphrase",
    address: @anvil_address
  }
  @order %Order{
    salt: 123_456_789,
    maker: @anvil_address,
    signer: @anvil_address,
    token_id: String.to_integer("15871154585880608648532107628464183779895785213830018178010423617714102767076"),
    maker_amount: 1_000_000,
    taker_amount: 2_000_000,
    side: :buy,
    signature_type: :eoa,
    timestamp: 1_700_000_000_000
  }
  # The golden signature for @order on Polygon non-neg-risk (see OrderSignerTest);
  # @order is the same vector, signed by @anvil_key.
  @signature "0x53a5127be262d6db40e65df062f6aa40f82fa7b5fdd1ecf56d8bb99b9e68f4c9" <>
               "3331088eb9f738fec78e0979884b20811feece2ea122c755bc3c876ef906c8af1c"
  @send_order %SendOrder{order: @order, signature: @signature, owner: @credentials.api_key}

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

  describe "derive_api_key/3" do
    test "signs L1 headers, GETs /auth/derive-api-key, and parses the credentials" do
      Req.Test.stub(Polymarket.Clob, fn conn ->
        assert conn.method == "GET"
        assert conn.request_path == "/auth/derive-api-key"

        assert Plug.Conn.get_req_header(conn, "poly_address") ==
                 ["0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"]

        assert Plug.Conn.get_req_header(conn, "poly_nonce") == ["0"]
        assert Plug.Conn.get_req_header(conn, "poly_timestamp") == ["10000000"]
        assert [<<"0x", _rest::binary>>] = Plug.Conn.get_req_header(conn, "poly_signature")

        Req.Test.json(conn, %{"apiKey" => "key-1", "secret" => "sec", "passphrase" => "pass"})
      end)

      assert {:ok, %Credentials{} = credentials} =
               Clob.derive_api_key(@anvil_key, 80_002, timestamp: 10_000_000)

      assert credentials.api_key == "key-1"
      assert credentials.secret == "sec"
      assert credentials.passphrase == "pass"
      # The owner EOA address is recorded for the L2 POLY_ADDRESS header.
      assert credentials.address == @anvil_address
    end

    test "passes a non-default nonce through to the headers" do
      Req.Test.stub(Polymarket.Clob, fn conn ->
        assert Plug.Conn.get_req_header(conn, "poly_nonce") == ["7"]
        Req.Test.json(conn, %{"apiKey" => "k", "secret" => "s", "passphrase" => "p"})
      end)

      assert {:ok, %Credentials{}} =
               Clob.derive_api_key(@anvil_key, 137, timestamp: 1, nonce: 7)
    end

    test "returns an error on a non-200 response" do
      Req.Test.stub(Polymarket.Clob, fn conn ->
        Plug.Conn.send_resp(conn, 401, ~s({"error":"Invalid API key"}))
      end)

      assert {:error, :derive_api_key_failed} =
               Clob.derive_api_key(@anvil_key, 80_002, timestamp: 10_000_000)
    end

    test "returns an error when the credentials payload is incomplete" do
      Req.Test.stub(Polymarket.Clob, fn conn ->
        Req.Test.json(conn, %{"apiKey" => "key-1"})
      end)

      assert {:error, :derive_api_key_failed} =
               Clob.derive_api_key(@anvil_key, 80_002, timestamp: 10_000_000)
    end
  end

  describe "create_api_key/3" do
    test "POSTs to /auth/api-key with L1 headers and parses the credentials" do
      Req.Test.stub(Polymarket.Clob, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/auth/api-key"
        assert [<<"0x", _rest::binary>>] = Plug.Conn.get_req_header(conn, "poly_signature")

        Req.Test.json(conn, %{"apiKey" => "new-key", "secret" => "s", "passphrase" => "p"})
      end)

      assert {:ok, %Credentials{} = credentials} =
               Clob.create_api_key(@anvil_key, 137, timestamp: 1, nonce: 2)

      assert credentials.api_key == "new-key"
    end

    test "returns an error on a non-200 response" do
      Req.Test.stub(Polymarket.Clob, fn conn ->
        Plug.Conn.send_resp(conn, 400, ~s({"error":"bad request"}))
      end)

      assert {:error, :create_api_key_failed} =
               Clob.create_api_key(@anvil_key, 137, timestamp: 1)
    end
  end

  describe "create_or_derive_api_key/3" do
    test "returns the created credentials when creation succeeds" do
      Req.Test.stub(Polymarket.Clob, fn conn ->
        assert conn.method == "POST"
        Req.Test.json(conn, %{"apiKey" => "created", "secret" => "s", "passphrase" => "p"})
      end)

      assert {:ok, %Credentials{} = credentials} =
               Clob.create_or_derive_api_key(@anvil_key, 137, timestamp: 1)

      assert credentials.api_key == "created"
    end

    test "falls back to deriving when creation fails" do
      Req.Test.stub(Polymarket.Clob, fn conn ->
        case conn.method do
          "POST" -> Plug.Conn.send_resp(conn, 400, ~s({"error":"key exists"}))
          "GET" -> Req.Test.json(conn, %{"apiKey" => "derived", "secret" => "s", "passphrase" => "p"})
        end
      end)

      assert {:ok, %Credentials{} = credentials} =
               Clob.create_or_derive_api_key(@anvil_key, 137, timestamp: 1)

      assert credentials.api_key == "derived"
    end
  end

  describe "post_order/3" do
    test "serialises, HMAC-authenticates, and posts the order; parses a live response" do
      Req.Test.stub(Polymarket.Clob, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/order"

        {:ok, raw_body, conn} = Plug.Conn.read_body(conn)
        sent = Jason.decode!(raw_body)
        assert sent["orderType"] == "GTC"
        assert sent["owner"] == @credentials.api_key
        assert sent["order"]["side"] == "BUY"
        assert sent["order"]["signature"] == @signature

        assert Plug.Conn.get_req_header(conn, "poly_api_key") == [@credentials.api_key]

        # POLY_ADDRESS is the order's signer, checksummed.
        assert Plug.Conn.get_req_header(conn, "poly_address") ==
                 ["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"]

        # The POLY_SIGNATURE must be the HMAC over exactly the bytes we received.
        expected = HmacAuth.sign(@credentials.secret, "1POST/order#{raw_body}")
        assert Plug.Conn.get_req_header(conn, "poly_signature") == [expected]

        Req.Test.json(conn, %{
          "success" => true,
          "orderID" => "0xorder",
          "status" => "live",
          "makingAmount" => "1000000",
          "takingAmount" => "2000000",
          "errorMsg" => ""
        })
      end)

      assert {:ok, %SendOrderResponse{} = response} =
               Clob.post_order(@send_order, @credentials, timestamp: 1)

      assert response.success
      assert response.status == "live"
      assert response.order_id == "0xorder"
    end

    test "surfaces an insufficient-balance rejection as a ClobError" do
      Req.Test.stub(Polymarket.Clob, fn conn ->
        Plug.Conn.send_resp(conn, 400, ~s({"error":"not enough balance / allowance"}))
      end)

      assert {:error, %ClobError{} = error} =
               Clob.post_order(@send_order, @credentials, timestamp: 1)

      assert error.status == 400
      assert error.error == "not enough balance / allowance"
    end

    test "parses a matched response with transactions and trades" do
      Req.Test.stub(Polymarket.Clob, fn conn ->
        Req.Test.json(conn, %{
          "success" => true,
          "orderID" => "0xmatched",
          "status" => "matched",
          "transactionsHashes" => ["0xtx"],
          "tradeIDs" => ["trade-1"]
        })
      end)

      assert {:ok, response} = Clob.post_order(@send_order, @credentials, timestamp: 1)

      assert response.status == "matched"
      assert response.transactions_hashes == ["0xtx"]
      assert response.trade_ids == ["trade-1"]
    end

    test "applies order_type and post_only from the SendOrder to the wire body" do
      Req.Test.stub(Polymarket.Clob, fn conn ->
        {:ok, raw_body, conn} = Plug.Conn.read_body(conn)
        sent = Jason.decode!(raw_body)
        assert sent["orderType"] == "FOK"
        assert sent["postOnly"] == true

        Req.Test.json(conn, %{"success" => true, "status" => "live", "orderID" => "0x1"})
      end)

      send_order = %{@send_order | order_type: :fok, post_only: true}
      assert {:ok, _response} = Clob.post_order(send_order, @credentials, timestamp: 1)
    end

    test "POLY_ADDRESS is the credentials' owner EOA, not the order's funder/maker" do
      # A poly1271 deposit-wallet order: maker == signer == funder (a contract),
      # which differs from the api-key owner EOA. POLY_ADDRESS must be the owner.
      funder = :binary.copy(<<0x22>>, 20)
      order = %{@order | maker: funder, signer: funder, signature_type: :poly1271}
      {:ok, signature} = OrderSigner.sign(order, @anvil_key, 137, false)
      send_order = %SendOrder{order: order, signature: signature, owner: @credentials.api_key}

      Req.Test.stub(Polymarket.Clob, fn conn ->
        assert Plug.Conn.get_req_header(conn, "poly_address") ==
                 ["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"]

        Req.Test.json(conn, %{"success" => true, "status" => "live", "orderID" => "0x1"})
      end)

      assert {:ok, _response} = Clob.post_order(send_order, @credentials, timestamp: 1)
    end

    test "returns a successful struct for a 200 in-band rejection (success: false)" do
      Req.Test.stub(Polymarket.Clob, fn conn ->
        Req.Test.json(conn, %{
          "success" => false,
          "status" => "live",
          "orderID" => "0x0",
          "errorMsg" => "order could not be placed"
        })
      end)

      assert {:ok, %SendOrderResponse{success: false} = response} =
               Clob.post_order(@send_order, @credentials, timestamp: 1)

      assert response.error_msg == "order could not be placed"
    end

    test "the serialized body the HMAC signs contains no single quote (normalize_body is a no-op)" do
      Req.Test.stub(Polymarket.Clob, fn conn ->
        {:ok, raw_body, conn} = Plug.Conn.read_body(conn)
        refute raw_body =~ "'"
        Req.Test.json(conn, %{"success" => true, "status" => "live", "orderID" => "0x1"})
      end)

      assert {:ok, _response} = Clob.post_order(@send_order, @credentials, timestamp: 1)
    end
  end

  describe "post_orders/3" do
    test "posts a JSON array to /orders, HMAC-signs the bytes, and parses each response" do
      sell = %{@send_order | order: %{@order | side: :sell}}

      Req.Test.stub(Polymarket.Clob, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/orders"

        {:ok, raw_body, conn} = Plug.Conn.read_body(conn)
        sent = Jason.decode!(raw_body)
        assert [a, b] = sent
        assert a["order"]["side"] == "BUY"
        assert b["order"]["side"] == "SELL"

        # The HMAC covers exactly the array bytes; POLY_ADDRESS is the owner EOA.
        expected = HmacAuth.sign(@credentials.secret, "1POST/orders#{raw_body}")
        assert Plug.Conn.get_req_header(conn, "poly_signature") == [expected]

        assert Plug.Conn.get_req_header(conn, "poly_address") ==
                 ["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"]

        Req.Test.json(conn, [
          %{"success" => true, "orderID" => "0xlive", "status" => "live"},
          %{
            "success" => true,
            "orderID" => "0xmatched",
            "status" => "matched",
            "transactionsHashes" => ["0xtx"],
            "tradeIDs" => ["trade-1"]
          }
        ])
      end)

      assert {:ok, [live, matched]} =
               Clob.post_orders([@send_order, sell], @credentials, timestamp: 1)

      assert %SendOrderResponse{status: "live", order_id: "0xlive"} = live
      assert matched.status == "matched"
      assert matched.transactions_hashes == ["0xtx"]
      assert matched.trade_ids == ["trade-1"]
    end

    test "surfaces a too-many-orders rejection as a ClobError" do
      Req.Test.stub(Polymarket.Clob, fn conn ->
        Plug.Conn.send_resp(conn, 400, ~s({"error":"Too many orders in payload: 20, max allowed: 15"}))
      end)

      assert {:error, %ClobError{} = error} =
               Clob.post_orders([@send_order], @credentials, timestamp: 1)

      assert error.status == 400
      assert error.error == "Too many orders in payload: 20, max allowed: 15"
    end

    test "returns an empty list when the server accepts an empty batch" do
      Req.Test.stub(Polymarket.Clob, fn conn ->
        {:ok, raw_body, conn} = Plug.Conn.read_body(conn)
        assert raw_body == "[]"
        Req.Test.json(conn, [])
      end)

      assert {:ok, []} = Clob.post_orders([], @credentials, timestamp: 1)
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
