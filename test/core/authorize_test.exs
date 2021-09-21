defmodule Core.AuthorizerTest do
  use ExUnit.Case
  alias Core.Transactions.AuthorizeTransactions
  alias Core.Accounts.Model.Account
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

    assert [
             %Account{
               active_card: true,
               available_limit: 100,
               violations: [],
               virtual_id: nil
             },
             %Account{
               active_card: true,
               available_limit: 80,
               violations: [],
               virtual_id: nil
             },
             %Account{
               active_card: true,
               available_limit: 60,
               violations: [],
               virtual_id: nil
             },
             %Account{
               active_card: true,
               available_limit: 40,
               violations: [],
               virtual_id: nil
             },
             %Account{
               active_card: true,
               available_limit: 40,
               violations: ["high_frequency_small_interval"],
               virtual_id: nil
             },
             %Account{
               active_card: true,
               available_limit: 30,
               violations: [],
               virtual_id: nil
             }
           ] == AuthorizeTransactions.execute(account, transactions)
  end

  test "test doubled-transaction" do
    account = %{"active-card" => true, "available-limit" => 100}
    now = DateTime.utc_now()
    time = now |> DateTime.add(:timer.minutes(2) * -1, :millisecond) |> DateTime.to_iso8601()

    transactions = [
      %{"merchant" => "Burger King", "amount" => 20, "time" => time},
      %{"merchant" => "McDonald's", "amount" => 10, "time" => time},
      %{"merchant" => "Burger King", "amount" => 20, "time" => time},
      %{"merchant" => "Burger King", "amount" => 15, "time" => time}
    ]

    assert [
             %Account{
               active_card: true,
               available_limit: 100,
               violations: [],
               virtual_id: nil
             },
             %Account{
               active_card: true,
               available_limit: 80,
               violations: [],
               virtual_id: nil
             },
             %Account{
               active_card: true,
               available_limit: 70,
               violations: [],
               virtual_id: nil
             },
             %Account{
               active_card: true,
               available_limit: 50,
               violations: ["doubled-transaction"],
               virtual_id: nil
             },
             %Account{
               active_card: true,
               available_limit: 35,
               violations: [],
               virtual_id: nil
             }
           ] == AuthorizeTransactions.execute(account, transactions)
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
      %{
        "merchant" => "Burger King",
        "amount" => 15,
        "time" => now |> DateTime.add(:timer.hours(1), :millisecond) |> DateTime.to_iso8601()
      }
    ]

    assert [
             %Account{
               active_card: true,
               available_limit: 100,
               violations: [],
               virtual_id: nil
             },
             %Account{
               active_card: true,
               available_limit: 90,
               violations: [],
               virtual_id: nil
             },
             %Account{
               active_card: true,
               available_limit: 70,
               violations: [],
               virtual_id: nil
             },
             %Account{
               active_card: true,
               available_limit: 65,
               violations: [],
               virtual_id: nil
             },
             %Account{
               active_card: true,
               available_limit: 65,
               violations: ["high_frequency_small_interval", "doubled-transaction"],
               virtual_id: nil
             },
             %Account{
               active_card: true,
               available_limit: 65,
               violations: ["high_frequency_small_interval", "insufficient-limit"],
               virtual_id: nil
             },
             %Account{
               active_card: true,
               available_limit: 65,
               violations: ["high_frequency_small_interval", "insufficient-limit"],
               virtual_id: nil
             },
             %Account{
               active_card: true,
               available_limit: 50,
               violations: [],
               virtual_id: nil
             }
           ] == AuthorizeTransactions.execute(account, transactions)
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

    [
      %Account{
        active_card: true,
        available_limit: 1000,
        violations: [],
        virtual_id: nil
      },
      %Account{
        active_card: true,
        available_limit: 1000,
        violations: ["insufficient-limit"],
        virtual_id: nil
      },
      %Account{
        active_card: true,
        available_limit: 1000,
        violations: ["insufficient-limit"],
        virtual_id: nil
      },
      %Account{
        active_card: true,
        available_limit: 200,
        violations: [],
        virtual_id: nil
      },
      %Account{
        active_card: true,
        available_limit: 120,
        violations: [],
        virtual_id: nil
      }
    ] ==
      AuthorizeTransactions.execute(account, transactions)
  end

  test "test account-not-initialized" do
    time = DateTime.utc_now()

    transactions = [
      %{"merchant" => "Vivara", "amount" => 1250, "time" => time},
      %{"merchant" => "Samsung", "amount" => 2500, "time" => time},
      %{"merchant" => "Nike", "amount" => 800, "time" => time},
      %{"merchant" => "Uber", "amount" => 80, "time" => time}
    ]

    assert [
             %Account{
               active_card: nil,
               available_limit: nil,
               violations: ["account-not-initialized"],
               virtual_id: nil
             },
             %Account{
               active_card: nil,
               available_limit: nil,
               violations: ["account-not-initialized"],
               virtual_id: nil
             },
             %Account{
               active_card: nil,
               available_limit: nil,
               violations: ["account-not-initialized"],
               virtual_id: nil
             },
             %Account{
               active_card: nil,
               available_limit: nil,
               violations: ["account-not-initialized"],
               virtual_id: nil
             }
           ] == AuthorizeTransactions.execute(nil, transactions)
  end

  test "test card-not-active" do
    account = %{"active-card" => false, "available-limit" => 100}
    now = DateTime.utc_now()

    transactions = [
      %{
        "merchant" => "Burger King",
        "amount" => 20,
        "time" => now
      },
      %{
        "merchant" => "Habbib's",
        "amount" => 15,
        "time" => now
      }
    ]

    assert [
             %Core.Accounts.Model.Account{
               active_card: false,
               available_limit: 100,
               violations: [],
               virtual_id: nil
             },
             %Core.Accounts.Model.Account{
               active_card: false,
               available_limit: 100,
               violations: ["card-not-active"],
               virtual_id: nil
             },
             %Core.Accounts.Model.Account{
               active_card: false,
               available_limit: 100,
               violations: ["card-not-active"],
               virtual_id: nil
             }
           ] ==
             AuthorizeTransactions.execute(account, transactions)
  end

  test "test insufficient-limit" do
    account = %{"active-card" => true, "available-limit" => 1000}
    now = DateTime.utc_now()

    transactions = [
      %{"merchant" => "Vivara", "amount" => 1250, "time" => now},
      %{"merchant" => "Samsung", "amount" => 2500, "time" => now},
      %{"merchant" => "Nike", "amount" => 800, "time" => now}
    ]

    assert [
      %Core.Accounts.Model.Account{
        active_card: true,
        available_limit: 1000,
        violations: [],
        virtual_id: nil
      },
      %Core.Accounts.Model.Account{
        active_card: true,
        available_limit: 200,
        violations: [],
        virtual_id: nil
      },
      %Core.Accounts.Model.Account{
        active_card: true,
        available_limit: 1000,
        violations: ["insufficient-limit"],
        virtual_id: nil
      },
      %Core.Accounts.Model.Account{
        active_card: true,
        available_limit: 1000,
        violations: ["insufficient-limit"],
        virtual_id: nil
      }
    ]
     == AuthorizeTransactions.execute(account, transactions)
  end
end
