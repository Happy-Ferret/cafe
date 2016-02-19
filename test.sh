#!/usr/bin/bash

coffee index.coffee 2> ast.json > executable.lua
lua executable.lua

if [[ $? != 0 ]]; then
	less ast.json
	less executable.lua
fi
