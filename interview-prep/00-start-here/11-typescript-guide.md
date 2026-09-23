# TypeScript — safe API aur React contracts (Hinglish)

[Roadmap](../README.md) · [React](03-react-nextjs-quick-guide.md)

## Core answer

“TypeScript compile-time checks deta hai; network response runtime par automatically validate nahi hota. API boundary par schema validation/narrowing chahiye.”

`any` checks bypass karta hai; `unknown` use se pehle narrow karna padta hai. `as User` assertion data convert/validate nahi karta. Strict null checks missing values explicit banate hain.

## Type vs interface, generics

Interface object contracts aur declaration merging support karti hai. Type alias unions, tuples, intersections bhi represent karta hai. Dono object shapes express kar sakte hain; “interface always better” rule nahi.

```ts
function first<T>(items: readonly T[]): T | undefined {
  return items[0];
}

type Task = { id: string; title: string; completed: boolean };
type TaskPatch = Partial<Pick<Task, 'title' | 'completed'>>;
```

Generic relationship preserve karta hai; `any` relationship erase karega. `Partial<Task>` se ID bhi editable ho jaata, isliye writable keys deliberately choose kiye. Runtime API empty PATCH reject kar sakti hai even if type allows it.

## Impossible states reduce karo

```ts
type LoadState<T> =
  | { status: 'loading' }
  | { status: 'success'; data: T }
  | { status: 'error'; message: string };

function summary(state: LoadState<Task[]>): string {
  switch (state.status) {
    case 'loading': return 'Loading';
    case 'success': return `${state.data.length} tasks`;
    case 'error': return state.message;
    default: {
      const exhaustive: never = state;
      return exhaustive;
    }
  }
}
```

Discriminated union se `loading=true` aur contradictory data/error flags avoid hote hain. `never` exhaustive handling missing branch expose kar sakta hai.

## React typing checklist

Props explicit rakho; callback `(id: string) => void`; nullable refs/state handle karo. Browser event type aur DOM element generic match karo. Server response ko blindly `as Task[]` mat cast karo.

**Practice:** task form ke props, async load-state union, API error union aur editable patch type likho. `unknown` JSON ko checked domain value banane ka flow explain karo.
