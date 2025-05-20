#!/usr/bin/env bash
set -euo pipefail

# returns the first argument if the pipeline is empty,
# otherwise passes along the pipeline
default() {
    local first rest
    if [ ! -t 0 ] && IFS='' read -d '' -r -n 1 first; then
        echo "$first"
        cat
    else
        echo "$1"
    fi
}

# get JSON field, returning null normally
# params: json, field
try_get_field() {
    echo "$1" | jq --arg "key" "$2" '.[$key]' 2>&- || err_parse
}

# get JSON field, returning err_invalid_request on null
# params: json, field, err_id
get_field() {
    local field
    field="$(try_get_field "$1" "$2")" || return "$?"
    echo "$field" | non-null || err_invalid_request "$3"
}

get_str_field() {
    local field
    field="$(get_field "$1" "$2" "$3")" || return "$?"
    echo "$field" | jq -r
}

# set JSON(-RPC) key value pair with json argument
kv() {
    jq --argjson val "$2" ".$1=\$val"
}

# set JSON(-RPC) key value pair with string argument
kv_str() {
    jq --arg val "$2" ".$1=\$val"
}

non-null() {
    local input
    input="$(cat)"
    echo -n "$input"
    test "$input" != "null"
}

response_header() {
    jq -n '.jsonrpc="2.0"'
}

response_ok() {
    response_header |
        kv id "$1" |
        kv result "$2" >&3
}

err_invalid_request() {
    response_header |
        kv id "$1" |
        kv error.code -32600 |
        kv_str error.message 'Invalid request' >&3
    return 1
}

err_parse() {
    response_header |
        kv id null |
        kv_str error.message "Parse error" |
        kv error.code -32700 >&3
    return 1
}

err_not_found() {
    response_header |
        kv id "$1" |
        kv_str error.message "Method not found" |
        kv error.code -32601 >&3
    return 1
}

err_invalid_params() {
    response_header |
        kv id "$1" |
        kv_str error.message "Invalid params" |
        kv error.code -32602 >&3
    return 1
}

# params: id, params
handle_echo() {
    local params
    params="$(try_get_field "$2" "params")" || return 1
    params="$(echo "$params" | non-null)" || {
        err_invalid_params "$2"
        return 1
    }
    response_ok "$id" "$params"
}

parse_command() {
    local method id
    id="$(get_field "$1" id null)" || return 1
    method="$(get_str_field "$1" method "$id")" || return 1

    case "$method" in
    "echo") handle_echo "$id" "$1" ;;
    *) err_not_found "$id" ;;
    esac
}

main() {
    exec 3>&1 # for error reporting
    while IFS='' read -r -d $'\0' object; do
        parse_command "$object" || true
    done
}

main
