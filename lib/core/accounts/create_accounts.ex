defmodule Core.Accounts.CreateAccount do
  @moduledoc """
  Implements accounts Business Logic
  """
  alias Core.Authorizer.Model.Account
  alias Core.Authorizer.Utils.ValueObject

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
    |> Enum.group_by(& &1.virtual_id)
    |> Enum.map(fn
      {_, [account | _] = list_ids} when length(list_ids) > 1 ->
        %{account | violations: ["account-already-initialized"]}

      {_, [account | _] = list_ids} when length(list_ids) == 1 ->
        account
    end)
  end
end
