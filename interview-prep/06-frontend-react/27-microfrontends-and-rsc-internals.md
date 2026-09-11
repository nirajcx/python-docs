# Micro-Frontends, RSC Flight Protocol & React Native Performance

> **Target Audience:** FAANG / Tier-1 MNC Staff & Senior Frontend / Full-Stack Engineers  
> **Evaluation Focus:** Module Federation, React Server Components (Flight Wire Protocol), Hermes Bytecode, Reanimated Worklets  
> **Cross-References:** [14-react-core-architecture.md](./14-react-core-architecture.md) | [15-nextjs-and-react-native.md](./15-nextjs-and-react-native.md) | [18-react-ecosystem-libraries.md](./18-react-ecosystem-libraries.md)

---

## 1. Micro-Frontends & Webpack/Vite Module Federation

For large organizations (e.g. 50+ engineers across multiple autonomous squads), a monolithic frontend repository creates deployment bottlenecks.

```
                  Module Federation Runtime Architecture
                  
 Host Application (Shell / Container)
 ┌─────────────────────────────────────────────────────────────┐
 │ • Navigation Header & Global Auth State                     │
 │ • Loads remotes dynamically at runtime via HTTP             │
 └──────────────────────────────┬──────────────────────────────┘
                                │
        ┌───────────────────────┴───────────────────────┐
        ▼                                               ▼
 Remote 1: Billing Squad (Port 3001)             Remote 2: AI / RAG Squad (Port 3002)
 ┌─────────────────────────────┐                 ┌─────────────────────────────┐
 │ remoteEntry.js              │                 │ remoteEntry.js              │
 │ • Exposes: "./BillingWidget"│                 │ • Exposes: "./RAGChatDrawer"│
 │ • Deployed independently!   │                 │ • Deployed independently!   │
 └─────────────────────────────┘                 └─────────────────────────────┘
```

### Module Federation Configuration (Webpack / Vite)
```javascript
// remote-rag/webpack.config.js
const { ModuleFederationPlugin } = require("webpack").container;

module.exports = {
  plugins: [
    new ModuleFederationPlugin({
      name: "rag_remote",
      filename: "remoteEntry.js",
      exposes: {
        "./RAGChatDrawer": "./src/components/RAGChatDrawer",
      },
      shared: {
        react: { singleton: true, requiredVersion: "^18.2.0", eager: false },
        "react-dom": { singleton: true, requiredVersion: "^18.2.0" },
        zustand: { singleton: true },
      },
    }),
  ],
};
```

### Critical Shared Dependency Trap: `singleton: true`
If Remote A loads React 18.2.0 and the Host loads React 18.1.0 without `singleton: true`, **two separate instances of React are loaded into browser memory**. Hook state will break, raising `Invalid hook call: Hooks can only be called inside the body of a function component`. Setting `singleton: true` forces Module Federation to resolve a single shared React instance.

---

## 2. React Server Components (RSC) Internals & The Flight Protocol

RSC is **not** simply SSR. RSC introduces a novel streaming protocol: the **Flight Protocol**.

### What Actually Travels Over the Wire?
When Next.js renders a Server Component, it does **not** send HTML. It streams an optimized, compact JSON-like tree format known as the **Flight Wire Format**.

```
                         The Flight Wire Format Disassembly
                         
 Line 1: Module Reference (Client Component import)
 1:I["./src/components/ChatBox.tsx", ["default"], "ChatBox"]
 
 Line 2: Server Component AST & Props
 0:["$","div",null,{"className":"container","children":[
     ["$","h1",null,{"children":"Enterprise Documents"}],
     ["$","$1",null,{"tenantId":"tenant_alpha","tokenLimit":4096}]
 ]}]
```

### Decoding Flight Opcodes:
- **`I[...]` (Import / Module Reference)**: Tells the client: *"Fetch the client-side JavaScript chunk for `ChatBox.tsx` from the CDN and hydrate it with the props passed below."*
- **`0:[...]` (JSON Component Tree)**: Represents the virtual DOM elements rendered by Server Components. Notice that HTML tags like `<h1>Enterprise Documents</h1>` are pre-evaluated text, requiring **0 KB of client JavaScript** to render!
- **`S...`**: Suspense boundaries streamed asynchronously over HTTP chunked transfer encoding as backend promises resolve.

### Server-Client Serialization Boundary
Any prop passed from a Server Component to a Client Component must be **serializable**:
- ✅ **Allowed**: Primitives (`string`, `number`, `boolean`), plain objects, arrays, Promises, React elements.
- ❌ **Disallowed**: Functions, event handlers (`onClick`), class instances, symbols.

---

## 3. React Native Performance & The Hermes Engine

