functions = {}

module.exports.optimize = (ast) ->
	ast.map (expr) ->
		if expr?.type?
			if expr.type is 'define_function'
				functions[expr.name] = expr
	ast
