// beamjs:pipe - Pipeline operator for JavaScript
// Provides Elixir-style |> piping via method chaining.

export class Pipeline {
  constructor(value) {
    this._value = value;
  }

  then(fn) {
    return new Pipeline(fn(this._value));
  }

  tap(fn) {
    fn(this._value);
    return this;
  }

  when(predicate, fn) {
    if (predicate(this._value)) {
      return new Pipeline(fn(this._value));
    }
    return this;
  }

  unless(predicate, fn) {
    if (!predicate(this._value)) {
      return new Pipeline(fn(this._value));
    }
    return this;
  }

  match(clauses) {
    // Integrates with beamjs:match
    for (const clause of clauses) {
      const bindings = {};
      if (matchPattern(this._value, clause.pattern, bindings)) {
        if (!clause.guardFn || clause.guardFn(bindings)) {
          return new Pipeline(clause.handler(bindings));
        }
      }
    }
    throw new Error(`No matching clause in pipe for: ${JSON.stringify(this._value)}`);
  }

  value() {
    return this._value;
  }
}

export function pipe(value) {
  return new Pipeline(value);
}

// Functional pipe (no chaining, just composition)
export function compose(...fns) {
  return (input) => fns.reduce((acc, fn) => fn(acc), input);
}

// Apply a series of functions to a value
export function pipeThrough(value, ...fns) {
  return fns.reduce((acc, fn) => fn(acc), value);
}

// Simple pattern matching helper for pipe.match()
function matchPattern(value, pattern, bindings) {
  if (pattern && pattern.__type === "bind") {
    bindings[pattern.name] = value;
    return true;
  }
  if (typeof pattern !== "object" || pattern === null) {
    return value === pattern;
  }
  if (typeof value !== "object" || value === null) return false;
  for (const key of Object.keys(pattern)) {
    if (!(key in value)) return false;
    if (!matchPattern(value[key], pattern[key], bindings)) return false;
  }
  return true;
}
