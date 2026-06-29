defmodule Polymarket.Schemas.SendOrder do
  @moduledoc """
  The exact `POST /order` request payload — a signed order plus its routing
  metadata — mirroring the CLOB `SendOrder` object.

  The caller constructs every value: sign the `order` with
  `Polymarket.Clob.OrderSigner` and put the resulting `signature` here, set `owner`
  to your API-key UUID, and choose the `order_type` and optional flags. Hand the
  finished struct to `Polymarket.Clob.post_order/3`, which only serialises,
  authenticates and transmits it.

  `signature` is the `0x`-prefixed order signature; `order_type` is the time in
  force (`:gtc` default). `post_only`/`defer_exec` are omitted from the wire body
  when left `nil`.
  """

  use TypedStruct

  alias Polymarket.Schemas.Order

  @typedoc "Time-in-force for an order: GTC, FOK, GTD or FAK."
  @type order_type :: :gtc | :fok | :gtd | :fak

  typedstruct do
    field(:order, Order.t(), enforce: true)
    field(:signature, String.t(), enforce: true)
    field(:owner, String.t(), enforce: true)
    field(:order_type, order_type(), default: :gtc)
    field(:post_only, boolean() | nil, default: nil)
    field(:defer_exec, boolean() | nil, default: nil)
  end
end
