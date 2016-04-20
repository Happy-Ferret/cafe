module.exports.traverser = (visitor) ->
	(e) ->
		if e?.type?
			switch e.type
				when "define_function"
					visitor n for n in e.body
				when "call_function"
					visitor e.name
					visitor n for n in e.args
				when "assignment"
					visitor e.value
				when "scoped_block"
					for n in e.vars
						visitor n[1]
					visitor n for n in e.body
				when "conditional"
					visitor e.cond
					visitor e.trueb
					visitor e.falsb
				when "lambda_expr"
					visitor n for n in e.body
				when "self_call"
					visitor e.name
					visitor n for n in e.args
				when "for_loop"
					visitor e.start
					visitor e.end
					visitor n for n in e.body
				when "raw" then
				when "while_loop"
					visitor e.cond
					visitor n for n in e.body
				when "switch"
					visitor e.thing
					for n in e.clauses
						visitor n.test
						visitor n.valu
				when "macro_declaration" then
				when "variable" then
				else
					throw new Error("Unknown node #{e.type}")
		else if e instanceof Array
			throw new Error("Cannot traverse array")

emit_expr = (e, allow_null) ->
	if e instanceof Array
		if e.length is 1
			e[0]
		else
			{ type: 'scoped_block', vars: [], body: e }
	else if e?
		e
	else if allow_null is true
		undefined
	else
		"nil"

map_multi = (items, func) ->
	if items.length is 0
		items

	out = []
	for item in items
		result = func(item)
		if result instanceof Array
			# We could use push.apply, but this seems more "stable"
			for res in result
				out.push res
		else if result?
			out.push result
	out


module.exports.modify = (e, mutator) ->
	if e?.type?
		switch e.type
			when "define_function"
				e.body = map_multi e.body, mutator
			when "assignment"
				e.value = emit_expr mutator e.value
			when "scoped_block"
				for n in e.vars
					if n[0]? and n[1]?
						n[1] = emit_expr mutator n[1]
				e.body = map_multi e.body, mutator
			when "conditional"
				e.cond = emit_expr mutator e.cond
				e.trueb = emit_expr mutator e.trueb
				e.falsb = emit_expr(mutator(e.falsb), true)
			when "lambda_expr"
				e.body = map_multi e.body, mutator
			when "self_call", "call_function"
				e.name = emit_expr mutator e.name
				e.args = map_multi e.args, (x) -> emit_expr mutator x
			when "for_loop"
				e.start = emit_expr mutator e.start
				e.end = emit_expr mutator e.end
				e.body = map_multi e.body, mutator
			when "raw" then
			when "while_loop"
				e.cond = emit_expr mutator, e.cond
				e.body = map_multi e.body, mutator
			when "switch"
				e.thing =  e.thing
				for n in e.clauses
					n.test = emit_expr mutator n.test
					n.valu = emit_expr mutator n.valu
			when "macro_declaration" then
			when "variable" then
			else
				throw new Error("Unknown node #{e.type}")
		e
	else if e instanceof Array
		map_multi e, mutator
	else
		e
