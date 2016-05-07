# Lists

Lists are heterogeneous, recursive data structures that store a collection of things. These things can be of any type, and you can have many types of things in a list.

In this section, we'll take a look at lists, list manipulation, and generators functions.

---

```
λ> (def some-numbers '(4 8 15 16 23 42))
λ> (describe some-numbers)
→ string: (4, 8, 15, 16, 23, 42)
```

> **Note**: keep that REPL open!  
> We'll be using the `some-numbers` list thoughout our examples, so keep it in memory.  
> The REPL can, however, save history to a file, but who wants to press that up key 20 times?

As you can see, much like other expressions, a list is a function call. In this case, it's a very sweet function call - the actual function is hidden behind syntactic sugar, and all you can see are the terms.

The function to build a list is the `list` function, and as discussed before, `'()` is shorthand for calling that.

But what _is_ a list? Lists can't be magic, can they?

They're not.

---

#### Lists?!

Remember how we talked about _consing_ an element to the front of a list before? Well.. all lists are just conses. In reality, what you're doing is creating a _new_ list, and setting the tail of that list to the list you had before. But if that's all lists are, then how do you create a new list?

The only list that's _actually_ magic is the empty list, `'()`.

To create a list `'(1 2 3 4)`, what you're actually doing is just nested cons:

```clojure
(1 . (2 . (3 . (4 . '()))))
```

or

```plain
* - * - * - * - '()
|   |   |   |
1   2   3   4
```

Since in reality there's no list manipulation actually going on, consing onto a list is instantaneous.

---

Now that we know how to make lists, what can we do with them? Well, just _having_ a data structure is pretty useless if we can't do anything with it.  
So, obviously, we can do stuff with lists.

#### Indexing

Indexing just means _taking the element at a given position_. Café lists start indexing at 1, so the first element is accessible through index 1.

Indexing can be done with either `nth` or with `!!`. It takes a number and a list, in that order, and returns the *n*-th element of that list.

```clojure
λ> (!! 1 some-numbers)
→ number: 4
λ> (!! 3 some-numbers)
→ number: 15
```

#### Heads or Tails?

- `head` takes a list and returns its head. The head of a list is just its first element.
- `tail` takes a list and returns its tail. In other words, it chops off a list's head.
- `last` takes a list and returns its last element.
- `init` takes a list and returns everything except its last element.

In other words...

```clojure
λ> (head some-numbers)
→ number: 4
λ> (tail some-numbers)
→ list: (8, 15, 16, 23, 42)
λ> (last some-numbers)
→ number: 42
λ> (init some-numbers)
→ list: (4, 8, 15, 16, 23)
```

If we think of the list as elements linked in a chain, here's what's what.
```plain
[ head ]   [   tail    ]
  1      · 2 · 3 · 4 · 5
[       init       ]   │
                  last ┘
```

There's no special behaviour in-place for when you take apart an empty list; All functions just return `nil`.

---

- `#^#` takes a list and returns its length. D'oh.
```
λ> (# some-numbers)
→ number: 6
```
- `null?` checks if a list is empty. If it is, it returns true, otherwise it returns false.
```
λ> (null? some-numbers)
→ boolean: false
λ> (null? '())
→ boolean: true
```
- `reverse` reverses a list.
```
λ> (reverse some-numbers)
→ list: (42, 23, 16, 15, 8, 4)
```
- `take` takes number and a list. It extracts that many elements from the beginning of the list. Watch.
```
λ> (take 4 some-numbers)
→ list: (4, 8, 15, 16)
λ> (take 2 (reverse some-numbers))
→ list: (42, 23)
λ> (take 9 (reverse some-numbers))
→ list: (false, you can't take 9 from a list of length 6)
```

See how if we try to take more elements from a list than a list has, it returns a pair of values? Such a pair is called a _tuple_, and it's actually not a collection of two values; It's two scalar values returned together by a function. In this case, it returns `false` to indicate failure, and an error message.

- `elem?` takes a thing and a list, and returns true if the thing you gave it is in the list, returning false otherwise.

It's most commonly used in conjunction with the _infix_ macro, as it's easier to read like that.

```
λ> (elem? 42 some-numbers)
→ boolean: true
λ> (infix 42 elem? some-numbers)
→ boolean: true
λ> (infix 99 elem? some-numbers)
→ boolean: false
```

- `range` takes a number and returns a list from 1 up to that number.
For example, `(range 20)` returns a list `'(1 2 3 ... 20)`. And `(infix 18 !! (range 20))` is just 18.

#### Folding those Maps

<!-- TODO write this section -->

#### Generator functions and Infinite Lists
<!-- TODO write code to document here :stuck_out_tongue: -->
