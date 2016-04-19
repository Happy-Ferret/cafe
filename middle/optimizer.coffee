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
			used: 0
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

		# Force global variables to be emitted
		variable = add_variable root, name
		variable.global = true
		variable.used = 1
		variable
	use_variable = (scope, name) ->
		# Use all parent tables in indexed expressions
		if '.' in name
			use_variable scope, (name.slice 0, name.lastIndexOf '.')

		variable = get_variable scope, name
		variable.used++
		for def in variable.definitions
			if def.visited is false
				def.visited = true
				if def.type is "variable"
					use_variable def.scope, def.name
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
					e.visited = false
					e.body_scope = push_scope()
					do_annotate n for n in e.body
					pop_scope()
				when "call_function"
					do_annotate e.name
					do_annotate n for n in e.args
				when "assignment"
					do_annotate e.value
				when "scoped_block"
					for n in e.vars
						do_annotate n[1]
					e.body_scope = push_scope()
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
					vari = root.variables[escape_name e.name]
					vari.definitions.push(e)
					e.arg_var = add_variable e.body_scope, "args"
					for arg in e.args
						variable = add_variable e.body_scope, arg
						variable.argument = true

					if vari.used isnt 0 and e.visited is false
						e.visited = true
						traverse e
				when "call_function", "self_call", "conditional", "for_loop"
					traverse e
				when "assignment"
					if e.value?.type is "variable"
						e.visited = false
					else
						visit e.value

					variable = if e.local
						add_variable e.scope, e.name
					else
						get_variable e.scope, e.name

					variable.definitions.push e
					e.variable = variable
				when "scoped_block"
					for [name, value] in e.vars
						if name? and value?
							visit value
							variable = add_variable e.body_scope, name
							variable.definitions.push value
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
						else if test.type?
							visit test

						visit clause.valu

				when "macro_declaration" then
				when "variable"
					use_variable e.scope, e.name
				else
					throw new Error("Unknown node #{e.type}")

		true
	traverse = traverser visit

	visit n for n in ast
	root

module.exports.optimize = (ast) ->
	scope = annotate ast
	ast