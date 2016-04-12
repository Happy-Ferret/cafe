{ writeFile } = require 'fs'
puny = require 'punycode'

operator = (s) ->
	isop = s in [
		'=', '!=',
		'not', 'and', 'or',
		'>', '<', '+', '-', '*', '/', '%',
		'>=', '<=', '>>', '<<',
		'#', '~', '&', '|', '??'
	]
	isop

specialChars = ['+', '-', '*', '/',
                '?', '!', '&', ':',
                '=', '!', '$', '^',
                '\\', '>', '<', '|',
                '~', '#', '%']

_sc = {}
kwda = "and break do else elseif end for function if in local nil not or repeat return then until while".split ' '

symbol = (str) ->
	encode = (str) ->
		ps = puny.encode(str).replace /-$/, ''
		if /^\d/.test(ps) || ps in kwda
			"_#{ps}"
		else ps

	escapeStr = (str) ->
		for special in specialChars
			str = str.replace new RegExp("\\#{special}", 'gmi'), special.codePointAt 0
		str

	_symbol = (str) ->
		if _sc[str]?
			_sc[str]
		else if str?
			if str.replace?
				if new RegExp("[#{specialChars.join '\\'}]", "gmi").test str
					"__#{escapeStr encode str}__"
				else
					encode str
			else
				encode str

	if str is '...'
		'...'
	else
		if str?.split?
			str.split(/\s*[./]\s*/).map(_symbol).filter((x) -> x.length >= 1).join '.'
		else
			str

module.exports.symbol = symbol

