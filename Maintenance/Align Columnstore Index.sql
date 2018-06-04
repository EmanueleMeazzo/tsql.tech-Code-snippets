CREATE OR ALTER PROCEDURE [AlignColumnstore] @SchemaName    SYSNAME = 'dbo',
                                             @TableName     SYSNAME ,
                                             @AlignToColumn SYSNAME ,
                                             @IndexToAlign  SYSNAME = '%',
                                             @PrintOnly     BIT     = 1
AS;
BEGIN

--A Stored procedure to Automatically Align a Columstore index to a specific Column
--The ideal case is for tables with Clustered Columnstore tables that need to be aligned 
--to a specific column to maximize Segment elimination
--URL: http://tsql.tech/a-script-to-automatically-align-columnstore-indexes-to-enhance-segment-elimination-and-hence-performances/
--Author: Emanuele Meazzo
--License: MIT AKA do whatever you want

---
DECLARE @ObjectID int
DECLARE @Error varchar(512)

SELECT
       @ObjectID = [T].object_id
FROM   [sys].[tables] [T]
       JOIN [sys].[columns] [C] ON [C].object_id = [T].object_id
WHERE  [T].schema_id = SCHEMA_ID(@SchemaName)
       AND [T].[name] = @TableName
       AND [C].[name] = @AlignToColumn;

IF @ObjectID IS NULL
BEGIN
    RAISERROR ('Table or Column not found or you don''t have enough permissions',18,1);  
    RETURN
END

DECLARE @index_id int,
@index_name sysname,
@index_columns varchar(MAX),
@index_unique bit,
@CC_index_id int,
@CC_index_name sysname,
@CC_index_columns varchar(MAX),
@CC_index_type tinyint


SELECT
       @CC_index_id      = [I].[index_id],
       @CC_index_name    = [I].[name],
       @CC_index_columns = [COL].[Columns],
       @CC_index_type    = [I].[type]
FROM      [sys].[indexes] [I]
CROSS APPLY
(
    SELECT
           QUOTENAME([C].[name])+','
    FROM   [sys].[index_columns] [IC]
           JOIN [sys].[columns] [C] ON [C].object_id = [IC].object_id
                                       AND [IC].[column_id] = [C].[column_id]
    WHERE  [IC].object_id = [I].object_id FOR
    XML PATH('')
) [COL]([Columns])
WHERE [name] LIKE @IndexToAlign
      AND [Type] IN(5, 6) --Columnstore Indexes
      AND object_id = @ObjectID;

IF (@CC_index_id IS NULL)
BEGIN
    SET @Error = 'Index ' + @IndexToAlign + 'doesn''t exist or isn''t a Columnstore Index'
    RAISERROR (@Error,18,1);  
    RETURN
END

SELECT
       @index_id      = [I].[index_id],
       @index_name    = [I].[name],
       @index_columns = [COL].[Columns],
       @index_unique  = [I].is_unique
FROM      [sys].[indexes] [I]
          CROSS APPLY
(
    SELECT
           QUOTENAME([C].[name])+','
    FROM   [sys].[index_columns] [IC]
           JOIN [sys].[columns] [C] ON [C].object_id = [IC].object_id
                                       AND [IC].[column_id] = [C].[column_id]
    WHERE  [IC].object_id = [I].object_id
           AND [IC].[key_ordinal] <> 0
           AND [IC].[index_id] = [I].[index_id] FOR
    XML PATH('')
) [COL]([Columns])
WHERE [I].object_id = @ObjectID
      AND [Type] = 1; --Existing Clustered Index

DECLARE @SQL nvarchar(max) 
SET @index_columns = LEFT(@index_columns,LEN(@index_columns)-1)
SET @CC_index_columns = LEFT(@CC_index_columns,LEN(@CC_index_columns)-1)

IF (@index_id IS NULL) --No existing Clustered Index
BEGIN
    
    SET @SQL = N'DROP INDEX ' + QUOTENAME(@CC_index_name) + ' ON ' + QUOTENAME(@TableName) + CHAR(10) + CHAR(13)

    SET @SQL += N'CREATE CLUSTERED INDEX ' + QUOTENAME(@CC_index_name) + ' ON ' + QUOTENAME(@TableName) + ' (' + QUOTENAME(@AlignToColumn) + ');' + CHAR(10) + CHAR(13)

    --EXEC sp_executesql @SQL

    IF (@CC_index_type = 5)
    BEGIN
        SET @SQL+= N'CREATE CLUSTERED COLUMNSTORE INDEX ' + QUOTENAME(@CC_index_name) + ' ON ' + QUOTENAME(@TableName) + N'WITH (DROP_EXISTING = ON, MAXDOP = 1)' + CHAR(10) + CHAR(13)

        --EXEC sp_executesql @SQL

    END
    ELSE
    BEGIN

        SET @SQL+= N'CREATE NONCLUSTERED COLUMNSTORE INDEX ' + QUOTENAME(@CC_index_name) +  ' ON ' + QUOTENAME(@TableName) + ' (' + @CC_index_columns + ') WITH (DROP_EXISTING = ON, MAXDOP = 1);' + CHAR(10) + CHAR(13)

    END
END
ELSE --Existing Clustered Index
BEGIN

        SET @Error = 'Trying to Align a Columnstore Index on a table that already has a Clustered Rowstore Index, this makes no sense as the rows will still be aligned as the existing Clustered Index, what are you trying to accomplish?'
        RAISERROR (@Error,18,1);  
        RETURN
END

IF(@PrintOnly = 1)
BEGIN

    PRINT @SQL

END
ELSE
BEGIN
    
    PRINT @SQL
    EXEC sp_executesql @SQL

END
END