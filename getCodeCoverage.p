
/*------------------------------------------------------------------------
    File        : getCodeCoverage.p
    Purpose     : 

    Syntax      :

    Description : 

    Author(s)   : rpy
    Created     : Thu May 02 15:04:35 CEST 2024
    Notes       :
  ----------------------------------------------------------------------*/

/* ***************************  Definitions  ************************** */

BLOCK-LEVEL ON ERROR UNDO, THROW.

/* ********************  Preprocessor Definitions  ******************** */


/* ***************************  Main Block  *************************** */
VAR DECIMAL dCodeCoverage.
VAR LONGCHAR lcNotExecutedLines.
VAR CodeCoverage oCodeCoverage = NEW CodeCoverage().

MESSAGE oCodeCoverage:ReportCodeCoverage("c:\temp\profiler.prof").

oCodeCoverage:ReportCodeCoverageAndNotExecutedLines("c:\temp\profiler.prof", dCodeCoverage, lcNotExecutedLines).
MESSAGE dCodeCoverage
VIEW-AS ALERT-BOX.
COPY-LOB lcNotExecutedLines TO FILE "c:\temp\notexecutedlines.json".

