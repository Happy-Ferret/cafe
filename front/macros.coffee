# Lazy loading of symbol
symbol = (e) ->
	{ symbol } = require './parser'
	symbol e

template_string = (str, tfa, ic) ->
	str.replace /\$,(\w+)/gmi, (orig, gr1, indx, str) ->
		if tfa[gr1]?
			x = tfa[gr1]
			if x.type?
				if x.type is 'variable'
					x
				else
					throw new Error("Cannot use #{x.type} in template string")
			else x
		else 'nil'

macro_test = (str, tfa, ic) ->
	condarg = tfa[str[1]]
	if !condarg?
		throw "No such argument to macro: #{str[1]}"
	else
		clauses = str.slice(2).map (x) ->
			switch x[0]
				when 'ast'
					return condarg.type?
				when 'const'
					return !condarg.type?
				else
					if x[0][0] is '-'
						if condarg.type is x[0].slice 1
							return true
						else
							return false
					if x[0][0] is '='
						if condarg.toString() == x[0].slice(1).toString()
							return true
						else
							return false
					if x[0] is '_'
						return true
					else throw "No such macro clause #{x[0]}"

		for i in [0..clauses.length]
			clause = clauses[i]
			if clause
				return str[2 + i][1]

macro_map = (expr, args, ic) ->
	context = args
	args[expr[1]].map (x) ->
		context[symbol expr[2]] = x
		replace_internal(expr.slice(3), context, ic)[0]

symbols = {}
last_sym = 0

replace_internal = (sym, args, ic) ->
	if sym[0] is '`cond'
		replace_internal macro_test sym, args, ic
	else if sym[0] is '`map' || sym[0] is '`*'
		if args[sym[1]]?.map?
			macro_map sym, args, ic
		else
			throw "Can not map over a non-array macro argument"
	else if sym[0] is '`cat'
		first = replace_internal(sym[1], args, ic)
		for elem in sym.slice(2)
			x = replace_internal(elem, args, ic)
			if x[0]?.map?
				first = first.concat x
			else
				first.push x
		first
	else
		if sym?.map?
			sym.map (x) -> replace_internal x, args, ic
		else if sym?[0] is ','
			if sym?[1] is '~'
				if args[sym.slice 2]?
					symbol args[sym.slice 2]
				else
					'nil'
			else if sym?[1] is '@'
				if args[sym.slice 2]?.map?
					['let', [['']]].concat replace_internal args[sym.slice 2], args, ic
				else
					'nil'
			else if /^\[[\d:]+\]/.test sym.slice(1)
				x = sym.slice(1).match /^\[([\d:]+)\]/
				indexes = x[1].split(':').map((x) -> parseInt x).map (x) -> if isNaN x then undefined else x
				[_, rest] = sym.slice(1).match /^\[[\d:]+\]([\w-@]+)/
				indexes[0] = 0 if indexes[0] is undefined
				if rest[0] is '@'
					rest = rest.slice 1
					if args[rest]?.slice?
						x = args[rest]?.slice(indexes[0], indexes[1])
						if x.length == 1
							x[0]
						else
							['let', [['']]].concat replace_internal args[rest]?.slice(indexes[0], indexes[1]), args, ic
					else
						'nil'
				else
					if args[rest]?.slice?
						x = args[rest]?.slice(indexes[0], indexes[1])
						if x.length == 1
							x[0]
						else
							replace_internal args[rest]?.slice(indexes[0], indexes[1]), args, ic
					else
						'nil'
			else if sym?[1] is '\''
				if sym?[2] is '~'
					if args[sym.slice 3].map?
						['table/unpack', ['list'].concat args[sym.slice 3]]
					else
						'nil'
				else
					if args[sym.slice 2].map?
						['list'].concat args[sym.slice 2]
					else
						'nil'
			else if args[sym.slice 1]?
				arg = args[sym.slice 1]
				if arg.mape
					arg.map (x) -> replace_internal x, args, ic
				else
					arg
			else if sym?[1] is ':'
				return if symbols[sym.slice(2)]? then symbols[sym.slice(2)] else symbols[sym.slice(2)] = symbol sym.slice(2).replace('$', last_sym++)
			else
				sym.slice 1
		else if sym?.startsWith?('`"') and sym.slice(-1)[0] is '"'
			"\"#{template_string sym.slice(2, -1), args, ic}\""
		else if sym?.type is "variable"
			{ type: "variable", name: replace_internal sym, args, ic }
		else
			sym

module.exports.macro_common = (decl, ic) ->
	{template, args: expect_args} = decl
	(args) ->
		transfargs = do ->
			ret = {varargs: []}
			args.map (x, i) ->
				if i >= expect_args.length
					if expect_args[expect_args.length - 1].startsWith '__38'
						arr = ret[expect_args[expect_args.length - 1].slice(4, -2)]
						if arr.push?
							arr.push x
						else
							ret[expect_args[expect_args.length - 1].slice(4, -2)] = [arr, x]
					else ret.varargs.push x
				else
					if expect_args[i].startsWith '__38'
						ret[expect_args[i].slice(4, -2)] = [x]
					else
						ret[expect_args[i]] = x
			ret

		cleanup = (x) ->
			if x[0][0] is '"' and x[0].slice(-1)[0] is '"'
				['lua-raw', "\"#{x}\""]
			else
				x

		x = template.map((x) -> replace_internal x, transfargs, ic).map cleanup
		console.log JSON.stringify x, null, '\t' if process.env.CAFE_DEBUG_MACRO?
		return x
