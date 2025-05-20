#!/usr/bin/env nu

let commands = [
  "spam", # parse error 
  {id: 0}, # invalid request (no method)
  {method: "fake", id: 1}, # method not found
  {method: "echo", params: "hello", id: 2}, # returns hello
  {method: "eval", params: "ls --color=auto", id: 3},
  {method: "stdout", id: 4}
]

$commands
| each {|e| sleep 100ms; $e | to json -r | into binary | bytes add -e 0x[00] }
| bytes collect
| bash server.bash
