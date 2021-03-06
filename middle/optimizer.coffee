# A primitive optimiser for the code
# This has several passes:
#   Basic setup
#    - Define all defn-ed functions in the root scope
#    - Push and pop scopes and give each node a scope
#   Walk the tree and count usages.
#    Usage is done lazily to prevent reference loops: we only count a variable as
#    being used if it is used in an active part of the program, rather than
#    if it is used anywhere.
#
# Further optimisations/beautification:
#  - Inline functions
#  - Give each variable a unique suffix. This would mean there are no name collisions

{ traverser, modify } = require "./traverse"

escape_name = (name) ->
	if name.startsWith '_G.'
		name.substring 3
	else if name.startsWith '_ENV.'
		name.substring 5
	else
		name

is_pure = (expr) ->
	switch expr?.type
		when "variable", "lambda_expr" then true
		when "raw" then expr.pure is true
		else false

annotate = (ast) ->
	scope = null
	root = null
	push_scope = () ->
		scope = {
			parent: scope
			variables: {}
		}
	pop_scope = () ->
		if scope.parent?
			scope = scope.parent
		else
			throw new Error("Scope overflow")

	add_variable = (scope, name, lookup_scope) ->
		if name.startsWith '_G.'
			name = name.substring 3
			scope = root
		else if name.startsWith '_ENV.'
			name = name.substring 5
			scope = root

		parent = if '.' in name and name isnt '...'
			scope = lookup_scope if lookup_scope?
			get_variable scope, (name.slice 0, name.lastIndexOf '.')
		else
			null

		scope.variables[name] = {
			name: name
			should_emit: false # If this symbol should be emitted.
			definitions: []
			scope: scope
			parent: parent
		}

	get_variable = (scope, name) ->
		if not scope?
			throw new Error("No scope for #{name}")

		if name.startsWith '_G.'
			name = name.substring 3
			scope = root
		else if name.startsWith '_ENV.'
			name = name.substring 5
			scope = root

		base = scope
		while scope?
			if scope.variables[name]?
				return scope.variables[name]
			else
				scope = scope.parent

		variable = add_variable root, name, base
		variable.global = true
		console.log "\x1b[1;33mwarning:\x1b[0m Using global #{name}" if process.env.CAFE_WARN_GLOBAL?
		variable

	use_variable = (scope, name) ->
		use_variable_ref(get_variable scope, name)

	use_variable_ref = (variable) ->
		if not variable.should_emit
			# Use all parent tables in indexed expressions
			if variable.parent?
				use_variable_ref variable.parent

			variable.should_emit = true
			for def in variable.definitions
				if def?.visited is false # We might just not set it
					def.visited = true
					switch def.type
						when "variable", "lambda_expr"
							visit def
						else
							traverse def

	root = scope = push_scope()
	macros = {}

	# Mark scopes and pre-declare functions
	do_annotate = (e) ->
		if e?.type?
			e.scope = scope
			switch e.type
				when "define_function"
					if !/([_\w\d]+)\.([_\w\d])+/gmi.test e.name
						e.variable = root.variables[escape_name e.name] ? add_variable root, e.name
					e.body_scope = push_scope()
					do_annotate n for n in e.body
					pop_scope()
				when "call_function"
					do_annotate e.name
					do_annotate n for n in e.args
				when "assignment"
					do_annotate e.value
				when "scoped_block"
					e.body_scope = push_scope()
					for n in e.vars
						do_annotate n[1]
					do_annotate n for n in e.body
					pop_scope()
				when "conditional"
					do_annotate e.cond
					do_annotate e.trueb
					do_annotate e.falsb
				when "lambda_expr"
					e.body_scope = push_scope()
					do_annotate n for n in e.body
					pop_scope()
				when "self_call"
					do_annotate e.name
					do_annotate n for n in e.args
				when "for_loop"
					do_annotate e.start
					do_annotate e.end
					e.body_scope = push_scope()
					do_annotate n for n in e.body
					pop_scope()
				when "raw" then
				when "while_loop"
					do_annotate e.cond
					e.body_scope = push_scope()
					do_annotate n for n in e.body
					pop_scope()
				when "variable" then
				when "macro_declaration" then

				else
					throw new Error("Unknown node #{e.type}")

	do_annotate n for n in ast

	# Mark usage
	visit = (e) ->
		if e?.type?
			switch e.type
				when "define_function"
					if not e.variable?
						e.variable = root.variables[escape_name e.name] ? add_variable root, e.name
					for arg in e.args
						variable = add_variable e.body_scope, arg
						variable.argument = true

					vari = root.variables[escape_name e.name]
					vari.definitions.push(e)

					if vari.should_emit
						e.visited = true
						traverse e
					else
						e.visited = false
				when "for_loop"
					add_variable e.body_scope, e.name
					traverse e
				when "call_function", "self_call", "conditional", "while_loop"
					traverse e
				when "assignment"
					if is_pure e.value
						if e.value?.type is "variable"
							e.value.variable = get_variable e.value.scope, e.value.name
						e.value.visited = false
					else
						visit e.value

					handle_variable = (name) ->
						variable =  if e.local
							add_variable e.scope, name
						else
							get_variable e.scope, name
						variable.definitions.push e.value

						if variable.should_emit and e.value?.visited is false
							e.value.visited = true
							visit e.value
						if (not is_pure e.value) and (typeof e.value isnt "string")
							use_variable_ref variable
						variable

					variables = if e.name instanceof Array
						e.name.map handle_variable
					else
						handle_variable e.name
					e.variable = variables
				when "scoped_block"
					for [name, value], i in e.vars
						if name? and value?
							if is_pure value
								if value?.type is "variable"
									value.variable = get_variable value.scope, value.name
								value.visited = false
							else
								visit value

							handle_variable = (name) ->
								variable = add_variable e.body_scope, name
								variable.definitions.push value

								if variable.should_emit and value?.visited is false
									value.visited = true
									visit value
								if (not is_pure value) and (typeof value isnt "string")
									use_variable_ref variable
								variable

							variables = if name instanceof Array
								name.map handle_variable
							else
								handle_variable name

							# Kinda hack to share variable state
							e.vars[i].push(variables)

					visit n for n in e.body
				when "lambda_expr"
					e.arg_var = add_variable e.body_scope, "args"
					for arg in e.args
						variable = add_variable e.body_scope, arg
						variable.argument = true

					visit n for n in e.body
				when "raw" then
				when "macro_declaration" then
				when "variable"
					if not e.variable?
						e.variable = get_variable e.scope, e.name
					use_variable_ref e.variable
				else
					throw new Error("Unknown node #{e.type}")

		true
	traverse = traverser visit

	visit n for n in ast
	root

