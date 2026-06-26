defmodule Polymarket.Schemas.TickSizeChangeEvent do
  @moduledoc """
  Tick size change event. Announces that the minimum price increment for an
  asset has changed.
  """

  use TypedEctoSchema

  import Ecto.Changeset

  alias Polymarket.Schemas.TickSizeChangeEvent

  @primary_key false

  typed_embedded_schema do
    field(:market, :string)
    field(:asset_id, :string)
    field(:old_tick_size, :float)
    field(:new_tick_size, :float)
    # Unix epoch in milliseconds, delivered as a string (e.g. "1782553314962").
    field(:timestamp, :integer)
    field(:event_type, :string)
  end

  @doc false
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:market, :asset_id, :old_tick_size, :new_tick_size, :timestamp, :event_type])
    |> validate_required([
      :market,
      :asset_id,
      :old_tick_size,
      :new_tick_size,
      :timestamp,
      :event_type
    ])
  end

  @doc """
  Create a `TickSizeChangeEvent` from the given map of attributes. Returns an error
  if the attributes are not valid.
  """
  @spec from_attrs(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def from_attrs(attrs) do
    %TickSizeChangeEvent{}
    |> changeset(attrs)
    |> case do
      %{valid?: true} = changeset ->
        {:ok, apply_changes(changeset)}

      changeset ->
        {:error, changeset}
    end
  end
end
