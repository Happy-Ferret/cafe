{ symbol } = require '../../front'
fs         = require 'fs'

actual_opch = (opch) ->
	opch_map =
		'=': '=='
		'!=': '~='
		'??': 'or'

	if opch_map[opch] then opch_map[opch] else opch

module.exports.codegen = (ast) ->
