# Software Development Life Cycle (SDLC), DevOps & Engineering Best Practices

Target Role: Python/FastAPI Backend & GenAI Engineer  
Cross-References: [05-fastapi-advanced.md](../02-fastapi-backend/05-fastapi-advanced.md) | [11-system-design-basics.md](../04-system-design-dsa/11-system-design-basics.md) | [16-database-design-principles.md](../07-database-design/16-database-design-principles.md)

---

## 1. Git Branching Strategies: Trunk-Based vs. GitFlow

Modern engineering organizations prioritize continuous delivery velocity and small batch sizes over heavy branch management.

```
       GitFlow (Heavy, Slow, Merge Conflicts)
 ┌───────────┐  Feature Branch (lives for 3 weeks)   ┌─────────────┐
 │ main      │──────────────────────────────────────►│ Merge Hell! │
 └───────────┘       Release Branch                  └─────────────┘
 
       Trunk-Based Development (Fast, Modern Standard)
 ┌───────────┐
 │ main      ├──► [Branch A: 1-day PR] ──► Merged to main behind Feature Flag
 │ (Trunk)   ├──► [Branch B: 4-hour PR] ──► Merged to main behind Feature Flag
 └───────────┘
```

| Criterion | Trunk-Based Development | GitFlow |
|---|---|---|
| **Branch Lifespan** | Very Short (< 24–48 hours) | Long (weeks or months) |
| **Integration Frequency** | Multiple times per day into `main` | Infrequent (at release boundaries) |
| **Merge Conflicts** | Minimal (continuous rebase/merge) | High ("Merge Hell" during releases) |
| **Release Mechanism**| Automated CI/CD + **Feature Flags** | Dedicated `release/*` branches |
| **Industry Adoption** | Google, Meta, Netflix, modern startups | Legacy enterprise, scheduled box software |

---

## 2. CI/CD Pipeline Architecture

A robust continuous integration and deployment pipeline guarantees code quality before anything reaches production.

```
 GitHub Push / PR
        │
        ▼
 ┌──────────────┐
 │ 1. Lint &    │ Ruff / Black / Flake8 (Python) + ESLint / Prettier (TypeScript)
 │    Format    │
 └──────┬───────┘
        ▼
 ┌──────────────┐
 │ 2. Typecheck │ Mypy / Pyright (Python) + `tsc --noEmit` (TypeScript)
 └──────┬───────┘
        ▼
 ┌──────────────┐
 │ 3. Automated │ Pytest (Unit + Async Integration tests with testcontainers)
 │    Tests     │ Jest / Playwright (Frontend E2E)
 └──────┬───────┘
        ▼
 ┌──────────────┐
 │ 4. Security  │ Trivy (Container CVEs) + Bandit (Python AST) + Snyk (Dependencies)
 └──────┬───────┘
        ▼
 ┌──────────────┐
 │ 5. Container │ Multi-stage Docker build with GitHub Actions layer caching (Buildx)
 └──────┬───────┘
        ▼
 ┌──────────────┐
 │ 6. Continuous│ Push image to AWS ECR / GHCR ──► Rolling Deploy to AWS ECS / K8s
 │    Deploy    │
 └──────────────┘
```

---

## 3. The Testing Pyramid in Modern AI & Backend Stacks

```
                         The Testing Pyramid
                                 ▲
                                / \
                               /E2E\       10% (Playwright / Cypress user journeys)
                              /-----\
                             / Integ \     20% (FastAPI TestClient + Real Postgres/Redis)
                            /---------\
                           /   Unit    \   70% (Pure functions, chunkers, algorithms, mocks)
                          /-------------\
```

### Types of Tests:
1. **Unit Tests (Fastest, High Volume)**: Tests isolated functions with zero network/database dependencies (e.g. testing text splitters, RRF formula, validation rules).
2. **Integration Tests (High Confidence)**: Tests API endpoints end-to-end with real containerized dependencies (Postgres, Redis) using `testcontainers` or mock servers.
3. **Contract Testing (Microservices)**: Using tools like **Pact** to ensure frontend schemas and backend API responses remain in sync without spinning up the entire microservice ecosystem.
4. **E2E / Regression Tests**: Automated browser simulations verifying critical revenue paths (Sign Up $\to$ Document Upload $\to$ Chat).

---

## 4. Observability: The Three Pillars (Metrics, Logs, Traces)

Monitoring tells you *when* a system is broken; Observability tells you *why* it broke.

### 1. Structured JSON Logging with Trace Correlation
Never output plain unstructured text (`print("error!")`) in production. Output structured JSON with a unique `request_id` passed across service boundaries.

```python
import structlog

logger = structlog.get_logger()

# Structured log payload parsed seamlessly by Datadog / Grafana Loki:
logger.info(
    "rag_retrieval_completed",
    request_id="req_9a41b2c",
    tenant_id="org_alpha",
    chunks_found=5,
    retrieval_latency_ms=42.5,
    model="text-embedding-3-small"
)
```

### 2. Metrics (Prometheus & Grafana)
Track the **Four Golden Signals**:
- **Latency**: Time to service requests (measured at 50th, 95th, and 99th percentiles—never rely purely on average!).
- **Traffic**: Request rate (QPS).
- **Errors**: Rate of failed requests (HTTP 5xx).
- **Saturation**: How full the most constrained resource is (CPU, RAM, DB connection pool).

