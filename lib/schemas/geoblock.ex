defmodule Polymarket.Schemas.Geoblock do
  @moduledoc """
  The geoblock status for the caller, as returned by `GET /api/geoblock` on the
  Polymarket site (https://polymarket.com).

  Reports whether the request is `blocked`, along with the detected `ip`,
  `country`, and `region`. The keys arrive already lower-cased, so `from_attrs/1`
  normalisation is a no-op here but kept for consistency with the other schemas.
  """

  use TypedEctoSchema

  import Ecto.Changeset

  alias Polymarket.JsonUtil
  alias Polymarket.Schemas.Geoblock

  @primary_key false

  typed_embedded_schema do
    field(:blocked, :boolean)
    field(:ip, :string)
    field(:country, :string)
    field(:region, :string)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(geoblock, attrs) do
    castable = __MODULE__.__schema__(:fields) -- __MODULE__.__schema__(:embeds)

    geoblock
    |> cast(attrs, castable)
    |> validate_required([:blocked])
  end

  @doc """
  Create a `Geoblock` from the raw (JSON-decoded) attributes returned by the
  geoblock endpoint. Keys may be in `camelCase` (atom or string); they are
  normalised to the `snake_case` schema fields. Returns an error if the
  attributes are invalid (e.g. the `blocked` flag is missing).
  """
  @spec from_attrs(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def from_attrs(attrs) do
    attrs
    |> JsonUtil.snake_case_keys()
    |> then(&changeset(%Geoblock{}, &1))
    |> case do
      %{valid?: true} = changeset ->
        {:ok, apply_changes(changeset)}

      changeset ->
        {:error, changeset}
    end
  end
end
