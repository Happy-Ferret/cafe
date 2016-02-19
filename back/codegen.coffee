actual_opch = (opch) ->
	opch_map =
		"eq?": '=='
		"neq?": '~='
		'!=': '~='

	if opch_map[opch] then opch_map[opch] else opch

module.exports.codegen = (ast) ->
	codegen_function = (expr) ->
		body = expr.body.slice(0, -1).map intermediate_codegen
		last_expr = expr.body.slice(-1)[0]


		last_expr.is_tail = true
		if last_expr[0]?.type is 'call_function'
			last_expr = "return #{intermediate_codegen last_expr}"
		else
			last_expr = "#{intermediate_codegen last_expr}"

		"function #{expr.name}(#{expr.args.join ', '})\n\t#{body.join '\n\t'}\n\t#{last_expr}\nend"

	codegen_call = (expr) ->
		"#{expr.name}(#{expr.args.map(intermediate_codegen).join ', '})"

	codegen_binary = (expr) ->
		"#{intermediate_codegen expr.lhs} #{actual_opch expr.opch} #{intermediate_codegen expr.rhs}"

	codegen_unary = (expr) ->
		"#{actual_opch expr.opch} #{intermediate_codegen expr.arg}"

	codegen_scoped_block = (expr) ->
		vars = expr.vars.map (v) ->
			"local #{v[0]} = #{intermediate_codegen v[1]};"

		body = expr.body.slice(0, -1).map intermediate_codegen
		last_expr = expr.body.slice(-1)[0]

		if expr.is_tail?
			last_expr.is_tail = true
			if last_expr[0]?.type is 'call_function'
				last_expr = "return #{intermediate_codegen last_expr}"
			else
				last_expr = "#{intermediate_codegen last_expr}"
		else
			last_expr = "#{intermediate_codegen last_expr}"

		"do\n\t#{vars.join '\n\t'}\n\t#{body}\n\t#{last_expr}\nend"

	codegen_conditional = (expr) ->
		if expr.is_tail?
			base = '\nreturn '
		else
			base = '\n '
		base += "(function() if #{intermediate_codegen expr.cond} then\n\t\treturn #{intermediate_codegen expr.trueb}"
		if expr.falsb?
			base += "\n\telse\n\t\treturn #{intermediate_codegen expr.falsb} end"
		else
			base += "\nend"

		base += " end)()"

	codegen_lambda_expr = (expr) ->
		body = expr.body.map intermediate_codegen
		"function(#{expr.args.join ', '})\n\t#{body.slice(0, -1).join '\n\t'}\n\treturn #{body.slice(-1)}\nend"

	codegen_assignment = (expr) ->
		if expr.local?
			base = 'local '
		else
			base = ''

		base += "#{expr.name} = #{intermediate_codegen expr.value};"
		base

	codegen_self_call = (expr) ->
		"#{expr.name}:#{expr.keyn}(#{expr.args.map(intermediate_codegen).join ', '})"


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
				else
					expr # either unimplemented construct or literal. either way, just emit.
		else
			console.error "can not generate: #{JSON.stringify expr, null, '  '}"
			expr

	ast.map intermediate_codegen

module.exports.emit = (code_parts) ->
	for code in code_parts
		console.log code
