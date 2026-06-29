defmodule Polymarket.Schemas.ClobReward do
  @moduledoc """
  A CLOB liquidity-reward configuration attached to a `Polymarket.Schemas.Market`.

  Returned (as `clobRewards`) by the single-event Gamma endpoints
  (`GET /events/:id`, `/events/slug/:slug`); the keyset endpoint omits it.
  """

  use TypedEctoSchema

  import Ecto.Changeset

  @primary_key false

  typed_embedded_schema do
    field(:id, :string)
    field(:condition_id, :string)
    field(:asset_address, :string)
    field(:rewards_amount, :float)
    field(:rewards_daily_rate, :float)
    field(:start_date, :date)
    field(:end_date, :date)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(clob_reward, attrs) do
    castable = __MODULE__.__schema__(:fields) -- __MODULE__.__schema__(:embeds)

    cast(clob_reward, attrs, castable)
  end
end
