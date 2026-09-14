# Memory Optimization, Profiling & Memory Leaks: Python, AI & Frontend

> **Target Audience:** Tier-1 MNCs, FAANG, AI Platforms (Senior / Staff Engineer Level)  
> **Scope:** Full-Stack & Systems Depth (CPython Heap, PyMalloc, Linux cgroups/OOM, React Closures, CUDA VRAM)  
> **Cross-References:** [01-python-fundamentals.md](../01-python-core/01-python-fundamentals.md) | [02-python-oop.md](../01-python-core/02-python-oop.md) | [14-react-core-architecture.md](../06-frontend-react/14-react-core-architecture.md) | [20-advanced-database-engineering-and-migrations.md](20-advanced-database-engineering-and-migrations.md)

---

## 1. CPython Memory Internals: The Allocator Hierarchy

CPython avoids calling the OS `malloc()` for every small allocation because system calls incur high CPU context-switching overhead and cause memory fragmentation.

```
                      CPython Memory Allocator Layers
                      
 ┌─────────────────────────────────────────────────────────────┐
 │ Layer 3: Object-Specific Allocators                         │
 │ (Dedicated fast paths for int, float, dict, list, unicode)  │
 └──────────────────────────────┬──────────────────────────────┘
                                │
 ┌──────────────────────────────▼──────────────────────────────┐
 │ Layer 2: PyMalloc (Small Object Allocator for <= 512 bytes) │
 │                                                             │
 │   ┌─────────────────────────────────────────────────────┐   │
 │   │ Arena (256 KB chunk requested from OS via malloc)   │   │
 │   │   ├── Pool 0 (4 KB page: e.g. handles 16-byte blocks)│   │
 │   │   ├── Pool 1 (4 KB page: e.g. handles 32-byte blocks)│   │
 │   │   └── Pool N (4 KB page: e.g. handles 64-byte blocks)│   │
 │   └─────────────────────────────────────────────────────┘   │
 └──────────────────────────────┬──────────────────────────────┘
                                │
 ┌──────────────────────────────▼──────────────────────────────┐
 │ Layer 1: Python Core Memory Manager (PyMem_RawMalloc)       │
 └──────────────────────────────┬──────────────────────────────┘
                                │
 ┌──────────────────────────────▼──────────────────────────────┐
 │ Layer 0: Operating System Virtual Memory (glibc malloc/free)│
 └─────────────────────────────────────────────────────────────┘
```

### Why Linux Reports High RAM Even After `del` and `gc.collect()`
Interviewers at MNCs frequently ask: *"I deleted 10 million objects and called `gc.collect()`, but `docker stats` and `top` show the Python container is still using 4GB of RAM. Is it a memory leak?"*

**The Senior Answer:**
- **No, it is PyMalloc Arena Fragmentation.**
- PyMalloc allocates memory in **256KB Arenas**. An arena can **only** be released back to the host operating system (`free()`) if **every single 4KB pool within that arena is 100% empty**.
- If 10 million objects are deleted, but just *one single long-lived object* remains referenced inside each 256KB arena, the operating system cannot reclaim any of those pages.
- The memory is not "leaked"; PyMalloc marks the internal 4KB pools as free for *future Python object allocations*, but the Linux kernel continues to report a high Resident Set Size (RSS).

---

## 2. Real-World Python & FastAPI Memory Leaks (Root Causes & Fixes)

### Leak 1: The Class Method `@lru_cache` Memory Trap
Applying `@lru_cache` to an instance method causes a permanent memory leak:
```python
# BUGGY CODE: Leaks memory permanently!
from functools import lru_cache

class DocumentProcessor:
    def __init__(self, doc_data: bytes):
        self.doc_data = doc_data  # Large 50MB PDF buffer

    @lru_cache(maxsize=128)
    def parse_section(self, section_id: int):
        # 'self' is passed as the first argument to parse_section!
        # The lru_cache dictionary stores a reference to 'self' in its global cache table.
        # Even when the DocumentProcessor goes out of scope, self is NEVER garbage collected!
        return self.doc_data[section_id : section_id + 1000]

# SENIOR FIX: Cache standalone functions or use a property cache
class SafeDocumentProcessor:
    def __init__(self, doc_data: bytes):
        self.doc_data = doc_data

    def parse_section(self, section_id: int):
        return _pure_cached_parser(self.doc_data, section_id)

@lru_cache(maxsize=128)
def _pure_cached_parser(doc_data: bytes, section_id: int):
    return doc_data[section_id : section_id + 1000]
```

