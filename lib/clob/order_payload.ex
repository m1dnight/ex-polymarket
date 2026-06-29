defmodule Polymarket.Clob.OrderPayload do
  @moduledoc """
  Serialises signed `Polymarket.Schemas.Order`s into the JSON wire body the CLOB
  expects — a single `SendOrder` object for `POST /order`, or a JSON array of them
  for the batch `POST /orders`.

  The body is produced once, as a string, so the L2 HMAC can sign exactly the bytes
  that go on the wire. Field formats mirror the reference client: `salt` is a JSON
  number; `tokenId`, `makerAmount`, `takerAmount`, `expiration` and `timestamp` are
  decimal strings; `maker`/`signer` are lowercase `0x` hex; `metadata`/`builder` are
  `0x`+64 hex; `side` is `"BUY"`/`"SELL"`; `signatureType` is a number. `expiration`
  rides on the wire body (for GTD/expiry) even though it is not part of the signed
  V2 struct.
  """

  alias Polymarket.Schemas.Order
  alias Polymarket.Schemas.SendOrder

  @doc """
  Builds the JSON `SendOrder` body string for a caller-constructed
  `Polymarket.Schemas.SendOrder` (signed order + owner + time-in-force + flags).

  `post_only`/`defer_exec` are omitted from the body when `nil`, matching the
  reference client.
  """
  @spec serialize(SendOrder.t()) :: String.t()
  def serialize(%SendOrder{} = send_order) do
    send_order |> send_order_object() |> Jason.encode!()
  end

  @doc """
  Builds the JSON array body string for the batch `POST /orders` from a list of
  caller-constructed `Polymarket.Schemas.SendOrder`s.

  Each element is the identical object `serialize/1` produces for a single order,
  in the given order. The CLOB caps a batch at 15 orders; this only serialises, so
  the server enforces that limit.
  """
  @spec serialize_many([SendOrder.t()]) :: String.t()
  def serialize_many(send_orders) when is_list(send_orders) do
    send_orders |> Enum.map(&send_order_object/1) |> Jason.encode!()
  end

  @spec send_order_object(SendOrder.t()) :: map()
  defp send_order_object(%SendOrder{} = send_order) do
    %{
      "order" => order_object(send_order.order, send_order.signature),
      "orderType" => order_type_string(send_order.order_type),
      "owner" => send_order.owner
    }
    |> maybe_put("postOnly", send_order.post_only)
    |> maybe_put("deferExec", send_order.defer_exec)
  end

  @spec order_object(Order.t(), String.t()) :: map()
  defp order_object(order, signature) do
    %{
      "salt" => order.salt,
      "maker" => address(order.maker),
      "signer" => address(order.signer),
      "tokenId" => Integer.to_string(order.token_id),
      "makerAmount" => Integer.to_string(order.maker_amount),
      "takerAmount" => Integer.to_string(order.taker_amount),
      "side" => side_string(order.side),
      "expiration" => Integer.to_string(order.expiration),
      "signatureType" => Order.signature_type_value(order.signature_type),
      "timestamp" => Integer.to_string(order.timestamp),
      "metadata" => bytes32(order.metadata),
      "builder" => bytes32(order.builder),
      "signature" => signature
    }
  end

  @spec maybe_put(map(), String.t(), boolean() | nil) :: map()
  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value) when is_boolean(value), do: Map.put(map, key, value)

  @spec address(<<_::160>>) :: String.t()
  defp address(<<_::160>> = bytes), do: "0x" <> Base.encode16(bytes, case: :lower)

  @spec bytes32(<<_::256>>) :: String.t()
  defp bytes32(<<_::256>> = bytes), do: "0x" <> Base.encode16(bytes, case: :lower)

  @spec side_string(Order.side()) :: String.t()
  defp side_string(:buy), do: "BUY"
  defp side_string(:sell), do: "SELL"

  @spec order_type_string(SendOrder.order_type()) :: String.t()
  defp order_type_string(:gtc), do: "GTC"
  defp order_type_string(:fok), do: "FOK"
  defp order_type_string(:gtd), do: "GTD"
  defp order_type_string(:fak), do: "FAK"
end
