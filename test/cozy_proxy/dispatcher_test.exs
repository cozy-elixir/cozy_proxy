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

    test "by matching host via regex is supported" do
      backends = [
        Backend.new!(plug: SamplePlug.General, host: ~r/^test/)
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

      # the internal implemention modify conn
      assert conn.request_path == "/api"
      assert conn.path_info == ["api"]
      assert conn.script_name == []
    end
  end

  describe "Path rewriting" do
    test "is enabled by default" do
      backends = [
        Backend.new!(plug: SamplePlug.EchoPath, path: "/api")
      ]

      conn = conn(:post, "/api/v1")
      conn = dispatch(conn, backends)

      assert conn.state == :sent
      assert conn.status == 200
      assert conn.resp_body == "/v1"
    end

    test "can be disabled" do
      backends = [
        Backend.new!(plug: SamplePlug.EchoPath, path: "/api", rewrite_path_info: false)
      ]

      conn = conn(:post, "/api/v1")
      conn = dispatch(conn, backends)

      assert conn.state == :sent
      assert conn.status == 200
      assert conn.resp_body == "/api/v1"
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
      #   Backend.new!(plug: SamplePlug.WebSocket, path: "/")
      # ]

      # I have tested the proxy for WebSocket connections in real appliactions.
      # But, I don't know how to test it in `mix test` for now.
    end

    @tag capture_log: true
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