### 3. Distributed Tracing (OpenTelemetry)
Assigns a `trace_id` to an incoming user request and attaches child `span_id`s as the request moves from:
`Next.js Frontend` $\to$ `FastAPI Gateway` $\to$ `Redis Cache` $\to$ `Qdrant Vector DB` $\to$ `OpenAI API`.  
Visualized in Jaeger or Datadog, pinpointing exactly which microservice or database query added latency.

---

## 5. Application Security & The OWASP Top 10 (AI Focus)

### 1. Broken Object Level Authorization (BOLA / IDOR)
The #1 API vulnerability. User A requests `/api/v1/documents/doc_999`. The server checks that the token is valid, but forgets to check if `doc_999` actually belongs to User A's organization!  
*Fix:* Always scope database queries by tenant: `WHERE id = :doc_id AND org_id = :current_user_org_id`.

### 2. Server-Side Request Forgery (SSRF) in AI Ingestion
RAG applications frequently let users submit URLs to index ("Scrape this website").  
*Vulnerability:* An attacker submits `http://169.254.169.254/latest/meta-data/` to steal AWS EC2 cloud IAM credentials!  
*Fix:* Reject private/internal IP ranges (`10.0.0.0/8`, `192.168.0.0/16`, `127.0.0.1`, AWS metadata endpoints) at the network socket layer before fetching.

### 3. Secrets Management
- **Never** commit `.env` files or API keys into Git.
- **Never** bake secrets into Docker image layers (`ENV OPENAI_KEY=sk-...` is permanently visible via `docker history`).
- **Production Standard**: Inject secrets at runtime via cloud secret managers (AWS Secrets Manager, HashiCorp Vault, Infisical, or Kubernetes Secrets).

---

## 6. Zero-Downtime Deployment Strategies

```
                      Zero-Downtime Release Patterns
                      
 Rolling Deployment              Blue-Green Deployment           Canary Release
┌──────────────────────┐        ┌────────────────────────┐      ┌────────────────────────┐
│ Replaces instances   │        │ Router switches 100%   │      │ Routes 5% of traffic   │
│ 1-by-1 in cluster.   │        │ traffic from Blue (v1) │      │ to v2; monitors errors │
│ Temporarily runs both│        │ to Green (v2) instantly│      │ before 100% rollout    │
│ v1 and v2 in pool.   │        │ Instant rollback!      │      │ Safest for AI models!  │
└──────────────────────┘        └────────────────────────┘      └────────────────────────┘
```

---

## 7. Incident Management & Blameless Post-Mortems

When production goes down, high-performing engineering teams follow a structured protocol:

1. **Mitigate First, Root-Cause Later**: Roll back the release, restart the pods, or toggle the feature flag immediately. Do not spend 2 hours debugging on live broken traffic.
2. **Mean Time to Detect (MTTD) & Mean Time to Recover (MTTR)**: Key metrics for engineering operational health.
3. **Blameless Post-Mortem**:
   - Focus on *process and systemic failure*, never human blame ("How did our CI pipeline allow an invalid migration to be executed?").
   - Conduct a **5 Whys Analysis** to find the root architectural deficiency.
   - Output concrete **Action Items (Jira tickets)** with owners and deadlines to guarantee the issue never happens again.

---

## 8. High-Probability Interview Questions & Model Answers

### Q1: What is the difference between a Liveness Probe and a Readiness Probe in Kubernetes / Container orchestration?
**Answer:**
- **Liveness Probe** (`/healthz`): Checks if the container process is alive and responsive. If the liveness probe fails, Kubernetes kills the container and restarts it.
- **Readiness Probe** (`/readyz`): Checks if the container is ready to accept incoming user traffic (e.g. database connection pools established, embedding models loaded in memory). If it fails, Kubernetes stops routing network traffic to this pod without killing it, allowing it time to warm up.

### Q2: How do you implement Feature Flags safely in a production environment?
**Answer:**
Feature flags decouple code deployment from feature release.
1. Wrap new code paths behind a toggle evaluated against the current user context: `if feature_flags.is_enabled("new_rag_pipeline", user_id): ...`.
2. Store flag configurations in an in-memory cache (Redis or LaunchDarkly/PostHog SDK) to evaluate toggles in $< 1\text{ms}$.
3. Roll out gradually: 1% internal employees $\to$ 10% beta users $\to$ 100% general availability while monitoring error rates.
4. **Crucial Hygiene**: File technical debt cleanup tickets immediately to delete the old code path and flag once 100% rollout is stable.

### Q3: How do you prevent sensitive user PII from being logged in centralized log aggregators?
**Answer:**
1. Implement a **log scrubbing middleware / filter** that strips or masks sensitive keys (passwords, credit cards, SSNs, JWT tokens, auth headers) using regex patterns before writing to `stdout`.
2. Use structured log fields with type annotations, enforcing that raw request payloads are never dumped un-redacted into logging channels.
3. Enforce strict RBAC and retention policies on the centralized log repository (e.g. Datadog, CloudWatch).

### Q4: What is Semantic Versioning (SemVer)?
**Answer:**
SemVer follows the format `MAJOR.MINOR.PATCH` (e.g. `2.4.1`):
- **MAJOR**: Incremented when you introduce incompatible, breaking API changes.
- **MINOR**: Incremented when you add functionality in a backward-compatible manner.
- **PATCH**: Incremented when you make backward-compatible bug fixes.
