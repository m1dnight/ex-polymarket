defmodule Polymarket.Crypto.Eip712Test do
  use ExUnit.Case, async: true

  alias Polymarket.Crypto
  alias Polymarket.Crypto.Eip712

  # The canonical "Ether Mail" worked example from https://eips.ethereum.org/EIPS/eip-712.
  @person_type "Person(string name,address wallet)"
  @mail_type "Mail(Person from,Person to,string contents)Person(string name,address wallet)"
  @mail_contract Base.decode16!("CcCcCCCcCCCCcCCCCCCcCcCccCcCCCcCcccccccC", case: :mixed)

  @spec hex(binary()) :: String.t()
  defp hex(binary), do: Base.encode16(binary, case: :lower)

  @spec person(binary(), binary()) :: <<_::256>>
  defp person(name, wallet_hex) do
    Eip712.hash_struct(@person_type, [
      Crypto.keccak256(name),
      Eip712.encode_address(Base.decode16!(wallet_hex, case: :mixed))
    ])
  end

  describe "encoders" do
    test "encode_uint256/1 left-pads to a 32-byte big-endian word" do
      assert hex(Eip712.encode_uint256(0)) == String.duplicate("0", 64)
      assert hex(Eip712.encode_uint256(1)) == String.pad_leading("1", 64, "0")
      assert hex(Eip712.encode_uint256(2 ** 256 - 1)) == String.duplicate("f", 64)
    end

    test "encode_uint256/1 rejects out-of-range values" do
      assert_raise FunctionClauseError, fn -> Eip712.encode_uint256(-1) end
      assert_raise FunctionClauseError, fn -> Eip712.encode_uint256(2 ** 256) end
    end

    test "encode_uint8/1 encodes like a uint256" do
      assert Eip712.encode_uint8(255) == Eip712.encode_uint256(255)
      assert_raise FunctionClauseError, fn -> Eip712.encode_uint8(256) end
    end

    test "encode_address/1 left-pads a 20-byte address with 12 zero bytes" do
      address = :binary.copy(<<0xFF>>, 20)
      assert hex(Eip712.encode_address(address)) == String.duplicate("0", 24) <> String.duplicate("f", 40)
    end

    test "encode_bytes32/1 passes a 32-byte value through unchanged" do
      value = :binary.copy(<<0xAB>>, 32)
      assert Eip712.encode_bytes32(value) == value
    end

    test "encode_string/1 hashes the UTF-8 bytes per EIP-712 dynamic-type rules" do
      assert Eip712.encode_string("") == Crypto.keccak256("")
      assert Eip712.encode_string("Polymarket") == Crypto.keccak256("Polymarket")
      assert byte_size(Eip712.encode_string("anything")) == 32
    end
  end

  describe "type_hash/1" do
    test "is the keccak-256 of the type string" do
      assert Eip712.type_hash(@person_type) == Crypto.keccak256(@person_type)
    end
  end

  describe "domain_separator/4" do
    test "matches the canonical EIP-712 spec example" do
      assert hex(Eip712.domain_separator("Ether Mail", "1", 1, @mail_contract)) ==
               "f2cee375fa42b42143804025fc449deafd50cc031ca257e0b194a650a912090f"
    end
  end

  describe "domain_separator/3 (no verifying contract)" do
    test "has a distinct type hash, so it differs from the 4-arg zero-contract domain" do
      without_contract = Eip712.domain_separator("ClobAuthDomain", "1", 137)
      zero_contract = Eip712.domain_separator("ClobAuthDomain", "1", 137, <<0::160>>)

      refute without_contract == zero_contract
    end

    test "depends on name, version and chain id" do
      base = Eip712.domain_separator("ClobAuthDomain", "1", 137)

      refute base == Eip712.domain_separator("OtherDomain", "1", 137)
      refute base == Eip712.domain_separator("ClobAuthDomain", "2", 137)
      refute base == Eip712.domain_separator("ClobAuthDomain", "1", 80_002)
    end
  end

  describe "digest/2 (end-to-end against the canonical EIP-712 example)" do
    # Reconstructs the full example and checks that the final signing hash matches
    # the value published in the spec. This exercises type_hash, hash_struct
    # (including nested structs), the domain separator, and the 0x1901 assembly.
    test "produces the spec's published signing hash" do
      from = person("Cow", "CD2a3d9F938E13CD947Ec05AbC7FE734Df8DD826")
      to = person("Bob", "bBbBBBBbbBBBbbbBbbBbbbbBBbBbbbbBbBbbBBbB")
      mail = Eip712.hash_struct(@mail_type, [from, to, Crypto.keccak256("Hello, Bob!")])

      domain_separator = Eip712.domain_separator("Ether Mail", "1", 1, @mail_contract)

      assert hex(Eip712.digest(domain_separator, mail)) ==
               "be609aee343fb3c4b28e1df9e632fca64fcfaede20f02e86244efddf30957bd2"
    end
  end
end
