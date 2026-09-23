# Python deeper concepts — language, OOP aur async traps

[Roadmap](../README.md) · [Python fundamentals](../00-start-here/01-python-quick-guide.md)

## 1. Python vs JavaScript transition

Python indentation blocks define karti hai, dynamic typing with optional static annotations. `None` absent value; truthiness empty containers/zero/False ko include karti hai. `and`/`or` operands return kar sakte hain, strictly bool nahi. `is` identity, `==` overloaded value equality; JS strict equality object behavior Python lists se different hai.

Python names scope LEGB: local, enclosing, global, builtins. Assigning name inside function normally local; `global`/`nonlocal` explicit rebinding choose. Function defaults definition-time; closures later binding read kar sakti hain.

```python
funcs = [lambda: n for n in range(3)]
assert [f() for f in funcs] == [2, 2, 2]
fixed = [lambda n=n: n for n in range(3)]
assert [f() for f in fixed] == [0, 1, 2]
```

## 2. args, kwargs, comprehensions, sorting

`*args` extra positional tuple; `**kwargs` keyword dict. `def f(x, /, *, mode)` positional-only x and keyword-only mode. Generator expressions lazy; list comprehension eagerly allocates list. Large comprehension still memory-heavy.

`sorted(items, key=...)` new list; `list.sort()` in-place and returns None. Python sort stable: equal keys relative order preserve. Hashability stable hash/equality contract hai, merely “immutable” synonym nahi. Dict/set collisions mean average O(1), worst-case assumptions discuss when needed. Tuple integer indexing O(1), membership scan O(n).

## 3. OOP: MRO, properties, protocols

`__init__` existing instance initialize karta hai; `__new__` instance create/return hook. `self` ordinary explicit first parameter by convention, instance bound method automatically supply karta hai. Class mutable attributes shared; instance attribute assignment shadow kar sakti hai.

`super()` method resolution order mein next implementation use karta hai; cooperative multiple inheritance compatible signatures needed. Encapsulation Python conventions/properties se, underscore security boundary nahi. Composition service dependency replace karke testing easy banati hai.

`@property` managed attribute syntax; descriptor `__get__`, `__set__`, `__delete__` attribute protocol. Methods/properties descriptor mechanism use karte hain. `__getattribute__` broad lookup, `__getattr__` missing attribute fallback; recursion trap avoid with base implementation.

ABC explicit abstract contract; Protocol structural type-checking contract. Dataclass methods generation, TypedDict dict shape typing (runtime validation nahi), Pydantic validation boundary. `__slots__` instance attribute layout constrain/save memory in some cases, universal leak fix nahi; inheritance/weakrefs matter.

## 4. Decorator factory, exception-safe timing

```python
import functools
import time

def timed(label):
    def decorate(fn):
        @functools.wraps(fn)
        def wrapped(*args, **kwargs):
            start = time.perf_counter()
            try:
                return fn(*args, **kwargs)
            finally:
                print(label, time.perf_counter() - start)
        return wrapped
    return decorate

@timed('sum')
def add(a, b):
    return a + b
```

Decorator factory arguments leta hai, decorator function leta hai, wrapper calls intercept karta hai. Async function ke liye `async def wrapped` and `await fn(...)` required to time execution not just coroutine creation. `wraps` metadata/`__wrapped__` preserve karta hai, wrapper calling convention magically change nahi karta.

Context manager `__enter__/__exit__`; exception suppress tab ho sakti hai when exit truthy return kare. `contextlib` generator context manager exactly one yield. Cleanup best effort Python execution ke andar; process hard kill par finally guarantee nahi.

## 5. Exceptions and resource safety

Specific exception catch, translate at HTTP boundary, traceback/context preserve (`raise ... from exc`). Bare except includes control exceptions; avoid blanket swallowing. Python cancellation `CancelledError` cleanup ke baad re-raise karo. `finally` return pending exception replace/suppress kar sakta hai.

Dependency setup partially fails toh already-created resources cleanup honi chahiye; async context managers/ExitStack helpful. Retrying whole function can duplicate side effects; transaction/provider idempotency align karo.

## 6. Async: scheduling, race, cancellation

Coroutine object create karna execution schedule nahi; await/create_task/TaskGroup needed. `await` completion-ready awaitable par event-loop handoff necessarily nahi. Multiple tasks same process memory share; await between read/write race create kar sakta hai even single event-loop thread.

```python
import asyncio

async def limited_jobs(items, operation):
    semaphore = asyncio.Semaphore(5)
    async def one(item):
        async with semaphore:
            async with asyncio.timeout(2):
                return await operation(item)
    return await asyncio.gather(*(one(item) for item in items))
```

Example active operations limit karta hai, but million-item iterable ke liye still million tasks create ho sakti hain. Bounded producer/consumer queue for huge streams better. Semaphore timeout starts after permit here; total queue+execution deadline chahiye toh placement/design change karo.

`asyncio.Lock` same loop tasks coordinate karta hai, distributed multi-worker stock invariant nahi. DB constraint/transaction required. Thread cancellation external work stop guarantee nahi; timeouts + cooperative cancellation + request result reconciliation design karo.

## 7. GIL, memory and runtime version

Standard GIL-enabled CPython one thread bytecode at a time per interpreter; native libraries may release GIL. Free-threaded builds exist, extension compatibility/runtime build matter. GIL compound business action atomic guarantee nahi. Processes avoid shared GIL but serialization/memory/process-start overhead add.

CPython uses reference counting plus cycle collection, with version/build-specific details (immortal objects/GC generations etc.). `del x` reference remove karta hai, necessarily object destroy nahi. Cache retains instance through key/value, unbounded tasks and native allocations common memory concerns. `lru_cache` default bounded hai; `maxsize=None` unbounded.

Source parse → code objects/bytecode → interpreter execution conceptual model. Opcode names, JIT/GC implementation details versions ke across change hote hain; interviews mein actual runtime clarify rather than outdated exact opcodes memorize.

## 8. Engineering questions

Virtual environment project Python dependencies isolate karta hai, OS/container isolation nahi. Lock/pin reproducible env, config secrets separate, package/module imports avoid circular design. `if __name__ == '__main__'` import side effects avoid/entrypoint define karta hai. Pytest fixtures lifecycle and dependency replacement cleanup; mutable global test state shared leakage avoid.

**Exit drill:** custom context manager, async cancellation reasoning, dataclass vs Pydantic, closure outputs, method binding, composition example and leak hypothesis explain karo.
