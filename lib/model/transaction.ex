defmodule Model.Transaction do
  @moduledoc """
    transaciton module
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  @fields ~w<
    merchant
    amount
    time
    is_processed
    rejected
  >a

  @required_fields ~w<
  merchant
  amount
  time
  >a

  @primary_key false
  embedded_schema do
    field(:merchant, :string)
    field(:amount, :integer)
    field(:time, :utc_datetime)
    field(:is_processed, :boolean, virtual: true, default: false)
    field(:rejected, :boolean, virtual: true, default: false)
  end

  @spec changeset(data :: t(), params :: map()) :: Ecto.Changeset.t()
  def changeset(data \\ %__MODULE__{}, params) do
    data
    |> cast(params, @fields)
    |> validate_required(@required_fields)
  end
end
