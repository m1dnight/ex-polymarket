defmodule Polymarket.Clob.OrderPayloadTest do
  use ExUnit.Case, async: true

  alias Polymarket.Clob.OrderPayload
  alias Polymarket.Schemas.Order
  alias Polymarket.Schemas.SendOrder

  @maker Base.decode16!("f39Fd6e51aad88F6F4ce6aB8827279cffFb92266", case: :mixed)
  @token_id String.to_integer("15871154585880608648532107628464183779895785213830018178010423617714102767076")
  @signature "0x53a5127be262d6db40e65df062f6aa40f82fa7b5fdd1ecf56d8bb99b9e68f4c9" <>
               "3331088eb9f738fec78e0979884b20811feece2ea122c755bc3c876ef906c8af1c"
  @owner "f4f247b7-4ac7-ff29-a152-04fda0a8755a"

  @order %Order{
    salt: 123_456_789,
    maker: @maker,
    signer: @maker,
    token_id: @token_id,
    maker_amount: 1_000_000,
    taker_amount: 2_000_000,
    side: :buy,
    signature_type: :eoa,
    timestamp: 1_700_000_000_000,
    metadata: <<0::256>>,
    builder: <<0::256>>
  }
  @send_order %SendOrder{order: @order, signature: @signature, owner: @owner}

  # Verbatim `serde_json` output of the identical SignedOrder from rs-clob-client-v2.
  # Compared decoded (so field order is irrelevant), this pins every wire field's
  # name, type and format against the reference implementation.
  @rust_minimal ~s({"order":{"salt":123456789,"maker":"0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266","signer":"0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266","tokenId":"15871154585880608648532107628464183779895785213830018178010423617714102767076","makerAmount":"1000000","takerAmount":"2000000","side":"BUY","expiration":"0","signatureType":0,"timestamp":"1700000000000","metadata":"0x0000000000000000000000000000000000000000000000000000000000000000","builder":"0x0000000000000000000000000000000000000000000000000000000000000000","signature":"0x53a5127be262d6db40e65df062f6aa40f82fa7b5fdd1ecf56d8bb99b9e68f4c93331088eb9f738fec78e0979884b20811feece2ea122c755bc3c876ef906c8af1c"},"orderType":"GTC","owner":"f4f247b7-4ac7-ff29-a152-04fda0a8755a"})

  describe "serialize/1 (matches rs-clob-client-v2 wire body)" do
    test "produces the reference SendOrder body for a GTC order" do
      assert decoded(OrderPayload.serialize(@send_order)) == decoded(@rust_minimal)
    end

    test "includes postOnly/deferExec only when given" do
      minimal = decoded(OrderPayload.serialize(@send_order))
      refute Map.has_key?(minimal, "postOnly")
      refute Map.has_key?(minimal, "deferExec")

      full = decoded(OrderPayload.serialize(%{@send_order | post_only: true, defer_exec: false}))
      assert full["postOnly"] == true
      assert full["deferExec"] == false
    end

    test "salt is a JSON number while amounts/ids/timestamps are strings" do
      order = decoded(OrderPayload.serialize(@send_order))["order"]
      assert order["salt"] == 123_456_789
      assert order["makerAmount"] == "1000000"
      assert order["tokenId"] == to_string(@token_id)
      assert order["timestamp"] == "1700000000000"
      assert order["expiration"] == "0"
    end

    test "maker/signer are lowercase hex; metadata/builder are 0x + 64 hex" do
      order = decoded(OrderPayload.serialize(@send_order))["order"]
      assert order["maker"] == "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"
      assert order["metadata"] == "0x" <> String.duplicate("0", 64)
    end

    test "encodes side and signatureType to their wire values" do
      buy = decoded(OrderPayload.serialize(@send_order))["order"]
      assert buy["side"] == "BUY"
      assert buy["signatureType"] == 0

      sell = %{@send_order | order: %{@order | side: :sell, signature_type: :gnosis_safe}}
      sell_order = decoded(OrderPayload.serialize(sell))["order"]
      assert sell_order["side"] == "SELL"
      assert sell_order["signatureType"] == 2
    end

    test "maps order_type to the time-in-force string" do
      for {atom, wire} <- [gtc: "GTC", fok: "FOK", gtd: "GTD", fak: "FAK"] do
        body = decoded(OrderPayload.serialize(%{@send_order | order_type: atom}))
        assert body["orderType"] == wire
      end
    end
  end

  describe "serialize_many/1 (batch POST /orders body)" do
    test "produces a JSON array whose elements equal the single-order bodies" do
      sell = %{@send_order | order: %{@order | side: :sell}, order_type: :fok}

      assert [first, second] = Jason.decode!(OrderPayload.serialize_many([@send_order, sell]))
      assert first == decoded(OrderPayload.serialize(@send_order))
      assert second == decoded(OrderPayload.serialize(sell))
    end

    test "preserves order and matches the reference single-order wire body" do
      assert [only] = Jason.decode!(OrderPayload.serialize_many([@send_order]))
      assert only == decoded(@rust_minimal)
    end

    test "serialises an empty batch as an empty JSON array" do
      assert OrderPayload.serialize_many([]) == "[]"
    end
  end

  @spec decoded(String.t()) :: map()
  defp decoded(json), do: Jason.decode!(json)
end
