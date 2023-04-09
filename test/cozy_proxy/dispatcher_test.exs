defmodule CozyProxy.DispatcherTest do
  use ExUnit.Case, async: true

  use Plug.Test
  alias CozyProxy.Dispatcher
  alias CozyProxy.Backend

  defp dispatch(conn, backends) do
    opts = Dispatcher.init(backends: backends)
    Dispatcher.call(conn, opts)
  end

  describe "Empty backends" do
    setup do
      backends = []

      %{backends: backends}
    end

    test "will cause the request to be sent to the error plug", %{backends: backends} do
      conn = conn(:get, "/")
      conn = dispatch(conn, backends)

      assert conn.state == :sent
      assert conn.status == 404
      assert conn.resp_body == "No backends matched"
    end
  end

  describe "Plug - General" do
    setup do
      backends = [
        Backend.new!(plug: SamplePlug.General)
      ]

      %{backends: backends}
    end

    test "is supported", %{backends: backends} do
      conn = conn(:get, "/")
      conn = dispatch(conn, backends)

      assert conn.resp_body == "Plug: Hello, World!"
    end
  end

  describe "Plug - WebSocket" do
    setup do
      backends = [
        Backend.new!(plug: SamplePlug.WebSocket)
      ]

      %{backends: backends}
    end

    test "is supported", %{backends: _backends} do
      # TODO: I don't know how to test it for now
    end
  end

  describe "Phoenix Endpoint" do
    setup do
      # prevent the warning of missing necessary configuration
      Application.put_env(:sample_phoenix, SamplePhoenix.Endpoint, [])

      backends = [
        Backend.new!(plug: SamplePhoenix.Endpoint)
      ]

      start_link_supervised!(SamplePhoenix.Endpoint)

      %{backends: backends}
    end

    test "is supported", %{backends: backends} do
      conn = conn(:get, "/")
      conn = dispatch(conn, backends)

      assert conn.resp_body == "Phoenix: Hello, World!"
    end
  end
end
