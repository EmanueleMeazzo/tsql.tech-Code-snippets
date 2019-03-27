-- List all Locks of the Current Database 
SELECT TL.resource_type AS ResType 
      ,TL.resource_description AS ResDescr 
      ,TL.request_mode AS ReqMode 
      ,TL.request_type AS ReqType 
      ,TL.request_status AS ReqStatus 
      ,TL.request_owner_type AS ReqOwnerType 
      ,TAT.[name] AS TransName 
      ,TAT.transaction_begin_time AS TransBegin 
      ,DATEDIFF(ss, TAT.transaction_begin_time, GETDATE()) AS TransDura 
      ,ES.session_id AS S_Id 
      ,ES.login_name AS LoginName 
      ,COALESCE(OBJ.name, PAROBJ.name) AS ObjectName 
      ,PARIDX.name AS IndexName 
      ,ES.host_name AS HostName 
      ,ES.program_name AS ProgramName 
      ,ST.Text as SQLStatementText
FROM sys.dm_tran_locks AS TL 
     INNER JOIN sys.dm_exec_sessions AS ES 
         ON TL.request_session_id = ES.session_id 
     LEFT JOIN sys.dm_tran_active_transactions AS TAT 
         ON TL.request_owner_id = TAT.transaction_id 
            AND TL.request_owner_type = 'TRANSACTION' 
     LEFT JOIN sys.objects AS OBJ 
         ON TL.resource_associated_entity_id = OBJ.object_id 
            AND TL.resource_type = 'OBJECT' 
     LEFT JOIN sys.partitions AS PAR 
         ON TL.resource_associated_entity_id = PAR.hobt_id 
            AND TL.resource_type IN ('PAGE', 'KEY', 'RID', 'HOBT') 
     LEFT JOIN sys.objects AS PAROBJ 
         ON PAR.object_id = PAROBJ.object_id 
     LEFT JOIN sys.indexes AS PARIDX 
         ON PAR.object_id = PARIDX.object_id 
            AND PAR.index_id = PARIDX.index_id 
     LEFT JOIN sys.dm_exec_connections AS EC
         ON EC.session_id = ES.session_id
    OUTER APPLY sys.dm_exec_sql_text(EC.most_recent_sql_handle) AS ST
WHERE TL.resource_database_id  = DB_ID() 
      AND ES.session_id <> @@Spid -- Exclude "my" session 
      -- optional filter  
      AND TL.request_mode <> 'S' -- Exclude simple shared locks 
ORDER BY TL.resource_type 
        ,TL.request_mode 
        ,TL.request_type 
        ,TL.request_status 
        ,ObjectName 
        ,ES.login_name;
