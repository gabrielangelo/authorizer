defmodule Cli.Test.AuthorizeReaderTest do
  @moduledoc """
  Authorizer reader tests
  """
  use ExUnit.Case, async: true

  alias Cli.Readers.AuhtorizerReader

  test "test entry starting with transaction" do
    data = [
      %{
        "transaction" => %{
          "merchant" => "Uber Eats",
          "amount" => 25,
          "time" => "2020-12-01T11:07:00.000Z"
        }
      },
      %{"account" => %{"active-card" => true, "available-limit" => 225}},
      %{
        "transaction" => %{
          "merchant" => "Uber Eats",
          "amount" => 25,
          "time" => "2020-12-01T11:07:00.000Z"
        }
      }
    ]

    assert [
             {%{},
              [
                %{
                  "merchant" => "Uber Eats",
                  "amount" => 25,
                  "time" => "2020-12-01T11:07:00.000Z"
                }
              ], "non_initialized_accounts_with_transactions"},
             {%{"active-card" => true, "available-limit" => 225},
              [
                %{
                  "amount" => 25,
                  "merchant" => "Uber Eats",
                  "time" => "2020-12-01T11:07:00.000Z"
                }
              ], "accounts_with_transactions"}
           ] == AuhtorizerReader.read(data)
  end

  test "test 2 accounts case " do
    data = [
      %{"account" => %{"active-card" => true, "available-limit" => 225}},
      %{
        "transaction" => %{
          "merchant" => "Uber Eats",
          "amount" => 25,
          "time" => "2020-12-01T11:07:00.000Z"
        }
      },
      %{"account" => %{"active-card" => true, "available-limit" => 500}},
      %{
        "transaction" => %{
          "merchant" => "Uber Eats",
          "amount" => 70,
          "time" => "2020-12-01T11:07:00.000Z"
        }
      }
    ]

    assert [
             {%{"active-card" => true, "available-limit" => 225},
              [
                %{
                  "amount" => 25,
                  "merchant" => "Uber Eats",
                  "time" => "2020-12-01T11:07:00.000Z"
                }
              ], "accounts_with_transactions"},
             {%{"active-card" => true, "available-limit" => 500},
              [
                %{
                  "amount" => 70,
                  "merchant" => "Uber Eats",
                  "time" => "2020-12-01T11:07:00.000Z"
                }
              ], "accounts_with_transactions"}
           ] ==
             AuhtorizerReader.read(data)
  end
end
