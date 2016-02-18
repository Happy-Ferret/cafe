class module.exports.ASTInstrospector

codegen_mod = require('./codegen')

for key, value of codegen_mod
	module.exports[key] = value
