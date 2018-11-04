--Removes a pattern (LIKE Syntax) from the source string
--Requires fn_TrasposeString (https://github.com/EmanueleMeazzo/SQL-Code-snippets/tree/master/Functions)
--2018 Emanuele Meazzo - MIT LICENSE
CREATE OR ALTER FUNCTION fn_RemoveFromString (@SourceString nvarchar(255), @RemovePattern nvarchar(255))
RETURNS nvarchar(255)
AS
BEGIN

DECLARE @ReturnString nvarchar(255) = ''
    
SELECT @ReturnString += CharValue
FROM fn_TrasposeString(@SourceString)
WHERE CharValue NOT LIKE @RemovePattern
ORDER BY Position

RETURN @ReturnString

END
GO

--Examples
SELECT [dbo].fn_RemoveFromString('T-SQL.Tech','[-]')
SELECT [dbo].fn_RemoveFromString('05050T25020S5050550Q550050L015.151T505056e3c0195051109h50','[0-9]')