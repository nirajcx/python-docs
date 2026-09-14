# RAG / GenAI Quick Guide (Start Here)

Many mid-size companies now ask about RAG and LLM integration, especially if the role mentions AI. You don't need deep ML — you need to explain the pipeline clearly and the practical decisions.

Format: **concept → plain explanation → what you say → follow-up.**

---

## 1. What is RAG, in one breath?

**Plain explanation:** LLMs only know what they were trained on and can make things up. RAG (Retrieval-Augmented Generation) fixes this by **fetching relevant documents from your own data and putting them into the prompt** before the model answers. So the model answers using your facts, not its guesses.

**Interview answer:** "RAG retrieves relevant chunks from a knowledge base and injects them into the prompt so the LLM answers from real, current, source-able data instead of relying on training memory. It reduces hallucinations and lets me cite sources."

---

## 2. The RAG pipeline (know this cold)

```
Documents → split into chunks → turn into embeddings → store in vector DB
                                                              |
User question → embed the question → search vector DB for similar chunks
                                                              |
        Put top chunks + question into a prompt → LLM → grounded answer
```

Two phases:
- **Ingestion (offline):** chunk your docs, embed them, store the vectors.
- **Retrieval + generation (per query):** embed the question, find similar chunks, feed them to the LLM.

---

## 3. Embeddings (the core idea)

**Plain explanation:** An embedding turns text into a list of numbers (a vector) that captures meaning. Texts with similar meaning end up close together in that number space. That's how we find "relevant" chunks — we look for vectors near the question's vector.

**Interview answer:** "An embedding is a numeric vector representing the meaning of text. Similar meanings produce nearby vectors, so retrieval is just finding the nearest vectors to the query."

**Follow-up:** *"How do you measure similarity?"* → Cosine similarity (the angle between vectors). Closer angle = more similar.

---

## 4. Chunking (a practical decision)

**Plain explanation:** You can't embed a whole 100-page PDF as one vector — it'd be too coarse. You split it into chunks (say 300–800 tokens) with a little overlap so context isn't lost at the boundaries.

**Interview answer:** "I split documents into overlapping chunks so each vector represents a focused idea. Too large and retrieval is imprecise; too small and you lose context. Overlap keeps sentences from being cut off between chunks."

---

## 5. Vector databases

**Plain explanation:** A vector DB stores embeddings and finds the nearest ones fast, even across millions of vectors. Names to know: **Chroma** (simple, local), **Qdrant**, **Pinecone** (managed), **FAISS** (a library, not a full DB), and **pgvector** (PostgreSQL extension).

**Interview answer:** "A vector DB does approximate nearest-neighbor search so it can find similar vectors quickly at scale. For a small project I'd use Chroma or pgvector; for managed scale, Pinecone or Qdrant."

**Follow-up:** *"Why 'approximate'?"* → Exact nearest-neighbor over millions of vectors is slow. Algorithms like HNSW trade a tiny bit of accuracy for a huge speed gain.

---

## 6. RAG vs fine-tuning (a classic question)

| | RAG | Fine-tuning |
|---|---|---|
| Best for | Facts, changing data, citations | Style, tone, output format |
| Update data | Instant (just add to the store) | Requires retraining |
| Hallucination risk | Lower (grounded) | Higher |

**Interview answer:** "For factual, changing knowledge I use RAG — I can update the data instantly and cite sources. Fine-tuning is better for teaching the model a style or format, not for injecting facts."

---

## 7. Making RAG better (mention if asked)

- **Re-ranking:** after retrieving, use a smarter model to reorder chunks by true relevance.
- **Hybrid search:** combine keyword search (BM25) with vector search for the best of both.
- **Query rewriting:** rephrase or expand the user's question before searching.
- **Evaluation:** measure quality (is the answer grounded? relevant?) with tools like Ragas.

---

## 8. LLM integration basics

- **Prompt = system message (rules) + context (retrieved chunks) + user question.**
- **Streaming:** stream tokens to the UI so the user sees output immediately (Server-Sent Events).
- **Function/tool calling:** the model can ask your code to run a function (e.g. look up an order) and use the result.
- **Temperature:** higher = more creative/random, lower = more deterministic. Use low for factual answers.

**Interview answer:** "I build the prompt from a system instruction, the retrieved context, and the user's question. I stream the response for better UX and keep temperature low for factual, grounded answers."

---

## Quick self-test
1. Explain the RAG pipeline end to end.
2. What is an embedding and how is similarity measured?
3. Why chunk documents, and why add overlap?
4. RAG vs fine-tuning — when each?
5. What does temperature control?

More detail: [`../03-rag-vector-genai/07-rag-fundamentals.md`](../03-rag-vector-genai/07-rag-fundamentals.md), [`08-vector-databases.md`](../03-rag-vector-genai/08-vector-databases.md), [`10-llm-integration.md`](../03-rag-vector-genai/10-llm-integration.md).
