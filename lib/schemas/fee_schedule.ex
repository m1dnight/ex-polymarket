defmodule Polymarket.Schemas.FeeSchedule do
  @moduledoc """
  Fee schedule for a market. Part of a NewMarketEvent.
  """

  use TypedEctoSchema

  import Ecto.Changeset

  @primary_key false

  @derive Jason.Encoder
  typed_embedded_schema do
    field(:exponent, :float)
    field(:rate, :float)
    field(:rebate_rate, :float)
    field(:taker_only, :boolean)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(fee_schedule, attrs) do
    castable = __MODULE__.__schema__(:fields) -- __MODULE__.__schema__(:embeds)

    cast(fee_schedule, attrs, castable)
  end
end
