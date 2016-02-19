{ parse }         = require './front'
{ codegen, emit } = require './back'

emit codegen parse """
(defn (exists n)
	(if n
		(if (== (# n) 0)
			false
			true)
		false))

(defn (prompt pchr)
	(io.write pchr)
	(let ((ret (io.read)))
		(if pred
			(if (not pred)
				(error "Doesn't pass predicate!")
				ret)
			ret)))

(defn (format fmtstr ...)
	(print (string.format fmtstr ...)))

(let ((my_var (prompt "enter your name: " exists)))
	(format "Hello, %s!" my_var))
"""

# (defn (format fmtstr ...)
# 	(print (string.format fmtstr ...)))
#
# (if pred
# (if (not (pred))
# (error "doesn't pass predicate!")
# ret)))
#
# (let ((my_var (prompt "enter your name: " (λ (ret)
# 	(if (eq? (# ret) 0)
# 		false
# 		(if (eq? ret "")
# 			false
# 			true))))))
# 	(format "Hello, %s!" my_var))
