# Interview Questions Bank: MNC Tier-1 Tech Deep Dive (Databases, AI & Systems)

> **Target Audience:** Tier-1 MNCs, FAANG, AI Unicorns, Enterprise Fintech  
> **Evaluation Bar:** Senior / Staff Level (Precision, engine internals, mathematical trade-offs, zero hand-waving)  
> **Cross-References:** [20-advanced-database-engineering-and-migrations.md](../07-database-design/20-advanced-database-engineering-and-migrations.md) | [10-llm-integration.md](../03-rag-vector-genai/10-llm-integration.md) | [19-high-scale-traffic-and-fintech.md](../04-system-design-dsa/19-high-scale-traffic-and-fintech.md)

---

### Q1: In Prompt Engineering and LLM Systems, how does Grammar-Constrained Decoding guarantee valid JSON outputs, and what is its computational trade-off compared to prompt-based instruction?
#### Staff/MNC Model Answer:
"1. **Mechanism**:
   Traditional approaches instruct the model via prompt text (`'Return valid JSON matching this schema'`) and parse the resulting completion using Pydantic. If the model hallucinates a missing brace or invalid type, validation fails, requiring retry loops that increase cost and latency.  
   **Grammar-Constrained Decoding** (used in OpenAI Structured Outputs, llama.cpp, and vLLM via Outlines) enforces constraints at the **token sampling layer**:
   - The Pydantic schema is compiled into a **Deterministic Finite Automaton (DFA)** or Context-Free Grammar (CFG).
   - At each generation step $t$, the inference engine evaluates the valid transitions from the current DFA state.
   - Any vocabulary token that would violate the grammar syntax is masked out by setting its logit to $-\infty$ before applying softmax.
2. **Trade-offs**:
   - *Advantage:* 100% mathematical guarantee of valid JSON structure matching the schema; eliminates retry overhead and schema parsing errors.
   - *Overhead:* Pre-compiling complex schemas into DFAs incurs slight upfront compile latency. In high-concurrency serving, maintaining dynamic DFA state transitions per beam/stream slightly increases CPU compute on the inference server."

---

### Q2: Walk me through reading a slow query's `EXPLAIN (ANALYZE, BUFFERS)` output. How do you distinguish whether the bottleneck is disk I/O, CPU sorting, or a sub-optimal join strategy?
#### Staff/MNC Model Answer:
"When profiling with `EXPLAIN (ANALYZE, BUFFERS)`:
1. **Disk I/O vs. Memory Cache Bottleneck**:
   - Inspect the `Buffers:` line.
   - `shared hit`: Number of 8KB disk pages found directly in PostgreSQL's `shared_buffers` in RAM.
   - `shared read`: Number of pages read physically from NVMe/SSD storage.
   - If `read` is high and execution time is dominated by that node, the bottleneck is disk I/O latency. Solution: increase `shared_buffers`, add covering indexes to reduce heap access, or pre-warm caches with `pg_prewarm`.
2. **CPU Sorting Bottleneck**:
   - Look for `Sort Method: external merge Disk: xxxkB` vs. `Sort Method: quicksort Memory: xxxkB`.
   - If sort spills to disk (`external merge`), `work_mem` is insufficient, causing slow disk writes. Increase `work_mem` for that session.
3. **Sub-optimal Join Strategy**:
   - **Nested Loop Join on Large Tables**: If the planner estimates 10 rows (`rows=10`) but actual loops find 100,000 rows (`actual rows=100000`), the planner incorrectly chose a Nested Loop instead of a Hash Join due to **stale planner statistics**. Fix: run `ANALYZE table_name;` to update catalog statistics in `pg_statistic`."

---

### Q3: How do you migrate a 100-million-row PostgreSQL table to add a new column, backfill historical data, and create an index with zero downtime and zero replication lag?
#### Staff/MNC Model Answer:
"At 100M rows, a naive migration locks the table, causes connection timeouts, and inflates WAL replication lag:
1. **Schema Expansion (Release 1)**:
   - Add column as **nullable** (`ALTER TABLE orders ADD COLUMN fulfillment_status VARCHAR(32);`). In PostgreSQL 11+, adding a nullable column or a column with a constant default updates only catalog metadata in $< 1\text{ms}$ with zero table rewrites.
   - Deploy code that **dual-writes** to both the old and new columns.
2. **Index Creation (Asynchronous)**:
   - Execute outside a transaction: `CREATE INDEX CONCURRENTLY idx_orders_fulfillment ON orders (fulfillment_status);`. This performs two table scans without taking an exclusive `SHARE UPDATE EXCLUSIVE` write lock.
