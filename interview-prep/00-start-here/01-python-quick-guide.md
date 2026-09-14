# Python Quick Guide (Start Here)

Written for a React/JS developer who's newer to Python. Every topic: **concept → plain explanation → what you say in an interview → likely follow-up.**

If you know JavaScript well, Python will feel familiar. The syntax is cleaner (no braces, no semicolons, indentation matters) and there's one obvious way to do most things.

---

## 1. Variables and how Python passes them

**Plain explanation:** In Python, a variable is just a name pointing at an object (like a `const` pointing at a value in JS). When you pass a variable to a function, you pass the pointer. If the object is *mutable* (list, dict, set) and you change it inside the function, the caller sees the change. If it's *immutable* (int, str, tuple, bool), you can't change it in place, so the caller is unaffected.

```python
def change(num, items):
    num += 10          # int is immutable -> makes a new number, original untouched
    items.append(100)  # list is mutable -> caller's list changes too

n = 5
lst = [1, 2]
change(n, lst)
print(n)    # 5
print(lst)  # [1, 2, 100]
```

**Interview answer:** "Python passes references by value. Whether the caller sees a change depends on whether the object is mutable. Lists and dicts are mutable, so in-place changes are visible. Numbers, strings, and tuples are immutable, so reassigning them just makes a new object."

**Follow-up:** *"Mutable vs immutable types?"* → Mutable: `list`, `dict`, `set`. Immutable: `int`, `float`, `str`, `tuple`, `bool`, `frozenset`.

---

## 2. The classic mutable-default-argument bug

**Plain explanation:** A default value like `def f(x=[])` is created **once** when the function is defined, not each time it runs. So the same list gets reused across calls. This is a very common interview trap.

```python
# Buggy
def add(item, bucket=[]):
    bucket.append(item)
    return bucket

add("a")  # ['a']
add("b")  # ['a', 'b']  <- surprise!

# Fix: use None as a sentinel
def add(item, bucket=None):
    if bucket is None:
        bucket = []
    bucket.append(item)
    return bucket
```

**Interview answer:** "Default arguments are evaluated once at definition time. If the default is mutable, it's shared across calls. The fix is to default to `None` and create a fresh object inside the function."

---

## 3. Lists, dicts, sets, tuples (the JS translation)

| Python | JS equivalent | Note |
|---|---|---|
| `list` `[1,2]` | `Array` | ordered, mutable |
| `dict` `{"a":1}` | `Object` / `Map` | key-value, mutable |
| `set` `{1,2}` | `Set` | unique items |
| `tuple` `(1,2)` | frozen array | ordered, immutable |

**Comprehensions** are Python's version of `.map()`/`.filter()`:

```python
nums = [1, 2, 3, 4]
squares = [n*n for n in nums]              # like nums.map(n => n*n)
evens   = [n for n in nums if n % 2 == 0]  # like nums.filter(...)
lookup  = {n: n*n for n in nums}           # dict comprehension
```

---

## 4. Generators (lazy sequences)

**Plain explanation:** A normal function returns once. A generator uses `yield` to produce values one at a time, only when asked. Great for large data because you don't hold everything in memory at once. Think of it like a lazy iterator / a stream.

```python
def read_lines(n):
    for i in range(n):
        yield f"line {i}"   # produced on demand

for line in read_lines(3):
    print(line)
```

**Interview answer:** "A generator produces values lazily with `yield`, keeping constant memory. I'd use one when streaming or processing large datasets so I don't load everything into memory."

---

## 5. Decorators

**Plain explanation:** A decorator is a function that wraps another function to add behavior — like a higher-order component (HOC) in React, but for functions. `@decorator` on top of a function is just `func = decorator(func)`.

```python
import functools, time

def timed(func):
    @functools.wraps(func)          # keeps the original name/docs
    def wrapper(*args, **kwargs):
        start = time.perf_counter()
        result = func(*args, **kwargs)
        print(f"{func.__name__} took {time.perf_counter()-start:.3f}s")
        return result
    return wrapper

@timed
def work():
    time.sleep(0.1)
```

**Interview answer:** "A decorator wraps a function to add cross-cutting behavior like logging, timing, or auth, without changing the function itself. FastAPI uses them heavily for routing."

**Follow-up:** *"Why `functools.wraps`?"* → Without it, the wrapped function loses its real name and docstring, which breaks debugging and tools that inspect it.

---

## 6. The GIL (Global Interpreter Lock)

**Plain explanation:** CPython lets only one thread run Python code at a time. So threads don't speed up CPU-heavy work. But for I/O work (network calls, DB, files), the lock is released while waiting, so threads and async DO help.

**Which tool for which job:**
- **I/O-bound** (API calls, DB queries): use `async`/`await` or threads.
- **CPU-bound** (heavy math, image processing): use `multiprocessing` (separate processes), or libraries like NumPy that run in C.

**Interview answer:** "The GIL means only one thread executes Python bytecode at a time, so multithreading doesn't help CPU-bound work — I'd use multiprocessing for that. But for I/O-bound work the GIL is released while waiting, so async or threads give real concurrency. FastAPI is I/O-bound, so async fits well."

---

## 7. `is` vs `==`

- `==` compares **values** (like `===` on values in JS).
- `is` compares **identity** (same object in memory).
- Use `is` only for `None`, `True`, `False`: `if x is None:`.

---

## 8. Memory & garbage collection (light version)

**Plain explanation:** Python frees an object as soon as nothing points to it (reference counting). A separate garbage collector cleans up cycles (A points to B, B points to A). You rarely manage this by hand.

**Interview answer:** "Python uses reference counting for immediate cleanup, plus a cycle collector for reference cycles. In a long-running service, leaks usually come from unbounded caches or global lists that keep growing — not the GC itself."

---

## Quick self-test
1. Why does a mutable default argument cause bugs, and how do you fix it?
2. When would you use a generator instead of a list?
3. Does multithreading speed up CPU-bound Python code? Why or why not?
4. When do you use `is` vs `==`?

Want more depth on any of these? See [`../01-python-core/01-python-fundamentals.md`](../01-python-core/01-python-fundamentals.md).
