{ toks2ast
, symbol   } = require '../../front'
template_string = (str, tfa, ic) ->
	str.replace /\$,(\w+)/gmi, (orig, gr1, indx, str) ->
		if tfa[gr1]?
			x = tfa[gr1]
			if x.type?
				if x.type is 'variable'
					x
				else
					ic x
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
					else throw "No such macro clause #{x[0]}"

		for i in [0..clauses.length]
			clause = clauses[i]
			if clause
				return str[2 + i][1]


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

		replace_internal = (sym) ->
			if sym[0] is '`cond'
				replace_internal macro_test sym, transfargs, ic
			else
				if sym?.map?
					sym.map replace_internal
				else if sym?[0] is ','
					if sym?[1] is '~'
						if transfargs[sym.slice 2]?
							symbol transfargs[sym.slice 2]
						else
							'nil'
					else if sym?[1] is '@'
						if transfargs[sym.slice 2]?.map?
							['let', [['']]].concat replace_internal transfargs[sym.slice 2]
						else
							'nil'
					else if /^\[[\d:]+\]/.test sym.slice(1)
						x = sym.slice(1).match /^\[([\d:]+)\]/
						indexes = x[1].split(':').map((x) -> parseInt x).map (x) -> if isNaN x then undefined else x
						[_, rest] = sym.slice(1).match /^\[[\d:]+\]([\w-@]+)/
						indexes[0] = 0 if indexes[0] is undefined
						if rest[0] is '@'
							rest = rest.slice 1
							if transfargs[rest]?.slice?
								x = transfargs[rest]?.slice(indexes[0], indexes[1])
								if x.length == 1
									x[0]
								else
									['let', [['']]].concat replace_internal transfargs[rest]?.slice(indexes[0], indexes[1])
							else
								'nil'
						else
							if transfargs[rest]?.slice?
								x = transfargs[rest]?.slice(indexes[0], indexes[1])
								if x.length == 1
									x[0]
								else
									replace_internal transfargs[rest]?.slice(indexes[0], indexes[1])
							else
								'nil'
					else if sym?[1] is '\''
						if sym?[2] is '~'
							if transfargs[sym.slice 3].map?
								['table/unpack', ['list'].concat transfargs[sym.slice 3]]
							else
								'nil'
						else
							if transfargs[sym.slice 2].map?
								['list'].concat transfargs[sym.slice 2]
							else
								'nil'
					else if transfargs[sym.slice 1]?
						arg = transfargs[sym.slice 1]
						if arg.map?
							arg.map replace_internal
						else
							arg
					else
						sym.slice 1
				else if sym?.startsWith?('`"') and sym.slice(-1)[0] is '"'
					"\"#{template_string sym.slice(2, -1), transfargs, ic}\""
				else if sym?.type is "variable"
					{ type: "variable", name: replace_internal sym }
				else
					sym

		cleanup = (x) ->
			if x[0][0] is '"' and x[0].slice(-1)[0] is '"'
				['lua-raw', "\"#{x}\""]
			else
				x

		x = template.map(replace_internal).map cleanup
		return x
