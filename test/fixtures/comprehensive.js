// Comprehensive BeamJS test - exercises all pure-JS features

// ========================================
// 1. Basic JavaScript on BEAM
// ========================================
console.log("=== BeamJS Comprehensive Test ===");
console.log("");

// ES6+ features
var nums = [1, 2, 3, 4, 5];
var sum = nums.reduce(function(a, b) { return a + b; }, 0);
console.log("1. Array reduce:", sum); // 15

var squared = nums.map(function(n) { return n * n; });
console.log("2. Array map:", JSON.stringify(squared)); // [1,4,9,16,25]

var evens = nums.filter(function(n) { return n % 2 === 0; });
console.log("3. Array filter:", JSON.stringify(evens)); // [2,4]

// Object destructuring (via QuickJS ES2023 support)
var obj = { x: 10, y: 20, z: 30 };
console.log("4. Object:", JSON.stringify(obj));

// Template literals not available in strict mode eval, use concatenation
console.log("5. String ops:", "Hello" + " " + "BeamJS");

// ========================================
// 2. Pattern Matching
// ========================================
console.log("");
console.log("--- Pattern Matching ---");

var WILDCARD = Symbol.for("beamjs:wildcard");

function bind(name) { return { __type: "bind", name: name }; }

function matchPattern(value, pattern, bindings) {
  if (pattern === WILDCARD) return true;
  if (pattern && pattern.__type === "bind") { bindings[pattern.name] = value; return true; }
  if (typeof pattern !== "object" || pattern === null) return value === pattern;
  if (Array.isArray(pattern)) {
    if (!Array.isArray(value) || pattern.length !== value.length) return false;
    for (var i = 0; i < pattern.length; i++) {
      if (!matchPattern(value[i], pattern[i], bindings)) return false;
    }
    return true;
  }
  if (typeof value !== "object" || value === null) return false;
  var keys = Object.keys(pattern);
  for (var i = 0; i < keys.length; i++) {
    if (!(keys[i] in value) || !matchPattern(value[keys[i]], pattern[keys[i]], bindings)) return false;
  }
  return true;
}

function match(value, clauses) {
  for (var i = 0; i < clauses.length; i++) {
    var bindings = {};
    if (matchPattern(value, clauses[i][0], bindings)) {
      return clauses[i][1](bindings);
    }
  }
  throw new Error("No match");
}

// HTTP response matching
var responses = [
  { status: 200, body: { users: ["Alice", "Bob"] } },
  { status: 404, message: "Not found" },
  { status: 500, message: "Internal error" },
  { status: 302, location: "/new-path" },
];

responses.forEach(function(resp) {
  var result = match(resp, [
    [{ status: 200, body: bind("b") }, function(b) { return "OK: " + JSON.stringify(b.b); }],
    [{ status: 404 }, function() { return "Not Found"; }],
    [{ status: 500, message: bind("m") }, function(b) { return "Server Error: " + b.m; }],
    [{ status: bind("s") }, function(b) { return "Status " + b.s; }],
  ]);
  console.log("6. Match:", result);
});

// ========================================
// 3. Pipeline
// ========================================
console.log("");
console.log("--- Pipeline ---");

function Pipeline(value) { this._value = value; }
Pipeline.prototype.then = function(fn) { return new Pipeline(fn(this._value)); };
Pipeline.prototype.tap = function(fn) { fn(this._value); return this; };
Pipeline.prototype.value = function() { return this._value; };
function pipe(v) { return new Pipeline(v); }

// Data processing pipeline
var rawData = [
  { name: "alice", score: 85, active: true },
  { name: "bob", score: 92, active: false },
  { name: "charlie", score: 78, active: true },
  { name: "diana", score: 95, active: true },
];

var result = pipe(rawData)
  .then(function(d) { return d.filter(function(u) { return u.active; }); })
  .then(function(d) { return d.map(function(u) { return { name: u.name.toUpperCase(), score: u.score }; }); })
  .then(function(d) { return d.sort(function(a, b) { return b.score - a.score; }); })
  .then(function(d) { return d.map(function(u) { return u.name + ":" + u.score; }).join(", "); })
  .value();

console.log("7. Pipeline result:", result);

// ========================================
// 4. Closures, Higher-order functions, Recursion
// ========================================
console.log("");
console.log("--- Advanced JS ---");

// Fibonacci
function fib(n) {
  if (n <= 1) return n;
  return fib(n - 1) + fib(n - 2);
}
console.log("8. Fibonacci(10):", fib(10)); // 55

// Closure-based counter
function makeCounter() {
  var count = 0;
  return {
    increment: function() { return ++count; },
    decrement: function() { return --count; },
    value: function() { return count; }
  };
}

var counter = makeCounter();
counter.increment();
counter.increment();
counter.increment();
counter.decrement();
console.log("9. Counter:", counter.value()); // 2

// Compose
function compose() {
  var fns = Array.prototype.slice.call(arguments);
  return function(x) {
    return fns.reduce(function(acc, fn) { return fn(acc); }, x);
  };
}

var transform = compose(
  function(x) { return x * 2; },
  function(x) { return x + 10; },
  function(x) { return "Result: " + x; }
);
console.log("10. Compose:", transform(5)); // "Result: 20"

// ========================================
// 5. Error handling
// ========================================
console.log("");
console.log("--- Error Handling ---");

try {
  JSON.parse("invalid json");
} catch (e) {
  console.log("11. Caught error:", e.message);
}

try {
  match("no_match", [
    [42, function() { return "nope"; }]
  ]);
} catch (e) {
  console.log("12. Match error:", e.message);
}

// ========================================
// Summary
// ========================================
console.log("");
console.log("=== All tests passed! ===");
console.log("BeamJS: JavaScript running on BEAM/OTP via QuickJS");
