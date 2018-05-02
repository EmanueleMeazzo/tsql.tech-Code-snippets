DECLARE @SQL nvarchar(max) = '';
DECLARE @OldSchema varchar(50) = 'dbo';
DECLARE @NewSchema varchar(50) = 'Analysis';

SELECT @SQL = @SQL + N'ALTER SCHEMA ' + QUOTENAME(@NewSchema) + CHAR(10) 
                   + N'TRANSFER ' + QUOTENAME(@OldSchema) + N'.' + QUOTENAME(name) + CHAR(10) + CHAR(13)
FROM sys.objects
WHERE schema_id = SCHEMA_ID(@OldSchema)
AND [type] IN ('U','V')

PRINT @SQL

exec sp_executesql @SQL