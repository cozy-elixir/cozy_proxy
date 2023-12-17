# CozyProxy

[![CI](https://github.com/cozy-elixir/cozy_proxy/actions/workflows/ci.yml/badge.svg)](https://github.com/cozy-elixir/cozy_proxy/actions/workflows/ci.yml)
[![Hex.pm](https://img.shields.io/hexpm/v/cozy_proxy.svg)](https://hex.pm/packages/cozy_proxy)
[![built with Nix](https://img.shields.io/badge/built%20with%20Nix-5277C3?logo=nixos&logoColor=white)](https://builtwithnix.org)

> Proxy requests to other plugs.

## Features

- General plug support
- WebSocket support (requires [`Plug >= 1.14`](https://github.com/elixir-plug/plug/blob/2ef07cdd2732cde5cac73fc39b49fe83d5fcc369/README.md?plain=1#L71))
- Phoenix Endpoint support (requires [`Phoenix >= 1.7`](https://github.com/phoenixframework/phoenix/blob/v1.7.0/mix.exs#L73))

## Installation

Add `cozy_proxy` to the list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:cozy_proxy, "~> <version>"}
  ]
end
```

## Usage

For more information, see the [documentation](https://hexdocs.pm/cozy_proxy/CozyProxy.html).

## Thanks

This library is built on the wisdom in following code:

- [main_proxy](https://github.com/Main-Proxy/main_proxy)
- [snake_proxy](https://github.com/evadne/snake/tree/master/apps/snake_proxy)
- [master_proxy](https://github.com/wojtekmach/acme_bank/tree/master/apps/master_proxy) application inside the [acme_bank](https://github.com/wojtekmach/acme_bank) project from [wojtekmach](https://github.com/wojtekmach)
- [master_proxy.ex](https://gist.github.com/Gazler/fe7ed5dc598250002dfe) from [Gazler](https://github.com/Gazler)

## License

Apache License 2.0
