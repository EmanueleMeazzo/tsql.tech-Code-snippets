
SELECT TOP(25) OBJECT_NAME(objectid) AS [ObjectName], 
               cp.objtype, cp.usecounts, cp.size_in_bytes, query_plan
FROM sys.dm_exec_cached_plans AS cp WITH (NOLOCK)
CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) AS qp
WHERE CAST(query_plan AS NVARCHAR(MAX)) LIKE N'%CONVERT_IMPLICIT%'
AND dbid = DB_ID()
ORDER BY cp.usecounts DESC OPTION (RECOMPILE);


---------------

--PINAL VERSION

SELECT TOP 50 
DB_NAME(T.dbid) AS [DB Name],
t.text AS [QUERY TEXT],
qs.total_worker_time [Total Worker Time],
qs.total_worker_time/qs.execution_count [Avg Worker Time],
QS.max_elapsed_time AS [Max Elapsed Time],
QS.max_logical_reads AS [Max Logical Reads],
QS.execution_count AS [Execution Count],
QP.query_plan AS [Query Plan]
FROM sys.dm_exec_query_stats QS WITH (NOLOCK)
CROSS APPLY sys.dm_exec_sql_text(plan_handle) T
CROSS APPLY sys.dm_exec_query_plan(plan_handle) QP
WHERE CAST(query_plan AS NVARCHAR(MAX)) LIKE N'%CONVERT_IMPLICIT%'
	AND t.dbid = DB_ID()
ORDER BY QS.total_worker_time DESC OPTION (RECOMPILE)