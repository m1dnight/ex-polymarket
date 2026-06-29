defmodule Polymarket.Clob.ClobAuthTest do
  use ExUnit.Case, async: true

  alias Polymarket.Clob.ClobAuth
  alias Polymarket.Crypto

  # Foundry/Anvil well-known test key #0 and its address.
  @private_key Base.decode16!(
                 "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
                 case: :lower
               )
  @address Base.decode16!("f39Fd6e51aad88F6F4ce6aB8827279cffFb92266", case: :mixed)

  # The exact L1 signature produced by the Rust reference client (rs-clob-client-v2,
  # `auth.rs` `l1_headers_should_succeed`) for the Anvil key on Amoy (80002) with
  # timestamp 10_000_000 and nonce 23 — a byte-for-byte cross-implementation vector.
  @signature "0xf62319a987514da40e57e2f4d7529f7bac38f0355bd88bb5adbb3768d80de6c1" <>
               "682518e0af677d5260366425f4361e7b70c25ae232aff0ab2331e2b164a1aedc1b"

  describe "golden vector (matches rs-clob-client-v2 byte-for-byte)" do
    test "headers/4 produces the full L1 header set" do
      assert ClobAuth.headers(@private_key, 10_000_000, 23, 80_002) == [
               {"POLY_ADDRESS", "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"},
               {"POLY_NONCE", "23"},
               {"POLY_SIGNATURE", @signature},
               {"POLY_TIMESTAMP", "10000000"}
             ]
    end

    test "sign/4 produces the golden signature" do
      assert ClobAuth.sign(@private_key, 10_000_000, 23, 80_002) == @signature
    end
  end

  describe "sign/4" do
    test "produces a signature that recovers to the wallet address" do
      timestamp = 1_700_000_000
      nonce = 0
      chain_id = 137
      digest = ClobAuth.signing_digest(@address, timestamp, nonce, chain_id)
      "0x" <> signature_hex = ClobAuth.sign(@private_key, timestamp, nonce, chain_id)
      <<r_s::binary-size(64), v>> = Base.decode16!(signature_hex, case: :lower)

      {:ok, <<4, public_key::binary-size(64)>>} = ExSecp256k1.recover_compact(digest, r_s, v - 27)
      <<_::binary-size(12), recovered::binary-size(20)>> = Crypto.keccak256(public_key)

      assert recovered == @address
    end

    test "is deterministic" do
      assert ClobAuth.sign(@private_key, 123, 1, 137) == ClobAuth.sign(@private_key, 123, 1, 137)
    end

    test "a different nonce changes the signature" do
      refute ClobAuth.sign(@private_key, 123, 0, 137) == ClobAuth.sign(@private_key, 123, 1, 137)
    end

    test "a different timestamp changes the signature" do
      refute ClobAuth.sign(@private_key, 123, 0, 137) == ClobAuth.sign(@private_key, 124, 0, 137)
    end

    test "a different chain id changes the signature" do
      refute ClobAuth.sign(@private_key, 123, 0, 137) == ClobAuth.sign(@private_key, 123, 0, 80_002)
    end
  end

  describe "headers/4" do
    test "renders POLY_ADDRESS as lowercase hex (not checksummed)" do
      headers = Map.new(ClobAuth.headers(@private_key, 1, 0, 137))

      assert headers["POLY_ADDRESS"] == "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"
    end
  end
end
