# React Core & Modern Architecture: Fiber, Hooks & State

Target Role: Full-Stack / Backend & AI Engineer with 3 YoE React/Next.js background  
Cross-References: [15-nextjs-and-react-native.md](./15-nextjs-and-react-native.md) | [05-fastapi-advanced.md](../02-fastapi-backend/05-fastapi-advanced.md)

---

## 1. The Virtual DOM & React Fiber Reconciler

Interviewers love asking how React renders under the hood. Most junior developers say "Virtual DOM compares two trees and updates the real DOM." A senior engineer explains the **Fiber Reconciler**.

```
                React 16+ Fiber Reconciliation Pipeline
               
  Render Phase (Asynchronous / Interruptible)      Commit Phase (Synchronous)
┌──────────────────────────────────────────────┐   ┌────────────────────────┐
│ 1. Trigger: State/Prop change                │   │ 4. DOM Mutation        │
│ 2. Fiber Tree: Linked list of units of work  │──►│    Applies diffs to    │
│ 3. Cooperative Scheduling (React scheduler) │    real browser DOM     │
│    Can PAUSE, ABORT, or REUSE work based on  │   │ 5. Runs useLayoutEffect│
│    priority (User input > Animation > Data)  │   │ 6. Runs useEffect      │
└──────────────────────────────────────────────┘   └────────────────────────┘
```

### Why Fiber Replaced the Legacy Stack Reconciler
- **Stack Reconciler (React < 16)**: Recursively processed the virtual DOM tree synchronously. If an update took 100ms, the main browser thread was completely blocked, causing dropped animation frames and unresponsive clicks.
- **Fiber Reconciler (React 16+)**: Breaks rendering into incremental units of work called **Fibers** (linked-list nodes with `child`, `sibling`, and `return` pointers). React can pause work on low-priority renders (e.g. background data fetch) to immediately handle high-priority user events (e.g. text input keystrokes or clicks).

### 🧠 Junior vs. Senior Answer: "What is the Virtual DOM?"
- **Junior Answer**: "The Virtual DOM is an in-memory copy of the real DOM. When state changes, React compares the new Virtual DOM with the old one, finds the diffs, and updates only the changed parts."
- **Senior Answer**: "The Virtual DOM is a lightweight JavaScript object representation of the UI tree. In modern React, this is managed by the **Fiber engine**, which implements a two-phase reconciliation architecture: an **asynchronous, interruptible Render Phase** where React calculates work across a singly-linked list of Fiber nodes, and a **synchronous, atomic Commit Phase** that flushes DOM mutations and invokes lifecycle effects. This allows React to prioritize urgent user interactions over background re-renders without locking the browser's main thread."

---

## 2. React Hooks Under the Hood: The Array/Linked-List Mental Model

Why can Hooks **never be called inside loops, conditions, or nested functions**?  
Because React does not store hook state by name; it stores hooks in a **strictly ordered linked list** on the current Fiber node (`fiber.memoizedState`).

```
 Current Component Fiber Node:
 memoizedState ──► [Hook 1: useState] ──► [Hook 2: useEffect] ──► [Hook 3: useMemo] ──► null
```
If a conditional statement causes Hook 2 to be skipped on a re-render, Hook 3's pointer misaligns with Hook 2's previous state, causing catastrophic state corruption!

### Deep Dive: Core Hooks & Gotchas

#### 1. `useState` & Batching (React 18 Automatic Batching)
In React 18, all state updates—whether inside event handlers, `setTimeout`, `fetch` callbacks, or native event listeners—are **automatically batched** into a single re-render.

```tsx
function Counter() {
  const [count, setCount] = useState(0);

  const handleClick = () => {
    // Both updates batched into 1 render; updater function receives latest state
    setCount(prev => prev + 1);
    setCount(prev => prev + 1);
    // count is STILL 0 here because state updates are asynchronous!
  };
  return <button onClick={handleClick}>{count}</button>;
}
```

#### 2. `useEffect` vs. `useLayoutEffect`
- **`useEffect`**: Runs after commit; often after paint, but interaction-related effects may run before paint. Long effect work can still block the main thread. (Use for data fetching, event subscriptions, logging).
- **`useLayoutEffect`**: Runs **synchronously after DOM mutation but before the browser paints**. (Use only for measuring DOM layout like scroll positions or element dimensions to prevent visual flickers).

