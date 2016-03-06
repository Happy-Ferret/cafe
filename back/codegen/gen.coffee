{ symbol } = require '../../front'
fs         = require 'fs'

actual_opch = (opch) ->
	opch_map =
		'=': '=='
		'!=': '~='

	if opch_map[opch] then opch_map[opch] else opch


module.exports.codegen = (ast) ->
	should_return = (expr) ->
		if expr.is_tail?
			if (expr.type is 'for_loop') and (expr.type is 'assignment') and (expr.type is 'raw')
				''
			else
				'return '
		else
			''
	codegen_function_body = (expr) ->
		body = expr.body.slice(0, -1).map intermediate_codegen
		last_expr = expr.body.slice(-1)[0]

		if body? and last_expr?
			last_expr.is_tail = true
			if typeof last_expr is 'object'
				last_expr = "#{intermediate_codegen last_expr}"
			else
				last_expr = "return #{last_expr}"

			"#{body.join ';'}#{last_expr}"
		else
			''

	codegen_function = (expr) ->
		if expr.name? and expr.args? and expr.body?
			body = codegen_function_body expr
			"function #{expr.name}(#{expr.args.join ', '})#{body};end"

	codegen_call = (expr) ->
		if expr.name?
			"#{should_return expr}(#{intermediate_codegen expr.name})(#{expr.args.map(intermediate_codegen).join ', '})"

	codegen_binary = (expr) ->
		if expr.lhs? and expr.opch? and expr.rhs?
			"#{should_return expr}#{intermediate_codegen expr.lhs} #{actual_opch expr.opch} #{intermediate_codegen expr.rhs}"

	codegen_unary = (expr) ->
		if expr.opch? and expr.arg?
			base = "#{should_return expr}#{actual_opch expr.opch}"
			if actual_opch expr.opch is 'not'
				base += ' '
			base + "#{intermediate_codegen expr.arg}"

	codegen_raw = (expr) ->
		rem_quots = (str) -> str.slice(1, -1)
		expr.body.map(rem_quots).join ''

	codegen_scoped_block = (expr) ->
		if expr.vars? and expr.body?
			vars = expr.vars.map (v) ->
				if v[0]? and v[1]? # Gracefully handle empty variables
					"local #{v[0]} = #{intermediate_codegen v[1]};"

			if expr.body.length >= 1 # Gracefully handle empty blocks
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
			else
				body = ''
				last_expr = ''

			"do #{vars.join ';'}#{body.join ';'};#{last_expr}; end"

	codegen_conditional = (expr) ->
		can_return = (exp) ->
			if (exp.type isnt 'for_loop') and (exp.type isnt 'assignment') and (exp.type isnt 'scoped_block') and (exp.type isnt 'raw')
				'return '
			else
				''

		if expr.cond? and expr.trueb?
			if expr.is_tail?
				base = ' return '
			else
				base = ' '

			if expr.trueb.type is 'scoped_block'
				expr.trueb.is_tail = true
			base += "(function() if #{intermediate_codegen expr.cond} then #{can_return expr.trueb}#{intermediate_codegen expr.trueb}"
			if expr.falsb?
				if expr.falsb.type is 'scoped_block'
					expr.falsb.is_tail = true
				base += " else #{can_return expr.falsb}#{intermediate_codegen expr.falsb} end"
			else
				base += ' end'

			base += ' end)()'

	codegen_lambda_expr = (expr) ->
		if expr.args? and expr.body?
			body = codegen_function_body expr
			"#{should_return expr}function(#{expr.args.join ', '}) #{body} end"

	codegen_assignment = (expr) ->
		if expr.name? and expr.value?
			if expr.local? and expr.local
				base = 'local '
			else
				base = ''

			base += "#{expr.name} = #{intermediate_codegen expr.value};"
			base

	codegen_self_call = (expr) ->
		if expr.name? and expr.keyn? and expr.args?
			"#{should_return expr}(#{intermediate_codegen expr.name}):#{expr.keyn}(#{expr.args.map(intermediate_codegen).join ', '})"

	codegen_for_loop = (expr) ->
		if expr.name? and expr.start? and expr.end and expr.body?
			"for #{expr.name} = #{intermediate_codegen expr.start}, #{intermediate_codegen expr.end} do #{expr.body.map(intermediate_codegen).join ';'} end"

	codegen_while_loop = (expr) ->
		if expr.cond? and expr.body?
			"while #{intermediate_codegen expr.cond} do #{expr.body.map(intermediate_codegen).join ';'} end"


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
				when 'while_loop'
					codegen_while_loop expr
				else
					expr # either unimplemented construct or literal. either way, just emit.
		else
			if not isNaN(parseFloat expr) or (expr?[0] is '"' and expr.slice(-1)?[0] is '"')
				expr
			else
				symbol expr

	if ast?
		if ast?.map?
			ast.map intermediate_codegen
		else
			intermediate_codegen ast
	else
		''
