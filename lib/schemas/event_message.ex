defmodule Polymarket.Schemas.EventMessage do
  @moduledoc """
  Event message describing the parent event of a market. Part of a NewMarketEvent.
  """

  use TypedEctoSchema

  import Ecto.Changeset

  @primary_key false

  typed_embedded_schema do
    field(:id, :string)
    field(:description, :string)
    field(:title, :string)
    field(:ticker, :string)
    field(:slug, :string)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(event_message, attrs) do
    cast(event_message, attrs, [:id, :description, :title, :ticker, :slug])
  end
end
