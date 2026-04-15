# BeamJS

A standalone JavaScript/TypeScript runtime built on the **BEAM VM** (Elixir/Erlang) with **QuickJS**. No Node.js. No V8. Just the BEAM and a tiny, ES2023-compliant JS engine working together.

BeamJS gives JavaScript developers real Erlang/OTP superpowers: lightweight processes, supervision trees, GenServer, pattern matching, and pipe operators.

## Install

```bash
npm install -g beamjs-runtime
```

Done. The package bundles the entire BEAM runtime + QuickJS engine as a standalone binary (~5.9MB). Zero external dependencies.

> **Platform support:** Currently ships Linux x64. macOS and ARM64 coming soon.

## Usage

```bash
# Run a JavaScript file
beamjs run app.js

# Start interactive REPL
beamjs shell

# Create a new project
beamjs new myapp

# Run tests
beamjs test

# Print version
beamjs version
```

## What Makes BeamJS Different

```
 ┌──────────────────────────────────────┐
 │          Your JavaScript Code        │
 ├──────────────────────────────────────┤
 │      QuickJS Engine (ES2023)         │
 ├──────────────────────────────────────┤
 │      Elixir/OTP (GenServer,          │
 │      Supervisors, Registry)          │
 ├──────────────────────────────────────┤
 │      BEAM VM (preemptive             │
 │      scheduling, fault tolerance)    │
 └──────────────────────────────────────┘
```

| Node.js | BeamJS |
|---|---|
| Single-threaded event loop | Thousands of lightweight processes across all cores |
| Crash = app dies | Supervisors auto-restart crashed processes |
| Shared mutable state | Actor model — message passing, no shared state |
| Complex async/callback chains | `receive()` blocks the process, not the VM |
| No pattern matching | First-class pattern matching with bindings and guards |

## Features

### Pattern Matching

```javascript
var result = match(response, [
  when({ status: 200, body: bind("b") }, function(ctx) {
    return "OK: " + JSON.stringify(ctx.b);
  }),
  when({ status: 404 }, function() { return "Not Found"; }),
  when({ status: 500, message: bind("m") }, function(ctx) {
    return "Error: " + ctx.m;
  }),
  when(_, function() { return "Unknown"; }),
]);
```

### Pipeline Operator

```javascript
var result = pipe(users)
  .then(function(u) { return u.filter(function(x) { return x.active; }); })
  .then(function(u) { return u.map(function(x) { return x.name; }); })
  .then(function(names) { return names.join(", "); })
  .value();
```

### Process Spawning & Message Passing

```javascript
var pid = spawn(function() {
  var msg = receive();
  console.log("Got:", msg);
});
send(pid, { hello: "world" });
```

### GenServer

```javascript
class Counter extends GenServer {
  init(args) { return { count: 0 }; }

  handleCall(request, from, state) {
    if (request === "increment") {
      var n = state.count + 1;
      return { reply: n, state: { count: n } };
    }
    return { reply: state.count, state: state };
  }
}

GenServer.start(Counter, {}, { name: "counter" });
GenServer.call("counter", "increment"); // 1
GenServer.call("counter", "increment"); // 2
```

### Supervision Trees

```javascript
Supervisor.start({
  strategy: "one_for_one",
  children: [
    { id: "counter", start: { module: Counter, args: {} }, restart: "permanent" }
  ]
});
```

### REPL

```
$ beamjs shell
BeamJS v0.1.0 (QuickJS on BEAM/OTP 24)
Type .help for help, .exit to quit

beamjs(1)> 1 + 2
=> 3
beamjs(2)> [1,2,3].map(function(n) { return n * n; })
=> [1, 4, 9]
beamjs(3)> var fib = function(n) { return n <= 1 ? n : fib(n-1) + fib(n-2); }
beamjs(4)> fib(10)
=> 55
```

### Project Scaffolding

```
$ beamjs new myapp
Created new BeamJS project: myapp

  cd myapp
  beamjs run src/main.js

$ cat myapp/beamjs.json
{
  "name": "myapp",
  "version": "0.1.0",
  "main": "src/main.js"
}
```

## How It Works

BeamJS embeds the [QuickJS](https://bellard.org/quickjs/) JavaScript engine inside the Erlang/Elixir BEAM VM via Native Implemented Functions (NIFs). Each JavaScript "process" runs in its own BEAM GenServer with an isolated QuickJS runtime (~50KB memory). Processes communicate through BEAM's built-in message passing — no shared mutable state.

The NIF layer runs all JS evaluation on BEAM's dirty CPU schedulers, so normal BEAM scheduling is never blocked. Host functions (`send`, `receive`, `spawn`, etc.) bridge JS calls into OTP primitives through a condvar-synchronized callback mechanism.

The npm package bundles a complete `mix release` — ERTS (Erlang Runtime System) + compiled BEAM files + NIF shared library — so no Elixir or Erlang installation is needed.

## Links

- **GitHub**: [github.com/the-einstein/beamjs](https://github.com/the-einstein/beamjs)
- **Issues**: [github.com/the-einstein/beamjs/issues](https://github.com/the-einstein/beamjs/issues)

## License

MIT
