defmodule Core.Test.CreateAccountsTest do
  @moduledoc """
  Create account test
  """

   use ExUnit.Case, async: true

  alias Core.Accounts.CreateAccount

  test "create accounts that already exists" do
    accounts = [
      %{"active-card" => true, "available-limit" => 175},
      %{"active-card" => true, "available-limit" => 350},
      %{"active-card" => true, "available-limit" => 150}
    ]

    assert [
      %Core.Accounts.Model.Account{
        active_card: true,
        available_limit: 175,
        violations: ["account-already-initialized"],
        virtual_id: nil
      },
      %Core.Accounts.Model.Account{
        active_card: true,
        available_limit: 175,
        violations: ["account-already-initialized"],
        virtual_id: nil
      },
      %Core.Accounts.Model.Account{
        active_card: true,
        available_limit: 175,
        violations: ["account-already-initialized"],
        virtual_id: nil
      }
    ] ==
    CreateAccount.execute(accounts)
  end

  test "create accounts with sucessfully" do
    accounts = [
      %{"active-card" => true, "available-limit" => 175}
    ]

    assert [
      %Core.Accounts.Model.Account{
        active_card: true,
        available_limit: 175,
        violations: [],
        virtual_id: nil
      }
    ] ==
    CreateAccount.execute(accounts)
  end
end
