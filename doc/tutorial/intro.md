Café
---

# Introduction
Café is a tiny lisp-like, written in CoffeeScript, that compiles to Lua.

Much like other lisps, all function calls (including operators, more on that later) are prefix-notation. Café also supports a number of syntactical constructs, such as `cond`, `cut` and `cute`, and allows for adaptation of the language for a given problem domain by use of the powerful (yet in-development) macro system.

You can type examples of code in the REPL (read [getting started](example.com)) to see their result; Lines prefixed with `λ>` need not the prefix to be copied.

---

### The Obligatory Hello World

There are, confusingly enough, many ways to print 'hello world' to standard output in Café.

The preffered way is:
```clojure
(print! *standard-output* "Hello, world!")
```

But you can also make use of Lua's built-in `print`:

```clojure
(print "Hello, world!")
```

Or by directly calling the `.write` method on `*standard-output*`:

```clojure
(.*standard-output* write "Hello, world!\n")
```

### Doing Maths

Café has no concept of _operators_. Really, internally, they're just functions provided by the standard library. The standard library provides the following operator functions, by default:

    + - / % = != > < and or >= <= ^ # >> << | & ~

To get the operator function of a given operator, prepend `#^` to the name. So the operator `+` is actually a call to `#^+`.

Since built-in operators are just functions, most operators can take variable number arguments (`#`, `not` and `~` take one argument and `>`, `>`, `>=` and `<=` take 2).

Here's some simple arithmetic:

```clojure
λ> (+ 2 2)
→ number: 4
λ> (* 49 100)
→ number: 4900
λ> (- 1892 1472)
→ number: 420
λ> (/ 5 2)
→ number: 2.5
λ>
```

Since all function calls are prefix notation, there are no precedence rules. Parameters are evaluated in-place before being passed to the function.

You can nest function calls, however, to mimic compound expressions; The following is equivalent to `(2 + 2) * 3`.
```clojure
λ> (* 3 (+ 2 2))
→ number: 12
```

To get a negative number, you can either do `-3`, or the more idiomatic `(- 0 3)`. Both are equivalent.

All valid floating-point numbers in JavaScript are treated as valid by the compiler. This includes numbers in scientific notation (`1.3e5` for `1.3 × 10⁵`) and hexadecimal literals with fractional parts.

```clojure
λ> (+ 5 5)
→ number: 10
λ> (+ 5 1e1)
→ number: 15.0
λ> (+ 5 1e25)
→ number: 1e+25
λ> (+ 5 0xf)
```

Boolean algebra is also supported, through the `and`, `or` and `not` ~~functions~~ operators.

```clojure
λ> (and true true)
→ boolean: true
λ> (and true false)
→ boolean: false
λ> (or false true)
→ boolean: true
λ> (?? false true)
→ boolean: true
λ> (not false)
→ boolean: true
λ> (not true)
→ boolean: false
λ> (not (and true true))
→ boolean: false
```

As you could notice, `??` is a synonym for `or`. Idiomatically, it's used for _nil coalescion_: transforming a value that might be nil into a safe value. For example:

```clojure
λ> (?? nil "hello")
→ string: hello
```

Testing for equality is done like so.
```clojure
→ boolean: true
λ> (= 1 0)
→ boolean: false
λ> (!= 5 5)
→ boolean: false
λ> (!= 5 4)
→ boolean: true
λ> (= "hello" "hello")
→ boolean: true
```

Café is, much like Lua, a non-strictly-typed language. This means that comparisons like `(= 5 "llama")`, while insane in theory, are totally valid. They will, however, return false, as the first thing `#^=` does is compare the types.

Behaviour of the `#^+` function can be quite confusing, because of it's type coercion rules, but here it goes:

- In case the first argument is a string, the second argument determines behaviour:
	- If the second argument is a list, it _conses_ the first argument onto the second;
	- If the second argument is anything else, it concatenates the first argument with the second.
- If the first argument is a list, the second argument determines behaviour:
	- If it is a list, the two lists are _joined_.
	- If it is not a list, the second argument is placed after the last element of the first list.
- If the first argument is neither a string, nor a list, again, behaviour depends on the second parameter:
	- If it's a list, it _conses_ the first argument onto the second;
	- If it is not, it calls the number addition operation `+` in Lua.

Phew! That's a lot to take in. Let's exemplify.

```clojure
λ> (+ 1 1) ; addition
→ number: 2
λ> (+ "a" "b") ; concatenation
→ string: ab
λ> (+ "a" '(1 2)) ; consing
→ list: (a, 1, 2)
λ> (+ '("a" "b") '("c" "d")) ; joining
→ list: (a, b, c, d)
```

See? That wasn't so hard. But wait up - what's that weird `'()` notation?
In many lisps, `'` is shorthand (a reader macro) for `quote`. But in Café, `'` is a compiler built-in for invoking the `list` function. So `'(1 2 3)` is `(list 1 2 3)`, which is a list of ones, twos and threes.

This operation is called `quoting`.

---

