defmodule Polymarket.Schemas.SendOrderTest do
  use ExUnit.Case, async: true

  alias Polymarket.Schemas.Order
  alias Polymarket.Schemas.SendOrder

  @order %Order{
    salt: 1,
    maker: <<0::160>>,
    signer: <<0::160>>,
    token_id: 1,
    maker_amount: 1,
    taker_amount: 1,
    side: :buy,
    timestamp: 1
  }

  test "defaults order_type to :gtc and leaves the flags unset" do
    send_order = %SendOrder{order: @order, signature: "0x1234", owner: "owner-uuid"}

    assert send_order.order_type == :gtc
    assert send_order.post_only == nil
    assert send_order.defer_exec == nil
  end

  test "requires the order, signature and owner" do
    assert_raise ArgumentError, fn -> struct!(SendOrder, %{}) end
  end
end
