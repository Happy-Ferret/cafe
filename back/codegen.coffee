fs = require 'fs'
actual_opch = (opch) ->
	opch_map =
		'=': '=='
		'!=': '~='

	if opch_map[opch] then opch_map[opch] else opch

symbol = (str) ->
	specialChars = ['-','*','?','!','&',':','=','!','$','^', '/', '\\']
	escapeStr = (str) ->
		for special in specialChars
			str = str.replace new RegExp("\\#{special}", 'gmi'), special.codePointAt 0
		str

	if str.replace?
		if new RegExp("[#{specialChars.concat ''}]", 'gmi').test str
			"__" + escapeStr str + "__"
		else
			str
	else
		str

module.exports.codegen = (ast) ->
	should_return = (expr) ->
		if expr.is_tail?
			"return "
		else
			""
	codegen_function_body = (expr) ->
		body = expr.body.slice(0, -1).map intermediate_codegen
		last_expr = expr.body.slice(-1)[0]

		last_expr.is_tail = true
		if typeof last_expr is 'object'
			last_expr = "#{intermediate_codegen last_expr}"
		else
			last_expr = "return #{last_expr}"

		"#{body.join ';'}#{last_expr}"

	codegen_function = (expr) ->
		body = codegen_function_body expr

		"function #{expr.name}(#{expr.args.join ', '})#{body};end"

	codegen_call = (expr) ->
		"#{should_return expr}#{expr.name}(#{expr.args.map(intermediate_codegen).join ', '})"

	codegen_binary = (expr) ->
		"#{should_return expr}#{intermediate_codegen expr.lhs} #{actual_opch expr.opch} #{intermediate_codegen expr.rhs}"

	codegen_unary = (expr) ->
		base = "#{should_return expr}#{actual_opch expr.opch}"
		if actual_opch expr.opch is 'not'
			base += " "
		base + "#{intermediate_codegen expr.arg}"

	codegen_raw = (expr) ->
		rem_quots = (str) -> str.slice(1, -1)
		expr.body.map(rem_quots).join ""

	codegen_scoped_block = (expr) ->
		vars = expr.vars.map (v) ->
			"local #{v[0]} = #{intermediate_codegen v[1]};"

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

		"do #{vars.join ';'}#{body};#{last_expr}; end"

	codegen_conditional = (expr) ->
		if expr.is_tail?
			base = ' return '
		else
			base = ' '
		base += "(function() if #{intermediate_codegen expr.cond} then return #{intermediate_codegen expr.trueb}"
		if expr.falsb?
			base += " else return #{intermediate_codegen expr.falsb} end"
		else
			base += " end"

		base += " end)()"

	codegen_lambda_expr = (expr) ->
		body = codegen_function_body expr
		"#{should_return expr}function(#{expr.args.join ', '}) #{body} end"

	codegen_assignment = (expr) ->
		if expr.local?
			base = 'local '
		else
			base = ''

		base += "#{expr.name} = #{intermediate_codegen expr.value};"
		base

	codegen_self_call = (expr) ->
		"#{should_return expr}#{expr.name}:#{expr.keyn}(#{expr.args.map(intermediate_codegen).join ', '})"

	codegen_for_loop = (expr) ->
		"for #{expr.name} = #{intermediate_codegen expr.start}, #{intermediate_codegen expr.end} do #{expr.body.map(intermediate_codegen).join ';'} end"


	intermediate_codegen = (expr) ->
		if expr?.type?
			switch expr.type
				when 'define_function'
					codegen_function expr
				when 'call_function'
					codegen_call expr
				when 'binary_operator'
					codegen_binary expr
				when 'unary_operator'
					codegen_unary expr
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
				else
					expr # either unimplemented construct or literal. either way, just emit.
		else
			if (parseFloat expr isnt NaN) or (expr[0] is '"' and expr.slice(-1)[0] is '"')
				expr
			else
				symbol expr

	ast.map intermediate_codegen

module.exports.emit = (file, code_parts, cb) ->
	fs.writeFile file, code_parts.join ';', (error) ->
		cb error, code_parts.join ';'
