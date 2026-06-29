defmodule Polymarket.Clob.DepositWalletTest do
  use ExUnit.Case, async: true

  alias Polymarket.Clob.DepositWallet

  # Foundry/Anvil test address and its deterministic Polymarket deposit wallets,
  # taken verbatim from rs-clob-client-v2's derivation tests.
  @eoa Base.decode16!("f39Fd6e51aad88F6F4ce6aB8827279cffFb92266", case: :mixed)
  @proxy Base.decode16!("365f0cA36ae1F641E02Fe3b7743673DA42A13a70", case: :mixed)
  @safe Base.decode16!("d93b25Cb943D14d0d34FBAf01fc93a0F8b5f6e47", case: :mixed)

  describe "derive_proxy_wallet/2 (matches rs-clob-client-v2)" do
    test "derives the deterministic proxy address on Polygon" do
      assert DepositWallet.derive_proxy_wallet(@eoa, 137) == {:ok, @proxy}
    end

    test "is unsupported on Amoy (no proxy factory)" do
      assert DepositWallet.derive_proxy_wallet(@eoa, 80_002) == :error
    end

    test "returns :error for an unknown chain" do
      assert DepositWallet.derive_proxy_wallet(@eoa, 1) == :error
    end
  end

  describe "derive_safe_wallet/2 (matches rs-clob-client-v2)" do
    test "derives the deterministic Safe address on Polygon" do
      assert DepositWallet.derive_safe_wallet(@eoa, 137) == {:ok, @safe}
    end

    test "derives the same Safe address on Amoy (chain-independent factory and salt)" do
      assert DepositWallet.derive_safe_wallet(@eoa, 80_002) == {:ok, @safe}
    end

    test "returns :error for an unknown chain" do
      assert DepositWallet.derive_safe_wallet(@eoa, 1) == :error
    end
  end

  test "the proxy and Safe wallets for an EOA are different addresses" do
    assert {:ok, proxy} = DepositWallet.derive_proxy_wallet(@eoa, 137)
    assert {:ok, safe} = DepositWallet.derive_safe_wallet(@eoa, 137)
    refute proxy == safe
  end
end