3. **Chunked Backfill Script**:
   - Run an offline Python backfill script utilizing **keyset pagination** (`WHERE id > last_seen_id ORDER BY id ASC LIMIT 2000`).
   - Execute in independent transactions with a 100ms pause between batches to allow read replica WAL streams to drain without lag.
   - Implement checkpointing in a separate metadata table to resume seamlessly if the script is interrupted.
4. **Switch & Contract (Release 2 & 3)**:
   - Switch application reads and writes to the new column.
   - Drop the old column in a subsequent release after confirming stability."

---

### Q4: How does the CPython memory management hierarchy operate, and why can memory usage remain high in OS metrics even after objects are deleted?
#### Staff/MNC Model Answer:
"CPython manages memory in three distinct layers:
1. **Layer 1 (OS Allocator)**: `malloc()` / `free()` interfacing with the OS virtual memory manager.
2. **Layer 2 (PyMalloc)**: Dedicated small-object allocator for allocations $\le 512$ bytes (strings, ints, tuples):
   - **Arenas**: 256KB chunks requested from OS.
   - **Pools**: 4KB pages within an arena.
   - **Blocks**: Fixed-size memory units (e.g. 8, 16, 32 bytes) within a pool.
3. **Layer 3 (Object Allocator)**: Type-specific allocators.  
*Why OS Memory Does Not Decrease After `del`:*  
An entire 256KB Arena can only be released back to the operating system if **every single 4KB pool within that arena is completely free**. If even one tiny 16-byte object remains referenced inside one pool of that arena, the entire 256KB virtual memory page remains held by the CPython process. While Python marks the internal blocks as free for future Python allocations, the host OS reports high resident set size (RSS)."

---

### Q5: In an enterprise RAG architecture, how do you mathematically size the GPU VRAM requirements for self-hosting an open-weights model using vLLM?
#### Staff/MNC Model Answer:
"Total VRAM sizing consists of two primary components: **Model Weight Footprint** and **KV Cache Capacity**:
$$\text{Total VRAM} = \text{Model Weights (GB)} + \text{KV Cache (GB)} + \text{Activation/CUDA Overhead (GB)}$$

1. **Model Weight Calculation**:
   $$\text{Weight Memory (GB)} = \frac{\text{Parameters (Billions)} \times \text{Bytes Per Weight}}{\text{Quantization Factor}}$$
   - A 70-Billion parameter model in 16-bit float (`fp16` = 2 bytes): $70 \times 2 = 140\text{ GB}$.
   - Quantized to 4-bit (`int4` via AWQ/GPTQ = 0.5 bytes): $70 \times 0.5 = 35\text{ GB}$.
2. **KV Cache Calculation (Per Token Per Layer)**:
   $$\text{KV Size per Token (Bytes)} = 2 \times (\text{Layers}) \times (\text{Hidden Dim}) \times (\text{Bytes per Float})$$
   - Across a batch of $B$ concurrent requests with context length $L$:
   $$\text{KV Cache Total} = B \times L \times \text{KV Size per Token}$$
   For a 70B model with context length 8,192 tokens and 64 concurrent requests, the KV cache alone requires $\approx 42\text{ GB}$ of RAM!
3. **Hardware Recommendation**:
   A single 80GB NVIDIA A100/H100 can run a 70B model in 4-bit AWQ ($35\text{GB weights} + 35\text{GB KV cache} + 5\text{GB activations} \approx 75\text{GB}$). For un-quantized `fp16`, it requires two 80GB A100s paired via NVLink with Tensor Parallelism (`tp=2`)."

---

### Q6: How do you prevent the Lost Update anomaly in PostgreSQL when multiple API instances update a shared resource concurrently?
#### Staff/MNC Model Answer:
"In high-concurrency environments (e.g. inventory decrements, account balances):
1. **Atomic SQL Expressions (Best for simple increments/decrements)**:
   ```sql
   UPDATE inventory 
   SET stock = stock - 1 
   WHERE item_id = :id AND stock >= 1;
   ```
   PostgreSQL acquires an exclusive row-level write lock during evaluation. If two transactions execute simultaneously, the second transaction waits, then re-evaluates the `WHERE stock >= 1` clause against the newly committed value, preventing negative stock with zero locking overhead.
2. **Pessimistic Locking (`SELECT ... FOR UPDATE`)**:
   When balance updates require complex multi-table validation in Python before writing:
   ```python
   stmt = select(Account).where(Account.id == acc_id).with_for_update()
   account = (await session.scalars(stmt)).one()
   # Row is exclusively locked; other concurrent readers/writers must wait
   account.balance -= amount
   ```
3. **Optimistic Concurrency Control (OCC)**:
   Add a `version` column. Compare and increment on update (`WHERE version = :current_version`). If 0 rows are updated, raise a concurrency exception and retry."
