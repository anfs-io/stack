# skills.zsh

export PPM_AI_HOME=$HOME/.agents
export PPM_AI_SKILLS_HOME=$PPM_AI_HOME/skills

sconf() {
  local dir=$PPM_AI_SKILLS_HOME file="chorus/hello/SKILL.md" ext="md"
  load_conf "$@"
}

