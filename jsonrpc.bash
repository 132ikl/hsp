#!/usr/bin/env bash
# Basic JSON-RPC implementation
# Expects file descriptor 3 to be available for reporting errors

# get JSON field, returning null normally
# params: json, field
try_get_field() {
    echo "$1" | jq --arg "key" "$2" '.[$key]' 2>&- || err_parse
}

# get JSON field, reports err_invalid_request on null
# reports errors
# params: id, json, field
get_field() {
    local field
    field="$(try_get_field "$2" "$3")" || return 1
    echo "$field" | non-null || err_invalid_request "$1"
}

# params: json
into_string() {
    ty="$(echo "$1" | jq -r '. | type')"
    if [ "$ty" = "string" ]; then
        echo "$1" | jq -r
    else
        return 1
    fi
}

# get string JSON field, reports err_invalid_request on null or non-string
# params: id, json, field
get_str_field() {
    local field
    field="$(get_field "$@")" || return 1
    into_string "$field" || err_invalid_request "$1"
}

# gets parameter from JSON, reports err_invalid_params on missing parameter
# params: id, req_json, field
get_param() {
    local param field
    if [[ ! -v "3" ]]; then
        field="params"
    else
        field="params.$3"
    fi
    param="$(try_get_field "$2" "$field")" || return 1
    param="$(echo "$param" | non-null)" || {
        err_invalid_params "$1"
        return 1
    }
    echo "$param"
}

# set JSON(-RPC) key value pair with json argument
kv() {
    jq -r --argjson val "$2" ".$1=\$val"
}

# set JSON(-RPC) key value pair with string argument
kv_str() {
    kv "$1" "\"$2\""
}

non-null() {
    local input
    input="$(cat)"
    echo -n "$input"
    test "$input" != "null"
}

response_header() {
    jq -r -n '.jsonrpc="2.0"'
}

response_ok() {
    response_header |
        kv id "$1" |
        kv result "$2" >&3
    printf "\0" >&3
}

# params: id, stdout, done
response_stdout() {
    response_header |
        kv id "$1" |
        kv_str result.stdout "$2" |
        kv result.done "$3" >&3
    printf "\0" >&3
}

err_invalid_request() {
    response_header |
        kv id "$1" |
        kv error.code -32600 |
        kv_str error.message 'Invalid request' >&3
    printf "\0" >&3
    return 1
}

err_parse() {
    response_header |
        kv id null |
        kv_str error.message "Parse error" |
        kv error.code -32700 >&3
    printf "\0" >&3
    return 1
}

err_not_found() {
    response_header |
        kv id "$1" |
        kv_str error.message "Method not found" |
        kv error.code -32601 >&3
    printf "\0" >&3
    return 1
}

err_invalid_params() {
    response_header |
        kv id "$1" |
        kv_str error.message "Invalid params" |
        kv error.code -32602 >&3
    printf "\0" >&3
    return 1
}
