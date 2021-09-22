defmodule Cli.Readers.AuhtorizerReader do
  @moduledoc """
    Read entries in auhtorizer
  """

  require Logger

  def re([]), do: []

  def re(data) do
    Logger.info("Mounting authorizer data")
    [f_item | head] = data

    test =
      case read_first_item(f_item, head) do
        {%{}, _, "non_initialized_accounts_with_transactions"} = item ->
          [item]

        _ ->
          []
      end

    data
    |> receive_data(test)
    |> Enum.filter(&(not is_nil(&1))) |> Enum.reverse()
  end

  defp receive_data([], test), do: test

  defp receive_data(data, test) do
    [f_item | head] = data

    test = [read(f_item, head) | test]
    receive_data(head, test)
  end

  defp read(%{"account" => account_data}, items) do
    Logger.info("mounting account params #{inspect(account_data)}")

    transactions = get_transactions(items)

    if transactions == [] do
      accounts =
        Enum.reduce_while(items, [], fn item, acc ->
          case Map.get(item, "account") do
            nil -> {:halt, acc}
            account_data -> {:cont, [account_data | acc]}
          end
        end)

      {account_data, accounts, "accounts"}
    else
      {account_data, transactions, "accounts_with_transactions"}
    end
  end

  defp read(%{"transaction" => _}, _), do: nil

  defp get_transactions(items) do
    items
    |> Enum.reduce_while([], fn item, acc ->
      case Map.get(item, "transaction") do
        nil -> {:halt, acc}
        transaction_data -> {:cont, [transaction_data | acc]}
      end
    end)
    |> Enum.reverse()
  end

  defp read_first_item(%{"transaction" => transaction}, items) do
    transactions = get_transactions(items)

    {%{}, [transaction | transactions], "non_initialized_accounts_with_transactions"}
  end

  defp read_first_item(%{"account" => account}, _), do: {account, [], "account_as_first_index"}
end
