import Config

config :beamjs_core,
  memory_limit: 256 * 1024 * 1024,
  max_stack_size: 1024 * 1024,
  max_processes: 10_000

import_config "#{Mix.env()}.exs"
