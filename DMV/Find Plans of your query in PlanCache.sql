SELECT 
  eqs.execution_count,
  CAST((1.)*eqs.total_worker_time/eqs.execution_count AS NUMERIC(10,1)) AS avg_worker_time,
  eqs.last_worker_time,
  CAST((1.)*eqs.total_logical_reads/eqs.execution_count AS NUMERIC(10,1)) AS avg_logical_reads,
  eqs.last_logical_reads,
    (SELECT TOP 1 SUBSTRING(est.text,statement_start_offset / 2+1 , 
    ((CASE WHEN statement_end_offset = -1 
      THEN (LEN(CONVERT(nvarchar(max),est.text)) * 2) 
      ELSE statement_end_offset END)  
      - statement_start_offset) / 2+1))  
    AS sql_statement,
  qp.query_plan
FROM sys.dm_exec_query_stats AS eqs
CROSS APPLY sys.dm_exec_sql_text (eqs.sql_handle) AS est 
JOIN sys.dm_exec_cached_plans cp on 
  eqs.plan_handle=cp.plan_handle
CROSS APPLY sys.dm_exec_query_plan (cp.plan_handle) AS qp
WHERE est.text like '%YOUR TEXT%'
OPTION (RECOMPILE);
GO