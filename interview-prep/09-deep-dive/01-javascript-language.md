# JavaScript: let/const/var se advanced follow-ups tak

[Roadmap](../README.md) · [Quick JS guide](../00-start-here/10-javascript-fundamentals-guide.md)

## let vs const vs var — full answer

| Property | var | let | const |
|---|---|---|---|
| Scope | function, otherwise script global | lexical block | lexical block |
| Same-scope redeclaration | allowed in ordinary var cases | not allowed | not allowed |
| Reassignment | allowed | allowed | not allowed |
| Initialization before declaration executes | `undefined` | uninitialized / TDZ | uninitialized / TDZ |
| Initializer required | no | no | yes in ordinary declaration |
| Per-iteration binding in `for` | shared binding | fresh binding | fresh binding in `for...of/in` |

“Hoisting” conceptual term hai: declarations scope setup mein recognized hoti hain. `let`/`const` ko “not hoisted” bolne se TDZ shadowing explain nahi hoti. Normal `const x;` syntax error hai; `for (const x of values)` valid hai. Top-level classic browser script ka `var` global-object property bana sakta hai; ES modules ka top-level scope alag hai. [MDN declarations and TDZ](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Grammar_and_types).

```js
console.log(a); // undefined
var a = 10;

// Separate example: uncomment to see ReferenceError.
// console.log(b);
// let b = 20;

const user = { name: 'Asha' };
user.name = 'Neha'; // allowed: object changed, binding same
// user = {};      // TypeError if executed
```

**Follow-up:** `Object.freeze` shallow hai. Nested objects separately freeze na kiye toh mutate ho sakte hain. Immutable application updates aur runtime freezing different concepts hain.

## Closures: loop interview trap

```js
const shared = [];
for (var i = 0; i < 3; i++) shared.push(() => i);
console.log(shared.map(fn => fn())); // [3, 3, 3]

const separate = [];
for (let j = 0; j < 3; j++) separate.push(() => j);
console.log(separate.map(fn => fn())); // [0, 1, 2]
```

Closure value ka automatic frozen copy nahi; lexical binding access preserve karta hai. `var i` ek binding, `let j` per iteration separate. React mein each render ki lexical bindings alag hoti hain, isliye timer older render ka state read kar sakta hai.

## Types, coercion aur equality

Seven primitive categories: undefined, null, boolean, number, bigint, string, symbol. Objects/functions reference identity rakhte hain. `typeof null === 'object'` historical quirk; `Array.isArray` array check ke liye. `NaN !== NaN`; `Number.isNaN` coercion avoid karta hai. `0.1 + 0.2` binary floating-point exactly 0.3 nahi; money ke representation explicitly choose karo.

`==` abstract coercive comparison; `===` strict comparison. `Object.is` signed zero/NaN differences useful for React comparisons. `[] == false` true but `[]` truthy: conversion rules alag questions hain, contradictory nahi.

```js
console.log(0 || 10, 0 ?? 10); // 10 0
console.log('' || 'x', '' ?? 'x'); // x, empty string
console.log(null?.name); // undefined
const { x = 1 } = { x: null };
console.log(x); // null: default only for undefined
```

## this, call/apply/bind, prototypes

```js
'use strict';
function label(prefix) { return `${prefix}${this.name}`; }
const person = { name: 'Asha' };
console.log(label.call(person, 'Hi ')); // Hi Asha
console.log(label.apply(person, ['Hi '])); // Hi Asha
const bound = label.bind(person, 'Hi ');
console.log(bound()); // Hi Asha
```

Regular method ka receiver call expression decide karta hai. Arrow lexical `this` retain karta hai; `call`/`bind` uska `this` replace nahi karte. Arrow constructor nahi. `new` prototype linkage create karke constructor invoke karta hai. Class prototype methods share hote hain; instance arrow fields per instance function banati hain. Class syntax bhi prototype-based model hai; private `#fields` runtime private access semantics dete hain.

Property own object par nahi toh prototype chain lookup hoti hai. `Object.hasOwn` own property check karta hai. User input blindly object keys/prototypes mein merge karna security problem ho sakta hai; schema/allowlisted fields use karo.

## Functions, modules, collections

- Higher-order function function ko accept/return karti hai. Currying multi-argument call ko sequence of functions mein convert karta hai; partial application some arguments fix karti hai.
- Function declaration vs expression ka initialization timing different hai. Rest collects arguments; spread iterable/object contents expand karta hai, deep copy nahi.
- `map/filter/reduce` result intent se choose karo. `sort()` array mutate karta hai, default string ordering; numeric comparator `(a,b) => a-b`. Immutable option available ho toh `toSorted`, otherwise `[...arr].sort(...)`.
- Object keys strings/symbols; Map arbitrary key types. WeakMap object keys ko alive keep nahi karta; iterable/enumerable nahi.
- ES modules explicit import/export aur live bindings use karte hain. Tree-shaking bundler analysis hai, guaranteed zero unused code nahi; module side effects matter.

## Event loop: browser aur Node ko mix mat karo

Browser output drills [quick guide](../00-start-here/10-javascript-fundamentals-guide.md) mein hain. Node mein libuv poll/timers/check phases hain. Top-level `setTimeout(0)` vs `setImmediate()` ka one universal order **nahi**. CommonJS top-level `nextTick` often Promise callbacks se pehle; ES-module execution context mein ordering differ kar sakti hai. Environment specify karke predict karo. [Node event loop](https://nodejs.org/en/learn/asynchronous-work/event-loop-timers-and-nexttick).

`Promise.all` rejection sibling I/O cancel nahi karti. `Promise.race` losers bhi run karte rehte hain. `Promise.any` first fulfillment, all rejected toh AggregateError. `finally` result normally preserve karta hai, lekin throw/rejected promise result replace kar sakta hai.

## Memory aur performance follow-ups

GC reachability par depend karta hai. Removed DOM node ko global variable/listener closure retain kare toh memory survive kar sakti hai. Cleanup timers/listeners/observers, bound caches, heap snapshot compare karo. “All primitives stack, all objects heap” language guarantee nahi—engine optimize kar sakta hai.

V8 parse/bytecode/JIT optimization use kar sakta hai; exact tiers version-specific. Stable object shapes helpful ho sakti hain, lekin interview mein premature engine micro-optimization ke bajaye algorithm, render workload aur measured hot path explain karo.

**Exit drill:** declaration table reproduce, loop closure output explain, Promise failure strategy likho, sort mutation bug fix karo, detached method ka `this` explain karo.
