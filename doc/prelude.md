prelude  
=======  
import this if you want anything to work  

  
## Symbols  
##### `*standard-output*`  
global symbol bound to the stdout stream  

  
## Functions  
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

  
##### `cons list elem`  
cons an element in front of a list  

  
##### `head list`  
return the first element of a list  

  
##### `list`  
create a list from given values  

  
##### `tail list`  
return the rest of the list, without head  

  
##### `map list fn`  
modify a list using a function, returning a new list  

  
