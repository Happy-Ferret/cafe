fs = require 'fs'

module.exports.emit = (file, code_parts, cb) ->
	code_joined = code_parts
		.filter (n) -> n? && n.length > 0
		.filter (n) -> !n.startsWith '--'
		.join '\n'
		.split(/\r?\n/)
		.filter((x) -> !x.trim().startsWith '--')
		.join '\n'
	_error = null
	try
		if fs.existsSync file
			fs.appendFileSync file, code_joined
		else
			fs.writeFileSync file, code_joined
	catch error
		_error = error
	finally
		cb _error, code_joined
