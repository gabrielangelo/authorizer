defmodule Cli.Test.AuthorizeReaderTest do
  @moduledoc """
  Authorizer reader tests
  """
  use ExUnit.Case

  alias Cli.Readers.AuhtorizerReader

  test "test" do
    transactions = [
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
             {%{"active-card" => true, "available-limit" => 225},
              [
                %{
                  "amount" => 25,
                  "merchant" => "Uber Eats",
                  "time" => "2020-12-01T11:07:00.000Z"
                }
              ], "accounts_with_transactions"},
             {%{}, [], "non_initialized_accounts_with_transactions"}
           ] == AuhtorizerReader.re(transactions)
  end
end
