{ exec } = require 'child_process'
fs = require 'fs'
path = require 'path'

resolve_module = (file) ->
	potential_files = [
		"./#{file}", "./#{file}.cafe",
		"./lib/#{file}", "./lib/#{file}.cafe",
		"#{__dirname}/#{file}", "#{__dirname}/#{file}.cafe",
		"#{__dirname}/lib/#{file}", "#{__dirname}/lib/#{file}.cafe",
		"#{__dirname}/../#{file}", "#{__dirname}/../#{file}.cafe",
		"#{__dirname}/../lib/#{file}", "#{__dirname}/../lib/#{file}.cafe",
		"/#{file}"
	]

	for file in potential_files
		if fs.existsSync file
			return file


module.exports.preprocess = (contents, docout = false) ->
	lines = []
	mkdn_lines = []
	mkdn = null

	contents.split('\n').map (line, ln) ->
		if line.startsWith '@import'
			file = line.split(' ')[1]
			modfile = resolve_module(file)
			if modfile?
				mod_contents = fs.readFileSync(modfile, {encoding: 'utf8'})

				lines.push module.exports.preprocess mod_contents
			else
				console.error "\x1b[1;31m→\x1b[0m No such module #{file}. Compilation halted."
				process.exit 1
		else if line.startsWith '@markdown-doc'
			mkdn = line.split(' ')[1]
			exec "install `mktemp` -D #{mkdn} -m 0644" if docout
		else if line.startsWith ';;'
			if mkdn?
				line = '\n' if line == ';; --'
				mkdn_lines.push line.replace(/^;; ?/g, '') + '  \n'
		else
			lines.push line

	if mkdn? && docout
		if fs.existsSync(path.dirname mkdn) or fs.existsSync mkdn
			fs.writeFile mkdn, mkdn_lines.join '', (error) -> console.error error
	ret = lines.join '\n'
