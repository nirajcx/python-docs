# React Ecosystem Libraries: Axios, TanStack Query, React Hook Form & Next.js Advanced

Target Role: Full-Stack / Senior Frontend / Backend Engineer (3 YoE React/Next.js background)  
Cross-References: [14-react-core-architecture.md](./14-react-core-architecture.md) | [15-nextjs-and-react-native.md](./15-nextjs-and-react-native.md) | [05-fastapi-advanced.md](../02-fastapi-backend/05-fastapi-advanced.md)

---

## 1. Axios Deep Dive: Production Interceptors, Refresh Queues & Cancellation

While native `fetch()` is built into modern browsers and Node 18+, **Axios** remains an enterprise standard due to automatic JSON serialization, request/response interceptors, request timeout defaults, and streamlined error handling.

### The Concurrent 401 Refresh Token Trap
**The Scenario:** A user's JWT access token expires. Five API calls fire concurrently from different components on page load. All five fail with `401 Unauthorized`.  
- *Junior Code:* Fires 5 separate refresh token API calls simultaneously, causing race conditions and revoking the refresh token!  
- *Senior Production Fix:* A **subscriber queue** that pauses failed requests, executes a single refresh token request, and retries all queued requests with the new token once resolved.

```typescript
import axios, { AxiosError, InternalAxiosRequestConfig } from "axios";

export const apiClient = axios.create({
  baseURL: process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000/api/v1",
  timeout: 10000,
  headers: { "Content-Type": "application/json" },
});

let isRefreshing = false;
let failedQueue: Array<{
  resolve: (token: string) => void;
  reject: (error: any) => void;
}> = [];

const processQueue = (error: any, token: string | null = null) => {
  failedQueue.forEach((prom) => {
    if (error) {
      prom.reject(error);
    } else {
      prom.resolve(token!);
    }
  });
  failedQueue = [];
};

// 1. Request Interceptor: Attach Bearer Token
apiClient.interceptors.request.use(
  (config: InternalAxiosRequestConfig) => {
    const token = typeof window !== "undefined" ? localStorage.getItem("access_token") : null;
    if (token && config.headers) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

// 2. Response Interceptor: Mutex Refresh Queue
apiClient.interceptors.response.use(
  (response) => response,
  async (error: AxiosError) => {
    const originalRequest = error.config as InternalAxiosRequestConfig & { _retry?: boolean };

    if (error.response?.status === 401 && !originalRequest._retry) {
      if (isRefreshing) {
        // Queue concurrent requests while refresh is in-flight
        return new Promise((resolve, reject) => {
          failedQueue.push({ resolve, reject });
        })
          .then((token) => {
            originalRequest.headers.Authorization = `Bearer ${token}`;
            return apiClient(originalRequest);
          })
          .catch((err) => Promise.reject(err));
      }

      originalRequest._retry = true;
      isRefreshing = true;

      try {
        const refreshToken = localStorage.getItem("refresh_token");
        const { data } = await axios.post(`${apiClient.defaults.baseURL}/auth/refresh`, {
          refresh_token: refreshToken,
        });

        const newAccessToken = data.access_token;
        localStorage.setItem("access_token", newAccessToken);

        processQueue(null, newAccessToken);
        originalRequest.headers.Authorization = `Bearer ${newAccessToken}`;
        return apiClient(originalRequest);
      } catch (refreshErr) {
        processQueue(refreshErr, null);
        localStorage.removeItem("access_token");
        localStorage.removeItem("refresh_token");
        if (typeof window !== "undefined") window.location.href = "/login";
        return Promise.reject(refreshErr);
      } finally {
        isRefreshing = false;
      }
    }

    return Promise.reject(error);
  }
);
```

### Request Cancellation with `AbortController`
Never allow search auto-completes to trigger out-of-order race conditions:
```typescript
const searchDocuments = (query: string, signal: AbortSignal) => {
  return apiClient.get(`/documents/search?q=${encodeURIComponent(query)}`, { signal });
};

// In React:
useEffect(() => {
  const controller = new AbortController();
  searchDocuments(searchTerm, controller.signal)
    .then((res) => setResults(res.data))
    .catch((err) => {
      if (!axios.isCancel(err)) console.error("Real error:", err);
    });

  return () => controller.abort(); // Cancels pending network request on unmount or keystroke!
}, [searchTerm]);
```

