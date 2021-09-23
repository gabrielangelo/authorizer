defmodule Core.Transactions.AuthorizeTransactions do
  @moduledoc """
    Module that authorize transactions
  """

  alias Core.Accounts.Model.Account
  alias Core.Transactions.Model.Transaction
  alias Core.Utils.ValueObject

  require Logger

  @window_time_in_seconds 120
  @max_transactions_processed_in_window 3

  @spec execute(account :: map(), transactions :: [map()]) :: [Account.t()] | {:error, any()}
  def execute(account, transactions) do
    now = DateTime.utc_now()
    account = account || %{}

    with {:ok, account} <- ValueObject.cast_and_apply(account, Account),
         {:ok, transactions} <- apply_changes_in_transactions(transactions),
         {:ok, result} <- process_transactions(account, transactions, now) do
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

  # Mounts the data structure, this means like a 'history' od transactions
  # The data map will be incremented between the transacion's processing pipelines.
  defp process_transactions(account, transactions, now) do
    data = %{account_movements_log: [account], transactions: transactions, transactions_log: []}

    result =
      data
      |> process_transactions_with_time_window(now)
      |> process_transactions_outside_the_time_window()

    {:ok, result}
  end

  # Process the transactions that are inside the window interval
  # the transactions_log is the list of operations rejected or processed.
  # account_movements_log is the list of each operation applied to an account, so each
  #  account movement will be increased here.
  # transactions with status processed=true are operations settled

  defp process_transactions_with_time_window(data, now) do
    time_ago = now |> DateTime.add(-@window_time_in_seconds, :second)
    transactions = data.transactions
    data = Map.put(data, :processed_transactions_count, 0)

    transactions
    |> Enum.with_index()
    |> Enum.reduce(data, fn
      {transaction, index}, history ->
        [account | _] = accounts_movements = history.account_movements_log

        # acummulated transactions
        processed_transactions = history.transactions_log

        case {
          is_inside_time_window?(time_ago, now, transaction.time),
          check_limit(account, transaction)
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
                result: nil
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

  defp apply_double_transaction_policy(
         %{
           transactions_log: transactions_log,
           now: now,
           result: result
         } = data
       ) do
    # transactions indexed by #{transaction.merchant}/#{transaction.amount}"
    transaction_info_log_in_last_time = get_merchant_and_amount(transactions_log, now)
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

  defp check_limit(%Account{active_card: false} = account, %Transaction{} = transaction),
    do: {%{account | violations: ["card-not-active"]}, %{transaction | rejected: true}}

  defp check_limit(
         %Account{available_limit: available_limit, violations: _} = account,
         %Transaction{
           amount: amount
         } = transaction
       )
       when amount > available_limit,
       do: {%{account | violations: ["insufficient-limit"]}, %{transaction | rejected: true}}

  defp check_limit(
         %Account{available_limit: available_limit, violations: []} = account,
         %Transaction{
           amount: amount
         } = transaction
       )
       when amount <= available_limit,
       do: {%{account | available_limit: available_limit - amount}, transaction}

  defp check_limit(
         %Account{available_limit: available_limit, violations: [_ | _]} = account,
         %Transaction{
           amount: amount
         } = transaction
       )
       when amount <= available_limit,
       do: {%{account | available_limit: available_limit - amount, violations: []}, transaction}

  defp is_inside_time_window?(time_ago, now, transaction_time) do
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
      if is_inside_time_window?(time_ago, now, transaction.time) do
        [transaction | transaction_info_log]
      else
        transaction_info_log
      end
    end)
    |> Enum.group_by(&"#{&1.merchant}/#{&1.amount}")
  end

  defp process_transactions_outside_the_time_window(data) do
    account_movement_log = data.account_movements_log

    data.transactions_log
    |> Enum.reduce(data, fn transaction, history ->
      [account | _] = account_movement_log

      processed_transactions = history.transactions_log

      case {transaction.is_processed, transaction.rejected, check_limit(account, transaction)} do
        # if transaction has not been processed, so, will be
        {false, false, {%Account{} = new_account_movement, _}} ->
          is_processed = if(new_account_movement.violations == [], do: true, else: false)

          Map.merge(
            history,
            %{
              account_movements_log: [new_account_movement | history.account_movements_log],
              transactions_log: [
                %{transaction | is_processed: is_processed} | processed_transactions
              ]
            }
          )

        _ ->
          history
      end
    end)
  end
end
