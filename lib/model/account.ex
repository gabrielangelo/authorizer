defmodule Model.Account do
  @moduledoc """
  Account module
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @fields ~w<
    virtual_id
    active_card
    available_limit
    violations
  >a

  @required_fields ~w<
    active_card
    available_limit
  >a

  @primary_key false
  embedded_schema do
    field(:virtual_id, Ecto.UUID)
    field(:active_card, :boolean)
    field(:available_limit, :integer)
    field(:violations, {:array, :any}, default: [])
  end

  @spec changeset(data :: t(), params :: map()) :: Ecto.Changeset.t()
  def changeset(data \\ %__MODULE__{}, params) do
    data
    |> cast(params, @fields)
    |> validate_required(@required_fields)
  end
end
