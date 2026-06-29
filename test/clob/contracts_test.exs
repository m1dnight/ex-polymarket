defmodule Polymarket.Clob.ContractsTest do
  use ExUnit.Case, async: true

  alias Polymarket.Clob.Contracts

  @exchange_v2 Base.decode16!("E111180000d2663C0091e4f400237545B87B996B", case: :mixed)
  @neg_risk_exchange_v2 Base.decode16!("e2222d279d744050d28e00520010520000310F59", case: :mixed)

  describe "chain ids" do
    test "polygon/0 and amoy/0" do
      assert Contracts.polygon() == 137
      assert Contracts.amoy() == 80_002
    end
  end

  describe "exchange_v2/2" do
    test "returns the standard exchange for non-neg-risk markets" do
      assert Contracts.exchange_v2(137, false) == {:ok, @exchange_v2}
      assert Contracts.exchange_v2(80_002, false) == {:ok, @exchange_v2}
    end

    test "returns the neg-risk exchange for neg-risk markets" do
      assert Contracts.exchange_v2(137, true) == {:ok, @neg_risk_exchange_v2}
      assert Contracts.exchange_v2(80_002, true) == {:ok, @neg_risk_exchange_v2}
    end

    test "returns :error for an unsupported chain" do
      assert Contracts.exchange_v2(1, false) == :error
      assert Contracts.exchange_v2(1, true) == :error
    end
  end
end
