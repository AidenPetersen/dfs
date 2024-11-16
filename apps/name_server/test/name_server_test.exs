defmodule NameServerTest do
  use ExUnit.Case
  doctest NameServer

  test "Register Server" do
    {:ok, pid} = GenServer.start_link(NameServer.KV, %{})
    NameServer.KV.register(pid, "test", self())
    assert NameServer.KV.get(pid, "test") == self()
  end

  test "Register Duplicate" do
    {:ok, pid} = GenServer.start_link(NameServer.KV, %{})
    result1 = NameServer.KV.register(pid, "test", self())
    result2 = NameServer.KV.register(pid, "test", self())
    assert result1 == :success
    assert result2 == :duplicate
  end
end
