defmodule Cachex do
  @moduledoc """
  In-memory key-value store for fetching, storing and deleting any type of data.

  Light wrapper around erlang's `ets` cache.

  A `GenServer` owns the table, so you need to add `Cachex` to your supervision tree.
  `name` is optional, defaults to `Cachex`.
  """

  use GenServer

  @impl true
  def init(opts) do
    new_table(opts[:name])

    {:ok, %{}}
  end

  def start_link(opts) do
    opts = Keyword.put_new(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  @doc """
  Removes entry `key` from cache
  """
  def delete(key, name \\ __MODULE__) do
    :ets.delete(name, key)
  end

  @doc """
  Looks up entry `key` in cache.

  Returns `{:error, :expired, insertion_timestamp, ttl}` if `ttl` exceeded
  and `{:error, :not_found}` if no entry exists.

  Otherwise returns `{:ok, value}`
  """
  def fetch(key, name \\ __MODULE__) do
    {value, timestamp, ttl} = :ets.lookup_element(name, key, 2)

    if expired?(timestamp, ttl) do
      delete(key, name)
      {:error, {:expired, value, timestamp, ttl}}
    else
      {:ok, value}
    end
  rescue
    ArgumentError -> {:error, :not_found}
  end

  @doc """
  Inserts entry `key` in cache with given `value`.

  You can specify a time-to-live (ttl) as an option, defaults to `:infinity`
  (entry never regarded as expired).
  """
  def put(key, value, opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    ttl = Keyword.get(opts, :ttl, :infinity)
    timestamp = Keyword.get(opts, :timestamp, DateTime.utc_now())

    true = :ets.insert(name, {key, {value, timestamp, ttl}})
    :ok
  end

  @doc """
  If cache entry not found or expired, invokes callback, stores result and returns it in
  an `{ok, result}` tuple. Callback can be 0- or 1-arity function.
  If 1-arity, it is passed the key.

  Otherwise returns cached value.
  """
  def fetch_or_put(key, fun, opts \\ []) when is_function(fun, 1) or is_function(fun, 0) do
    name = Keyword.get(opts, :name, __MODULE__)

    case fetch(key, name) do
      # Entry already in cache
      {:ok, _} = cached ->
        cached

      # Lookup has failed
      {:error, e} when e in [:not_found, :expired] ->
        value = apply_callback(fun, key)
        put(key, value, opts)
        {:ok, value}

      # Fallback
      error ->
        error
    end
  end

  defp new_table(name) do
    :ets.new(name, [
      :set,
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])
  end

  defp expired?(_timestamp, :infinity), do: false

  defp expired?(timestamp, ttl) do
    DateTime.compare(DateTime.utc_now(), DateTime.add(timestamp, ttl)) == :gt
  end

  defp apply_callback(fun, key) when is_function(fun, 1), do: fun.(key)
  defp apply_callback(fun, _key) when is_function(fun, 0), do: fun.()
end
