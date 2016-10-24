{ macros, parse, symbol } = require './parser'
{ preprocess, resolve }   = require './preproc'
{ ast2cafe }              = require '../back/ast2cafe'
{ codegen }               = require '../back'
child_process             = require 'child_process'
readline                  = require 'readline'
fs                        = require 'fs'

arrow = "\x1b[1;31m→\x1b[0m"

## Install special REPL functions
compile_cache = []
repl_special = [
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

preproc_context = {
	file_name: '<REPL>',
	interpreter: '<REPL>',
	interpreter_version: '5.2',
	silent: true
}

eval_string = (str, state, cb) ->
	ast = parse(preprocess(str, null, preproc_context, null))

	if ast.length >= 1
		ast[ast.length - 1].is_tail = true
		code = do ->
			"repl_describe((function()\n#{codegen(ast, "return ").join ';'}\nend)(), true)"

		try
			state.execute code
			do cb
		catch e
			console.error e.message.replace /\[string "\?"\]:2:/, "#{arrow} \x1b[1;31mlua error:\x1b[0m"
			do cb

## Read history from disk
read_history = (int) ->
	if fs.existsSync int.historyFile
		JSON.parse fs.readFileSync int.historyFile
	else
		fs.writeFileSync int.historyFile, '[]'
		read_history int

save_history = (int) -> fs.writeFileSync int.historyFile, JSON.stringify int.history

compile = (module, state) ->
	code = if resolve(module)?
		codegen(parse(preprocess fs.readFileSync(resolve(module), {encoding: 'utf8'}), null, preproc_context, null), null, false, false).join ';' + '\n'
	else
		codegen(parse(preprocess(module, null, preproc_context, null)), null, false, false).join '\n;'

	state.execute code

## Warm compilation cache by compiling the built-in modules
warm_cache = (state) ->
	['prelude', 'math', 'hashmap'].map (x) -> compile x, state
	repl_special.map (x) -> state.execute x
plural = ->
	if compile_cache.length is '1'
		''
	else
		's'

module.exports.repl = (intpt, cb) ->
	state = new (require('lua.vm.js')).Lua.State

	state.pushnil(); state.setglobal 'js'

	console.log "Café REPL - Node #{process.version} - #{state._G.get '_VERSION'}"
	warm_cache state

	ri = readline.createInterface
		input: process.stdin
		output: process.stdout

	ri.historyFile = "#{process.env.HOME || process.env.USERPROFILE}/.cafe_history"
	ri.setPrompt "\x1b[1;32mλ\x1b[0m> "
	do ri.prompt

	ri.history = read_history ri
	ri.on 'line', (line) ->
		try
			line = do line.trim
			if line.startsWith ',dump' # Print the result of code-generating an expression
				console.log "#{arrow} #{codegen(parse(preprocess(line.replace(/^,dump /g, ''), null, preproc_context, null))).join ';'}"
				do ri.prompt
			else if line.startsWith ',view-ast'
				console.log "#{arrow} #{JSON.stringify parse(preprocess(line.replace(/^,view-ast /g, ''), null, preproc_context, null)), null, ' '}"
				do ri.prompt
			else if line.startsWith ',macro-expand'
				code = parse preprocess line.replace(/^,macro-expand /g, ''), null, preproc_context, null
				console.log "#{arrow} #{ast2cafe(code).join('')}"
				do ri.prompt
			else if line.startsWith ',import' # Import a module into the compile cache
				compile line.replace(/^,import /gmi, ''), state
				do ri.prompt
			else
				eval_string do line.trim, state, -> do ri.prompt
		catch error
			console.error "\x1b[1;31mAn exception was thrown: \x1b[0m#{error}\x1b[0m"
			do ri.prompt

	ri.on 'close', ->
		try
			console.log "Have a great day!"
			save_history ri
			cb ''
		catch e
