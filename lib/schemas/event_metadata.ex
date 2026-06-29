defmodule Polymarket.Schemas.EventMetadata do
  @moduledoc """
  Internal metadata attached to an `Event` returned by the Gamma API.
  """

  use TypedEctoSchema

  import Ecto.Changeset

  @primary_key false

  typed_embedded_schema do
    field(:context_requires_regen, :boolean)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(metadata, attrs) do
    castable = __MODULE__.__schema__(:fields) -- __MODULE__.__schema__(:embeds)

    cast(metadata, attrs, castable)
  end
end
