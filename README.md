Café  [![Build Status](https://travis-ci.org/demhydraz/cafe.svg?branch=master)](https://travis-ci.org/demhydraz/cafe)
---

_/ˈkæfeɪ/_

Café is a tiny Lisp that compiles to Lua. It features operator overloading, a rudimentary macro system, a comprehensive standard library which extends the Lua libraries, including hash-map manipulation (internally maps to tables) and a small, but fast testing framework.

Why?
---

I really like Lisps.

The comprehensive syntatical macro system based on the fact that the line between syntax and data in most Lisps is a very blurry one is incredibly powerful, giving the developer the ability to extend syntax in-flight, without any special compiler support, apart from macro expansion.

How?
---

Cáfe is, currently, implemented in Node.js using CoffeeScript, an elegant syntatical overlay over JavaScript. Thus, it runs in any platforms that Node.js can run on, including Windows, Mac, Linux and the BSDs. Windows support, however, is not guaranteed.

The parser is based on a simple if-else chain for categorizing expressions in expressions, and the code generator is implemented as a switch statement. This does not lead to the most robust of compiler systems. There is presently no in-place system for reporting syntatical errors, much less semantic ones.

The parser uses simple renaming rules to generate valid Lua symbols, including table accesses, from Café symbols, which, through the use of punycode and regex, can support pretty much any unicode symbol.[¹](http://i.imgur.com/sky28Ud.png)

The macro system is also implemented as a simple set of substitution over a template, and still needs much work.

Learning
---

The official reference for the language resides in this repository, under [doc/tutorial](http://github.com/demhydraz/cafe/blob/master/doc/tutorial/intro.md). It is, however, not complete.
