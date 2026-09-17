#!/bin/sh
# Prints the make fragment `.nimble-resolution.mk` from a nimble.paths file.
# `?=` so a command-line or environment value (a local checkout) wins.
# A script, not a recipe: a backslash inside a make recipe reaches sh halved on
# native Windows make.
set -eu
paths=${1:?usage: nimble-resolution.sh <nimble.paths>}
norm() { tr '\\' '/' | sed 's#//#/#g'; }
sed -n -E 's#^--path:"(.*[/\\]prl_to_pc-[^"]*)"$#PRL_TO_PC_ROOT ?= \1#p' "$paths" | norm
sed -n -E 's#^--path:"([^"]*)"$#\1#p' "$paths" | norm | while IFS= read -r p; do
	if [ -f "$p/statusgo.nims" ]; then printf 'STATUSGO_SRC ?= %s\n' "$p"; break; fi
done
