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
      account
      |> process_settlements_with_time_window(transactions, now)
      |> process_settlements()

    {:ok, result}
  end

  defp process_settlements_with_time_window(account, transactions, now) do
    %{account_movements_log: [account], transactions_log: transactions}
    |> check_high_frequency_small_interval(now)

    # |> IO.inspect(label: :check_high_frequency_small_interval)

    # |> check_doubled_transaction(now)
  end

  defp check_high_frequency_small_interval(data, now) do
    time_ago = now |> DateTime.add(-@window_time_in_seconds, :second)
    # account_movement_log = data.account_movements_log
    transactions_log = data.transactions_log
    # processed_transactions = []

    transactions_log
    |> Enum.with_index()
    |> Enum.reduce(data, fn
      {transaction, index}, history ->
        accounts_movements = history.account_movements_log
        processed_transactions = history.transactions_log

        [account | _] = accounts_movements

        IO.inspect(
          {
            is_inside_delay?(time_ago, now, transaction.time),
            check_limit(account, transaction),
            transaction.processed_in_time_window_context
          }
        )
        case {
          is_inside_delay?(time_ago, now, transaction.time),
          check_limit(account, transaction),
          transaction.processed_in_time_window_context
        } do
          {true, %Account{violations: []} = account, false} when index <= 2 ->
            Map.merge(history, %{
              account_movements_log: [account | accounts_movements],
              transactions_log: [
                %{transaction | processed_in_time_window_context: true} | processed_transactions
              ]
            })

          {true, %Account{violations: []}, true} when index <= 2 ->
            Map.merge(history, %{
              account_movements_log: [account | accounts_movements],
              transactions_log: [transaction | processed_transactions]
            })

          {true, %Account{violations: violations} = account, false} when index > 2 ->
            Map.merge(
              history,
              %{
                account_movements_log: [
                  # Map.merge(
                  #   account,
                  #   %{
                  #     violations: [],
                  #     available_limit: account.available_limit + transaction.amount
                  #   }
                  # ),
                  Map.merge(
                    account,
                    %{
                      violations: ["high_frequency_small_interval" | violations],
                      available_limit: account.available_limit + transaction.amount
                    }
                  )
                  | accounts_movements
                ],
                transactions_log: [
                  %{transaction | processed_in_time_window_context: true}
                  | processed_transactions
                ]
              }
            )

          {false, %Account{violations: []}, _} when index <= 2 ->
            Map.merge(history, %{
              account_movements_log: [account | accounts_movements],
              transactions_log: [transaction | processed_transactions]
            })

          {false, %Account{} = account, false} when index > 2 ->
            Map.merge(
              history,
              %{
                account_movements_log: [account | accounts_movements],
                transactions_log: [transaction | processed_transactions]
              }
            )
        end
    end)
  end

  defp check_doubled_transaction(data, now) do
    time_ago = now |> DateTime.add(-@window_time_in_seconds, :second)
    account_movement_log = data.account_movements_log
    transactions_log = data.transactions_log
    processed_transactions = []

    transaction_info_log_in_last_time = get_merchant_and_amount(transactions_log, now)
    # |> IO.inspect(label: :transaction_info_log_in_last_time)

    transactions_log
    |> Enum.reduce_while(data, fn transaction, history ->
      [account | _] = history.account_movements_log

      # IO.inspect(
      #   {is_inside_delay?(time_ago, now, transaction.time), check_limit(account, transaction),
      #    Map.get(
      #      transaction_info_log_in_last_time,
      #      "#{transaction.merchant}#{transaction.amount}",
      #      []
      #    )}
      # )

      case {
        is_inside_delay?(time_ago, now, transaction.time),
        check_limit(account, transaction),
        Map.get(
          transaction_info_log_in_last_time,
          "#{transaction.merchant}#{transaction.amount}",
          []
        )
      } do
        {true, %Account{violations: []} = account, []} ->
          {:cont,
           Map.merge(history, %{
             account_movements_log: [account | account_movement_log],
             transactions_log: [
               %{transaction | processed_in_time_window_context: true} | processed_transactions
             ]
           })}

        {true, %Account{violations: violations} = account, [_ | _]} ->
          account_movement = %{
            account
            | processed_in_time_window_context: true,
              violations: ["doubled-transaction" | violations]
          }

          {:cont,
           Map.merge(history, %{
             account_movements_log: [account_movement | account_movement_log],
             transactions_log: [
               %{transaction | processed_in_time_window_context: true} | processed_transactions
             ]
           })}

        {false, _, _} ->
          {:cont,
           Map.merge(history, %{
             account_movements_log: account_movement_log,
             transactions_log: [
               %{transaction | processed_in_time_window_context: true} | processed_transactions
             ]
           })}
      end
    end)
  end

  defp check_limit(%Account{available_limit: available_limit} = account, %Transaction{
         amount: amount
       })
       when amount > available_limit,
       do: %{account | violations: ["insufficient-limit"]}

  defp check_limit(%Account{available_limit: available_limit} = account, %Transaction{
         amount: amount
       })
       when amount <= available_limit,
       do: %{account | available_limit: available_limit - amount}

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
    |> Enum.reduce_while([], fn transaction, transaction_info_log ->
      if is_inside_delay?(time_ago, now, transaction.time) do
        {:cont, [transaction | transaction_info_log]}
      else
        {:cont, transaction_info_log}
      end
    end)
    |> Enum.group_by(&"#{&1.merchant}/#{&1.amount}")
  end

  defp process_settlements(data) do
    account_movement_log = data.account_movements_log
    transactions_log = data.transactions_log
    processed_transactions = []

    transactions_log
    |> Enum.reduce(data, fn transaction, history ->
      [account | _] = account_movement_log

      case {transaction.processed_in_time_window_context, check_limit(account, transaction)} do
        {true, _} ->
          history

        {false, %Account{}} ->
          Map.merge(
            history,
            %{
              account_movements_log: [account | account_movement_log],
              transactions_log: [
                %{transaction | processed_in_time_window_context: true} | processed_transactions
              ]
            }
          )
      end
    end)
  end
end
