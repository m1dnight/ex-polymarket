defmodule Polymarket.Schemas.EventMetadata do
  @moduledoc """
  Internal metadata attached to an `Event` returned by the Gamma API.
  """

  use TypedEctoSchema

  import Ecto.Changeset

  @primary_key false

  typed_embedded_schema do
    field(:context_requires_regen, :boolean)
    field(:context_description, :string)
    field(:context_updated_at, :utc_datetime_usec)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(metadata, attrs) do
    castable = __MODULE__.__schema__(:fields) -- __MODULE__.__schema__(:embeds)

    cast(metadata, attrs, castable)
  end
end
