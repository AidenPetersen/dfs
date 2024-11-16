defmodule NameServer do
  @moduledoc """
  `NameServer` Application. Holds name process mapping for available file servers.
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      NameServer.KV,
    ]
    opts = [strategy: :one_for_one, name: NameServer.Supervisor]
    IO.puts("Starting nameserver...")
    Supervisor.start_link(children, opts)

  end
end
