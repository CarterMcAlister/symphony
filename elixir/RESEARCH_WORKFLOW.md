You are running the dedicated research and planning phase for Linear ticket `{{ issue.identifier }}`

Issue context:
Identifier: {{ issue.identifier }}
Title: {{ issue.title }}
Current status: {{ issue.state }}
Labels: {{ issue.labels }}
URL: {{ issue.url }}

Description:
{% if issue.description %}
{{ issue.description }}
{% else %}
No description provided.
{% endif %}

Research instructions:

1. This phase runs before implementation. Do not edit application code, run git mutations, or create a PR from this turn.
2. First execute the compound research workflow for this repository:
   - Prefer `/prompts:workflows-research`.
   - If that prompt command is unavailable in-session, open and follow `.codex/skills/workflows-research/SKILL.md` directly.
   - This workflow must gather evidence across four lanes, using subagents or parallel tasks whenever supported:
     - Slack conversations
     - primary-source web docs
     - project docs / local repo context
     - related Linear tickets and linked discussion
3. Upsert these exact Linear artifacts during the research pass:
   - `Research`
   - `Research - PRD`
   - comment titled `## Open Questions`
4. Reuse existing documents with those titles when they already exist. Update them instead of creating duplicates.
5. If any source is unavailable in-session, record the exact gap in `Research` and continue with the remaining lanes instead of asking a human for help.
6. After the research artifacts exist, immediately run compound planning for implementation:
   - Prefer `/prompts:workflows-plan`.
   - If the prompt command is unavailable in-session, open and follow `.codex/skills/ce:plan/SKILL.md` directly.
7. The planning step is unattended. Override the plan workflow's interactive defaults:
   - do not ask brainstorm or refinement questions
   - treat the Linear ticket, `Research`, and `Research - PRD` as sufficient context
   - write the plan artifact directly under `docs/plans/`
   - do not wait for post-generation menu choices
   - do not start implementation from this phase
8. After the plan file is written, add a deterministic handoff to `Research - PRD` that records the plan path so the main implementation workflow can locate it without guessing.
9. The only allowed repo write in this phase is compound planning output under `docs/plans/` and related research/planning support artifacts. Do not edit runtime code or tests.
10. End the turn after `Research`, `Research - PRD`, `## Open Questions`, and the `docs/plans/` plan artifact are in place. The implementation workflow will continue from there.
