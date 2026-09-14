# Practical Must-Knows (Start Here)

These are the everyday-engineering questions almost every interview slips in. They're easy points if you're ready and easy to fumble if you're not.

---

## 1. Git (you will be asked something)

**Core commands:**
```bash
git status                 # what changed
git add .                  # stage changes
git commit -m "message"    # save a snapshot
git push                   # send to remote
git pull                   # get latest
git checkout -b feature-x  # create + switch to a branch
git merge feature-x        # merge a branch in
```

**Common questions:**

- **`merge` vs `rebase`?** → "Merge keeps history as-is and adds a merge commit. Rebase replays my commits on top of the latest base for a linear history. I rebase my own feature branch to stay current, but avoid rebasing shared branches."
- **How do you resolve a merge conflict?** → "Git marks the conflicting sections; I open the file, pick the correct combination, remove the markers, then `add` and commit."
- **What's a pull request?** → "A request to merge my branch into main, where teammates review the code before it's merged."
- **`git revert` vs `git reset`?** → "Revert makes a new commit that undoes a change (safe on shared history). Reset moves the branch pointer back (rewrites history — use only locally)."

**Branching strategy:** "We used short-lived feature branches off main, opened PRs, got a review, and merged. Small, frequent merges reduce conflicts."

---

## 2. REST API design

**Plain explanation:** REST uses HTTP methods on resources (nouns), not actions.

| Method | Use | Example |
|---|---|---|
| GET | read | `GET /users/1` |
| POST | create | `POST /users` |
| PUT | replace | `PUT /users/1` |
| PATCH | partial update | `PATCH /users/1` |
| DELETE | remove | `DELETE /users/1` |

**Good practices:**
- Use plural nouns: `/users`, not `/getUsers`.
- Nest for relationships: `GET /users/1/orders`.
- Use query params for filtering/paging: `GET /users?page=2&limit=20`.
- Return the right status code (see below).

**Interview answer:** "REST models resources as URLs and uses HTTP methods for actions. I keep endpoints noun-based, use proper status codes, and page large collections with query params."

**Follow-up:** *"PUT vs PATCH?"* → PUT replaces the whole resource; PATCH updates only the fields you send.

---

## 3. HTTP status codes (memorize these buckets)

- **2xx success:** `200` OK, `201` Created, `204` No Content.
- **3xx redirect:** `301` moved permanently, `304` not modified (caching).
- **4xx client error:** `400` bad request, `401` unauthenticated, `403` forbidden (authenticated but not allowed), `404` not found, `409` conflict, `422` validation failed, `429` too many requests.
- **5xx server error:** `500` internal error, `502` bad gateway, `503` unavailable.

**Key distinction:** `401` = "I don't know who you are." `403` = "I know who you are, you're not allowed."

---

## 4. Authentication basics

- **JWT (JSON Web Token):** a signed token the client sends on each request (usually in the `Authorization: Bearer` header). The server verifies the signature — no server-side session needed (stateless).
- **Access token vs refresh token:** access tokens are short-lived; a longer-lived refresh token gets a new access token without re-login.
- **Hashing passwords:** never store plain passwords. Hash with bcrypt/argon2.

**Interview answer:** "I authenticate with JWTs sent in the Authorization header. The server verifies the signature so it stays stateless. Access tokens are short-lived and refreshed with a refresh token. Passwords are hashed with bcrypt, never stored in plain text."

---

## 5. Testing basics

**The testing pyramid:** many fast **unit tests** (single functions), fewer **integration tests** (modules together, e.g. API + DB), very few slow **end-to-end tests** (whole flow).

- **Frontend:** Jest / React Testing Library.
- **Python:** pytest.

**Interview answer:** "I write mostly unit tests for logic, some integration tests for endpoints hitting a test database, and a few end-to-end tests for critical flows. I test behavior, not implementation details."

**Follow-up:** *"What's a mock?"* → A stand-in for a real dependency (like an external API or DB) so the test is fast and isolated.

---

## 6. Debugging (they love a real story)

Have a short story ready: a bug you found, how you isolated it, and how you fixed it.

**A structured approach to describe:** "I reproduce the bug reliably, check logs and error messages, narrow down where it happens (binary-search the code path or add logging), form a hypothesis, test the fix, and add a test so it can't regress."

**Interview answer for a slow API:** "I'd check whether it's the database (slow query, missing index, N+1), an external call, or heavy computation. I'd measure with logging/timing, use `EXPLAIN` on suspect queries, and add caching or an index where it helps."

---

## 7. Environment & config hygiene

- Keep secrets in environment variables, never in code or git.
- Use a `.env` file locally (git-ignored) and real env vars in production.
- Different configs per environment (dev/staging/prod).

---

## 8. Docker (just the idea)

**Plain explanation:** Docker packages your app plus its dependencies into a container that runs the same everywhere — "works on my machine" solved.

**Interview answer:** "A container bundles the app and its dependencies so it runs identically across dev and prod. I write a Dockerfile, build an image, and run it as a container."

---

## Quick self-test
1. `merge` vs `rebase`, and when do you use each?
2. `401` vs `403`? `PUT` vs `PATCH`?
3. What goes in each layer of the testing pyramid?
4. Walk through how you'd debug a slow endpoint.
5. Where do secrets belong?
