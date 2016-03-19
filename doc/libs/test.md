test  
====  
simple, functional testing framework for café.  
test operates on simple expected value / actual value comparisons, and classifies tests as 'failed' or 'passed'.  
it also features a simple test results screen that displays  
- passed test count (and percentage)  
- failed test count (and percentage)  
- description of all passed tests  
- description, actual value and given value of all failed tests  


  
test puts all functions in the namespace `tests/`.  
## Functions  
#### `tests/fail-test desc value expr`  
internal use function for adding a test to the failed-tests list.  


  
#### `tests/fail-test desc value expr`  
internal use function for adding a test to the passed-tests list.  


  
#### `tests/print-tests`  
print tests results as described in the opening paragraph  


  
#### `tests/expect! expr value desc`  
Compare expected values and given values, then appropriately class the test as passed or failed.  


