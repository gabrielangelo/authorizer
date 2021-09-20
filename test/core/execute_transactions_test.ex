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

    # |> IO.inspect(label: :transactions_test)

    ExecuteTransactions.execute(account, transactions)
  end

  test "test multiple logics" do
    account = %{"active-card" => true, "available-limit" => 100}
    now = DateTime.utc_now()
    time = now |> DateTime.add(:timer.minutes(2) * -1, :millisecond) |> DateTime.to_iso8601()


    # {"transaction": {"merchant": "McDonald's", "amount": 10, "time": "2019-02-13T11:00:01.000Z"}}
    # {"transaction": {"merchant": "Burger King", "amount": 20, "time": "2019-02-13T11:00:02.000Z"}}
    # {"transaction": {"merchant": "Burger King", "amount": 5, "time": "2019-02-13T11:00:07.000Z"}}
    # {"transaction": {"merchant": "Burger King", "amount": 5, "time": "2019-02-13T11:00:08.000Z"}}
    # {"transaction": {"merchant": "Burger King", "amount": 150, "time": "2019-02-13T11:00:18.000Z"}}
    # {"transaction": {"merchant": "Burger King", "amount": 190, "time": "2019-02-13T11:00:22.000Z"}}
    # {"transaction": {"merchant": "Burger King", "amount": 15, "time": "2019-02-13T12:00:27.000Z"}}

    transactions = [
      %{"merchant" => "McDonald's", "amount" => 10, "time" => time},
      %{"merchant" => "Burger King", "amount" => 20, "time" => time},
      %{"merchant" => "Burger King", "amount" => 5, "time" => time},
      %{"merchant" => "Burger King", "amount" => 5, "time" => time},
      %{"merchant" => "Burger King", "amount" => 150, "time" => time},
      %{"merchant" => "Burger King", "amount" => 190, "time" => time},
      %{"merchant" => "Burger King", "amount" => 15, "time" => now |> DateTime.add(:timer.hours(1), :millisecond) |> DateTime.to_iso8601()}
    ]

    # |> IO.inspect(label: :transactions_test)

    ExecuteTransactions.execute(account, transactions)
  end
end
