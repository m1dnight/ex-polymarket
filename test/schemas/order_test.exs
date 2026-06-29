defmodule Polymarket.Schemas.OrderTest do
  use ExUnit.Case, async: true

  alias Polymarket.Schemas.Order

  describe "struct defaults" do
    test "fills in EOA signature type, zero expiration, and zeroed bytes32 fields" do
      order = %Order{
        salt: 1,
        maker: <<0::160>>,
        signer: <<0::160>>,
        token_id: 1,
        maker_amount: 1,
        taker_amount: 1,
        side: :buy,
        timestamp: 1
      }

      assert order.signature_type == :eoa
      assert order.expiration == 0
      assert order.metadata == <<0::256>>
      assert order.builder == <<0::256>>
    end

    test "requires the core signed fields" do
      assert_raise ArgumentError, fn -> struct!(Order, %{}) end
    end
  end

  describe "side_value/1" do
    test "maps sides to their on-chain integers" do
      assert Order.side_value(:buy) == 0
      assert Order.side_value(:sell) == 1
    end
  end

  describe "signature_type_value/1" do
    test "maps signature types to their on-chain integers" do
      assert Order.signature_type_value(:eoa) == 0
      assert Order.signature_type_value(:proxy) == 1
      assert Order.signature_type_value(:gnosis_safe) == 2
      assert Order.signature_type_value(:poly1271) == 3
    end
  end
end
