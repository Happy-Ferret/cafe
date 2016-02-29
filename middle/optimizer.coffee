functions = {}

module.exports.optimize = (ast) ->
	ast.map (expr) ->
		if expr?.type?
			if expr.type is 'define_function'
				console.log "define: #{expr.name}: #{expr.body} (#{expr.body.length})"
				functions[expr.name] = expr
	ast
