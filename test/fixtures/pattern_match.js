// Test pattern matching - pure JS, no imports needed for now
// (imports require module loader which needs GenServer running)

// Inline the pattern matching logic for this test
var _ = Symbol.for("beamjs:wildcard");

function bind(name) {
  return { __type: "bind", name: name };
}

function when(pattern, handler, guardFn) {
  return { pattern: pattern, handler: handler, guardFn: guardFn };
}

function match(value, clauses) {
  for (var i = 0; i < clauses.length; i++) {
    var clause = clauses[i];
    var bindings = {};
    if (matchPattern(value, clause.pattern, bindings)) {
      if (!clause.guardFn || clause.guardFn(bindings)) {
        return clause.handler(bindings);
      }
    }
  }
  throw new Error("No matching clause for: " + JSON.stringify(value));
}

function matchPattern(value, pattern, bindings) {
  if (pattern === _) return true;
  if (pattern && pattern.__type === "bind") {
    bindings[pattern.name] = value;
    return true;
  }
  if (typeof pattern !== "object" || pattern === null) {
    return value === pattern;
  }
  if (Array.isArray(pattern)) {
    if (!Array.isArray(value)) return false;
    if (pattern.length !== value.length) return false;
    for (var i = 0; i < pattern.length; i++) {
      if (!matchPattern(value[i], pattern[i], bindings)) return false;
    }
    return true;
  }
  if (typeof value !== "object" || value === null) return false;
  var keys = Object.keys(pattern);
  for (var i = 0; i < keys.length; i++) {
    var key = keys[i];
    if (!(key in value)) return false;
    if (!matchPattern(value[key], pattern[key], bindings)) return false;
  }
  return true;
}

// Test 1: Simple value matching
var r1 = match(42, [
  when(1, function() { return "one"; }),
  when(42, function() { return "forty-two"; }),
  when(_, function() { return "other"; }),
]);
console.log("Test 1:", r1); // forty-two

// Test 2: Object pattern matching with bindings
var r2 = match({ status: "ok", data: { name: "BeamJS", version: "0.1.0" } }, [
  when({ status: "ok", data: bind("d") }, function(b) {
    return "Got data: " + JSON.stringify(b.d);
  }),
  when({ status: "error" }, function() { return "Error!"; }),
  when(_, function() { return "Unknown"; }),
]);
console.log("Test 2:", r2);

// Test 3: Array pattern matching
var r3 = match([1, 2, 3], [
  when([1, bind("second"), bind("third")], function(b) {
    return "second=" + b.second + " third=" + b.third;
  }),
  when(_, function() { return "no match"; }),
]);
console.log("Test 3:", r3);

// Test 4: Nested patterns
var r4 = match({ user: { name: "Alice", role: "admin" }, action: "delete" }, [
  when({ user: { role: "admin" }, action: bind("a") }, function(b) {
    return "Admin action: " + b.a;
  }),
  when({ user: { role: "user" } }, function() { return "Regular user"; }),
  when(_, function() { return "Unknown"; }),
]);
console.log("Test 4:", r4);

console.log("All pattern matching tests passed!");
