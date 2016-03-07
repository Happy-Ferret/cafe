#!/usr/bin/coffee
{ parse, preprocess } = require './front'
{ codegen, emit }     = require './back'
{ optimize }          = require './middle'
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
  \x1b[1;32m--run\x1b[0m            Evaluate the compiled output.
"""


if argv['?']? or argv.h? or argv.help?
	console.log helpstr
	process.exit 0

if argv?._[0]?
	inp = argv._[0]
else if argv?.run? and typeof argv.run is 'string'
	inp = argv.run
else
	inp = '-'

if argv.d? or argv.docs?
	do_docout = true
else
	do_docout = false

if argv['doc-dir']?
	docdir = argv['doc-dir']
	do_docout = true


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
		fs.unlink fifo.replace(/\n+$/gmi, ''), (err) ->
			if err?
				console.log "Error unlinking REPL FIFO: #{err}"
else
	if argv.o? or argv.output?
		out = argv.o or argv.output
	else if argv.run? and !(argv.o?)
		out = child_process.execSync "mktemp -u '/tmp/.cafe.run_XXX'", {encoding: 'utf8'}
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

			emit out, ([hashbang].concat codegen(optimize parse preprocess(data, do_docout, docdir), ast)), ->
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
