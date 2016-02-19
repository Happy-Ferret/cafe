{ parse }         = require './front'
{ codegen, emit } = require './back'
{ readFile }      = require 'fs'

readFile 'test_program.cafe', {encoding: 'utf-8'}, (err, data) ->
	if err
		throw err

	emit codegen parse data
