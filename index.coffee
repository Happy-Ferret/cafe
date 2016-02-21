#!/usr/bin/coffee
{ parse, preprocess } = require './front'
{ codegen, emit }     = require './back'
{ resolve }           = require 'path'
{ repl }              = require './front/repl'
fs                    = require 'fs'
readline              = require 'readline'
child_process         = require 'child_process'

inp = process.argv[2] ? '/dev/stdin'
out = process.argv[3] ? "#{inp}.lua"
ast = process.argv[4] ? "#{inp}.ast.json"

if inp is '/dev/stdin' or inp is '-'
	do repl
else
	fs.readFile inp, {encoding: 'utf-8'}, (err, data) ->
	if err
		throw err

	emit out, codegen parse preprocess(data), ast
