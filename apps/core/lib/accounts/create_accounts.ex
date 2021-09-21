defmodule Core.Accounts.CreateAccount do
  @moduledoc """
  Implements accounts Business Logic
  """
  alias Core.Accounts.Model.Account
  alias Core.Utils.ValueObject

  require Logger

  @spec execute([map()]) :: {:error, Ecto.Changeset.t()} | [map()]
  def execute(accounts) do
    {valid_accounts, _invalid_accounts} =
      accounts
      |> Enum.map(&ValueObject.cast_and_apply(&1, Account))
      |> Enum.split_with(&(elem(&1, 0) == :ok))

    constraint_unique_account_virtual_id(valid_accounts)
  end

  defp constraint_unique_account_virtual_id(accounts) do
    accounts
    |> Enum.group_by(fn {:ok, account} -> account.virtual_id end, &elem(&1, 1))
    |> Enum.map(fn
      {_, [account | _] = list_ids} when length(list_ids) > 1 ->
        Logger.info("account-already-initialize, account: inspect(#{account})")
        Enum.map(1..length(list_ids), fn _ -> %{account | violations: ["account-already-initialized"]} end)

      {_, [account | _] = list_ids} when length(list_ids) == 1 ->
        Logger.info("account successfully created")
        account
    end)
    |> List.flatten()
  end
end
