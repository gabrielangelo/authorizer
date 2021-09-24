defmodule Core.Transactions.Policies.TimeWindow do
  @moduledoc """
    Time window policy
  """

  alias Core.Accounts.Model.Account
  alias Core.Ledger

  @max_transactions_processed_in_window 3
  @window_time_in_minutes 2

  @doc """
    Process the transactions that are inside the window interval
    the transactions_log is the list of operations rejected or processed.
    account_movements_log is the list of each operation applied to an account, so each
    account movement will be increased here.
    transactions with status processed=true are operations settled
  """
  @spec apply(Core.Types.AuthorizeTransactionsHistory.t()) ::
          AuthorizeTransactionsInput.t()
  def apply(data) do

    {initial_time, end_time, [transactions_in_last_minutes, transactions_outer_limit]} =
      get_transactions_within_time_interval(data.transactions)

    applied_data =
      data
      |> Map.put(:transactions, transactions_in_last_minutes)
      |> apply_policy_2(initial_time, end_time)

    Map.merge(data, %{
      transactions_log: applied_data.transactions_log ++ transactions_outer_limit,
      account_movements_log: applied_data.account_movements_log
    })
  end

  def get_transactions_within_time_interval(transactions) do
    [transaction | _] = transactions
    initial_time = transaction.time
    end_time = DateTime.add(transaction.time, :timer.minutes(@window_time_in_minutes), :millisecond)

    items =
      Enum.reduce(
        transactions,
        %{transactions_in_last_minutes: [], transactions_outer_limit: []},
        fn transaction, acc ->
          case is_inside_time_window?(initial_time, end_time, transaction.time) do
            true ->
              Map.put(acc, :transactions_in_last_minutes, [
                transaction | acc.transactions_in_last_minutes
              ])

            false ->
              Map.put(acc, :transactions_outer_limit, [transaction | acc.transactions_outer_limit])
          end
        end
      )
      |> Enum.map(fn {_, list} -> Enum.reverse(list) end)

    {initial_time, end_time, items}
  end

  defp apply_policy_2(data, time_ago, now) do
    data.transactions
    |> Enum.with_index()
    |> Enum.reduce(data, fn
      {transaction, index}, history ->
        [account | _] = accounts_movements = history.account_movements_log

        # acummulated transactions
        processed_transactions = history.transactions_log

        case Ledger.check_limit(account, transaction) do
          {%Account{violations: _} = new_account_movement, transaction_processed} ->
            # apply time window policy
            {%Account{violations: violations} = applied_account_movement, transaction} =
              %{
                transaction: transaction_processed,
                account: new_account_movement,
                now: now,
                processed_transactions_count: history.processed_transactions_count,
                index: index,
                transactions_log: history.transactions_log,
                result: nil,
                time_ago: time_ago
              }
              |> apply_time_window_policies()

            # credo:disable-for-lines:6
            applied_account_movement =
              if violations != [] do
                %{account | violations: violations}
              else
                applied_account_movement
              end

            # increases the history
            if transaction.rejected do
              Map.merge(history, %{
                account_movements_log: [applied_account_movement | accounts_movements],
                transactions_log: [transaction | processed_transactions]
              })
            else
              Map.merge(history, %{
                account_movements_log: [new_account_movement | accounts_movements],
                transactions_log: [
                  %{transaction | is_processed: true} | processed_transactions
                ],
                processed_transactions_count: history.processed_transactions_count + 1
              })
            end
        end
    end)
  end

  defp apply_time_window_policies(data) do
    data
    |> apply_high_frequency_small_interval_transaction_policy()
    |> apply_double_transaction_policy()
    |> Map.get(:result)
  end

  defp apply_high_frequency_small_interval_transaction_policy(
         %{
           transaction: transaction,
           account: account,
           processed_transactions_count: processed_transactions_count,
           index: index
         } = data
       ) do
    result =
      if processed_transactions_count == @max_transactions_processed_in_window and index > 2 do
        {
          %{account | violations: ["high_frequency_small_interval" | account.violations]},
          %{transaction | rejected: true}
        }
      else
        {account, transaction}
      end

    Map.put(data, :result, result)
  end

  defp get_merchant_and_amount(transactions, now, time_ago) do
    transactions
    |> Enum.reduce([], fn transaction, transaction_info_log ->
      if is_inside_time_window?(time_ago, now, transaction.time) do
        [transaction | transaction_info_log]
      else
        transaction_info_log
      end
    end)
    |> Enum.group_by(&"#{&1.merchant}/#{&1.amount}")
  end

  defp is_inside_time_window?(time_ago, now, transaction_time) do
    transaction_time = DateTime.truncate(transaction_time, :second)

    bigger_or_equal =
      DateTime.compare(transaction_time, time_ago) == :eq or
        DateTime.compare(transaction_time, time_ago) == :gt

    less_than = DateTime.compare(transaction_time, now) == :lt

    if bigger_or_equal and less_than do
      true
    else
      false
    end
  end

  defp apply_double_transaction_policy(
         %{
           transactions_log: transactions_log,
           now: now,
           result: result,
           time_ago: time_ago
         } = data
       ) do
    # transactions indexed by #{transaction.merchant}/#{transaction.amount}"
    transaction_info_log_in_last_time = get_merchant_and_amount(transactions_log, now, time_ago)
    {account, transaction} = result

    result =
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

    Map.put(data, :result, result)
  end
end
