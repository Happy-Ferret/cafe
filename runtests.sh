#!/usr/bin/bash

for testsuite in $(grep test package.json | sed -re 's|\s*"(\S+)":.*$|\1|g' | grep test); do
	echo -e "\x1b[1;34m::\x1b[0m Testing with Lua $(echo $testsuite | sed -re 's/test(.*)$/\1/')"
	if npm run "$testsuite" | grep "passed"; then
		echo -e "\x1b[1;32m→\x1b[0m Test $testsuite passed!"
	else
		echo -e "\x1b[1;31m→\x1b[0m Test $testsuite failed!"
		exit
	fi
done

echo -e "\x1b[1;34m::\x1b[0m Generating documentation..."
npm run docs 1>/dev/null
echo -e "\x1b[1;34m::\x1b[0m Done!"
