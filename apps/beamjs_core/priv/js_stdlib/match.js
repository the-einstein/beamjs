// beamjs:match - Pattern matching for JavaScript
// Pure JS implementation, no host function calls needed.

export const _ = Symbol.for("beamjs:wildcard");
export const REST = Symbol.for("beamjs:rest");

export function bind(name) {
  return { __type: "bind", name };
}

export function guard(predicate) {
  return { __type: "guard", predicate };
}

export function when(pattern, handler, guardFn) {
  return { pattern, handler, guardFn };
}

export function match(value, clauses) {
  for (const clause of clauses) {
    const bindings = {};
    if (matchPattern(value, clause.pattern, bindings)) {
      if (!clause.guardFn || clause.guardFn(bindings)) {
        return clause.handler(bindings);
      }
    }
  }
  throw new Error(`No matching clause for: ${JSON.stringify(value)}`);
}

function matchPattern(value, pattern, bindings) {
  // Wildcard matches anything
  if (pattern === _) return true;

  // Bind marker captures the value
  if (pattern && pattern.__type === "bind") {
    bindings[pattern.name] = value;
    return true;
  }

  // Guard marker checks a predicate
  if (pattern && pattern.__type === "guard") {
    return pattern.predicate(value);
  }

  // Exact equality for primitives
  if (typeof pattern !== "object" || pattern === null) {
    return value === pattern;
  }

  // Array pattern matching
  if (Array.isArray(pattern)) {
    if (!Array.isArray(value)) return false;
    for (let i = 0; i < pattern.length; i++) {
      if (pattern[i] === REST) {
        if (i + 1 < pattern.length && pattern[i + 1] && pattern[i + 1].__type === "bind") {
          bindings[pattern[i + 1].name] = value.slice(i);
        }
        return true;
      }
      if (i >= value.length) return false;
      if (!matchPattern(value[i], pattern[i], bindings)) return false;
    }
    return value.length === pattern.length;
  }

  // Object pattern matching (partial - pattern is subset of value)
  if (typeof value !== "object" || value === null) return false;
  for (const key of Object.keys(pattern)) {
    if (!(key in value)) return false;
    if (!matchPattern(value[key], pattern[key], bindings)) return false;
  }
  return true;
}

export function matchFn(clauses) {
  return (value) => match(value, clauses);
}

// Convenience: cond-like matching
export function cond(pairs) {
  for (const [predicate, handler] of pairs) {
    if (typeof predicate === 'function' ? predicate() : predicate) {
      return typeof handler === 'function' ? handler() : handler;
    }
  }
  throw new Error("No matching condition");
}
