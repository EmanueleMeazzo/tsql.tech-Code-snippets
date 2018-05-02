
DECLARE @whoisactive_table VARCHAR(4000) ;
DECLARE @schema VARCHAR(4000) ;
DECLARE @dsql NVARCHAR(4000) ;

SET @whoisactive_table = QUOTENAME ('##WhoIsActive_' + CAST(NEWID() as varchar(255)));

EXEC sp_WhoIsActive
	@get_transaction_info = 1,
	@output_column_list = '[block%][%]',
	@get_plans = 1,
	@find_block_leaders = 1,
	@return_schema = 1,
	@format_output = 0,
	@schema = @schema OUTPUT ;
SET @schema = REPLACE(@schema, '<table_name>', @whoisactive_table) ;
PRINT @schema
EXEC(@schema) ;

EXEC sp_WhoIsActive
	@get_transaction_info = 1,
	@output_column_list = '[block%][%]',
	@get_plans = 1,
	@find_block_leaders = 1,
	@format_output = 0,
	@destination_table=@whoisactive_table;

SET @dsql = N'
IF (
SELECT COUNT(*)
FROM ' + @whoisactive_table + N'
WHERE blocking_session_id IS NOT NULL
and datediff(mi,start_time, collection_time) > 15
	) > 0

SELECT datediff(mi,start_time, collection_time) as duration_minutes, *
FROM ' + @whoisactive_table + N' OPTION (RECOMPILE);'

EXEC sp_executesql @dsql;

SET @dsql = N'DROP TABLE ' + @whoisactive_table + N';'
