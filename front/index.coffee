{ parse, symbol, toks2ast } = require './parser'
{ preprocess }    = require './preproc'

module.exports.parse = parse
module.exports.preprocess = preprocess
module.exports.symbol = symbol
module.exports.toks2ast = toks2ast
