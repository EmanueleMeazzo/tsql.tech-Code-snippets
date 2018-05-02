--TempDB Page contention script

--If you see a lot of lines of output where the wait_type is PAGELATCH_UP or PAGELATCH_EX, and the resource_description is 2:1:1 then that’s the PFS page (database ID 2 – tempdb, file ID 1, page ID 1), and if you see 2:1:3 then that’s another allocation page called an SGAM.

--A sample resource description may look like 2:3:18070499. We want to focus on the page ID of 18070499. The formula for determining the page type is as follows: GAM: (Page ID – 2) % 511232 SGAM: (Page ID – 3) % 511232 PFS: (Page ID – 1) % 8088 If one of these formulas equates to 0, then the contention is on the allocation pages.

--There are three things you can do to alleviate this kind of contention and increase the throughput of the overall workload:

--Stop using temp tables
--Enable trace flag 1118 as a start-up trace flag
--Create multiple tempdb data files

--Figure out the number of logical processor cores you have (e.g. two CPUS, with 4 physical cores each, plus hyperthreading enabled = 2 (cpus) x 4 (cores) x 2 (hyperthreading) = 16 logical cores. Then if you have less than 8 logical cores, create the same number of data files as logical cores. If you have more than 8 logical cores, create 8 data files and then add more in chunks of 4 if you still see PFS contention. Make sure all the tempdb data files are the same size too. (This advice is now official Microsoft guidance in KB article 2154845.)

SELECT
    [owt].[session_id],
    [owt].[exec_context_id],
    [owt].[wait_duration_ms],
    [owt].[wait_type],
    [owt].[blocking_session_id],
    [owt].[resource_description],
    CASE [owt].[wait_type]
        WHEN N'CXPACKET' THEN
            RIGHT ([owt].[resource_description],
            CHARINDEX (N'=', REVERSE ([owt].[resource_description])) - 1)
        ELSE NULL
    END AS [Node ID],
    [es].[program_name],
    [est].[text],
    [er].[database_id],
    [eqp].[query_plan],
    [er].[cpu_time]
FROM sys.dm_os_waiting_tasks [owt]
INNER JOIN sys.dm_exec_sessions [es] ON
    [owt].[session_id] = [es].[session_id]
INNER JOIN sys.dm_exec_requests [er] ON
    [es].[session_id] = [er].[session_id]
OUTER APPLY sys.dm_exec_sql_text ([er].[sql_handle]) [est]
OUTER APPLY sys.dm_exec_query_plan ([er].[plan_handle]) [eqp]
WHERE
    [es].[is_user_process] = 1
ORDER BY
    [owt].[session_id],
    [owt].[exec_context_id];
GO