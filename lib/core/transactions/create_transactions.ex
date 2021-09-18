defmodule Core.Transactions.CreateTransactions do
  @moduledoc """
  Transactions module
  """

  @window_time_in_seconds 120

  alias Core.Authorizer.Model.Transaction
  alias Core.Authorizer.Model.Account
  alias Core.Authorizer.Utils.ValueObject

  def execute(account, transactions) do
    account
    |> apply!(Account)
    |> case do
      %Account{} = account ->
        account
        |> check_if_has_initialized_account()
        |> check_account_has_active_card()
        |> case do
          {:ok, account} ->
            [account]
            |> check_high_frequency_small_interval(transactions)
            |> process_settlements(transactions)

          {:error, account_with_violation} ->
            account_with_violation
        end

      {:error, _} = error ->
        error
    end
  end

  defp apply!(input, mod) do
    case ValueObject.cast_and_apply(input, mod) do
      {:ok, account} -> account
      {:error, _} -> {:error, %{violations: ["account-not-initialized"]}}
    end
  end

  defp check_if_has_initialized_account(%Account{} = account), do: {:ok, account}

  defp check_account_has_active_card({:ok, %Account{active_card: true} = account}),
    do: {:ok, account}

  defp check_account_has_active_card({:ok, %Account{active_card: false} = account}),
    do: {:error, %{account | violations: ["card-not-active"]}}

  defp process_settlements(account_log, transactions) do
    transactions
    |> Enum.reduce(account_log, fn transaction, account_log ->
      [last_account_movement | _] = account_log

      case check_limit(last_account_movement, transaction) do
        {:ok, account} -> [account | account_log]
      end
    end)
  end

  defp check_high_frequency_small_interval(account_log, transactions) do
    now = NaiveDateTime.utc_now()
    time_ago = now |> NaiveDateTime.add(-@window_time_in_seconds, :second)

    transactions
    |> Enum.with_index()
    |> Enum.reduce_while(account_log, fn {transaction, index}, account_log ->
      [account | _] = account_log

      case {is_inside_delay?(time_ago, now, transaction.time), check_limit(account, transaction)} do
        {true, {_, %Account{violations: []} = account}} when index <= 3 ->
          {:cont, [%{account | processed_in_time_window_context: true} | account_log]}

        {false, {_, %Account{violations: []} = account}} when index == 4 ->
          {:halt,
           [
             %{
               account
               | violations: ["high_frequency_small_interval"],
                 processed_in_time_window_context: true
             }
             | account_log
           ]}
      end
    end)
  end

  # defp check_doubled_transaction(account_log, transactions) do
  #   now = NaiveDateTime.utc_now()
  #   time_ago = now |> NaiveDateTime.add(-@window_time_in_seconds, :second)

  #   transactions
  #   |> Enum.reduce_while(account_log, fn transaction, account_log ->
  #     [account | _] = account_log

  #     case {is_inside_delay?(time_ago, now, transaction.time), check_limit(account, transaction)} do
  #       {true, {_, %Account{violations: []} = account}} ->
  #         {:cont, [%{account | processed_in_time_window_context: true} | account_log]}

  #       {false, {_, %Account{violations: []} = account}} ->
  #         {:halt,
  #          [
  #            %{
  #              account
  #              | violations: ["high_frequency_small_interval"],
  #                processed_in_time_window_context: true
  #            }
  #            | account_log
  #          ]}
  #     end
  #   end)
  # end

  # defp get_merchant_and_amount(account_log, transactions) do
  #   now = NaiveDateTime.utc_now()
  #   time_ago = now |> NaiveDateTime.add(-@window_time_in_seconds, :second)

  #   transactions
  #   |> Enum.reduce_while(account_log, fn transaction ->
  #     case {is_inside_delay?(time_ago, now, transaction.time), check_limit(account, transaction) do
  #       {:cont, [%{account | processed_in_time_window_context: true} | account_log]}
  #     end
  #   end)
  #   |> Enum.group_by(
  #     "#{&1.merchant}/#{&1.amount}"
  #   )
  # end

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
       when transaction_time >= time_ago and transaction_time <= now,
       do: true

  defp is_inside_delay?(_, _, _), do: false
end
