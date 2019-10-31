--All versions of SQL
CREATE TABLE #VLFInfo (FileID  int,
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
SELECT DatabaseName, VLFCount  
FROM #VLFCountResults
ORDER BY VLFCount DESC;
DROP TABLE #VLFInfo;
DROP TABLE #VLFCountResults;


--Only works on SQL 2017	
SELECT
		name AS 'Database Name',
		COUNT(l.database_id) AS 'VLF Count',
		SUM(vlf_size_mb) AS 'VLF Size (MB)',
		SUM(CAST(vlf_active AS INT)) AS 'Active VLF',
		SUM(vlf_active*vlf_size_mb) AS 'Active VLF Size (MB)',
		COUNT(l.database_id)-SUM(CAST(vlf_active AS INT)) AS 'In-active VLF',
		SUM(vlf_size_mb)-SUM(vlf_active*vlf_size_mb) AS 'In-active VLF Size (MB)'
	FROM
		sys.databases s
		CROSS APPLY sys.dm_db_log_info(s.database_id) l
	GROUP BY
		[name], s.database_id
	ORDER BY
		'VLF Count' DESC;
