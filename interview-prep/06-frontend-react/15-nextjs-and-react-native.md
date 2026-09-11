# Next.js & React Native: Full-Stack Rendering & Mobile Architecture

Target Role: Full-Stack / Backend & AI Engineer with 3 YoE React/Next.js/React Native background  
Cross-References: [14-react-core-architecture.md](./14-react-core-architecture.md) | [11-system-design-basics.md](../04-system-design-dsa/11-system-design-basics.md)

---

## 1. Next.js App Router & React Server Components (RSC)

The Next.js **App Router** (introduced in Next.js 13/14+) fundamentally shifted React from a client-only library to a unified server-client component architecture.

```
                   Server Components vs. Client Components
                   
 Server Component (Default in App Router)        Client Component ('use client')
┌────────────────────────────────────────┐     ┌────────────────────────────────┐
│ • Executes strictly on Node/Edge server│     │ • Pre-rendered on server,      │
│ • Direct access to DB / secrets / FS   │     │   then hydrated in browser     │
│ • ZERO JavaScript sent to client bundle│──►  │ • Has access to browser APIs   │
│ • Cannot use hooks (useState, useEffect│     │ • Can use hooks & click handlers│
└────────────────────────────────────────┘     └────────────────────────────────┘
```

### Rendering Strategies Cheat Sheet
| Strategy | When Rendered? | How it Works | Best Used For |
|---|---|---|---|
| **SSR** (Server-Side Rendering) | At request time | HTML generated on each incoming HTTP request | Dynamic dashboards, user-specific data |
| **SSG** (Static Site Generation) | At build time (`npm run build`) | HTML generated once; served from global CDN | Marketing pages, public blogs, docs |
| **ISR** (Incremental Static Regen) | Background interval | Static page regenerated on-demand after interval | Product catalogs, e-commerce listings |
| **Streaming SSR** | At request time via HTTP stream | Shell sent instantly; heavy components stream in via `<Suspense>` | RAG chat dashboards, heavy data reports |

### The Hydration Mismatch Trap
**Hydration** is the process where client-side React attaches event listeners and state to the server-rendered HTML.  
A **hydration error** happens when the HTML generated on the server does **not** match the initial render tree generated on the client.

```tsx
// BUGGY PATTERN (Causes Hydration Mismatch):
export default function Clock() {
  // Server renders UTC time or server local; client renders user local time!
  return <div>Current Time: {new Date().toLocaleTimeString()}</div>;
}

// SENIOR FIX: Delay client-only rendering until after mount
'use client';
import { useState, useEffect } from 'react';

export default function SafeClock() {
  const [mounted, setMounted] = useState(false);
  useEffect(() => setMounted(true), []);

  if (!mounted) return <div>Loading clock...</div>;
  return <div>Current Time: {new Date().toLocaleTimeString()}</div>;
}
```

---

## 2. Server Actions & Direct Backend Communication

Server Actions allow client components to invoke asynchronous server functions directly without manually declaring REST API endpoints.

```tsx
// app/actions/documentActions.ts
'use server';

import { revalidatePath } from 'next/cache';

export async function archiveDocument(docId: string) {
  // Direct server DB call or secure Python microservice request
  const res = await fetch(`http://fastapi-service:8000/api/v1/documents/${docId}/archive`, {
    method: 'POST',
    headers: { 'X-Internal-Secret': process.env.INTERNAL_SERVICE_KEY! },
  });
  
  if (!res.ok) throw new Error('Archive failed');
  revalidatePath('/dashboard/documents');
  return { success: true };
}
```

---

## 3. React Native Architecture: Legacy Bridge vs. New Architecture

Interviewers heavily test React Native architecture when assessing mid/senior mobile candidates.

```
       Legacy Architecture (The Bottleneck)
 ┌────────────┐        JSON String Serialization        ┌─────────────┐
 │ JavaScript │ ◄═════════════════════════════════════► │   Native    │
 │   Thread   │         Asynchronous Bridge             │ (iOS / Java)│
 └────────────┘                                         └─────────────┘
 
       New Architecture (Fabric + TurboModules via JSI)
 ┌────────────┐          Direct C++ In-Memory Calls      ┌─────────────┐
 │ JavaScript │ ◄─────────────────────────────────────► │   Native    │
 │ (Hermes V8)│          JSI (JavaScript Interface)     │ (iOS / Java)│
 └────────────┘                                         └─────────────┘
```

### Core Pillars of the New Architecture:
1. **JSI (JavaScript Interface)**: Replaces the asynchronous JSON bridge with direct C++ pointer bindings. JavaScript can directly invoke native C++ methods synchronously in shared memory.
2. **Fabric**: The new concurrent rendering system. Executes UI layout calculations synchronously or concurrently on the native thread, eliminating white-flash glitches during fast scrolling.
3. **TurboModules**: Lazy-loads native modules on-demand rather than initializing all native modules at app startup, drastically improving app launch time (TTR - Time to Interactive).
4. **Hermes**: Bytecode-compiled JavaScript engine optimized specifically for React Native on Android and iOS (lowers APK size and memory consumption).

---

## 4. Mobile Offline-First Architecture (Wishan App Patterns)

Building reliable mobile applications requires handling intermittent cellular network loss.

```
                  Offline-First Mobile Synchronization Flow
                  
 ┌────────────────┐
 │ User Action    │ (e.g. Submit Service Ticket)
 └───────┬────────┘
         │
         ▼
 ┌────────────────┐
 │ Local Database │ 1. Write to local SQLite / WatermelonDB immediately
 │ (WatermelonDB) │ 2. UI updates optimistically with status: 'PENDING'
 └───────┬────────┘
         │
         ▼
 ┌────────────────┐
 │ Sync Manager   │ 3. Check @react-native-community/netinfo
 └───────┬────────┘
         │
    ┌────┴──────────────────────────┐
    │ Connected?                    │ Offline?
    ▼                               ▼
 ┌──────────────────────┐   ┌───────────────────────────┐
 │ 4. Flush Queue via   │   │ Persist in Sync Queue;    │
 │    FastAPI with      │   │ Listen for NetInfo        │
 │    Idempotency-Key   │   │ 'isConnected: true' event │
 └──────────────────────┘   └───────────────────────────┘
