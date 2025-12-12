# opentofu

tf() {
  # Check if TF_BIN is already set
  if [[ -z "$TF_BIN" ]]; then
    # Check for tofu first, then terraform
    if command -v tofu >/dev/null 2>&1; then
      export TF_BIN=tofu
    elif command -v terraform >/dev/null 2>&1; then
      export TF_BIN=terraform
    else
      echo "Error: Neither 'tofu' nor 'terraform' found in PATH"
      return 1
    fi
  fi

  ${TF_BIN} "$@"
}

alias tf-console='tf console'
alias tf-init='tf init'
alias tf-state-list='tf state list'
alias tf-state-show='tf state show'
alias tf-workspace-delete='tf workspace delete'
alias tf-workspace-list='tf workspace list'
alias tf-workspace-new='tf workspace new'
alias tf-workspace-select='tf workspace select'
alias tf-workspace-show='tf workspace show'

tf-apply() { _tf_exec "apply" "$1" }
tf-apply-auto() { _tf_exec "apply" "$1" "-auto-approve" }
tf-destroy() { _tf_exec "destroy" "$1" }
tf-destroy-target() { _tf_exec "destroy" "$1" "-target" "$2"}
tf-plan() { _tf_exec "plan" "$1" }

_tf_exec() {
  local action="$1"
  local extra_args="$3"  # Add support for extra arguments
  local space
  local var_file_arg=""

  # If parameter provided, use it; otherwise use current workspace
  if [[ -n "$2" ]]; then
    space="$2"

    # Switch to the specified workspace
    if ! tf workspace select ${space}; then
      return 1
    fi
  else
    # Use current workspace
    space=$(tf workspace show)
  fi

  # Check if tfvars file exists
  if [[ ! -f "workspace/${space}.tfvars" ]]; then
    # Require a tfvars file unless its the default workspace
    if [[ "$space" != "default" ]]; then
      echo "Error: workspace/${space}.tfvars file not found"
      return 1
    fi
  else
    # File exists, so include it in the command
    var_file_arg="-var-file=workspace/${space}.tfvars"
  fi

  # Execute the terraform/tofu command
  tf ${action} ${var_file_arg} ${extra_args}
}
