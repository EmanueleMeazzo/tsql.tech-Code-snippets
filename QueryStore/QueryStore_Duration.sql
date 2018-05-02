SELECT TOP 10 
    qt.query_sql_text,
    CONVERT(XML,query_plan) as 'Execution Plan',
    rs.avg_duration,
    rs.count_executions,
    rs.avg_dop,
    rs.last_dop
FROM sys.query_store_plan qp
JOIN sys.query_store_query q
    ON qp.query_id = q.query_id
JOIN sys.query_store_query_text qt
    ON q.query_text_id = qt.query_text_id
JOIN sys.query_store_runtime_stats rs
    on qp.plan_id = rs.plan_id
ORDER BY rs.avg_duration DESC