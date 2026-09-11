# Interview Questions Bank: SDLC, DevOps & Behavioral Leadership

Target Role: Mid / Senior Python & AI Backend Engineer  
Cross-References: [13-project-talking-points.md](../05-behavioral/13-project-talking-points.md) | [17-sdlc-devops-practices.md](../08-sdlc-engineering/17-sdlc-devops-practices.md)

---

### Q1: Why do modern engineering teams favor Trunk-Based Development over GitFlow?
#### Junior Answer:
"Trunk-based development has fewer branches, so you don't get as many git merge conflicts."
#### Senior In-Depth Answer:
"In **GitFlow**, feature branches live for weeks or months. When multiple developers attempt to merge large, diverged branches into `develop` before a release, they encounter **Merge Hell**, where resolving conflicting lines of code breaks unspoken logic and introduces regressions.  
In **Trunk-Based Development**, all developers merge small, incremental PRs (< 24–48 hours of work) directly into the `main` branch multiple times per day.  
- Incomplete or experimental features are safely merged behind **Feature Flags**.
- Automated CI/CD runs instantly on every commit.
- Feedback loops are tight: if a bug is introduced, it is isolated to a 50-line diff rather than a 5,000-line release branch merge."

---

### Q2: Walk me through how you conduct a Blameless Post-Mortem after a critical production outage.
#### Junior Answer:
"We get on a call, figure out who caused the bug, and tell them how to prevent it next time."
#### Senior In-Depth Answer:
"A blameless post-mortem is rooted in the principle that human error is the *symptom* of a broken system, never the root cause. If an engineer deployed a bug, our automated CI/CD, linters, or staging environments failed to catch it.  
My process:
1. **Establish the Incident Timeline**: Document timestamps for: Alert triggered $\to$ Engineer paged $\to$ Incident commander assigned $\to$ Rollback/mitigation executed $\to$ Service restored. (Calculate MTTD and MTTR).
2. **Perform a 5 Whys Root-Cause Analysis**: Keep asking 'why' to drill down from the immediate bug to the architectural vulnerability. (e.g. Why did the DB crash? Exhausted connections. Why? Un-awaited async session. Why? Missing async lint rule in CI).
3. **Generate Preventative Action Items**: Every post-mortem must produce concrete Jira tickets with assigned owners and deadlines: add automated linting in CI, add health-check alerts, and configure connection pool limits.
4. **Publish Transparently**: Share findings across engineering so the entire organization learns from the incident."

---

### Q3: "Tell me about a time you had a strong technical disagreement with a team member. How did you resolve it?"
#### Model Response (STAR Framework):
- **Situation**: "During the architecture phase of the Siraaj document platform, a senior colleague wanted to use an all-in-one AI orchestration framework (LangChain) because of its extensive pre-built chains and third-party integrations. I advocated for a lightweight, native approach using the official OpenAI/Anthropic SDKs, FastAPI, and Pydantic."
- **Task**: "I needed to align the team on an architecture that prioritized maintainability, low latency, and ease of debugging without creating friction or stalling the sprint."
- **Action**: "Rather than arguing theoretically, I proposed a time-boxed 1-day spike where we built two parallel proofs-of-concept for our core RAG retrieval endpoint. We then ran a load test and inspected stack traces. The native implementation showed 40% lower response latency, cleaner Pythonic stack traces during failure simulation, and eliminated over 50 transitive npm/pip dependencies."
- **Result**: "My colleague agreed that the native approach was far superior for our core low-latency RAG APIs. We mutually decided to use native FastAPI for all core pipelines, while agreeing to keep LangGraph in reserve for complex cyclic multi-agent prototypes where state graphs are genuinely beneficial."

---

### Q4: How do you achieve zero-downtime database schema migrations in a high-traffic system?
#### Junior Answer:
"Run `alembic upgrade head` late at night when traffic is low."
#### Senior In-Depth Answer:
"Zero-downtime migrations follow the **Expand / Contract (Parallel Run) Pattern**, decoupled across multiple releases:
1. **Expand (Release 1)**: Add the new column as nullable in the database migration. Deploy application code that begins dual-writing to both the old column and the new column, while still reading from the old column.
2. **Backfill (Offline Job)**: Run an asynchronous background script to backfill historical data from the old column to the new column in small batches (e.g. 2,000 rows with pauses) to prevent locking table rows or exhausting replication lag.
3. **Switch (Release 2)**: Deploy application code that switches reading and writing exclusively to the new column.
4. **Contract (Release 3)**: Once metrics confirm stability, run a final migration to drop the old column and any deprecation constraints."

---

### Q5: "How do you handle non-deterministic outputs and hallucination risks in customer-facing AI products?"
#### Model Response:
"Non-determinism is the central challenge in AI engineering. I approach it with three layers of defense:
1. **Deterministic Guardrails & Structured Output**: Never allow an LLM to generate free-form text when structured data is required. Use Grammar-Constrained Decoding / Pydantic schemas (`response_format` or tool calling) to ensure valid, typed payloads.
2. **Automated Continuous Evaluation**: Before releasing any prompt or model update, run evaluation benchmarks using frameworks like Ragas against a golden dataset of ground-truth test cases. We measure Faithfulness (groundedness in citations) and Answer Relevance. If Faithfulness drops below 98%, the release is blocked.
3. **Graceful Fallbacks & Citations**: In the UI, every claim is anchored with a clickable citation linked directly to the underlying document chunk. If the retrieval confidence score falls below a set threshold, the agent does not guess—it triggers a graceful fallback message: *'I cannot verify this in your company records.'*"
