# Python Fundamentals: Under the Hood & Interview Prep

Target Role: Python/FastAPI Backend & GenAI Engineer  
Cross-References: [02-python-oop.md](./02-python-oop.md) | [03-python-async.md](./03-python-async.md) | [11-system-design-basics.md](../04-system-design-dsa/11-system-design-basics.md)

---

## 1. Data Types, Mutability & Memory Representation

In Python, **everything is an object** (instances of classes, functions, modules, integers). Variables are not memory boxes that hold values; they are **names bound to references (pointers) in memory**.

### Mutability Map
| Type | Mutable? | Example Operations | Memory Behavior on Modification |
|---|---|---|---|
| `int`, `float`, `bool`, `complex` | **No** | `x += 1` | Rebinds pointer to a newly created object. |
| `str`, `tuple`, `bytes`, `frozenset` | **No** | `t = (1, 2)` | Content cannot be modified in-place; elements immutable. |
| `list`, `dict`, `set`, `bytearray` | **Yes** | `l.append(4)`, `d["k"] = "v"` | Mutates object in-place; memory address (`id()`) unchanged. |

```python
# Pass-by-object-reference demonstration
def modify_values(num: int, items: list[int]) -> None:
    num += 10          # Rebinds local variable 'num' to new int object
    items.append(100)  # Mutates the underlying list in heap memory

val = 5
lst = [1, 2]
modify_values(val, lst)
print(val)  # 5  (Unchanged)
print(lst)  # [1, 2, 100] (Mutated!)
```

### The Default Mutable Argument Gotcha
Default arguments are evaluated **once at module load / function definition time**, not at invocation time.

```python
# BUGGY PATTERN
def add_event(event: str, events: list = []) -> list:
    events.append(event)
    return events

print(add_event("login"))   # ['login']
print(add_event("signup"))  # ['login', 'signup'] -> Persisted across calls!

# SENIOR IDIOMATIC FIX
def add_event_fixed(event: str, events: list | None = None) -> list:
    if events is None:
        events = []
    events.append(event)
    return events
```

### 🧠 Junior vs. Senior Answer: "How does Python pass arguments to functions?"
- **Junior Answer**: "Python passes primitives by value and lists/objects by reference like JavaScript."
- **Senior Answer**: "Python uses *call-by-sharing* (or *pass-by-object-reference*). All variables hold references to heap-allocated objects. When calling a function, the references are passed by value. If the object referenced is mutable (like a `list` or `dict`), mutations through the reference affect the caller. If the object is immutable (`int`, `str`, `tuple`), any operation producing a new value simply rebinds the local name to a new heap object without touching the original."

---

## 2. Comprehensions vs. Generators: Memory & Performance

Comprehensions allocate the entire collection in memory eagerly. Generator expressions produce values lazily on-demand.

```python
# List, Dict, and Set Comprehensions
squared_list = [x**2 for x in range(10) if x % 2 == 0]
lookup_dict  = {f"user_{i}": i * 10 for i in range(5)}
unique_tags  = {tag.strip().lower() for tag in ["AI ", "ai", "ML", "python"]}

# Generator Expression (Lazy stream)
import sys

large_list_comp = [x * 2 for x in range(1_000_000)]
large_gen_expr  = (x * 2 for x in range(1_000_000))

print(sys.getsizeof(large_list_comp))  # ~8,448,728 bytes (~8.4 MB)
print(sys.getsizeof(large_gen_expr))   # ~104 bytes (constant generator state!)
```

**Rule of thumb for RAG/Data pipelines:** Use generator expressions when streaming large batches of embeddings or chunked documents to prevent Out-Of-Memory (OOM) crashes in memory-constrained containers.

---

## 3. Function Signatures: `*args`, `**kwargs`, Positional-Only & Keyword-Only

Python 3.8+ introduced positional-only (`/`) and keyword-only (`*`) operators for strict API contracts.

```python
def configure_pipeline(
    model_name: str,          # Positional or keyword
    batch_size: int = 32,     # Positional or keyword
    /,                        # Everything before '/' is POSITIONAL-ONLY
    threshold: float = 0.5,   # Positional or keyword
    *,                        # Everything after '*' is KEYWORD-ONLY
    cache: bool = True,       # Must be passed as cache=True
    **extra_configs           # Arbitrary keyword kwargs
) -> dict:
    return {
        "model": model_name,
        "batch_size": batch_size,
        "threshold": threshold,
        "cache": cache,
        "extras": extra_configs,
    }

# Allowed:
configure_pipeline("text-embedding-3-small", 64, threshold=0.7, cache=False, timeout=30)

# TypeError: Positional-only parameter passed as keyword!
# configure_pipeline(model_name="gpt-4o", batch_size=32)
```

---

## 4. Decorators: Mechanics, Closures, and Parameterized Wrappers

Decorators are syntactic sugar for higher-order functions: `@dec def f(): pass` is identical to `f = dec(f)`.

