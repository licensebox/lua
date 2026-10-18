#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export LUA_PATH="$PWD/?/init.lua;${LUA_PATH:-;};;"
exec luajit tests/adapter.lua
