You are running the dedicated research phase for Linear ticket `{{ issue.identifier }}`

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

1. This phase runs before implementation. Do not edit code, run git mutations, or create a PR from this turn.
2. Use `linear_graphql` to load the current issue context before researching:
   - issue comments
   - issue attachments
   - issue documents
3. Gather the best available evidence for the ticket from:
   - the Linear issue and linked discussion
   - relevant Slack conversations when the configured tools expose them
   - official docs or primary-source web research when external documentation is needed
   - Railway production logs or metrics when runtime evidence is needed and the configured tools expose them
4. Start in plan mode and produce a concise PRD/spec for the implementation phase.
5. Upsert these Linear documents on the issue with exact, consistent titles:
   - `Research`
   - `Research - PRD`
   - `Research - Questions`
6. Reuse existing documents with those titles when they already exist. Update them instead of creating duplicates.
7. Put the evidence trail, assumptions, and source links in `Research`.
8. Put the implementation-ready PRD/spec in `Research - PRD`.
9. Put every unresolved implementation question, open dependency, or missing access gap in `Research - Questions`.
10. If a source is unavailable in-session, record that gap in `Research` and continue with the remaining sources instead of asking a human for help.
11. End the turn after the research documents are attached. The implementation workflow will start next.

Recommended Linear GraphQL shapes:

```graphql
query IssueResearchContext($id: String!) {
  issue(id: $id) {
    id
    identifier
    title
    description
    url
    comments(first: 50) {
      nodes {
        id
        body
        resolvedAt
      }
    }
    attachments(first: 50) {
      nodes {
        id
        title
        url
        sourceType
      }
    }
    documents(first: 50) {
      nodes {
        id
        title
        url
        content
        updatedAt
      }
    }
  }
}
```

```graphql
mutation CreateDocument($issueId: String!, $title: String!, $content: String!) {
  documentCreate(input: {issueId: $issueId, title: $title, content: $content}) {
    success
    document {
      id
      title
      url
    }
  }
}
```

```graphql
mutation UpdateDocument($id: String!, $content: String!, $title: String) {
  documentUpdate(id: $id, input: {title: $title, content: $content}) {
    success
    document {
      id
      title
      url
    }
  }
}
```
