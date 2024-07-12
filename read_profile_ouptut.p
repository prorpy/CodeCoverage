DEFINE VARIABLE zprofData AS CHARACTER NO-UNDO.
DEFINE VARIABLE topLines  AS INTEGER   NO-UNDO INITIAL 20.

DEFINE TEMP-TABLE ttProfile
    FIELD id          AS INTEGER   FORMAT ">>>>9"
    FIELD pdate       AS DATE      FORMAT "99/99/99"
    FIELD description AS CHARACTER FORMAT "x(30)"
    INDEX profile-idx IS UNIQUE PRIMARY
    id
    INDEX profile-date
    pdate
    .

DEFINE TEMP-TABLE ttSource
    FIELD id         AS INTEGER   FORMAT ">>>>9"
    FIELD pid        AS INTEGER   FORMAT ">>>>>9"
    FIELD pname      AS CHARACTER FORMAT "x(40)"
    FIELD debug_name AS CHARACTER FORMAT "x(40)"
    INDEX source-idx IS UNIQUE PRIMARY
    id    pid
    INDEX source-name
    pname
    .

DEFINE TEMP-TABLE tt_tree
    FIELD id         AS INTEGER FORMAT ">>>>9"
    FIELD caller     AS INTEGER FORMAT ">>>>>9"
    FIELD src_line   AS INTEGER FORMAT ">>>>>9"
    FIELD callee     AS INTEGER FORMAT ">>>>>9"
    FIELD call_count AS INTEGER FORMAT ">>>>>9"
    INDEX tree-idx IS PRIMARY
    id caller src_line callee
    .

DEFINE TEMP-TABLE ttTime
    FIELD id         AS INTEGER FORMAT ">>>>9"
    FIELD pid        AS INTEGER FORMAT ">>>>>9"
    FIELD src_line   AS INTEGER FORMAT ">>>>>9"
    FIELD exec_count AS INTEGER FORMAT ">>>>>>>>>9"
    FIELD exe_time   AS DECIMAL FORMAT ">>>>>9.999999"
    FIELD tot_time   AS DECIMAL FORMAT ">>>>>9.999999"
    FIELD avg_time   AS DECIMAL FORMAT ">>>>>9.999999"
    INDEX ptime-idx IS UNIQUE PRIMARY
    id       pid        src_line
    INDEX avg-idx
    avg_time DESCENDING
    INDEX line-idx
    src_line
    INDEX ptime-pid-dExecutionTime
    id       pid        exe_time
    INDEX ptime-pid-iSessions
    id       pid        avg_time
    INDEX ptime-dExecutionTime
    id       exe_time
    INDEX ptime-iSessions
    id       avg_time
    .

DEFINE TEMP-TABLE ttCodeLine
    FIELD pid      AS INTEGER   FORMAT ">>>>>9"        /* program id#              */
    FIELD src_line AS INTEGER   FORMAT ">>>>9"         /* source line#             */
    FIELD pname    AS CHARACTER FORMAT "x(30)"         /* procedure or class name      */
    FIELD ipname   AS CHARACTER FORMAT "x(40)"         /* internal procedure or method name    */
    FIELD dExecutionTime       AS DECIMAL   FORMAT ">>>>>9.999999"     /* execution time           */
    FIELD iNumberOfCalls       AS INTEGER   FORMAT ">>>>>>>>>9"        /* calls                */
    FIELD iSessions       AS INTEGER   FORMAT ">>9"           /* sessions             */
    FIELD dAverageTime       AS DECIMAL   FORMAT ">>>>>9.999999"     /* average time             */
    INDEX bad-idx1 IS UNIQUE PRIMARY
    pid pname src_line
    INDEX bad-idx2
    iNumberOfCalls  iSessions
    INDEX bad-idx3
    dExecutionTime
    INDEX avg-idx
    dAverageTime
    .


/*********************************************************/

DEFINE STREAM inStrm.

