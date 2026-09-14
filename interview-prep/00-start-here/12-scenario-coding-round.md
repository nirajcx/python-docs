# Scenarios & Coding-Round Practice (Start Here)

Real prompts that come up in interviews for your level, with solutions and — just as important — **what to say while you solve them**. Practice narrating your thinking; interviewers score how you reason, not just the final code.

---

## Part A: React practical prompts

### 1. "Build a search input that doesn't fire a request on every keystroke"

**What they're testing:** debouncing, `useEffect` cleanup.

```tsx
function Search({ onSearch }: { onSearch: (q: string) => void }) {
  const [query, setQuery] = useState("");

  useEffect(() => {
    const timer = setTimeout(() => onSearch(query), 300); // wait for a pause
    return () => clearTimeout(timer);                       // cancel on next keystroke
  }, [query, onSearch]);

  return <input value={query} onChange={(e) => setQuery(e.target.value)} />;
}
```

**Say this:** "I debounce by scheduling the search after 300ms and clearing the timer on each new keystroke via the effect cleanup, so it only fires once the user pauses."

---

### 2. "This component re-renders too much / on every parent render. Fix it."

**What they're testing:** `React.memo`, `useCallback`, stable references.

**Say this:** "First I'd confirm the cause — usually the parent passes a new object or function reference every render, breaking the child's shallow comparison. I'd wrap the child in `React.memo`, memoize callbacks with `useCallback`, and memoize expensive derived values with `useMemo`. But I'd only add these where there's a real cost, not everywhere."

---

### 3. "Fetch and display a list, with loading and error states"

**What they're testing:** async handling, UI states. (Bonus: mention TanStack Query.)

```tsx
function Users() {
  const [users, setUsers] = useState<User[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    fetch("/api/users")
      .then((r) => { if (!r.ok) throw new Error("Failed"); return r.json(); })
      .then((data) => { if (active) setUsers(data); })
      .catch((e) => { if (active) setError(e.message); })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; }; // avoid setting state after unmount
  }, []);

  if (loading) return <p>Loading…</p>;
  if (error) return <p>Error: {error}</p>;
  return <ul>{users.map((u) => <li key={u.id}>{u.name}</li>)}</ul>;
}
```

**Say this:** "I handle three states — loading, error, success — and guard against setting state after unmount. In a real app I'd use TanStack Query so caching, refetch, and these states come for free."

---

### 4. "Why shouldn't you use the array index as a key?"

**Say this:** "Keys help React match items between renders. If the list can reorder, insert, or delete, index keys make React associate the wrong DOM nodes with the wrong data — causing bugs in inputs and animations. I use a stable unique id."

---

## Part B: Python / FastAPI practical prompts

### 5. "Write an endpoint that creates a user with validation"

```python
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, EmailStr, Field

app = FastAPI()

class CreateUser(BaseModel):
    name: str = Field(min_length=1)
    email: EmailStr
    age: int = Field(ge=0)

@app.post("/users", status_code=201)
async def create_user(user: CreateUser):
    # imagine saving to DB here
    return {"id": 1, "name": user.name}
```

**Say this:** "Pydantic validates the body automatically — invalid input returns a 422 before my code runs. I return 201 for a successful create."

---

### 6. "This endpoint is slow. How do you investigate?"

**Say this:** "I'd first find where the time goes — is it the database, an external API, or computation? For the DB I'd check the query with `EXPLAIN`, look for a missing index or an N+1 pattern where we query in a loop. Common fixes: add an index, batch the queries with a join or eager loading, or cache the result in Redis if it's read-often and changes rarely."

---

### 7. "Fix the N+1 query"

```python
# Problem: 1 query for users, then 1 per user for orders
users = await get_users()
for u in users:
    u.orders = await get_orders(u.id)   # N extra queries

# Fix: load related data in one go (SQLAlchemy eager loading)
from sqlalchemy.orm import selectinload
users = await session.scalars(
    select(User).options(selectinload(User.orders))
)
```

**Say this:** "N+1 is querying once per item in a loop. I fix it with eager loading or a join so it's one or two queries total."

---

## Part C: Easy-to-medium DSA (Python)

These are the level you'll actually see. Narrate your approach and complexity.

### 8. Two Sum
```python
def two_sum(nums, target):
    seen = {}                       # value -> index
    for i, n in enumerate(nums):
        if target - n in seen:
            return [seen[target - n], i]
        seen[n] = i
    return []
```
**Say this:** "A hashmap of values I've seen lets me check the complement in O(1), so it's O(n) time instead of the O(n²) brute force."

### 9. Reverse a string / check a palindrome
```python
def is_palindrome(s: str) -> bool:
    cleaned = [c.lower() for c in s if c.isalnum()]
    return cleaned == cleaned[::-1]
```

### 10. Find duplicates
```python
def has_duplicate(nums) -> bool:
    return len(set(nums)) != len(nums)   # a set drops duplicates
```

### 11. Count word frequency
```python
from collections import Counter
def word_count(text: str):
    return Counter(text.lower().split())
```

### 12. FizzBuzz (they still ask it)
```python
for i in range(1, 16):
    if i % 15 == 0: print("FizzBuzz")
    elif i % 3 == 0: print("Fizz")
    elif i % 5 == 0: print("Buzz")
    else: print(i)
```

**General DSA talking tip:** state the approach first ("I'll use a hashmap to get O(n)"), then code, then mention time/space complexity. That structure alone puts you ahead of most candidates.

---

## Part D: Open-ended discussion prompts

- **"How would you design a simple URL shortener?"** → see [`05-system-design-quick-guide.md`](./05-system-design-quick-guide.md).
- **"How do you secure an API?"** → auth with JWT, validate all input, use HTTPS, rate-limit, never trust the client, hash passwords, keep secrets in env vars.
- **"How do you handle a feature you've never built before?"** → break it down, check docs/existing patterns, build the smallest working version first, iterate. Honesty about learning is fine.
- **"How do you make sure your code works?"** → tests for the logic, manual testing of the happy path and edge cases, and code review.

---

## How to practice
1. Cover the solution, try the prompt yourself, then compare.
2. Say your reasoning **out loud** — that's the actual skill being tested.
3. For DSA, always end with time and space complexity.
