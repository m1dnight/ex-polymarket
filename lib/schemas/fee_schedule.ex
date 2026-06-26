defmodule Polymarket.Schemas.FeeSchedule do
  @moduledoc """
  Fee schedule for a market. Part of a NewMarketEvent.
  """

  use TypedEctoSchema

  import Ecto.Changeset

  @primary_key false

  typed_embedded_schema do
    field(:exponent, :float)
    field(:rate, :float)
    field(:rebate_rate, :float)
    field(:taker_only, :boolean)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(fee_schedule, attrs) do
    cast(fee_schedule, attrs, [:exponent, :rate, :rebate_rate, :taker_only])
  end
end
