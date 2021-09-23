defmodule Core.Types.AuthorizeTransactionsHistory do
  @moduledoc """
    Athorize transactions input
  """

  @type t :: %__MODULE__{
    account_movements_log: list(),
    transactions: list(),
    transactions_log: list()
  }

  defstruct account_movements_log: [], transactions: [], transactions_log: []
end
