prelude  
=======  
import this if you want anything to work  

  
##### `exists thing`  
returns false if:  
- thing is a table or a string and thing.length is 0  
- thing is falsy (false, nil)  
  
if not, returns true.  

  
##### `exit-on-error! erfmt ...`  
exits with a formatted error message and status code 1.  

  
##### `prompt pstr predicate?`  
prompt the user for input, writing `pstr` before reading,  
tests given input against `pred`, exiting with status  
code -1 on failure.  

  
##### `print! stream string`  
print a string to a stream  

  
##### `print! stream fmtstr va_args`  
print a formatted string to a stream  

  
