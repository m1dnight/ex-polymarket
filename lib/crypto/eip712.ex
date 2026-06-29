defmodule Polymarket.Crypto.Eip712 do
  @moduledoc """
  Minimal EIP-712 typed-data hashing, tailored to Polymarket orders.

  Polymarket's `Order` struct contains only *static* ABI types (`uint256`,
  `address`, `uint8`, `bytes32`), so encoding a struct's data is simply each
  field left-padded to a 32-byte word and concatenated — no dynamic-type or
  nested-struct handling is required. This module deliberately implements only
  that subset.

  The pieces, in EIP-712 terms:

    * `type_hash/1` — `keccak256(encodeType)`.
    * `hash_struct/2` — `keccak256(typeHash ‖ encodeData)`.
    * `domain_separator/4` — the `hashStruct` of the standard `EIP712Domain`.
    * `digest/2` — `keccak256(0x19 0x01 ‖ domainSeparator ‖ hashStruct)`, the
      32-byte value that is finally signed.
  """

  alias Polymarket.Crypto

  @domain_type "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"

  @domain_type_without_contract "EIP712Domain(string name,string version,uint256 chainId)"

  @max_uint256 2 ** 256

  @doc "Left-pads a non-negative `uint256` to a 32-byte big-endian word."
  @spec encode_uint256(non_neg_integer()) :: <<_::256>>
  def encode_uint256(value) when is_integer(value) and value >= 0 and value < @max_uint256 do
    <<value::unsigned-big-integer-size(256)>>
  end

  @doc "Left-pads a `uint8` to a 32-byte word."
  @spec encode_uint8(0..255) :: <<_::256>>
  def encode_uint8(value) when value in 0..255, do: encode_uint256(value)

  @doc "Left-pads a 20-byte `address` to a 32-byte word."
  @spec encode_address(<<_::160>>) :: <<_::256>>
  def encode_address(<<_::160>> = address), do: <<0::96, address::binary>>

  @doc "Passes a 32-byte `bytes32` value through unchanged (it is already one word)."
  @spec encode_bytes32(<<_::256>>) :: <<_::256>>
  def encode_bytes32(<<_::256>> = value), do: value

  @doc """
  Encodes a dynamic `string` value to its 32-byte EIP-712 word, `keccak256(value)`.

  Per EIP-712, dynamic types (`string`, `bytes`) contribute the keccak-256 hash of
  their contents rather than the value itself.
  """
  @spec encode_string(binary()) :: <<_::256>>
  def encode_string(value) when is_binary(value), do: Crypto.keccak256(value)

  @doc """
  The type hash for an EIP-712 struct: `keccak256(encodeType)`. `encode_type` is
  the canonical type string, e.g. `"Order(uint256 salt,...)"`.
  """
  @spec type_hash(binary()) :: <<_::256>>
  def type_hash(encode_type) when is_binary(encode_type), do: Crypto.keccak256(encode_type)

  @doc """
  Hashes a struct: `keccak256(typeHash ‖ encodeData)`. `encoded_fields` is the
  list of already-encoded 32-byte words, in the struct's declared field order.
  """
  @spec hash_struct(binary(), [<<_::256>>]) :: <<_::256>>
  def hash_struct(encode_type, encoded_fields) when is_binary(encode_type) and is_list(encoded_fields) do
    Crypto.keccak256([type_hash(encode_type) | encoded_fields])
  end

  @doc """
  Computes the domain separator for the standard EIP-712 domain
  (`name`, `version`, `chain_id`, `verifying_contract`).
  """
  @spec domain_separator(binary(), binary(), non_neg_integer(), <<_::160>>) :: <<_::256>>
  def domain_separator(name, version, chain_id, <<_::160>> = verifying_contract) do
    hash_struct(@domain_type, [
      encode_string(name),
      encode_string(version),
      encode_uint256(chain_id),
      encode_address(verifying_contract)
    ])
  end

  @doc """
  Computes the domain separator for an EIP-712 domain *without* a verifying
  contract (`name`, `version`, `chain_id`).

  A `verifyingContract`-less domain has a distinct type hash, so this is not the
  same as `domain_separator/4` with a zero address. Polymarket's `ClobAuthDomain`
  (used for L1 API-key authentication) omits the verifying contract.
  """
  @spec domain_separator(binary(), binary(), non_neg_integer()) :: <<_::256>>
  def domain_separator(name, version, chain_id) do
    hash_struct(@domain_type_without_contract, [
      encode_string(name),
      encode_string(version),
      encode_uint256(chain_id)
    ])
  end

  @doc """
  Assembles the final EIP-712 signing digest from a domain separator and a struct
  hash: `keccak256(0x19 0x01 ‖ domainSeparator ‖ hashStruct)`.
  """
  @spec digest(<<_::256>>, <<_::256>>) :: <<_::256>>
  def digest(<<_::256>> = domain_separator, <<_::256>> = hash_struct) do
    Crypto.keccak256([<<0x19, 0x01>>, domain_separator, hash_struct])
  end
end
