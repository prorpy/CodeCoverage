Use CodeCoverage to calculate the lines of code that are executed during a run, e.g. unit tests. 
The test directory generates a .prof file. 
getCodeCoverageSample.p shows the usage of the 2 public methods in CodeCoverage:
- return a decimal representing code coverage
- return a decimal representing code coverage and a longchar that contains a listing of all the lines of code that are NOT executed
