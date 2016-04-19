#!/usr/bin/env coffee
{ parse, preprocess } = require './front'
{ codegen, emit }     = require './back'
{ resolve }           = require 'path'
{ repl }              = require './front/repl'
{ optimize }          = require './middle/optimizer'
{ argv }              = require 'optimist'
fs                    = require 'fs'
readline              = require 'readline'
child_process         = require 'child_process'


helpstr = """
usage: \x1b[1;34mcafe\x1b[0m <input> [-o/--out file] [-a,--ast file] | [--repl] [--interpreter lua/luajit]

Available options are:
	\x1b[1;32m--repl/-r\x1b[0m        Start a café REPL.
	\x1b[1;32m-i/--interpreter\x1b[0m Set the interpreter for use with the REPL.
	\x1b[1;32m-o/--out\x1b[0m         Set the output file.
	\x1b[1;32m-a/--ast\x1b[0m         Set the AST output file.
	\x1b[1;32m-?/-h/--help\x1b[0m     Print this help and exit.
	\x1b[1;32m--hashbang\x1b[0m       Specify a custom #! line for executables.
	\x1b[1;32m--run\x1b[0m            Evaluate the compiled output.
	\x1b[1;32m--mini\x1b[0m           Compile with minilib instead of the prelude.
"""


if argv['?']? or argv.h? or argv.help?
	console.log helpstr
	process.exit 0

if argv?._[0]?
	inp = argv._[0]
else if argv?.run? and typeof argv.run is 'string'
	inp = argv.run
else if argv?.mini? and typeof argv.mini is 'string'
	inp = argv.mini
else
	inp = '-'


interp = do ->
	if argv.i? or argv.interpreter?
		argv.interpreter ? argv.i
	else
		'lua'


if argv.hashbang?
	hashbang = argv.hashbang
else
	hashbang = "#!/usr/bin/env #{argv.interpreter or argv.i ? "lua"}"

if inp is '/dev/stdin' or inp is '-'
	repl interp, (fifo) ->
		if fs.existsSync(fifo)
			fs.unlink fifo.replace(/\n+$/gmi, ''), (err) ->
				if err?
					console.log "Error unlinking REPL FIFO: #{err}"
else
	if argv.o? or argv.out?
		out = argv.o or argv.out
	else if argv.run? and !(argv.o?)
		out = child_process.execSync("mktemp -u '/tmp/.cafe.run_XXX'", {encoding: 'utf8'}).replace /\n$/gmi, ''
	else
		out = 'out.lua'

	if argv.a? or argv.ast?
		ast = argv.a or argv.ast
	else
		ast = '/dev/null'

	if fs.existsSync inp
		fs.readFile inp, {encoding: 'utf-8'}, (err, data) ->
			if err?
				throw err

			if argv.mini?
				data = ";;@import minilib\n#{data}"
			else
				data = ";;@import prelude\n#{data}"

			fs.writeFile out, hashbang + "\n", ->
				emit out, (codegen(optimize parse(preprocess(data, inp, null, interp), ast))), ->
					if argv.run?
						process.stdout.write "\x1b[0m"
						proc = child_process.spawn "#{interp}", ["#{out}"], {encoding: 'utf-8', stdio: 'inherit'}
						proc.on 'close', (status) ->
							console.log "#{interp} process (#{proc.pid}) exited with status code #{status}."
							fs.chmodSync out, 0o755 if argv.o? or argv.out?
							if !(argv.o? or argv.out?)
								fs.unlink out
					else fs.chmodSync out, 0o755

	else
		console.log "\x1b[1;31m→\x1b[0m No such file #{inp}."