### Leak 2: Dangling References in Event Listeners & Global Registries
In microservices, registering callbacks without weak references retains entire objects:
```python
import weakref

class EventDispatcher:
    def __init__(self):
        # BAD: self._subscribers = [] -> Strong reference prevents GC of subscriber
        # GOOD: WeakSet automatically evicts subscriber when its owner goes out of scope
        self._subscribers = weakref.WeakSet()

    def register(self, subscriber):
        self._subscribers.add(subscriber)
```

### Leak 3: Closures Capturing Heavy Outer Scope
```python
# BUGGY PATTERN:
def build_vector_indexer(huge_corpus: list[str]):
    # huge_corpus is 2GB of strings in RAM
    metadata_lookup = {i: len(text) for i, text in enumerate(huge_corpus)}
    
    async def query_index(doc_id: int):
        # Even though query_index ONLY uses metadata_lookup,
        # Python's closure mechanism keeps the ENTIRE lexical scope alive,
        # retaining huge_corpus in memory indefinitely!
        return metadata_lookup.get(doc_id)
        
    return query_index

# SENIOR FIX: Explicitly delete or isolate variables before creating closure
def build_safe_vector_indexer(huge_corpus: list[str]):
    metadata_lookup = {i: len(text) for i, text in enumerate(huge_corpus)}
    del huge_corpus  # Sever the pointer before returning closure!
    
    async def query_index(doc_id: int):
        return metadata_lookup.get(doc_id)
    return query_index
```

### Leak 4: Unclosed Coroutines & Abandoned Async Tasks
If an async coroutine is spawned with `asyncio.create_task()` and gets stuck on a network socket without a timeout, the task object, its stack frame, and all local variables are held in the event loop's `_tasks` set permanently.

---

## 3. Production Memory Profiling Tooling (MNC Standards)

Never guess where memory leaks occur. Top-tier teams profile using systematic telemetry.

```
                          Python Memory Profiler Suite
                          
 Profiler      Overhead   Scope                     Best For
┌────────────┐┌─────────┐┌────────────────────────┐┌────────────────────────────────┐
│ tracemalloc│ Low-Med  │ Line-by-line snapshots │ Standard library leak detection│
│ memray     │ Low      │ C-extensions + Python  │ Production profiling (Bloomberg│
│ objgraph   │ High     │ Reference graph visual │ Diagnosing circular GC cycles  │
│ filprofiler│ High     │ Peak memory allocator  │ Finding OOM causes in batch AI │
└────────────┘└─────────┘└────────────────────────┘└────────────────────────────────┘
```

### 1. `tracemalloc` Production Snapshot Script
```python
import tracemalloc
import logging

logger = logging.getLogger("memory")

# Start tracing allocations (record up to 10 stack frames)
tracemalloc.start(10)

def profile_endpoint_memory():
    snapshot1 = tracemalloc.take_snapshot()

    # Run heavy operations (e.g. RAG retrieval, document parsing)
    execute_workload()

    snapshot2 = tracemalloc.take_snapshot()

    # Compare snapshot2 against snapshot1 to see exact line allocations
    top_stats = snapshot2.compare_to(snapshot1, 'lineno')

    logger.info("--- TOP 5 MEMORY ALLOCATIONS BY LINE ---")
    for stat in top_stats[:5]:
        logger.info(stat)
        # Output: /app/rag/parser.py:42: size=142 MB (+142 MB), count=12400 (+12400)
```

### 2. Diagnosing Circular References with `objgraph`
```python
import gc
import objgraph

# Force a garbage collection cycle
gc.collect()

# Print the top 10 object types consuming heap instances
objgraph.show_most_common_types(limit=10)

# Generate a visual graph (PNG) showing who holds references to a leaked DocumentChunk
leaked_objects = objgraph.by_type("DocumentChunk")
if leaked_objects:
    objgraph.show_backrefs(leaked_objects[0], max_depth=5, filename="leak_backrefs.png")
```

