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
