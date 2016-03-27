hash-map
====
functions for manipulations of hash-maps.
## Functions
#### `hash-map/new [key value]*`
Create a new hash-map with keys and values given as variadic arguments.
Every two arguments constitutes a key:value pair.


#### `hash-map/empty`
Create an empty hashmap.


#### `hash-map/map map fun`
Map _fun_ over every value:key pair in the hash-map.


#### `hash-map/filter hm fun`
Filter the hash-map using _fun_.


#### `hash-map/size hm`
Determine the size of _hm_


#### `hash-map/set k v` and `hash-map/get k v`
Set or get a key in a hash map


