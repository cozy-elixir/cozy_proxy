defmodule CozyProxy.ErrorPlug do
  @moduledoc false

  import Plug.Conn
  require Logger

  @behaviour Plug

  @impl true
  def init(opts) do
    opts
  end

  @impl true
  def call(conn, _opts) do
    conn
    |> resp(404, "No backends matched")
    |> send_resp()
  end
end