### The Hermes JavaScript Engine Internals
Traditional mobile JS engines (JSC - JavaScriptCore) parse and compile JavaScript source code into bytecode at **app startup on the user's phone**, causing slow startup times (Time-To-Interactive).  
**Hermes Engine**:
1. **Ahead-Of-Time (AOT) Bytecode Compilation**: JavaScript is compiled into optimized Hermes Bytecode (`.hbc`) on the developer's laptop during the build step. The APK/IPA contains zero raw JavaScript.
2. **Instant Memory-Mapped Execution**: Hermes bytecode is memory-mapped (`mmap`) directly from flash storage without reading the whole file into RAM, slashing app launch times by **$50\%$**.

```
                Hermes AOT Compilation vs. Legacy JSC
                
 Legacy JSC (Android/iOS)      Hermes Engine (Modern Production Standard)
┌─────────────────────────┐   ┌────────────────────────────────────────┐
│ App Launch:             │   │ Build Time (CI/CD):                    │
│ 1. Read JS from disk    │   │ • Source JS compiled to .hbc Bytecode  │
│ 2. Parse source string  │   ├────────────────────────────────────────┤
│ 3. Compile to Bytecode  │   │ App Launch:                            │
│ 4. Execute (Slow TTI!)  │   │ 1. mmap() Bytecode directly from disk  │
│                         │   │ 2. Execute immediately! (Sub-second TTI)│
└─────────────────────────┘   └────────────────────────────────────────┘
```

---

## 4. Mobile List Virtualization: `FlatList` Tuning

Rendering 5,000 items in React Native without virtualization will trigger an immediate OS memory kill.

```tsx
import { FlatList } from "react-native";

export function OptimizedDocumentList({ documents }: { documents: DocumentItem[] }) {
  return (
    <FlatList
      data={documents}
      renderItem={({ item }) => <DocumentRow item={item} />}
      keyExtractor={(item) => item.id}

      // CRUCIAL PROPS FOR 60-120 FPS SCROLLING:
      // 1. Skip dynamic height calculation by providing fixed dimensions
      getItemLayout={(data, index) => ({
        length: 72,       // Row height in pixels
        offset: 72 * index,
        index,
      })}

      // 2. Reduce the offscreen render window (default is 21 viewports!)
      windowSize={5}      // Renders 2 viewports above + 1 current + 2 below

      // 3. Render minimal items on initial mount to achieve instant display
      initialNumToRender={10}

      // 4. Batch renders during rapid scrolling
      maxToRenderPerBatch={10}
      removeClippedSubviews={true} // Unmounts offscreen native views
    />
  );
}
```

---

## 5. UI Thread vs. JS Thread: Reanimated 3 Worklets

In React Native, animations executed on the **JavaScript Thread** drop frames whenever the thread is busy parsing large JSON payloads or sorting arrays.

### Reanimated 3 Worklets: Direct UI Thread Execution
A **worklet** is a tiny JavaScript function marked with `'worklet';` compiled to run **directly on the UI thread** at 60–120 FPS via the JSI (JavaScript Interface), completely immune to JS thread congestion.

```tsx
import Animated, { useSharedValue, useAnimatedStyle, withSpring } from "react-native-reanimated";

export function BouncingChatBubble() {
  const scale = useSharedValue(1);

  // Executed on the native UI thread via C++ worklet!
  const animatedStyle = useAnimatedStyle(() => {
    'worklet';
    return {
      transform: [{ scale: scale.value }],
    };
  });

  const handlePress = () => {
    // Runs smooth spring animation on UI thread uninterrupted
    scale.value = withSpring(1.2);
  };

  return (
    <Animated.View style={[styles.bubble, animatedStyle]}>
      <Button title="Tap" onPress={handlePress} />
    </Animated.View>
  );
}
```

---

## 6. Pointwise MNC Interview Questions & Answers

### Q1: How do Server Actions in Next.js prevent Cross-Site Request Forgery (CSRF)?
**Answer:**
1. Server Actions can only be invoked via `POST` HTTP requests.
2. Next.js enforces strict **Origin Header Verification**: the `Origin` header in the incoming request must match the host header of the application server. If they differ, the request is rejected with HTTP 403.
3. Because Server Actions are identified by a cryptographic hash of the action function generated at build time, an attacker cannot forge an action call without knowing the exact hash signature deployed in that production build.

### Q2: What are the primary failure modes of Micro-Frontends using Module Federation?
**Answer:**
1. **Cascading Network Failures**: If the remote hosting the Billing widget goes down or experiences DNS failure, the entire Shell container can crash unless wrapped in an **Error Boundary** with dynamic fallback imports.
2. **Version Skew / Diamond Dependencies**: If Host requires Library X v2.0 and Remote requires Library X v1.0, failing to specify `shared` rules leads to duplicate bundles or incompatible runtime global states.
3. **CSS Collision**: Without scoped styling (CSS Modules, Tailwind, or Shadow DOM), global CSS rules from one remote can inadvertently override typography and layouts in another remote.
