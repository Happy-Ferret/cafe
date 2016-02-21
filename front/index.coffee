{ parse, symbol } = require './parser'
{ preprocess }    = require './preproc'

module.exports.parse = parse
module.exports.preprocess = preprocess
module.exports.symbol = symbol
