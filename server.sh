#!/usr/bin/env sh
set -eu

error() {
    echo "$1" >&2
    exit 1
}

read_hex_byte() {
    # adapted from https://www.etalabs.net/sh_tricks.html
    # we could see a null byte, which cannot be stored in a variable, so encode in hex
    # could be more performant/avoid fork with read -n in bash
    read -r _ byte <<EOF
$(dd bs=1 count=1 status=none | od -t x1)
EOF
    echo "$byte"
}

is_integer() {
    # adapted from https://unix.stackexchange.com/a/598047/297758
    case "$1" in
    [0123456789]*) return 0 ;;
    *) return 1 ;;
    esac
}

hex_to_dec() {
    if ! is_integer "$1"; then
        error "Length bytes are not an integer"
    fi
    if [ "$1" -lt 30 ] || [ "$1" -gt 39 ]; then
        error "Length byte out of range"
    fi
    echo "$(($1 - 30))"
}

read_length() {
    MAX_LENGTH=10
    out=""
    i=0
    while [ "$i" -le "$MAX_LENGTH" ]; do
        byte="$(read_hex_byte)"
        # if semicolon delimiter is detected return length
        if [ "$byte" = "3a" ]; then
            echo "$out"
            return
        fi
        digit="$(hex_to_dec "$byte")"
        out="${out}${digit}"
        i=$((i + 1))
    done
    error "Length more than 10 digits"
}

parse_netstring() {
    read_length
}

parse_command() {
    parse_netstring
    exit 0
}

eval_command() {
    eval "$1"
}

main() {
    eval_command "echo hello world"

    # while true; do
    #     parse_command
    # done
}

main