### Production Decorator Template with `functools.wraps`
Without `functools.wraps`, the decorated function loses its `__name__`, `__doc__`, and signature metadata (breaks FastAPI dependency inspection and debugging tools!).

```python
import functools
import time
import logging
from typing import Callable, Any

logger = logging.getLogger(__name__)

def retry_with_backoff(retries: int = 3, backoff_factor: float = 0.5):
    """Decorator factory accepting arguments."""
    def decorator(func: Callable) -> Callable:
        @functools.wraps(func)
        def wrapper(*args: Any, **kwargs: Any) -> Any:
            attempt = 0
            delay = backoff_factor
            while attempt < retries:
                try:
                    return func(*args, **kwargs)
                except Exception as exc:
                    attempt += 1
                    if attempt >= retries:
                        logger.error(f"Function {func.__name__} failed after {retries} retries.")
                        raise
                    logger.warning(f"Retry {attempt}/{retries} for {func.__name__} in {delay}s due to: {exc}")
                    time.sleep(delay)
                    delay *= 2
        return wrapper
    return decorator

@retry_with_backoff(retries=3, backoff_factor=1.0)
def fetch_external_embedding(text: str) -> list[float]:
    # Simulated unreliable LLM API call
    return [0.1, 0.2, 0.3]
```

---

## 5. Iterators, Generators, and `yield from`

- **Iterable**: Implements `__iter__()` returning an Iterator.
- **Iterator**: Implements `__next__()` (returning next element or raising `StopIteration`) and `__iter__()` (returning `self`).
- **Generator**: A function containing `yield` that automatically creates an iterator preserving stack state.

```python
# Custom Chunking Generator for Document Streaming
from typing import Iterator

def chunk_document(document: str, chunk_size: int, overlap: int) -> Iterator[dict]:
    """Yields overlapping chunks lazily without holding duplicated strings in memory."""
    start = 0
    doc_len = len(document)
    chunk_id = 0
    
    while start < doc_len:
        end = min(start + chunk_size, doc_len)
        yield {
            "chunk_id": chunk_id,
            "start": start,
            "end": end,
            "text": document[start:end]
        }
        if end == doc_len:
            break
        start += (chunk_size - overlap)
        chunk_id += 1

# 'yield from' delegates generator execution cleanly:
def batch_corpus_stream(corpus: list[str], chunk_size: int = 500) -> Iterator[dict]:
    for doc in corpus:
        yield from chunk_document(doc, chunk_size=chunk_size, overlap=50)
```

---

## 6. Context Managers: Resource Safety & `contextlib`

Context managers guarantee resource cleanup (e.g. database connections, open files, locks) even when exceptions occur.

### Class-based vs. `contextlib.contextmanager`
```python
from contextlib import contextmanager
import time

# Method 1: Dunder methods (__enter__, __exit__)
class ManagedDBConnection:
    def __init__(self, dsn: str):
        self.dsn = dsn
        self.conn = None

    def __enter__(self):
        print("Acquiring connection...")
        self.conn = f"Connected to {self.dsn}"
        return self.conn

    def __exit__(self, exc_type, exc_val, exc_tb):
        print("Releasing connection back to pool...")
        self.conn = None
        # Return True to suppress exceptions, False/None to propagate
        return False

# Method 2: Generator with contextlib
@contextmanager
def execution_timer(task_name: str):
    start = time.perf_counter()
    try:
        yield
    finally:
        elapsed = time.perf_counter() - start
        print(f"[{task_name}] took {elapsed * 1000:.2f}ms")

# Usage:
with execution_timer("Vector DB Query"):
    with ManagedDBConnection("postgres://localhost:5432/rag") as conn:
        print(f"Executing query with {conn}")
```

---

## 7. The GIL, Threading, Multiprocessing & AsyncIO

The **GIL (Global Interpreter Lock)** is a mutual-exclusion mutex used by CPython to prevent multiple native OS threads from executing Python bytecode simultaneously.

### Why does the GIL exist?
CPython's memory management uses reference counting. Without a global lock, race conditions between threads incrementing/decrementing reference counts would corrupt memory or cause deadlocks.

### Concurrency Matrix: Which one do you pick?
| Paradigm | Tooling | GIL Bound? | Best For | Overhead |
|---|---|---|---|---|
| **AsyncIO** | `asyncio`, `uvloop` | Single thread; cooperative switching at `await` | High-concurrency network I/O (FastAPI, LLM API calls) | Extremely low (single thread stack) |
| **Multithreading** | `threading`, `ThreadPoolExecutor` | Yes (GIL released during OS I/O like disk/network C calls) | Blocking I/O (file I/O, legacy sync DB calls) | Medium (OS thread stacks ~8MB) |
| **Multiprocessing**| `multiprocessing`, `ProcessPoolExecutor` | No (Separate Python process per core with own GIL & memory) | CPU-bound computation (image preprocessing, embedding generation) | High (IPC serialization via `pickle`, memory duplication) |

