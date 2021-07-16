CREATE TABLE #VLFInfo (RecoveryUnitID int, FileID  int,
					   FileSize bigint, StartOffset bigint,
					   FSeqNo      bigint, [Status]    bigint,
					   Parity      bigint, CreateLSN   numeric(38));
	 
CREATE TABLE #VLFCountResults(DatabaseName sysname, VLFCount int);
	 
EXEC sp_MSforeachdb N'Use [?]; 

				INSERT INTO #VLFInfo 
				EXEC sp_executesql N''DBCC LOGINFO([?])''; 
	 
				INSERT INTO #VLFCountResults 
				SELECT DB_NAME(), COUNT(*) 
				FROM #VLFInfo; 

				TRUNCATE TABLE #VLFInfo;'
	 
--SELECT DatabaseName, VLFCount  
--FROM #VLFCountResults
--ORDER BY VLFCount DESC;
	 
DROP TABLE #VLFInfo;

DECLARE @DBNAme sysname;
DECLARE @SQL nvarchar(max);
DECLARE VLF_CUR CURSOR  
    FOR SELECT DatabaseName FROM #VLFCountResults WHERE VLFCount > 500

OPEN VLF_CUR ;
FETCH NEXT FROM VLF_CUR into @DBName;  

WHILE @@FETCH_STATUS = 0  
BEGIN  

SET @SQL = N'
	USE §§§;

	DECLARE @file_name sysname,
	@file_size int,
	@file_growth int,
	@shrink_command nvarchar(max),
	@alter_command nvarchar(max)

	SELECT @file_name = name,
	@file_size = (size / 128)
	FROM sys.database_files
	WHERE type_desc = ''log''

	SELECT @shrink_command = ''DBCC SHRINKFILE (N'''''' + @file_name + '''''' , 0, TRUNCATEONLY)''
	PRINT @shrink_command
	EXEC sp_executesql @shrink_command

	SELECT @shrink_command = ''DBCC SHRINKFILE (N'''''' + @file_name + '''''' , 0)''
	PRINT @shrink_command
	EXEC sp_executesql @shrink_command

	SELECT @alter_command = ''ALTER DATABASE ['' + db_name() + ''] MODIFY FILE (NAME = N'''''' + @file_name + '''''', SIZE = '' + CAST(@file_size AS nvarchar) + ''MB)''
	PRINT @alter_command
	EXEC sp_executesql @alter_command
	'

	SELECT @SQL = REPLACE(@SQL,N'§§§',@DBNAme);

	PRINT @SQL
	--EXEC sp_executeSQL @SQL;

	FETCH NEXT FROM VLF_CUR into @DBName;  
END

CLOSE VLF_CUR;
DEALLOCATE VLF_CUR;

DROP TABLE #VLFCountResults;