non_pure = (e) -> (not is_pure e) and (typeof e isnt "string")
should_emit = (v) -> if v instanceof Array then v.find((v) -> v.should_emit isnt false)? else v?.should_emit isnt false

filter_block = (block) ->
	if block.length <= 1
		block
	else
		last = block[block.length - 1]
		init = block.slice(0, -1).filter non_pure
		init.push last
		init
mutator = (e) ->
	e = modify e, mutator
	switch e?.type
		when "scoped_block"
			e.vars = e.vars.filter (x) -> x[0]? and x[1]? and should_emit x[2]
			e.body = filter_block e.body
			if e.vars.length is 0
				return e.body
		when "define_function"
			if e.variable?.should_emit is false
				return undefined
			e.body = filter_block e.body
		when "assignment"
			if not should_emit e.variable
				return undefined
		when "variable"
			# Inline variables
			if e.variable?
				defs = e.variable.definitions
				if defs.length is 1 and typeof defs[0] is "string"
					return defs[0]
		when "conditional"
			if typeof e.cond is "string"
				if e.cond is "nil" or e.cond is "false"
					return e.falsb
				else
					return e.trueb
		when "lambda_expr", "for_loop", "while_loop"
			e.body = filter_block e.body

	e

module.exports.optimize = (ast) ->
	scope = annotate ast
	ast = modify ast, mutator
	ast
