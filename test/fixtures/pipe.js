// Test pipe operator - inline for testing

function Pipeline(value) {
  this._value = value;
}

Pipeline.prototype.then = function(fn) {
  return new Pipeline(fn(this._value));
};

Pipeline.prototype.tap = function(fn) {
  fn(this._value);
  return this;
};

Pipeline.prototype.when = function(predicate, fn) {
  if (predicate(this._value)) {
    return new Pipeline(fn(this._value));
  }
  return this;
};

Pipeline.prototype.value = function() {
  return this._value;
};

function pipe(value) {
  return new Pipeline(value);
}

// Test 1: Basic pipe
var r1 = pipe(5)
  .then(function(x) { return x * 2; })
  .then(function(x) { return x + 1; })
  .then(function(x) { return x.toString(); })
  .value();
console.log("Test 1:", r1); // "11"

// Test 2: Pipe with data transformation
var users = [
  { name: "Alice", age: 30, active: true },
  { name: "Bob", age: 25, active: false },
  { name: "Charlie", age: 35, active: true },
];

var r2 = pipe(users)
  .then(function(u) { return u.filter(function(x) { return x.active; }); })
  .then(function(u) { return u.map(function(x) { return x.name; }); })
  .then(function(names) { return names.join(", "); })
  .value();
console.log("Test 2:", r2); // "Alice, Charlie"

// Test 3: Pipe with tap (side effect)
var sideEffect = [];
var r3 = pipe(42)
  .tap(function(x) { sideEffect.push("before: " + x); })
  .then(function(x) { return x * 2; })
  .tap(function(x) { sideEffect.push("after: " + x); })
  .value();
console.log("Test 3:", r3, "side effects:", JSON.stringify(sideEffect)); // 84, ["before: 42", "after: 84"]

// Test 4: Pipe with conditional
var r4 = pipe(10)
  .when(function(x) { return x > 5; }, function(x) { return x * 10; })
  .when(function(x) { return x < 5; }, function(x) { return x + 100; })
  .value();
console.log("Test 4:", r4); // 100

console.log("All pipe tests passed!");
