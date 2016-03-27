#!/usr/bin/env coffee
{ resolve } = require 'path'
{ exec }    = require 'child_process'
{ argv }    = require 'optimist'
fs          = require 'fs'

docgen = (file, cb) ->
	docout_file = null
	docs = []
	fs.readFile file, { encoding: 'utf-8' }, (err, contents) ->
		if err?
			throw err
		contents.split(/\r?\n/).filter (line) ->
			line.startsWith ';;'
		.map (line) ->
			line.replace /^;; ?/, ''
		.map (line) ->
			if /^@doc/.test line
				matches = line.match /^@doc ([\w/]+(\.md)?)$/
				docout_file = matches[1]
			else if do line.trim is '--'
				docs.push '\n\n'
			else if line.startsWith '@'
			else
				docs.push line

		if docout_file?
			cb null, {
				contents: docs.join '  \n'
				file:     docout_file
			}
		else
			cb -1, {}

		return

compile_file = (afile, file) ->
	docgen afile, (err, d) ->
		if err?
			return console.log "\x1b[1;33mwarning:\x1b[0m no documentation in file #{file}" if err is -1
			throw err
		else
			try
				fs.writeFileSync "#{argv['doc'] ? argv['d'] ? 'doc'}/#{d.file}", d.contents
			catch err
				throw err

compile_dir = (from) ->
	fs.readdir from, (err, files) ->
		if err?
			console.log "No such directory #{argv.from}."
			process.exit 1
		else
			files.map (file) ->
				afile = resolve "#{from}/#{file}"
				fs.stat afile, (err, stat) ->
					throw err if err?
					if stat.isFile()
						compile_file afile, file
					else if stat.isDirectory()
						compile_dir afile


if argv.from? or argv.f?
	compile_dir argv.from ? argv.f

for file in argv._
	compile_file resolve(file), file
