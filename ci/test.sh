#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export LUA_PATH="$PWD/?/init.lua;${LUA_PATH:-;};;"
luajit tests/binding_test.lua
luarocks --lua-version=5.1 make --tree="$PWD/build/rocks" --deps-mode=none licensebox-0.2.0-1.rockspec
luarocks --lua-version=5.1 pack --tree="$PWD/build/rocks" licensebox
luarocks --lua-version=5.1 install --tree="$PWD/build/consumer" --deps-mode=none licensebox-0.2.0-1.all.rock
LUA_PATH="$PWD/build/consumer/share/lua/5.1/?.lua;$PWD/build/consumer/share/lua/5.1/?/init.lua;;" luajit -e 'local lb=require("licensebox");assert(lb.version=="0.2.0");assert(lb.native_binding("demo"):match("^m1:"))'
