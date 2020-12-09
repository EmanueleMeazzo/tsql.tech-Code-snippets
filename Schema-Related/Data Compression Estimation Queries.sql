
    -- SQL Server Data Compression Estimation Queries
    -- This may take some time to run, depending on your hardware, storage performance and table size
    -- Glenn Berry 
    -- https://glennsqlperformance.com/
    -- YouTube: https://www.youtube.com/c/GlennBerrySQL
    -- Twitter: GlennAlanBerry

	-- Data compression types
	-- Prior to SQL Server 2019: PAGE, ROW, or NONE
	-- SQL Server 2019: COLUMNSTORE and COLUMNSTORE_ARCHIVE
 
    -- Get estimated data compression savings and other index info for every index in the specified table
    SET NOCOUNT ON;
    DECLARE @SchemaName sysname = N'dbo';                    -- Specify schema name
    DECLARE @TableName sysname = N'YourTableName';           -- Specify table name
    DECLARE @FullName sysname = @SchemaName + N'.' + @TableName;
    DECLARE @IndexID int = 1;
    DECLARE @CompressionType nvarchar(60) = N'PAGE'; -- Specify desired data compression type (PAGE, ROW, or NONE)
    SET @FullName = @SchemaName + N'.' + @TableName;
 
    -- Get Table name, row count, and compression status for clustered index or heap table
    SELECT OBJECT_NAME(object_id) AS [Object Name], 
    SUM(Rows) AS [RowCount], data_compression_desc AS [Compression Type]
    FROM sys.partitions WITH (NOLOCK)
    WHERE index_id < 2
    AND OBJECT_NAME(object_id) = @TableName
    GROUP BY object_id, data_compression_desc
    ORDER BY SUM(Rows) DESC OPTION (RECOMPILE);

    -- Breaks down buffers used by current table in this database by object (table, index) in the buffer pool
    -- Shows you which indexes are taking the most space in the buffer cache, 
	-- so they might be possible candidates for data compression
    SELECT OBJECT_NAME(p.[object_id]) AS [Object Name],
    p.index_id, COUNT(*)/128 AS [Buffer size(MB)],  COUNT(*) AS [Buffer Count], 
    p.data_compression_desc AS [Compression Type]
    FROM sys.allocation_units AS a WITH (NOLOCK)
    INNER JOIN sys.dm_os_buffer_descriptors AS b WITH (NOLOCK)
    ON a.allocation_unit_id = b.allocation_unit_id
    INNER JOIN sys.partitions AS p WITH (NOLOCK)
    ON a.container_id = p.hobt_id
    WHERE b.database_id = DB_ID()
    AND OBJECT_NAME(p.[object_id]) = @TableName
    AND p.[object_id] > 100
    GROUP BY p.[object_id], p.index_id, p.data_compression_desc
    ORDER BY [Buffer Count] DESC OPTION (RECOMPILE);

    -- Get the current and estimated size for every index in specified table
    DECLARE curIndexID CURSOR FAST_FORWARD
    FOR
        -- Get list of index IDs for this table
        SELECT i.index_id
        FROM sys.indexes AS i WITH (NOLOCK)
        INNER JOIN sys.tables AS t WITH (NOLOCK)
        ON i.[object_id] = t.[object_id]
        WHERE t.type_desc = N'USER_TABLE'
        AND OBJECT_NAME(t.[object_id]) = @TableName
        ORDER BY i.index_id OPTION (RECOMPILE);
 
    OPEN curIndexID;
 
    FETCH NEXT FROM curIndexID INTO @IndexID;

    -- Loop through every index in the table and run sp_estimate_data_compression_savings
    WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Get current and estimated size for specified index with specified compression type
            EXEC dbo.sp_estimate_data_compression_savings @SchemaName, @TableName, @IndexID, NULL, @CompressionType;

            FETCH NEXT
            FROM curIndexID
            INTO @IndexID;
        END
    CLOSE curIndexID;
    DEALLOCATE curIndexID;

    -- Index Read/Write stats for this table
    SELECT SCHEMA_NAME(t.[schema_id]) AS [SchemaName], 
	OBJECT_NAME(s.[object_id]) AS [TableName],
    i.name AS [IndexName], i.index_id,
    SUM(user_seeks) AS [User Seeks], SUM(user_scans) AS [User Scans],
    SUM(user_lookups)AS [User Lookups],
    SUM(user_seeks + user_scans + user_lookups)AS [Total Reads],
    SUM(user_updates) AS [Total Writes]     
    FROM sys.dm_db_index_usage_stats AS s WITH (NOLOCK)
    INNER JOIN sys.indexes AS i WITH (NOLOCK)
    ON s.[object_id] = i.[object_id]
    AND i.index_id = s.index_id
	LEFT OUTER JOIN sys.tables AS t WITH (NOLOCK)
	ON t.[object_id] = i.[object_id]
    WHERE OBJECTPROPERTY(s.[object_id],'IsUserTable') = 1
    AND s.database_id = DB_ID()
    AND OBJECT_NAME(s.[object_id]) = @TableName
    GROUP BY SCHEMA_NAME(t.[schema_id]), OBJECT_NAME(s.[object_id]), i.[name], i.index_id
    ORDER BY [Total Writes] DESC, [Total Reads] DESC OPTION (RECOMPILE);

    -- Get basic index information (does not include filtered indexes or included columns)
    EXEC sp_helpindex @FullName;

    -- Individual File Sizes and space available for current database  
    SELECT f.[name] AS [File Name] , f.physical_name AS [Physical Name],
    CAST((f.size/128.0) AS decimal(15,2)) AS [Total Size in MB],
	CAST((f.size/128.0) AS DECIMAL(15,2)) -
	CAST(f.size/128.0 - CAST(FILEPROPERTY(f.name, 'SpaceUsed') AS int)/128.0 AS DECIMAL(15,2)) 
	AS [Used Space in MB],
	CAST(f.size/128.0 - CAST(FILEPROPERTY(f.name, 'SpaceUsed') AS int)/128.0 AS decimal(15,2))
    AS [Available Space In MB],
	f.[file_id], fg.[name] AS [Filegroup Name], fg.is_default
    FROM sys.database_files AS f WITH (NOLOCK)
	LEFT OUTER JOIN sys.filegroups AS fg WITH (NOLOCK)
	ON f.data_space_id = fg.data_space_id 
	ORDER BY f.[type], f.[file_id] OPTION (RECOMPILE);

