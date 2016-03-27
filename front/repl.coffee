{ preprocess, resolve } = require './preproc'
{ parse, symbol }       = require './parser'
{ codegen }             = require '../back'
child_process           = require 'child_process'
fs                      = require 'fs'
readline                = require 'readline'

arrow = "\x1b[1;31m→\x1b[0m"

## Install special REPL functions
compile_cache = [
	"""
	function io.read()
		return 'io.read is unimplemented in the REPL'
	end
	""", """
	function repl_describe(expr)
		if expr ~= nil then
			io.write(\"#{arrow}\ ")
			print(describe(expr, true))
		end
	end
	""",
	"""
	function print(...)
		__print33__(__42standard45output42__, tostring(...))
	end
	"""
]


interpr = do ->
	which = child_process.spawnSync 'which', ['luajit']
	if which?.status isnt 0
		'lua'
	else
		'luajit'

## Use the same file for all operations.
file = do ->
	temp = child_process.execSync "mktemp -u '/tmp/.cafe.repl.file_XXX'", {encoding: 'utf8'}
	temp.replace /\n+$/gmi, ''

error_report = (err, interpr, code) ->
	is_call = (str) -> (str.indexOf 'attempt to call') isnt -1
	call_sym = (str) ->
		luajit_call = new RegExp "#{interpr}: #{file}:(\\d+): attempt to call global '(.+)' \\(a nil value\\)"
		lua_call = new RegExp "#{interpr}: #{file}:(\\d+): attempt to call a nil value \\(global '(.+)'\\)"
		if luajit_call.test str
			match = str.match luajit_call
		else
			match = str.match lua_call

		console.error "#{arrow} ERROR: Attempt to call undefined symbol #{match[2]}"
		console.error "  #{arrow} in line #{match[1]}: #{code.split(/\r?\n/)[(parseFloat match[1]) - 1] ? "no such line"}"

	err = err.join '\n'
	err.split(/\r?\n/gmi).map (x) ->
		x = do x.trim
		if new RegExp("\\t*[\\w/.]+:\\d+: ").test x
			if is_call x
				call_sym x
			else console.error x
		else console.error x

## Compile and evaluate a string using the passed interpreter
eval_string = (str, interp, cb) ->
	tempFile = child_process.execSync 'mktemp', {encoding: 'utf8'}
	ast = parse(preprocess(str))
	interp ?= interpr

	if ast.length >= 1
		ast[ast.length - 1].is_tail = true
		code = do ->
			"#{compile_cache.join ';\n'};\nrepl_describe((function() #{codegen(ast).join ';'} end)(), true)"

		if code.length >= 1
			fs.writeFile file, code, ->
				try
					lua_process = child_process.spawn interp, [file], {encoding: 'utf8', stdio: ['ignore', 1, 'pipe']}
					stderr = []
					if lua_process?
						lua_process.stderr.on 'data', (x) ->
							stderr.push x.toString 'utf8'

						lua_process.on 'close', (status) ->
							if status isnt 0
								error_report stderr, interp, code
							do cb
					else
						console.log 'Failed to execSync'
				catch error
					console.error error
					do cb
		else do cb
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


## Compile a new module
compile = (module) ->
	if resolve(module)?
		compile_cache.push codegen(parse(preprocess fs.readFileSync resolve(module), {encoding: 'utf8'})).join ';' + '\n'
	else
		compile_cache.push codegen(parse(preprocess module)).join ';'

## Warm compilation cache by compiling the built-in modules
warm_cache = ->
	['prelude'].map (x) -> compile x
plural = ->
	if compile_cache.length is '1'
		''
	else
		's'

module.exports.repl = (intpt, cb) ->
	interpr = intpt ? interpr
	## Determine Lua interpreter version for the header
	interpr_version = do ->
		base = child_process.execSync "#{interpr} -e \"print(_VERSION)\"",
		encoding: 'utf8'

		base.replace(/^Lua /gmi, '').replace(/\n$/gmi, '')

	console.log "Café REPL - Node #{process.version} - Lua (#{interpr}) #{interpr_version}"
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
			else if line.startsWith ',view-cache'
				console.log compile_cache.join ';\n'
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
				if not skip
					eval_string do line.trim, interpr, -> do ri.prompt
		catch error
			console.error "\x1b[1;31m#{error}\x1b[0m"
			save_history ri
			cb file
			process.exit 1

	ri.on 'close', ->
		console.log "Have a great day!"
		save_history ri
		cb file
