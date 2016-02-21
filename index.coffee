#!/usr/bin/coffee
{ parse, preprocess } = require './front'
{ codegen, emit }     = require './back'
fs                    = require 'fs'
readline              = require 'readline'
child_process         = require 'child_process'


inp = process.argv[2] ? '/dev/stdin'
out = process.argv[3] ? "#{inp}.lua"
ast = process.argv[4] ? "#{inp}.ast.json"

prelude = codegen(parse(preprocess(fs.readFileSync './lib/prelude.cafe', {encoding: 'utf8'}))).join ';'

eval_string = (str, cb) ->
	tempFile = child_process.execSync 'mktemp', {encoding: 'utf8'}
	code = codegen(parse(preprocess(str))).join ';'

	try
		lua_process = child_process.spawn 'lua', {encoding: 'utf8', stdio: ['pipe', 1, 2]}
		if lua_process?.stdin?
			lua_process.stdin.write prelude + '; '
			lua_process.stdin.end code

			lua_process.on 'close', cb
		else
			console.log 'Failed to execSync'
	catch error
		console.error error


if inp is '/dev/stdin' or inp is '-'
	ri = readline.createInterface process.stdin, process.stdout
	ri.setPrompt "\x1b[1;32mλ\x1b[0m> "
	ri.prompt()

	ri.on 'line', (line) ->
		eval_string do line.trim, -> ri.prompt()
	.on 'close', -> console.log "Have a great day!"

else
	fs.readFile inp, {encoding: 'utf-8'}, (err, data) ->
	if err
		throw err

	emit out, codegen parse preprocess(data), ast
