defmodule FileServer.FileManager do
  use GenServer, restart: :permanent
  require Logger

  def start_link(default) do
    GenServer.start_link(__MODULE__, default,
      name: FileServer.FileManager,
      strategy: :one_for_all
    )
  end

  @impl true
  def init([root, nameserver, name]) when is_bitstring(root) do
    # root = file root, nameserver is the atom for the nameserver
    Logger.info(
      "Starting FileManager with [#{inspect(root)}, #{inspect(nameserver)}, #{inspect(name)}]"
    )

    # Registers itself in the nameserver
    :success = GenServer.call(nameserver, {:register, name, self()})

    # make sure when supervisor exits it unregisters itself from the nameserver
    Process.flag(:trap_exit, true)
    {:ok, %{root: root, nameserver: nameserver, name: name}}
  end

  # Handles recieved ls request
  @impl true
  def handle_call({:ls_recv, path}, _from, state) when is_bitstring(path) do
    # We aren't sandboxing this, but it should be for "security" (you can use .. to escape the directory)
    # "security" does not exist in this application at all...
    Logger.info("Recieved list request at: #{path}")

    abs_path = Path.absname(Path.join(state.root, path))
    {:reply, File.ls(abs_path), state}
  end

  # Sends and returns ls result
  @impl true
  def handle_call({:ls_send, path, server}, _from, state)
      when is_bitstring(path) and is_bitstring(server) do
    Logger.info("Listing directory: #{path} on #{server}")
    destination = GenServer.call(state.nameserver, {:get, server})
    {:ok, lis} = GenServer.call(destination, {:ls_recv, path})
    {:reply, Enum.join(lis, " "), state}
  end

  # Reading file, used to respond to read and get
  @impl true
  def handle_call({:read_file, path}, _from, state) when is_bitstring(path) do
    Logger.info("Retrieving file from #{path}")
    abs_path = Path.absname(Path.join(state.root, path))
    # return file descriptor. Can be used to do a variety of things.
    {:reply, File.open(abs_path, [:read]), state}
  end

  # Writing file, used to respond to put operation
  @impl true
  def handle_call({:write_file, path, file}, _from, state) when is_bitstring(path) do
    Logger.info("Writing file to #{path}")
    abs_path = Path.absname(Path.join(state.root, path))
    contents = IO.binread(file, :eof)

    File.open(abs_path, [:write])
    |> elem(1)
    |> IO.binwrite(contents)

    {:reply, :success, state}
  end

  # Reads file on another node
  @impl true
  def handle_call({:read_send, path, server}, _from, state)
      when is_bitstring(path) and is_bitstring(server) do
    Logger.info("Reading file: #{path} from #{server}")
    destination = GenServer.call(state.nameserver, {:get, server})
    {:ok, file} = GenServer.call(destination, {:read_file, path})
    contents = IO.binread(file, :eof)
    {:reply, contents, state}
  end

  # Copies file from another node
  @impl true
  def handle_call({:get_send, src_path, dst_path, server}, _from, state)
      when is_bitstring(src_path) and is_bitstring(dst_path) and is_bitstring(server) do
    Logger.info("Copying file: #{src_path} from #{server} to #{dst_path}")
    destination = GenServer.call(state.nameserver, {:get, server})
    {:ok, file} = GenServer.call(destination, {:read_file, src_path})
    contents = IO.binread(file, :eof)
    abs_path = Path.absname(Path.join(state.root, dst_path))

    File.open(abs_path, [:write])
    |> elem(1)
    |> IO.binwrite(contents)

    {:reply, "success", state}
  end

  # Copies file to another node
  @impl true
  def handle_call({:put_send, src_path, dst_path, server}, _from, state)
      when is_bitstring(src_path) and is_bitstring(dst_path) and is_bitstring(server) do
    Logger.info("Copying file: #{src_path} to #{dst_path}on #{server}")
    destination = GenServer.call(state.nameserver, {:get, server})
    abs_path = Path.absname(Path.join(state.root, src_path))
    {:ok, file} = File.open(abs_path, [:read])
    :success = GenServer.call(destination, {:write_file, dst_path, file})
    {:reply, "success", state}
  end

  # Deletes file on it's own node
  @impl true
  def handle_call({:del_recv, path}, _from, state) do
    Logger.info("Deleting file #{path}")
    abs_path = Path.absname(Path.join(state.root, path))

    {:ok, files_removed} = File.rm_rf(abs_path)
    {:reply, files_removed, state}
  end

  # Deletes file on another node
  @impl true
  def handle_call({:del_send, path, server}, _from, state)
      when is_bitstring(path) and is_bitstring(server) do
    Logger.info("Deleting file/dir: #{path} on #{server}")
    destination = GenServer.call(state.nameserver, {:get, server})
    res = GenServer.call(destination, {:del_recv, path}) |>
    Enum.join(" ")
    {:reply, "Removed: #{res}", state}
  end

  @impl true
  # Remove itself from the nameserver when it exits/crashes
  def terminate(_reason, state) do
    Logger.warning("Killing FileManager, removing from NameServer")
    GenServer.cast(state.nameserver, {:delete, state.name})
  end
end
