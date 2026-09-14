# React State Management Quick Guide (Start Here)

State management is one of the most common React interview topics. The winning move isn't memorizing one library — it's explaining **which tool for which job**. That judgment is what interviewers want to hear.

Format: **concept → plain explanation → what you say → follow-up.**

---

## 1. The mental model: not all state is the same

Split state into two kinds first — this single idea impresses interviewers:

- **Client state:** UI stuff your app owns — a modal being open, a form's current values, the selected tab, theme.
- **Server state:** data that lives in a database and you fetch — user lists, products, orders. It can be stale, needs caching, refetching, loading/error handling.

**Interview answer:** "I separate client state from server state. Server data I put in something like TanStack Query so I get caching and refetching for free. Client-only UI state stays in local state or a small store. Mixing the two is where apps get messy."

---

## 2. `useState` — the default

For most state, this is all you need. Local to one component.

```jsx
const [count, setCount] = useState(0);
```

**Rule:** start here. Only reach for something bigger when you actually feel the pain (prop drilling, shared state across many components).

---

## 3. `useReducer` — when state logic gets complex

**Plain explanation:** Like `useState`, but for state with multiple sub-values and complex transitions. You describe changes as "actions" and a reducer function decides the next state. It's Redux's pattern, built into React.

```jsx
function reducer(state, action) {
  switch (action.type) {
    case "increment": return { count: state.count + 1 };
    case "reset":     return { count: 0 };
    default:          return state;
  }
}
const [state, dispatch] = useReducer(reducer, { count: 0 });
dispatch({ type: "increment" });
```

**Interview answer:** "I use `useReducer` when a component's state has several related fields or complex update rules — like a multi-step form. It keeps the update logic in one predictable place instead of scattered `setState` calls."

---

## 4. Context API — sharing without prop drilling

**Plain explanation:** Context lets you pass data down the tree without threading props through every level. Good for **low-frequency global data**: theme, current user, language.

```jsx
const ThemeContext = createContext();
// Provider high in the tree
<ThemeContext.Provider value={theme}>...</ThemeContext.Provider>
// Any child
const theme = useContext(ThemeContext);
```

**The big gotcha (interviewers love this):** every component reading a Context re-renders whenever the Context value changes. So Context is bad for fast-changing state (like text being typed) — it can cause performance problems.

**Interview answer:** "Context solves prop drilling for stable, low-frequency data like theme or the logged-in user. I avoid putting rapidly-changing state in Context because every consumer re-renders on each change — for that I'd use a dedicated store like Zustand."

---

## 5. Zustand — the lightweight store

**Plain explanation:** A tiny state-management library. You create a store, and components subscribe only to the slices they use — so they re-render only when *that* slice changes. Much less boilerplate than Redux.

```jsx
import { create } from "zustand";

const useStore = create((set) => ({
  count: 0,
  increment: () => set((s) => ({ count: s.count + 1 })),
}));

// In a component — subscribes ONLY to count
const count = useStore((state) => state.count);
const increment = useStore((state) => state.increment);
```

**Why people pick it:** minimal boilerplate, no provider wrapping needed, selective subscriptions avoid the Context re-render problem.

**Interview answer:** "Zustand is a small store where components subscribe to just the slice they need, so re-renders stay tight. I reach for it when I have shared client state across many components but Redux would be overkill."

---

## 6. Redux (Redux Toolkit) — the structured, larger-scale option

**Plain explanation:** The long-standing, opinionated state container. State lives in one central store; you change it by dispatching actions handled by reducers. Modern Redux = **Redux Toolkit (RTK)**, which cuts the old boilerplate dramatically.

```jsx
import { createSlice, configureStore } from "@reduxjs/toolkit";

const counterSlice = createSlice({
  name: "counter",
  initialState: { value: 0 },
  reducers: {
    increment: (state) => { state.value += 1; },  // RTK lets you "mutate" (Immer handles immutability)
  },
});

const store = configureStore({ reducer: { counter: counterSlice.reducer } });
```

**Key terms to know:**
- **Store:** the single source of truth.
- **Action:** a plain object describing "what happened" (`{ type: 'increment' }`).
- **Reducer:** a pure function `(state, action) => newState`.
- **Dispatch:** how you send an action.
- **Selector:** how you read a slice of state.
- **RTK Query:** Redux's built-in data-fetching/caching tool (an alternative to TanStack Query).

**Interview answer:** "Redux centralizes state in one store with a strict, predictable update flow — actions and reducers. I'd use Redux Toolkit for large apps with lots of shared, complex state and a team that benefits from that structure and great DevTools. For smaller apps it's usually overkill."

**Follow-up:** *"Why Redux Toolkit over classic Redux?"* → RTK removes the boilerplate (action types, immutable spread everywhere) with `createSlice`, uses Immer so you can write simpler update code, and includes good defaults. Classic Redux was verbose; nobody starts fresh with it now.

---

## 7. TanStack Query (React Query) — for server state

**Plain explanation:** Not a general state library — it's built specifically for **server data**. It fetches, caches, dedupes, refetches, and gives you loading/error states automatically. Stop hand-rolling `useEffect` + `useState` for API calls.

```jsx
const { data, isLoading, error } = useQuery({
  queryKey: ["users"],
  queryFn: fetchUsers,
});
```

**Two terms interviewers ask about:**
- **`staleTime`:** how long fetched data is considered fresh (no refetch).
- **`gcTime`** (garbage-collect time): how long unused cached data stays before being dropped.

**Interview answer:** "TanStack Query handles server state — caching, background refetching, dedupe, and loading/error states. It removed a whole category of bugs from manual `useEffect` fetching in my projects."

---

## 8. The decision table (memorize this)

| Situation | Use |
|---|---|
| State in one component | `useState` |
| Complex multi-field state logic | `useReducer` |
| Stable global data (theme, user) | Context |
| Shared client state, many components, low boilerplate | Zustand |
| Large app, complex shared state, team + DevTools | Redux Toolkit |
| Data from an API | TanStack Query (or RTK Query) |

**The senior one-liner:** "I don't default to a big state library. I start with local state, use Context for stable globals, put server data in TanStack Query, and only add Zustand or Redux when shared client state genuinely grows."

---

## Quick self-test
1. Difference between client state and server state, and why it matters?
2. Why is Context a poor choice for fast-changing state?
3. Zustand vs Redux — when would you pick each?
4. What does TanStack Query give you over `useEffect` + `useState`?
5. Why Redux Toolkit instead of classic Redux?
