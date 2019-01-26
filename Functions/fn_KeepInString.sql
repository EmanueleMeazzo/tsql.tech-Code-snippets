--Removes everything except a pattern (LIKE Syntax) from the source string
--Requires fn_TrasposeString (https://github.com/EmanueleMeazzo/SQL-Code-snippets/tree/master/Functions)
--2018 Emanuele Meazzo - MIT LICENSE
CREATE OR ALTER FUNCTION fn_KeepInString (@SourceString nvarchar(255), @KeepPattern nvarchar(255))
RETURNS nvarchar(255)
AS
BEGIN

DECLARE @ReturnString nvarchar(255) = ''
    
SELECT @ReturnString += CharValue
FROM fn_TrasposeString(@SourceString)
WHERE CharValue LIKE  @KeepPattern
ORDER BY Position

RETURN @ReturnString

END
GO

--Examples
SELECT [dbo].fn_KeepInString('T-SQL.Tech','[a-z,A-Z,.]')
SELECT [dbo].fn_KeepInString('05050T25020S5050550Q550050L015.151T505056e3c0195051109h50','[A-Z,a-z,.]')