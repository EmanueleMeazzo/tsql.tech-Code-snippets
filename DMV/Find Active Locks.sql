SELECT CASE [DTL].[request_session_id]
           WHEN-2 THEN 'ORPHANED DISTRIBUTED TRANSACTION'
           WHEN-3 THEN 'DEFERRED RECOVERY TRANSACTION'
           ELSE [DTL].[request_session_id]
       END AS [SPID],
       DB_NAME([DTL].[resource_database_id]) AS [DATABASENAME],
       [SO].[name] AS [LOCKEDOBJECTNAME],
       [DTL].[resource_type] AS [LOCKEDRESOURCE],
       [DTL].[resource_description] AS [RESOURCEDESCRIPTION],
       [DTL].[REQUEST_MODE] AS [LOCKTYPE],
       [ST].TEXT AS [SQLSTATEMENTTEXT],
       [ES].[LOGIN_NAME] AS [LOGINNAME],
       [ES].HOST_NAME AS [HOSTNAME],
       CASE [TST].[IS_USER_TRANSACTION]
           WHEN 0 THEN 'SYSTEM TRANSACTION'
           WHEN 1 THEN 'USER TRANSACTION'
       END AS [USER_OR_SYSTEM_TRANSACTION],
       [AT].[name] AS [TRANSACTIONNAME],
       [DTL].[REQUEST_STATUS]
FROM   SYS.DM_TRAN_LOCKS AS DTL
JOIN SYS.PARTITIONS AS SP
ON SP.HOBT_ID = DTL.RESOURCE_ASSOCIATED_ENTITY_ID
JOIN SYS.OBJECTS AS SO
ON SO.OBJECT_ID = SP.OBJECT_ID
JOIN SYS.DM_EXEC_SESSIONS AS ES
ON ES.SESSION_ID = DTL.REQUEST_SESSION_ID
JOIN SYS.DM_TRAN_SESSION_TRANSACTIONS AS TST
ON ES.SESSION_ID = TST.SESSION_ID
JOIN SYS.DM_TRAN_ACTIVE_TRANSACTIONS AT
ON TST.TRANSACTION_ID = AT.TRANSACTION_ID
JOIN SYS.DM_EXEC_CONNECTIONS AS EC
ON EC.SESSION_ID = ES.SESSION_ID
OUTER APPLY SYS.DM_EXEC_SQL_TEXT(EC.MOST_RECENT_SQL_HANDLE) AS ST
WHERE  [RESOURCE_DATABASE_ID] = DB_ID()
ORDER BY [DTL].[REQUEST_SESSION_ID];
