defmodule AuthorizerTest do
  use ExUnit.Case
  alias Core.Transactions.ExecuteTransactions
  alias Model.Account
  # doctest Authorizer

  test "create transactions" do
    account = %{"active-card" => true, "available-limit" => 100}
    now = DateTime.utc_now()
    time = now |> DateTime.add(:timer.minutes(2) * -1, :millisecond) |> DateTime.to_iso8601()

    transactions = [
      %{"merchant" => "Burger King", "amount" => 20, "time" => time},
      %{"merchant" => "Habbib's", "amount" => 20, "time" => time},
      %{"merchant" => "McDonald's", "amount" => 20, "time" => time},
      %{"merchant" => "Subway", "amount" => 20, "time" => time},
      %{"merchant" => "Burger King", "amount" => 10, "time" => now}
    ] |> IO.inspect(label: :transactions_test)

    ExecuteTransactions.execute(account, transactions)
  end
end
