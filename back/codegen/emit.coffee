fs = require 'fs'

module.exports.emit = (file, code_parts, cb) ->
	if fs.existsSync file
		_error = null
		try
			fs.appendFileSync file, code_parts.join ';'
		catch error
			_error = error
		finally
			cb _error, code_parts.join ';'
	else
		_error = null
		try
			fs.writeFileSync file, code_parts.join ';'
		catch error
			_error = error
		finally
			cb _error, code_parts.join ';'
