/*============================================================================
  File:     ShortPeriodIOLatencies.sql
 
  Summary:  Short snapshot of I/O latencies
 
  SQL Server Versions: 2005 onwards
------------------------------------------------------------------------------
  Written by Paul S. Randal, SQLskills.com
 
  (c) 2014, SQLskills.com. All rights reserved.
 
  For more scripts and sample code, check out http://www.SQLskills.com
 
  You may alter this code for your own *non-commercial* purposes (e.g. in a
  for-sale commercial tool). Use in your own environment is encouraged.
  You may republish altered code as long as you include this copyright and
  give due credit, but you must obtain prior permission before blogging
  this code.
 
  THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF
  ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED
  TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
  PARTICULAR PURPOSE.
============================================================================*/
  
 
IF EXISTS (SELECT * FROM [tempdb].[sys].[objects]
    WHERE [name] = N'##SQLskillsStats1')
    DROP TABLE [##SQLskillsStats1];
 
IF EXISTS (SELECT * FROM [tempdb].[sys].[objects]
    WHERE [name] = N'##SQLskillsStats2')
    DROP TABLE [##SQLskillsStats2];
GO
 
SELECT [database_id], [file_id], [num_of_reads], [io_stall_read_ms],
       [num_of_writes], [io_stall_write_ms], [io_stall],
       [num_of_bytes_read], [num_of_bytes_written], [file_handle]
INTO ##SQLskillsStats1
FROM sys.dm_io_virtual_file_stats (NULL, NULL);
GO
 
WAITFOR DELAY '00:30:00';
GO
 
SELECT [database_id], [file_id], [num_of_reads], [io_stall_read_ms],
       [num_of_writes], [io_stall_write_ms], [io_stall],
       [num_of_bytes_read], [num_of_bytes_written], [file_handle]
INTO ##SQLskillsStats2
FROM sys.dm_io_virtual_file_stats (NULL, NULL);
GO
 
WITH [DiffLatencies] AS
(SELECT
-- Files that weren't in the first snapshot
        [ts2].[database_id],
        [ts2].[file_id],
        [ts2].[num_of_reads],
        [ts2].[io_stall_read_ms],
        [ts2].[num_of_writes],
        [ts2].[io_stall_write_ms],
        [ts2].[io_stall],
        [ts2].[num_of_bytes_read],
        [ts2].[num_of_bytes_written]
    FROM [##SQLskillsStats2] AS [ts2]
    LEFT OUTER JOIN [##SQLskillsStats1] AS [ts1]
        ON [ts2].[file_handle] = [ts1].[file_handle]
    WHERE [ts1].[file_handle] IS NULL
UNION
SELECT
-- Diff of latencies in both snapshots
        [ts2].[database_id],
        [ts2].[file_id],
        [ts2].[num_of_reads] - [ts1].[num_of_reads] AS [num_of_reads],
        [ts2].[io_stall_read_ms] - [ts1].[io_stall_read_ms] AS [io_stall_read_ms],
        [ts2].[num_of_writes] - [ts1].[num_of_writes] AS [num_of_writes],
        [ts2].[io_stall_write_ms] - [ts1].[io_stall_write_ms] AS [io_stall_write_ms],
        [ts2].[io_stall] - [ts1].[io_stall] AS [io_stall],
        [ts2].[num_of_bytes_read] - [ts1].[num_of_bytes_read] AS [num_of_bytes_read],
        [ts2].[num_of_bytes_written] - [ts1].[num_of_bytes_written] AS [num_of_bytes_written]
    FROM [##SQLskillsStats2] AS [ts2]
    LEFT OUTER JOIN [##SQLskillsStats1] AS [ts1]
        ON [ts2].[file_handle] = [ts1].[file_handle]
    WHERE [ts1].[file_handle] IS NOT NULL)
SELECT
    DB_NAME ([vfs].[database_id]) AS [DB],
    LEFT ([mf].[physical_name], 2) AS [Drive],
    [mf].[type_desc],
    [num_of_reads] AS [Reads],
    [num_of_writes] AS [Writes],
    [ReadLatency(ms)] =
        CASE WHEN [num_of_reads] = 0
            THEN 0 ELSE ([io_stall_read_ms] / [num_of_reads]) END,
    [WriteLatency(ms)] =
        CASE WHEN [num_of_writes] = 0
            THEN 0 ELSE ([io_stall_write_ms] / [num_of_writes]) END,
    -- [Latency] =
        -- CASE WHEN ([num_of_reads] = 0 AND [num_of_writes] = 0)
            -- THEN 0 ELSE ([io_stall] / ([num_of_reads] + [num_of_writes])) END,
    [AvgBPerRead] =
        CASE WHEN [num_of_reads] = 0
            THEN 0 ELSE ([num_of_bytes_read] / [num_of_reads]) END,
    [AvgBPerWrite] =
        CASE WHEN [num_of_writes] = 0
            THEN 0 ELSE ([num_of_bytes_written] / [num_of_writes]) END,
    -- [AvgBPerTransfer] =
        -- CASE WHEN ([num_of_reads] = 0 AND [num_of_writes] = 0)
            -- THEN 0 ELSE
                -- (([num_of_bytes_read] + [num_of_bytes_written]) /
                -- ([num_of_reads] + [num_of_writes])) END,
    [mf].[physical_name],
    [num_of_bytes_written]/1048576 as num_of_mb_written,
    [num_of_bytes_read]/1048576 as num_of_mb_read,
    ([num_of_bytes_written]/1048576)/300 as mb_per_sec_written,
    ([num_of_bytes_read]/1048576)/300 as mb_per_sec_read
FROM [DiffLatencies] AS [vfs]
JOIN sys.master_files AS [mf]
    ON [vfs].[database_id] = [mf].[database_id]
    AND [vfs].[file_id] = [mf].[file_id]
-- ORDER BY [ReadLatency(ms)] DESC
ORDER BY [WriteLatency(ms)] DESC;
GO
 
-- Cleanup
IF EXISTS (SELECT * FROM [tempdb].[sys].[objects]
    WHERE [name] = N'##SQLskillsStats1')
    DROP TABLE [##SQLskillsStats1];
 
IF EXISTS (SELECT * FROM [tempdb].[sys].[objects]
    WHERE [name] = N'##SQLskillsStats2')
    DROP TABLE [##SQLskillsStats2];
GO