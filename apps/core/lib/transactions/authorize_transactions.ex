defmodule Core.Transactions.AuthorizeTransactions do
  @moduledoc """
    Module that authorize transactions
  """
  alias Core.Accounts.Model.Account

  alias Core.Transactions.Model.Transaction
  alias Core.Transactions.Policies.TimeWindow, as: TimeWindowPolicy
  alias Core.Transactions.Policies.WithdrawFunds, as: WithdrawFundsPolicy


  alias Core.Utils.ValueObject

  require Logger

  @spec execute(account :: map(), transactions :: [map()]) :: [Account.t()] | {:error, any()}
  def execute(account, transactions) do
    account = account || %{}

    with {:ok, account} <- ValueObject.cast_and_apply(account, Account),
         {:ok, transactions} <- apply_changes_in_transactions(transactions),
         {:ok, result} <- process_transactions(account, transactions) do
      Enum.reverse(result.account_movements_log)
    else
      {:error, %Ecto.Changeset{valid?: false}} ->
        Enum.map(1..length(transactions), fn _ ->
          %Account{violations: ["account-not-initialized"]}
        end)

      {:error, _} = error ->
        error
    end
  end

  defp apply_changes_in_transactions(transactions) do
    {:ok,
     transactions
     |> Enum.map(&ValueObject.cast_and_apply(&1, Transaction))
     |> Enum.filter(&match?({:ok, _}, &1))
     |> Enum.map(&elem(&1, 1))}
  end

  defp process_transactions(account, transactions) do
    # build  the data structure, this means like a 'history' of transactions
    data = %Core.Types.AuthorizeTransactionsHistory{
      account_movements_log: [account],
      transactions: transactions,
      transactions_log: []
    }

    result =
      data
      |> TimeWindowPolicy.apply()
      |> WithdrawFundsPolicy.apply()

    {:ok, result}
  end
end
