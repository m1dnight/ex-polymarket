defmodule Polymarket.Clob.DepositWallet do
  @moduledoc """
  Derives a wallet's **deposit-wallet** address — the contract wallet Polymarket
  trades through on a user's behalf.

  Polymarket does not let a bare EOA be an order's `maker`; orders are made by a
  deposit wallet deterministically derived from the EOA via `CREATE2`. Two kinds
  exist, matching how the account was created:

    * a **proxy** wallet (EIP-1167 minimal proxy) for Magic/email accounts —
      `signatureType` `:proxy`; and
    * a **Gnosis Safe** (1-of-1) for browser-wallet accounts — `:gnosis_safe`.

  To place such an order, set the order's `maker` to the derived address, keep
  `signer` as the EOA, and sign with the matching `signature_type`.

  Addresses are derived as `keccak256(0xff ‖ factory ‖ salt ‖ initCodeHash)[12..]`,
  with the factory contracts and init-code hashes taken from the reference
  `rs-clob-client-v2`. Proxy wallets exist only on Polygon; Safe wallets on both
  Polygon and Amoy.
  """

  alias Polymarket.Crypto

  @polygon 137
  @amoy 80_002

  @proxy_factory %{
    @polygon => Base.decode16!("aB45c5A4B0c941a2F231C04C3f49182e1A254052", case: :mixed)
  }

  @safe_factory Base.decode16!("aacFeEa03eb1561C4e67d661e40682Bd20E3541b", case: :mixed)

  @proxy_init_code_hash Base.decode16!(
                          "d21df8dc65880a8606f09fe0ce3df9b8869287ab0b058be05aa9e8af6330a00b",
                          case: :lower
                        )

  @safe_init_code_hash Base.decode16!(
                         "2bce2127ff07fb632d16c8347c4ebf501f4841168bed00d9e6ef715ddb6fcecf",
                         case: :lower
                       )

  @doc """
  Derives the Polymarket **proxy** wallet (`signatureType` `:proxy`) for `eoa` on
  `chain_id`.

  The CREATE2 salt is `keccak256(eoa)` (the 20 address bytes, unpadded). Proxy
  wallets are only deployed on Polygon (137); other chains return `:error`.
  """
  @spec derive_proxy_wallet(<<_::160>>, integer()) :: {:ok, <<_::160>>} | :error
  def derive_proxy_wallet(<<_::160>> = eoa, chain_id) when is_integer(chain_id) do
    case Map.fetch(@proxy_factory, chain_id) do
      {:ok, factory} -> {:ok, create2(factory, Crypto.keccak256(eoa), @proxy_init_code_hash)}
      :error -> :error
    end
  end

  @doc """
  Derives the Polymarket **Gnosis Safe** wallet (`signatureType` `:gnosis_safe`)
  for `eoa` on `chain_id`.

  The CREATE2 salt is `keccak256(eoa left-padded to 32 bytes)`. Safe wallets are
  configured on Polygon (137) and Amoy (80002); other chains return `:error`.
  """
  @spec derive_safe_wallet(<<_::160>>, integer()) :: {:ok, <<_::160>>} | :error
  def derive_safe_wallet(<<_::160>> = eoa, chain_id) when chain_id in [@polygon, @amoy] do
    salt = Crypto.keccak256(<<0::96, eoa::binary>>)
    {:ok, create2(@safe_factory, salt, @safe_init_code_hash)}
  end

  def derive_safe_wallet(<<_::160>>, _chain_id), do: :error

  # CREATE2 address: the low 20 bytes of keccak256(0xff ‖ factory ‖ salt ‖ hash).
  @spec create2(<<_::160>>, <<_::256>>, <<_::256>>) :: <<_::160>>
  defp create2(factory, salt, init_code_hash) do
    <<_::binary-size(12), address::binary-size(20)>> =
      Crypto.keccak256([<<0xFF>>, factory, salt, init_code_hash])

    address
  end
end
