DECLARE C CURSOR LOCAL FAST_FORWARD
FOR SELECT obj.name as TableName, schem.name as SchemaName
FROM sys.dm_db_index_physical_stats(
     DB_ID()
    ,NULL
    ,NULL
    ,NULL
    ,'DETAILED') stats
JOIN sys.objects obj ON obj.object_id = stats.object_id
JOIN sys.schemas schem on schem.schema_id = obj.schema_id
WHERE stats.index_id = 0
AND avg_fragmentation_in_percent > 20;

OPEN C
DECLARE @TableName sysname, @SchemaName sysname
DECLARE @SQL nvarchar(max)

FETCH NEXT FROM C INTO @TableName, @SchemaName

WHILE @@FETCH_STATUS = 0
BEGIN

SET @SQL = N'ALTER TABLE ' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + N' REBUILD'

PRINT @SQL
EXEC sp_executesql @SQL

FETCH NEXT FROM C INTO @TableName, @SchemaName

END 

CLOSE C
DEALLOCATE C
