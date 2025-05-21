#!/usr/bin/env bash
# Proof-of-concept HSP server in Bash

set -euo pipefail
source jsonrpc.bash
source util.bash
source common.bash

TMPDIR="$(create_tmpdir)"
INNER_PID=""

trap cleanup 0 1 2 3 6

# params: id, req_json
handle_echo() {
    local params
    params="$(get_param "$@")" || return 1
    response_ok "$id" "$params"
}

# params: id, req_json
handle_eval() {
    local params
    params="$(get_param "$@")" || return 1
    params="$(into_string "$params")" || {
        err_invalid_params
        return 1
    }
    printf "%s\0" "$params" >&10
    # response_ok "$id" '"command ran"'
    consume_stdout "$1"
}

# consume one byte from inner stdout and encode in hex
consume_byte() {
    local byte
    # od -v -t x1 -w1 <&11 | IFS='' read -r -N 2 byte || return 1
    # adapted from https://www.etalabs.net/sh_tricks.html
    read -r _ byte <<EOF
$(dd bs=1 count=1 status=none <&11 | od -t x1)
EOF
    printf "%s" "$byte"
}

# consume stdout until end of command
# (end of command detected by shoddily parsing OSC 133;D)
# splits into roughly 500 byte chunks
# this can be optimized
# params: id
consume_stdout() {
    local buffer=""
    while buffer="${buffer}$(consume_byte)"; do
        # we have OSC 133;D BEL (TODO also handle ST)
        [[ "$buffer" = *1b5d3133333b4407 ]] && {
            response_stdout "$1" "${buffer:0:-16}" true
            return
        }
        [[ "${buffer: -14}" = *1b* ]] && continue # we *might* have osc 133, so continue
        [[ "${#buffer}" -le 1000 ]] && continue   # buffer limit not reached yet

        # send this chunk
        response_stdout "$1" "$buffer" false
        buffer=""
    done
    error "Reached EOF while consuming stdout"
}

# params: req_json
parse_command() {
    local method id
    id="$(get_field null "$1" id)" || return 1
    method="$(get_str_field "$id" "$1" method)" || return 1

    case "$method" in
    "echo") handle_echo "$id" "$1" ;;
    "eval") handle_eval "$id" "$1" ;;
    *) err_not_found "$id" ;;
    esac
}

# This function uses the `script` command (not part of coreutils, but widely available since 3BSD)
# to create a PTY for the actual shell process. Therefore, we can run the shell interactively
# even though we're wrapping the input and output of the shell.
setup_inner_shell() {
    # create FIFOs to communicate with inner shell
    local stdin stdout stderr
    stdin="$TMPDIR/stdin"
    stdout="$TMPDIR/stdout"
    stderr="$TMPDIR/stderr"
    mkfifo -m 700 "$stdin" "$stdout" "$stderr"

    local inner_path
    inner_path="$(dirname "$0")/inner.bash"

    # `script` sends stdout and stderr to the same PTY.
    # we want stderr in a separate stream, so we will redirect within the command
    # this does unfortunately mean isatty(2) = 0, but hopefully this isn't a big issue or we can work around?
    script -qc "bash -il \"$inner_path\" 2>\"$stderr\"" /dev/null <"$stdin" >"$stdout" &
    INNER_PID="$!"

    # open file descriptors after starting `script` so inner shell doesn't inherit them
    # open with <> to avoid hanging
    exec 10<>"$stdin" 11<>"$stdout" 12<>"$stderr"
}

main() {
    exec 3>&1 # for error reporting
    setup_inner_shell
    while IFS='' read -r -d $'\0' object; do
        parse_command "$object" || true
    done
    sleep 3
}

main
