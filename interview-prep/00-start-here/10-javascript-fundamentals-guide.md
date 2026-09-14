# JavaScript Fundamentals Quick Guide (Start Here)

Even for a React role, interviewers test raw JavaScript. These are the questions that come up again and again. Know them cold — they're easy points.

Format: **concept → plain explanation → what you say → follow-up.**

---

## 1. `var` vs `let` vs `const`

- **`var`:** function-scoped, hoisted, can be redeclared. Avoid it.
- **`let`:** block-scoped, can be reassigned.
- **`const`:** block-scoped, can't be reassigned (but objects/arrays it points to can still be mutated).

**Interview answer:** "I use `const` by default and `let` when I need to reassign. I avoid `var` because it's function-scoped and hoisted, which causes surprises. Note `const` doesn't make objects immutable — it just stops reassigning the variable."

---

## 2. `==` vs `===`

- `==` compares with type coercion (`0 == "0"` is `true`).
- `===` compares value **and** type (`0 === "0"` is `false`).

**Interview answer:** "I always use `===` to avoid surprising coercion. `==` converts types before comparing, which leads to bugs like `0 == ''` being true."

---

## 3. Closures (asked constantly)

**Plain explanation:** A closure is a function that "remembers" the variables from where it was created, even after that outer function has finished. The inner function keeps access to the outer scope.

```js
function makeCounter() {
  let count = 0;              // captured by the closure
  return function () {
    count += 1;
    return count;
  };
}
const counter = makeCounter();
counter(); // 1
counter(); // 2  <- remembers count
```

**Interview answer:** "A closure is a function bundled with the variables from its surrounding scope. It keeps those variables alive after the outer function returns. It's how things like private counters, memoization, and React hooks work under the hood."

**Follow-up (the classic loop bug):**
```js
// With var, all logs print 3 (shared variable)
for (var i = 0; i < 3; i++) setTimeout(() => console.log(i), 0);
// With let, each iteration gets its own i -> logs 0,1,2
for (let i = 0; i < 3; i++) setTimeout(() => console.log(i), 0);
```
"`var` shares one variable across iterations, so the callbacks all see the final value. `let` creates a fresh binding per iteration."

---

## 4. Hoisting

**Plain explanation:** JavaScript moves declarations to the top of their scope before running. `var` and function declarations are hoisted; `let`/`const` are hoisted but not initialized (the "temporal dead zone"), so using them early throws.

**Interview answer:** "Declarations are hoisted to the top of their scope. Function declarations are fully hoisted so you can call them before they appear. `let` and `const` are hoisted but not usable until their line runs — accessing them earlier throws a ReferenceError."

---

## 5. `this` (the tricky one)

**Plain explanation:** `this` depends on **how a function is called**, not where it's defined.
- Regular function: `this` is whatever called it (or `undefined`/window if called plainly).
- Method on an object: `this` is that object.
- Arrow function: has **no own `this`** — it uses `this` from where it was defined. This is why arrow functions are handy in callbacks.

**Interview answer:** "`this` is set by the call site for regular functions. Arrow functions don't have their own `this` — they inherit it from the enclosing scope, which is why I use arrows for callbacks so `this` stays predictable."

---

## 6. Promises and `async/await`

**Plain explanation:** A Promise represents a value that will exist later — pending, then fulfilled or rejected. `async/await` is nicer syntax over promises.

```js
// Promise style
fetch("/api").then(res => res.json()).then(data => ...).catch(err => ...);

// async/await style (same thing, cleaner)
async function load() {
  try {
    const res = await fetch("/api");
    const data = await res.json();
  } catch (err) {
    // handle error
  }
}
```

**Interview answer:** "A promise is an eventual value. `async/await` lets me write asynchronous code that reads top-to-bottom, with `try/catch` for errors, instead of chaining `.then()`."

**Follow-up:** *"`Promise.all` vs `Promise.race`?"* → `Promise.all` waits for all to resolve (fails if any rejects); `Promise.race` settles with whichever finishes first. Use `Promise.all` to run independent calls in parallel.

---

## 7. The event loop (short version)

**Plain explanation:** JavaScript is single-threaded. Synchronous code runs first. Async callbacks wait in queues: **microtasks** (promises) run before **macrotasks** (setTimeout) after each chunk of sync code.

```js
console.log(1);
setTimeout(() => console.log(2), 0);   // macrotask
Promise.resolve().then(() => console.log(3)); // microtask
console.log(4);
// Order: 1, 4, 3, 2
```

**Interview answer:** "JS runs on one thread with an event loop. After the current synchronous code finishes, it drains all microtasks (promise callbacks) before the next macrotask (like a timer). That's why a resolved promise logs before a `setTimeout(…, 0)`."

---

## 8. Array methods (be fluent)

```js
arr.map(x => x * 2)          // transform -> new array
arr.filter(x => x > 2)       // keep matching -> new array
arr.reduce((a, x) => a + x, 0) // fold into one value
arr.find(x => x.id === 1)    // first match
arr.some(x => x > 2)         // any match? -> boolean
arr.every(x => x > 2)        // all match? -> boolean
arr.forEach(x => ...)        // side effects, no return
```

**Interview note:** `map`/`filter`/`reduce` return new arrays (don't mutate) — that's why they fit React's immutable state model.

---

## 9. Debounce and throttle (very common practical question)

**Plain explanation:**
- **Debounce:** wait until the user stops doing something, then run once. (Search-as-you-type: run after they stop typing.)
- **Throttle:** run at most once every N ms. (Scroll/resize handlers.)

```js
function debounce(fn, delay) {
  let timer;
  return (...args) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), delay);
  };
}
```

**Interview answer:** "Debounce delays running until activity stops — good for search input. Throttle limits how often something runs — good for scroll events. Both prevent expensive work from firing too often."

---

## 10. Shallow vs deep copy

```js
const shallow = { ...obj };            // nested objects still shared
const deep = structuredClone(obj);     // fully independent copy
```

**Interview answer:** "A spread or `Object.assign` is a shallow copy — nested objects are still shared references. For a fully independent copy I use `structuredClone`. This matters in React because I must not mutate nested state."

---

## Quick self-test
1. Explain a closure and the `var`-in-a-loop bug.
2. Why does a resolved promise log before `setTimeout(…, 0)`?
3. How does `this` differ in a regular vs arrow function?
4. `Promise.all` vs `Promise.race`?
5. Debounce vs throttle — when each?
6. Shallow vs deep copy, and why it matters in React?
