defmodule Polymarket.Schemas.MarketByToken do
  @moduledoc """
  The parent market for a given token ID, as returned by the CLOB API
  `GET /markets-by-token/:token_id`.

  Resolves a token ID to its market's `condition_id` and both the primary (Yes)
  and secondary (No) token IDs. The CLOB API already delivers `snake_case` keys,
  so `from_attrs/1` normalisation is a no-op here but kept for consistency with
  the other schemas.
  """

  use TypedEctoSchema

  import Ecto.Changeset

  alias Polymarket.JsonUtil
  alias Polymarket.Schemas.MarketByToken

  @primary_key false

  typed_embedded_schema do
    field(:condition_id, :string)
    field(:primary_token_id, :string)
    field(:secondary_token_id, :string)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(market, attrs) do
    castable = __MODULE__.__schema__(:fields) -- __MODULE__.__schema__(:embeds)

    market
    |> cast(attrs, castable)
    |> validate_required([:condition_id, :primary_token_id, :secondary_token_id])
  end

  @doc """
  Create a `MarketByToken` from the raw (JSON-decoded) attributes returned by the
  CLOB API. Keys may be in `camelCase` (atom or string); they are normalised to
  the `snake_case` schema fields. Returns an error if the attributes are invalid.
  """
  @spec from_attrs(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def from_attrs(attrs) do
    attrs
    |> JsonUtil.snake_case_keys()
    |> then(&changeset(%MarketByToken{}, &1))
    |> case do
      %{valid?: true} = changeset ->
        {:ok, apply_changes(changeset)}

      changeset ->
        {:error, changeset}
    end
  end
end
