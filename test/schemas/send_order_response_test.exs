defmodule Polymarket.Schemas.SendOrderResponseTest do
  use ExUnit.Case, async: true

  alias Polymarket.Schemas.SendOrderResponse

  describe "from_attrs/1" do
    test "parses a live (resting) order from atom-keyed attrs" do
      response =
        SendOrderResponse.from_attrs(%{
          success: true,
          orderID: "0xabcdef",
          status: "live",
          makingAmount: "100000000",
          takingAmount: "200000000",
          errorMsg: ""
        })

      assert response.success == true
      assert response.order_id == "0xabcdef"
      assert response.status == "live"
      assert response.making_amount == "100000000"
      assert response.taking_amount == "200000000"
      assert response.transactions_hashes == []
      assert response.trade_ids == []
    end

    test "parses a matched order with transactions and trades (OpenAPI key spellings)" do
      response =
        SendOrderResponse.from_attrs(%{
          success: true,
          orderID: "0xabc",
          status: "matched",
          transactionsHashes: ["0xtx1", "0xtx2"],
          tradeIDs: ["trade-123"]
        })

      assert response.status == "matched"
      assert response.transactions_hashes == ["0xtx1", "0xtx2"]
      assert response.trade_ids == ["trade-123"]
    end

    test "also reads the reference client's canonical transactionHashes/tradeIds keys" do
      response =
        SendOrderResponse.from_attrs(%{
          success: true,
          status: "matched",
          transactionHashes: ["0xtx"],
          tradeIds: ["trade-9"]
        })

      assert response.transactions_hashes == ["0xtx"]
      assert response.trade_ids == ["trade-9"]
    end

    test "parses a 200 in-band rejection (success: false with an error message)" do
      response =
        SendOrderResponse.from_attrs(%{
          success: false,
          status: "live",
          errorMsg: "order could not be placed"
        })

      assert response.success == false
      assert response.error_msg == "order could not be placed"
    end

    test "also accepts string keys" do
      response = SendOrderResponse.from_attrs(%{"success" => true, "status" => "delayed"})

      assert response.success == true
      assert response.status == "delayed"
    end

    test "fills defaults for an empty body" do
      response = SendOrderResponse.from_attrs(%{})

      assert response.success == false
      assert response.order_id == nil
      assert response.error_msg == ""
    end
  end
end
