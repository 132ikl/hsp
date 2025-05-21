#!/usr/bin/env bash
# Shared utilities

dbg() {
    echo "dbg: $1" >&2
}

error() {
    echo "Error: $1" >&2
    exit 1
}

# prefixes a string if it is not empty
# params: string, suffix
prefix_non_empty() {
    if [[ -n "$1" ]]; then
        printf "%s%s" "$2" "$1"
    fi
}

# prints an OSC code terminated by BEL
# params: code, parameter, data
osc() {
    local parameter data
    parameter="$(prefix_non_empty "$2" ";")"
    data="$(prefix_non_empty "$3" ";")"
    printf "\e]%s%s%s\a" "$1" "$parameter" "$data"
}
