{ symbol } = require '../../front'
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
		if typeof txt is 'string'
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


module.exports.codegen = (ast) ->
	decd_funs = {}

	should_return = (expr) ->
		if expr.is_tail?
			if (expr.type is 'for_loop') and (expr.type is 'assignment') and (expr.type is 'raw')
				''
			else
				'return '
		else
			''
	codegen_function_body = (expr, gen) ->
		body = expr.body.slice(0, -1).map intermediate_codegen
		last_expr = expr.body.slice(-1)[0]

		if not ('args' in expr.args)
			gen.write "local args = {#{expr.args.join ', '}}"
		if body? and last_expr?
			if typeof last_expr is 'object'
				last_expr.is_tail = true
				last_expr = "#{intermediate_codegen last_expr}"
			else
				last_expr = "return #{intermediate_codegen last_expr}"

			body.map gen.write
			gen.write last_expr
		else ''

		gen.join ';\n'

	codegen_function = (expr) ->
		gen = new Generator()
		if expr.name? and expr.args?.join? and expr.body?
			if !decd_funs[expr.name]?
				gen.startBlock "function #{expr.name}(#{expr.args.join ', '})"
				codegen_function_body expr, gen
				gen.endBlock "end"
				decd_funs[expr.name] = {expr}
			else
				false

		gen.join ';\n'

	codegen_call = (expr) ->
		gen = new Generator()
		if expr.name? and expr.args?
			gen.write "#{should_return expr}(#{intermediate_codegen expr.name})(#{expr.args?.map?(intermediate_codegen).join ', '})"

		gen.join ';\n'

	codegen_raw = (expr) ->
		gen = new Generator()
		rem_quots = (str) -> str.slice(1, -1)
		gen.write expr.body.map(rem_quots)
		gen.join ';\n'

	codegen_scoped_block = (expr) ->
		gen = new Generator()
		if expr.vars? and expr.body?
			vars = expr.vars.map (v) ->
				if v[0]? and v[1]? # Gracefully handle empty variables
					"local #{v[0]} = #{intermediate_codegen v[1]}"

			if expr.body.length >= 1 # Gracefully handle empty blocks
				body = expr.body.slice(0, -1).map intermediate_codegen
				last_expr = expr.body.slice(-1)[0]

				if expr.is_tail?
					last_expr.is_tail = true
					if typeof last_expr is 'string'
						last_expr = "return #{last_expr}"
					else
						if last_expr[0]?.type is 'call_function'
							last_expr = "return #{intermediate_codegen last_expr}"
						else
							last_expr = "#{intermediate_codegen last_expr}"
				else
					last_expr = "#{intermediate_codegen last_expr}"
			else
				body = ''
				last_expr = ''

			gen.startBlock "do"
			gen.write vars
			gen.write body
			gen.write last_expr
			do gen.endBlock
		gen.join ';\n'

	codegen_conditional = (expr) ->
		gen = new Generator()
		can_return = (exp) ->
			if (exp.type isnt 'for_loop') and (exp.type isnt 'assignment') and (exp.type isnt 'scoped_block') and (exp.type isnt 'raw')
				'return '
			else
				''

		if expr.cond? and expr.trueb?
			if expr.is_tail?
				base = 'return '
			else
				base = ''

			if expr.trueb.type is 'scoped_block'
				expr.trueb.is_tail = true
			gen.startBlock "#{base}(function(...)"
			gen.startBlock "if #{intermediate_codegen expr.cond} then"
			gen.write "#{can_return expr.trueb}#{intermediate_codegen expr.trueb}"
			if expr.falsb?
				if expr.falsb.type is 'scoped_block'
					expr.falsb.is_tail = true
				gen.endBlock "else"
				gen.startBlock "#{can_return expr.falsb}#{intermediate_codegen expr.falsb}"
				do gen.endBlock
			else
				do gen.endBlock

			gen.endBlock 'end)(table.unpack(args or {}))'
		gen.join ';\n'

	codegen_lambda_expr = (expr) ->
		gen = new Generator()
		if expr.args? and expr.body?
			gen.startBlock "#{should_return expr}function(#{expr.args.join ', '})"
			codegen_function_body expr, gen
			do gen.endBlock
		gen.join ';\n'

	codegen_assignment = (expr) ->
		gen = new Generator()
		if expr.name? and expr.value?
			if expr.local? and expr.local
				base = 'local '
			else
				base = ''

			gen.write base + "#{expr.name} = #{intermediate_codegen expr.value}"
		gen.join '\n'

	codegen_self_call = (expr) ->
		gen = new Generator()
		if expr.name? and expr.keyn? and expr.args?
			gen.write "#{should_return expr}(#{intermediate_codegen expr.name}):#{expr.keyn}(#{expr.args.map(intermediate_codegen).join ', '})"
		gen.join ';\n'

	codegen_for_loop = (expr) ->
		gen = new Generator()
		if expr.name? and expr.start? and expr.end and expr.body?
			gen.startBlock "for #{expr.name} = #{intermediate_codegen expr.start}, #{intermediate_codegen expr.end} do"
			gen.write expr.body.map(intermediate_codegen)
			do gen.endBlock
		gen.join ';\n'

	codegen_while_loop = (expr) ->
		gen = new Generator()
		if expr.cond? and expr.body?
			gen.startBlock "while #{intermediate_codegen expr.cond}"
			gen.write expr.body.map(intermediate_codegen)
			gen.endBlock
		gen.join ';\n'

	codegen_switch = (expr) ->
		gen = new Generator()
		if expr.thing? and expr.clauses?
			gen.startBlock "#{if expr.is_tail? then 'return ' else ''}(function(value) "
			extra = {}
			compile_value = (thing) ->
				if typeof thing is 'object'
					thing.is_tail = true
					intermediate_codegen thing
				else
					"return " + thing

			compile_test = (n) ->
				if /^\[(?:~?[\w|:]+,?)*\]$/gmi.test n
					n.slice(1, -1).split(',').map (n) ->
						if /(\w+)\|(\w+):(\w+)\|/gmi.test n
							matches = n.match(/(\w+)|(\w+):(\w+)|/gmi).filter (x) -> x.length >= 1
							x = "(type(value) == '#{matches[0]}' and head(value) and tail(value))"
							if !extra[x]?
								extra[x] = ["#{matches[1]} = head(value)", "#{matches[2]} = tail(value)"]
							x
						else if /(\w+)\|(\d+)\|/gmi.test n
							matches = n.match(/(\w+)|(\d+)|/gmi).filter (x) -> x.length >= 1
							x = "(type(value) == '#{matches[0]}' and #value == #{matches[1]})"
						else
							n = do n.trim
							if n[0] in "~!"
								"(type(value) ~= '#{n.slice(1)}')"
							else
								"(type(value) == '#{n}')"
					.join ' or '
				else if /^".+"$/gmi.test n
					"type(value) == 'string' and value:match(#{n})"
				else if n.type?
					intermediate_codegen n
				else
					n

			clauses = do ->
				ret = {}
				expr.clauses.forEach (n) ->
					ret[compile_test n.test] = compile_value n.valu
				ret


			gen_switch_body = ->
				meat = []
				for test, value of clauses
					if test isnt '_'
						gen.startBlock "if #{test} then"
						if extra[test]?
							extra[test].map gen.write
						gen.write value
						gen.endBlock 'end'

			gen_switch_catchall = ->
				if clauses._
					gen.write clauses._
				else
					gen.write "return nil"

			gen.startBlock "if value then"
			do gen_switch_body
			gen.endBlock 'end'
			do gen_switch_catchall
			gen.endBlock "end)(#{intermediate_codegen expr.thing})"

		gen.join ';\n'

	intermediate_codegen = (expr) ->
		if expr?.type?
			switch expr.type
				when 'define_function'
					codegen_function expr
				when 'call_function'
					codegen_call expr
				when 'assignment'
					codegen_assignment expr
				when 'scoped_block'
					codegen_scoped_block expr
				when 'conditional'
					codegen_conditional expr
				when 'lambda_expr'
					codegen_lambda_expr expr
				when 'self_call'
					codegen_self_call expr
				when 'for_loop'
					codegen_for_loop expr
				when 'raw'
					codegen_raw expr
				when 'while_loop'
					codegen_while_loop expr
				when 'switch'
					codegen_switch expr
				else
					symbol expr # either unimplemented construct or literal. either way, just emit.
		else
			if not isNaN(parseFloat expr) or (expr?[0] is '"' and expr.slice(-1)?[0] is '"')
				expr
			else
				symbol expr

	if ast?
		if ast?.map?
			x = ast.map intermediate_codegen
		else
			x = [intermediate_codegen ast]

		if decd_funs?
			fns = []
			for nam, expr of decd_funs
				if !/([_\w\d]+)\.([_\w\d])+/gmi.test nam
					fns.push nam

		decs = ["local #{fns.join ', '};\n"]
		if fns.length > 0
			decs.concat x
		else
			x
	else
		['']
