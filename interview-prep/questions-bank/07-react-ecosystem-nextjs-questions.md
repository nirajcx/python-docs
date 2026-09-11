# Interview Questions Bank: React Ecosystem, Next.js & Modern Frontend

Target Role: Full-Stack / Senior Frontend / Backend Engineer (3 YoE React/Next.js background)  
Cross-References: [14-react-core-architecture.md](../06-frontend-react/14-react-core-architecture.md) | [15-nextjs-and-react-native.md](../06-frontend-react/15-nextjs-and-react-native.md) | [18-react-ecosystem-libraries.md](../06-frontend-react/18-react-ecosystem-libraries.md)

---

### Q1: How do you handle concurrent 401 Unauthorized errors in Axios interceptors without triggering multiple refresh token requests?
#### Junior Answer:
"In the response interceptor, catch 401, call the refresh endpoint, and retry the request."
#### Senior In-Depth Answer:
"If a page fires 5 API calls simultaneously and the access token has expired, all 5 requests fail with 401 at the same time. Naively calling the refresh endpoint in the interceptor triggers **5 parallel refresh calls**, which invalidates the refresh token on modern rotation setups.  
*Senior Solution:*
Use a **Mutex Flag and a Subscriber Queue**:
```typescript
let isRefreshing = false;
let failedQueue: Array<{ resolve: (token: string) => void; reject: (err: any) => void }> = [];

apiClient.interceptors.response.use(
  (res) => res,
  async (error) => {
    const originalRequest = error.config;
    if (error.response?.status === 401 && !originalRequest._retry) {
      if (isRefreshing) {
        // Queue subsequent failed requests while refresh is in-flight
        return new Promise((resolve, reject) => {
          failedQueue.push({ resolve, reject });
        }).then((token) => {
          originalRequest.headers.Authorization = `Bearer ${token}`;
          return apiClient(originalRequest);
        });
      }

      originalRequest._retry = true;
      isRefreshing = true;

      try {
        const { data } = await axios.post('/auth/refresh', { refresh_token: getRefreshToken() });
        const newToken = data.access_token;
        setAccessToken(newToken);
        failedQueue.forEach((p) => p.resolve(newToken));
        failedQueue = [];
        originalRequest.headers.Authorization = `Bearer ${newToken}`;
        return apiClient(originalRequest);
      } catch (err) {
        failedQueue.forEach((p) => p.reject(err));
        failedQueue = [];
        logoutUser();
        return Promise.reject(err);
      } finally {
        isRefreshing = false;
      }
    }
    return Promise.reject(error);
  }
);
```"

---

### Q2: What is the exact difference between `staleTime` and `gcTime` in TanStack Query (React Query v5)?
#### Junior Answer:
"`staleTime` is how long the data stays fresh, and `gcTime` is how long it stays in the cache."
#### Senior In-Depth Answer:
"- **`staleTime`**: The duration (in milliseconds) before cached data is marked 'stale'. While data is fresh (`staleTime > 0`), mounting a component or refocusing the browser window **will never trigger a network request**; data is served instantly from memory. When data becomes stale, TanStack Query still serves the cached data immediately to avoid loading spinners, but initiates a background refetch.  
- **`gcTime` (formerly `cacheTime`)**: The duration that *inactive* query data remains in the in-memory cache after all subscribing components have unmounted. If no components use the query for `gcTime`, it is garbage-collected. If a component mounts within `gcTime`, it sees the cached stale data instantly while the background fetch runs."

---

### Q3: Why does React Hook Form outperform Formik and traditional controlled inputs in large forms?
#### Junior Answer:
"React Hook Form uses hooks and is easier to configure with Zod."
#### Senior In-Depth Answer:
"Traditional controlled forms (and older versions of Formik) bind form values to React component state (`value={state} onChange={e => setState(e.target.value)}`). This causes the **entire form component and all its child inputs to re-render on every single keystroke**. In a 30-field form, typing suffers high latency and dropped keystrokes.  
**React Hook Form (RHF)** uses **uncontrolled inputs via native DOM refs**. RHF subscribes to DOM inputs directly without triggering React re-renders on keystrokes. Re-renders only occur when validation errors change or when fields explicitly subscribed to via `watch()` update, yielding $O(1)$ render performance."

---

### Q4: When should you choose Next.js Edge Runtime over the Node.js Runtime?
#### Junior Answer:
"Edge is always faster because it runs closer to the user."
#### Senior In-Depth Answer:
"- **Edge Runtime (V8 Isolates)**:
  - *Pros:* Near-zero cold starts (< 10ms); distributed globally across 300+ CDN edge locations.
  - *Cons:* No full Node.js API support (no native `fs`, `child_process`, or standard TCP socket libraries like raw `pg` or `mysql2`).
  - *Best For:* Lightweight auth routing (Next.js Middleware), geo-redirects, A/B testing, and HTTP-based serverless DB proxies (e.g. Neon, Supabase HTTP).
- **Node.js Runtime**:
  - *Pros:* Full POSIX operating system environment, native C/C++ bindings, large NPM library compatibility, persistent database connection pooling.
  - *Best For:* Complex backend API routes, heavy RAG vector transformations, file system manipulation, and Python microservice communication."

---

### Q5: How do you measure and optimize Interaction to Next Paint (INP) in modern web applications?
#### Junior Answer:
"Use React.memo to make sure your buttons click faster."
#### Senior In-Depth Answer:
"INP measures the latency of all user interactions (clicks, taps, keystrokes) across the entire lifespan of the page, reporting the worst interaction.  
*Optimization Strategy:*
1. **Break Up Long Tasks**: The browser main thread cannot paint while running a JavaScript task $> 50\text{ms}$. Yield execution back to the browser using `await scheduler.yield()` or `setTimeout(..., 0)`.
2. **Use React 18 `useTransition`**: Separate urgent updates (typing in search bar) from non-urgent updates (filtering 1,000 document cards), allowing React to interrupt background filtering to keep keystrokes fluid.
3. **Debounce Expensive Handlers**: Never run expensive operations on raw `onChange` or `onScroll` events."

---

### Q6: What is On-Demand Revalidation in Next.js, and how does it compare to time-based ISR?
#### Junior Answer:
"Time-based revalidates every few seconds; on-demand revalidates when you tell it to."
#### Senior In-Depth Answer:
"- **Time-Based ISR** (`export const revalidate = 60`): Statically cached pages automatically re-check after 60 seconds. However, this means users might see stale data for up to 60 seconds, or the server wastes compute regenerating unchanged pages.  
- **On-Demand ISR** (`revalidatePath` and `revalidateTag`): The page remains statically cached on the CDN indefinitely with 0ms response time until an event occurs (e.g. user updates a product or uploads a document). A webhook or Server Action immediately invokes `revalidateTag('documents')` or `revalidatePath('/dashboard')`, purging the CDN cache globally in real-time."
