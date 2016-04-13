{ toks2ast } = require '../../front'
template_string = (str, tfa, ic) ->
	str.replace /\$,(\w+)/gmi, (orig, gr1, indx, str) ->
		if tfa[gr1]?
			x = tfa[gr1]
			if x.type?
				if x.type is 'variable'
					x.name
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
			ret = {}
			args.map (x, i) ->
				ret[expect_args[i].name] = x
			ret

		replace_internal = (sym) ->
			if sym[0] is '`cond'
				replace_internal macro_test sym, transfargs, ic
			else
				if sym?.map?
					sym.map replace_internal
				else if sym?[0] is ','
					if transfargs[sym.slice 1]
						transfargs[sym.slice 1]
					else
						sym.slice 1
				else if sym?.startsWith?('`"') and sym.slice(-1)[0] is '"'
					"\"#{template_string sym.slice(2, -1), transfargs, ic}\""
				else if sym?.type is "variable"
					{ type: "variable", name: replace_internal sym.name }
				else
					sym

		cleanup = (x) ->
			if x[0][0] is '"' and x[0].slice(-1)[0] is '"'
				['lua-raw', "\"#{x}\""]
			else
				x

		x = template.map(replace_internal).map cleanup
		return x
