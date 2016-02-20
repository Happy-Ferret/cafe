fs = require 'fs'
{ exec } = require 'child_process'

resolve_module = (file) ->
	potential_files = [
		"./#{file}", "./#{file}.cafe",
		"./lib/#{file}", "./lib/#{file}.cafe"
	]

	for file in potential_files
		if fs.existsSync file
			return file


module.exports.preprocess = (contents) ->
	lines = []
	mkdn_lines = []
	mkdn = null

	contents.split('\n').map (line, ln) ->
		if line.startsWith '@import'
			file = line.split(' ')[1]
			mod_contents = fs.readFileSync(resolve_module(file), {encoding: 'utf8'})

			lines.push module.exports.preprocess mod_contents
		else if line.startsWith '@markdown-doc'
			mkdn = line.split(' ')[1]
			exec "install `mktemp` -D #{mkdn} -m 0644"
		else if line.startsWith ';;'
			if mkdn?
				line = '\n' if line == ';; --'
				mkdn_lines.push line.replace(/^;; ?/g, '') + '  \n'
		else
			lines.push line

	if mkdn?
		fs.writeFile mkdn, mkdn_lines.join '', (error) -> console.error error
	ret = lines.join '\n'
