# Interview Questions Bank: JavaScript Core, React Foundations & Dual-Language Event Loop

> **Target Audience:** FAANG / Tier-1 MNC Staff & Senior Full-Stack Engineers  
> **Evaluation Bar:** V8 Memory Allocations, React Immutability Mechanics, Microtask Draining, Python AsyncIO vs JS Event Loop, DOM Event Delegation vs React SyntheticEvents  
> **Cross-References:** [30-javascript-core-and-event-loop-deep-dive.md](../06-frontend-react/30-javascript-core-and-event-loop-deep-dive.md) | [03-python-async.md](../01-python-core/03-python-async.md) | [14-react-core-architecture.md](../06-frontend-react/14-react-core-architecture.md)

---

### Q1: Explain how the JavaScript Event Loop coordinates Microtasks, Macrotasks, and Browser UI Renders. What happens if microtasks keep enqueuing?
#### Junior Answer:
"JavaScript runs synchronous code first, then runs promises, and then runs setTimeout."
#### Senior In-Depth Answer:
"The JavaScript execution model is governed by a strict prioritization algorithm:
1. **Call Stack Execution**: Synchronous frames execute until the call stack is completely empty.
2. **Microtask Queue Draining (High Priority)**: The engine processes the microtask queue (containing `Promise.then/catch/finally`, `queueMicrotask`, `process.nextTick`). Crucially, the engine **drains the microtask queue to completion**. If a microtask enqueues another microtask, the engine continues processing microtasks in a loop.
3. **Render Pipeline (Browser)**: If 16.6ms have elapsed (60Hz refresh rate), the browser executes `requestAnimationFrame` callbacks, recalculates styles, computes layout, and paints pixels.
4. **Macrotask Execution**: The engine picks **exactly ONE macrotask** from the Task Queue (`setTimeout`, `setInterval`, network I/O callback), executes it on the call stack, and immediately returns to Step 2 to drain any new microtasks created.  
*Starvation Risk:* If a microtask recursively spawns another microtask (`function loop() { Promise.resolve().then(loop); }`), the engine will loop indefinitely, **never reaching the render step or the macrotask queue**, completely freezing the browser tab UI."

---

### Q2: Compare and contrast how Python's `asyncio` Event Loop works compared to Node.js's `libuv` Event Loop.
#### Junior Answer:
"Both use async/await and non-blocking I/O to handle thousands of requests."
#### Senior In-Depth Answer:
"While both achieve non-blocking concurrency over a single thread using OS multiplexing primitives (`epoll` on Linux), their runtime engines differ fundamentally:
1. **Invocation Mechanics**:
   - **JavaScript**: Calling `async function getData()` immediately begins execution synchronously until the first `await`. Promises are **eagerly evaluated**.
   - **Python**: Calling `async def get_data()` does not execute any code. It returns a **cold, suspended coroutine generator object**. Execution only begins when explicitly awaited or scheduled via `asyncio.create_task()`.
2. **Queue Architecture**:
   - **JavaScript**: Features a strict two-tier priority hierarchy (Microtasks starve Macrotasks).
   - **Python**: Uses a flat FIFO deque (`_ready`) for immediate tasks and a binary min-heap (`_scheduled`) for timed callbacks (`loop.call_later`). Python does not have an equivalent microtask starvation concept.
3. **Pluggable Event Loops**:
   - Node.js binds to a fixed, non-replaceable C library (`libuv`).
   - Python supports **pluggable event loop implementations**. In production, FastAPI and high-scale services swap Python's default loop with **`uvloop`** (a drop-in replacement written in Cython on top of libuv), increasing throughput by **$2\text{--}4\times$**."

---

### Q3: Why does mutating React state directly (e.g. `state.items.push(item)`) cause components not to re-render, and why is `Object.is` fundamental to this behavior?
#### Junior Answer:
"Because React requires you to use the setter function so it knows the state changed."
#### Senior In-Depth Answer:
"React's Fiber reconciler uses `Object.is(prevState, nextState)` to determine whether a component's state has mutated.
When an object or array is mutated directly (e.g. `state.items.push(newItem)`):
1. The memory address of `state.items` on the V8 heap remains identical.
2. Even if you invoke `setItems(state.items)`, React compares the new argument with the previous state using `Object.is`.
3. Because both reference the identical heap address, `Object.is(prevState, nextState)` evaluates to `true`.
4. React concludes that no state transition occurred and **bails out of the reconciliation cycle**, skipping the render phase entirely.  
To trigger a render, state updates must be **immutable** (`setItems(prev => [...prev, newItem])`), which allocates a new array reference on the heap, ensuring `Object.is` returns `false`."

---

### Q4: Why does using the array index as a `key` prop in React lists cause subtle bugs when items are reordered or filtered?
#### Junior Answer:
"Index as a key causes performance issues and React gives a console warning."
#### Senior In-Depth Answer:
"React's reconciliation algorithm uses the `key` prop to identify which items in a collection have changed, been added, or been removed.  
When using array indices (`key={index}`):
1. **Reordering / Deletion Anomaly**: If the first item in a 3-item list is deleted, the item originally at index 1 now becomes index 0, and index 2 becomes index 1.
2. **Fiber Node Reuse**: React compares the new virtual DOM against the old Fiber tree. It sees that a node with `key=0` still exists. It assumes the identity of the element is unchanged and reuses the existing DOM node and internal component state.
3. **Corrupted Uncontrolled State**: Any state managed inside the child component—such as uncontrolled `<input />` text, `<input type="checkbox" />` checked states, or CSS animation timers—will remain attached to the wrong data row.
*Senior Fix:* Always use persistent, globally unique entity identifiers (`item.id`, database UUIDs) as keys."

