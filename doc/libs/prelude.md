gprelude
=======
import this if you want anything to work


## Symbols
###### `*standard-output*`
global symbol bound to the stdout stream


###### `*standard-error*`
global symbol bound to the stderr stream


###### `*standard-input*`
global symbol bound to the stdin stream


###### `*version*`
global symbol bound to the Lua version currently in use, and the semver version of the compiler itself


## Functions
###### `exit-on-error! erfmt ...` or `fail ...`
exits with a formatted error message and status code 1.


###### `print! stream string`
print a string to a stream


###### `print! stream fmtstr va_args`
print a formatted string to a stream


###### `format! fmtstr va_args`
print a formatted string to *standard-output* unconditionally


###### `cons list elem`
cons an element in front of a list


###### `head list`
return the first element of a list


###### `list`
create a list from given values


###### `push! car rest`
insert a value at the head of a list, mutating it.


###### `! end rest`
insert a value at the end of a list, mutating it.


###### `tail list`
return the rest of the list, without head


###### `map list fn`
modify a list using a function, returning a new list


###### `size li`
determine the size of a list.


###### `filter list fn`
filter a list using a predicate.


###### `curry fna fnb`
merge two functions together, applying the second over the result of the first


###### `compose fna fnb`
merge two functions together, applying the first over the result of the second


###### `exists thing`
returns false if:
- thing is a table or a string and thing.length is 0
- thing is falsy (false, nil)

if not, returns true.


###### `describe a`
format `a` for printing.


###### `type a`
reimplementation of Lua's `type`


###### `pair? a`
returns true if a is a pair


###### `pair? a`
returns true if a is a list


###### `eq? a b`
** deprecated **: use `=` instead.
returns true if both parameters are equal


###### `neq? a b`
** deprecated **: use `!=` instead.
returns true if both parameters are not equal


###### `nth num list`
get num-th element of list


###### `null? list`
returns true if list is empty.


###### `foldl func accum lst`
combine elements of a list into an accumulator using a function.


###### `truth?`
returns true if x is truthy, or:
- if x is a pair, return if the first element is truthy
- if x is a list, return if all elements are truthy.


###### `range end`
create a list of integers from 0 to `end`


###### `partial fn x`
return a function that when invoked applies the given function (`fn`) with parameters `x` and parameters given to the return function.


###### `flip x`
return a function that when invoked applies the given function (`x`) with it's parameters in reverse order.
###### `elem? a li`
return true if `a` is an element of `li`, false otherwise.


###### `join li1 li2`
join the two given lists


###### `copy li1`
copy a list
