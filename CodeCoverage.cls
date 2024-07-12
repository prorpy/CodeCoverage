 
/*------------------------------------------------------------------------
   File        : CodeCoverage
   Purpose     : 
   Syntax      : 
   Description : 
   Author(s)   : rpy
   Created     : Thu May 02 13:45:04 CEST 2024
   Notes       : 
 ----------------------------------------------------------------------*/

USING Progress.Lang.*.

BLOCK-LEVEL ON ERROR UNDO, THROW.

CLASS CodeCoverage: 
    DEFINE TEMP-TABLE ttProfile
        FIELD iIdentifier   AS INTEGER  
        FIELD dtProfileDate AS DATE      
        FIELD cDescription  AS CHARACTER 
        INDEX ttProfile-prim IS UNIQUE PRIMARY iIdentifier
        INDEX ttProfile-profiledate            dtProfileDate.

    DEFINE TEMP-TABLE ttSource
        FIELD iIdentifier  AS INTEGER   INITIAL 1   
        FIELD iProgramId   AS INTEGER   
        FIELD cProgramName AS CHARACTER 
        INDEX ttSource-prim IS UNIQUE PRIMARY iIdentifier  iProgramId
        INDEX ttSource-programname            cProgramName.

    DEFINE TEMP-TABLE ttTime
        FIELD iIdentifier AS INTEGER INITIAL 1
        FIELD iProgramId  AS INTEGER 
        FIELD iSourceLine AS INTEGER 
        INDEX ttTime-prim IS UNIQUE PRIMARY iIdentifier iProgramId iSourceLine
        INDEX ttTime-sourceline             iSourceLine.

    DEFINE TEMP-TABLE ttCodeLine
        FIELD iProgramId   AS INTEGER   SERIALIZE-HIDDEN 
        FIELD cProgramName AS CHARACTER SERIALIZE-NAME "Program":U
        FIELD cUnitName    AS CHARACTER SERIALIZE-NAME "Unit":U
        FIELD iSourceLine  AS INTEGER   SERIALIZE-NAME "Line":U 
        FIELD lExecuted    AS LOGICAL   SERIALIZE-HIDDEN  
        INDEX ttCodeLine-prim IS UNIQUE PRIMARY iProgramId cProgramName iSourceLine.

    /*------------------------------------------------------------------------------
     Purpose:
     Notes:
    ------------------------------------------------------------------------------*/
    DEFINE STREAM sProfiler. 

    METHOD PUBLIC VOID ReportCodeCoverageAndNotExecutedLines(INPUT pcFileName AS CHARACTER, OUTPUT pdCodeCoverage AS DECIMAL, OUTPUT lcNotExecutedLines AS LONGCHAR):
        pdCodeCoverage = ReportCodeCoverage(pcFileName).
        TEMP-TABLE ttCodeLine:WRITE-JSON('longchar':U, lcNotExecutedLines, TRUE).
    END METHOD. 
    
    METHOD PUBLIC DECIMAL ReportCodeCoverage(INPUT pcFileName AS CHARACTER):
        OpenStream(pcFileName).
        ReadProfile().
        ReadSource().
        ReadTree().
        ReadTime().
        ReadCode().

        RETURN ProcessProfilerAndCalculateCoverage().
    END METHOD.

    METHOD PRIVATE VOID OpenStream(INPUT pcFileName AS CHARACTER):
        FILE-INFO:FILE-NAME = pcFileName.
    
        IF FILE-INFO:FULL-PATHNAME = ? THEN
            UNDO, THROW NEW Progress.Lang.AppError('Profiler file not found: ' + STRING(pcFileName)).

        EMPTY TEMP-TABLE ttProfile.
        EMPTY TEMP-TABLE ttSource.
        EMPTY TEMP-TABLE ttTime. 
        EMPTY TEMP-TABLE ttCodeLine. 

        INPUT STREAM sProfiler FROM VALUE( FILE-INFO:FULL-PATHNAME ).
    END METHOD.
    
    METHOD PRIVATE VOID ReadProfile():
        VAR INTEGER   iVersion.
        VAR CHARACTER cDescription. 
        VAR INTEGER   iProfile = 1.
        
        REPEAT:             
            IMPORT STREAM sProfiler iVersion ^ cDescription NO-ERROR.    
            IF iVersion <> 3 THEN
            DO:
                INPUT STREAM sProfiler CLOSE.
                UNDO, THROW NEW Progress.Lang.AppError('Invalid profiler version: ' + STRING(iVersion)).
            END.
            CREATE ttProfile.
            ASSIGN
                ttProfile.iIdentifier   =  iProfile
                ttProfile.dtProfileDate =  TODAY 
                ttProfile.cDescription  =  cDescription
                iProfile                += 1.
        END.
    END METHOD.
    
    METHOD PRIVATE VOID ReadSource ():
        REPEAT:
            CREATE ttSource.
            IMPORT STREAM sProfiler ttSource.iProgramId ttSource.cProgramName NO-ERROR.
        END.
        ASSIGN
            ttSource.iProgramId   = 0
            ttSource.cProgramName = "Session":U.
    END METHOD.
    
    METHOD PRIVATE VOID ReadTree(  ):
        VAR INTEGER iLine.
        REPEAT:
            IMPORT STREAM sProfiler iLine NO-ERROR.
        END.
    END METHOD.
    
    METHOD PRIVATE VOID ReadTime(  ):
        REPEAT:
            CREATE ttTime.
            IMPORT STREAM sProfiler ttTime.iProgramId ttTime.iSourceLine NO-ERROR.
        END.
        DELETE ttTime.
    END METHOD.

    METHOD PRIVATE VOID ReadCode(  ):
        VAR CHARACTER cLine.
        VAR CHARACTER cUnitName.
        VAR INTEGER   iProgramId.

        REPEAT:
            IMPORT STREAM sProfiler cLine NO-ERROR.
        END.

        REPEAT:
            IMPORT STREAM sProfiler iProgramId cUnitName NO-ERROR.
            FIND FIRST ttSource
                WHERE ttSource.iIdentifier = 1 AND
                ttSource.iProgramId = iProgramId.
            REPEAT:
                CREATE ttCodeLine.
                IMPORT STREAM sProfiler ttCodeLine.iSourceLine NO-ERROR.
                ASSIGN 
                    ttCodeLine.iProgramId   = iProgramId
                    ttCodeLine.cProgramName = ttSource.cProgramName
                    ttCodeLine.cUnitName    = cUnitName.
            END. 
        END.
        DELETE ttCodeLine.
    
        INPUT stream sProfiler close.
    END METHOD.
    
    METHOD PRIVATE DECIMAL ProcessProfilerAndCalculateCoverage(  ):
        VAR INTEGER iTotalLinesOfCode.
        VAR INTEGER iLinesNotCovered.

        FOR EACH ttCodeLine:
            IF ttCodeLine.iSourceLine = 0 OR ttCodeLine.cProgramName = "session":U THEN 
                DELETE ttCodeLine. 
            ELSE 
            DO:  
                iTotalLinesOfCode += 1.
                IF CAN-FIND(FIRST ttTime WHERE 
                                  ttTime.iProgramId = ttCodeLine.iProgramId AND
                                  ttTime.iSourceLine = ttCodeLine.iSourceLine) THEN 
                  DELETE ttCodeLine.
                ELSE 
                  iLinesNotCovered += 1.     
            END.                   
        END. 
        RETURN (iTotalLinesOfCode - iLinesNotCovered) / iTotalLinesOfCode * 100.
    END METHOD.

END CLASS.