PROCEDURE zprofiler_load:

    DEFINE INPUT PARAMETER zprofData AS CHARACTER NO-UNDO.

    DEFINE VARIABLE i          AS INTEGER   NO-UNDO.
    DEFINE VARIABLE v          AS INTEGER   NO-UNDO.
    DEFINE VARIABLE dt         AS DATE      NO-UNDO.
    DEFINE VARIABLE dsc        AS CHARACTER NO-UNDO.

    DEFINE VARIABLE profile_id AS INTEGER   NO-UNDO.

    EMPTY TEMP-TABLE ttProfile.
    EMPTY TEMP-TABLE ttSource.
    EMPTY TEMP-TABLE tt_tree.
    EMPTY TEMP-TABLE ttTime.

    FILE-INFO:FILE-NAME = zprofData + ".prof".

    IF FILE-INFO:FULL-PATHNAME = ? THEN
    DO:
        MESSAGE "Cannot find profiler .prof data file:" zprofData.
        PAUSE.
        RETURN.
    END.

    /* message "loading from:" file-info:full-pathname. /* session:date-format. */ pause. */

    INPUT stream inStrm from value( FILE-INFO:FULL-PATHNAME ).

    i = 1.

    REPEAT:               /* in theory there could be more than 1?  that would probably break a lot of stuff...   */

        IMPORT STREAM inStrm v /* dt */ ^ dsc NO-ERROR.     /* the profiler apparently ignores session:date-format...   */

        IF v <> 3 THEN
        DO:
            INPUT stream inStrm close.
            MESSAGE "Invalid version:" v.
            PAUSE.
            RETURN.
        END.

        /* message v dt dsc. pause. */              /* the profiler apparently ignores session:date-format...   */

        profile_id = i.

        CREATE ttProfile.
        ASSIGN
            ttProfile.id          = profile_id
            ttProfile.pdate       = TODAY /* dt */
            ttProfile.description = dsc
            .

        i = i + 1.

    END.

    /* message "profile id:" profile_id. pause. */

    i = 1.

    REPEAT:

        CREATE ttSource.
        ttSource.id = profile_id.
        IMPORT STREAM inStrm ttSource.pid ttSource.pname ttSource.debug_name NO-ERROR.

        i = i + 1.

    END.

    /* create ttSource. */       /* don't CREATE -- an extra will be left over from the REPEAT logic */
    ASSIGN
        ttSource.id         = profile_id
        ttSource.pid        = 0
        ttSource.pname      = "Session"
        ttSource.debug_name = "Session"
        .

    /* message "ttSource session record created". pause. */

    i = 1.

    REPEAT:

        CREATE tt_tree.
        tt_tree.id = profile_id.
        IMPORT STREAM inStrm tt_tree.caller tt_tree.src_line tt_tree.callee tt_tree.call_count NO-ERROR.

        i = i + 1.

    END.

    DELETE tt_tree.

    /* message i "tt_tree loaded". pause. */

    i = 1.

    REPEAT:

        CREATE ttTime.
        ttTime.id = profile_id.
        IMPORT STREAM inStrm ttTime.pid ttTime.src_line ttTime.exec_count ttTime.exe_time ttTime.tot_time NO-ERROR.
        ttTime.avg_time = ttTime.exe_time / ttTime.exec_count.

        i = i + 1.

    END.

    DELETE ttTime.
  //MESSAGE i "ttTime loaded" VIEW-AS ALERT-BOX.

// read the next . line
    DEFINE VARIABLE cLine AS CHARACTER.
    DEFINE VARIABLE iPid  AS INTEGER. 
    REPEAT:
        IMPORT STREAM inStrm cLine NO-ERROR.
    END.

    REPEAT:
        IMPORT STREAM inStrm iPid NO-ERROR.
        FIND FIRST ttSource
            WHERE ttSource.id = 1 AND
            ttSource.pid = iPid.
        REPEAT:
            CREATE ttCodeLine.
            IMPORT STREAM inStrm ttCodeLine.src_line NO-ERROR.
            ASSIGN 
                ttCodeLine.pid   = iPid
                ttCodeLine.pname = ttSource.pname.
        END. 
    END.
    DELETE ttCodeLine.
    
    INPUT stream inStrm close.

    RETURN.