---

## 2. TanStack Query (React Query): Server State vs. Client State

Coming from older patterns where developers stored fetched data in Redux/Zustand:  
**Server State** (cached data from an external DB that can change without your knowledge) should **never** be mixed with **Client State** (modal open, draft form input).

```
                      TanStack Query Caching Lifecycle
                      
 Fresh                  Stale                       Garbage Collected
┌─────────────────────┐┌───────────────────────────┐┌────────────────────────┐
│ staleTime: 60s      ││ Stale (Background fetch    ││ gcTime: 5 mins         │
│ Data served from    ││ on window focus or remount)││ Data evicted from      │
│ cache instantly;    ││ Cached data served instantly││ memory if 0 components │
│ NO network request! ││ while background update runs││ are mounted            │
└─────────────────────┘└───────────────────────────┘└────────────────────────┘
```

### Production Query with Optimistic Updates & Rollback
When a user stars a document or likes a message, the UI must update in 0ms, rolling back only if the backend returns an error:

```typescript
import { useMutation, useQueryClient } from "@tanstack/react-query";

interface StarDocContext {
  previousDocs?: Array<{ id: string; is_starred: boolean }>;
}

export function useStarDocument() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async ({ docId, isStarred }: { docId: string; isStarred: boolean }) => {
      const { data } = await apiClient.patch(`/documents/${docId}`, { is_starred: isStarred });
      return data;
    },
    // 1. When mutation is fired:
    onMutate: async ({ docId, isStarred }): Promise<StarDocContext> => {
      // Cancel outgoing refetches so they don't overwrite optimistic update
      await queryClient.cancelQueries({ queryKey: ["documents"] });

      // Snapshot previous state for rollback
      const previousDocs = queryClient.getQueryData<any[]>(["documents"]);

      // Optimistically update cache immediately
      queryClient.setQueryData(["documents"], (old: any[] = []) =>
        old.map((doc) => (doc.id === docId ? { ...doc, is_starred: isStarred } : doc))
      );

      return { previousDocs };
    },
    // 2. If mutation fails: Roll back to previous snapshot!
    onError: (err, variables, context) => {
      if (context?.previousDocs) {
        queryClient.setQueryData(["documents"], context.previousDocs);
      }
    },
    // 3. Always refetch after error or success to guarantee synchronization
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ["documents"] });
    },
  });
}
```

---

## 3. High-Performance Form Handling: React Hook Form + Zod

In traditional forms (or Formik), binding `onChange` to React state causes the **entire form component and all child inputs to re-render on every single keystroke**. On a 20-field form, typing lags noticeably.

### React Hook Form (RHF) Mechanics
RHF uses **uncontrolled inputs via ref subscriptions**. It isolates re-renders to the individual input that changed, resulting in $O(1)$ re-render cost.

```tsx
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";

const ragIngestSchema = z.object({
  collectionName: z.string().min(3, "Must be at least 3 characters").max(50),
  chunkSize: z.number().int().min(128).max(2048),
  overlap: z.number().int().min(0).max(512),
  temperature: z.number().min(0).max(2),
}).refine((data) => data.overlap < data.chunkSize, {
  message: "Overlap must be smaller than chunk size",
  path: ["overlap"],
});

type RAGIngestForm = z.infer<typeof ragIngestSchema>;

export function IngestConfigForm({ onSubmit }: { onSubmit: (data: RAGIngestForm) => void }) {
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
  } = useForm<RAGIngestForm>({
    resolver: zodResolver(ragIngestSchema),
    defaultValues: { chunkSize: 512, overlap: 64, temperature: 0.7 },
  });

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
      <div>
        <label>Collection Name</label>
        <input {...register("collectionName")} className="border p-2 rounded w-full" />
        {errors.collectionName && <p className="text-red-500 text-sm">{errors.collectionName.message}</p>}
      </div>

      <div>
        <label>Chunk Size (tokens)</label>
        <input type="number" {...register("chunkSize", { valueAsNumber: true })} className="border p-2 rounded" />
        {errors.chunkSize && <p className="text-red-500 text-sm">{errors.chunkSize.message}</p>}
      </div>

      <button type="submit" disabled={isSubmitting} className="bg-blue-600 text-white px-4 py-2 rounded">
        {isSubmitting ? "Submitting..." : "Save Pipeline Config"}
      </button>
    </form>
  );
}
```

