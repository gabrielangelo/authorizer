defmodule Core.Transactions.AuthorizeTransactions do
  @moduledoc """
  Transactions module
  """

  alias Core.Accounts.Model.Account
  alias Core.Transactions.Model.Transaction
  alias Core.Utils.ValueObject

  @window_time_in_seconds 120
  @max_transactions_processed_in_window 3

  @spec execute(account :: map(), transactions :: [map()]) :: [Account.t()]
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
    data = Map.put(data, :processed_transactions_count, 0)

    transactions
    |> Enum.with_index()
    |> Enum.reduce(data, fn
      {transaction, index}, history ->
        [account | _] = accounts_movements = history.account_movements_log

        processed_transactions = history.transactions_log
        processed_transactions_count = history.processed_transactions_count

        case {
          is_inside_delay?(time_ago, now, transaction.time),
          check_limit(account, transaction)
        } do
          {true, {%Account{violations: violations}, _}}
          when processed_transactions_count == @max_transactions_processed_in_window and index > 2 ->
            new_movement_account = %{account | violations: []}

            {k_movement, transaction} =
              apply_double_transaction(transaction, new_movement_account, history, now)

            Map.merge(
              history,
              %{
                account_movements_log: [
                  Map.merge(
                    k_movement,
                    %{
                      violations:
                        ["high_frequency_small_interval" | k_movement.violations] ++ violations
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

          {true, {%Account{violations: _} = new_account_movement, transaction}} ->
            {k_movement, transaction} =
              apply_double_transaction(transaction, new_account_movement, history, now)

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

  defp apply_double_transaction(transaction, account, data, now) do
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

        {false, true, {%Account{}, _}} ->
          history
      end
    end)
  end
end
