#!/usr/bin/env bash
# Extracted from Makefile so it runs without the Makefile's prerequisites (Qt, nimble).
git clean -qfdx
# nuke vendor, they're regenerated anyways
rm -rf vendor
rm -rf mobile/vendors
