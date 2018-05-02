IF (OBJECT_ID('dbo.FindPrimaryKey') IS NULL)
	EXEC('CREATE PROCEDURE dbo.FindPrimaryKey AS --');
GO
/*

This stored procedure is used to identify primary key candidates.

Copyright Daniel Hutmacher under Creative Commons 4.0 license with attribution.
http://creativecommons.org/licenses/by/4.0/

Source:  http://sqlsunday.com/downloads/
Version: 2017-02-18

DISCLAIMER: This script does not make any modifications to the server, except
            for installing a stored procedure. However, the script may not be
	    suitable to run in a production environment. I cannot assume any
	    responsibility regarding the accuracy of the output information,
	    performance impacts on your server, or any other consequence. If
	    your juristiction does not allow for this kind of waiver/disclaimer,
	    or if you do not accept these terms, you are NOT allowed to store,
	    distribute or use this code in any way.

*/

ALTER PROCEDURE dbo.FindPrimaryKey
	@table		sysname
AS

--- Anything to declare?
DECLARE @sql nvarchar(max),		--- The source table we're analyzing.
        @count bigint;			--- Total row count of the source table.

SET NOCOUNT ON;

--- If we're talking temp tables, say so.
IF (@table LIKE '#%') SET @table='tempdb.dbo.'+@table;

--- This table keeps track of how many unique
--- members there are in each column of the table.
CREATE TABLE #counts (
	col		sysname NOT NULL,
	_dist	bigint NOT NULL,
	_count	bigint NOT NULL,
	PRIMARY KEY CLUSTERED (col)
);

--- These are all the candidates we're going to test:
CREATE TABLE #candidates (
	id		int NOT NULL,
	cols	xml NOT NULL,
	_dist	bigint NOT NULL,
	is_unique bit NULL,
	PRIMARY KEY CLUSTERED (id)
);




--- Here be dynamic SQL.
SET @sql='
	INSERT INTO #counts (col, _dist, _count)
	SELECT x.col, x._dist, src._count
	FROM (
		SELECT COUNT(*) AS _count'+CAST((SELECT ', COUNT(DISTINCT '+QUOTENAME([name])+') AS '+QUOTENAME('_dist_'+[name])
	FROM (
		SELECT [name] FROM sys.columns WHERE [object_id]=OBJECT_ID(@table) UNION ALL
		SELECT [name] FROM tempdb.sys.columns WHERE [object_id]=OBJECT_ID(@table)
		) AS cols
	FOR XML PATH(''), TYPE) AS varchar(max))+'
		FROM '+@table+') AS src
	CROSS APPLY (
		VALUES '+SUBSTRING(CAST((SELECT ', (src.'+QUOTENAME('_dist_'+[name])+', '''+[name]+''')'
	FROM (
		SELECT [name] FROM sys.columns WHERE [object_id]=OBJECT_ID(@table) UNION ALL
		SELECT [name] FROM tempdb.sys.columns WHERE [object_id]=OBJECT_ID(@table)
		) AS cols
	FOR XML PATH(''), TYPE) AS varchar(max)), 3, 10000)+'
		) AS x(_dist, col);';

EXECUTE sys.sp_executesql @sql;

--- We've stored the row count of the table in one of the columns.
SELECT TOP (1) @count=_count FROM #counts;


IF (EXISTS (SELECT NULL FROM #counts WHERE _dist=_count)) BEGIN;
	SELECT col AS [Columns], 'UNIQUE' AS Uniqueness
	FROM #counts
	WHERE _dist=_count;

	RETURN;
END;



--- These are all the candidates we're going to test:
WITH cte AS (
	SELECT 1 AS colcount, col, CAST('<col>'+col+'</col>' AS varchar(max)) AS cols, _dist
	FROM #counts
	WHERE _dist<_count

	UNION ALL

	SELECT cte.colcount+1, c.col, CAST(cte.cols+'<col>'+c.col+'</col>' AS varchar(max)), cte._dist*c._dist
	FROM cte
	INNER JOIN #counts AS c ON cte.col<c.col AND cte._dist<@count)

INSERT INTO #candidates (id, cols, _dist, is_unique)
SELECT ROW_NUMBER() OVER (ORDER BY colcount, _dist),
       CAST('<cols>'+cols+'</cols>' AS xml) AS cols, _dist, NULL
FROM cte
WHERE _dist>=@count;





--- Loop through them, iterate through increasing sample sizes:
WHILE (EXISTS (SELECT NULL FROM #candidates WHERE is_unique IS NULL)) BEGIN;

	SELECT TOP (1) @sql='
		DECLARE @sample bigint=1000, @duplicates bit=0;
		DECLARE @rowcount bigint='+CAST(@count AS nvarchar(max))+';

		SELECT @sample=1000, @duplicates=0;

		WHILE (@duplicates=0 AND @sample<@rowcount) BEGIN;
			SET @sample=@sample*5;

			SELECT TOP (1) @duplicates=1
			FROM (
				SELECT TOP (@sample) *
				FROM '+@table+') AS t
			GROUP BY '+REPLACE(REPLACE(REPLACE(CAST(cols AS nvarchar(max)), '</col><col>', '], ['), '<cols><col>', '['), '</col></cols>', ']')+'
			HAVING COUNT(*)>1;
		END;

		UPDATE #candidates
		SET is_unique=1-@duplicates
		WHERE id='+CAST(id AS nvarchar(10))+';'
	FROM #candidates AS c
	WHERE is_unique IS NULL
	ORDER BY id;

	EXECUTE sys.sp_executesql @sql;

END;



--- Output the results.
SELECT REPLACE(REPLACE(REPLACE(CAST(cols AS nvarchar(max)), '</col><col>', ', '), '<cols><col>', ''), '</col></cols>', '') AS [Columns],
       (CASE WHEN is_unique=1 THEN 'UNIQUE' WHEN is_unique=0 THEN 'Not unique' END) AS Uniqueness
FROM #candidates;



--- Clean-up.
DROP TABLE #candidates;
DROP TABLE #counts;


GO

--EXECUTE dbo.FindPrimaryKey '#table'

