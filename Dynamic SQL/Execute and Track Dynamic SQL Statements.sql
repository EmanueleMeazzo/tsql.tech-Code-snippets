SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

DROP TABLE IF EXISTS [dbo].[DYNSQL_LOG]

CREATE TABLE [dbo].[DYNSQL_LOG](
	[Id] [bigint] IDENTITY(1,1) NOT NULL,
	[UserName] [nvarchar](128),
	[StartTime] [datetime2](7),
	[EndTime] [datetime2](7) NULL,
	[RunTimeSeconds]  AS (datediff(second,[StartTime],[EndTime])) PERSISTED,
	[RunTimeMilliSeconds]  AS (datediff(millisecond,[StartTime],[EndTime])) PERSISTED,
	[DynamicSQL] [nvarchar](max),
	[Failed] [bit] NULL,
	[ErrorMsg] [nvarchar] (256) NULL,
	[Tag] [varchar] (512) NULL
 CONSTRAINT [PK_DYNSQL_LOG] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

CREATE TYPE SQLParameters AS TABLE
(   
    Name NVARCHAR(50),
    Value NVARCHAR(max),
    Type NVARCHAR(20) DEFAULT N'NVARCHAR(20)'
);
GO


CREATE OR ALTER PROCEDURE [dbo].[ExecuteAndTrackSQL] (
    @USER_IDEN NVARCHAR(256) = 'Undef',
    @SQL NVARCHAR(MAX),
    @PARAM_VALUES SQLParameters READONLY,
    @RETURN nvarchar(max) = NULL OUTPUT,
    @SKIP_ERRORS bit = 0,
    @TAG varchar (512) = NULL
    )
AS
--09/01/2017 Emanuele Meazzo
--Added @TAG to Tag Code to know from where it was launched (or other tagging)
--14/08/2017 Emanuele Meazzo
--Added error tracking information
--Logging full execution stack for parameter launch
--07/07/2017 Emanuele Meazzo
--Added generic parameter output (limited to 1 in this release)
--31/05/2017 Emanuele Meazzo
--First Release
BEGIN

SET NOCOUNT ON;

SELECT @USER_IDEN = SUSER_NAME()
WHERE @USER_IDEN = 'Undef'

--Log the Start
INSERT INTO dbo.DYNSQL_LOG (UserName, StartTime, EndTime, DynamicSQL, Tag)
    VALUES (@USER_IDEN, SYSDATETIME(), NULL, @SQL, @TAG)

DECLARE @ID int = SCOPE_IDENTITY();

DECLARE @Count int
SELECT @Count = COUNT(*)
FROM @PARAM_VALUES;

IF(@Count = 0)
BEGIN
    --Execute without parameters
    BEGIN TRY

	   EXEC sp_executesql @SQL;
    END TRY
    BEGIN CATCH
	   UPDATE dbo.DYNSQL_LOG
	   SET EndTime = SYSDATETIME(),
		  Failed = 1,
		  ErrorMsg = LEFT(ERROR_MESSAGE(),256)
	   WHERE
		Id = @ID;

	   IF(@SKIP_ERRORS = 0)
		  THROW

    END CATCH;
END
ELSE
BEGIN
        SET @SQL = REPLACE(@SQL,'''',''''''); --Escape ' for execution

	   --Execute with parameters (max 1 Output parameter)
	   DECLARE @SupportSQL_Header		nvarchar(max)
	   DECLARE @SupportSQL_Footer		nvarchar(max)
	   DECLARE @SupportSQL_Parameters	nvarchar(max)

	   SELECT @SupportSQL_Header = COALESCE(@SupportSQL_Header,N'SET NOCOUNT ON;' + CHAR(13)+CHAR(10)) + 'DECLARE @' + P.Name + N' as ' + REPLACE(P.Type,'OUTPUT','') + ' = ' +
	   CASE
		  WHEN P.Type LIKE 'varchar%' THEN '''' + P.Value + ''''
		  WHEN P.Type LIKE 'nvarchar%' THEN 'N''' + P.Value + ''''
		  ELSE CONVERT(nvarchar(40),P.Value)
		  END
	   --+ CHAR(13)+CHAR(10)
	   FROM @PARAM_VALUES P

	   SELECT @SupportSQL_Parameters = COALESCE(@SupportSQL_Parameters,'DECLARE @Parameters nvarchar(max) = N''') + N'@' + P.Name + N' as ' + P.Type + N', '
	   FROM @PARAM_VALUES P

	   SET @SupportSQL_Parameters = LEFT(@SupportSQL_Parameters,LEN(@SupportSQL_Parameters)-1) + N''''

	   SELECT @SupportSQL_Footer = COALESCE(@SupportSQL_Footer,N'EXEC sp_executesql @SQL, @Parameters, ') + '@' + P.Name + N' = @' + P.Name +N', '
	   FROM @PARAM_VALUES P

	   SET @SupportSQL_Footer = LEFT(@SupportSQL_Footer,LEN(@SupportSQL_Footer)-1)

	   --Find the eventual output variable
	   DECLARE @OUT_VARIABLE nvarchar(256)
	   SELECT TOP 1 @OUT_VARIABLE = Name
	   FROM @PARAM_VALUES
	   WHERE Type LIKE '%OUTPUT%'

	   --Adds 'OUTPUT' in the parameter assign step if there is an output variable in the parameters
	   IF @OUT_VARIABLE IS NOT NULL
		  SET @SupportSQL_Footer = REPLACE(@SupportSQL_Footer,N' = @' + @OUT_VARIABLE,N' = @' + @OUT_VARIABLE + N' OUTPUT')

	   DECLARE @SupportSQL_OutGrabber nvarchar(max)
	   SET @SupportSQL_OutGrabber = N'SET @OUTPUT = CONVERT(nvarchar(max),@' + @OUT_VARIABLE + N');'

	   SET @SQL = N'DECLARE @SQL nvarchar(max) = N''' + @SQL + ''''
	   

	   --Build the dynamic string to run
	   SET @SQL =	@SupportSQL_Header + N';' + CHAR(13)+CHAR(10) +
	   			@SupportSQL_Parameters + N';' + CHAR(13)+CHAR(10) +
	   			@SQL + N';' + CHAR(13)+CHAR(10) +
	   			@SupportSQL_Footer + N';' + CHAR(13)+CHAR(10) +
				COALESCE(@SupportSQL_OutGrabber,N'')
	   
	   --PRINT @SQL

	   UPDATE dbo.DYNSQL_LOG
		  SET DynamicSQL = @SQL
	   WHERE Id = @ID
	   
	   BEGIN TRY

		  EXEC sp_executesql @SQL, N'@OUTPUT nvarchar(max) OUTPUT', @OUTPUT = @RETURN OUTPUT --DUMMY OUTPUT VALUE

	   END TRY
	   BEGIN CATCH
		  UPDATE dbo.DYNSQL_LOG
			 SET EndTime = SYSDATETIME(),
			 Failed = 1,
			 ErrorMsg = LEFT(ERROR_MESSAGE(),256)
		  WHERE Id = @ID
		  
		  IF(@SKIP_ERRORS = 0)
			 THROW

	   END CATCH

	   --SELECT @RETURN

END;

UPDATE dbo.DYNSQL_LOG
    SET EndTime = SYSDATETIME()
WHERE Id = @ID

END
GO

