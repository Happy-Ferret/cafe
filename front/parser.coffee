{ writeFile } = require 'fs'
{ macro_common } = require './macros'
puny = require 'punycode'

operator = (s) ->
	isop = s in [
		'=', '!=',
		'not', 'and', 'or',
		'>', '<', '+', '-', '*', '/', '%',
		'>=', '<=', '>>', '<<',
		'#', '~', '&', '|', '??', '^'
	]
	isop

specialChars = ['+', '-', '*', '/',
                '?', '!', '&', ':',
                '=', '!', '$', '^',
                '\\', '>', '<', '|',
                '~', '#', '%', '\'']

_sc = {}
kwda = "and break do else elseif end for function if in local not or repeat return then until while".split ' '
reserved_names = "nil true false".split ' '

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
			throw new Error("Expected identifier, got #{str}")

name_symbol = (str) ->
	str = symbol str
	if str in reserved_names
		throw new Error("#{str} is a reserved name")
	str
module.exports.symbol = symbol
macros = {}

generate_macro = (expr) -> (args) -> macro_common(expr)(args).map(toks2ast)

make_body = (args, body) ->
	if "args" in args
		body.map toks2ast
	else
		out = []
		out.push {
			type: 'assignment'
			name: 'args'
			local: true
			value: {
				type: 'raw'
				body: [ '"return {' + (args.join ", ") + '}"' ]
				pure: true
			}
		}

		for node in body
			out.push toks2ast node
		out

module.exports.toks2ast = toks2ast = (tokens) ->
	switch typeof tokens
		when 'object'
			if tokens[0] is 'defn'
				args = tokens[1].slice(1).map name_symbol
				{
					type: 'define_function'
					name: name_symbol tokens[1][0]
					args: args
					body: make_body args, tokens.slice(2), tokens[1][0]
				}
			else if operator tokens[0]
				{
					type: 'call_function'
					name: { type: 'variable', name: symbol "#^#{tokens[0]}" }
					args: tokens.slice(1).map toks2ast
				}
			else if tokens[0] is 'def'
				base = {
					type: 'assignment'
					name: if tokens[1] instanceof Array
							if tokens[1].length is 0
								throw new Error("Cannot assign to empty list!")
							tokens[1].map name_symbol
						else
							name_symbol tokens[1]
					value: toks2ast tokens[2]
					local: true
				}
				if tokens[3] is ':global'
					base.local = false

				base
			else if tokens[0] is 'let'
				{
					type: 'scoped_block'
					vars: tokens[1].map (tok) ->
						name = if tok[0] instanceof Array then tok[0].map name_symbol else name_symbol tok[0]
						arr = [name]
						if arr[0]? and arr[0]?.length isnt 0
							otherv = toks2ast tok[1]
							if otherv
								arr.push otherv

								arr
							else []
						else []
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
				args = tokens[1].map name_symbol
				{
					type: 'lambda_expr'
					args: args
					body: make_body args, tokens.slice(2)
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
					name: name_symbol tokens[1]
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
					name: { type: 'variable', name: symbol 'list' }
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
			else if tokens[0] is 'defmacro'
				expr = {
					type: 'macro_declaration'
					name: symbol tokens[1][0]
					args: tokens[1].slice(1).map symbol
					template: tokens.slice 2
				}
				macros[symbol tokens[1][0]] = generate_macro expr
				expr
			else if tokens.type?
				tokens
			else
				if tokens[0]?
					if tokens[1]? and tokens[2]? and tokens[1] in ['.', '·']
						{
							type: 'call_function'
							name: { type: 'variable', name: symbol 'cons' }
							args: [toks2ast(tokens[0])].concat [toks2ast(tokens[2])]
						}
					else
						name = try symbol tokens[0] catch e
						if name? and macros[name]?
							replace = macros[name](tokens.slice 1)
							if replace instanceof Array
								if replace.length is 1
									replace[0]
								else
									{
										type: 'scoped_block'
										vars: []
										body: replace
									}
							else
								replace
						else
							{
								type: 'call_function'
								name: toks2ast tokens[0]
								args: tokens.slice(1)?.map?(toks2ast)
							}
				else
					''
		when 'string'
			if tokens[0] == '"' and tokens.slice(-1)[0] == '"' or tokens in reserved_names
				tokens
			else if !isNaN(parseFloat(tokens)) && (/^-/.test(tokens) || !(new RegExp("[#{specialChars.join '\\'}]", "gmi").test(tokens)))
				tokens
			else if tokens[0] is '\''
				{
					type: 'call_function'
					name: { type: 'variable', name: symbol 'list'}
					args: ["'#{tokens.slice 1}'"]
				}
			else if tokens[0] is '[' and tokens.slice(-1)[0] is ']'
				tokens
			else
				{ type: 'variable', name: symbol tokens }
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
