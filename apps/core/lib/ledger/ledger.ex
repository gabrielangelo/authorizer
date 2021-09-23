defmodule Core.Ledger do
  @moduledoc """
    Ledger module
  """

  alias Core.Accounts.Model.Account
  alias Core.Transactions.Model.Transaction

  @spec check_limit(Account.t(), Transaction.t()) :: {Account.t(), Transaction.t()}
  def check_limit(%Account{active_card: false} = account, %Transaction{} = transaction),
    do: {%{account | violations: ["card-not-active"]}, %{transaction | rejected: true}}

  def check_limit(
         %Account{available_limit: available_limit, violations: _} = account,
         %Transaction{
           amount: amount
         } = transaction
       )
       when amount > available_limit,
       do: {%{account | violations: ["insufficient-limit"]}, %{transaction | rejected: true}}

  def check_limit(
         %Account{available_limit: available_limit, violations: []} = account,
         %Transaction{
           amount: amount
         } = transaction
       )
       when amount <= available_limit,
       do: {%{account | available_limit: available_limit - amount}, transaction}

  def check_limit(
         %Account{available_limit: available_limit, violations: [_ | _]} = account,
         %Transaction{
           amount: amount
         } = transaction
       )
       when amount <= available_limit,
       do: {%{account | available_limit: available_limit - amount, violations: []}, transaction}
end
