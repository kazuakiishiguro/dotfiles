#!/bin/bash

set -eu

rcup -d . -x README.md
unlink ~/.install.sh