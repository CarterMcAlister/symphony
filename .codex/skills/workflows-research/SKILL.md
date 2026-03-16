---
name: workflows-research
description: Gather Slack, web, repo, and Linear evidence for a ticket, then upsert Research documents and open questions before planning.
argument-hint: "[Linear ticket identifier or full ticket context]"
---

## Arguments
[Linear ticket identifier or full ticket context]

# Research Before Planning

This workflow is the compound-engineering research phase for unattended Symphony runs. It gathers
evidence across four channels, writes the ticket's research artifacts in Linear, and stops before
implementation begins.

## Ground Rules

- Always load the ticket via `linear_graphql` before researching.
- Never edit application code, run git mutations, or create a PR from this workflow.
- It is acceptable to write or update Linear documents/comments.
- If Slack or another source is unavailable in-session, record the gap in `Research` and continue.

## Required Outputs

Upsert these exact issue artifacts:

- `Research`
- `Research - PRD`
- comment titled `## Open Questions`

## Research Lanes

Use subagents or parallel tasks when the runtime supports them. If not, run the same lanes
sequentially without dropping any source category.

### 1. Slack lane

- Use the `agent-slack` skill or `agent-slack` CLI directly.
- Search by ticket identifier, key nouns from the title, and likely workflow terms.
- If credentials are missing, record the exact gap and proceed.

### 2. Web lane

- Use primary sources first.
- Prefer official docs and the source repository README over tertiary commentary.
- Capture direct source URLs used for the final evidence trail.

### 3. Project docs lane

- Use `repo-research-analyst` to inspect local repo structure, workflow files, and guidance.
- Use `learnings-researcher` to inspect `docs/solutions/` and critical patterns.
- Identify local file paths the implementation phase should touch.

### 4. Linear lane

- Search related tickets via `linear_graphql`.
- Read comments, attachments, and documents on any clearly related issues when they exist.
- Reuse prior decisions instead of re-deriving them.

## Synthesis

### `Research`

Include:

- Executive summary
- Evidence trail by source type
- Constraints and assumptions
- Access gaps or missing auth
- Source links and local file references

### `Research - PRD`

Include:

- Objective
- Scope / out of scope
- Proposed design
- Likely files
- Acceptance criteria
- Validation plan
- Risks and unresolved dependencies

### `## Open Questions`

Only include unresolved implementation questions, access gaps, or dependencies that still matter
after the research pass.

## Exit Condition

Stop after the two documents and the open-questions comment are attached to the issue. Do not begin
implementation from this workflow.