---

## 4. Advanced Next.js Architecture: Edge vs. Node Runtime, Middleware & Core Web Vitals

### Edge Runtime vs. Node.js Runtime
Next.js supports two distinct server execution environments:

| Feature | Node.js Runtime (Default) | Edge Runtime (V8 Isolates) |
|---|---|---|
| **Underlying Engine** | Full Node.js process (Linux/Docker) | Lightweight V8 WebAssembly isolates (Cloudflare Workers / Vercel Edge) |
| **Cold Start** | 200ms – 2s | **< 10ms (Near instantaneous)** |
| **Global APIs** | Full filesystem (`fs`), child processes, native C bindings | Web Standards only (`fetch`, `Request`, `Response`, `SubtleCrypto`) |
| **Database Drivers** | Standard TCP pools (`pg`, `mysql2`, `prisma`) | HTTP/WebSocket proxies (Neon, PlanetScale, Supabase HTTP) |
| **Best Used For** | Heavy backend APIs, file processing, Python interop | Authentication middleware, geo-routing, A/B redirects |

### Next.js Middleware Pattern (Edge Auth & Geo-Routing)
```typescript
// middleware.ts (runs at network edge before hitting pages or API routes)
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

export function middleware(request: NextRequest) {
  const token = request.cookies.get("session_token")?.value;
  const isAuthPage = request.nextUrl.pathname.startsWith("/login");
  const isProtectedPage = request.nextUrl.pathname.startsWith("/dashboard");

  // Redirect unauthenticated requests to login
  if (isProtectedPage && !token) {
    const loginUrl = new URL("/login", request.url);
    loginUrl.searchParams.set("from", request.nextUrl.pathname);
    return NextResponse.redirect(loginUrl);
  }

  // Redirect logged-in users away from login page
  if (isAuthPage && token) {
    return NextResponse.redirect(new URL("/dashboard", request.url));
  }

  // Attach correlation ID header to every downstream request
  const requestHeaders = new Headers(request.headers);
  requestHeaders.set("x-request-id", crypto.randomUUID());

  return NextResponse.next({
    request: { headers: requestHeaders },
  });
}

export const config = {
  matcher: ["/dashboard/:path*", "/login"],
};
```

### Core Web Vitals & Optimization
Interviewers frequently ask how to optimize user experience metrics:
1. **LCP (Largest Contentful Paint) $\le 2.5\text{s}$**: Render the main hero image or text block fast. Use `priority` on above-the-fold `next/image` components; preload critical fonts using `next/font`.
2. **INP (Interaction to Next Paint) $\le 200\text{ms}$**: (Replaced FID in 2024). Measures UI responsiveness during user clicks and typing. Avoid long-running JavaScript on the main thread; use `useTransition` and debounce heavy filter operations.
3. **CLS (Cumulative Layout Shift) $\le 0.1$**: Prevent elements jumping around as resources load. Always specify width/height on images and videos; reserve space for dynamic ads or skeleton loaders.

---

## 5. Gotchas & Follow-Up Questions Interviewers Ask

1. **"What is the difference between `staleTime` and `gcTime` (formerly `cacheTime`) in TanStack Query?"**
   - `staleTime`: How long data is considered "fresh". While fresh, TanStack Query will **never** refetch data from the network when components remount or the window refocuses.
   - `gcTime`: How long unused or inactive data remains in the in-memory cache before being garbage-collected. If 0 components are observing a query, it stays in memory for `gcTime` (default: 5 minutes).
2. **"Why can't you use `fs` or `net` inside Next.js Middleware?"**
   - Next.js Middleware runs on the **Edge Runtime** (lightweight V8 isolates), which does not have a full Node.js POSIX OS environment or TCP socket primitives. It only supports standard Web APIs (`fetch`, `crypto`, `URL`).
3. **"How do you prevent UI flickers when switching query keys in TanStack Query?"**
   - Use `placeholderData: keepPreviousData`. When page changes from page 1 to page 2, TanStack Query keeps displaying page 1 data while page 2 is fetching in the background, avoiding blank loading spinners.
