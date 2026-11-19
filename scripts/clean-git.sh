#!/usr/bin/env bash
# Cleans the checkout and removes the submodule checkouts.
git clean -qfdx
# nuke vendor, they're regenerated anyways
rm -rf vendor
rm -rf mobile/vendors
