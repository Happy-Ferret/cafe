# minilib
The minilib contains simple implementations of the buitlin functions needed
for Café programs to work. To use the minilib instead of the standard
prelude, pass the `--mini` flag to the compiler.
###### `compose fna fnb`
merge two functions together, applying the first over the result of the second


###### `partial fn x`
return a function that when invoked applies the given function (`fn`) with parameters `x` and parameters given to the return function.


###### `infix lhs op rhs...`
Apply an operation infixly.
