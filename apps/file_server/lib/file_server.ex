defmodule FileServer do
  @moduledoc """
  `FileServer` Application. Supervises the FileManager, and TCP server.
  This section really examplifies the "let if fail" philosphy.
  If the FileManager ever fails, it restarts itself and all other processes.
  This will occur if you give it an invalid command.
  """
  alias FileServer.TCPServer
  require Logger
  use Application

  @impl true
  def start(_type, args) do
    [root, name, port] = args
    ns_proc = :global.whereis_name({:name, NameServer})
    Logger.info("ns_proc: #{inspect(ns_proc)}")
    # Define 3 children, FileManager genserver, TCP server supervisor, and TCP server
    children = [
      {FileServer.FileManager, [root, ns_proc, name]},
      {Task.Supervisor, name: FileServer.TCPServer.TaskSupervisor},
      # Must have childspec to when FileManager crashes TCP server doesn't continue to try to send
      # crashing message to FileManager when it restarts. We use one_for_all strategy for FileManager
      # so that the TCP server restarts.
      Supervisor.child_spec({Task, fn -> TCPServer.accept(port) end}, restart: :permanent)
    ]

    opts = [
      strategy: :one_for_all,
      name: FileServer.Supervisor,
      restart: :permanent
    ]

    Logger.info("Launching fileserver #{name}")
    Supervisor.start_link(children, opts)
  end
end