END.


PROCEDURE zprofiler_proc:

    DEFINE VARIABLE c         AS INTEGER   NO-UNDO.
    DEFINE VARIABLE i         AS INTEGER   NO-UNDO.
    DEFINE VARIABLE dExecutionTime        AS DECIMAL   NO-UNDO FORMAT ">>>>>9.999999".
    DEFINE VARIABLE iNumberOfCalls        AS INTEGER   NO-UNDO FORMAT ">>>>>>>>>9".
    DEFINE VARIABLE iSessions        AS INTEGER   NO-UNDO FORMAT ">>9".

    DEFINE VARIABLE srcName   AS CHARACTER NO-UNDO.
    DEFINE VARIABLE iprocName AS CHARACTER NO-UNDO.

    FOR EACH ttTime NO-LOCK BY ttTime.avg_time DESCENDING:     

        /*  if exec_count < 1 /* or src_line = 0 */ then next. */

        FIND ttSource WHERE
            ttSource.id =  ttTime.id AND
            ttSource.pid = ttTime.pid NO-ERROR.

        IF NOT AVAILABLE( ttSource ) THEN
            srcName = "session".
        ELSE
            srcName = ttSource.pname.

        IF srcName BEGINS "lib/zprof" THEN NEXT.            /* don't include the profiler */

        FIND ttCodeLine WHERE
            ttCodeLine.pid      = ttTime.pid AND
            ttCodeLine.src_line = ttTime.src_line AND
            ttCodeLine.pname    = srcName /* ttSource.pname */ NO-ERROR.

        IF NOT AVAILABLE ttCodeLine THEN
        DO:
            CREATE ttCodeLine.
            ASSIGN
                i                     = i + 1
                ttCodeLine.pid      = ttTime.pid
                ttCodeLine.src_line = ttTime.src_line
                ttCodeLine.pname    = srcName
                .
        END.

    END.

    /* message i "entries processed". pause. */

    FOR EACH ttCodeLine:

        ASSIGN
            ttCodeLine.dExecutionTime = 0
            ttCodeLine.iNumberOfCalls = 0
            .

        FOR
            EACH ttSource WHERE
            ttSource.pname = ttCodeLine.pname,
            EACH ttTime WHERE
            ttTime.id       = ttSource.id  AND
            ttTime.pid      = ttSource.pid AND
            ttTime.src_line = ttCodeLine.src_line:      

            ASSIGN
                ttCodeLine.dExecutionTime = ttCodeLine.dExecutionTime + ttTime.exe_time
                ttCodeLine.iNumberOfCalls = ttCodeLine.iNumberOfCalls + ttTime.exec_count
                ttCodeLine.iSessions = ttCodeLine.iSessions + 1
                .

            IF ttTime.pid = 0 AND ttTime.src_line = 0 THEN ttCodeLine.dExecutionTime = ttTime.tot_time.

        END.

    END.

    FOR EACH ttCodeLine:

        ttCodeLine.dAverageTime = ( ttCodeLine.dExecutionTime / ttCodeLine.iNumberOfCalls ).    /* calculate the average time... */

        IF NUM-ENTRIES( ttCodeLine.pname, " " ) > 1 THEN
            ASSIGN
                ttCodeLine.ipname = ENTRY( 1, ttCodeLine.pname, " " )
                ttCodeLine.pname  = ENTRY( 2, ttCodeLine.pname, " " )
                .

    END.

    RETURN.

END.


