defmodule AuthorizerTest do
  use ExUnit.Case
  alias Core.Transactions.ExecuteTransactions
  alias Model.Account
  # doctest Authorizer

  test "test high_frequency_small_interval" do
    account = %{"active-card" => true, "available-limit" => 100}
    now = DateTime.utc_now()
    time = now |> DateTime.add(:timer.minutes(2) * -1, :millisecond) |> DateTime.to_iso8601()

    transactions = [
      %{"merchant" => "Burger King", "amount" => 20, "time" => time},
      %{"merchant" => "Habbib's", "amount" => 20, "time" => time},
      %{"merchant" => "McDonald's", "amount" => 20, "time" => time},
      %{"merchant" => "Subway", "amount" => 20, "time" => time},
      %{"merchant" => "Burger King", "amount" => 10, "time" => now}
    ]

    # |> IO.inspect(label: :transactions_test)

    ExecuteTransactions.execute(account, transactions)
  end

  test "test doubled-transaction" do
    account = %{"active-card" => true, "available-limit" => 100}
    now = DateTime.utc_now()
    time = now |> DateTime.add(:timer.minutes(2) * -1, :millisecond) |> DateTime.to_iso8601()

    transactions = [
      %{"merchant" => "Burger King", "amount" => 20, "time" => time},
      %{"merchant" => "McDonald's", "amount" => 10, "time" => time},
      %{"merchant" => "Burger King", "amount" => 20, "time" => time},
      %{"merchant" => "Burger King", "amount" => 15, "time" => time},
    ]

    ExecuteTransactions.execute(account, transactions)
  end

  test "test multiple logics" do
    account = %{"active-card" => true, "available-limit" => 100}
    now = DateTime.utc_now()
    time = now |> DateTime.add(:timer.minutes(2) * -1, :millisecond) |> DateTime.to_iso8601()

    transactions = [
      %{"merchant" => "McDonald's", "amount" => 10, "time" => time},
      %{"merchant" => "Burger King", "amount" => 20, "time" => time},
      %{"merchant" => "Burger King", "amount" => 5, "time" => time},
      %{"merchant" => "Burger King", "amount" => 5, "time" => time},
      %{"merchant" => "Burger King", "amount" => 150, "time" => time},
      %{"merchant" => "Burger King", "amount" => 190, "time" => time},
      %{"merchant" => "Burger King", "amount" => 15, "time" => now |> DateTime.add(:timer.hours(1), :millisecond) |> DateTime.to_iso8601()}
    ]

    ExecuteTransactions.execute(account, transactions)
  end

  test "test insuficient limit" do
    account = %{"active-card" => true, "available-limit" => 1000}
    now = DateTime.utc_now()
    time = now |> DateTime.add(:timer.minutes(2) * -1, :millisecond) |> DateTime.to_iso8601()

    transactions = [
      %{"merchant" => "Vivara", "amount" => 1250, "time" => time},
      %{"merchant" => "Samsung", "amount" => 2500, "time" => time},
      %{"merchant" => "Nike", "amount" => 800, "time" => time},
      %{"merchant" => "Uber", "amount" => 80, "time" => time}
    ]

    ExecuteTransactions.execute(account, transactions)
    |> Renders.Account.render()
  end
end