---

## 4. Linux Containers, cgroups & The `OOMKilled` (Exit Code 137)

When running FastAPI or Celery inside Docker / Kubernetes, memory limits are enforced by **Linux cgroups (`memory.max`)**.

```
 Physical Host Memory
┌─────────────────────────────────────────────────────────────┐
│ Kubernetes Pod: Memory Limit = 2.0 GiB                      │
│                                                             │
│   FastAPI Process RSS: 1.8 GiB                              │
│   + New 400MB PDF Upload loaded into RAM                    │
│   = 2.2 GiB (Exceeds cgroup limit!)                         │
│                                                             │
│   KERNEL INTERVENTION: Linux Out-Of-Memory Killer           │
│   Sends SIGKILL (-9) ──► Process terminated immediately!    │
│   Pod Status: OOMKilled | Exit Code: 137 (128 + 9)          │
└─────────────────────────────────────────────────────────────┘
```

### Prevention Strategies:
1. **Streaming Request Bodies**: Never parse large files with `await file.read()`. Use `UploadFile` (Starlette spool file) and stream chunks directly to disk or S3.
2. **Uvicorn Max Requests / Memory Recycler**:
   Configure Gunicorn to recycle worker processes after handling a set number of requests to mitigate slow memory fragmentation:
   ```bash
   gunicorn main:app \
     --worker-class uvicorn.workers.UvicornWorker \
     --max-requests 5000 \
     --max-requests-jitter 500
   ```
   The jitter prevents all workers from restarting at the exact same moment.

---

## 5. React & Modern Frontend Memory Leaks

Frontend memory leaks cause tabs to consume 2GB+ RAM, slowing browser performance and causing mobile web browsers (Safari iOS) to crash.

### Leak 1: Uncleared Subscriptions & Event Listeners
```tsx
// BUGGY PATTERN: Leaks on every mount/unmount
useEffect(() => {
  const handleResize = () => setWindowWidth(window.innerWidth);
  window.addEventListener("resize", handleResize);
  // MISSING CLEANUP! Every time component remounts, an uncollected listener
  // retains references to the component instance in the global DOM window object!
}, []);

// SENIOR FIX: Guaranteed cleanup
useEffect(() => {
  const handleResize = () => setWindowWidth(window.innerWidth);
  window.addEventListener("resize", handleResize);
  return () => window.removeEventListener("resize", handleResize);
}, []);
```

### Leak 2: Stale Closures in `setInterval` and WebSockets
```tsx
// BUGGY PATTERN:
useEffect(() => {
  const socket = new WebSocket("wss://api.enterprise.com/rag/chat");
  socket.onmessage = (event) => {
    // Closure holds reference to local state and heavy document context
    appendMessage(event.data);
  };
  // MISSING CLEANUP: If user navigates away, WebSocket connection remains
  // open on the browser thread, leaking network sockets and memory!
}, []);

// SENIOR FIX:
useEffect(() => {
  const socket = new WebSocket("wss://api.enterprise.com/rag/chat");
  socket.onmessage = (event) => appendMessage(event.data);

  return () => {
    socket.close(1000, "Component unmounted");
  };
}, []);
```

### Leak 3: Detached DOM Trees
A detached DOM node occurs when a node has been removed from the DOM tree, but some JavaScript code still holds a reference to it (e.g. in a global array or `useRef`). The browser cannot garbage collect the DOM node or any of its children.  
*Diagnosis:* In Chrome DevTools, open the **Memory** tab, capture a **Heap Snapshot**, and filter by `Detached HTMLElement`.

---

## 6. AI & RAG Memory Optimization (Quantization & CUDA VRAM)

### 1. Vector Embeddings: RAM Sizing & Quantization
In vector search (HNSW indexes in Qdrant, Milvus, or FAISS), storing 10 million vectors in memory can bankrupt infrastructure:
- 10,000,000 vectors $\times$ 1536 dimensions $\times$ 4 bytes (`float32`) = **61.44 GB of pure raw vector RAM** (plus graph edge overhead $\approx 85\text{ GB}$).

