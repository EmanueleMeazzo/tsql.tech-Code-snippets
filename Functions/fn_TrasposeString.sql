--Trasposes a string into tabular format, with position
--2018 Emanuele Meazzo - MIT LICENSE
CREATE FUNCTION fn_TrasposeString (@String NVARCHAR(255))
RETURNS TABLE
AS RETURN
  WITH E1(N) AS (
                 SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL
                 SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL
                 SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1 UNION ALL SELECT 1
                ),                                    
       E2(N) AS (SELECT 1 FROM E1 a CROSS JOIN E1 b), 
       E3(N) AS (SELECT 1 FROM E2 a CROSS JOIN E2 b), 
 cteTally(N) AS (SELECT TOP (ISNULL(LEN(@String),0)) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) FROM E2
                )
SELECT SUBSTRING(@String,N,1) CharValue, N as Position
FROM cteTally