console.log("Hello from BeamJS!");
console.log("1 + 2 =", 1 + 2);

var arr = [1, 2, 3, 4, 5];
var doubled = arr.map(function(x) { return x * 2; });
console.log("Doubled:", JSON.stringify(doubled));

var obj = { name: "BeamJS", version: "0.1.0", runtime: "BEAM + QuickJS" };
console.log("Runtime:", JSON.stringify(obj));
