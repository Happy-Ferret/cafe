#!/usr/bin/coffee
{ parse, preprocess } = require './front'
{ codegen, emit }     = require './back'
fs                    = require 'fs'
readline              = require 'readline'
child_process         = require 'child_process'


inp = process.argv[2] ? '/dev/stdin'
out = process.argv[3] ? 'stdin.lua'
ast = process.argv[4] ? 'stdin.ast.json'

fs.readFile inp, {encoding: 'utf-8'}, (err, data) ->
	if err
		throw err

	emit out, codegen parse preprocess(data), ast
