DECLARE C CURSOR LOCAL FAST_FORWARD
FOR SELECT
	OBJECT_NAME(object_id)
FROM sys.dm_db_index_physical_stats(
     DB_ID('Urban_PLANNING_AppDB')
    ,NULL
    ,NULL
    ,NULL
    ,'DETAILED')
WHERE index_id = 0
AND avg_fragmentation_in_percent > 20;

OPEN C
DECLARE @TableName nvarchar(256)
DECLARE @SQL nvarchar(max)

FETCH NEXT FROM C INTO @TableName

WHILE @@FETCH_STATUS = 0
BEGIN

SET @SQL = N'ALTER TABLE ' + QUOTENAME(@TableName) + N' REBUILD'

PRINT @SQL
EXEC sp_executesql @SQL

FETCH NEXT FROM C INTO @TableName

END 

CLOSE C
DEALLOCATE C