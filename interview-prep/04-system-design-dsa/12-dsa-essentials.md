# DSA Essentials: High-Frequency Patterns for Python & AI Backend Interviews

Target Role: Python/FastAPI Backend & GenAI Engineer  
Cross-References: [01-python-fundamentals.md](../01-python-core/01-python-fundamentals.md) | [08-vector-databases.md](../03-rag-vector-genai/08-vector-databases.md) | [11-system-design-basics.md](./11-system-design-basics.md)

---

## 1. Complexity & Python Built-in Performance

In backend and AI interviews, coding problems test your ability to choose optimal data structures and write clean, idiomatic Python.

| Python Data Structure | Operation | Average Complexity | Worst Case | Critical Interview Note |
|---|---|---|---|---|
| `list` | `append()`, `pop()` (end) | $O(1)$ | $O(1)$ amortized | Dynamic array resizing ($1.125\times$ growth). |
| `list` | `insert(0, x)`, `pop(0)` | **$O(N)$** | **$O(N)$** | **NEVER use `list` as a Queue!** Shifts all $N$ elements. |
| `collections.deque` | `append()`, `popleft()` | **$O(1)$** | **$O(1)$** | **Always use `deque` for FIFO queues / sliding windows.** |
| `dict` / `set` | `in`, get, set, delete | $O(1)$ | $O(N)$ (hash collision)| Open addressing with quadratic probing. |
| `heapq` | `heappush()`, `heappop()` | **$O(\log K)$** | **$O(\log K)$** | Binary min-heap; essential for Top-$K$ candidate ranking. |

---

## 2. Pattern 1: Hashmaps & Frequency Counters

The most frequently tested pattern in backend coding interviews (used for grouping, caching, deduplication, and $O(1)$ lookups).

### Example 1: Group Anagrams
*Problem:* Given an array of strings, group the anagrams together.
```python
from collections import defaultdict

def group_anagrams(strs: list[str]) -> list[list[str]]:
    # Map sorted tuple of characters -> list of matching words
    anagram_map: defaultdict[tuple, list[str]] = defaultdict(list)
    
    for word in strs:
        # Tuple of sorted chars is immutable and therefore hashable as dict key
        key = tuple(sorted(word))
        anagram_map[key].append(word)
        
    return list(anagram_map.values())

# Complexity: O(N * K log K) where N = len(strs), K = max word length
```

### Example 2: In-Memory LRU Cache with `OrderedDict`
Interviewers love asking how to implement an LRU cache (found in Redis, LangChain token caches, and FastAPI).
```python
from collections import OrderedDict

class LRUCache:
    def __init__(self, capacity: int):
        self.capacity = capacity
        self.cache: OrderedDict[str, str] = OrderedDict()

    def get(self, key: str) -> str | None:
        if key not in self.cache:
            return None
        # Move accessed key to the end (most recently used)
        self.cache.move_to_end(key)
        return self.cache[key]

    def put(self, key: str, value: str) -> None:
        if key in self.cache:
            self.cache.move_to_end(key)
        self.cache[key] = value
        if len(self.cache) > self.capacity:
            # Pop first item (least recently used)
            self.cache.popitem(last=False)
```

---

## 3. Pattern 2: Two Pointers (Converging & Fast/Slow)

Ideal for sorted arrays, strings, and linked list traversal with $O(1)$ auxiliary space.

### Example 1: Two Sum II (Sorted Array)
```python
def two_sum_sorted(numbers: list[int], target: int) -> list[int]:
    """Finds two numbers that sum to target in an already sorted list."""
    left = 0
    right = len(numbers) - 1
    
    while left < right:
        current_sum = numbers[left] + numbers[right]
        if current_sum == target:
            return [left, right]
        elif current_sum < target:
            left += 1  # Need a larger number
        else:
            right -= 1 # Need a smaller number
            
    return []
# Time Complexity: O(N), Space Complexity: O(1)
```

---

## 4. Pattern 3: Sliding Window

Used for sub-array or sub-string problems where you maintain an active state over a contiguous window.

### Example: Longest Substring Without Repeating Characters
```python
def length_of_longest_substring(s: str) -> int:
    char_index_map: dict[str, int] = {}
    max_len = 0
    left = 0
    
    for right, char in enumerate(s):
        # If character is already in window, shrink left boundary past previous occurrence
        if char in char_index_map and char_index_map[char] >= left:
            left = char_index_map[char] + 1
            
        char_index_map[char] = right
        max_len = max(max_len, right - left + 1)
        
    return max_len
# Time Complexity: O(N), Space Complexity: O(min(N, AlphabetSize))
```

---

## 5. Pattern 4: Top-$K$ Elements using Heaps (`heapq`)

Essential for AI systems: finding the top-$K$ highest scoring document chunks without sorting the entire multi-million candidate list.

