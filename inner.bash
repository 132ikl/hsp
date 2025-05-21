#!/usr/bin/env bash
# Inner eval-loop shell, controlled by HSP server

source common.bash

stty -echo
while IFS='' read -r -d $'\0' command; do
    eval "$command"
    osc 133 D ""
done
