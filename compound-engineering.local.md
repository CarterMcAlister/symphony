---
review_agents: [code-simplicity-reviewer, security-sentinel, performance-oracle, architecture-strategist]
plan_review_agents: [code-simplicity-reviewer]
---

# Review Context

These notes are passed to compound-engineering review flows during `/prompts:workflows-review`
and `/ce:review`.

- `elixir/WORKFLOW.md` and `elixir/RESEARCH_WORKFLOW.md` are orchestration prompts; preserve Symphony's Linear state, workpad, PR, and land semantics while integrating compound workflows.
- `docs/plans/`, `docs/solutions/`, `docs/brainstorms/`, and `todos/` are intentional pipeline artifacts and must not be flagged for cleanup.