```python
import heapq

def find_top_k_chunks(chunks: list[dict], k: int) -> list[dict]:
    """
    Finds top-K highest scoring chunks.
    Maintains a min-heap of size K:
    - If candidate score > min-heap root, evict root and push candidate.
    """
    # Min-heap stores tuples of (score, chunk_id, chunk)
    min_heap: list[tuple[float, str, dict]] = []
    
    for chunk in chunks:
        score = chunk["score"]
        item = (score, chunk["id"], chunk)
        
        if len(min_heap) < k:
            heapq.heappush(min_heap, item)
        else:
            if score > min_heap[0][0]:
                heapq.heappushpop(min_heap, item)
                
    # Extract and sort descending
    return [item[2] for item in sorted(min_heap, key=lambda x: x[0], reverse=True)]

# Complexity: O(N log K) vs Full Sort O(N log N)
# When N = 1,000,000 and K = 10, O(N log K) is 20x faster than full sorting!
```

---

## 6. Pattern 5: Recursion & Tree Traversal (DFS/BFS)

Used heavily in document hierarchy parsing (navigating ASTs, nested JSON schemas, or DOM trees in HTML scrapers).

```python
# Flattening Nested JSON Schemas or Document Sections
def traverse_document_tree(node: dict, breadcrumbs: list[str] = []) -> list[dict]:
    """Recursively traverses document sections and flattens into chunks."""
    results = []
    current_path = breadcrumbs + [node.get("title", "Section")]
    
    # If leaf node with content
    if "content" in node and node["content"]:
        results.append({
            "path": " > ".join(current_path),
            "content": node["content"]
        })
        
    # Recursively traverse children
    for child in node.get("subsections", []):
        results.extend(traverse_document_tree(child, current_path))
        
    return results
```

---

## 7. Gotchas & Follow-Up Questions Interviewers Ask

1. **"Why should you never use `list.pop(0)` to process items in a queue?"**
   - In Python, `list` is a contiguous dynamic array of pointers. Calling `pop(0)` removes the first element and shifts all remaining $N-1$ elements left in memory, making a queue loop $O(N^2)$ total runtime! Always use `collections.deque.popleft()`, which runs in guaranteed $O(1)$ time via a doubly-linked block list.
2. **"Can a list be used as a dictionary key in Python?"**
   - No. Dictionary keys must be **hashable** (implement `__hash__` and `__eq__` and remain immutable during their lifetime). Lists are mutable, so Python raises `TypeError: unhashable type: 'list'`. Convert the list to an immutable `tuple` first (`tuple(my_list)`).
3. **"What is the time complexity of slicing a list `a[start:end]`?"**
   - Slicing creates a brand-new list and shallow-copies references to the sliced elements. The time complexity is $O(K)$, where $K$ is the length of the slice (`end - start`), not $O(1)$.

---

## 8. High-Probability Interview Questions & Model Answers

### Q1: How do you detect a cycle in a linked list or document graph?
**Answer:**
Use **Floyd's Cycle-Finding Algorithm (Fast and Slow Pointers)**:
- Initialize two pointers (`slow` and `fast`) at the head.
- Advance `slow` by 1 step and `fast` by 2 steps at each iteration.
- If there is a cycle, the `fast` pointer will eventually lap and meet the `slow` pointer ($O(N)$ time, $O(1)$ auxiliary memory). If `fast` reaches `None`, the list is acyclic.

### Q2: What is the difference between BFS (Breadth-First Search) and DFS (Depth-First Search)?
**Answer:**
- **BFS (Breadth-First Search)** explores all neighbors at the current depth before moving to the next level. Implemented iteratively using a **Queue (`collections.deque`)**. Best for finding the **shortest path** or closest nodes.
- **DFS (Depth-First Search)** explores as deep as possible along each branch before backtracking. Implemented recursively (call stack) or iteratively using a **Stack (`list`)**. Best for topological sorting, cycle detection, and exhaustive path enumeration.

### Q3: How does Python's built-in `Timsort` work?
**Answer:**
Python's `sorted()` and `list.sort()` use **Timsort** (a hybrid sorting algorithm combining Merge Sort and Insertion Sort).  
It identifies naturally occurring ordered sequences in real-world data ("runs") and sorts short chunks using Insertion Sort ($O(1)$ overhead). It then merges runs using Merge Sort.
- Best Case: $O(N)$ (already sorted).
- Worst Case: $O(N \log N)$.
- Space Complexity: $O(N)$ (requires temporary buffer for merging runs).

### Q4: How would you design a rate limiter using the Sliding Window Log algorithm?
**Answer:**
Use Redis **Sorted Sets (`ZSET`)**:
1. When a request arrives from `user_id`, remove all elements from the user's sorted set older than `(current_timestamp - window_size)` using `ZREMRANGEBYSCORE`.
2. Count remaining elements in the set with `ZCARD`.
3. If count exceeds allowed limit, reject request with HTTP 429.
4. If allowed, add current timestamp to the set (`ZADD`) with member ID = `UUID` and score = `current_timestamp`, set TTL on the key, and proceed.  
*Guarantees exact window enforcement without edge-boundary burst leaks.*

### Q5: How do you find the median of a streaming data flow of embedding similarity scores?
**Answer:**
Use the **Two-Heap Pattern**:
- Maintain two heaps: a **Max-Heap** for the lower half of numbers and a **Min-Heap** for the upper half.
- Balance heaps so their sizes differ by at most 1:
  - If total elements is odd, median is the root of the larger heap.
  - If even, median is the average of the roots of both heaps.
- Insertion takes $O(\log N)$ time, and retrieving the median takes $O(1)$ time.
