defmodule Polymarket.CryptoTest do
  use ExUnit.Case, async: true

  alias Polymarket.Crypto

  # Foundry/Anvil well-known test key #0 and its (lower-cased) address.
  @private_key Base.decode16!(
                 "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
                 case: :lower
               )
  @address Base.decode16!("f39fd6e51aad88f6f4ce6ab8827279cfffb92266", case: :lower)

  describe "keccak256/1" do
    test "matches the known empty-string vector" do
      assert Base.encode16(Crypto.keccak256(""), case: :lower) ==
               "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"
    end

    test "matches the known \"abc\" vector" do
      assert Base.encode16(Crypto.keccak256("abc"), case: :lower) ==
               "4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45"
    end

    test "accepts iodata, hashing it identically to the joined binary" do
      assert Crypto.keccak256(["a", "b", "c"]) == Crypto.keccak256("abc")
    end
  end

  describe "address_from_private_key/1" do
    test "derives the known Anvil address" do
      assert Crypto.address_from_private_key(@private_key) == @address
    end

    test "raises on a key that is not 32 bytes" do
      assert_raise ArgumentError, fn -> Crypto.address_from_private_key(<<0, 1, 2>>) end
    end
  end

  describe "sign_digest/2" do
    setup do
      %{digest: Crypto.keccak256("polymarket order digest")}
    end

    test "produces a deterministic 65-byte signature", %{digest: digest} do
      signature = Crypto.sign_digest(digest, @private_key)
      assert byte_size(signature) == 65
      assert Crypto.sign_digest(digest, @private_key) == signature
    end

    test "uses a recovery byte of 27 or 28", %{digest: digest} do
      <<_r::binary-size(32), _s::binary-size(32), v>> = Crypto.sign_digest(digest, @private_key)
      assert v in [27, 28]
    end

    test "recovers to the signer's address", %{digest: digest} do
      <<r_s::binary-size(64), v>> = Crypto.sign_digest(digest, @private_key)
      {:ok, <<4, public_key::binary-size(64)>>} = ExSecp256k1.recover_compact(digest, r_s, v - 27)
      <<_::binary-size(12), recovered::binary-size(20)>> = Crypto.keccak256(public_key)
      assert recovered == @address
    end

    test "raises when the digest is not 32 bytes", %{digest: _digest} do
      assert_raise ArgumentError, fn -> Crypto.sign_digest(<<0>>, @private_key) end
    end
  end

  describe "to_checksum_address/1" do
    test "matches the EIP-55 reference vectors" do
      assert checksum("5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed") ==
               "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed"

      assert checksum("fB6916095ca1df60bB79Ce92cE3Ea74c37c5d359") ==
               "0xfB6916095ca1df60bB79Ce92cE3Ea74c37c5d359"

      assert checksum("dbF03B407c01E7cD3CBea99509d93f8DDDC8C6FB") ==
               "0xdbF03B407c01E7cD3CBea99509d93f8DDDC8C6FB"

      assert checksum("D1220A0cf47c7B9Be7A2E6BA89F429762e7b9aDb") ==
               "0xD1220A0cf47c7B9Be7A2E6BA89F429762e7b9aDb"
    end

    test "checksums the Anvil test address" do
      assert checksum("f39Fd6e51aad88F6F4ce6aB8827279cffFb92266") ==
               "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
    end

    test "produces a 42-character 0x-prefixed string" do
      checksummed = checksum("0000000000000000000000000000000000000000")
      assert checksummed == "0x0000000000000000000000000000000000000000"
      assert String.length(checksummed) == 42
    end
  end

  @spec checksum(String.t()) :: String.t()
  defp checksum(hex), do: Crypto.to_checksum_address(Base.decode16!(hex, case: :mixed))
end
