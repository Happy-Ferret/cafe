{ symbol } = require '../../front'
fs         = require 'fs'

actual_opch = (opch) ->
	opch_map =
		'=': '=='
		'!=': '~='
		'??': 'or'

	if opch_map[opch] then opch_map[opch] else opch

module.exports.codegen = (ast) ->
	define_function = (ast) ->
	lambda_expr = (ast) ->

	unary_operator = (ast) ->
	binary_operator = (ast) ->

	assignment = (ast) -> "#{if ast.local? then 'local ' else ''}#{ast.name} = #{_codegen ast.value}"
	scoped_block = (ast) ->
	self_call = (ast) ->
	raw = (ast) ->
	call_function = (ast) ->

	for_loop = (ast) ->
	while_loop = (ast) ->
	scoped_block = (ast) ->
	gen_switch = (ast) ->
	conditional = (ast) ->

	out = []
	_codegen = (ast) ->
		if ast?.type?
			switch ast.type
				when 'define_function'
					define_function ast
				when 'unary_operator'
					unary_operator ast
				when 'binary_operator'
					binary_operator ast
				when 'assignment'
					assignment ast
				when 'scoped_block'
					scoped_block ast
				when 'scoped_block'
					scoped_block ast,
				when 'conditional'
					conditional ast
				when 'lambda_expr'
					lambda_expr ast
				when 'self_call'
					self_call ast,
				when 'for_loop'
					for_loop ast
				when 'raw'
					raw ast
				when 'while_loop'
					while_loop ast
				when 'scoped_block'
					scoped_block ast,
				when 'switch'
					gen_switch ast
				when 'call_function'
					call_function ast
				else ast
		else
			if not isNaN(parseFloat ast) or (ast?[0] is '"' and ast.slice(-1)?[0] is '"')
				ast
			else
				symbol ast

	if ast?.map?
		ast.map (n) ->
			meat = _codegen n
			if meat?.map?
				out.concat meat
			else
				out.push meat
			null
	else
		out.push _codegen n

	JSON.stringify out, null, '\t'
