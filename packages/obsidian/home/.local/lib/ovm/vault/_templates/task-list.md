---
id: <% Array.from(crypto.getRandomValues(new Uint8Array(10)), b => "abcdefghijklmnopqrstuvwxyz234567"[b % 32]).join("") %>
type: note
title: "<% tp.file.title %>"
---

# <% tp.file.title %>

```meta-bind-button
label: Validate this vault
style: primary
action:
  type: command
  command: obsidian-shellcommands:shell-command-ovm-validate
```

## Tasks

- [ ] 
