# BeamJS

[![npm version](https://img.shields.io/npm/v/beamjs-runtime.svg)](https://www.npmjs.com/package/beamjs-runtime)
[![GitHub](https://img.shields.io/github/license/the-einstein/beamjs)](https://github.com/the-einstein/beamjs)

A standalone JavaScript/TypeScript runtime built on the **BEAM VM** (Elixir/Erlang) with **QuickJS** as the embedded JS engine. No Node.js. No V8. Just the BEAM and a tiny, ES2023-compliant JS engine working together.

BeamJS gives JavaScript developers real Erlang/OTP superpowers: lightweight processes, supervision trees, GenServer, pattern matching, and pipe operators -- all backed by the battle-tested BEAM virtual machine that powers WhatsApp, Discord, and countless telecom systems.

## Why BeamJS?

| Problem | BeamJS Solution |
|---|---|
| Node.js is single-threaded | BEAM schedules thousands of lightweight processes across all CPU cores |
| No built-in fault tolerance | OTP supervision trees automatically restart crashed processes |
| Shared mutable state causes bugs | Actor model with message passing -- no shared state between processes |
| Complex async/callback patterns | Elixir-style `receive()` blocks the process without blocking the VM |
| No pattern matching in JS | First-class pattern matching with bindings, wildcards, and guards |

## Architecture

```
 ┌─────────────────────────────────────────────────┐
 │                  JavaScript Code                │
 │   (ES2023, modules, async/await, classes)       │
 ├─────────────────────────────────────────────────┤
 │              QuickJS Engine (NIF)               │
 │   Embedded via Erlang NIFs on dirty CPU         │
 │   schedulers. Each process gets its own         │
 │   isolated JSRuntime + JSContext (~50KB)         │
 ├─────────────────────────────────────────────────┤
 │             Elixir/OTP Layer                    │
 │   GenServer per JS process, Registry,           │
 │   DynamicSupervisor, host function callbacks,   │
 │   module resolution, TypeScript transpilation   │
 ├─────────────────────────────────────────────────┤
 │               BEAM VM (OTP 24+)                 │
 │   Preemptive scheduling, fault tolerance,       │
 │   hot code loading, distribution                │
 └─────────────────────────────────────────────────┘
```

**Three layers:**

1. **C Layer** -- QuickJS (2024-01-13) compiled as an Erlang NIF. All JS evaluation runs on dirty CPU schedulers so the BEAM's normal schedulers are never blocked. Handles bidirectional Erlang term <-> JS value marshaling, host function callbacks via condvar synchronization, and a custom ES module loader for `beamjs:*` imports.

2. **Elixir/OTP Layer** -- Each JS "process" is a `GenServer` wrapping a QuickJS context. Processes are registered in an OTP `Registry` and managed by a `DynamicSupervisor`. Host function callbacks (like `send`, `receive`, `spawn`) are dispatched from the NIF to the GenServer via message passing. The supervisor bridge translates JS supervisor specs into real OTP supervisor trees.

3. **JS Standard Library** -- 9 built-in modules: `beamjs:process`, `beamjs:gen_server`, `beamjs:supervisor`, `beamjs:match`, `beamjs:pipe`, `beamjs:task`, `beamjs:agent`, `beamjs:timer`, `beamjs:test`. These call host functions injected by the NIF layer to bridge into BEAM primitives.

## Install

### via npm (recommended)

Zero dependencies. The npm package bundles the entire BEAM runtime + QuickJS engine as a standalone binary (~5.9MB).

```bash
npm install -g beamjs-runtime
```

That's it. Now you can use `beamjs` from anywhere:

```bash
beamjs version
# BeamJS v0.1.0 (QuickJS on BEAM/OTP 24)

beamjs run app.js
beamjs new myapp
beamjs shell
```

> **Supported platforms:** Linux x64, macOS arm64 (Apple Silicon), Windows x64. On `npm install`, the correct binary is automatically downloaded for your platform.

### From source

If you want to build from source or contribute:

**Prerequisites:** Elixir 1.12+, Erlang/OTP 24+, GCC, Make

```bash
git clone https://github.com/the-einstein/beamjs.git
cd beamjs
mix deps.get
cd apps/beamjs_nif/c_src && make && cd ../../..
mix compile

# Run a JavaScript file
./beamjs run test/fixtures/hello.js

# Start the interactive REPL
./beamjs shell

# Create a new project
./beamjs new myapp

# Run all Elixir + NIF tests
mix test
```

### Build the npm package locally

```bash
bash scripts/build-npm.sh
npm install -g npm/beamjs-runtime-0.1.0.tgz
```

## Features

### Pattern Matching

Elixir-style pattern matching with wildcards (`_`), variable bindings (`bind`), guards, and deep object/array matching.

```javascript
// Match HTTP responses
var result = match(response, [
  when({ status: 200, body: bind("b") }, function(b) {
    return "OK: " + JSON.stringify(b.b);
  }),
  when({ status: 404 }, function() {
    return "Not Found";
  }),
  when({ status: 500, message: bind("m") }, function(b) {
    return "Server Error: " + b.m;
  }),
  when(_, function() {
    return "Unknown status";
  }),
]);

// Nested pattern matching
match({ user: { name: "Alice", role: "admin" }, action: "delete" }, [
  when({ user: { role: "admin" }, action: bind("a") }, function(b) {
    return "Admin action: " + b.a;  // "Admin action: delete"
  }),
  when({ user: { role: "user" } }, function() {
    return "Regular user";
  }),
]);

// Array pattern matching
match([1, 2, 3], [
  when([1, bind("second"), bind("third")], function(b) {
    return "second=" + b.second + " third=" + b.third;
  }),
]);
```

### Pipeline Operator

Elixir-style `|>` piping via method chaining. Transform data through a sequence of functions with `then`, inspect intermediate values with `tap`, and conditionally apply transforms with `when`.

```javascript
// Data processing pipeline
var result = pipe(rawData)
  .then(function(d) { return d.filter(function(u) { return u.active; }); })
  .then(function(d) { return d.map(function(u) { return u.name.toUpperCase(); }); })
  .then(function(d) { return d.sort(); })
  .tap(function(d) { console.log("Sorted:", d); })  // side effect, doesn't change value
  .then(function(d) { return d.join(", "); })
  .value();

// Conditional pipeline
pipe(10)
  .when(function(x) { return x > 5; }, function(x) { return x * 10; })
  .value();  // 100

// Functional composition (no chaining)
var transform = compose(
  function(x) { return x * 2; },
  function(x) { return x + 10; },
  function(x) { return "Result: " + x; }
);
transform(5);  // "Result: 20"
```

### Process Spawning & Message Passing

Each `spawn()` creates a real BEAM process with its own QuickJS context. Processes communicate via message passing -- no shared mutable state.

```javascript
// Spawn a process
var pid = spawn(function() {
  var msg = receive();
  console.log("Got:", msg);
});
send(pid, { hello: "world" });

// Named processes
spawn(function() {
  register("greeter");
  while (true) {
    var msg = receive();
    send(msg.from, "Hello, " + msg.name + "!");
  }
});

// Send to named process
var greeter = whereis("greeter");
send(greeter, { from: self(), name: "BeamJS" });
```

### GenServer

The GenServer class maps to OTP GenServer -- a generic server process that handles synchronous calls and asynchronous casts.

```javascript
class Counter extends GenServer {
  init(args) {
    return { count: args.initial || 0 };
  }

  handleCall(request, from, state) {
    if (request === "increment") {
      var newCount = state.count + 1;
      return { reply: newCount, state: { count: newCount } };
    }
    if (request === "get") {
      return { reply: state.count, state: state };
    }
    return { reply: null, state: state };
  }

  handleCast(request, state) {
    if (request === "reset") {
      return { noreply: true, state: { count: 0 } };
    }
    return { noreply: true, state: state };
  }
}

// Start and interact
var result = GenServer.start(Counter, { initial: 0 }, { name: "counter" });
GenServer.call("counter", "increment");  // 1
GenServer.call("counter", "increment");  // 2
GenServer.call("counter", "get");        // 2
GenServer.cast("counter", "reset");
```

### Supervision Trees

Supervisors monitor child processes and restart them according to a strategy when they crash.

```javascript
Supervisor.start({
  strategy: "one_for_one",  // also: "one_for_all", "rest_for_one"
  maxRestarts: 3,
  maxSeconds: 5,
  children: [
    {
      id: "counter",
      start: { module: Counter, args: { initial: 0 } },
      restart: "permanent"   // also: "temporary", "transient"
    }
  ]
});
```

### Test Framework

Built-in test runner with `describe`, `it`, and `expect` assertions.

```javascript
// test/math.test.js
describe("Math", function() {
  it("should add numbers", function() {
    expect(1 + 1).toBe(2);
  });

  it("should handle arrays", function() {
    expect([1, 2, 3]).toContain(2);
  });

  it("should catch errors", function() {
    expect(function() { throw new Error("boom"); }).toThrow("boom");
  });
});

run();  // Executes all tests and prints results
```

```bash
beamjs test
```

### TypeScript Support

BeamJS includes a lightweight TypeScript transpiler that strips type annotations before evaluation. Files with `.ts` or `.tsx` extensions are automatically transpiled.

```typescript
// Supported: type annotations, interfaces, type aliases
const x: number = 42;
interface User { name: string; age: number; }
type Result = { ok: boolean; data: any };
```

## CLI Commands

| Command | Description |
|---|---|
| `beamjs run <file>` | Execute a JavaScript or TypeScript file |
| `beamjs shell` | Start an interactive REPL with persistent context |
| `beamjs new <name>` | Scaffold a new project with `beamjs.json`, `src/`, `test/` |
| `beamjs new <name> --supervised` | Scaffold with a supervision tree template |
| `beamjs test` | Discover and run `*.test.js` files in `test/` |
| `beamjs version` | Print version info (BeamJS, QuickJS, OTP, Elixir) |

## Project Structure

```
beamjs/
├── mix.exs                              # Umbrella root
├── beamjs                               # CLI launcher script
├── config/                              # Elixir config (dev/test/prod)
├── apps/
│   ├── beamjs_nif/                      # C NIF layer (QuickJS integration)
│   │   ├── c_src/
│   │   │   ├── beamjs_nif.c             # NIF entry point (8 NIF functions)
│   │   │   ├── beamjs_nif.h             # Shared types (BeamjsContext, atoms)
│   │   │   ├── term_convert.c/h         # Erlang <-> JS value marshaling
│   │   │   ├── host_functions.c/h       # 22 host functions exposed to JS
│   │   │   ├── module_loader.c/h        # Custom ES module loader
│   │   │   ├── Makefile                 # Builds beamjs_nif.so
│   │   │   └── quickjs/                 # Vendored QuickJS source (2024-01-13)
│   │   ├── lib/beamjs_nif.ex            # Elixir NIF stubs
│   │   ├── priv/beamjs_nif.so           # Compiled NIF (~1MB)
│   │   └── test/beamjs_nif_test.exs     # 18 NIF tests
│   │
│   ├── beamjs_core/                     # Elixir/OTP runtime core
│   │   ├── lib/beamjs_core/
│   │   │   ├── process.ex               # GenServer wrapping QuickJS context
│   │   │   ├── supervisor_bridge.ex     # JS supervisor -> OTP supervisor
│   │   │   ├── module_resolver.ex       # beamjs:* and file import resolution
│   │   │   ├── transpiler.ex            # TypeScript type stripping
│   │   │   └── application.ex           # OTP app (Registry + DynamicSupervisor)
│   │   ├── priv/js_stdlib/              # JS standard library (9 modules)
│   │   │   ├── process.js               # spawn, send, receive, self
│   │   │   ├── gen_server.js            # GenServer class
│   │   │   ├── supervisor.js            # Supervisor class
│   │   │   ├── match.js                 # Pattern matching
│   │   │   ├── pipe.js                  # Pipeline operator
│   │   │   ├── task.js                  # Async tasks
│   │   │   ├── agent.js                 # State management
│   │   │   ├── timer.js                 # Timer utilities
│   │   │   └── test.js                  # Test framework
│   │   └── test/beamjs_core_test.exs    # 8 core tests
│   │
│   └── beamjs_cli/                      # CLI application
│       ├── lib/beamjs_cli/
│       │   ├── commands/
│       │   │   ├── run.ex               # beamjs run
│       │   │   ├── shell.ex             # beamjs shell
│       │   │   ├── new.ex               # beamjs new
│       │   │   ├── test.ex              # beamjs test
│       │   │   └── version.ex           # beamjs version
│       │   └── repl.ex                  # Interactive REPL
│       └── test/beamjs_cli_test.exs     # 2 CLI tests
│
├── npm/                                 # npm package for distribution
│   ├── package.json                     # beamjs-runtime on npmjs.com
│   ├── bin/beamjs                       # Node.js shim (exec's release binary)
│   └── install.js                       # postinstall: extracts release tarball
│
├── scripts/
│   └── build-npm.sh                     # Build release + package for npm
│
├── rel/
│   └── env.sh.eex                       # Release environment config
│
├── test/fixtures/                       # JS test files
│   ├── hello.js                         # Basic hello world
│   ├── pattern_match.js                 # Pattern matching tests
│   ├── pipe.js                          # Pipeline tests
│   └── comprehensive.js                 # Full feature test (12 subtests)
│
└── js_stdlib/src/                       # JS stdlib TypeScript source
```

## How It Works

### Term Conversion (Erlang <-> JavaScript)

| Erlang | JavaScript | Notes |
|---|---|---|
| `integer` | `Number` | Int32 range or Float64 |
| `float` | `Number` | |
| `binary` (UTF-8) | `String` | |
| `true` / `false` | `true` / `false` | |
| `nil` / `null` | `null` | |
| `undefined` | `undefined` | |
| other atoms | `String` | Atom name as string |
| `list` | `Array` | |
| `map` | `Object` | String keys become properties |
| `tuple` | `Array` | |

### Host Function Callback Mechanism

When JS code calls a host function (like `send` or `spawn`):

1. The C NIF converts JS args to Erlang terms
2. Sends `{:host_call, fn_name, args}` to the owning BEAM process via `enif_send()`
3. Blocks on a condition variable (safe on dirty scheduler)
4. The GenServer's `handle_info` dispatches the call and performs the operation
5. Calls `deliver_host_reply/2` which signals the condvar
6. The NIF wakes up, converts the Erlang reply to a JS value, and returns it to JS

This pattern allows JS code to synchronously call into the BEAM's OTP infrastructure while keeping the BEAM's normal schedulers unblocked.

### Process Isolation

Each `spawn()` creates:
- A new BEAM process (GenServer)
- A new QuickJS `JSRuntime` + `JSContext` (~50KB memory)
- Its own message mailbox
- Independent garbage collection

Processes cannot share JS objects. `spawn(fn)` serializes the function via `fn.toString()` and evaluates it in the new context. This matches the Erlang actor model: no shared mutable state, communication only through message passing.

## Current Status

### Working
- **npm distribution** -- `npm install -g beamjs-runtime` (standalone 5.9MB binary, zero dependencies)
- **JS evaluation on BEAM** via QuickJS NIF with dirty CPU schedulers
- **Full ES2023 JavaScript support** (QuickJS 2024-01-13)
- **`console.log` / `console.error`** (direct stdout/stderr, no host round-trip)
- **Process spawning and message passing** via BEAM actors
- **GenServer behavior bridge** -- JS classes delegating to OTP GenServer
- **Supervisor bridge** -- one_for_one, one_for_all, rest_for_one strategies
- **Pattern matching** -- wildcards, bindings, guards, nested object/array matching
- **Pipeline operator** -- then/tap/when/value chaining
- **Task and Agent** abstractions
- **CLI** -- `run`, `shell` (REPL), `new` (scaffolding), `test`, `version`
- **TypeScript** -- lightweight type stripping
- **Module resolution** for `beamjs:*` imports
- **28 passing Elixir tests** + **4 JS fixture tests** (12 subtests)

### Planned
- macOS x64 (Intel) support
- ES module imports for user files (`import`/`export`)
- Full TypeScript compiler (via QuickJS-hosted tsc)
- Distribution (cross-node messaging)
- Hot code reload
- Port-based safety backend (alternative to NIF)
- GenStage producer/consumer patterns
- Package manager / dependency resolution

## Tests

```bash
# Run all tests
mix test

# Run only NIF tests
mix test apps/beamjs_nif

# Run only core tests
mix test apps/beamjs_core

# Run JS fixture tests manually
beamjs run test/fixtures/comprehensive.js
```

## Key Design Decisions

- **NIF over Ports**: NIFs are ~100x faster for the frequent small calls (term marshaling, short evals). Dirty CPU schedulers prevent blocking BEAM's normal schedulers. A Port-based safety backend is planned for Phase 4.

- **One JSRuntime per process**: No sharing, no locking during evaluation. The NIF resource destructor ensures cleanup when the owning BEAM process terminates.

- **No closures across processes**: Functions are serialized via `toString()`. This is intentional -- it matches the actor model where processes don't share mutable state.

- **`JS_UpdateStackTop`**: Critical for dirty scheduler compatibility. QuickJS checks stack depth relative to a base pointer; without updating it on each eval, the different stack addresses of dirty scheduler threads trigger false "stack overflow" errors.

## License

MIT
