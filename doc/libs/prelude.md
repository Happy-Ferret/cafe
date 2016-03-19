prelude  
=======  
import this if you want anything to work  


  
## Symbols  
##### `*standard-output*`  
global symbol bound to the stdout stream  


  
##### `*version*`  
global symbol bound to the Lua version currently in use, and the semver version of the compiler itself  


  
## Functions  
##### `exit-on-error! erfmt ...` or `fail ...`  
exits with a formatted error message and status code 1.  


  
##### `prompt pstr predicate?`  
prompt the user for input, writing `pstr` before reading,  
tests given input against `pred`, exiting with status  
code -1 on failure.  


  
##### `print! stream string`  
print a string to a stream  


  
##### `print! stream fmtstr va_args`  
print a formatted string to a stream  


  
#### `format! fmtstr va_args`  
print a formatted string to *standard-output* unconditionally  


  
##### `require! module`  
require a Lua module into the current environment  
  
support for hot-compilation of café modules will be added at a later date.  


  
##### `cons list elem`  
cons an element in front of a list  


  
##### `head list`  
return the first element of a list  


  
##### `list`  
create a list from given values  


  
##### `push! car rest`  
insert a value at the head of a list, mutating it.  


  
##### `push-tail! end rest`  
insert a value at the end of a list, mutating it.  


  
##### `tail list`  
return the rest of the list, without head  


  
##### `map list fn`  
modify a list using a function, returning a new list  


  
##### `size li`  
determine the size of a list.  


  
##### `filter list fn`  
filter a list using a predicate.  


  
##### `curry fna fnb`  
merge two functions together  


  
##### `exists thing`  
returns false if:  
- thing is a table or a string and thing.length is 0  
- thing is falsy (false, nil)  
  
if not, returns true.  


  
##### `describe a`  
format `a` for printing.  


  
##### `type a`  
reimplementation of Lua's `type`  


  
##### `pair? a`  
returns true if a is a pair  


  
##### `pair? a`  
returns true if a is a list  


  
##### `eq? a b`  
returns true if both parameters are equal  


  
##### `neq? a b`  
returns true if both parameters are not equal  


  
##### `nth num list`  
get num-th element of list  


  
##### `null? list`  
returns true if list is empty.  


  
##### `foldl func accum lst`  
combine elements of a list into an accumulator using a function.  


  
##### `truth?`  
returns true if x is truthy, or:  
- if x is a pair, return if the first element is truthy  
- if x is a list, return if all elements are truthy.  


