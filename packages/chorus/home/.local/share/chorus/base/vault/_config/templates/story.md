<%*
const configFile = app.vault.getAbstractFileByPath("_config/base.json");
const config = configFile ? JSON.parse(await app.vault.read(configFile)) : {};
const tasksMode = config.tasks || "inline";
-%>
---
feature: "[[feature]]"
status: backlog
priority: medium
created: <% tp.date.now("YYYY-MM-DD") %>
---

# <% tp.file.title %>

## User Story

As a [type of user], I want [goal] so that [benefit].

## Acceptance Criteria

- [ ] Given... When... Then...
- [ ] Given... When... Then...

## Technical Notes

Implementation guidance, affected files, approach suggestions.

---

## Tasks

<%* if (tasksMode === "file") { -%>
```button
name New Task
type append template
action scripts/new-task
templater true
```

![[_config/bases/tasks.base]]
<%* } else { -%>
- [ ] Task 1
- [ ] Task 2
<%* } -%>
