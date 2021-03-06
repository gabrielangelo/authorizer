defmodule Core.Types.AuthorizeTransactionsHistory do
  @moduledoc """
    Athorize transactions input
  """

  @type t :: %__MODULE__{
    account_movements_log: list(),
    transactions: list(),
    transactions_log: list(),
    settled_transactions_count: integer()
  }

  defstruct account_movements_log: [], transactions: [], transactions_log: [], settled_transactions_count: 0
end
