defmodule Polymarket.Clob.OrderSignerTest do
  use ExUnit.Case, async: true

  alias Polymarket.Clob.OrderSigner
  alias Polymarket.Crypto
  alias Polymarket.Schemas.Order

  # Foundry/Anvil well-known test key #0 and its address.
  @private_key Base.decode16!(
                 "ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
                 case: :lower
               )
  @maker Base.decode16!("f39Fd6e51aad88F6F4ce6aB8827279cffFb92266", case: :mixed)
  @token_id String.to_integer("15871154585880608648532107628464183779895785213830018178010423617714102767076")

  # The exact V2 EOA order whose EIP-712 hashes and signature were produced by the
  # Rust reference client (rs-clob-client-v2). Every expected hex below is its
  # verbatim output, making this an end-to-end cross-implementation golden vector.
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

  @signature "0x53a5127be262d6db40e65df062f6aa40f82fa7b5fdd1ecf56d8bb99b9e68f4c9" <>
               "3331088eb9f738fec78e0979884b20811feece2ea122c755bc3c876ef906c8af1c"

  # The Order EIP-712 type string, used as the trailing field of the Poly1271
  # envelope (and to derive its `0x00ba` length).
  @order_type_string "Order(uint256 salt,address maker,address signer,uint256 tokenId," <>
                       "uint256 makerAmount,uint256 takerAmount,uint8 side,uint8 signatureType," <>
                       "uint256 timestamp,bytes32 metadata,bytes32 builder)"

  # A deposit-wallet ("funder") address: the Poly1271 order's maker == signer.
  @funder Base.decode16!("1111111111111111111111111111111111111111", case: :mixed)

  # The verbatim Poly1271 deposit-wallet envelope produced by the working polybot
  # implementation for `@order` with maker == signer == @funder and `:poly1271`.
  # Layout: r ‖ s ‖ v ‖ exchange domain separator ‖ order contents hash ‖ the
  # Order type string ‖ uint16 length. The signature, domain separator and
  # contents hash below are polybot's literal output (cross-implementation golden).
  @poly1271_signature "0x805443312af8562dbe8421e411e11cb4299d5094eaf62be236732f82af6e24df" <>
                        "76b6ca3d4b861b217026d7c0389afd034c9ab73ea3ad1238be2f8a7aa740a658" <>
                        "1c" <>
                        "3264e159346253e26a64e00b69032db0e7d32f94628de3e6eecb50304d7af3d2" <>
                        "1108cebd131d0e71513e4783b68365b73d6863636cf60a254abe44eb0d043411" <>
                        Base.encode16(@order_type_string, case: :lower) <>
                        "00ba"

  # A second golden vector that drives every field the first one leaves trivial:
  # sell side (uint8 1), gnosis-safe signature type (uint8 2), a distinct
  # maker != signer, non-zero metadata/builder bytes32, and a maximal uint256
  # salt. Its expected hashes are the verbatim output of rs-clob-client-v2 for the
  # identical order, so it pins those encoder branches against a known-good value
  # rather than mere inequality. `signer` is the Anvil address, so `sign/4` with
  # `@private_key` still recovers to it.
  @varied_order %Order{
    salt: Integer.pow(2, 256) - 1,
    maker: :binary.copy(<<0x11>>, 20),
    signer: @maker,
    token_id: @token_id,
    maker_amount: 123_456_789_000_000,
    taker_amount: 987_654_321_000_000,
    side: :sell,
    signature_type: :gnosis_safe,
    timestamp: 2_000_000_000_000,
    metadata: :binary.copy(<<0x11>>, 32),
    builder: :binary.copy(<<0x22>>, 32)
  }

  @spec hex(binary()) :: String.t()
  defp hex(binary), do: "0x" <> Base.encode16(binary, case: :lower)

  describe "sign/4 poly1271 deposit-wallet flow (matches polybot byte-for-byte)" do
    test "produces the ERC-1271 TypedDataSign envelope" do
      order = %{@order | maker: @funder, signer: @funder, signature_type: :poly1271}

      assert OrderSigner.sign(order, @private_key, 137, false) == {:ok, @poly1271_signature}
    end

    test "embeds the order's exchange domain separator, contents hash and type string" do
      order = %{@order | maker: @funder, signer: @funder, signature_type: :poly1271}
      {:ok, "0x" <> envelope} = OrderSigner.sign(order, @private_key, 137, false)
      type_len = byte_size(@order_type_string)

      <<_sig::binary-size(65), domain_sep::binary-size(32), contents_hash::binary-size(32),
        type_string::binary-size(type_len), len::16>> = Base.decode16!(envelope, case: :lower)

      assert {:ok, domain_sep} == OrderSigner.domain_separator(137, false)
      assert contents_hash == OrderSigner.eip712_hash_struct(order)
      assert type_string == @order_type_string
      assert len == type_len
    end

    test "selects the neg-risk domain for neg-risk markets" do
      order = %{@order | maker: @funder, signer: @funder, signature_type: :poly1271}

      assert {:ok, standard} = OrderSigner.sign(order, @private_key, 137, false)
      assert {:ok, neg_risk} = OrderSigner.sign(order, @private_key, 137, true)
      refute standard == neg_risk
    end

    test "returns an error for an unsupported chain" do
      order = %{@order | maker: @funder, signer: @funder, signature_type: :poly1271}

      assert OrderSigner.sign(order, @private_key, 1, false) == {:error, :unsupported_chain}
    end
  end

  describe "golden vector (matches rs-clob-client-v2 byte-for-byte)" do
    test "eip712_hash_struct/1" do
      assert hex(OrderSigner.eip712_hash_struct(@order)) ==
               "0xb381f5582806334a4a10d8ac2abec5dc5491ffbd7bf5efde62621c226413bcc5"
    end

    test "domain_separator/2 (Polygon, non-neg-risk)" do
      assert {:ok, separator} = OrderSigner.domain_separator(137, false)

      assert hex(separator) ==
               "0x3264e159346253e26a64e00b69032db0e7d32f94628de3e6eecb50304d7af3d2"
    end

    test "signing_digest/3" do
      assert {:ok, digest} = OrderSigner.signing_digest(@order, 137, false)

      assert hex(digest) ==
               "0xb19175130ba93538ad5619bd3e1b85c40804c648293ea3a00cdc098deddc13da"
    end

    test "sign/4" do
      assert OrderSigner.sign(@order, @private_key, 137, false) == {:ok, @signature}
    end
  end

  describe "golden vector 2 — every field non-trivial (matches rs-clob-client-v2)" do
    test "eip712_hash_struct/1 pins sell, gnosis-safe, non-zero metadata/builder, max salt" do
      assert hex(OrderSigner.eip712_hash_struct(@varied_order)) ==
               "0xbf5aa9bd5ff2da2cdd0af88309a54a4a0fcec91d2973329ee7557a7572fe4b72"
    end

    test "signing_digest/3 on Polygon non-neg-risk" do
      assert {:ok, digest} = OrderSigner.signing_digest(@varied_order, 137, false)

      assert hex(digest) ==
               "0xb3d29f9052d2a4c4c01ccac169f5f6cc66be08ad81699f690077080158f33df6"
    end

    test "signing_digest/3 on Polygon neg-risk pins the neg-risk domain absolutely" do
      assert {:ok, digest} = OrderSigner.signing_digest(@varied_order, 137, true)

      assert hex(digest) ==
               "0x86892f083272dab23bd08e549ffbe7f31ec9a5b7a40bb543d8e7fcd546e8d864"
    end

    test "sign/4 produces a signature that recovers to the order's signer" do
      {:ok, digest} = OrderSigner.signing_digest(@varied_order, 137, false)
      {:ok, "0x" <> signature_hex} = OrderSigner.sign(@varied_order, @private_key, 137, false)
      <<r_s::binary-size(64), v>> = Base.decode16!(signature_hex, case: :lower)

      {:ok, <<4, public_key::binary-size(64)>>} = ExSecp256k1.recover_compact(digest, r_s, v - 27)
      <<_::binary-size(12), recovered::binary-size(20)>> = Crypto.keccak256(public_key)

      assert recovered == @varied_order.signer
    end
  end

  describe "domain_separator/2 golden values (matches rs-clob-client-v2)" do
    test "Polygon neg-risk" do
      assert {:ok, separator} = OrderSigner.domain_separator(137, true)

      assert hex(separator) ==
               "0x9b858f53327b0bd13af8ec14cfb35234fb9eb7b0504d1a4e61f433840d30e81a"
    end

    test "Amoy non-neg-risk" do
      assert {:ok, separator} = OrderSigner.domain_separator(80_002, false)

      assert hex(separator) ==
               "0xa440cbd865bc0c6243d7a8df9a8bf48a8827b0a4abbb61c30e96d305423af148"
    end

    test "Amoy neg-risk" do
      assert {:ok, separator} = OrderSigner.domain_separator(80_002, true)

      assert hex(separator) ==
               "0x1468e39841f0a0e05d3762b235cb7acecabf8cd7b6d3a672965a5d415bf9378e"
    end
  end

  describe "sign/4" do
    test "produces a signature that recovers to the maker's address" do
      {:ok, digest} = OrderSigner.signing_digest(@order, 137, false)
      {:ok, "0x" <> signature_hex} = OrderSigner.sign(@order, @private_key, 137, false)
      <<r_s::binary-size(64), v>> = Base.decode16!(signature_hex, case: :lower)

      {:ok, <<4, public_key::binary-size(64)>>} = ExSecp256k1.recover_compact(digest, r_s, v - 27)
      <<_::binary-size(12), recovered::binary-size(20)>> = Crypto.keccak256(public_key)

      assert recovered == @maker
    end

    test "a sell order signs differently from a buy order" do
      assert {:ok, buy} = OrderSigner.sign(@order, @private_key, 137, false)
      assert {:ok, sell} = OrderSigner.sign(%{@order | side: :sell}, @private_key, 137, false)
      refute buy == sell
    end

    test "returns an error for an unsupported chain" do
      assert OrderSigner.sign(@order, @private_key, 1, false) == {:error, :unsupported_chain}
    end
  end

  describe "signing_digest/3" do
    test "neg-risk markets sign against a different domain, changing the digest" do
      assert {:ok, normal} = OrderSigner.signing_digest(@order, 137, false)
      assert {:ok, neg_risk} = OrderSigner.signing_digest(@order, 137, true)
      refute normal == neg_risk
    end

    test "returns an error for an unsupported chain" do
      assert OrderSigner.signing_digest(@order, 1, false) == {:error, :unsupported_chain}
    end
  end
end
