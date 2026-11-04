#!/bin/sh
# Headless checks: parse every script, then run the gameplay test suite.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
"$ROOT/tools/dev-run.sh" --headless res://tests/check_scripts.tscn
"$ROOT/tools/dev-run.sh" --headless res://tests/run_tests.tscn
