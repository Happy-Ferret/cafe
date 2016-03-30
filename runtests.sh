#!/usr/bin/env bash

for testsuite in $(grep test package.json | sed -re 's|\s*"(\S+)":.*$|\1|g' | grep test); do
	echo -e "\x1b[1;34m::\x1b[0m Testing with $(lua$(echo $testsuite | sed -re 's/test(.*)$/\1/') -e 'print(_VERSION);') (lua$(echo $testsuite | sed -re 's/test(.*)$/\1/'))"
	if which lua$(echo $testsuite | sed -re 's/test(.*)$/\1/') >/dev/null; then
		if npm run "$testsuite" | grep "status code 0" &>/dev/null; then
			echo -e "  \x1b[1;32m→\x1b[0m Test $testsuite passed!"
			rm -rf "$(echo "$testsuite" | sed -re 's/test/&s/;s/\.//g').lua"
		else
			echo -e "  \x1b[1;31m→\x1b[0m Test $testsuite failed!"
			exit
		fi
	else
		echo -e "  \x1b[1;32m→\x1b[0m No interpreter for $testsuite, skipping.."
	fi
done

echo -e "\x1b[1;34m::\x1b[0m Generating documentation..."
npm run docs 1>/dev/null
echo -e "\x1b[1;34m::\x1b[0m Done!"