PROCEDURE zprofiler_topx:

    DEFINE INPUT PARAMETER zprofData AS CHARACTER NO-UNDO.
    DEFINE INPUT PARAMETER toTTY     AS LOGICAL   NO-UNDO.
    DEFINE INPUT PARAMETER topLines  AS INTEGER   NO-UNDO.

    DEFINE VARIABLE c  AS INTEGER NO-UNDO.
    DEFINE VARIABLE i  AS INTEGER NO-UNDO.
    DEFINE VARIABLE dExecutionTime AS DECIMAL NO-UNDO FORMAT ">>>>>9.999999".
    DEFINE VARIABLE iNumberOfCalls AS INTEGER NO-UNDO FORMAT ">>>>>>>>>9".
    DEFINE VARIABLE iSessions AS INTEGER NO-UNDO FORMAT ">>9".

    DEFINE VARIABLE t9 AS INTEGER NO-UNDO.

    FIND FIRST ttProfile NO-LOCK NO-ERROR.   /* assuming that they're all the same date... */

    FOR EACH ttCodeLine NO-LOCK WHERE ttCodeLine.pname <> "session":
        t9 = t9 + ttCodeLine.dExecutionTime.
    END.

    IF toTTY = NO THEN OUTPUT to value( zprofData + ".rpt" ).
    DEFINE VARIABLE iTotalLinesOfCode AS INTEGER NO-UNDO.
    DEFINE VARIABLE iLinesNotCovered  AS INTEGER NO-UNDO. 
    DEFINE VARIABLE dCodeCoverage     AS DECIMAL NO-UNDO.
  
    FOR EACH ttCodeLine WHERE ttCodeLine.src_line <> 0 AND ttCodeLine.pname <> "session":
        iTotalLinesOfCode += 1.
        IF ttCodeLine.iSessions = 0 THEN 
            iLinesNotCovered += 1. 
    END. 
    dCodeCoverage = (iTotalLinesOfCode - iLinesNotCovered) / iTotalLinesOfCode * 100.
  
    DISPLAY
        ttProfile.description  LABEL "Description" FORMAT "x(70)" SKIP
        "Lines of code  " iTotalLinesOfCode  SKIP
        "Not covered " iLinesNotCovered SKIP 
        "Code coverage " dCodeCoverage SKIP SKIP 
        WITH FRAME prof-hdr
        TITLE " Profiler Results "
        WIDTH 120
        CENTERED
        OVERLAY
        5 DOWN 
        SIDE-LABELS
        ROW 1
        .

    FOR EACH ttCodeLine WHERE ttCodeLine.src_line <> 0 AND ttCodeLine.iSessions = 0:
        DISPLAY "Program " ttCodeLine.pname " Line " ttCodeLine.src_line
            WITH FRAME prof-coverage
            TITLE " Not covered "
            WIDTH 120
            CENTERED
            OVERLAY
            DOWN 
            SIDE-LABELS
            ROW 7
            .
    END. 

    IF toTTY = NO THEN
        OUTPUT close.
    ELSE
    DO:
        PAUSE.
        HIDE FRAME prof-rpt.
        HIDE FRAME prof-hdr.
    END.

    RETURN.

END.


//zprofData = ENTRY( 1, SESSION:PARAMETER, "|" ).
zprofData = "c:\temp\profiler".
IF NUM-ENTRIES( SESSION:PARAMETER, "|" ) = 2 THEN topLines = INTEGER( ENTRY( 2, SESSION:PARAMETER, "|" )).

RUN zprofiler_load( zprofData ).            /* load profiler data into temp-tables to analyze       */
RUN zprofiler_proc.                 /* process the data                     */
RUN zprofiler_topx( zprofData, NO,  topLines ).     /* report on the top X execution time lines -- to file      */

IF SESSION:BATCH = NO THEN
    RUN zprofiler_topx( zprofData, YES, topLines ).   /* report on the top X execution time lines -- to TTY       */

QUIT.