#### 3. `useCallback` vs. `useMemo`
- `useMemo(() => computeExpensive(a), [a])`: Caches the **result** of a computation.
- `useCallback(fn, deps)`: Syntactic sugar for `useMemo(() => fn, deps)`. Caches the **function reference** to prevent unnecessary re-renders of memoized child components (`React.memo`).

```tsx
// Anti-pattern: Over-optimizing trivial operations
// BAD: Overhead of creating array and dependency check exceeds a simple sum!
const total = useMemo(() => a + b, [a, b]); 

// GOOD: Caching callback passed to a heavy memoized list component
const handleSelectDocument = useCallback((docId: string) => {
  setSelectedDoc(docId);
}, []); // Stable reference across re-renders
```

#### 4. `useRef`
Maintains a mutable object (`{ current: initialValue }`) that **persists across renders without triggering a re-render** when mutated. Essential for direct DOM access, timer IDs, and tracking previous state values.

---

## 3. Custom Hooks: Production-Ready Patterns

A custom hook is a function whose name starts with `use` and that can call other hooks to encapsulate reusable stateful logic.

### Production Example: `useRAGStream` (SSE Streaming Hook)
For connecting React frontends to FastAPI RAG endpoints:

```tsx
import { useState, useCallback, useRef } from "react";

interface UseRAGStreamOptions {
  apiEndpoint: string;
  onToken?: (token: string) => void;
  onError?: (err: Error) => void;
}

export function useRAGStream({ apiEndpoint, onToken, onError }: UseRAGStreamOptions) {
  const [streamingText, setStreamingText] = useState<string>("");
  const [isStreaming, setIsStreaming] = useState<boolean>(false);
  const abortControllerRef = useRef<AbortController | null>(null);

  const startStream = useCallback(async (prompt: string) => {
    setIsStreaming(true);
    setStreamingText("");

    // Abort any ongoing stream
    if (abortControllerRef.current) {
      abortControllerRef.current.abort();
    }
    abortControllerRef.current = new AbortController();

    try {
      const response = await fetch(`${apiEndpoint}?prompt=${encodeURIComponent(prompt)}`, {
        signal: abortControllerRef.current.signal,
        headers: { Accept: "text/event-stream" },
      });

      if (!response.ok || !response.body) {
        throw new Error(`Stream request failed with status: ${response.status}`);
      }

      const reader = response.body.getReader();
      const decoder = new TextDecoder("utf-8");
      let accumulated = "";

      while (true) {
        const { value, done } = await reader.read();
        if (done) break;

        const rawChunk = decoder.decode(value, { stream: true });
        const lines = rawChunk.split("\n\n");

        for (const line of lines) {
          if (line.startsWith("data: ")) {
            const dataStr = line.replace("data: ", "").trim();
            if (dataStr === "[DONE]") break;

            try {
              const parsed = JSON.parse(dataStr);
              accumulated += parsed.text;
              setStreamingText(accumulated);
              onToken?.(parsed.text);
            } catch {
              // Plain text stream fallback
              accumulated += dataStr;
              setStreamingText(accumulated);
            }
          }
        }
      }
    } catch (err: any) {
      if (err.name !== "AbortError") {
        onError?.(err);
      }
    } finally {
      setIsStreaming(false);
      abortControllerRef.current = null;
    }
  }, [apiEndpoint, onToken, onError]);

  const stopStream = useCallback(() => {
    abortControllerRef.current?.abort();
    setIsStreaming(false);
  }, []);

  return { streamingText, isStreaming, startStream, stopStream };
}
```

---

## 4. State Management: Context API vs. Zustand vs. Redux Toolkit

| Feature | Context API | Zustand | Redux Toolkit (RTK) |
|---|---|---|---|
| **Bundle Size** | 0 KB (Built-in) | ~1.1 KB (Minimalist) | ~11 KB |
| **Boilerplate** | Medium (Provider, Context, Hook) | Near Zero (Plain JS store) | Moderate (Slices, Reducers, Store) |
| **Re-render Optimization**| Poor (All consumers re-render unless split) | **Built-in granular selectors** | Built-in granular selectors |
| **Async Middleware** | Manual (`useEffect` / custom) | Native async functions | Redux Thunk / RTK Query |
| **Best Used For** | Theme, Auth user, static configs | Application UI state, RAG drawer state | Huge enterprise teams, strict audit logs |

