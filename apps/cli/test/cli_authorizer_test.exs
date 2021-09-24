defmodule Cli.Test.CliAuthorizerTest do
  @moduledoc """
    Cli authorizer test
  """

  use ExUnit.Case, async: true
  alias Cli.Scripts.Authorizer

  import Mox
  setup :verify_on_exit!

  setup do
    now = DateTime.utc_now()
    time = DateTime.add(now, :timer.minutes(2) * -1, :millisecond) |> DateTime.to_iso8601()
    time_after = DateTime.add(now, :timer.hours(1), :millisecond) |> DateTime.to_iso8601()

    %{
      now: now,
      time: time,
      time_after: time_after
    }
  end

  test "test stdin successfully transactions followed by insufficient-limit", %{
    time: time,
    time_after: time_after
  } do
    expect(StdinMock, :read_data, fn ->
      [
        "{\"account\": {\"active-card\": true, \"available-limit\": 100}}\n",
        "{\"transaction\": {\"merchant\": \"Burger King\", \"amount\": 20, \"time\": \"#{time}\"}}\n",
        "{\"transaction\": {\"merchant\": \"Habbib's\", \"amount\": 90, \"time\": \"#{time}\"}}\n",
        "{\"transaction\": {\"merchant\": \"McDonald's\", \"amount\": 30, \"time\": \"#{
          time_after
        }\"}}"
      ]
    end)

    assert [
             "{\"account\":{\"active-card\":true,\"available-limit\":100,\"violations\":[]}}",
             "{\"account\":{\"active-card\":true,\"available-limit\":80,\"violations\":[]}}",
             "{\"account\":{\"active-card\":true,\"available-limit\":80,\"violations\":[\"insufficient-limit\"]}}",
             "{\"account\":{\"active-card\":true,\"available-limit\":50,\"violations\":[]}}"
           ] ==
             Authorizer.main([])
  end

  test "test account-already-initialized" do
    expect(StdinMock, :read_data, fn ->
      [
        "{\"account\":{\"active-card\":false,\"available-limit\":175}}",
        "{\"account\":{\"active-card\":false,\"available-limit\":350}}"
      ]
    end)

    assert [
             "{\"account\":{\"active-card\":false,\"available-limit\":175,\"violations\":[\"account-already-initialized\"]}}",
             "{\"account\":{\"active-card\":false,\"available-limit\":175,\"violations\":[\"account-already-initialized\"]}}"
           ] ==
             Authorizer.main([])
  end

  test "test account creation with success" do
    expect(StdinMock, :read_data, fn ->
      [
        ["{\"account\": {\"active-card\": false, \"available-limit\": 750}}\n"]
      ]
    end)

    assert [
             "{\"account\":{\"active-card\":false,\"available-limit\":750,\"violations\":[]}}"
           ] == Authorizer.main([])
  end

  test "test account-not-initialized", %{time: time, now: now} do
    expect(StdinMock, :read_data, fn ->
      [
        "{\"transaction\": {\"merchant\": \"Uber Eats\", \"amount\": 25, \"time\": \"#{time}\"}}\n",
        "{\"account\": {\"active-card\": true, \"available-limit\": 225}}\n",
        "{\"transaction\": {\"merchant\": \"Habbib's\", \"amount\": 25, \"time\": \"#{now}\"}}\n"
      ]
    end)

    assert [
             "{\"account\":{\"active-card\":null,\"available-limit\":null,\"violations\":[\"account-not-initialized\"]}}",
             "{\"account\":{\"active-card\":true,\"available-limit\":225,\"violations\":[]}}",
             "{\"account\":{\"active-card\":true,\"available-limit\":200,\"violations\":[]}}"
           ] ==
             Authorizer.main([])
  end

  test "test card not active", %{time: time, now: now} do
    expect(StdinMock, :read_data, fn ->
      [
        "{\"account\": {\"active-card\": false, \"available-limit\": 100}}\n",
        "{\"transaction\": {\"merchant\": \"Burger King\", \"amount\": 20, \"time\": \"#{time}\"}}\n",
        "{\"transaction\": {\"merchant\": \"Habbib's\", \"amount\": 90, \"time\": \"#{time}\"}}\n",
        "{\"transaction\": {\"merchant\": \"McDonald's\", \"amount\": 30, \"time\": \"#{now}\"}}"
      ]
    end)

    assert [
             "{\"account\":{\"active-card\":false,\"available-limit\":100,\"violations\":[]}}",
             "{\"account\":{\"active-card\":false,\"available-limit\":100,\"violations\":[\"card-not-active\"]}}",
             "{\"account\":{\"active-card\":false,\"available-limit\":100,\"violations\":[\"card-not-active\"]}}",
             "{\"account\":{\"active-card\":false,\"available-limit\":100,\"violations\":[\"card-not-active\"]}}"
           ] ==
             Authorizer.main([])
  end

  test "test insufficient-limit", %{time: time, now: now} do
    expect(StdinMock, :read_data, fn ->
      [
        "{\"account\": {\"active-card\": true, \"available-limit\": 1000}}\n",
        "{\"transaction\": {\"merchant\": \"Burger King\", \"amount\": 1250, \"time\": \"#{time}\"}}\n",
        "{\"transaction\": {\"merchant\": \"Habbib's\", \"amount\": 2500, \"time\": \"#{time}\"}}\n",
        "{\"transaction\": {\"merchant\": \"McDonald's\", \"amount\": 800, \"time\": \"#{now}\"}}"
      ]
    end)

    assert [
             "{\"account\":{\"active-card\":true,\"available-limit\":1000,\"violations\":[]}}",
             "{\"account\":{\"active-card\":true,\"available-limit\":1000,\"violations\":[\"insufficient-limit\"]}}",
             "{\"account\":{\"active-card\":true,\"available-limit\":1000,\"violations\":[\"insufficient-limit\"]}}",
             "{\"account\":{\"active-card\":true,\"available-limit\":200,\"violations\":[]}}"
           ] ==
             Authorizer.main([])
  end

  test "test high-frequency-small-interval", %{time: time, now: now} do
    expect(StdinMock, :read_data, fn ->
      [
        "{\"account\": {\"active-card\": true, \"available-limit\": 100}}",
        "{\"transaction\": {\"merchant\": \"Burger King\", \"amount\": 20, \"time\": \"#{time}\"}}\n",
        "{\"transaction\": {\"merchant\": \"Habbib's\", \"amount\": 20, \"time\": \"#{time}\"}}\n",
        "{\"transaction\": {\"merchant\": \"McDonald's\", \"amount\": 20, \"time\": \"#{time}\"}}\n",
        "{\"transaction\": {\"merchant\": \"Subway\", \"amount\": 20, \"time\": \"#{time}\"}}\n",
        "{\"transaction\": {\"merchant\": \"Burger King\", \"amount\": 10, \"time\": \"#{now}\"}}"
      ]
    end)

    assert [
             "{\"account\":{\"active-card\":true,\"available-limit\":100,\"violations\":[]}}",
             "{\"account\":{\"active-card\":true,\"available-limit\":80,\"violations\":[]}}",
             "{\"account\":{\"active-card\":true,\"available-limit\":60,\"violations\":[]}}",
             "{\"account\":{\"active-card\":true,\"available-limit\":40,\"violations\":[]}}",
             "{\"account\":{\"active-card\":true,\"available-limit\":40,\"violations\":[\"high_frequency_small_interval\"]}}",
             "{\"account\":{\"active-card\":true,\"available-limit\":30,\"violations\":[]}}"
           ] ==
             Authorizer.main([])
  end

  test "test doubled-transaction", %{time: time} do
    expect(StdinMock, :read_data, fn ->
      [
        "{\"account\": {\"active-card\": true, \"available-limit\": 100}}",
        "{\"transaction\": {\"merchant\": \"Burger King\", \"amount\": 20, \"time\": \"#{time}\"}}\n",
        "{\"transaction\": {\"merchant\": \"McDonald's\", \"amount\": 10, \"time\": \"#{time}\"}}\n",
        "{\"transaction\": {\"merchant\": \"Burger King\", \"amount\": 20, \"time\": \"#{time}\"}}\n",
        "{\"transaction\": {\"merchant\": \"Burger King\", \"amount\": 15, \"time\": \"#{time}\"}}\n"
      ]
    end)

    assert [
             "{\"account\":{\"active-card\":true,\"available-limit\":100,\"violations\":[]}}",
             "{\"account\":{\"active-card\":true,\"available-limit\":80,\"violations\":[]}}",
             "{\"account\":{\"active-card\":true,\"available-limit\":70,\"violations\":[]}}",
             "{\"account\":{\"active-card\":true,\"available-limit\":70,\"violations\":[\"doubled-transaction\"]}}",
             "{\"account\":{\"active-card\":true,\"available-limit\":55,\"violations\":[]}}"
           ] ==
             Authorizer.main([])
  end

  test "test multiple logics", %{time: time, time_after: time_after} do
    expect(StdinMock, :read_data, fn ->
      [
        "{\"account\": {\"active-card\": true, \"available-limit\": 100}}",
        "{\"transaction\": {\"merchant\": \"McDonald's\", \"amount\": 10, \"time\": \"#{time}\"}}\n",
        "{\"transaction\": {\"merchant\": \"Burger King\", \"amount\": 20, \"time\": \"#{time}\"}}\n",
        "{\"transaction\": {\"merchant\": \"Burger King\", \"amount\": 5, \"time\": \"#{time}\"}}\n",
        "{\"transaction\": {\"merchant\": \"Burger King\", \"amount\": 5, \"time\": \"#{time}\"}}\n",
        "{\"transaction\": {\"merchant\": \"Burger King\", \"amount\": 150, \"time\": \"#{time}\"}}\n",
        "{\"transaction\": {\"merchant\": \"Burger King\", \"amount\": 190, \"time\": \"#{time}\"}}\n",
        "{\"transaction\": {\"merchant\": \"Burger King\", \"amount\": 15, \"time\": \"#{
          time_after
        }\"}}\n"
      ]
    end)

    assert [
             "{\"account\":{\"active-card\":true,\"available-limit\":100,\"violations\":[]}}",
             "{\"account\":{\"active-card\":true,\"available-limit\":90,\"violations\":[]}}",
             "{\"account\":{\"active-card\":true,\"available-limit\":70,\"violations\":[]}}",
             "{\"account\":{\"active-card\":true,\"available-limit\":65,\"violations\":[]}}",
             "{\"account\":{\"active-card\":true,\"available-limit\":65,\"violations\":[\"doubled-transaction\",\"high_frequency_small_interval\"]}}",
             "{\"account\":{\"active-card\":true,\"available-limit\":65,\"violations\":[\"high_frequency_small_interval\",\"insufficient-limit\"]}}",
             "{\"account\":{\"active-card\":true,\"available-limit\":65,\"violations\":[\"high_frequency_small_interval\",\"insufficient-limit\"]}}",
             "{\"account\":{\"active-card\":true,\"available-limit\":50,\"violations\":[]}}"
           ] ==
             Authorizer.main([])
  end

  test "test account-not-initialized case", %{time: time, time_after: time_after} do
    expect(StdinMock, :read_data, fn ->
      [
        "{\"transaction\": {\"merchant\": \"McDonald's\", \"amount\": 10, \"time\": \"#{time}\"}}\n",
        "{\"transaction\": {\"merchant\": \"Burger King\", \"amount\": 20, \"time\": \"#{time}\"}}\n",
        "{\"transaction\": {\"merchant\": \"Burger King\", \"amount\": 5, \"time\": \"#{time}\"}}\n",
        "{\"transaction\": {\"merchant\": \"Burger King\", \"amount\": 5, \"time\": \"#{time}\"}}\n",
        "{\"transaction\": {\"merchant\": \"Burger King\", \"amount\": 150, \"time\": \"#{time}\"}}\n",
        "{\"transaction\": {\"merchant\": \"Burger King\", \"amount\": 190, \"time\": \"#{time}\"}}\n",
        "{\"transaction\": {\"merchant\": \"Burger King\", \"amount\": 15, \"time\": \"#{
          time_after
        }\"}}\n"
      ]
    end)

    assert [
             "{\"account\":{\"active-card\":null,\"available-limit\":null,\"violations\":[\"account-not-initialized\"]}}",
             "{\"account\":{\"active-card\":null,\"available-limit\":null,\"violations\":[\"account-not-initialized\"]}}",
             "{\"account\":{\"active-card\":null,\"available-limit\":null,\"violations\":[\"account-not-initialized\"]}}",
             "{\"account\":{\"active-card\":null,\"available-limit\":null,\"violations\":[\"account-not-initialized\"]}}",
             "{\"account\":{\"active-card\":null,\"available-limit\":null,\"violations\":[\"account-not-initialized\"]}}",
             "{\"account\":{\"active-card\":null,\"available-limit\":null,\"violations\":[\"account-not-initialized\"]}}",
             "{\"account\":{\"active-card\":null,\"available-limit\":null,\"violations\":[\"account-not-initialized\"]}}"
           ] ==
             Authorizer.main([])
  end
end
