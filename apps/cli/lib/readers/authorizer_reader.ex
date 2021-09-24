defmodule Cli.Readers.AuhtorizerReader do
  @moduledoc """
    Read entries in auhtorizer
  """

  require Logger

  @spec read([map]) :: [tuple()]
  def read([]), do: []

  def read(data) do
    Logger.info("Mounting authorizer data")
    [f_item | head] = data

    case read_first_item(f_item, head) do
      {%{}, _, "non_initialized_accounts_with_transactions"} = item ->

        process(data, [item])
      {account, accounts, "all_accounts"} ->
        [{account, accounts, "accounts"}]

      _ ->
        process(data, [])

    end
  end

  defp process(data, items), do: data |> receive_data(items) |> Enum.filter(&(not is_nil(&1))) |> Enum.reverse()

  defp receive_data([], test), do: test

  defp receive_data(data, test) do
    [f_item | head] = data

    test = [read(f_item, head) | test]
    receive_data(head, test)
  end

  defp read(%{"account" => account_data}, items) when items != [] do
    transactions = get_transactions(items)

    if transactions == [] do
      accounts =
        Enum.reduce_while(items, [], fn item, acc ->
          case Map.get(item, "account") do
            nil -> {:halt, acc}
            account_data -> {:cont, [account_data | acc]}
          end
        end)

      gen_accounts({account_data, accounts, "accounts"})
    else
      {account_data, transactions, "accounts_with_transactions"}
    end
  end

  defp read(%{"account" => account_data}, []), do: {account_data, [], "accounts"}

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

  defp gen_accounts({account, items, "accounts" = type}), do: {account, [account | items], type}

  defp read_first_item(%{"transaction" => transaction}, items) do
    transactions = get_transactions(items)

    {%{}, [transaction | transactions], "non_initialized_accounts_with_transactions"}
  end

  defp read_first_item(%{"account" => account}, []), do: {account, [], "account_as_first_index"}

  defp read_first_item(%{"account" => account}, items) do
    len_items = length(items)

    accounts =
      Enum.reduce_while(items, [], fn item, acc ->
        case Map.get(item, "account") do
          nil -> {:halt, acc}
          account_data -> {:cont, [account_data | acc]}
        end
      end)

    if len_items == length(accounts) do
      {account, [account | accounts], "all_accounts"}
    else
      {account, [], "account_as_first_index"}
    end
  end
end
