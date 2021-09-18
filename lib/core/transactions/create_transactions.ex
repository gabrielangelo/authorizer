defmodule Core.Transactions.CreateTransactions do
  @moduledoc """
  Transactions module
  """

  @window_time_in_seconds 120

  alias Model.Transaction
  alias Model.Account
  alias Core.Authorizer.Utils.ValueObject
  alias Renders.Account, as: RendersAccount

  def execute(account, transactions) do
    now = NaiveDateTime.utc_now()

    with {:ok, account} <- ValueObject.cast_and_apply(account, Account),
         {:ok, account} <- check_if_has_initialized_account(account),
         {:ok, account} <- check_account_has_active_card(account),
         {:ok, transactions} <- apply_changes_in_transactions(transactions),
         {:ok, result} <- process_transactions(account, transactions, now) do
      RendersAccount.render(result)
    else
      {:error, %Ecto.Changeset{valid?: false}} ->
        %{"account" => %{"violations" => ["account-not-initialized"]}}

      {:error, _} = error -> error
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
     |> Enum.filter(&match?({:ok, _}, &1))}
  end

  defp process_transactions(account, transactions, now) do
    result =
      account
      |> process_settlements_with_time_window(transactions, now)
      |> process_settlements(transactions)

    {:ok, result}
  end

  defp process_settlements_with_time_window(account, transactions, now) do
    [account]
    |> check_high_frequency_small_interval(transactions, now)
    |> check_doubled_transaction(transactions, now)
  end

  defp check_high_frequency_small_interval(account_log, transactions, now) do
    time_ago = now |> NaiveDateTime.add(-@window_time_in_seconds, :second)

    transactions
    |> Enum.with_index()
    |> Enum.reduce_while(account_log, fn {transaction, index}, account_log ->
      [account | _] = account_log

      case {
        is_inside_delay?(time_ago, now, transaction.time),
        check_limit(account, transaction),
        transaction.processed_in_time_window_context
      } do
        {true, {_, %Account{violations: []} = account}, false} when index <= 3 ->
          {:cont, [%{account | processed_in_time_window_context: true} | account_log]}

        {true, {_, %Account{violations: []}}, true} when index <= 3 ->
          {:cont, account_log}

        {false, {_, %Account{violations: violations} = account}, _} when index > 3 ->
          {:halt,
           [
             %{
               account
               | violations: ["high_frequency_small_interval" | violations],
                 processed_in_time_window_context: true
             }
             | account_log
           ]}
      end
    end)
  end

  defp check_doubled_transaction(account_log, transactions, now) do
    time_ago = now |> NaiveDateTime.add(-@window_time_in_seconds, :second)
    transaction_info_log_in_last_time = get_merchant_and_amount(transactions, now)

    transactions
    |> Enum.reduce_while(account_log, fn transaction, account_log ->
      [account | _] = account_log

      case {
        is_inside_delay?(time_ago, now, transaction.time),
        check_limit(account, transaction),
        Map.get(
          transaction_info_log_in_last_time,
          "#{transaction.merchant}#{transaction.amount}",
          []
        )
      } do
        {true, {_, %Account{violations: []} = account}, []} ->
          {:cont, [%{account | processed_in_time_window_context: true} | account_log]}

        {true, {_, %Account{violations: violations} = account}, [_ | _]} ->
          {:cont,
           [
             %{
               account
               | processed_in_time_window_context: true,
                 violations: ["doubled-transaction" | violations]
             }
             | account_log
           ]}

        {false, {_, %Account{violations: []} = account}, _} ->
          {:halt,
           [
             %{
               account
               | processed_in_time_window_context: true
             }
             | account_log
           ]}
      end
    end)
  end

  defp check_limit(%Account{available_limit: available_limit} = account, %Transaction{
         amount: amount
       })
       when amount > available_limit,
       do: {:ok, %{account | violations: ["insufficient-limit"]}}

  defp check_limit(%Account{available_limit: available_limit} = account, %Transaction{
         amount: amount
       })
       when amount <= available_limit,
       do: {:ok, %{account | available_limit: available_limit - amount}}

  defp is_inside_delay?(time_ago, now, transaction_time)
       when transaction_time >= time_ago and transaction_time < now,
       do: true

  defp is_inside_delay?(_, _, _), do: false

  defp get_merchant_and_amount(transactions, now) do
    time_ago = now |> NaiveDateTime.add(-@window_time_in_seconds, :second)

    transactions
    |> Enum.reduce_while([], fn transaction, transaction_info_log ->
      case is_inside_delay?(time_ago, now, transaction.time) do
        true -> {:cont, [transaction | transaction_info_log]}
        false -> {:halt, transaction_info_log}
      end
    end)
    |> Enum.group_by(&"#{&1.merchant}/#{&1.amount}")
  end

  defp process_settlements(account_log, transactions) do
    transactions
    |> Enum.reduce(account_log, fn transaction, account_log ->
      [last_account_movement | _] = account_log

      case check_limit(last_account_movement, transaction) do
        {:ok, account} -> [account | account_log]
      end
    end)
  end
end
