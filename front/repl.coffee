{ parse, symbol }     = require './parser'
{ preprocess }        = require './preproc'
{ codegen }           = require '../back'
child_process         = require 'child_process'
fs                    = require 'fs'
readline              = require 'readline'
compile_cache = []

## Compile and evaluate a string using the passed interpreter
arrow = "\x1b[1;31m→\x1b[0m"
eval_string = (str, interp, cb) ->
	tempFile = child_process.execSync 'mktemp', {encoding: 'utf8'}
	ast = parse(preprocess(str))

	if ast.length >= 1
		ast[ast.length - 1].is_tail = true
		code = codegen(ast).join ';'

		if code.length >= 1
			try
				lua_process = child_process.spawn 'lua', {encoding: 'utf8', stdio: ['pipe', 1, 2]}
				if lua_process?.stdin?
					lua_process.stdin.write compile_cache.join ';\n;'
					lua_process.stdin.end ";\n" + "io.write(\"#{arrow} \"); print(describe((function() #{code} end)(), true))"

					lua_process.on 'close', cb
				else
					console.log 'Failed to execSync'
			catch error
				console.error error
		else
			do cb
	else do cb

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

## Compile a new module
compile = (module) ->
	resolve = (file) ->
		potential_files = [
			"./#{file}", "./#{file}.cafe",
			"./lib/#{file}", "./lib/#{file}.cafe",
			"#{__dirname}/#{file}", "#{__dirname}/#{file}.cafe",
			"#{__dirname}/lib/#{file}", "#{__dirname}/lib/#{file}.cafe",
			"#{__dirname}/../#{file}", "#{__dirname}/../#{file}.cafe",
			"#{__dirname}/../lib/#{file}", "#{__dirname}/../lib/#{file}.cafe",
			"/#{file}"
		]

		for file in potential_files
			if fs.existsSync file
				return file

	if resolve(module)?
		compile_cache.push codegen(parse(preprocess fs.readFileSync resolve(module), {encoding: 'utf8'})).join ';' + '\n'
	else
		compile_cache.push codegen(parse(preprocess module)).join ';'

## Warm compilation cache by compiling the built-in modules
warm_cache = ->
	['prelude', 'math', 'hashmap'].map (x) -> compile x

plural = ->
	if compile_cache.length is '1'
		''
	else
		's'

module.exports.repl = (intpt) ->
	interpr = intpt ? interpr
	## Determine Lua interpreter version for the header
	interpr_version = do ->
		base = child_process.execSync "#{interpr} -e \"print(_VERSION)\"",
		encoding: 'utf8'

		base.replace(/^Lua /gmi, '').replace(/\n$/gmi, '')

	console.log "Café REPL - Node #{process.version} - #{if interpr is 'luajit' then 'LuaJIT' else 'Lua'} #{interpr_version}"
	do warm_cache

	ri = readline.createInterface
		input: process.stdin
		output: process.stdout

	ri.historyFile = "/#{process.env.HOME}/.cafe_history"
	ri.setPrompt "\x1b[1;32mλ\x1b[0m> "
	do ri.prompt

	ri.history = read_history ri
	ri.on 'line', (line) ->
		try
			line = do line.trim
			if line.startsWith ',dump' # Print the result of code-generating an expression
				console.log "#{arrow} #{codegen(parse(preprocess(line.replace /^,dump /g, ''))).join ';'}"
				do ri.prompt
			else if line.startsWith ',import' # Import a module into the compile cache
				compile line.replace /^,import /gmi, ''
				console.log "#{arrow} Imported #{line.replace /^,import /gmi, ''}. #{compile_cache.length} module#{do plural} currently compiled."
				do ri.prompt
			else if line.startsWith ',cache ' # Cache an expression in the compile Cache
				compile line.replace /^,cache /gmi, ''
				console.log "#{arrow} Cached #{line.replace /^,cache /gmi, ''}. #{compile_cache.length} module#{do plural} currently compiled."
				do ri.prompt
			else
				parsed = parse preprocess do line.trim
				skip = false
				for ast in parsed
					if ast.type is 'assignment' or ast.type is 'define_function'
						skip = true
						compile_cache.push codegen(ast)
						do ri.prompt
					else if ast.type is 'call_function'
						if ast.name is symbol 'require!'
							skip = true
							compile_cache.push codegen ast
							do ri.prompt
				if !skip
					eval_string do line.trim, interpr, -> do ri.prompt
		catch error
			console.error "\x1b[1;31m#{error}\x1b[0m"
			save_history ri
			process.exit 1

	ri.on 'close', ->
		console.log "Have a great day!"
		save_history ri
