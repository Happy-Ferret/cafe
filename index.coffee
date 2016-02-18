{ parse }                     = require './front'
{ codegen, emit } = require './back'

emit codegen parse """
(defn (format fmtstr ...)
	(print (string.format fmtstr ...)))

(format "Hello, %s!" "ybden")
(format "1 << 32 = %d" (<< 1 32))
"""
