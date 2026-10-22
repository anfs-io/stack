# What pjm reads of a source's output: the normalisation in user/pjm's cmd_pull
# (packages/pjm/home/.local/bin/pjm, under "--- pull", pjm 0.1.1), copied as it is. tasks.bats
# feeds `ovm tasks --json` through it, so a change to either side that breaks the contract fails
# there. If pjm's copy changes, change this one with it.
# Usage: jq -s --arg tag go -f pjm-pull.jq <source output>...
def strip: gsub("(?<![^\\s])#" + $tag + "(?![A-Za-z0-9_/-])"; "") | gsub("\\s+"; " ") | sub("^ "; "") | sub(" $"; "");
[.[] | if type == "array" then .[] else . end]
| map({vault_id: (.vault_id // ""), vault: (.vault // ""), file: (.file // ""),
       line: ((.line // 0) | tonumber), doc: (.doc // ""), space: (.space // ""),
       section: (.section // ""), parent: ((.parent // "") | strip), tags: (.tags // []),
       go: ((.tags // []) | any(. == $tag)), text: ((.text // "") | strip)})
| map(select(.text != "")) | sort_by(.vault_id, .file, .line)
