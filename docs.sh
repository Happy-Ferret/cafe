#!/usr/bin/bash

for file in lib/*.cafe; do
	cafe --out out.lua --docs --doc-dir "doc" "$file"
done
