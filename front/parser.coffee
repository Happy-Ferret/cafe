operator = (s) ->
	isop = s in [
		'==', '!=', 'eq?', 'neq?',
		'not', 'and', 'or',
		'>', '<', '+', '-', '*', '/', '%',
		'>=', '<=', '>>', '<<',
		'#', '~', '&', '|'
	]
	isop

symbol = (str) ->
	str.replace(new RegExp('-', 'g'), '_').replace(/\?/g, 'qm').replace(new RegExp('!', 'g'), 'bang')

module.exports.parse = (string) ->
	str2tok = (str) ->
		sexpr = [[]]
		word  = ''
		in_str = false

		for c in str
			if c == '(' and !in_str
				sexpr.push []
			else if c == ')' and !in_str
				if word.length > 0
					sexpr[sexpr.length - 1].push word
					word = ''

				thing = do sexpr.pop
				sexpr[sexpr.length - 1].push thing
			else if c in " \r\n\t" and !in_str
				if word.length > 0
					sexpr[sexpr.length - 1].push word
					word = ''
			else if c == '"'
				word += c
				in_str = !in_str
			else
				word += c
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
						if tokens.length is 2
							{
								type: 'unary_operator'
								opch: tokens[0]
								arg:  toks2ast tokens[1]
							}
						else
							{
								type: 'binary_operator'
								opch: tokens[0]
								lhs: toks2ast tokens[1]
								rhs: toks2ast tokens[2]
							}
				else if tokens[0] is 'set!'
					base = {
						type: 'assignment'
						name: symbol tokens[1]
						value: toks2ast tokens[2]
						local: true
					}
					if tokens[3] is '!global'
						base.local = false

					base
				else if tokens[0] is 'let'
					{
						type: 'scoped_block'
						vars: tokens[1].map (tok) ->
							[tok[0], toks2ast tok[1]]
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
				else
					{
						type: 'call_function'
						name: symbol tokens[0]
						args: tokens.slice(1).map toks2ast
					}
			when 'string'
				if tokens[0] == '"' and tokens.slice(-1)[0] == '"'
					tokens
				else
					symbol tokens

	tokens = str2tok string
	ast = tokens.map toks2ast

	console.error JSON.stringify ast, null, '\t'

	ast
