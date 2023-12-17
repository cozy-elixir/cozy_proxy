defmodule CozyProxy.DispatcherTest do
  use ExUnit.Case, async: true

  use Plug.Test
  alias CozyProxy.Dispatcher
  alias CozyProxy.Backend

  defp dispatch(conn, backends) do
    opts = Dispatcher.init(backends: backends)
    Dispatcher.call(conn, opts)
  end

  describe "Dispatch request to error plug" do
    test "when backends are empty" do
      backends = []
      conn = conn(:get, "/")
      conn = dispatch(conn, backends)

      assert conn.state == :sent
      assert conn.status == 404
      assert conn.resp_body == "No backends matched"
    end

    test "when no backend is matched" do
      backends = [
        Backend.new!(plug: SamplePlug.General)
      ]

      conn = conn(:get, "/")
      conn = dispatch(conn, backends)

      assert conn.state == :sent
      assert conn.status == 404
      assert conn.resp_body == "No backends matched"
    end
  end

  describe "Dispatch request" do
    test "by matching method is supported" do
      backends = [
        Backend.new!(plug: SamplePlug.General, method: "POST")
      ]

      conn = conn(:post, "/")
      conn = dispatch(conn, backends)

      assert conn.state == :sent
      assert conn.status == 200
      assert conn.resp_body == "Plug: Hello, World!"
    end

    test "by matching host is supported" do
      backends = [
        Backend.new!(plug: SamplePlug.General, host: "test.example.com")
      ]

      conn = conn(:post, "https://test.example.com/")
      conn = dispatch(conn, backends)

      assert conn.state == :sent
      assert conn.status == 200
      assert conn.resp_body == "Plug: Hello, World!"
    end

    test "by matching path is supported" do
      backends = [
        Backend.new!(plug: SamplePlug.General, path: "/api")
      ]

      conn = conn(:post, "/api")
      conn = dispatch(conn, backends)

      assert conn.state == :sent
      assert conn.status == 200
      assert conn.resp_body == "Plug: Hello, World!"
    end
  end

  describe "Respond with" do
    test "General Plug is supported" do
      backends = [
        Backend.new!(plug: SamplePlug.General, method: "GET")
      ]

      conn = conn(:get, "/")
      conn = dispatch(conn, backends)

      assert conn.state == :sent
      assert conn.status == 200
      assert conn.resp_body == "Plug: Hello, World!"
    end

    test "WebSocket Plug is supported" do
      # backends = [
      #   Backend.new!(plug: SamplePlug.WebSocket)
      # ]
      #
      # I don't know how to test it for now
    end

    test "Phoenix Endpoint is supported" do
      # prevent the warning of missing necessary configuration
      Application.put_env(:sample_phoenix, SamplePhoenix.Endpoint, [])

      backends = [
        Backend.new!(plug: SamplePhoenix.Endpoint, method: "GET")
      ]

      start_supervised!(SamplePhoenix.Endpoint)

      conn = conn(:get, "/")
      conn = dispatch(conn, backends)

      assert conn.state == :sent
      assert conn.status == 200
      assert conn.resp_body == "Phoenix: Hello, World!"
    end
  end
end
