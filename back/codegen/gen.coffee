{ symbol
, toks2ast } = require '../../front'
fs         = require 'fs'

actual_opch = (opch) -> opch
indentinc = /\b(else|elseif|(local\s+)?function|then|do|repeat)\b((?!end).)*$|\{\s*$/
indentdec = /^(end|until)/
indentdic = /^else/

lua_indent_func = (frag) ->
	ci = 0
	ni = 0

	meat = frag.split(/\r?\n/).map (line) ->
		if line?
			line = do line.trim
			ci = ni

			if indentinc.test line
				ni = ci + 1

			if indentdec.test line
				ni = ci = ci - 1

			if indentdic.test line
				ci = ci - 1
				ni = ci + 1

			if ci >= 1
				'\t'.repeat(ci) + line
			else
				line
		else
			''
	.map (line) ->
		if indentinc.test line or indentdic.test line or indentdec.test line
			if /;$/gmi.test line
				line = line.replace /;*$/gmi, ''
			else line
		else line
	.join('\n')

	meat.replace /;{2,}$/gm, ''

class Generator
	constructor: ->
		@text = []

	startBlock: (str) =>
		@write str

	endBlock: (str) =>
		if str?
			@write str
		else
			@write 'end'

	write: (txt) =>
		if typeof txt is 'string' and txt.length > 0
			_ = @text.push txt
			null
		else
			if txt?.map?
				txt.map @write

	join: (joiner, indent_func = lua_indent_func) =>
		t = @text.join joiner
		if indent_func?
			indent_func t
		else
			t


is_lua_expr = (node) ->
	typeof node isnt "object" or node.type in ['call_function', 'lambda_expr', 'variable', 'raw']

module.exports.codegen = (ast, terminate) ->
	decd_funs = {}

	codegen_function_body = (expr, gen) ->
		body = expr.body.slice(0, -1).map block_codegen
		last_expr = expr.body.slice(-1)[0]

		if body? and last_expr?
			last_expr = intermediate_codegen last_expr, "return ", true

			body.map gen.write
			gen.write last_expr
		else ''

		gen.join ';\n'

	codegen_function = (expr, terminate) ->
		if terminate? and terminate isnt "" and terminate isnt "return " then throw new Error("Cannot use function as an expression: " + terminate)
		gen = new Generator()
		if expr.name? and expr.args?.join? and expr.body?
			decd_funs[expr.name] = {expr} if !decd_funs[expr.name]?

			gen.startBlock "function #{expr.name}(#{expr.args.join ', '})"
			codegen_function_body expr, gen
			gen.endBlock "end"

		gen.join ';\n'

	codegen_call = (expr, terminate) ->
		gen = new Generator()
		if expr.name? and expr.args?
			if undefined in expr.args
				console.log expr
			gen_name = (x) ->
				if x.type is 'variable'
					x.name
				else
					"(#{expr_codegen expr.name})"
			gen.write "#{terminate ? ""}#{gen_name expr.name}(#{expr.args?.map?(expr_codegen).join ', '})"

		gen.join ';\n'

	codegen_raw = (expr, terminate) ->
		gen = new Generator()
		if expr.body.length >= 1
			gen.write expr.body.slice(0, -1)

			last_expr = expr.body.slice(-1)[0]
			if terminate?
				if last_expr.startsWith "return "
					last_expr = last_expr.replace /^return /gmi, ''
					gen.write "#{terminate ? ""}#{last_expr}"
				else if terminate is "return "
					gen.write last_expr
				else
					throw (new Error("Cannot use raw statement '#{last_expr}' as an expression for #{terminate}"))
			else
				gen.write last_expr
			gen.join ';\n'

	codegen_scoped_block = (expr, terminate, scope_top) ->
		gen = new Generator()
		if expr.vars? and expr.body?
			vars = expr.vars.map (v) ->
				if v[0]? and v[1]? # Gracefully handle empty variables
					names = if v[0] instanceof Array then v[0].join ", " else v[0]
					if is_lua_expr v[1]
						"local #{names} = #{expr_codegen v[1]}"
					else
						temps = if v[0] instanceof Array then v[0].map((x) -> "__temp_" + x).join ", " else "__temp_" + v[0]
						"local #{temps}\n#{intermediate_codegen v[1], "#{temps} = "}\n#{names} = #{temps}"

			wrap = false
			if terminate is ''
				# If an expression is required then we wrap in a function
				# This will only occur in function calls.
				wrap = true
				terminate = "return "
				gen.startBlock "(function(...)"
			else if not scope_top
				gen.startBlock "do"

			if expr.body.length >= 1 # Gracefully handle empty blocks
				body = expr.body.slice(0, -1).map block_codegen
				last_expr = expr.body.slice(-1)[0]
				last_expr = intermediate_codegen last_expr, terminate
			else
				body = ''
				last_expr = ''

			gen.write vars
			gen.write body
			gen.write last_expr
			if wrap
				gen.endBlock 'end)(table.unpack(args or {}))'
			else if not scope_top
				do gen.endBlock
		gen.join ';\n'

	codegen_conditional = (expr, terminate) ->
		gen = new Generator()

		if expr.cond? and (expr.trueb? or expr.falseb?)
			wrap = false
			if terminate is ''
				# If an expression is required then we wrap in a function
				# This will only occur in function calls.
				wrap = true
				terminate = "return "
				gen.startBlock "(function(...)"
			if is_lua_expr expr.cond
				gen.startBlock "if #{expr_codegen expr.cond} then"
			else
				gen.write "local __cond"
				gen.write intermediate_codegen expr.cond, "__cond = "
				gen.startBlock "if __cond then"

			if expr.trueb?
				gen.write intermediate_codegen expr.trueb, terminate, true

			if expr.falsb?
				while expr? and (expr.falsb?.type is "conditional") and (is_lua_expr expr.falsb.cond)
					gen.write "elseif #{expr_codegen expr.falsb.cond} then"
					expr = expr.falsb
					gen.startBlock intermediate_codegen expr.trueb, terminate, true

				if expr?
					gen.endBlock "else"
					gen.startBlock intermediate_codegen expr.falsb, terminate, true

			do gen.endBlock

			if wrap
				gen.endBlock 'end)(table.unpack(args or {}))'
		gen.join ';\n'

	codegen_lambda_expr = (expr, terminate) ->
		# Lambdas can be ignored
		if not terminate?
			return null

		gen = new Generator()
		if expr.args? and expr.body?
			gen.startBlock "#{terminate ? ""}function(#{expr.args.join ', '})"
			codegen_function_body expr, gen
			do gen.endBlock
		gen.join ';\n'

	codegen_assignment = (expr, terminate) ->
		if terminate? and terminate isnt "return " then throw new Error("Cannot use assignment as an expression: " + terminate)

		gen = new Generator()
		if expr.name? and expr.value?
			names = if expr.name instanceof Array then expr.name.join ", " else expr.name
			if expr.local? and expr.local
				if is_lua_expr expr.value
					gen.write "local #{names} = #{expr_codegen expr.value}"
				else
					temps = if expr.name instanceof Array then expr.name.map((x) -> "__temp_" + x).join ", " else "__temp_" + expr.name
					gen.write "local #{temps}"
					gen.write(intermediate_codegen expr.value, "#{temps} = ")
					gen.write "local #{names} = #{temps}"
			else
				gen.write(intermediate_codegen expr.value, "#{names} = ")


		gen.join '\n'

	codegen_self_call = (expr, terminate) ->
		gen = new Generator()
		if expr.name? and expr.keyn? and expr.args?
			gen.write "#{terminate ? ""}(#{expr_codegen expr.name}):#{expr.keyn}(#{expr.args.map(expr_codegen).join ', '})"
		gen.join ';\n'

	codegen_for_loop = (expr) ->
		if terminate? and terminate isnt "return " then throw new Error("Cannot use for loop as an expression: " + terminate)
		gen = new Generator()
		if expr.name? and expr.start? and expr.end and expr.body?
			gen.startBlock "for #{expr.name} = #{expr_codegen expr.start}, #{expr_codegen expr.end} do"
			gen.write expr.body.map(block_codegen)
			do gen.endBlock
		gen.join ';\n'

	codegen_while_loop = (expr) ->
		if terminate? and terminate isnt "return " then throw new Error("Cannot use while loop as an expression: " + terminate)
		gen = new Generator()
		if expr.cond? and expr.body?
			gen.startBlock "while #{expr_codegen expr.cond} do"
			gen.write expr.body.map(block_codegen)
			gen.endBlock "end"
		gen.join ';\n'

	codegen_variable = (expr, terminate) ->
		if terminate?
			"#{terminate}#{expr.name}"
		else
			null

	block_codegen = (expr) -> intermediate_codegen expr
	expr_codegen = (expr) -> intermediate_codegen expr, ""
	intermediate_codegen = (expr, terminate, scope_top) ->
		if expr?.type?
			switch expr.type
				when 'define_function'
					codegen_function expr, terminate
				when 'call_function'
					codegen_call expr, terminate
				when 'assignment'
					codegen_assignment expr, terminate
				when 'scoped_block'
					codegen_scoped_block expr, terminate, scope_top
				when 'conditional'
					codegen_conditional expr, terminate
				when 'lambda_expr'
					codegen_lambda_expr expr, terminate
				when 'self_call'
					codegen_self_call expr, terminate
				when 'for_loop'
					codegen_for_loop expr, terminate
				when 'raw'
					codegen_raw expr, terminate
				when 'while_loop'
					codegen_while_loop expr, terminate
				when 'macro_declaration'
					return "-- macro declaration of #{expr.name}"
				when 'variable'
					codegen_variable expr, terminate
				else
					(terminate ? "") + symbol expr # either unimplemented construct or literal. either way, just emit.
		else
			if not isNaN(parseFloat expr) or (expr?[0] is '"' and expr.slice(-1)?[0] is '"')
				if terminate? then terminate + expr else null
			else
				if terminate? then terminate + symbol expr else null

	if ast?
		if ast?.map?
			body = ast.slice(0, -1).map block_codegen
			last_expr = ast.slice(-1)[0]

			if body? and last_expr?
				x = body.concat (intermediate_codegen last_expr, terminate)
			else
				x = []
		else
			x = [intermediate_codegen ast, terminate]

		fns = []
		for nam, expr of decd_funs
			if !/([_\w\d]+)\.([_\w\d])+/gmi.test nam
				fns.push symbol nam

		if fns.length >= 1
			decs = ["local #{fns.join ', '}"]
			decs.concat x
		else
			x
	else
		['']