---

### Q5: Write a production-grade Debounce function from scratch in vanilla JavaScript. How do you implement cleanup in React hooks (`useEffect`)?
#### Junior Answer:
"Debounce sets a `setTimeout` and clears it if called again."
#### Senior In-Depth Answer:
"Here is a memory-safe, cancelable debounce implementation:
```javascript
function debounce(fn, delay) {
  let timerId = null;

  function debounced(...args) {
    if (timerId) clearTimeout(timerId);
    timerId = setTimeout(() => {
      fn.apply(this, args);
      timerId = null;
    }, delay);
  }

  debounced.cancel = () => {
    if (timerId) {
      clearTimeout(timerId);
      timerId = null;
    }
  };

  return debounced;
}
```
**React Hook Lifecycle Integration**:
In React, if a debounced handler fires after a component has unmounted, it causes memory leaks and console warnings. You must clean it up:
```tsx
const debouncedSearch = useMemo(
  () => debounce((query: string) => fetchResults(query), 300),
  []
);

useEffect(() => {
  return () => debouncedSearch.cancel(); // Cleanup on unmount
}, [debouncedSearch]);
```"

---

### Q6: How does `AbortController` prevent race conditions in React `useEffect` data fetching?
#### Junior Answer:
"It cancels the fetch request if a new request comes in."
#### Senior In-Depth Answer:
"When a user rapidly changes search filters or switches tabs, multiple asynchronous network requests are dispatched concurrently. Due to variable network latency, Request 1 (older query) may resolve *after* Request 2 (latest query). Without cancellation, Request 1's callback overwrites the UI with stale data.
```tsx
useEffect(() => {
  const controller = new AbortController();

  async function loadData() {
    try {
      const res = await fetch(`/api/search?q=${query}`, {
        signal: controller.signal,
      });
      const data = await res.json();
      setResults(data);
    } catch (err: any) {
      if (err.name !== "AbortError") {
        setError(err); // Ignore intentional abort cancellations
      }
    }
  }

  loadData();
  return () => controller.abort(); // Cancels previous in-flight fetch immediately
}, [query]);
```
When `query` updates or the component unmounts, the cleanup function invokes `controller.abort()`, which immediately terminates the underlying TCP/HTTP stream at the browser network layer, guaranteeing that stale responses never touch component state."

---

### Q7: What is the difference between `Promise.all()` and `Promise.allSettled()`, and when would you choose each?
#### Junior Answer:
"`Promise.all` fails if one fails, while `Promise.allSettled` waits for all of them."
#### Senior In-Depth Answer:
- **`Promise.all(iterable)`**:
  - **Behavior**: Fail-fast. If any promise in the array rejects, the returned promise immediately rejects with that error, discarding the results of the other promises.
  - **Use Case**: Atomic dependent operations (e.g. creating an order, charging the credit card, and generating an invoice where all three must succeed together).
- **`Promise.allSettled(iterable)`**:
  - **Behavior**: Never short-circuits. It awaits all promises regardless of success or failure, returning an array of descriptors: `{ status: 'fulfilled', value }` or `{ status: 'rejected', reason }`.
  - **Use Case**: Independent widget dashboards (e.g. fetching Analytics, Notifications, and Profile widgets in parallel, where a failure in Notifications should not break Analytics or Profile)."

---

### Q8: How did React's SyntheticEvent system change between React 16 and React 17+, and why is this critical for micro-frontends?
#### Junior Answer:
"React 17 changed where event listeners are attached."
#### Senior In-Depth Answer:
- **React 16 Architecture**: React attached all event listeners at the `document` level. When an event occurred in the DOM, it bubbled all the way to `document`, where React's event dispatcher mapped it to the appropriate SyntheticEvent handler.
  - *The Problem:* If a non-React library or embedded legacy script called `e.stopPropagation()`, the event never reached `document`, preventing React listeners from firing. Furthermore, embedding two different React versions on one page caused nested events to break.
- **React 17+ Architecture**: React attaches event listeners to the **root DOM container (`rootNode`, e.g. `<div id="root">`)** instead of `document`.
  - *Production Impact:* Multiple independent React micro-frontends (even running disparate React versions) can now safely nest within each other without event interference.
  - In addition, React 17 eliminated SyntheticEvent object pooling (`e.persist()` is no longer needed)."

---

### Q9: What is the difference between `WeakMap` and `Map`, and how does `WeakMap` prevent memory leaks in enterprise applications?
#### Junior Answer:
"`WeakMap` can only have objects as keys, and you can't loop over it."
#### Senior In-Depth Answer:
"A standard `Map` holds **strong references** to its keys. As long as the `Map` instance remains reachable in memory, every object used as a key in that map cannot be collected by V8's garbage collector, even if all other references to that key are deleted.  
A **`WeakMap` holds weak references to its keys**:
- If an object key has no other strong references outside the `WeakMap`, V8's Mark-and-Sweep garbage collector **automatically reclaims the object and evicts the corresponding key-value pair from the WeakMap**.
- This is critical in frameworks like React and Angular for attaching private metadata, DOM listeners, or caches to DOM nodes. When the DOM element is unmounted and deleted, all associated metadata in the `WeakMap` is garbage collected automatically, eliminating memory leaks."
