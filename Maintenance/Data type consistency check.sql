/*
1. Database Design : Data Type Issues : Inconsistency
Identifies columns having different datatypes for the same column name.
Sorted by the prevalence of the mismatched column.

--Data type consistency check by Ian_Stirk@yahoo.com
*/

 -- Do not lock anything, and do not get held up by any locks.
 SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
 -- Calculate prevalence of column name
 SELECT
	   COLUMN_NAME
	   ,[%] = CONVERT(DECIMAL(12,2),COUNT(COLUMN_NAME)* 100.0 / COUNT(*)OVER())
 INTO #Prevalence
 FROM INFORMATION_SCHEMA.COLUMNS
 GROUP BY COLUMN_NAME
 -- Do the columns differ on datatype across the schemas and tables?
 SELECT DISTINCT
		 C1.COLUMN_NAME
	   , C1.TABLE_SCHEMA
	   , C1.TABLE_NAME
	   , C1.DATA_TYPE
	   , C1.CHARACTER_MAXIMUM_LENGTH
	   , C1.NUMERIC_PRECISION
	   , C1.NUMERIC_SCALE
	   , [%]
 FROM INFORMATION_SCHEMA.COLUMNS C1
 INNER JOIN INFORMATION_SCHEMA.COLUMNS C2 ON C1.COLUMN_NAME = C2.COLUMN_NAME
 INNER JOIN #Prevalence p ON p.COLUMN_NAME = C1.COLUMN_NAME
 WHERE ((C1.DATA_TYPE != C2.DATA_TYPE)
	   OR (C1.CHARACTER_MAXIMUM_LENGTH != C2.CHARACTER_MAXIMUM_LENGTH)
	   OR (C1.NUMERIC_PRECISION != C2.NUMERIC_PRECISION)
	   OR (C1.NUMERIC_SCALE != C2.NUMERIC_SCALE))
 ORDER BY [%] DESC, C1.COLUMN_NAME, C1.TABLE_SCHEMA, C1.TABLE_NAME
 -- Tidy up.
 DROP TABLE #Prevalence;
 GO 


 /*
2. Database Design : Data Type Issues : Oversize columns
Some developers and many ORMs consistently oversize the columns of their tables
compared to the amount of data actually stored, resulting in wasted space.
 
This script compares the column length according to the metadata versus the 
length of data actually in the column. 
*/

SET NOCOUNT ON;

DECLARE @table_schema   NVARCHAR(128);
DECLARE @table_name     NVARCHAR(128);
DECLARE @column_name    NVARCHAR(128);
DECLARE @parms          NVARCHAR(100);
DECLARE @data_type      NVARCHAR(128);
DECLARE @character_maximum_length   INT;
DECLARE @max_len        NVARCHAR(10);
DECLARE @tsql           NVARCHAR(4000);

DECLARE DDLCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
      table_schema,
      table_name,
      column_name,
      data_type,
      character_maximum_length
    FROM information_schema.columns
    WHERE table_name IN (SELECT table_name
                     FROM information_schema.tables
                     WHERE table_type = 'BASE TABLE') 
	AND data_type IN ('char', 'nchar', 'varchar', 'nvarchar') 
	AND character_maximum_length > 1

OPEN DDLCursor;
-- Should rewrite using sp_MSforeachtable instead of explicit cursor

SET @PARMS = N'@MAX_LENout nvarchar(10) OUTPUT';

CREATE TABLE #space(
  table_schema               NVARCHAR(128) NOT NULL,
  table_name                 NVARCHAR(128) NOT NULL,
  column_name                NVARCHAR(128) NOT NULL,
  data_type                  NVARCHAR(128) NOT NULL,
  character_maximum_length   INT NOT NULL,
  actual_maximum_length      INT NOT NULL);

-- Perform the first fetch.

FETCH NEXT FROM DDLCursor
INTO
  @table_schema,
  @table_name,
  @column_name,
  @data_type,
  @character_maximum_length;

-- Check @@FETCH_STATUS to see if there are any more rows to fetch.

WHILE @@FETCH_STATUS = 0
  BEGIN
    SET @tsql      = 'select @MAX_LENout = cast(max(len(isnull(' +
                     QUOTENAME(@COLUMN_NAME) +
                     ',''''))) as nvarchar(10)) from ' +
                     QUOTENAME(@TABLE_SCHEMA) +
                     '.' +
                     QUOTENAME(@TABLE_NAME);
    EXEC sp_executesql @tsql,
                       @PARMS,
                       @MAX_LENout = @MAX_LEN OUTPUT ;

    IF CAST(@MAX_LEN AS INT) < @CHARACTER_MAXIMUM_LENGTH -- not interested if lengths match
      BEGIN
        SET @tsql      = 'insert into #space values (''' +
                         @table_schema +
                         ''',''' +
                         @table_name +
                         ''',''' +
                         @column_name +
                         ''',''' +
                         @data_type +
                         ''',' +
                         CAST(@character_maximum_length AS NVARCHAR(10)) +
                         ',' +
                         @max_len +
                         ')';
        EXEC sp_executesql @tsql ;
      END;

    -- This is executed as long as the previous fetch succeeds.

    FETCH NEXT FROM DDLCursor
    INTO
      @table_schema,
      @table_name,
      @column_name,
      @data_type,
      @character_maximum_length;
  END;

CLOSE DDLCursor;
DEALLOCATE DDLCursor;

SELECT * FROM #space;
DROP TABLE #space;
GO