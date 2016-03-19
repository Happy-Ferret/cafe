module.exports.optimize = (ast) ->
	functions = {}
	optimize_function = (e, destructive) ->
		console.log "** DEFINING #{e.name.toUpperCase()}"
		if !functions[e.name]?
			functions[e.name] = {
				called: 0
			}
		e.body.map intermediate_optimize

		if destructive?
			if functions[e.name].called > 0
				e
			else
				functions[e.name] = null
				{}
		else
			e

	optimize_call = (e, destructive) ->
		console.log "** CALLING #{e.name.toUpperCase()}"
		e.args.map intermediate_optimize
		if functions[e.name]?
			functions[e.name].called++
		else
			functions[e.name] = {
				called: 1
			}
		e
	optimize_binary = (e, destructive) ->
		intermediate_optimize e.lhs
		intermediate_optimize e.rhs
		e

	optimize_unary = (e, destructive) ->
		intermediate_optimize e.arg
		e

	optimize_assignment = (e, destructive) ->
		intermediate_optimize e.value
		e

	optimize_scoped_block = (e, destructive) ->
		e.vars.map (n) ->
			intermediate_optimize n[0]
			intermediate_optimize n[1]
		e.body.map intermediate_optimize
		e
	optimize_conditional = (e, destructive) ->
		intermediate_optimize e.cond
		intermediate_optimize e.trueb
		intermediate_optimize e.falsb
		e

	optimize_lambda_expr = (e, destructive) ->
		e.body.map intermediate_optimize
		e
	optimize_self_call = (e, destructive) ->
		intermediate_optimize e.name
		e.args.map intermediate_optimize
		e
	optimize_for_loop = (e, destructive) ->
		intermediate_optimize e.start
		intermediate_optimize e.end
		e.body.map intermediate_optimize
		e
	optimize_raw = (e, destructive) -> e
	optimize_while_loop = (e, destructive) ->
		intermediate_optimize e.cond
		e.body.map intermediate_optimize
		e
	optimize_switch = (e, destructive) ->
		intermediate_optimize e.thing
		e.clauses.map (x) ->
			intermediate_optimize x.test
			intermediate_optimize x.valu
		e

	intermediate_optimize = (expr, destructive) ->
		if expr?.type?
			switch expr.type
				when 'define_function'
					optimize_function expr, destructive
				when 'call_function'
					optimize_call expr, destructive
				when 'binary_operator'
					optimize_binary expr, destructive
				when 'unary_operator'
					optimize_unary expr, destructive
				when 'assignment'
					optimize_assignment expr, destructive
				when 'scoped_block'
					optimize_scoped_block expr, destructive
				when 'conditional'
					optimize_conditional expr, destructive
				when 'lambda_expr'
					optimize_lambda_expr expr, destructive
				when 'self_call'
					optimize_self_call expr, destructive
				when 'for_loop'
					optimize_for_loop expr, destructive
				when 'raw'
					optimize_raw expr, destructive
				when 'while_loop'
					optimize_while_loop expr, destructive
				when 'switch'
					optimize_switch expr, destructive
				else
					symbol expr # either unimplemented construct or literal. either way, just emit.
		else
			if not isNaN(parseFloat expr) or (expr?[0] is '"' and expr.slice(-1)?[0] is '"')
				expr
			else
				expr

	pass = (destroy) ->
		if ast?
			if ast?.map?
				ast.map (x) -> intermediate_optimize x, destroy
			else
				intermediate_optimize ast, destroy
		else
			''

	pass null
	for f, v of functions
		console.log "#{f}: #{v.called}"

	pass true
