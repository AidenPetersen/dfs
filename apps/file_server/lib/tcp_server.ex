defmodule FileServer.TCPServer do
  require Logger

  # I'm grabbing most of this from the docs: https://hexdocs.pm/elixir/main/task-and-gen-tcp.html
  def accept(port) do
    server = Process.whereis(FileServer.FileManager)
    {:ok, socket} =
      :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])

    Logger.info("Accepting connections on port #{port}")
    loop_acceptor(socket, server)
  end

  defp loop_acceptor(socket, server) do
    {:ok, client} = :gen_tcp.accept(socket)
    {:ok, pid} = Task.Supervisor.start_child(FileServer.TCPServer.TaskSupervisor, fn -> serve(client, server) end)
    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket, server)
  end

  defp serve(socket, server) do
    read_command(socket)
    |> execute_command(socket, server)

    serve(socket, server)
  end

  defp read_command(socket) do
    {:ok, data} = :gen_tcp.recv(socket, 0)
    String.split(data)
    |> get_command()
  end

  defp get_command([command | args]) do
    case command do
      "ls" -> {:ls, args}
      "get" -> {:get, args}
      "put" -> {:put, args}
      "read" -> {:read, args}
      "del" -> {:del, args}
      "stop" -> {:stop}
      _ -> :err
    end
  end

  defp get_command(_command) do
    :err
  end

  defp execute_command(command, socket, server) do
    res =
      case command do
        {:ls, [path, dst]} -> GenServer.call(server, {:ls_send, path, dst})
        {:get, [src_path, dst_path, dst]} -> GenServer.call(server, {:get_send, src_path, dst_path, dst})
        {:put, [src_path, dst_path, dst]} -> GenServer.call(server, {:put_send, src_path, dst_path, dst})
        {:read, [path, dst]} -> GenServer.call(server, {:read_send, path, dst})
        {:del, [path, dst]} -> GenServer.call(server, {:del_send, path, dst})
        {:stop} -> Supervisor.stop(FileServer.Supervisor)
        _ -> "invalid command"
      end

    :gen_tcp.send(socket, "#{res}\n")
  end
end
