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
  @spec apply(Core.Types.AuthorizeTransactionsHistory.t(), DateTime.t()) ::
          AuthorizeTransactionsInput.t()
  def apply(data, now) do
    %{
      last_transactions: %{now: last_transactions_now, transactions: last_transactions},
      old_transactions: %{now: old_transaction_now, transactions: old_transactions}
    } = set_times(now, data.transactions)

    data
    |> Map.put(:transactions, old_transactions)
    |> apply_policy(old_transaction_now |> DateTime.add(:timer.minutes(2), :millisecond))
    |> Map.put(:transactions, last_transactions)
    |> apply_policy(last_transactions_now)
  end

  defp apply_policy(data, now) do
    time_ago = now |> DateTime.add(:timer.minutes(@window_time_in_minutes) * -1, :second)

    data.transactions
    |> Enum.with_index()
    |> Enum.reduce(data, fn
      {transaction, index}, history ->
        [account | _] = accounts_movements = history.account_movements_log

        # acummulated transactions
        processed_transactions = history.transactions_log

        case {
          is_inside_time_window?(time_ago, now, transaction.time),
          Ledger.check_limit(account, transaction)
        } do
          {true, {%Account{violations: _} = new_account_movement, transaction_processed}} ->
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

  defp set_times(now, transactions) do
    time_ago = now |> DateTime.add(:timer.minutes(@window_time_in_minutes) * -1, :millisecond)

    case check_time_line(time_ago, transactions) do
      {[], [_ | _] = last_transactions} ->
        %{
          last_transactions: %{now: now, transactions: last_transactions},
          old_transactions: %{now: now, transactions: []}
        }

      {[_ | _] = old_transactions, []} ->
        [last_old_transaction | _] = old_transactions

        %{
          last_transactions: %{now: now, transactions: []},
          old_transactions: %{now: last_old_transaction.time, transactions: old_transactions}
        }

      {old_transactions, last_transactions}
      when old_transactions != [] and last_transactions != [] ->
        [last_old_transaction | _] = old_transactions

        %{
          last_transactions: %{now: now, transactions: last_transactions},
          old_transactions: %{now: last_old_transaction.time, transactions: old_transactions}
        }

      {[], []} ->
        %{
          last_transactions: %{now: now, transactions: []},
          old_transactions: %{now: now, transactions: []}
        }
    end
  end

  defp check_time_line(time_ago, transactions) do
    time_ago = DateTime.truncate(time_ago, :second)

    result =
      Enum.reduce(transactions, %{old_transactions: [], actual_transactions: []}, fn transaction,
                                                                                     acc ->
        transaction_time = DateTime.truncate(transaction.time, :millisecond)

        less_time_ago = DateTime.compare(transaction_time, time_ago) == :lt

        if less_time_ago do
          Map.put(acc, :old_transactions, [transaction | acc.old_transactions])
        else
          Map.put(acc, :actual_transactions, [transaction | acc.actual_transactions])
        end
      end)

    {Enum.reverse(result.old_transactions), Enum.reverse(result.actual_transactions)}
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

    bigger_or_equal  =
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
