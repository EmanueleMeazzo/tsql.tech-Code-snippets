--Reads the active transaction log looking for user actions

WITH UserTransactions
     AS (
     SELECT
            [USR].[name],
            LOG.[Transaction ID],
            [Transaction Name],
            [Begin Time],
            [End Time],
            [Current LSN]
     FROM   [sys].[fn_dblog](NULL, NULL) LOG
            JOIN [sysusers] [USR] ON [USR].[sid] = LOG.[Transaction SID])
     SELECT
            [UT].[name] AS [UserName],
            [SCH].[name] AS [SchemaName],
            [OBJ].[name] AS [Objectname],
            LOG.[Transaction ID],
            [UT].[Transaction Name],
            COALESCE(LOG.[Begin Time], LOG.[End Time]) AS Time,
            LOG.[Operation],
            LOG.[Context],
            LOG.[Current LSN],
            [DECODE].[Current LSN(Decoded)],
            [Lock Information]
     FROM      [UserTransactions] [UT]
               JOIN [sys].[fn_dblog](NULL, NULL) LOG ON LOG.[Transaction ID] = [UT].[Transaction ID]
               LEFT JOIN [sys].[partitions] [PART] ON [PART].[partition_id] = LOG.[PartitionId]
               LEFT JOIN [sys].[objects] [OBJ] ON [OBJ].object_id = [PART].object_id
               LEFT JOIN [sys].[schemas] [SCH] ON [SCH].schema_id = [OBJ].schema_id
               OUTER APPLY
(
    SELECT
           CAST(CAST(CONVERT(VARBINARY, '0x'+RIGHT(REPLICATE('0', 8)+LEFT([U].[Current LSN], 8), 8), 1) AS INT) AS VARCHAR(8))+CAST(RIGHT(REPLICATE('0', 10)+CAST(CAST(CONVERT(VARBINARY, '0x'+RIGHT(REPLICATE('0', 8)+SUBSTRING([U].[Current LSN], 10, 8), 8), 1) AS INT) AS VARCHAR(10)), 10) AS VARCHAR(10))+CAST(RIGHT(REPLICATE('0', 5)+CAST(CAST(CONVERT(VARBINARY, '0x'+RIGHT(REPLICATE('0', 8)+RIGHT([U].[Current LSN], 4), 8), 1) AS INT) AS VARCHAR(5)), 5) AS VARCHAR(5)) AS [Current LSN(Decoded)]
    FROM   [UserTransactions] [U]
    WHERE  [U].[Current LSN] = [UT].[Current LSN]
) AS [DECODE]
     WHERE [SCH].[name] IS NOT NULL  --Comment this predicate to show statements related to dropped objects
           AND [SCH].[name] <> 'sys' --Comment this predicate to show statements that write to system tables (e.g CREATE TABLE)
     ORDER BY
              LOG.[Current LSN] DESC;
