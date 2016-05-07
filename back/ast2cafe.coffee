module.exports.ast2cafe = (ast) ->
	# Compile Café back into Café for use in the REPL.
	unsymbol = (n) ->
		n = n.slice(2, -2)
		work = ''
		res = []
		while n.length >= 2
			work = n.slice(0, 2); n = n.slice(2)
			res.push String.fromCharCode work
		res.join ''
	deconstruct = (elem) ->
		if elem?.type?
			switch elem.type
				when 'define_function'
					"(defn (#{elem.name} #{elem.args.join ' '}) #{elem.body.map(deconstruct).join ''})"
				when 'call_function'
					"(#{deconstruct elem.name}#{if elem.args.length > 0 then ' ' else ''}#{elem.args.map(deconstruct).join ' '})"
				when 'assignment'
					"(def #{elem.name} #{deconstruct elem.value}#{if elem.local then "" else " :global"})"
				when 'raw'
					"(lua-raw #{elem.body.map((x) -> "\"#{x}\"").join ' '})"
				when 'lambda_expr'
					"(λ (#{elem.args.join ' '}) #{elem.body.map(deconstruct).join ''})"
				when 'scoped_block'
					base = "(let "
					base += "(" + elem.vars.map (x) ->
						if x[0]? and x[1]?
							"(#{x[0]} #{deconstruct x[1]})"
						else
							'()'
					.join(' ') + ") "
					base + elem.body.map(deconstruct).join('') + ')'
				when 'variable'
					if elem.name.startsWith '__'
						unsymbol elem.name
					else
						elem.name
				when 'conditional'
					base = "(if #{deconstruct elem.cond} #{deconstruct elem.trueb}"
					if elem.falsb?
						base += " #{deconstruct elem.falsb}"
					base + ")"
				when 'self_call'
					"(.#{deconstruct elem.name} #{elem.keyn} #{elem.args.map(deconstruct).join ' '})"
				when 'for_loop'
					"(for #{elem.name} #{deconstruct elem.start} #{deconstruct elem.end} #{elem.body.map(deconstruct).join ''})"
				when 'while_loop'
					"(loop #{deconstruct elem.cond} #{elem.body.map(deconstruct).join ''})"
				else
					elem
		else
			elem

	if ast?.map?
		ast.map (x) -> deconstruct x
	else
		deconstruct ast
