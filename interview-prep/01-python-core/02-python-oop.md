# Python OOP: Architecture, Dunders & Clean Design

Target Role: Python/FastAPI Backend & GenAI Engineer  
Cross-References: [01-python-fundamentals.md](./01-python-fundamentals.md) | [04-fastapi-core.md](../02-fastapi-backend/04-fastapi-core.md) | [10-llm-integration.md](../03-rag-vector-genai/10-llm-integration.md)

---

## 1. Class vs. Instance Attributes & Methods

Understanding how Python resolves attributes on instances vs. classes is one of the most common mid-level interview screening tests.

```python
class ModelConfig:
    # CLASS ATTRIBUTE: Shared across all instances via class dictionary
    default_timeout: int = 30
    active_instances: int = 0

    def __init__(self, model_id: str, temperature: float = 0.7):
        # INSTANCE ATTRIBUTES: Specific to this instance (__dict__)
        self.model_id = model_id
        self.temperature = temperature
        ModelConfig.active_instances += 1

    # Instance method: Has access to specific instance state via self
    def get_prompt_payload(self, prompt: str) -> dict:
        return {"model": self.model_id, "prompt": prompt, "temp": self.temperature}

    # Class method: Factory method or class-level state manipulator
    @classmethod
    def from_fast_preset(cls) -> "ModelConfig":
        return cls(model_id="gpt-4o-mini", temperature=0.1)

    # Static method: Utility function bound to class namespace, takes neither self nor cls
    @staticmethod
    def is_valid_temperature(temp: float) -> bool:
        return 0.0 <= temp <= 2.0
```

### 🧠 The Class Attribute Shadowing Gotcha
```python
cfg1 = ModelConfig("gpt-4o")
cfg2 = ModelConfig("claude-3-5-sonnet")

cfg1.default_timeout = 60  # Creates an INSTANCE variable 'default_timeout' on cfg1!
print(cfg1.default_timeout)       # 60 (Reads from cfg1.__dict__)
print(cfg2.default_timeout)       # 30 (Reads from ModelConfig.__dict__)
print(ModelConfig.default_timeout) # 30 (Unchanged!)
```

---

## 2. Inheritance, `super()`, and MRO (Method Resolution Order)

Python uses the **C3 Linearization algorithm** to resolve method and attribute lookups in multiple inheritance hierarchies.

### How `super()` Works Under the Hood
`super()` does **not** simply mean "call my immediate parent". It means **"call the next class in the Method Resolution Order (MRO) of the current instance"**.

```python
class BaseRetriever:
    def retrieve(self, query: str) -> list[str]:
        print("BaseRetriever: Executing semantic search")
        return ["base_doc_1"]

class FilterMixin(BaseRetriever):
    def retrieve(self, query: str) -> list[str]:
        print("FilterMixin: Applying metadata pre-filtering")
        docs = super().retrieve(query)
        return [d for d in docs if "base" in d]

class CacheMixin(BaseRetriever):
    def retrieve(self, query: str) -> list[str]:
        print("CacheMixin: Checking Redis cache")
        return super().retrieve(query)

class HybridRetriever(FilterMixin, CacheMixin):
    pass

# Check the MRO:
print(HybridRetriever.__mro__)
# (HybridRetriever, FilterMixin, CacheMixin, BaseRetriever, object)

retriever = HybridRetriever()
retriever.retrieve("What is RAG?")
# Output:
# FilterMixin: Applying metadata pre-filtering
# CacheMixin: Checking Redis cache
# BaseRetriever: Executing semantic search
```

### 🧠 Junior vs. Senior Answer: "Why do we use `super().__init__()` instead of `Parent.__init__(self)`?"
- **Junior Answer**: "`super()` is cleaner and avoids typing the parent class name explicitly."
- **Senior Answer**: "Explicit parent calls (`Parent.__init__(self)`) break cooperative multiple inheritance and the diamond problem. With `super()`, Python traverses the C3 Linearization MRO graph deterministically. If multiple mixins or base classes are involved, `super()` guarantees each ancestor's method is invoked exactly once in the correct topological order."

---

## 3. Core Magic / Dunder Methods

Magic methods allow custom classes to integrate with Python's built-in syntax (operators, context managers, collections).

