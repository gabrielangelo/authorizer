defmodule Cli.Test.CliAuthorizerTest do
  @moduledoc """
    Cli authorizer test
  """

  use ExUnit.Case, async: true
  alias Cli.Authorizer

  import Mox
  setup :verify_on_exit!

  test "test stdin read basic case" do
    expect(StdinMock, :read_data, fn ->
      [
        "{\"account\": {\"active-card\": true, \"available-limit\": 100}}\n",
        "{\"transaction\": {\"merchant\": \"Burger King\", \"amount\": 20, \"time\": \"2019-02-13T10:00:00.000Z\"}}\n",
        "{\"transaction\": {\"merchant\": \"Habbib's\", \"amount\": 90, \"time\": \"2019-02-13T11:00:00.000Z\"}}\n",
        "{\"transaction\": {\"merchant\": \"McDonald's\", \"amount\": 30, \"time\": \"2019-02-13T12:00:00.000Z\"}}"
      ]
    end)

    assert [
             [
               "{\"account\":{\"active-card\":true,\"available-limit\":100,\"violations\":[]}}",
               "{\"account\":{\"active-card\":true,\"available-limit\":70,\"violations\":[]}}",
               "{\"account\":{\"active-card\":true,\"available-limit\":70,\"violations\":[\"insufficient-limit\"]}}",
               "{\"account\":{\"active-card\":true,\"available-limit\":50,\"violations\":[]}}"
             ]
           ] == Cli.Scripts.Authorizer.run()
  end
end
