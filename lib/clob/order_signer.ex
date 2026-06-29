defmodule Polymarket.Clob.OrderSigner do
  @moduledoc """
  EIP-712 signing for Polymarket CLOB **V2** orders.

  Turns a `Polymarket.Schemas.Order` into the `0x`-prefixed signature the CLOB
  expects, following the on-chain CTF Exchange V2 typed-data scheme:

    1. `eip712_hash_struct/1` — hash the order's eleven signed fields;
    2. `domain_separator/2` — the domain for the V2 exchange on the target chain
       (selected by `chain_id` and the market's `neg_risk?` flag);
    3. `signing_digest/3` — `keccak256(0x1901 ‖ domainSeparator ‖ hashStruct)`;
    4. `sign/4` — secp256k1-sign that digest with the maker's private key.

  `sign/4` dispatches on the order's `signature_type`:

    * `:eoa`, `:proxy`, `:gnosis_safe` — a plain EIP-712 signature of the digest;
    * `:poly1271` — the **deposit-wallet flow**: a Solady/ERC-1271 `TypedDataSign`
      envelope, signed by the deposit wallet's owner key and validated on-chain by
      the wallet contract (EIP-1271). Here `maker` and `signer` are the deposit
      wallet (the "funder") address and `private_key` is the owner EOA's key.

  The order's `maker`/`signer` must already be set correctly by the caller; `sign/4`
  signs the order as given.
  """

  alias Polymarket.Clob.Contracts
  alias Polymarket.Crypto
  alias Polymarket.Crypto.Eip712
  alias Polymarket.Schemas.Order

  @domain_name "Polymarket CTF Exchange"
  @domain_version "2"

  @order_type "Order(uint256 salt,address maker,address signer,uint256 tokenId," <>
                "uint256 makerAmount,uint256 takerAmount,uint8 side,uint8 signatureType," <>
                "uint256 timestamp,bytes32 metadata,bytes32 builder)"

  # Solady ERC-1271 `TypedDataSign` envelope (used by the deposit wallet). The
  # `Order` type string is appended with no separator — that is how Solidity
  # composes a referenced struct type into a single type-string for hashing.
  @typed_data_sign_type "TypedDataSign(Order contents,string name,string version," <>
                          "uint256 chainId,address verifyingContract,bytes32 salt)" <> @order_type

  @deposit_wallet_name "DepositWallet"
  @deposit_wallet_version "1"

  @doc """
  Computes the EIP-712 `hashStruct` of an order's eleven signed V2 fields.

  `expiration` is intentionally excluded — it is not part of the V2 signed struct.
  """
  @spec eip712_hash_struct(Order.t()) :: <<_::256>>
  def eip712_hash_struct(%Order{} = order) do
    Eip712.hash_struct(@order_type, [
      Eip712.encode_uint256(order.salt),
      Eip712.encode_address(order.maker),
      Eip712.encode_address(order.signer),
      Eip712.encode_uint256(order.token_id),
      Eip712.encode_uint256(order.maker_amount),
      Eip712.encode_uint256(order.taker_amount),
      Eip712.encode_uint8(Order.side_value(order.side)),
      Eip712.encode_uint8(Order.signature_type_value(order.signature_type)),
      Eip712.encode_uint256(order.timestamp),
      Eip712.encode_bytes32(order.metadata),
      Eip712.encode_bytes32(order.builder)
    ])
  end

  @doc """
  Computes the EIP-712 domain separator for the V2 exchange on `chain_id`, using
  the variant selected by `neg_risk?`. Returns `{:error, :unsupported_chain}` when
  no exchange is configured for that chain.
  """
  @spec domain_separator(integer(), boolean()) ::
          {:ok, <<_::256>>} | {:error, :unsupported_chain}
  def domain_separator(chain_id, neg_risk?) do
    case Contracts.exchange_v2(chain_id, neg_risk?) do
      {:ok, exchange} ->
        {:ok, Eip712.domain_separator(@domain_name, @domain_version, chain_id, exchange)}

      :error ->
        {:error, :unsupported_chain}
    end
  end

  @doc """
  Computes the 32-byte EIP-712 signing digest for `order` on `chain_id`/`neg_risk?`.
  """
  @spec signing_digest(Order.t(), integer(), boolean()) ::
          {:ok, <<_::256>>} | {:error, :unsupported_chain}
  def signing_digest(%Order{} = order, chain_id, neg_risk?) do
    with {:ok, separator} <- domain_separator(chain_id, neg_risk?) do
      {:ok, Eip712.digest(separator, eip712_hash_struct(order))}
    end
  end

  @doc """
  Signs `order` with `private_key`, returning the `0x`-prefixed signature hex the
  CLOB expects.

  For `:eoa`/`:proxy`/`:gnosis_safe` orders this is the 65-byte `r ‖ s ‖ v`
  signature; for `:poly1271` it is the longer Solady/ERC-1271 `TypedDataSign`
  envelope. `chain_id` selects the network (137 Polygon / 80002 Amoy) and
  `neg_risk?` the exchange variant for the order's market. Returns
  `{:error, :unsupported_chain}` for a chain with no configured exchange.
  """
  @spec sign(Order.t(), Crypto.private_key(), integer(), boolean()) ::
          {:ok, String.t()} | {:error, :unsupported_chain}
  def sign(%Order{signature_type: :poly1271} = order, private_key, chain_id, neg_risk?) do
    with {:ok, separator} <- domain_separator(chain_id, neg_risk?) do
      {:ok, poly1271_signature(order, private_key, separator, chain_id)}
    end
  end

  def sign(%Order{} = order, private_key, chain_id, neg_risk?) do
    with {:ok, digest} <- signing_digest(order, chain_id, neg_risk?) do
      {:ok, "0x" <> Base.encode16(Crypto.sign_digest(digest, private_key), case: :lower)}
    end
  end

  # The deposit-wallet (Poly1271) signature: an ERC-1271 `TypedDataSign` envelope
  # wrapping the order's contents hash, signed by the wallet owner's key. The
  # on-chain wallet validates it. Wire format:
  # `0x ‖ sig(65) ‖ domainSeparator(32) ‖ contentsHash(32) ‖ orderTypeString ‖
  # uint16_be(byte_size(orderTypeString))`.
  @spec poly1271_signature(Order.t(), Crypto.private_key(), <<_::256>>, integer()) :: String.t()
  defp poly1271_signature(%Order{} = order, private_key, separator, chain_id) do
    contents_hash = eip712_hash_struct(order)

    typed_data_sign_hash =
      Crypto.keccak256([
        Eip712.type_hash(@typed_data_sign_type),
        contents_hash,
        Crypto.keccak256(@deposit_wallet_name),
        Crypto.keccak256(@deposit_wallet_version),
        Eip712.encode_uint256(chain_id),
        Eip712.encode_address(order.signer),
        <<0::256>>
      ])

    digest = Eip712.digest(separator, typed_data_sign_hash)
    signature = Crypto.sign_digest(digest, private_key)
    wrapped = signature <> separator <> contents_hash <> @order_type <> <<byte_size(@order_type)::16>>

    "0x" <> Base.encode16(wrapped, case: :lower)
  end
end
