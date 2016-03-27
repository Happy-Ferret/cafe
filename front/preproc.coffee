{ execSync } = require 'child_process'
fs = require 'fs'
path = require 'path'

resolve_module = (file, fnam) ->
	potential_files = [
		"./#{file}", "./#{file}.cafe",
		"./lib/#{file}", "./lib/#{file}.cafe",
		"#{__dirname}/#{file}", "#{__dirname}/#{file}.cafe",
		"#{__dirname}/lib/#{file}", "#{__dirname}/lib/#{file}.cafe",
		"#{__dirname}/../#{file}", "#{__dirname}/../#{file}.cafe",
		"#{__dirname}/../lib/#{file}", "#{__dirname}/../lib/#{file}.cafe",
		"/#{file}"
	]

	if fnam?
		potential_files = potential_files.concat [
			"#{path.dirname path.resolve fnam}/#{file}", "#{path.dirname path.resolve fnam}/#{file}.cafe",
			"#{path.dirname path.resolve fnam}/lib/#{file}", "#{path.dirname path.resolve fnam}/lib/#{file}.cafe",
		]

	for file in potential_files
		if fs.existsSync file
			return file
module.exports.resolve = resolve_module

defines = {}
filter = false
commands =
	import: (params, context) ->
		file = params[1]
		fnam = context.file_name
		lines = context.lines
		context.modules = {} if !context.modules?

		params.slice(1).map (file) ->
			modfile = resolve_module file, context.file_name
			if modfile?
				if !context.modules?[modfile]?
					mod_contents = fs.readFileSync(modfile, {encoding: 'utf8'})

					context.modules[modfile] = true
					lines.push module.exports.preprocess mod_contents, path.dirname(path.resolve modfile), context, context.interpreter
				else
					console.log "Not importing #{file} because it's already imported"
			else
				console.error "\x1b[1;31m→\x1b[0m No such module #{file}. Compilation halted."
				process.exit 1
	define: (params, context) ->
		defines[params[1]] = params[2] ? true
	ifdef: (params, context) ->
		if defines[params[1]]?
			filter = false
		else
			filter = true
	ifndef: (params) ->
		if defines[params[1]]?
			filter = true
		else
			filter = false
	version: (params, context) ->
		expect = Math.round (parseFloat(params[1]) * 10)|0
		got    = Math.round (context.interpreter_version * 10)|0
		Math.isInteger
		if params[2] is 'eq'
			filt = expect == got
		else
			filt = expect <= got

		filter = not filt
	warn: (params) ->
		console.log "\x1b[1;33mwarning:\x1b[0m #{params.slice(1).join ' '}"

	else: (params) -> filter = !filter
	end: (params) -> filter = false

get_interp_version = (int) ->
	base = execSync "#{int} -e \"print(_VERSION)\"",
		encoding: 'utf8'

	base.replace(/^Lua /gmi, '').replace(/\n$/gmi, '')


module.exports.preprocess = (contents, fnam, context, interp = 'lua') ->
	lines = []
	command_context = context ?
		file_name: fnam
		file_contents: contents
		lines: lines
		interpreter: interp
		interpreter_version: get_interp_version interp

	contents.split('\n').map (line, ln) ->
		line = do line.trim
		command = line.match /;;@(\w+)/
		if !filter
			if command?
				if commands[command[1] ? 'nop']?
					commands[command[1] ? 'nop'] line.split(' ').filter((x) -> x?).map((x) -> do x.trim), command_context
				else lines.push line
			else lines.push line
		else if command?[1] is 'end'
			filter = false
		else if command?[1] is 'else'
			filter = !filter
	lines.join '\n'
