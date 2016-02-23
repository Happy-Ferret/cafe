#!/usr/bin/coffee
{ parse, preprocess } = require './front'
{ codegen, emit }     = require './back'
{ resolve }           = require 'path'
{ repl }              = require './front/repl'
{ argv }              = require 'optimist'
fs                    = require 'fs'
readline              = require 'readline'
child_process         = require 'child_process'


helpstr = """
usage: \x1b[1;34mcafe\x1b[0m <input> [-o/--output file] [-a,--ast file] | [--repl] [--interpreter lua/luajit]

Available options are:
  \x1b[1;32m--repl/-r\x1b[0m        Start a café REPL.
  \x1b[1;32m-i/--interpreter\x1b[0m Set the interpreter for use with the REPL.
  \x1b[1;32m-o/--output\x1b[0m      Set the output file.
  \x1b[1;32m-a/--ast\x1b[0m         Set the AST output file.
  \x1b[1;32m-?/-h/--help\x1b[0m     Print this help and exit.
  \x1b[1;32m-d/--docs\x1b[0m        Emit documentation.
  \x1b[1;32m--doc-dir\x1b[0m        Specify where to emit documentation to.
  \x1b[1;32m--hashbang\x1b[0m       Specify a custom #! line for executables.
"""


if argv['?']? || argv.h? || argv.help?
	console.log helpstr
	process.exit 0

if argv?._[0]?
	inp = argv._[0]
else
	inp = '-'

if argv.d? || argv.docs?
	do_docout = true
else
	do_docout = false

if argv['doc-dir']?
	docdir = argv['doc-dir']
	do_docout = true


interp = do ->
	if argv.i? || argv.interpreter?
		argv.interpreter ? argv.i
	else
		which = child_process.spawnSync 'which', ['luajit']
		if !(which?) || which?.status isnt 0
			'lua'
		else
			'luajit'


if argv.hashbang?
	hashbang = argv.hashbang
else
	hashbang = "#!/usr/bin/env #{argv.interpreter || argv.i ? "lua"}"

if inp is '/dev/stdin' or inp is '-'
	repl argv.interpreter ? 'lua'
else
	if argv.o? || argv.output?
		out = argv.o || argv.output
	else
		out = 'out.lua'

	if argv.a? || argv.ast?
		ast = argv.a || argv.ast
	else
		ast = '/dev/null'

	if fs.existsSync inp
		fs.readFile inp, {encoding: 'utf-8'}, (err, data) ->
			if err?
				throw err

			emit out, ([hashbang].concat codegen(parse preprocess(data, do_docout, docdir), ast)), ->
				fs.chmodSync out, 0o755
	else
		console.log "\x1b[1;31m→\x1b[0m No such file #{inp}."
