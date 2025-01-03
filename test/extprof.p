VAR INTEGER iCount.

FOR EACH customer:
    iCount += 1.
END. 

PROCEDURE doSomething:
    VAR CHARACTER cTemp.
    cTemp = 'Not executed'.
END PROCEDURE.

FOR EACH customer:
    iCount += 1.
END. 
