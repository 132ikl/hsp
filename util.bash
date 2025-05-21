#!/usr/bin/env bash
# Server utilities

error() {
    echo "Error: $1" >&2
    exit 1
}

cleanup() {
    # clear trap in case of additional signal
    trap : 0 1 2 3 6

    if [[ -n "$INNER_PID" ]] && ps "$INNER_PID" >/dev/null 2>&1; then
        kill -INT "$INNER_PID"
        # prevent `script` from writing to terminal
        # this only seems to really work for normal exits
        # kill -STOP "$INNER_PID"
    fi

    # avoid rm -rf just to be safe
    rm -f "$TMPDIR/stdin"
    rm -f "$TMPDIR/stdout"
    rm -f "$TMPDIR/stderr"
    rmdir "$TMPDIR"
}

get_runtime_dir() {
    if [[ -v "XDG_RUNTIME_DIR" ]]; then
        echo "$XDG_RUNTIME_DIR"
    elif [[ -w "/run/user/$UID" ]]; then
        echo "/run/user/$UID"
    elif [[ -w "/tmp/" ]]; then
        echo "/tmp"
    else
        error "Unable to find suitable temporary directory!"
    fi
}

create_tmpdir() {
    mktemp -dp "$(get_runtime_dir)" "hsp-bash-$UID.XXXXXXXXXX"
}
