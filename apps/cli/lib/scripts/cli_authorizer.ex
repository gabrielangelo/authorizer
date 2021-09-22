defmodule Cli.Scripts.Authorizer do
  @moduledoc """
    Authorizer cli module
  """

  alias Cli.Ports.Stdin
  alias Cli.Readers.AuhtorizerReader
  alias Cli.Renders.Account, as: AccountRender
  alias Core.Accounts.CreateAccount
  alias Core.Transactions.AuthorizeTransactions

  require Logger

  def run() do
    Logger.info("getting file info and processing")

    Stdin.read_data()
    |> Enum.map(& Jason.decode!(&1))
    |> execute()
    |> AccountRender.render()
  end

  defp execute(data) do
    data
    |> AuhtorizerReader.re()
    |> Enum.map(&process_results/1)
    |> Task.async_stream(& &1. (),
      max_concurrency: 40,
      timeout: 10_000
    )
    |> get_tasks_results()
  end

  defp get_tasks_results(data) do
    Enum.reduce_while(data, {:ok, []}, fn
      {:ok, {:error, _} = error}, _ ->
        {:halt, error}

      {:ok, [_, {:error, _} = error]}, _ ->
        {:halt, error}

      {:ok, result}, {:ok, acc} ->
        {:cont, [result | acc]}
    end)
  end

  defp process_results({account, transactions, operation})
       when operation in [
              "accounts_with_transactions",
              "non_initialized_accounts_with_transactions"
            ] do
    fn -> AuthorizeTransactions.execute(account, transactions) end
  end

  defp process_results({account, accounts, "accounts"}) do
   fn -> [account | accounts]
    |> CreateAccount.execute() end
  end
end

if Mix.env() not in [:test]  do
  Cli.Scripts.Authorizer.run()
end
