# Behavioral & Project Talking Points (STAR Templates)

For a full-stack developer (~2.5 years, React/Next.js strong, growing into Python/FastAPI + PostgreSQL). Targeting mid-size companies in Tier-1 Indian cities.

See also: [`../00-start-here/08-node-to-python-pitch.md`](../00-start-here/08-node-to-python-pitch.md) for your intro and how to talk about AI-assisted work.

> ⚠️ **Use these as templates, not scripts.** Fill them with YOUR real projects, YOUR real numbers, and things you can actually explain. Interviewers ask follow-up questions ("how exactly did you measure that?"), so never claim a metric or a story you can't back up. Honest and specific beats impressive and fabricated.

---

## 🎯 The "Bridge Story": pitching your experience honestly

When asked: *"You're strong in React/Node, but this role leans Python/FastAPI. Why you?"*

### A grounded narrative (adapt to your real work):
> *"I've spent about two and a half years building full-stack applications, strongest on the React and Next.js side, and over the last several months I've been building backend services with FastAPI and PostgreSQL. Because I've built and consumed a lot of APIs from the frontend, I understand the full path from a user click down to the database and back, which helps me design clean APIs and debug across the stack. The async concepts carried over from JavaScript, so picking up FastAPI's async model and Pydantic validation felt natural. I'm still growing on the backend, but I learn fast and I make sure I understand what I ship."*

Keep it honest about being frontend-strong and backend-growing. That's a real, hireable profile — don't oversell it into a senior-backend claim you'll have to defend.

---

## 📋 STAR Story 1: Siraaj (Rihal) — your real project ⭐

*This is your strongest, real story. Fill the brackets with what YOU actually did. Only keep the technical details and numbers you can explain if asked a follow-up.*

> **Before your interview, get clear on these about Siraaj:**
> - What Siraaj does, in one line: `[e.g. document Q&A / AI assistant / search over documents]`
> - Your role: `[frontend / backend / RAG-AI / mix]`
> - Tech YOU personally worked with: `[React/Next.js, FastAPI, PostgreSQL, vector DB (which one?), which LLM API?]`
> - One thing you personally built or fixed and can explain deeply: `[__________]`

### Situation:
- "At Rihal I worked on Siraaj, which `[one-line description of what it does and who uses it]`."
- The challenge was `[e.g. users needed accurate answers from their documents / the UI needed to feel responsive while the model generated answers]`.

### Task:
- "I was responsible for `[your actual part — e.g. building the frontend chat UI and wiring it to the backend / building the FastAPI endpoints / the retrieval flow]`."

### Action (keep only what you did):
- **Frontend (if you did it):** built the UI in React/Next.js with streaming responses so users saw the answer appear token by token instead of waiting.
- **Backend (if you did it):** built FastAPI endpoints with Pydantic validation, talking to PostgreSQL `[and a vector DB]`.
- **RAG flow (if you did it):** chunked documents, embedded them, stored vectors, and on each query retrieved the most relevant chunks to build the LLM prompt.
- `[Any specific improvement you made — a bug you fixed, something you made faster or cleaner.]`

### Result:
- "`[Real outcome. If you have a real measured number, use it. If not, describe it honestly:]` the feature shipped and `[users could do X / it was more accurate / it felt faster]`."

> 💡 **Honesty tip:** The earlier version of this file had impressive numbers (38% precision, 8.5s→350ms). Only claim numbers you actually measured. "It felt noticeably faster once we streamed the response" is a perfectly good, defensible answer.

---

## 📋 Template 2: A feature you built end to end

*Theme: ownership across the stack — your strongest angle. Use a real feature.*

- **Situation:** "[Your app] needed [feature] because [reason]."
- **Task:** "I owned it from the UI down to the API and database."
- **Action:** "Built the React/Next.js frontend with proper loading/error states and form validation; built the FastAPI endpoint with a Pydantic model and a SQLAlchemy query against PostgreSQL; [any real detail: pagination, auth check, caching]."
- **Result:** "It shipped and [real outcome]."

---

## 📋 Template 3: A bug you debugged systematically

*Theme: calm, methodical problem-solving.*

- **Situation:** "We had [a slow page / wrong data / an intermittent error]."
- **Task:** "Find the root cause and fix it safely."
- **Action:** "I reproduced it reliably, checked logs and the network tab, narrowed down where it happened, formed a hypothesis, and tested the fix. [If DB-related: used `EXPLAIN`, found a missing index or an N+1 query.]"
- **Result:** "Fixed it and added [a test / an index / logging] so it wouldn't recur."

---

## 📋 Template 4: A technical decision or disagreement

*Theme: judgment and communication — no ego.*

- **Situation:** "We had to choose between [option A] and [option B]."
- **Task:** "Make a call and get the team aligned."
- **Action:** "Instead of just arguing, I weighed [simplicity vs flexibility / speed vs maintainability], tried a small prototype, and shared what I found."
- **Result:** "We went with [choice] because [reason], and it worked out."

---

## 💬 Common Behavioral Questions (answer honestly, at your level)

These are sample answers in the right *shape*. Swap in your real experiences. Simple and true beats polished and fake — interviewers can tell the difference.

### 1. "Tell me about a technical disagreement with a teammate."
**Aim for:** data over ego, and a good outcome.
> *"On a feature, a teammate wanted to pull in a heavy library and I felt it was overkill for what we needed. Instead of just debating, I put together a small version both ways so we could compare — one was simpler and had fewer dependencies to maintain. We talked it through and went with the lighter approach. The point wasn't winning; it was picking what the team could maintain."*

### 2. "How do you deal with unclear requirements?"
**Aim for:** you ask questions and reduce ambiguity early.
> *"I don't guess for long. I ask the person who raised it what the actual goal is and what 'done' looks like, sketch the smallest version, and confirm before building the whole thing. It saves reworking later. For anything involving AI outputs, I also validate the response shape so bad output doesn't break the app."*

### 3. "Describe a bug you ran into and how you fixed it."
**Aim for:** a calm, systematic process — and honesty about what you learned.
> *"We had an endpoint that got slow under a bit of load. I reproduced it, added some timing/logging, and traced it to the database — a query without an index was scanning the whole table, and there was an N+1 pattern where we queried in a loop. I added the index and switched to loading the related data in one query. It got much faster, and I learned to check `EXPLAIN` early when a query feels slow."*

*(If you used AI to help find or fix a bug, that's fine to mention — what matters is that you understood the root cause and the fix.)*
