defmodule Polymarket.Schemas.Tag do
  @moduledoc """
  A tag attached to a `Market` returned by the Gamma API.
  """

  use TypedEctoSchema

  import Ecto.Changeset

  @primary_key false

  typed_embedded_schema do
    field(:id, :string)
    field(:label, :string)
    field(:slug, :string)
    field(:force_show, :boolean)
    field(:force_hide, :boolean)
    field(:is_carousel, :boolean)
    field(:requires_translation, :boolean)
    field(:published_at, :utc_datetime_usec)
    field(:created_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
    field(:created_by, :integer)
    field(:updated_by, :integer)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(tag, attrs) do
    castable = __MODULE__.__schema__(:fields) -- __MODULE__.__schema__(:embeds)

    cast(tag, attrs, castable)
  end
end
