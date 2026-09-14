# TypeScript Quick Guide (Start Here)

If your resume says React/Next.js, expect TypeScript questions. You don't need advanced type gymnastics — you need the everyday concepts and the ones interviewers love to probe.

Format: **concept → plain explanation → what you say → follow-up.**

---

## 1. Why TypeScript at all?

**Interview answer:** "TypeScript adds static types on top of JavaScript, so I catch errors at compile time instead of at runtime — typos, wrong shapes, missing props. It also gives great autocomplete and makes refactoring safer. It compiles down to plain JavaScript."

---

## 2. Basic types

```ts
let name: string = "Asha";
let age: number = 25;
let active: boolean = true;
let tags: string[] = ["a", "b"];
let pair: [string, number] = ["x", 1];   // tuple
let anything: any;                         // avoid
let value: unknown;                        // safer 'any'
```

---

## 3. `type` vs `interface` (the #1 TS interview question)

**Plain explanation:** Both describe the shape of an object. Mostly interchangeable, with a few differences.

```ts
interface User { id: number; name: string; }
type User2 = { id: number; name: string; };
```

- **`interface`** can be "reopened" (declaration merging) and is the common choice for object shapes, especially public APIs.
- **`type`** is more flexible — it can describe unions, primitives, and tuples, not just objects.

**Interview answer:** "For object shapes they're mostly interchangeable. I use `interface` for object and component prop shapes because it reads well and supports merging; I use `type` when I need unions, intersections, or to alias a primitive or tuple — things `interface` can't do."

**Follow-up:** *"Can interface do a union?"* → No. `type Status = "active" | "inactive"` needs `type`.

---

## 4. Union and literal types

```ts
type Status = "loading" | "success" | "error";  // literal union
let id: string | number;                          // union
```

**Interview answer:** "Union types let a value be one of several types. Literal unions like `'loading' | 'success' | 'error'` are great for state — the compiler stops me from using an invalid value."

---

## 5. `any` vs `unknown`

- **`any`:** turns off type checking. Anything goes. Avoid — it defeats the purpose.
- **`unknown`:** "I don't know the type yet." You must narrow/check it before using it. Type-safe.

**Interview answer:** "`any` disables checking entirely; `unknown` is the safe version — I have to check what it is before using it. I prefer `unknown` for values from outside the app, like API responses I then validate."

---

## 6. Generics

**Plain explanation:** Generics let a function or type work with any type while keeping the connection. Think "a type parameter." Like how an array can be `Array<string>` or `Array<number>`.

```ts
function first<T>(arr: T[]): T {
  return arr[0];
}
first([1, 2, 3]);       // T is number
first(["a", "b"]);      // T is string
```

**Interview answer:** "Generics let me write reusable code that preserves type info. `first<T>` returns the same type it received, so I don't lose type safety. React uses this a lot — `useState<User | null>(null)`."

---

## 7. Utility types (know a few)

```ts
Partial<User>       // all fields optional
Required<User>      // all fields required
Pick<User, "id">    // just some fields
Omit<User, "id">    // all fields except some
Record<string, number>  // object with string keys, number values
Readonly<User>      // can't reassign fields
```

**Interview answer:** "Utility types transform existing types. I use `Partial` for update payloads where every field is optional, `Pick`/`Omit` to derive smaller types, and `Record` for maps. They keep types DRY."

---

## 8. Common React + TypeScript patterns

**Typing props:**
```tsx
interface ButtonProps {
  label: string;
  onClick: () => void;
  variant?: "primary" | "secondary";   // optional
}
function Button({ label, onClick, variant = "primary" }: ButtonProps) { ... }
```

**Typing state and refs:**
```tsx
const [user, setUser] = useState<User | null>(null);
const inputRef = useRef<HTMLInputElement>(null);
```

**Typing events:**
```tsx
const onChange = (e: React.ChangeEvent<HTMLInputElement>) => setValue(e.target.value);
```

**Interview answer:** "I type props with an interface, pass generics to `useState` and `useRef` when the type isn't obvious, and use React's built-in event types like `React.ChangeEvent`. It catches a lot of mistakes before the app even runs."

---

## 9. Optional, nullish, and narrowing

```ts
user?.name                 // optional chaining: safe if user is null
user?.name ?? "Guest"      // nullish coalescing: default only if null/undefined

// Narrowing
function print(x: string | number) {
  if (typeof x === "string") x.toUpperCase(); // TS knows it's a string here
  else x.toFixed(2);                           // and a number here
}
```

**Interview answer:** "Optional chaining (`?.`) safely accesses possibly-missing values, and `??` gives a default only for null/undefined (unlike `||`, which also triggers on `0` or `''`). TypeScript narrows union types inside `typeof`/`if` checks so I get the right methods."

---

## Quick self-test
1. `type` vs `interface` — differences and when each?
2. `any` vs `unknown`?
3. What problem do generics solve? Give an example.
4. Name three utility types and what they do.
5. `??` vs `||` — what's the difference?
6. How do you type a React component's props and its `useState`?
