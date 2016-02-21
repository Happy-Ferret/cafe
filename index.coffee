#!/usr/bin/coffee
{ parse, preprocess } = require './front'
{ codegen, emit }     = require './back'
{ resolve }           = require 'path'
{ repl }              = require './front/repl'
{ argv }              = require 'optimist'
fs                    = require 'fs'
readline              = require 'readline'
child_process         = require 'child_process'


if argv?._[0]?
	inp = argv._[0]
else
	inp = '-'


if inp is '/dev/stdin' or inp is '-'
	do repl
else
	if argv.o? || argv.output?
		out = argv.o || argv.output
	else
		out = 'out.lua'

	if argv.ast?
		ast = argv.ast
	else
		ast = '/dev/null'

	fs.readFile inp, {encoding: 'utf-8'}, (err, data) ->
		if err?
			throw err

		fs.writeFile out, '#!/usr/bin/env lua\n', (err) ->
			if err?
				throw err

			emit out, codegen(parse preprocess(data), ast), ->
				fs.chmodSync out, 0o755
