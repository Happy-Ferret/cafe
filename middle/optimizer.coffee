functions = {}

module.exports.optimize = (ast) ->
	ast.map (expr) ->
		if expr?.type?
			if expr.type is 'define_function'
				functions[expr.name] = expr
			else if expr.type is 'function_call'
				functions[expr.name].called = true

	ast.map (expr) ->
		if expr?.type is 'define_function'
			if not functions[expr.name].called?
				console.log "removing #{expr.name}"
				''
			else
				expr
		else
			expr
	ast
