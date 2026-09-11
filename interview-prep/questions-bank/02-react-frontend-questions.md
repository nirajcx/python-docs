# Interview Questions Bank: React, Next.js & React Native

Target Role: Full-Stack / Frontend / Backend Engineer (3 YoE React/Next.js/React Native background)  
Cross-References: [14-react-core-architecture.md](../06-frontend-react/14-react-core-architecture.md) | [15-nextjs-and-react-native.md](../06-frontend-react/15-nextjs-and-react-native.md)

---

### Q1: How does the React Fiber reconciler work, and why was the legacy stack reconciler replaced?
#### Junior Answer:
"React uses the Virtual DOM to compare changes and update only the parts of the real DOM that changed."
#### Senior In-Depth Answer:
"Prior to React 16, the Stack Reconciler executed tree diffing synchronously and recursively. Once an update started, it could not be paused; if an update took 100ms, the main browser thread was blocked, causing dropped animation frames and unresponsive typing.  
The **Fiber Reconciler** rewrote this into a cooperative scheduling system:
1. It models components as a singly-linked list of **Fiber nodes** (with `child`, `sibling`, and `return` pointers).
2. Rendering is split into two phases: an **asynchronous, interruptible Render Phase** (which can pause, abort, or prioritize high-priority user keystrokes over low-priority background renders using `requestIdleCallback`) and an **atomic, synchronous Commit Phase** that flushes DOM mutations and runs lifecycle effects."

---

### Q2: Why can Hooks never be called inside `if` statements, loops, or nested functions?
#### Junior Answer:
"Because React requires hooks to always be at the top level of your component."
#### Senior In-Depth Answer:
"React does not identify hooks by a string name or hash key. Internally, each component Fiber node holds a singly-linked list of hook objects (`fiber.memoizedState`). On every render cycle, React traverses this linked list in the exact sequential order in which the hooks are called in code.  
If a hook is wrapped inside a conditional statement and skipped, the internal pointer (`workInProgressHook = currentHook.next`) shifts out of sync. Hook #3 will receive the memoized state of Hook #2, resulting in corrupted component state, mismatched types, and runtime crashes."

---

### Q3: What are React Server Components (RSC), and how do they differ from traditional Server-Side Rendering (SSR)?
#### Junior Answer:
"RSC renders React on the server like Next.js `getServerSideProps`."
#### Senior In-Depth Answer:
"- In traditional **SSR**, the server generates an initial static HTML string of the entire component tree, sends it to the browser, and the browser must download the complete JavaScript bundle for *all* those components to **hydrate** them into interactive DOM elements.  
- In **React Server Components (RSC)**, server components execute *exclusively* on the server and are serialized into a compact JSON-like stream format (the RSC payload). They **never ship any JavaScript code to the client bundle**. They can directly query databases, read backend secrets, and import heavy npm packages without increasing browser bundle size. Only Client Components marked with `'use client'` ship JavaScript for browser interactivity."

---

### Q4: What causes Hydration Mismatch errors in Next.js, and how do you resolve them cleanly?
#### Junior Answer:
"It happens when the HTML from the server is different from what the browser renders, like when using `window`."
#### Senior In-Depth Answer:
"Hydration errors occur when the initial client-rendered Virtual DOM does not match the server-generated HTML markup. Common root causes:
1. Accessing browser-only globals during render (`window`, `localStorage`, `document`).
2. Non-deterministic rendering: Using `Date.now()`, `Math.random()`, or timezone-dependent formatting (`toLocaleDateString()`).
3. Invalid HTML nesting (e.g. `<p>` tag wrapping a `<div>`, which the browser auto-corrects before React attaches).  
*Senior Fix:* Use an `isMounted` state pattern:
```tsx
const [mounted, setMounted] = useState(false);
useEffect(() => setMounted(true), []);
if (!mounted) return <SkeletonLoader />;
return <div>{window.location.hostname}</div>;
```
Or disable SSR selectively on dynamic widgets using dynamic imports: `const Widget = dynamic(() => import('./Widget'), { ssr: false })`."

---

### Q5: How does React Native's New Architecture (Fabric & TurboModules) differ from the Old Bridge?
#### Junior Answer:
"The new architecture is faster because it uses Hermes and doesn't lag on scrolling."
#### Senior In-Depth Answer:
"The **Legacy Architecture** relied on an **Asynchronous JSON Bridge**:
- Whenever JavaScript needed to update native views or call a native sensor, data had to be serialized into a JSON string, sent over an asynchronous bridge, and deserialized on the native iOS/Android thread. This serialization queue became a massive bottleneck, causing white-flash blanks during rapid list scrolling.  
The **New Architecture** eliminates the bridge via:
1. **JSI (JavaScript Interface)**: Direct C++ shared-memory bindings between the JS runtime (Hermes) and native code. JS can call native methods synchronously with zero JSON serialization.
2. **Fabric**: A concurrent UI layout manager that performs layout measurements directly on the native thread.
3. **TurboModules**: Lazy-loads native modules only when invoked, eliminating app startup overhead."

---

### Q6: What is the difference between `useCallback` and `useMemo`, and when is using them an antipattern?
#### Junior Answer:
"`useMemo` caches values and `useCallback` caches functions so components don't re-render."
#### Senior In-Depth Answer:
"`useCallback(fn, deps)` is syntactic sugar for `useMemo(() => fn, deps)`. It preserves the exact function reference across re-renders to prevent breaking shallow equality checks (`prevProps === nextProps`) in child components wrapped with `React.memo`.  
*When it is an antipattern:*
Wrapping trivial computations or inline handlers passed to standard native DOM elements (e.g. `<button onClick={useCallback(...)}>`) is wasteful. The memory overhead of allocating the dependency array, comparing array elements on each render, and maintaining closures in memory often costs *more* CPU than simply allocating a fresh inline function. Only use them when passing callbacks to heavy, memoized child component trees or as dependencies to other hooks (`useEffect`)."

---

### Q7: How do you design an offline-first data sync architecture in React Native (e.g. for the Wishan mobile app)?
#### Junior Answer:
"Save the data to AsyncStorage and send it to the server when the user gets internet back."
#### Senior In-Depth Answer:
"A production offline-first architecture requires three coordinated subsystems:
1. **Local Persistent Storage**: Use a high-performance relational database like **WatermelonDB** or **SQLite** (avoid AsyncStorage for complex queries due to single-key string serialization limits).
2. **Optimistic UI with Outbox Queue**: When a user creates or edits a record, persist the change to the local database immediately with a `sync_status = 'PENDING'` flag and update the UI optimistically. Add a sync job to a persistent outbox queue.
3. **Background Sync Worker & Network Listener**: Use `@react-native-community/netinfo` to listen for connectivity changes. When online, flush the outbox queue in FIFO order to the FastAPI backend, attaching a client-generated `Idempotency-Key` UUID to each request so retried network packets never duplicate backend transactions."