You may have known that we've been using functions all along. `+` is but a function that does... something.. to it's arguments. In Lisp, all functions are called in prefix notation (except when they aren't; more on that later).

Functions are the first element of a non-quoted list, and their arguments follow, delimited by spaces.

If a list is quoted, it is but a list; However, if a list is non-quoted, it's shiny and receives the name of _expression_. Expressions form the base of all Lisps.

For a start, we'll call one of the most boring functions in Café.

```clojure
λ> (succ 8)
→ number: 9
```

The `succ` functions takes a number with a defined successor and returns that successor.

Calling a function with several arguments is also simple.

```clojure
λ> (math/min 9 10)
→ number: 9
λ> (math/min 3.4 3.2)
→ number: 3.2
λ> (math/max 100 101)
```

The `min` and `max` functions, in the `math` namespace (`name/` means the namespace n, except when it doesn't; sometimes it can mean table access too.), take some numbers that can be put in order and returns the smallest and highest of them, respectively.

### Your first functions

In the previous section, we covered how to call functions. Now let's make our own. Open up the REPL and punch in this declaration that takes a number and doubles it:

```clojure
λ> (defn (doubleMe' x) (+ x x))
λ>
```

You see how that `defn` didn't have a result? That's because it isn't evaluated. Instead, it is compiled into a function-definition and stored for later use.

Now that this function is loaded, let's call it:
```clojure
λ> (doubleMe' 9)
→ number: 18
λ> (doubleMe' 8.3)
→ number: 16.6
```

Cool!

Remember how we talked about the oddities of the `+` operator? This means that `doubleMe'`, our little function, can, without extra effort, work on both strings and lists.

```clojure
λ> (doubleMe' "hello ")
→ string: hello hello
λ> (doubleMe' '(1 2 3))
→ list: (1, 2, 3, 1, 2, 3)
λ> (doubleMe' true)
```

Let's make a function that will take _two_ numbers and double them together.
```clojure
λ> (defn (doubleUs' x y) (+ (* x 2) (* y 2)))
λ>
```

Done. We could also have defined it as `(defn (doubleUs' x y) (+ x x y y))`

```clojure
λ> (doubleUs 4 9)
→ number: 26
λ> (doubleUs 2.3 34.2)
→ number: 73.0
λ> (+ (doubleUs 28 88) + (doubleMe' 123))
→ number: 478
```

Now, we're going to make a function that multiplies a number by 2, but only if that number is smaller than or equal to 100, because numbers bigger than 100 are big enough as it is!

Load your favourite text editor and punch in the following snippet.

```clojure
(defn (doubleSmallNumber x)
	(if (> x 100)
		x           ; truth branch
		(* 2 x)))   ; false branch
```

Now load it in the REPL.

```
λ> ,import doubleSmallNumber.cafe
→ Imported doubleSmallNumber.cafe. 4 modules currently compiled.
```

Nice- Wait, what? FOUR?? But I only loaded one!
Implicitly, at the start of a session, the REPL loads and compiles 3 of the built-in libraries: `hashmap`, `math` and the `prelude`. `,import`-ed modules are also placed in this same cache, as are function and variable declarations.

In this function definition, we introduced the _if expression_. If is a special form that evaluates a condition (the first expression after `if` itself, in our case `(> x 100)`), and if it's truthy, returns the second expression (the `truth` branch), and if it's not, returns the third expression (the `false` branch.)

As the name implies, if _is_ just another expression. It behaves much like a special function, that evaluates it's arguments conditionally. So, you can use _if_-expressions as arguments to a function!

If you want to, say, add 1 to every number the previous function produced, you could write it like this.

```clojure
(defn (doubleSmallNumber' x)
	(+ 1 (if (> x 100)
		x
		(* 2 x))))
```

In Café, much like other lisps, the only whitespace that matters is the one between terms of an expression; Anything else is irrelevant. It is, however, good style to indent your code into logical blocks, namely after the first term of a special form, and to push "heavier" expressions to the bottom of the terms, if possible.

---

### Variables? What are those‽

A variable is a mutable binding to a value that can be used as a term in an expression. _Wha?_

A variable is, in simpler terms, an association, between a _name_ and a _value_.

There are a bunch of characters that can be used in identifiers, but the most common are expressed here as a regex:  
```regex
/[a-zA-Z0-9?!'-]+/
```

That means...
- All alphanumerical characters,
- Interrogation and exclamation points,
- The hyphen/minus `-`.

But wait up! Weren't you using `/` in identifiers before?

No. `/` splits up the identifier into a number of parts: The _context_ (what's before the `/`), and the _element_ (what's after the `/`). You can nest them, too! `a/b/c/d` is a valid context-element sequence, with 3 contexts.

Anything that can be on the right-hand side of a definition is called an _rvalue_. Most of the times, _rvalue_ is just another term for expression.

The left-hand-side of the definition, however, is more constrained. These so-called _lvalues_ can only be names, or lists (unquoted) of names.

If there's a single name, the whole rvalue is stored in that name. If there is, however, a list of names, the rvalue is broken up into sequencial bits, and those are stored in the corresponding name of the list.

For example,

```clojure
λ> (def a '(1 2 3))
λ> (def (a' b c) '(1 2 3))
```

In that first case, the whole list of one, two and three is bound to a. However, in the second declaration, each number of the list is bound to one of the names.