```python
class DocumentChunk:
    def __init__(self, chunk_id: str, content: str, embedding: list[float]):
        self.chunk_id = chunk_id
        self.content = content
        self.embedding = embedding

    # Developer inspection / debugging: unambiguous representation
    def __repr__(self) -> str:
        return f"DocumentChunk(chunk_id={self.chunk_id!r}, content_len={len(self.content)})"

    # User-friendly string display: print(chunk)
    def __str__(self) -> str:
        return f"[{self.chunk_id}] {self.content[:30]}..."

    # Equality: Used by ==
    def __eq__(self, other: object) -> bool:
        if not isinstance(other, DocumentChunk):
            return False
        return self.chunk_id == other.chunk_id

    # Hash: Required if instances will be stored in sets or as dict keys
    # RULE: If you override __eq__, you MUST override __hash__ to remain hashable!
    def __hash__(self) -> int:
        return hash(self.chunk_id)

    # Callable object: instance()
    def __call__(self) -> str:
        return self.content

    # Container protocol: len(chunk)
    def __len__(self) -> int:
        return len(self.content)
```

---

## 4. Abstract Base Classes (ABCs) & Protocols

Use ABCs to establish formal contracts across interchangeable components in AI/Backend systems (e.g., swapping embedding providers).

```python
from abc import ABC, abstractmethod
from typing import Protocol, runtime_checkable

# Approach 1: Nominal Subtyping (Explicit Inheritance via ABC)
class BaseVectorStore(ABC):
    @abstractmethod
    async def upsert(self, vectors: list[list[float]], ids: list[str]) -> None:
        """Upsert vectors into the index."""
        pass

    @abstractmethod
    async def query(self, vector: list[float], top_k: int = 5) -> list[dict]:
        """Query nearest neighbors."""
        pass

# Approach 2: Structural Subtyping (Duck Typing via PEP 544 Protocol)
@runtime_checkable
class EmbedderProtocol(Protocol):
    def embed_query(self, text: str) -> list[float]: ...
    def embed_documents(self, texts: list[str]) -> list[list[float]]: ...

# Any class with embed_query & embed_documents satisfies EmbedderProtocol
# without explicit inheritance!
```

---

## 5. Dataclasses vs. Pydantic vs. NamedTuple vs. TypedDict

Choosing the right data representation is a favorite interview differentiator.

| Feature | `dataclass` | `pydantic.BaseModel` | `NamedTuple` | `TypedDict` |
|---|---|---|---|---|
| **Primary Use** | Internal domain objects | API validation / serialization | Lightweight immutable records | Dict type hints for raw JSON |
| **Validation** | Type hints only (no runtime check) | Strict runtime coercion & validation | Type hints only | Type hints only (erased at runtime) |
| **Mutability** | Mutable by default (`frozen=True` opt) | Mutable by default (`frozen=True` opt) | Immutable | Mutable (standard dict) |
| **Performance** | Fast (pure Python C-generated bytecode) | Slightly slower (Pydantic v2 is Rust-backed) | Fastest (C-tuple struct) | Standard dict performance |
| **JSON Export**| Requires custom serializer | Built-in (`model_dump_json()`) | `_asdict()` | `json.dumps()` |

```python
from dataclasses import dataclass, field

@dataclass(slots=True, frozen=True)
class SearchResult:
    doc_id: str
    score: float
    metadata: dict = field(default_factory=dict)
```
> **Senior Tip (`slots=True`):** In Python 3.10+, adding `slots=True` to a dataclass suppresses the per-instance `__dict__`, storing attributes in a compact flat array. This reduces memory by **40–60%** when holding millions of vector search results in memory.

---

## 6. Composition vs. Inheritance in AI Pipelines

A common antipattern in junior code is building deep inheritance trees (`ChromaRAGService -> HybridRAGService -> AuthenticatedHybridRAGService`).  
**Senior Pattern:** Favor object composition and dependency injection.