module.exports.parse = (string, astf) ->
	str2tok = (str) ->
		sexpr = [[]]
		word  = ''
		in_str = false
		in_cm = false


		for c in str
			if c == '(' and (not in_str and not in_cm)
				sexpr.push []
			else if c == ')' and (not in_str and not in_cm)
				if word.length > 0
					sexpr[sexpr.length - 1].push word
					word = ''

				thing = do sexpr.pop
				if sexpr[sexpr.length - 1]?
					sexpr[sexpr.length - 1].push thing
				else
					return null
			else if c in " \r\n\t" and not in_str
				if in_cm
					if c is '\n'
						word = ''
						in_cm = false
				else if word.length > 0
					sexpr[sexpr.length - 1].push word
					word = ''
			else if c == '"'
				word += c
				in_str = not in_str
			else if c == ';' and not in_str
				if word.length > 0 and not in_cm
					sexpr[sexpr.length - 1].push word
					word = ''
				in_cm = true
			else
				word += c

		if sexpr.length > 1
			if sexpr?[1]?[0]?
				sexpr[1][0]
			else
				null
		else
			sexpr[0]

	toks2ast = (tokens) ->
		switch typeof tokens
			when 'object'
				if tokens[0] is 'defn'
						{
							type: 'define_function'
							name: symbol tokens[1][0]
							args: tokens[1].slice 1
							body: tokens.slice(2).map toks2ast
						}
				else if operator tokens[0]
						{
							type: 'call_function'
							name: symbol "^#{tokens[0]}"
							args: tokens.slice(1).map toks2ast
						}
				else if tokens[0] is 'def'
					base = {
						type: 'assignment'
						name: symbol tokens[1]
						value: toks2ast tokens[2]
						local: true
					}
					if tokens[3] is ':global'
						base.local = false

					base
				else if tokens[0] is 'ns'
					{
						type: 'assignment'
						name: symbol tokens[1]
						value: '{}'
						local: false
					}
				else if tokens[0] in ['let', 'with']
					if tokens[0] is 'let'
						{
							type: 'scoped_block'
							vars: tokens[1].map (tok) ->
								arr = [symbol tok[0]]
								if arr[0]?
									otherv = toks2ast tok[1]
									if otherv
										arr.push otherv

										arr
									else []
								else []
							body: tokens.slice(2).map toks2ast
						}
					else
						{
							type: 'scoped_block',
							vars: [[symbol(tokens[1][0]), toks2ast(tokens[1][1])]],
							body: tokens.slice(2).map toks2ast
						}

				else if tokens[0] is 'if'
					{
						type: 'conditional'
						cond: toks2ast tokens[1]
						trueb: toks2ast tokens[2]
						falsb: toks2ast tokens[3]
					}
				else if tokens[0] in ['λ', 'lambda']
					{
						type: 'lambda_expr'
						args: tokens[1]
						body: tokens.slice(2).map toks2ast
					}
				else if tokens[0]?[0]? and tokens[0][0] is '.'
					{
						type: 'self_call',
						name: toks2ast tokens[0].slice 1
						keyn: symbol tokens[1]
						args: tokens.slice(2).map toks2ast
						cond: 2
					}
				else if tokens[0] is 'for'
					{
						type: 'for_loop'
						name: symbol tokens[1]
						start: toks2ast tokens[2]
						end: toks2ast tokens[3]
						body: tokens.slice(4).map toks2ast
					}
				else if tokens[0] is 'lua-raw'
					{
						type: 'raw'
						body: tokens.slice(1)
					}
				else if tokens[0] is 'loop'
					{
						type: 'while_loop'
						cond: toks2ast tokens[1]
						body: tokens.slice(2).map toks2ast
					}
				else if tokens[0] is 'do'
					{
						type: 'scoped_block',
						vars: [],
						body: tokens.slice(1).map toks2ast
					}
				else if tokens[0] is 'cond'
					{
						type: 'switch'
						thing: toks2ast tokens[1]
						clauses: tokens.slice(2).map (n) ->
							{
								test: toks2ast n[0]
								valu: toks2ast n[1]
							}
					}
				else if tokens?[0]?[0] is '\''
					{
						type: 'call_function'
						name: symbol 'list'
						args: ([toks2ast tokens[0].slice(1)].concat tokens.slice(1)?.map toks2ast)
					}
				else if tokens[0] is 'cut'
					# Build a list of wildcard arguments
					args = []
					toks2wild = (item) ->
						if item is '<>'
							id = '__arg' + args.length + '__'
							args.push(id)
							id
						else if item is '...'
							args.push('...')
							item
						else
							toks2ast item
					func = toks2wild tokens[1]
					body = tokens.slice(2).map toks2wild

					{
						type: 'lambda_expr'
						args: args
						body: [
							{
								type: 'call_function'
								name: func
								args: body
							}
						]
					}
				else if tokens[0] is 'cute'
					# Build a list of wildcard arguments
					args = []
					vars = []
					toks2wild = (item) ->
						if item is '<>'
							id = '__arg' + args.length + '__'
							args.push(id)
							id
						else if item is '...'
							args.push('...')
							item
						else
							id = '__var' + vars.length + '__'
							vars.push([id, toks2ast item])
							id
					func = toks2wild tokens[1]
					body = tokens.slice(2).map toks2wild

					{
						type: 'scoped_block',
						vars: vars,
						body: [
							{
								type: 'lambda_expr'
								args: args
								body: [
									{
										type: 'call_function'
										name: func
										args: body
									}
								]
							}
						]
					}
				else
					if tokens[0]?
						if tokens[1]? and tokens[2]? and tokens[1] is '.'
							{
								type: 'call_function'
								name: symbol 'cons'
								args: [toks2ast(tokens[0])].concat [toks2ast(tokens[2])]
							}
						else
							{
								type: 'call_function'
								name: toks2ast tokens[0]
								args: tokens.slice(1)?.map(toks2ast)
							}
					else
						''
			when 'string'
				if tokens[0] == '"' and tokens.slice(-1)[0] == '"'
					tokens
				else if !isNaN(parseFloat(tokens)) && !(new RegExp("[#{specialChars.join '\\'}]", "gmi").test(tokens))
					tokens
				else if tokens[0] is '\''
					{
						type: 'call_function'
						name: symbol 'list'
						args: ["'#{tokens.slice 1}'"]
					}
				else if tokens[0] is '[' and tokens.slice(-1)[0] is ']'
					tokens
				else
					symbol tokens

	tokens = str2tok string
	if tokens?
		ast = tokens.map toks2ast

		if astf?
			writeFile astf, JSON.stringify(ast, null, '  '), (error) ->
				if error?
					console.error "Failed to write #{astf}: #{error}"
		ast
	else
		{}