| Compression Strategy | Precision | RAM for 10M Vectors | Recall Retention |
|---|---|---|---|
| **Raw `float32`** | 32-bit float | $\approx 61.4\text{ GB}$ | $100\%$ |
| **Scalar Quantization (SQ8)** | 8-bit integer | $\mathbf{\approx 15.3\text{ GB (75% savings)}}$ | $\mathbf{98\text{--}99\%}$ |
| **Product Quantization (PQ)** | 8-bit sub-vectors | $\mathbf{\approx 3.8\text{ GB (94% savings)}}$ | $92\text{--}95\%$ |

> **Staff Tip:** In production RAG systems, **Scalar Quantization (SQ8)** is enabled by default in Qdrant. It cuts RAM bills by $4\times$ while utilizing integer SIMD hardware acceleration to speed up vector comparisons.

### 2. PyTorch CUDA Memory Leaks: `torch.no_grad()`
In Python services running local embedding or re-ranking models:
```python
# BUGGY PATTERN: Leaks GPU VRAM rapidly during inference
def embed_query(query: str):
    tokens = tokenizer(query, return_tensors="pt").to("cuda")
    # WITHOUT torch.no_grad(), PyTorch tracks and builds an autograd DAG graph
    # storing intermediate activation tensors in GPU VRAM for backpropagation!
    output = model(**tokens)
    return output.last_hidden_state

# SENIOR FIX:
@torch.inference_mode()  # Faster and more memory-efficient than torch.no_grad()
def embed_query_safe(query: str):
    tokens = tokenizer(query, return_tensors="pt").to("cuda")
    output = model(**tokens)
    return output.last_hidden_state.cpu()
```

---

## 7. Pointwise MNC Interview Questions & Answers (Memory Systems)

### Q1: How does Python's cyclical garbage collector detect and break reference cycles?
**Answer:**
1. Reference counting alone cannot detect circular references (e.g. `A.b = B; B.a = A; del A; del B`). The ref count for both objects remains 1.
2. The cyclical GC monitors container objects (lists, dicts, custom class instances) tracked in doubly-linked generation lists (Gen 0, 1, 2).
3. **Trial Deletion Algorithm**:
   - The GC makes a copy of the reference count (`gc_refs`) for all candidate objects.
   - It iterates through each candidate and decrements `gc_refs` for every object referenced by it.
   - Any object whose `gc_refs` reaches 0 was referenced *only* from within the isolated cycle.
   - Objects with `gc_refs == 0` are flagged as unreachable and collected; objects with `gc_refs > 0` are retained along with any objects reachable from them.

### Q2: What is the difference between shallow copy, deep copy, and copy-on-write?
**Answer:**
- **Shallow Copy** (`copy.copy(x)`): Allocates a new container object, but populates it with references to the original child objects. Modifying nested mutable objects affects the original.
- **Deep Copy** (`copy.deepcopy(x)`): Recursively copies every nested object, tracking memoized references to handle cyclic graphs cleanly. Heavy memory and CPU overhead.
- **Copy-On-Write (COW)**: Memory pages are shared read-only across processes (e.g., when Linux `fork()`s worker processes in Gunicorn). Memory pages are only duplicated when a process writes to them. *Python Gotcha:* Prior to Python 3.8, CPython's reference counting modified `ob_refcnt` on reads, dirtying the memory page and destroying Linux Copy-On-Write benefits.

### Q3: How do you profile a memory leak in a production Kubernetes pod without restarting it?
**Answer:**
1. Execute an ephemeral debug container or SSH into the pod namespace.
2. If **`py-spy`** is installed, generate a flamegraph of allocations with zero overhead:
   `py-spy dump --pid <fastapi_pid>`.
3. If using **`memray`**, attach to the live running process dynamically:
   `memray attach <fastapi_pid>`.
4. Trigger an internal diagnostic admin endpoint (`/admin/memory-snapshot`) protected by authentication that invokes `tracemalloc.take_snapshot()` and outputs top allocations to S3 or logs.
