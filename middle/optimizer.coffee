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
#  - Merge nested "scoped_blocks" into single blocks
#  - Inline functions
#  - Give each variable a unique suffix. This would mean there
#  - are no name collisions

{ traverser } = require "./traverse"

escape_name = (name) ->
	if name.startsWith '_G.'
		name.substring 3
	else if name.startsWith '_ENV.'
		name.substring 5
	else
		name

is_pure = (expr) ->
	expr?.type is "variable" or expr?.type is "lambda_expr"

annotate  = (ast) ->
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

	add_variable = (scope, name) ->
		if name.startsWith '_G.'
			name = name.substring 3
			scope = root
		else if name.startsWith '_ENV.'
			name = name.substring 5
			scope = root

		scope.variables[name] = {
			name: name
			should_emit: false # If this symbol should be emitted.
			definitions: []
			scope: scope
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

		while scope?
			if scope.variables[name]?
				return scope.variables[name]
			else
				scope = scope.parent

		variable = add_variable root, name
		variable.global = true
		console.log "\x1b[1;33mwarning:\x1b[0m Using global #{name}" if process.env.CAFE_WARN_GLOBAL?
		variable

	use_variable = (scope, name) ->
		# Use all parent tables in indexed expressions
		if '.' in name
			use_variable scope, (name.slice 0, name.lastIndexOf '.')

		use_variable_ref(get_variable scope, name)

	use_variable_ref = (variable) ->
		if not variable.should_emit
			variable.should_emit = true
			for def in variable.definitions
				if def?.visited is false # We might just not set it
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
				when "switch"
					do_annotate e.thing
					for x in e.clauses
						x.body_scope = push_scope()
						do_annotate x.test
						do_annotate x.valu
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
					e.arg_var = add_variable e.body_scope, "args"
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
				when "call_function", "self_call", "conditional"
					traverse e
				when "assignment"
					if is_pure e.value?.type
						if e.value?.type is "variable"
							e.value.variable = get_variable e.value.scope, e.value.name
						e.value.visited = false
					else
						visit e.value

					variable = if e.local
						add_variable e.scope, e.name
					else
						get_variable e.scope, e.name
					variable.definitions.push e.value

					if variable.should_emit and e.value?.visited is false
						visit e.value

					if (not is_pure e.value) and (typeof e.value isnt "string")
						use_variable_ref variable
					e.variable = variable
				when "scoped_block"
					for [name, value], i in e.vars
						if name? and value?
							if is_pure value
								if value?.type is "variable"
									value.variable = get_variable value.scope, value.name
								value.visited = false
							else
								visit value

							variable = add_variable e.body_scope, name
							variable.definitions.push value
							e.vars[i].push(variable) # Kinda hack to share variable state

							if variable.should_emit and value?.visited is false
								visit value
							if (not is_pure value) and (typeof value isnt "string")
								use_variable_ref variable
					visit n for n in e.body
				when "lambda_expr"
					e.arg_var = add_variable e.body_scope, "args"
					for arg in e.args
						variable = add_variable e.body_scope, arg
						variable.argument = true

					visit n for n in e.body
				when "raw" then
				when "switch"
					visit e.test
					for clause in e.clauses
						test = clause.test
						if /^\[(?:~?[\w|:]+,?)*\]$/gmi.test test
							for n in test.slice(1, -1).split(',')
								use_variable e.scope, 'type'
								if /(\w+)\|(\w+):(\w+)\|/gmi.test n
									matches = n.match(/(\w+)|(\w+):(\w+)|/gmi).filter (x) -> x.length >= 1

									use_variable e.scope, 'head'
									use_variable e.scope, 'tail'

									# This will probably duplicate variables. Eh.
									add_variable clause.body_scope, matches[1]
									add_variable clause.body_scope, matches[2]
						else if /^".+"$/gmi.test test
							use_variable e.scope, 'type'
						else if test.type? and (test.type isnt "variable" or test.name isnt "_")
								visit test

						visit clause.valu

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

module.exports.optimize = (ast) ->
	scope = annotate ast
	ast
