fs = require 'fs'

module.exports.emit = (file, code_parts, cb) ->
	code_joined = (code_parts.map (part) -> part + '\n').join '\n'
	_error = null
	try
		fs.writeFileSync file, code_joined
	catch error
		_error = error
	finally
		cb _error, code_joined
