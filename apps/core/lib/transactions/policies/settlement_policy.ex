defmodule Core.Transactions.Policies.ProcessSettlementsPolicy do
  @moduledoc """
    Proess settlements policy
  """

  alias Core.Accounts.Model.Account
  alias Core.Ledger

  @spec apply(Core.Types.AuthorizeTransactionsHistory.t()) ::
          AuthorizeTransactionsInput.t()
  def apply(data) do
    data.transactions_log
    |> Enum.reduce(data, fn transaction, history ->
      [account | _] = history.account_movements_log

      processed_transactions = history.transactions_log

      case {transaction.is_settled, transaction.rejected,
            Ledger.check_limit(account, transaction)} do
        # if transaction has not been processed, so, will be
        {false, false, {%Account{} = new_account_movement, _}} ->
          is_settled = if(new_account_movement.violations == [], do: true, else: false)

          Map.merge(
            history,
            %{
              account_movements_log: [new_account_movement | history.account_movements_log],
              transactions_log: [
                %{transaction | is_settled: is_settled} | processed_transactions
              ]
            }
          )

        _ ->
          history
      end
    end)
  end
end
