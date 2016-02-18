operator = (s) ->
	isop = s in [
		'==', '!=', 'eq?', 'neq?',
		'not', 'and', 'or',
		'>', '<', '+', '-', '*', '/', '%',
		'>=', '<=', '>>', '<<',
		'#', '~', '&', '|'
	]
	isop

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
							name: tokens[1][0]
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
				else
					{
						type: 'call_function'
						name: tokens[0]
						args: tokens.slice(1).map toks2ast
					}
			when 'string'
				tokens

	tokens = str2tok string
	ast = tokens.map toks2ast

	console.error JSON.stringify ast, null, '\t'

	ast
