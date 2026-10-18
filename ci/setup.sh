#!/usr/bin/env bash
set -euo pipefail
sudo apt-get update
sudo apt-get install -y luajit lua-cjson luarocks liblua5.1-0-dev lua5.1
