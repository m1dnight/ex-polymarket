defmodule Polymarket.Crypto do
  @moduledoc """
  Low-level Ethereum cryptographic primitives used to sign Polymarket orders.

  Wraps the two native dependencies — `ExKeccak` for keccak-256 and `ExSecp256k1`
  for ECDSA secp256k1 — behind a small, total API so the rest of the codebase
  never touches the NIFs directly:

    * `keccak256/1` — the keccak-256 hash (Ethereum's hash, *not* FIPS SHA3-256).
    * `address_from_private_key/1` — the 20-byte Ethereum address for a key.
    * `sign_digest/2` — an Ethereum-style 65-byte `r ‖ s ‖ v` signature over a
      pre-computed 32-byte digest.

  All functions raise `ArgumentError` on malformed input (wrong byte sizes); a
  failure here is a programming error, not a recoverable runtime condition.
  """

  @typedoc "A 32-byte digest, e.g. a keccak-256 hash."
  @type digest :: <<_::256>>

  @typedoc "A 32-byte secp256k1 private key."
  @type private_key :: <<_::256>>

  @typedoc "A 20-byte Ethereum address."
  @type address :: <<_::160>>

  @typedoc "A 65-byte `r ‖ s ‖ v` signature, with `v` in `27..28`."
  @type signature :: <<_::520>>

  @doc """
  Computes the keccak-256 hash of `data` (a binary or iodata).

  This is the hash function Ethereum uses everywhere — address derivation,
  EIP-712, function selectors. It differs from the FIPS-202 `:sha3_256` exposed
  by `:crypto`, which uses different padding and produces different output.
  """
  @spec keccak256(iodata()) :: digest()
  def keccak256(data), do: ExKeccak.hash_256(IO.iodata_to_binary(data))

  @doc """
  Derives the 20-byte Ethereum address controlled by `private_key`.

  The address is the last 20 bytes of the keccak-256 hash of the 64-byte
  uncompressed public key (the key without its leading `0x04` prefix).
  """
  @spec address_from_private_key(private_key()) :: address()
  def address_from_private_key(<<_::256>> = private_key) do
    {:ok, <<4, public_key::binary-size(64)>>} = ExSecp256k1.create_public_key(private_key)
    <<_::binary-size(12), address::binary-size(20)>> = keccak256(public_key)
    address
  end

  def address_from_private_key(other) do
    raise ArgumentError, "private key must be 32 bytes, got: #{inspect(other)}"
  end

  @doc """
  Signs a pre-computed 32-byte `digest` with `private_key`, returning a 65-byte
  Ethereum signature `r (32) ‖ s (32) ‖ v (1)`, where `v` is the recovery id
  normalised to 27 or 28.

  The signature is deterministic (RFC 6979): the same digest and key always yield
  the same bytes.
  """
  @spec sign_digest(digest(), private_key()) :: signature()
  def sign_digest(<<_::256>> = digest, <<_::256>> = private_key) do
    {:ok, {<<_::512>> = r_s, recovery_id}} = ExSecp256k1.sign_compact(digest, private_key)
    <<r_s::binary, recovery_id + 27>>
  end

  def sign_digest(digest, private_key) do
    raise ArgumentError,
          "digest and private key must both be 32 bytes, got: #{inspect({digest, private_key})}"
  end

  @doc """
  Renders a 20-byte address as its EIP-55 mixed-case checksummed `0x` string.

  Each hex letter is upper-cased when the corresponding nibble of the keccak-256
  hash of the lowercase address string is `>= 8`. Polymarket's L2 `POLY_ADDRESS`
  header expects this form (the order wire body, by contrast, uses lowercase).
  """
  @spec to_checksum_address(address()) :: String.t()
  def to_checksum_address(<<_::160>> = address) do
    hex = Base.encode16(address, case: :lower)
    nibbles = Base.encode16(keccak256(hex), case: :lower)

    checksummed =
      hex
      |> String.to_charlist()
      |> Enum.zip(String.to_charlist(nibbles))
      |> Enum.map(fn {char, nibble} -> checksum_char(char, nibble) end)
      |> List.to_string()

    "0x" <> checksummed
  end

  # Upper-case an a-f hex letter when its hash nibble is >= 8 (hex 8..f); leave
  # digits and already-low nibbles untouched.
  @spec checksum_char(byte(), byte()) :: byte()
  defp checksum_char(char, nibble) when char in ?a..?f and nibble in ~c"89abcdef", do: char - 32
  defp checksum_char(char, _nibble), do: char
end
