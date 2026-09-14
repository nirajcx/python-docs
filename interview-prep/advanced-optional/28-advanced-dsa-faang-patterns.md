# Advanced DSA Patterns: FAANG & Tier-1 Coding Interview Master Handbook

> **Target Audience:** FAANG / Tier-1 MNC Coding Rounds (Senior / Staff Level)  
> **Patterns Covered:** Binary Search on Answer, Monotonic Stack, Trie, Union-Find (DSU), Topological Sort, Dynamic Programming, Intervals  
> **Cross-References:** [12-dsa-essentials.md](../04-system-design-dsa/12-dsa-essentials.md)

---

## 1. Pattern 1: Binary Search on Answer Space

When a problem asks for the **minimum or maximum value** that satisfies a condition, and the feasibility function is **monotonic** (if $x$ is valid, all values $> x$ are also valid).

### Template Problem: Capacity to Ship Packages Within $D$ Days
```python
def ship_within_days(weights: list[int], days: int) -> int:
    """
    Finds the minimum ship capacity to ship all packages within 'days'.
    Search space: [max(weights), sum(weights)]
    Time Complexity: O(N * log(sum - max)), Space Complexity: O(1)
    """
    def can_ship_with_capacity(cap: int) -> bool:
        days_needed = 1
        current_load = 0
        for w in weights:
            if current_load + w > cap:
                days_needed += 1
                current_load = 0
            current_load += w
        return days_needed <= days

    left = max(weights)
    right = sum(weights)
    ans = right

    while left <= right:
        mid = (left + right) // 2
        if can_ship_with_capacity(mid):
            ans = mid
            right = mid - 1  # Try to find a smaller valid capacity
        else:
            left = mid + 1   # Capacity too small, increase

    return ans
```

---

## 2. Pattern 2: Monotonic Stack

Used when you need to find the **Next Greater Element**, **Previous Greater Element**, or calculate spanning boundaries in $O(N)$ time.

### Template Problem: Daily Temperatures
```python
def daily_temperatures(temperatures: list[int]) -> list[int]:
    """
    Returns array where ans[i] is number of days to wait for a warmer temp.
    Monotonic Decreasing Stack stores: indices of unresolved cooler days.
    Time Complexity: O(N), Space Complexity: O(N)
    """
    n = len(temperatures)
    ans = [0] * n
    stack: list[int] = []  # Stores indices

    for i, temp in enumerate(temperatures):
        # If current temp is warmer than stack top, resolve top!
        while stack and temperatures[stack[-1]] < temp:
            prev_index = stack.pop()
            ans[prev_index] = i - prev_index
        stack.append(i)

    return ans
```

---

## 3. Pattern 3: Trie (Prefix Tree)

Essential for autocomplete systems, spell checkers, and IP routing prefix lookups.

```python
class TrieNode:
    def __init__(self):
        self.children: dict[str, "TrieNode"] = {}
        self.is_terminal: bool = False

class Trie:
    def __init__(self):
        self.root = TrieNode()

    def insert(self, word: str) -> None:
        curr = self.root
        for char in word:
            if char not in curr.children:
                curr.children[char] = TrieNode()
            curr = curr.children[char]
        curr.is_terminal = True

    def starts_with(self, prefix: str) -> bool:
        """Checks if there is any word in the trie that starts with prefix."""
        curr = self.root
        for char in prefix:
            if char not in curr.children:
                return False
            curr = curr.children[char]
        return True
```

---

## 4. Pattern 4: Union-Find (Disjoint Set Union - DSU) with Path Compression & Rank

Used for graph connectivity, dynamic network partitioning, and Kruskal's Minimum Spanning Tree.

```python
class UnionFind:
    def __init__(self, n: int):
        self.parent = list(range(n))
        self.rank = [1] * n
        self.num_components = n

    def find(self, x: int) -> int:
        """Finds root with Path Compression: O(alpha(N)) ~ O(1) amortized."""
        if self.parent[x] != x:
            self.parent[x] = self.find(self.parent[x])  # Flattens tree
        return self.parent[x]

    def union(self, x: int, y: int) -> bool:
        """Unions two sets by rank. Returns False if already in same set (cycle!)."""
        root_x = self.find(x)
        root_y = self.find(y)

        if root_x == root_y:
            return False  # Already connected -> Cycle detected!

        # Attach smaller rank tree under higher rank tree
        if self.rank[root_x] < self.rank[root_y]:
            self.parent[root_x] = root_y
        elif self.rank[root_x] > self.rank[root_y]:
            self.parent[root_y] = root_x
        else:
            self.parent[root_y] = root_x
            self.rank[root_x] += 1

        self.num_components -= 1
        return True
```

---

## 5. Pattern 5: Topological Sort (Kahn's In-Degree Algorithm)

Used for resolving build systems, dependency resolution, and task workflow scheduling.

```python
from collections import deque

def find_task_order(num_tasks: int, prerequisites: list[list[int]]) -> list[int]:
    """
    Kahn's Algorithm:
    Time Complexity: O(V + E), Space Complexity: O(V + E)
    """
    adj = {i: [] for i in range(num_tasks)}
    in_degree = [0] * num_tasks

    for dest, src in prerequisites:
        adj[src].append(dest)
        in_degree[dest] += 1

    # Queue holds all nodes with zero dependencies
    queue = deque([i for i in range(num_tasks) if in_degree[i] == 0])
    order = []

    while queue:
        node = queue.popleft()
        order.append(node)

        for neighbor in adj[node]:
            in_degree[neighbor] -= 1
            if in_degree[neighbor] == 0:
                queue.append(neighbor)

    # If order does not include all tasks, a cycle exists!
    return order if len(order) == num_tasks else []
```

---

## 6. Pattern 6: Dynamic Programming (0/1 Knapsack & Coin Change)

```python
def coin_change(coins: list[int], amount: int) -> int:
    """
    Finds minimum coins needed to make up 'amount'.
    dp[i] = min coins to make amount i.
    Time Complexity: O(amount * len(coins)), Space Complexity: O(amount)
    """
    dp = [float('inf')] * (amount + 1)
    dp[0] = 0

    for i in range(1, amount + 1):
        for coin in coins:
            if i - coin >= 0:
                dp[i] = min(dp[i], dp[i - coin] + 1)

    return int(dp[amount]) if dp[amount] != float('inf') else -1
```

---

## 7. Pattern 7: Interval Merging

```python
def merge_intervals(intervals: list[list[int]]) -> list[list[int]]:
    """
    Merges all overlapping intervals.
    Time Complexity: O(N log N) due to sorting, Space Complexity: O(N)
    """
    intervals.sort(key=lambda x: x[0])
    merged: list[list[int]] = []

    for interval in intervals:
        if not merged or merged[-1][1] < interval[0]:
            merged.append(interval)
        else:
            merged[-1][1] = max(merged[-1][1], interval[1])

    return merged
```
