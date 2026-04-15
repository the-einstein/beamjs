defmodule BeamjsCli.Commands.New do
  @moduledoc "Create a new BeamJS project."

  def run([], _opts) do
    IO.puts(:stderr, "Error: no project name specified")
    IO.puts(:stderr, "Usage: beamjs new <name> [--supervised]")
    System.halt(1)
  end

  def run([name | _], opts) do
    if File.exists?(name) do
      IO.puts(:stderr, "Error: directory '#{name}' already exists")
      System.halt(1)
    end

    supervised = Keyword.get(opts, :supervised, false)

    File.mkdir_p!(Path.join(name, "src"))
    File.mkdir_p!(Path.join(name, "test"))

    # beamjs.json
    File.write!(Path.join(name, "beamjs.json"), Jason.encode!(%{
      "name" => name,
      "version" => "0.1.0",
      "main" => "src/main.js",
      "beamjs" => "~> 0.1",
      "scripts" => %{
        "start" => "beamjs run src/main.js",
        "test" => "beamjs test"
      },
      "dependencies" => %{}
    }, pretty: true))

    # .gitignore
    File.write!(Path.join(name, ".gitignore"), """
    beamjs_modules/
    _build/
    .beamjs/
    """)

    if supervised do
      write_supervised_template(name)
    else
      write_default_template(name)
    end

    IO.puts("Created new BeamJS project: #{name}")
    IO.puts("")
    IO.puts("  cd #{name}")
    IO.puts("  beamjs run src/main.js")
    IO.puts("")
  end

  defp write_default_template(name) do
    File.write!(Path.join([name, "src", "main.js"]), """
    // #{name} - A BeamJS application
    console.log("Hello from BeamJS!");

    // Example: Pattern matching
    // import { match, when, _, bind } from "beamjs:match";
    //
    // const result = match({ status: "ok", data: 42 }, [
    //   when({ status: "ok", data: bind("d") }, ({ d }) => `Got: ${d}`),
    //   when({ status: "error" }, () => "Error!"),
    //   when(_, () => "Unknown"),
    // ]);
    // console.log(result);
    """)

    File.write!(Path.join([name, "test", "main.test.js"]), """
    // import { describe, it, expect, run } from "beamjs:test";
    //
    // describe("#{name}", () => {
    //   it("should work", () => {
    //     expect(1 + 1).toBe(2);
    //   });
    // });
    //
    // run();

    console.log("Tests not yet implemented");
    """)
  end

  defp write_supervised_template(name) do
    File.mkdir_p!(Path.join([name, "src", "workers"]))

    File.write!(Path.join([name, "src", "main.js"]), """
    // #{name} - A supervised BeamJS application
    // import { Supervisor } from "beamjs:supervisor";
    // import { GenServer } from "beamjs:gen_server";
    //
    // class Counter extends GenServer {
    //   init(args) { return { count: args.initial || 0 }; }
    //
    //   handleCall(request, from, state) {
    //     if (request === "increment") {
    //       const newCount = state.count + 1;
    //       return { reply: newCount, state: { count: newCount } };
    //     }
    //     if (request === "get") {
    //       return { reply: state.count, state };
    //     }
    //     return { reply: null, state };
    //   }
    // }
    //
    // const { ok: sup } = Supervisor.start({
    //   strategy: "one_for_one",
    //   children: [
    //     { id: "counter", module: Counter, args: { initial: 0 } }
    //   ]
    // });
    //
    // console.log("Supervised application started");

    console.log("Hello from supervised BeamJS app: #{name}!");
    """)

    File.write!(Path.join([name, "test", "main.test.js"]), """
    console.log("Tests not yet implemented");
    """)
  end
end
