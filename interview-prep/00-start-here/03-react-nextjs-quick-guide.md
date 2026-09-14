# React & Next.js Quick Guide (Start Here)

This is your strong area, so this guide is about **saying things clearly** in an interview, not learning from scratch. These are the answers that come up most for a 2.5 YOE frontend dev.

Format: **question → the crisp answer → likely follow-up.**

---

## 1. How does React update the UI?

**Answer:** "React keeps a virtual representation of the UI. When state changes, it builds a new tree, compares it to the old one (diffing), and updates only the DOM nodes that actually changed. This batching and minimal-update approach is why it's fast."

**Follow-up:** *"What is the key prop for?"* → It helps React match items between renders so it reuses DOM nodes instead of recreating them. Use a stable unique id, never the array index for dynamic lists.

---

## 2. `useState` vs `useEffect` vs `useMemo` vs `useCallback`

- **`useState`** — component state; changing it triggers a re-render.
- **`useEffect`** — run side effects after render (data fetch, subscriptions). Cleanup runs on unmount or before the next run.
- **`useMemo`** — cache an expensive computed value between renders.
- **`useCallback`** — cache a function so it isn't recreated every render (useful when passing callbacks to memoized children).

**Follow-up:** *"When do you actually need useMemo/useCallback?"* → Only when there's a real cost: an expensive calculation, or a dependency that must stay referentially stable. Don't wrap everything — it adds complexity for no gain.

---

## 3. The rules of hooks

**Answer:** "Only call hooks at the top level of a component or another hook, never inside conditions or loops. React tracks hooks by call order, so the order must be identical on every render."

---

## 4. Why is state immutable in React?

**Answer:** "React decides whether to re-render by comparing references. If I mutate state directly, the reference doesn't change, so React may skip the update. I always create a new object/array — e.g. `setItems([...items, newItem])`."

---

## 5. Controlled vs uncontrolled components

- **Controlled:** the input value lives in React state (`value` + `onChange`). Predictable, easy to validate.
- **Uncontrolled:** the DOM holds the value; you read it with a ref. Less code, less control.

---

## 6. Next.js: SSR vs SSG vs CSR vs RSC

**Plain explanation:**
- **CSR** — render in the browser (classic React SPA).
- **SSR** — render HTML on the server per request (fresh data, good SEO).
- **SSG** — render at build time (fastest, for content that rarely changes).
- **RSC (React Server Components)** — components that run only on the server and send rendered output to the client, shipping less JS.

**Answer:** "I pick based on data freshness and SEO. Static marketing pages → SSG. Dashboards with per-request data → SSR or client fetching. In the App Router, Server Components let me keep data-fetching and heavy logic on the server and only ship interactive bits as Client Components."

**Follow-up:** *"What causes a hydration error?"* → The server-rendered HTML doesn't match what the client renders on first pass — often from using `Date.now()`, `window`, or random values during render. Fix by keeping render deterministic or gating browser-only code to `useEffect`.

---

## 7. `use client` vs Server Components

**Answer:** "By default App Router components are Server Components (no JS shipped, can fetch data directly). I add `'use client'` only when I need state, effects, or browser APIs. Keeping the client boundary small means less JavaScript and faster loads."

---

## 8. State management: when to reach for what

- **Local state** (`useState`) — most of the time.
- **Context** — low-frequency global data (theme, current user). Not for fast-changing state (causes re-renders).
- **Zustand / Redux** — larger shared client state.
- **TanStack Query** — server state (caching, refetching, loading/error). Don't hand-roll this in `useEffect`.

**Answer:** "I separate server state from client state. Server data goes in TanStack Query so I get caching and refetching for free. Client-only UI state stays in local state or a small store like Zustand."

---

## 9. Performance basics

- Split code with dynamic imports so the initial bundle is small.
- Memoize expensive children with `React.memo` when props are stable.
- Virtualize long lists.
- Debounce expensive handlers (search-as-you-type).

---

## Quick self-test
1. Why must React state be updated immutably?
2. When do you actually need `useMemo`/`useCallback`?
3. SSG vs SSR — how do you choose?
4. What causes a hydration mismatch and how do you fix it?
5. When would you use TanStack Query over `useEffect` + `useState`?

More detail: [`../06-frontend-react/14-react-core-architecture.md`](../06-frontend-react/14-react-core-architecture.md), [`15-nextjs-and-react-native.md`](../06-frontend-react/15-nextjs-and-react-native.md), [`18-react-ecosystem-libraries.md`](../06-frontend-react/18-react-ecosystem-libraries.md).
