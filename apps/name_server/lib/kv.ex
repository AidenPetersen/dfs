defmodule NameServer.KV do
  use GenServer
  require Logger

  # Client, all wrapper functions for Genserver calls/casts
  def start_link(default) when is_list(default) do
    GenServer.start_link(__MODULE__, default, name: {:global, {:name, NameServer}})
  end

  def get(pid, name) do
    GenServer.call(pid, {:get, name})
  end

  def register(pid, name, server_pid) do
    GenServer.call(pid, {:register, name, server_pid})
  end

  def delete(pid, name) do
    GenServer.cast(pid, {:delete, name})
  end

  @impl true
  def init(_args) do
    {:ok, %{}}
  end

  # Get a name's process
  @impl true
  def handle_call({:get, name}, _from, map) do
    Logger.info("Getting PID for #{inspect(name)}")
    {:reply, Map.get(map, name, :not_registered), map}
  end

  # Respond :duplicate when trying to register already existing server
  @impl true
  def handle_call({:register, name, pid}, _from, map) when is_map_key(map, name) do
    Logger.info("Not registering duplicate: #{inspect(name)} for pid #{inspect(pid)}")
    {:reply, :duplicate, map}
  end

  # Register server normally
  @impl true
  def handle_call({:register, name, pid}, _from, map) when is_bitstring(name) do
    Logger.info("Registering #{inspect(name)} for pid #{inspect(pid)}")
    new_map = Map.put(map, name, pid)
    {:reply, :success, new_map}
  end

  # Remove a server from the map
  @impl true
  def handle_cast({:delete, name}, map) do
    Logger.info("Deleting #{inspect(name)}")

    newmap = Map.delete(map, name)
    {:noreply, newmap}
  end

end