```

### High-Performance Lists: `FlatList` vs. `FlashList`
Rendering long lists (e.g., 5,000 document records or chat items) will crash a mobile app if memory is unmanaged.
- **`FlatList` (Default)**: Unmounts offscreen items, but creates new native view components as the user scrolls, causing blank white frames on rapid scrolls.
- **`FlashList` (Shopify)**: Recycles existing native view instances (`View Recycling`), achieving **5–10x higher FPS** and zero blank scroll areas.

```tsx
import { FlashList } from "@shopify/flashlist";

export function FastDocumentList({ documents }: { documents: DocumentItem[] }) {
  return (
    <FlashList
      data={documents}
      renderItem={({ item }) => <DocumentCard item={item} />}
      estimatedItemSize={84} // Mandatory: informs layout engine before render
      keyExtractor={(item) => item.id}
    />
  );
}
```

---

## 5. Gotchas & Follow-Up Questions Interviewers Ask

1. **"Can you import a Server Component into a Client Component?"**
   - You cannot *import* a Server Component directly inside a file with `'use client'`. However, you can pass a Server Component as a **`children` prop** to a Client Component!
2. **"Why does React Native's `Animated.timing` lag without `useNativeDriver: true`?"**
   - Without `useNativeDriver: true`, every frame of the animation calculates on the JavaScript thread and serializes across the bridge to the UI thread 60 times per second. If the JS thread is busy parsing JSON, frames drop. With `useNativeDriver: true`, the entire animation configuration is serialized *once* to the native thread, executing at 60–120 FPS uninterrupted.
3. **"What is the difference between `localStorage` and `AsyncStorage`?"**
   - `localStorage` in the browser is completely synchronous and blocks the main thread. `AsyncStorage` in React Native is **asynchronous** and non-blocking, storing data in SQLite (Android) or native serialization files (iOS).

---

## 6. High-Probability Interview Questions & Model Answers

### Q1: What is the difference between Next.js App Router and Pages Router?
**Answer:**
- **Pages Router** (`pages/`): Centered on file-based routes where each page defines its own data fetching via `getServerSideProps` or `getStaticProps`. Everything is a client component by default; layouts do not persist state across navigation without custom `_app.js` wrapping.
- **App Router** (`app/`): Built on React Server Components (RSC). Components are server-first by default; data is fetched directly using async/await inside components. Supports nested and persistent layouts, streaming with Suspense, and built-in error handling (`error.tsx`, `loading.tsx`).

### Q2: How do you optimize image rendering in Next.js?
**Answer:**
Use the `next/image` component:
1. Automatically serves modern lightweight formats (WebP / AVIF) based on browser support.
2. Implements responsive sizing using the `sizes` attribute and device pixel ratio (DPR).
3. Prevents Cumulative Layout Shift (CLS) by enforcing explicit aspect ratios or blur-up placeholders (`placeholder="blur"`).
4. Employs lazy loading by default for offscreen images.

### Q3: How does React Native achieve cross-platform styling?
**Answer:**
React Native uses **Yoga**, an open-source, cross-platform layout engine written in C++ that implements the CSS Flexbox specification. JavaScript code writes styles using standard Flexbox properties (`flexDirection`, `alignItems`, `justifyContent`), and Yoga translates these rules into native platform layout metrics (AutoLayout on iOS, ViewGroup on Android). *Key difference:* The default `flexDirection` in React Native is `column`, whereas in web CSS it is `row`.

### Q4: How do you prevent layout shifts when keyboard opens in React Native?
**Answer:**
Wrap the input forms inside a `<KeyboardAvoidingView>` component and set the `behavior` property appropriately:
- iOS: `behavior="padding"` (adjusts padding as keyboard slides up).
- Android: Handled naturally via `windowSoftInputMode="adjustResize"` in `AndroidManifest.xml`, or `behavior="height"`. For complex chat UIs, use libraries like `react-native-keyboard-controller` for frame-accurate native layout animations.

### Q5: What is the difference between Static Site Generation (SSG) and Incremental Static Regeneration (ISR)?
**Answer:**
- **SSG**: Pre-renders HTML pages at build time. If content changes in the database, the entire website must be rebuilt and redeployed.
- **ISR**: Pre-renders static pages initially, but allows individual pages to be regenerated in the background without rebuilding the entire application:
  ```tsx
  export const revalidate = 60; // Regenerate page in background if requested after 60 seconds
  ```
  Users receive the cached static page instantly, and the CDN cache updates in the background when stale.
