/*

Emanuele Meazzo - 2024
MIT License or whatever, I can't stop you

Quick and Dirty script to check wich data types are possibily compatibile with the data in your table in order to optimize id

Use case: you've dumped everything into a table via an ETL tool which has created all NVARCHAR(MAX) columns for your data
With this script you go in and actually check the contents of the table to assign a decent data type to each column

*/

SET NOCOUNT ON;

DECLARE @table_name SYSNAME = 'yourtable';
DECLARE @schema_name SYSNAME = 'dbo';

DROP TABLE IF EXISTS #COLS;

SELECT t.object_id, c.column_id, c.name AS column_name, tp.name AS typ_name, c.max_length, c.precision, c.scale
INTO #COLS
FROM sys.columns c
JOIN sys.tables t ON c.object_id = t.object_id
JOIN sys.schemas s ON t.schema_id = s.schema_id
JOIN sys.types tp ON c.system_type_id = tp.system_type_id AND c.user_type_id = tp.user_type_id
WHERE s.name = @schema_name
AND T.name = @table_name;

DECLARE	@object_id INT;
DECLARE @column_id INT;
DECLARE @column_name NVARCHAR(1000);
DECLARE @type_name NVARCHAR(1000);
DECLARE @max_length SMALLINT;
DECLARE @precision SMALLINT;
DECLARE @scale SMALLINT;
DECLARE @SQL NVARCHAR(MAX), @BASE_SQL NVARCHAR(MAX);
DECLARE @compatible BIT;
        
DECLARE cur CURSOR FAST_FORWARD READ_ONLY LOCAL FOR
    SELECT c.object_id
		  ,c.column_id
		  ,c.column_name
		  ,c.typ_name
		  ,c.max_length
		  ,c.precision
		  ,c.scale
    FROM #COLS c;

DROP TABLE IF EXISTS #RESULTS;

CREATE TABLE #RESULTS 
(
	COLUMN_NAME SYSNAME NOT NULL,
	TYPE SYSNAME NOT NULL,
	COMPABITLE BIT NOT NULL,
	MAX_LEN SMALLINT, 
	MIN_LEN SMALLINT,
	SAMPLE NVARCHAR(MAX)
);
        
OPEN cur
        
FETCH NEXT FROM cur INTO @object_id, @column_id, @column_name, @type_name, @max_length, @precision, @scale
        
WHILE @@FETCH_STATUS = 0 BEGIN
        
			SELECT @BASE_SQL =
			'SELECT ''' + @column_name + ''' AS COLUMN_NAME, ''###'' AS DATA_TYPE, IIF(X.TESTING = y.BASELINE, 1, 0) AS COMPATIBLE, y.MAX_LEN, y.MIN_LEN, SAMPLE
			FROM (SELECT COUNT(*) TESTING FROM ' + QUOTENAME(@schema_name) + N'.' + QUOTENAME(@table_name) + N' WHERE TRY_CONVERT(###,' + QUOTENAME(@column_name) + N') IS NOT NULL) X
			CROSS APPLY (SELECT COUNT(*) BASELINE, MAX(LEN(' + QUOTENAME(@column_name) + N')) MAX_LEN, MIN(LEN(' + QUOTENAME(@column_name) + N')) MIN_LEN 
			FROM ' + QUOTENAME(@schema_name) + N'.' + QUOTENAME(@table_name) + N' WHERE ' + QUOTENAME(@column_name) + N' IS NOT NULL) y
			CROSS APPLY (SELECT STRING_AGG(SAMPLED,'','') SAMPLE FROM (SELECT TOP 5 ' + QUOTENAME(@column_name) + N' AS SAMPLED FROM ' + QUOTENAME(@schema_name) + N'.' + QUOTENAME(@table_name) + N') k) s'

			--Types to check
			--INT
			SELECT @SQL = REPLACE(@BASE_SQL,'###','INT')
			INSERT INTO #RESULTS
			EXEC @compatible = sys.sp_executesql @SQL;

			--FLOAT
			SELECT @SQL = REPLACE(@BASE_SQL,'###','FLOAT')
			INSERT INTO #RESULTS
			EXEC @compatible = sys.sp_executesql @SQL;

			--NUMERIC
			SELECT @SQL = REPLACE(@BASE_SQL,'###','NUMERIC(18,2)')
			INSERT INTO #RESULTS
			EXEC @compatible = sys.sp_executesql @SQL;

			--VARCHAR
			SELECT @SQL = REPLACE(@BASE_SQL,'###','VARCHAR(8000)')
			INSERT INTO #RESULTS
			EXEC @compatible = sys.sp_executesql @SQL;

			--BIT
			SELECT @SQL = REPLACE(@BASE_SQL,'###','BIT')
			INSERT INTO #RESULTS
			EXEC @compatible = sys.sp_executesql @SQL;

			--DATE
			SELECT @SQL = REPLACE(@BASE_SQL,'###','DATE')
			INSERT INTO #RESULTS
			EXEC @compatible = sys.sp_executesql @SQL;

			--DATETIME
			SELECT @SQL = REPLACE(@BASE_SQL,'###','DATETIME')
			INSERT INTO #RESULTS
			EXEC @compatible = sys.sp_executesql @SQL;
        
    FETCH NEXT FROM cur INTO @object_id, @column_id, @column_name, @type_name, @max_length, @precision, @scale
        
END
        
CLOSE cur
DEALLOCATE cur

SELECT
	c.COLUMN_NAME
   ,c.typ_name AS current_type
   ,c.max_length AS current_lenght
   ,R.TYPE AS proposed_type
   ,R.MAX_LEN AS required_lenght
   ,R.MIN_LEN AS minimum_lenght
   ,R.SAMPLE AS DATA_SAMPLE
FROM #RESULTS R
JOIN #COLS c
	ON R.COLUMN_NAME = c.COLUMN_NAME
WHERE R.COMPABITLE = 1;
