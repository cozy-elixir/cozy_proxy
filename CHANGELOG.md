# Changelog

## v0.4.0

Features:

- add `:rewrite_path_info` backend option for controlling path rewriting
- extend `:host` backend option for supporting regex
- add optional `:opts` argument to `CozyProxy.start_link/_`

Breaking changes:

- `CozyProxy.start_link/1` doesn't call `Supervisor.start_link/3` with `[name: CozyProxy]` any more. If you need the name, you should pass it manually.

## v0.3.0

Features:

- add adapter support

Breaking changes:

- change the format the options
