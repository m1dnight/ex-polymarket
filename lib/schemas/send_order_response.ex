defmodule Polymarket.Schemas.SendOrderResponse do
  @moduledoc """
  A successful (`200`) response from the CLOB's `POST /order`.

  `status` is `"live"` (resting on the book), `"matched"` (filled immediately, with
  `transactions_hashes`/`trade_ids` populated) or `"delayed"`. `error_msg` is empty
  on success. Amounts are fixed-point strings with 6 decimals.
  """

  use TypedStruct

  typedstruct do
    field(:success, boolean(), default: false)
    field(:order_id, String.t() | nil, default: nil)
    field(:status, String.t() | nil, default: nil)
    field(:making_amount, String.t() | nil, default: nil)
    field(:taking_amount, String.t() | nil, default: nil)
    field(:transactions_hashes, [String.t()], default: [])
    field(:trade_ids, [String.t()], default: [])
    field(:error_msg, String.t(), default: "")
  end

  @doc """
  Builds a `SendOrderResponse` from the raw (JSON-decoded) `POST /order` body.

  Reads the API's `camelCase` keys (atom or string) leniently, filling defaults for
  anything absent.
  """
  @spec from_attrs(map()) :: t()
  def from_attrs(attrs) when is_map(attrs) do
    %__MODULE__{
      success: fetch(attrs, [:success], false),
      order_id: fetch(attrs, [:orderID], nil),
      status: fetch(attrs, [:status], nil),
      making_amount: fetch(attrs, [:makingAmount], nil),
      taking_amount: fetch(attrs, [:takingAmount], nil),
      # The reference client's canonical key is `transactionHashes`, with
      # `transactionsHashes` (and the OpenAPI doc) as an accepted variant.
      transactions_hashes: fetch(attrs, [:transactionHashes, :transactionsHashes], []),
      # camelCase `tradeIds` (reference client) vs `tradeIDs` (OpenAPI doc).
      trade_ids: fetch(attrs, [:tradeIds, :tradeIDs], []),
      error_msg: fetch(attrs, [:errorMsg], "")
    }
  end

  # Returns the first of `keys` present in `attrs` (as an atom — the HTTP layer
  # decodes to atoms — or as a string), else `default`. Halts on presence so a
  # legitimately `nil`/`false` value is returned rather than skipped.
  @spec fetch(map(), [atom()], term()) :: term()
  defp fetch(attrs, keys, default) do
    Enum.reduce_while(keys, default, fn key, acc ->
      case lookup(attrs, key) do
        {:ok, value} -> {:halt, value}
        :error -> {:cont, acc}
      end
    end)
  end

  @spec lookup(map(), atom()) :: {:ok, term()} | :error
  defp lookup(attrs, key) do
    with :error <- Map.fetch(attrs, key) do
      Map.fetch(attrs, Atom.to_string(key))
    end
  end
end
