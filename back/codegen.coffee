module.exports.codegen = (ast) ->
	codegen_function = (expr) ->
		"function #{expr.name}(#{expr.args.join ', '})\n#{expr.body.map(intermediate_codegen).join '\n\t'}\nend"

	codegen_call = (expr) ->
		"#{expr.name}(#{expr.args.map(intermediate_codegen).join ', '})"

	codegen_binary = (expr) ->
		"#{intermediate_codegen expr.lhs} #{expr.opch} #{intermediate_codegen expr.rhs}"

	intermediate_codegen = (expr) ->
		switch expr.type
			when 'define_function'
				codegen_function expr
			when 'call_function'
				codegen_call expr
			when 'binary_operator'
				codegen_binary expr
			when 'unary_operator'
				codegen_unary expr
			else expr

	ast.map intermediate_codegen

module.exports.emit = (code_parts) ->
	for code in code_parts
		console.log code
