#!/bin/sh
printf '\033c\033]0;%s\a' Terry -Your Terra Companion!
base_path="$(dirname "$(realpath "$0")")"
"$base_path/Terry -Your Terra Companion!.x86_64" "$@"
