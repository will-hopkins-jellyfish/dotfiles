---
name: jira
description: Look up Jira tickets by ticket number. Use this when the user mentions a Jira ticket ID like OJ-12345, ABC-999, etc.
argument-hint: <TICKET-ID>
---

## Instructions

When a Jira ticket ID is mentioned (e.g., OJ-12345, ABC-999), fetch the ticket details using the jira CLI tool.

**Ticket ID:** $ARGUMENTS

## Steps

1. Run `jira issue view $ARGUMENTS --plain` to get the ticket details
2. Present the key information to the user in a clear format:
   - Summary/Title
   - Status
   - Priority
   - Assignee
   - Description (summarized if very long)
   - Any linked issues or parent epic

If the user asks you to work on or solve the ticket, first understand what the ticket is asking for, then proceed to implement the solution.

