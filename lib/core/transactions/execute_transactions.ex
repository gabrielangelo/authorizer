defmodule Core.Transactions.ExecuteTransactions do
  @moduledoc """
  Transactions module
  """

  @window_time_in_seconds 120

  alias Model.Transaction
  alias Model.Account
  alias Core.Authorizer.Utils.ValueObject
  alias Renders.Account, as: RendersAccount

  def execute(account, transactions) do
    now = DateTime.utc_now()

    with {:ok, account} <- ValueObject.cast_and_apply(account, Account),
         {:ok, account} <- check_if_has_initialized_account(account),
         {:ok, account} <- check_account_has_active_card(account),
         {:ok, transactions} <- apply_changes_in_transactions(transactions),
         {:ok, result} <- process_transactions(account, transactions, now) do
      RendersAccount.render(result.account_movements_log)
    else
      {:error, %Ecto.Changeset{valid?: false}} ->
        %{"account" => %{"violations" => ["account-not-initialized"]}}

      {:error, _} = error ->
        error
    end
  end

  defp check_if_has_initialized_account(%Account{} = account), do: {:ok, account}

  defp check_account_has_active_card(%Account{active_card: true} = account),
    do: {:ok, account}

  defp check_account_has_active_card(%Account{active_card: false} = account),
    do: {:error, %{account | violations: ["card-not-active"]}}

  defp apply_changes_in_transactions(transactions) do
    {:ok,
     transactions
     |> Enum.map(&ValueObject.cast_and_apply(&1, Transaction))
     |> Enum.filter(&match?({:ok, _}, &1))
     |> Enum.map(&elem(&1, 1))}
  end

  defp process_transactions(account, transactions, now) do
    result =
      %{account_movements_log: [account], transactions: transactions, transactions_log: []}
      |> process_settlements_with_time_window(now)
      |> process_settlements()

    {:ok, result}
  end

  defp process_settlements_with_time_window(data, now) do
    time_ago = now |> DateTime.add(-@window_time_in_seconds, :second)
    transactions = data.transactions
    data = Map.put(data, :cont, 0)

    transactions
    |> Enum.with_index()
    |> Enum.reduce(data, fn
      {transaction, index}, history ->
        [account | _] = accounts_movements = history.account_movements_log

        processed_transactions = history.transactions_log
        cont = history.cont

        # IO.inspect({
        #   is_inside_delay?(time_ago, now, transaction.time),
        #   transaction,
        #   check_limit(account, transaction),
        #   cont,
        #   index
        # })
        # IO.inspect("##############################################")

        case {
          is_inside_delay?(time_ago, now, transaction.time),
          check_limit(account, transaction)
        } do
          {true, %Account{violations: violations}} when cont == 3 and index > 2 ->
            Map.merge(
              history,
              %{
                account_movements_log: [
                  Map.merge(
                    account,
                    %{
                      violations: ["high_frequency_small_interval" | violations]
                    }
                  )
                  | accounts_movements
                ],
                transactions_log: [
                  %{transaction | rejected: true}
                  | processed_transactions
                ]
              }
            )

          {true, %Account{violations: _} = new_account_movement} when cont <= 3 ->
            {k_movement, transaction} = c_double_transaction(transaction, account, history, now)

            if transaction.rejected do
              Map.merge(history, %{
                account_movements_log: [k_movement | accounts_movements],
                transactions_log: [transaction | processed_transactions]
              })
            else
              Map.merge(history, %{
                account_movements_log: [new_account_movement | accounts_movements],
                transactions_log: [
                  %{transaction | is_processed: true} | processed_transactions
                ],
                cont: history.cont + 1
              })
            end

          {false, _} ->
            Map.merge(
              history,
              %{
                transactions_log: [
                  transaction
                  | processed_transactions
                ]
              }
            )
        end
    end)
  end

  defp c_double_transaction(transaction, account, data, now) do
    transaction_info_log_in_last_time = get_merchant_and_amount(data.transactions_log, now)

    case Map.get(
           transaction_info_log_in_last_time,
           "#{transaction.merchant}/#{transaction.amount}",
           []
         ) do
      [_ | _] ->
        {
          %{account | violations: ["doubled-transaction" | account.violations]},
          %{transaction | rejected: true}
        }

      [] ->
        {account, transaction}
    end
  end

  defp check_limit(
         %Account{available_limit: available_limit, violations: violations} = account,
         %Transaction{
           amount: amount
         }
       )
       when amount > available_limit,
       do: %{account | violations: ["insufficient-limit" | violations]}

  defp check_limit(
         %Account{available_limit: available_limit, violations: []} = account,
         %Transaction{
           amount: amount
         }
       )
       when amount <= available_limit,
       do: %{account | available_limit: available_limit - amount}

  defp check_limit(
         %Account{available_limit: available_limit, violations: [_ | _]} = account,
         %Transaction{
           amount: amount
         }
       )
       when amount <= available_limit,
       do: %{account | available_limit: available_limit - amount, violations: []}

  defp is_inside_delay?(time_ago, now, transaction_time) do
    time_ago = DateTime.truncate(time_ago, :millisecond)
    now = DateTime.truncate(now, :millisecond)
    transaction_time = DateTime.truncate(transaction_time, :millisecond)

    bigger_or_equal =
      DateTime.compare(time_ago, transaction_time) == :eq or
        DateTime.compare(time_ago, transaction_time) == :gt

    less_than = DateTime.compare(transaction_time, now) == :lt

    if bigger_or_equal and less_than do
      true
    else
      false
    end
  end

  defp get_merchant_and_amount(transactions, now) do
    time_ago = now |> DateTime.add(-@window_time_in_seconds, :second)

    transactions
    |> Enum.reduce([], fn transaction, transaction_info_log ->
      if is_inside_delay?(time_ago, now, transaction.time) do
        [transaction | transaction_info_log]
      else
        transaction_info_log
      end
    end)
    |> Enum.group_by(&"#{&1.merchant}/#{&1.amount}")
  end

  defp process_settlements(data) do
    account_movement_log = data.account_movements_log

    data.transactions_log
    |> Enum.reduce(data, fn transaction, history ->
      [account | _] = account_movement_log
      processed_transactions = history.transactions_log

      case {transaction.is_processed, transaction.rejected, check_limit(account, transaction)} do
        {true, false, _} ->
          history

        {false, false, %Account{} = new_account_movement} ->
          Map.merge(
            history,
            %{
              account_movements_log: [new_account_movement | account_movement_log],
              transactions_log: [
                %{transaction | is_processed: true} | processed_transactions
              ]
            }
          )

        {false, true, %Account{}} ->
          history
      end
    end)
  end
end
