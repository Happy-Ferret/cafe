#!/usr/bin/bash

coffee index.coffee 2> ast.json > executable.lua
lua executable.lua

echo "exited with $?"
