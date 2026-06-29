defmodule Polymarket.Schemas.Series do
  @moduledoc """
  A series an `Event` belongs to, as returned by the Gamma API (e.g. nested in
  `GET /events/keyset`).

  A series groups recurring events together (e.g. all "NBA" games). The Gamma API
  delivers its keys in `camelCase`; `from_attrs/1` normalises them to the
  `snake_case` fields below. Field coverage follows the Gamma OpenAPI `Series`
  schema; the nested relational objects (`events`, `tags`, `categories`,
  `collections`, `chats`) are intentionally omitted as they are not returned when
  a series is nested inside an event.
  """

  use TypedEctoSchema

  import Ecto.Changeset

  alias Polymarket.JsonUtil
  alias Polymarket.Schemas.Series

  @primary_key false

  typed_embedded_schema do
    # Identity / description
    field(:id, :string)
    field(:ticker, :string)
    field(:slug, :string)
    field(:title, :string)
    field(:description, :string)
    field(:series_type, :string)
    field(:recurrence, :string)
    field(:layout, :string)
    field(:image, :string)
    field(:icon, :string)
    # Spec types `competitive` as a string here, unlike on `Market`/`Event`.
    field(:competitive, :string)
    field(:created_by, :string)
    field(:updated_by, :string)

    # Status flags
    field(:active, :boolean)
    field(:closed, :boolean)
    field(:archived, :boolean)
    field(:new, :boolean)
    field(:featured, :boolean)
    field(:restricted, :boolean)
    field(:comments_enabled, :boolean)
    field(:requires_translation, :boolean)

    # Counts / volume / liquidity
    field(:comment_count, :integer)
    field(:liquidity, :float)
    field(:volume, :float)
    field(:volume24hr, :float)

    # Dates
    field(:start_date, :utc_datetime_usec)
    field(:published_at, :utc_datetime_usec)
    field(:created_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(series, attrs) do
    castable = __MODULE__.__schema__(:fields) -- __MODULE__.__schema__(:embeds)

    cast(series, attrs, castable)
  end

  @doc """
  Create a `Series` from the raw (JSON-decoded) attributes returned by the Gamma
  API. Keys may be in `camelCase` (atom or string); they are normalised to the
  `snake_case` schema fields. Returns an error if the attributes are not valid.
  """
  @spec from_attrs(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def from_attrs(attrs) do
    attrs
    |> JsonUtil.snake_case_keys()
    |> then(&changeset(%Series{}, &1))
    |> case do
      %{valid?: true} = changeset ->
        {:ok, apply_changes(changeset)}

      changeset ->
        {:error, changeset}
    end
  end
end