### 🧠 Junior vs. Senior Answer: "Does multithreading make Python code faster?"
- **Junior Answer**: "Yes, threading lets multiple tasks run in parallel so the CPU finishes faster."
- **Senior Answer**: "It depends strictly on the workload. For CPU-bound tasks (e.g. matrix math, heavy data parsing), multithreading in CPython is actually *slower* than single-threaded execution due to the GIL contention and thread context-switching overhead. However, for I/O-bound tasks (HTTP requests, database queries), threads release the GIL while waiting on the operating system socket/file descriptors, yielding concurrency. For CPU-bound Python workloads, use `multiprocessing` or native C/Rust extensions (like NumPy or PyTorch) that release the GIL during heavy compute."

---

## 8. Python Memory Management & Garbage Collection

Memory in CPython is managed via two coordinated systems:

### 1. Reference Counting (Primary, Real-Time)
- Every Python object has an internal `ob_refcnt` field.
- Incremented when bound to a name, passed to a function, or placed in a container.
- Decremented when a variable goes out of scope or `del` is called.
- When `ob_refcnt == 0`, memory is deallocated **immediately**.

### 2. Generational Cyclical Garbage Collector (`gc` module)
Reference counting alone **cannot detect circular references**:
```python
a = []
b = []
a.append(b)
b.append(a)
del a
del b
# Ref count for both is still 1! Without cyclical GC, this leaks memory forever.
```
- The cyclical GC monitors objects that can hold references (lists, dicts, custom classes, tuples).
- It groups objects into 3 generations: **Gen 0** (newly created), **Gen 1** (survived one GC collection), and **Gen 2** (long-lived).
- Gen 0 runs frequently; Gen 2 runs rarely. If an object survives enough collections, it is promoted.

```python
import gc
print(gc.get_threshold())  # Default: (700, 10, 10)
# (700 allocations net of deallocations triggers Gen 0; 
#  10 Gen 0 runs triggers Gen 1; 10 Gen 1 runs triggers Gen 2)
```

---

## 9. Gotchas & Follow-Up Questions Interviewers Ask

1. **"Is `is` the same as `==`?"**
   - `==` checks value equality (invoking `__eq__`).
   - `is` checks identity equality (comparing memory addresses `id(a) == id(b)`).
   - *Gotcha:* Python caches small integers (`-5` to `256`) and string interning, so `a = 256; b = 256; a is b` is `True`, but `a = 257; b = 257; a is b` may be `False`! Always use `==` for values and `is` for singletons (`None`, `True`, `False`).
2. **"Why should you not use `del` as a destructor in `__del__`?"**
   - `__del__` execution is not guaranteed during interpreter shutdown and can mask exceptions or cause circular GC deadlocks. Use context managers (`with`) for deterministic cleanup instead.
3. **"What happens if you mutate a list while iterating over it?"**
   - The iterator maintains an index offset. Modifying items causes skipped items or infinite loops. Always iterate over a shallow copy (`for item in items[:]:`) or build a new list using a list comprehension.

---

## 10. High-Probability Interview Questions & Model Answers

### Q1: What is the difference between shallow copy and deep copy?
**Answer:**
- A **shallow copy** (`copy.copy(x)` or `list.copy()`) creates a new container object, but populates it with references to the original nested objects. Modifying nested mutable objects inside the copy alters the original.
- A **deep copy** (`copy.deepcopy(x)`) recursively creates new copies of all nested child objects, producing an independent clone with no shared mutable references.

### Q2: How does a closure work in Python, and how do you modify an outer variable?
**Answer:**
A closure is an inner function that retains access to variables from its enclosing lexical scope even after the outer function has completed execution. To rebind an outer variable (not global), you must use the `nonlocal` keyword:
```python
def make_counter():
    count = 0
    def counter():
        nonlocal count
        count += 1
        return count
    return counter
```

### Q3: How would you debug a memory leak in a long-running FastAPI/Python service?
**Answer:**
1. Check for **global state accumulation** (e.g. unbounded lists/dicts acting as naive in-memory caches).
2. Inspect circular references holding uncollected objects via `objgraph` or the built-in `tracemalloc` module to take snapshots before and after high-load endpoints.
3. Inspect `gc.garbage` to identify unreachable cyclical objects with broken destructors.
4. Profile memory consumption per line using `memory_profiler`.

### Q4: Why is `tuple` immutable, and does that mean all its elements are immutable?
**Answer:**
A tuple itself has a fixed length and its array of memory pointers cannot be altered or reassigned. However, if a tuple contains a mutable object (e.g., `t = ([1, 2], 3)`), the list inside `t[0]` can still be mutated (`t[0].append(4)`). A tuple is only hashable (usable as a dict key or set member) if **all** of its elements are also hashable.

### Q5: How do generator functions handle exception propagation inside `yield`?
**Answer:**
You can inject an exception into a paused generator using `gen.throw(ExceptionType)`. Inside the generator, you wrap the `yield` statement in a `try...except` block to catch and handle or clean up before exiting. You can also cleanly terminate a generator using `gen.close()`, which raises `GeneratorExit` at the suspension point.
