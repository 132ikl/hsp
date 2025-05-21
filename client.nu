#!/usr/bin/env nu

let commands = [
  "spam", # parse error 
  {id: 0}, # invalid request (no method)
  {method: "fake", id: 1}, # method not found
  {method: "echo", params: "hello", id: 2}, # returns hello
  {method: "eval", params: "ls --color=auto", id: 3},
]

def handle-response [] {
  let response = bytes collect | decode | from json
  match $response.result? {
    {stdout: $stdout} => {
      $stdout | decode hex | decode | print -n
    },
    _ => ($response | table -e | print)
  }
}

$commands
| each {|e| sleep 500ms; $e | to json -r | into binary | bytes add -e 0x[00] }
| bytes collect
| bash server.bash
| chunks 1
| split list 0x[00]
| each { handle-response }
| ignore
