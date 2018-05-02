--Source: https://sqlperformance.com/2015/06/extended-events/t-sql-tuesday-67-backup-restore?utm_source=ebook&utm_medium=pdf&utm_term=Michael&utm_content=5&utm_campaign=ebook

CREATE EVENT SESSION [Backup progress] ON SERVER 
ADD EVENT [sqlserver].[backup_restore_progress_trace](
ACTION([package0].[event_sequence])  
    
   -- to only capture backup operations:     
   --WHERE [operation_type] = 0      

   -- to only capture restore operations:    
   --WHERE [operation_type] = 1  

) ADD TARGET [package0].[event_file] (
    SET filename = N'C:\temp\BackupProgress.xel'
); -- default options are probably ok 
GO

ALTER EVENT SESSION [Backup progress] ON SERVER STATE = START;
GO 

--
---Run Backups/restores
--

--Stop the Session
ALTER EVENT SESSION [Backup progress] ON SERVER STATE = STOP;


---Analyze the output

;WITH x AS 
(
  SELECT ts,op,db,msg,es
  FROM 
  (
   SELECT 
    ts  = x.value(N'(event/@timestamp)[1]', N'datetime2'),
    op  = x.value(N'(event/data[@name="operation_type"]/text)[1]', N'nvarchar(32)'),
    db  = x.value(N'(event/data[@name="database_name"])[1]', N'nvarchar(128)'),
    msg = x.value(N'(event/data[@name="trace_message"])[1]', N'nvarchar(max)'),
    es  = x.value(N'(event/action[@name="event_sequence"])[1]', N'int')
   FROM 
   (
    SELECT x = CONVERT(XML, event_data) 
     FROM sys.fn_xe_file_target_read_file
          (N'c:\temp\Backup--Progress*.xel', NULL, NULL, NULL)
   ) AS y
  ) AS x 
  WHERE op = N'Backup' -- N'Restore'
  AND db = N'floob'
  AND ts > CONVERT(DATE, SYSUTCDATETIME())
)
SELECT /* x.db, x.op, x.ts, */ 
  [Message] = x.msg, 
  Duration = COALESCE(DATEDIFF(MILLISECOND, x.ts, 
             LEAD(x.ts, 1) OVER(ORDER BY es)),0)
FROM x
ORDER BY es;


