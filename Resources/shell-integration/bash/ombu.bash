# Flow cannot load this into bash by itself. To have agents started through
# Flow's shims, end ~/.bashrc or ~/.bash_profile with
#
#   [ -n "$OMBU_HELPER" ] && source "${OMBU_HELPER%/*}/../Resources/shell-integration/bash/ombu.bash"
#
# The first prompt comes after the user's config has set PATH, so the shims
# go in front of wherever the agents were installed.
if [[ $- == *i* && -n "$OMBU_SURFACE_ID" && -n "$OMBU_SHIMS" && -z "$OMBU_AGENTS_DISABLED" ]]; then
    __flow_agents_init() {
        PROMPT_COMMAND=${PROMPT_COMMAND/__flow_agents_init;/}
        unset -f __flow_agents_init
        local dir="$OMBU_SHIMS/$OMBU_SURFACE_ID"
        "$OMBU_HELPER" shims "$dir" && PATH="$dir:$PATH"
    }
    PROMPT_COMMAND="__flow_agents_init;${PROMPT_COMMAND}"
fi