```python
# HIGHLY TESTABLE, COMPOSED RAG PIPELINE
class RAGPipeline:
    def __init__(
        self,
        retriever: BaseVectorStore,
        llm_client: "LLMClientProtocol",
        reranker: "RerankerProtocol | None" = None
    ):
        self._retriever = retriever
        self._llm = llm_client
        self._reranker = reranker

    async def run(self, query: str) -> str:
        # Step 1: Retrieve
        raw_docs = await self._retriever.query([0.1, 0.2], top_k=10)
        
        # Step 2: Optional Rerank
        if self._reranker:
            raw_docs = await self._reranker.rerank(query, raw_docs, top_k=3)
            
        # Step 3: Synthesize
        return await self._llm.generate(query, raw_docs)
```

---

## 7. Gotchas & Follow-Up Questions Interviewers Ask

1. **"What happens if you define a mutable default in a dataclass?"**
   - Python raises `ValueError: mutable default <class 'list'> for field items is not allowed: use default_factory`. Dataclasses protect you from the classic mutable default argument trap by forcing `field(default_factory=list)`.
2. **"Can an abstract class be instantiated if it has no abstract methods?"**
   - Yes! A subclass of `ABC` can be instantiated freely unless at least one method is decorated with `@abstractmethod`.
3. **"What is the difference between `__repr__` and `__str__`?"**
   - `__str__` is meant for human end-users (readable). `__repr__` is meant for developers and debugging (unambiguous, should ideally look like valid Python code to recreate the object). If `__str__` is not defined, Python falls back to `__repr__`.

---

## 8. High-Probability Interview Questions & Model Answers

### Q1: How does Python resolve attribute access under the hood?
**Answer:**
Attribute lookup (`obj.attr`) follows this sequence:
1. Check the class and its MRO for a **data descriptor** (implements `__get__` and `__set__`). If found, descriptor `__get__` wins.
2. Check instance dictionary `obj.__dict__['attr']`.
3. Check the class dictionary `Class.__dict__['attr']` (and its MRO) for a **non-data descriptor** (e.g. methods) or normal class attribute.
4. If not found anywhere, Python calls `obj.__getattr__('attr')` if defined, otherwise raises `AttributeError`.

### Q2: What is the difference between `__getattr__` and `__getattribute__`?
**Answer:**
- `__getattribute__` is called **unconditionally** for *every single* attribute access on an object. Overriding it requires extreme caution (must use `super().__getattribute__`) to prevent infinite recursion.
- `__getattr__` is only called as a **fallback** when the requested attribute was *not* found in the instance `__dict__` or class hierarchy. It is the safe and standard way to implement dynamic attributes or proxies.

### Q3: When should you use a `@staticmethod` vs a `@classmethod`?
**Answer:**
- Use `@classmethod` when the method needs to access or mutate class-level state, or when implementing alternative factory constructors (e.g. `User.from_jwt(token)`), because it receives the class object `cls` as its first parameter.
- Use `@staticmethod` when the function is logically related to the class domain, but does not need access to `self` or `cls`. It behaves like a plain function placed inside the class namespace.

### Q4: How do `__slots__` work, and what are their trade-offs?
**Answer:**
By default, Python instances use a dynamic dictionary (`__dict__`) to store instance attributes, allowing arbitrary attributes to be added at runtime at the cost of dictionary memory overhead.  
Defining `__slots__ = ('x', 'y')` replaces `__dict__` with a fixed-size C array of attribute descriptors.
- **Pros:** Drastically reduces memory footprint (crucial for millions of chunk or vector objects) and speeds up attribute access.
- **Trade-offs:** Instances cannot have dynamic attributes added unless `'__dict__'` is explicitly included in slots, and multiple inheritance gets complicated if multiple base classes declare non-empty slots.

### Q5: How do you implement a Singleton in Python, and what is the preferred production approach?
**Answer:**
A Singleton can be implemented via `__new__` or a metaclass:
```python
class Singleton:
    _instance = None
    def __new__(cls, *args, **kwargs):
        if not cls._instance:
            cls._instance = super().__new__(cls)
        return cls._instance
```
*Senior Production Note:* In modern Python and FastAPI backends, explicit Singleton classes are often an antipattern. The idiomatic Python approach is **module-level instantiation** (Python modules are cached in `sys.modules` on first import, naturally acting as singletons) or **FastAPI Dependency Injection** with `lru_cache` (`@lru_cache def get_settings()`).
