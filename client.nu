#!/usr/bin/env nu

[{id: 123} "spam" {method: "fake", id: 123} {method: "echo", params: "hello", id: 123}]
| each { try { to json -r } | into binary | bytes add -e 0x[00] }
| bytes collect
| bash server.bash 
