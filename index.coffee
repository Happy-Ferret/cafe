{ parse }         = require './front'
{ codegen, emit } = require './back'

emit codegen parse """
(defn (format fmtstr ...)
	(print (string.format fmtstr ...)))

(format "Hello, %s!" "person")
(format "1 << 32 = %d" (<< 1 32))
"""
