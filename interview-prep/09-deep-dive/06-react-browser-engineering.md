# React, browser, forms aur frontend engineering — deeper round

[Roadmap](../README.md) · [React core](../00-start-here/03-react-nextjs-quick-guide.md)

## 1. Hooks and rendering follow-ups

Props read-only inputs; state component position/identity ke saath persist. Parent render ordinarily child render trigger kar sakta hai; memo can skip with stable props, but own state/context still update. `Object.is` state equality bailout does not mean all React rendering is “reference compare only”.

Ordinary hooks top level of components/custom hooks. React `use` is exception: condition/loop mein resource read allowed, but still React component/hook context chahiye and `try/catch` around it prohibited. Promise pending par Suspense, rejection error boundary; unstable newly-created promise every render avoid. [React use](https://react.dev/reference/react/use).

Fiber implementation tree of linked nodes hai, plain doubly-linked-list model incomplete. Concurrent rendering interruptible work support karta hai, not multiple JS threads executing component simultaneously. Commit/layout work can still block paint.

## 2. Reducer vs state vs custom hook

Reducer related transitions centralize karta hai, e.g. draft→saving→saved/error. Reducer pure hona chahiye; network side effect reducer mein nahi. Custom hook stateful logic reuse karta hai, automatically shared state create nahi—two calls ordinarily independent instances.

`useRef` persist without render; `useImperativeHandle` controlled imperative API expose kar sakta hai. `useId` accessibility association ke liye, data list keys ka generator nahi. Context provider values change par consumers render; `memo` context update block nahi karta.

## 3. Form engineering: library vs simple state

Small form controlled state often fine. Large form mein field subscriptions, validation timing, dynamic arrays, async submission, reset/defaults, dirty/touched state complexity grows. React Hook Form uncontrolled registration and subscriptions reduce work, but watch/formState/controlled components rerender kar sakte hain—“zero renders always” false.

Number HTML input value often string; parser/schema coercion explicit. Missing/empty/null semantics agree with API. Client validation instant UX, server validation authoritative. Server field errors input se associate, submit-level failures visible, failed submit typed values preserve kare.

Schema evolution: backend adds required field → old frontend must remain compatible or rollout coordinate. OpenAPI-generated TypeScript helps compilation; runtime validation, contract tests and deployment versioning still matter.

## 4. Fetching, query caching and mutations

Remote state includes freshness, retry, pagination and invalidation. Cache key all query inputs + identity scope represent kare. “stale” means eligible for refetch according to policy, immediate delete nahi. Cache retention and staleness timers separate concepts. Retry non-idempotent mutation blindly nahi.

Optimistic update only safe UX assumptions ke saath. Server final value/version may differ; rollback older request se newer mutation overwrite na kare. Invalidation coarse but safe ho sakti hai; fine-grained cache patch faster but complexity. Offline queues must reconcile conflicts after reconnect.

## 5. Suspense, transition, memo and compiler

Suspense supported resource/lazy component loading boundary hai; ordinary Effect fetch automatically suspend nahi hoti. Transition non-urgent update schedule karta hai; controlled input current value urgent rakho. Deferred value expensive result display lag allow karta hai, debounce API calls nahi.

React Compiler configured build optimization hai; React 19 install karne se every project auto-compiled nahi hota. Compiler manual memoization ki need reduce kar sakta hai, but configuration/support/performance verify karo. Logic correct first, measure second. [React Compiler introduction](https://react.dev/learn/react-compiler/introduction).

## 6. SSR, SSG, ISR, RSC, hydration

SSR request server HTML; SSG prerender; ISR regeneration/revalidation strategy; RSC server execution and serialization model. These orthogonal axes overlap kar sakti hain. Client Components initial server HTML ka part ho sakti hain, then hydrate. RSC code client bundle mein nahi, lekin serialized props/output secrets leak kar sakte hain—data projection needed.

Server Actions bhi input-facing server entrypoints hain: authenticate, authorize, validate, rate-limit as appropriate. Server-only placement alone business permission enforce nahi karta. Framework caching defaults evolving hain; project version-specific docs follow karo. [Next.js server/client boundaries](https://nextjs.org/docs/app/getting-started/server-and-client-components).

Hydration troubleshooting: same initial inputs/timezone/locale, invalid HTML nesting, browser-only data, random values, extensions. Escape-hatch suppression actual mismatch fix nahi. CSS skeleton/reserved image dimensions prevent layout shift, but one Image component zero page CLS guarantee nahi.

## 7. Browser rendering + HTML/CSS basics

URL navigation may reuse DNS/connection/cache. HTTP/1.1 and HTTP/2 commonly TLS over TCP; HTTP/3 QUIC over UDP. Browser HTML parse → DOM, CSS style → layout → paint/composite conceptual pipeline. JavaScript long tasks can delay interaction; layout reads interleaved writes force repeated layout.

| Topic | Explain in interview |
|---|---|
| Box model | content/padding/border/margin; border-box includes padding/border in declared width |
| Flex vs Grid | one-dimensional distribution vs two-dimensional layout; use based on structure |
| Specificity/cascade | origin/layer/importance/specificity/source order, not simply last selector |
| Positioning | static/relative/absolute/fixed/sticky; containing block and scroll container matter |
| Stacking context | z-index scoped; huge z-index cannot escape parent context |
| Responsive UI | content-driven breakpoints, flexible sizes, media/container queries where supported |
| Semantic HTML | correct buttons, links, inputs, headings, table structure |

CSS utility framework doesn't guarantee tiny bundle/accessible UI. Tailwind build/config differs by version; dynamic constructed class names may not be discovered. Component library copied code still needs maintenance, dependency updates and keyboard testing.

## 8. Accessibility practical round

Labels linked via htmlFor/id, real button for action, anchor for navigation. Modal: meaningful label, focus placement/trap appropriate, Escape handling, restore trigger focus. Keyboard behaviors element-specific; not every element responds to Space/Enter/Escape identically. Error text via aria-describedby, important async status announce thoughtfully. Contrast, zoom/reflow, reduced motion, alt text context matter.

Automated checks catch subset; keyboard and screen-reader journeys test karo. ARIA labels semantic element misuse cure nahi karte.

## 9. Performance debugging

Network waterfall vs React Profiler vs browser Performance panel different evidence dete hain. Profiler slow component, Performance JS/layout/paint, network payload/latency. Real user metrics vs lab runs separate. LCP loading, INP responsiveness, CLS stability; goal thresholds official Web Vitals docs/project SLO se verify.

Optimize measured bottleneck: avoid waterfall, smaller response, pagination, lazy heavy code, correct image sizes, virtualize long lists with keyboard/accessibility plan. `React.memo` expensive child help kar sakta hai if props stable; unnecessary memo adds maintenance. CPU-heavy computation worker mein, not endless useMemo hopes.

## 10. Security and frontend testing

JSX text escaping helpful; raw HTML/unsafe URLs/script injection surfaces still need validation/sanitization. Private API keys frontend build mein expose mat karo. Auth state UI hint, server authorization source of truth.

React Testing Library user-visible behavior: labelled input, submit, loading, error, resulting view. Test stale response with deferred promises, debounce with fake timers, unmount cleanup. E2E real API contract/login/cookies test kare, every component permutation E2E mein inefficient ho sakta hai.

## Machine-coding expectations

Search/table CRUD with loading/error/empty states, modal form, pagination/sort, debounce cleanup, request race protection, accessible UI. Explain time complexity and state ownership while implementing. Advanced stretch: virtualized list, optimistic edit with conflict, multi-tab session refresh.
