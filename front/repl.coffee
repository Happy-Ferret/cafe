{ preprocess }        = require './preproc'
{ codegen }           = require '../back'
{ parse }             = require './parser'
child_process         = require 'child_process'
fs                    = require 'fs'
readline              = require 'readline'
compile_cache = []

## Compile and evaluate a string using the passed interpreter
eval_string = (str, interp, cb) ->
	tempFile = child_process.execSync 'mktemp', {encoding: 'utf8'}
	code = codegen(parse(preprocess(str))).join ';'

	if code.length >= 1
		try
			lua_process = child_process.spawn 'lua', {encoding: 'utf8', stdio: ['pipe', 1, 2]}
			if lua_process?.stdin?
				lua_process.stdin.write compile_cache.join ';\n;'
				lua_process.stdin.end ";\n" + code

				lua_process.on 'close', cb
			else
				console.log 'Failed to execSync'
		catch error
			console.error error
	else
		do cb

## Read history from disk
read_history = (int) ->
	if fs.existsSync int.historyFile
		JSON.parse fs.readFileSync int.historyFile
	else
		fs.writeFileSync int.historyFile, '[]'
		read_history int

## Save history to disk
save_history = (int) -> fs.writeFileSync int.historyFile, JSON.stringify int.history

## Determine Lua interpreter to use
interpr = do ->
	which = child_process.spawnSync 'which', ['luajit']
	if which?.status isnt 0
		'lua'
	else
		'luajit'

## Determine Lua interpreter version for the header
interpr_version = do ->
	base = child_process.execSync "#{interpr} -e \"print(_VERSION)\"",
		encoding: 'utf8'

	base.replace(/^Lua /gmi, '').replace(/\n$/gmi, '')

## Warm compilation cache by compiling the prelude
warm_cache = ->
	compile_cache.push codegen(parse(preprocess(fs.readFileSync './lib/prelude.cafe', {encoding: 'utf8'}))).join ';' + '\n'

## Compile a new module
compile = (module) ->
	resolve = (file) ->
		potential_files = [
			"./#{file}", "./#{file}.cafe",
			"./lib/#{file}", "./lib/#{file}.cafe",
			"/#{file}"
		]

		for file in potential_files
			if fs.existsSync file
				return file

	compile_cache.push codegen(parse(preprocess fs.readFileSync resolve(module), {encoding: 'utf8'})).join ';' + '\n'

plural = ->
	if compile_cache.length is '1'
		''
	else
		's'

module.exports.repl = ->
	console.log "Café REPL - Node #{process.version} - #{if interpr is 'luajit' then 'LuaJIT' else 'Lua'} #{interpr_version}"
	do warm_cache

	ri = readline.createInterface
		input: process.stdin
		output: process.stdout

	ri.historyFile = "/#{process.env.HOME}/.cafe_history"
	ri.setPrompt "\x1b[1;32mλ\x1b[0m> "
	ri.prompt()

	ri.history = read_history ri
	ri.on 'line', (line) ->
		line = do line.trim
		if line.startsWith ',dump' # Print the result of code-generating an expression
			console.log "\x1b[1;31m→\x1b[0m #{codegen(parse(preprocess(line.replace /^,dump /g, ''))).join ';'}"
			ri.prompt()
		else if line.startsWith ',import' # Import a module into the compile cache
			compile line.replace /^,import /gmi, ''
			console.log "\x1b[1;31m→\x1b[0m Imported #{line.replace /^,import /gmi, ''}. #{compile_cache.length} module#{do plural} currently compiled."
			ri.prompt()
		else
			eval_string do line.trim, interpr, -> ri.prompt()

	ri.on 'close', ->
		console.log "Have a great day!"
		save_history ri
