{ exec } = require 'child_process'
fs = require 'fs'
path = require 'path'

resolve_module = (file, fnam) ->
	potential_files = [
		"./#{file}", "./#{file}.cafe",
		"./lib/#{file}", "./lib/#{file}.cafe",
		"#{__dirname}/#{file}", "#{__dirname}/#{file}.cafe",
		"#{__dirname}/lib/#{file}", "#{__dirname}/lib/#{file}.cafe",
		"#{__dirname}/../#{file}", "#{__dirname}/../#{file}.cafe",
		"#{__dirname}/../lib/#{file}", "#{__dirname}/../lib/#{file}.cafe",
		"/#{file}"
	]

	if fnam?
		potential_files = potential_files.concat [
			"#{path.dirname path.resolve fnam}/#{file}", "#{path.dirname path.resolve fnam}/#{file}.cafe",
			"#{path.dirname path.resolve fnam}/lib/#{file}", "#{path.dirname path.resolve fnam}/lib/#{file}.cafe",
		]

	for file in potential_files
		if fs.existsSync file
			return file
module.exports.resolve = resolve_module

module.exports.preprocess = (contents, fnam) ->
	lines = []
	contents.split('\n').map (line, ln) ->
		if line.startsWith ';;@import'
			file = line.split(' ')[1]
			modfile = resolve_module file, fnam
			if modfile?
				mod_contents = fs.readFileSync(modfile, {encoding: 'utf8'})

				lines.push module.exports.preprocess mod_contents, fnam
			else
				console.error "\x1b[1;31m→\x1b[0m No such module #{file}. Compilation halted."
				process.exit 1
		else
			lines.push line
	lines.join '\n'
