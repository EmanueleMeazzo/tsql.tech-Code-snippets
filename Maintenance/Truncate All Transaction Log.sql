DECLARE @DBName varchar(255)
DECLARE @LogName varchar(255)
DECLARE @DATABASES_Fetch int
DECLARE DATABASES_CURSOR CURSOR FOR
    select distinct
        name, db_name(s_mf.database_id) dbName
    from
        sys.master_files s_mf
    where
        s_mf.state = 0 and -- ONLINE
        has_dbaccess(db_name(s_mf.database_id)) = 1 -- Only look at databases to which we have access
    and db_name(s_mf.database_id) not in ('Master','tempdb','model')
    and db_name(s_mf.database_id) not like 'MSDB%'
    and db_name(s_mf.database_id) not like 'Report%'
    and type=1
    order by 
        db_name(s_mf.database_id)
OPEN DATABASES_CURSOR
FETCH NEXT FROM DATABASES_CURSOR INTO @LogName, @DBName
WHILE @@FETCH_STATUS = 0
BEGIN
 exec ('USE [' + @DBName + '] ; DBCC SHRINKFILE (N''' + @LogName + ''' , 0, TRUNCATEONLY)')
 FETCH NEXT FROM DATABASES_CURSOR INTO @LogName, @DBName
END
CLOSE DATABASES_CURSOR
DEALLOCATE DATABASES_CURSOR