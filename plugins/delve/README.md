# Delve

Review diffs the way you actually read code — one focused chunk at a time.

Delve breaks a diff into small, logically grouped pieces, presents them in an order that makes sense, and captures your
feedback as structured TODOs that the agent can act on immediately.

## Why Delve?

- **Stay focused.** Large diffs are split into screen-sized chunks grouped by related changes, so you never lose context.
- **Review in the right order.** Intelligent ordering means you understand _what_ something does before seeing _where_
  it's used.
- **Comments become actions.** Every piece of feedback you leave is captured as a TODO with enough context for the agent
  to implement it - no copy-pasting, no separate issue tracker.
- **Pick up where you left off.** Session state is saved automatically. Come back later and resume from the chunk you
  were on.

## Installation

### GitHub Copilot CLI / Claude Code

```
/plugin marketplace add MattKotsenas/agent-plugins
/plugin install delve@agent-plugins
```

## Sample workflow

> [!TIP]
> The exchange below is condensed for readability. In practice, each `>` block is a separate prompt/response in your
> terminal.

**1. Start a review**

```
/delve
```

**2. Choose a baseline**

```
Agent: You're on branch feature/auth at abc1234.
       Choose a diff baseline:
         ❯ Merge base (recommended)
           Last change
           Custom ref
```

**3. See the plan**

```
Agent: Diff Plan

       | # | Chunk                        | File              |
       |---|------------------------------|-------------------|
       | 1 | New validateToken() helper   | src/auth/token.ts |
       | 2 | Login endpoint uses helper   | src/auth/login.ts |
       | 3 | Add token expiry config      | config/auth.json  |

       3 chunks · 3 files · ~3 min
```

**4. Walk through chunks**

The agent shows each chunk as a colored diff:

````
Agent: Chunk 1 / 3 — New validateToken() helper
       File: src/auth/token.ts

       ```diff
        export function validateToken(token: string): boolean {
       +  if (!token || token.length < 16) {
       +    return false;
       +  }
       +  const decoded = decodeBase64(token);
       +  return decoded.exp > Date.now();
        }
       ```

       [Next]  [Previous]  or type a comment
````

**5. Leave feedback inline**

```
You:  Should we throw instead of returning false? The caller needs to know *why* validation failed.

Agent: 📝 TODO captured. Still on Chunk 1/3.
       [Next]  [Previous]  or type a comment

You:  Next
```

**6. Finish and hand off**

```
Agent: ✅ Review complete

       | Chunks reviewed | 3 / 3 |
       | TODOs captured  | 2     |
       | Files covered   | 3     |

       TODOs:
       1. Throw instead of returning false in validateToken()
          → src/auth/token.ts · validateToken()
       2. Token expiry should be configurable per environment
          → config/auth.json

       What would you like to do?
         ❯ Hand off TODOs to an implementation agent
           Revisit a specific chunk
           Done — keep TODOs for later
```

The agent then applies your feedback automatically.

## What about `/review` and `/diff`?

The `/review` command is aimed at agents reviewing the code. `/delve` is aimed at _you_ reviewing the code.
The `/diff` command shows unstaged or branch diffs only. It doesn't provide guidance on the _order_ in which files are
reviewed, nor does it allow for specifying the diff range.
