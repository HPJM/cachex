defmodule CachexTest do
  use ExUnit.Case
  doctest Cachex

  # Uniquely name cache each test so we don't have to look up PID
  setup context do
    start_supervised!({Cachex, name: context.test})
    %{name: context.test}
  end

  describe "put" do
    test "put/3 inserts entry into cache", %{name: name} do
      Cachex.put(:key, :value, ttl: 5, name: name)
      assert {value, _timestamp, ttl} = :ets.lookup_element(name, :key, 2)
      assert value == :value
      assert ttl == 5
    end
  end

  describe "fetch" do
    test "fetch/2 fetches entry if exists", %{name: name} do
      :ets.insert(name, {:another_key, {:another_value, DateTime.utc_now(), 5}})
      assert Cachex.fetch(:another_key, name) == {:ok, :another_value}
    end

    test "fetch/2 returns errors and time metadata on expiry", %{name: name} do
      now = DateTime.utc_now()
      Cachex.put(:blue, :cheese, ttl: 0, name: name, timestamp: now)
      assert Cachex.fetch(:blue, name) == {:error, {:expired, :cheese, now, 0}}
      # Check deleted
      assert Cachex.fetch(:blue, name) == {:error, :not_found}
    end

    test "fetch/2 returns error when not found", %{name: name} do
      assert Cachex.fetch(:wensleydale, name) == {:error, :not_found}
    end
  end

  describe "delete" do
    test "delete/2 removes entry from cache", %{name: name} do
      Cachex.put(:red, :leicester, name: name)
      assert Cachex.delete(:red, name)
      assert Cachex.fetch(:red, name) == {:error, :not_found}
    end
  end

  describe "fetch_or_put" do
    test "fetch_or_put/3 puts if doesn't exist", %{name: name} do
      assert Cachex.fetch_or_put(:number, &"#{&1}", name: name) == {:ok, "number"}

      assert Cachex.fetch(:number, name) == {:ok, "number"}
    end

    test "fetch_or_put/3 fetches if exists", %{name: name} do
      Cachex.put(:key, :value, name: name)

      assert Cachex.fetch_or_put(:key, fn -> 1 end, name: name) == {:ok, :value}
    end
  end
end