### Senior Pattern: Why Zustand is Preferred in Modern Stacks
```tsx
import { create } from "zustand";

interface ChatState {
  activeSessionId: string | null;
  messages: Array<{ role: string; content: string }>;
  setActiveSession: (id: string) => void;
  addMessage: (msg: { role: string; content: string }) => void;
}

export const useChatStore = create<ChatState>((set) => ({
  activeSessionId: null,
  messages: [],
  setActiveSession: (id) => set({ activeSessionId: id }),
  addMessage: (msg) => set((state) => ({ messages: [...state.messages, msg] })),
}));

// Component only re-renders when activeSessionId changes, ignoring messages updates!
function ChatHeader() {
  const activeSessionId = useChatStore((state) => state.activeSessionId);
  return <h2>Session: {activeSessionId}</h2>;
}
```

---

## 5. React 18 Concurrent Features: `useTransition` & `Suspense`

Concurrent React enables user interfaces to stay responsive even during expensive UI updates by rendering in the background without blocking the main thread.

### Non-Urgent UI Updates with `useTransition`
```tsx
import { useState, useTransition } from "react";

function DocumentFilterList({ documents }: { documents: string[] }) {
  const [searchTerm, setSearchTerm] = useState("");
  const [filteredDocs, setFilteredDocs] = useState(documents);
  const [isPending, startTransition] = useTransition();

  const handleSearchChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    // 1. URGENT: Update input box immediately so typing never lags
    const query = e.target.value;
    setSearchTerm(query);

    // 2. NON-URGENT: Mark heavy filtering calculation as transition
    startTransition(() => {
      const results = documents.filter((d) => d.toLowerCase().includes(query.toLowerCase()));
      setFilteredDocs(results);
    });
  };

  return (
    <div>
      <input value={searchTerm} onChange={handleSearchChange} placeholder="Search 10,000 docs..." />
      {isPending && <span>Filtering results...</span>}
      <List items={filteredDocs} />
    </div>
  );
}
```

---

## 6. Gotchas & Follow-Up Questions Interviewers Ask

1. **"Why does my `useEffect` run twice in development?"**
   - React 18's **`StrictMode`** mounts, unmounts, and re-mounts components in development to detect missing cleanup logic in effects (e.g. unclosed WebSockets, un-cancelled subscriptions). It runs once in production.
2. **"Can `useMemo` guarantee that a value will never be recomputed?"**
   - No! React treats `useMemo` as a performance hint, not a semantic guarantee. In low-memory conditions, React may "forget" memoized values and recalculate on the next render.
3. **"What is the difference between controlled and uncontrolled inputs?"**
   - A **controlled input** has its value driven by React state (`value={val} onChange={...}`). An **uncontrolled input** stores its state directly in the DOM and is accessed via a `ref` (`ref={inputRef}`).

---

## 7. High-Probability Interview Questions & Model Answers

### Q1: What causes unnecessary re-renders in React and how do you profile them?
**Answer:**
A component re-renders when:
1. Its local state changes (`useState`, `useReducer`).
2. Its parent component re-renders.
3. A Context value it subscribes to updates.
To profile, use the **React DevTools Profiler** to inspect render durations and check the "Why did this render?" flamegraph. Common fixes: wrap children in `React.memo` with stable props, pass callbacks stabilized with `useCallback`, use granular selectors (e.g., in Zustand), and push state down to leaf nodes.

### Q2: What is an Error Boundary, and can it catch async errors?
**Answer:**
An Error Boundary is a class component implementing `static getDerivedStateFromError()` and/or `componentDidCatch()` to catch JavaScript errors anywhere in its child component tree, log them, and render a fallback UI.  
*Gotcha:* Error Boundaries **cannot** catch errors inside asynchronous callbacks (e.g. `setTimeout`, `async/await` in `useEffect`, or event handlers). Those must be handled using `try...catch` blocks or passed to state to trigger a render-time error.

### Q3: How does React's Reconciliation Key algorithm work on lists?
**Answer:**
When comparing children in lists, React uses the `key` attribute to match elements between renders.  
- Using **array index as key** is an antipattern when items can be inserted, deleted, or re-ordered: React assumes the item at index 0 is the same element, causing UI glitches with form inputs or component state.
- Always use a unique, stable business identifier (e.g., `doc.id` or `uuid`) so React correctly re-orders DOM elements instead of destroying and re-creating them.
