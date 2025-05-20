#!/usr/bin/env bash
# Inner eval-loop shell, controlled by HSP server

stty -echo
while IFS='' read -r -d $'\0' command; do
    eval "$command"
done
