--https://www.red-gate.com/simple-talk/sql/database-devops-sql/but-the-database-worked-in-development-preventing-broken-constraints/

CREATE OR ALTER PROCEDURE #ListAllCheckConstraints
  /**
Summary: >
  This creates a JSON list of all the check constraints in the database. 
  their name, table and definition
Author: Phil Factor
Date: 12/12/2019
Example:
   - DECLARE @OurListAllCheckConstraints  NVARCHAR(MAX)
     EXECUTE #ListAllCheckConstraints 
           @TheJsonList=@OurListAllCheckConstraints OUTPUT
     SELECT @OurListAllCheckConstraints AS theCheckConstraints
   - DECLARE @OurCheckConstraints  NVARCHAR(MAX)
     EXECUTE #ListAllCheckConstraints 
           @TheJsonList=@OurCheckConstraints OUTPUT
     SELECT Constraintname, TheTable, [definition]
      FROM OPENJSON(@OurCheckConstraints)  WITH
      (Constraintname sysname '$.constraintname',
           TheTable sysname '$.thetable', 
      [Definition] nvarchar(4000) '$.definition' ); 
Returns: >
  the JSON as an output variable
**/
  @TheJSONList NVARCHAR(MAX) OUTPUT
AS
SELECT @TheJSONList =
  (
  SELECT QuoteName(CC.name) AS constraintname,
    QuoteName(Object_Schema_Name(CC.parent_object_id)) + '.'
    + QuoteName(Object_Name(CC.parent_object_id)) AS thetable, 
    definition
    FROM sys.check_constraints AS CC
    WHERE is_ms_shipped = 0
  FOR JSON AUTO
  );
GO


CREATE OR ALTER PROCEDURE #TestAllCheckConstraints
  /**
Summary: >
  This tests the current database against its check constraints. 
  and reports any data that would fail a check were it enabled
Author: Phil Factor
Date: 15/12/2019
Example:
   - DECLARE @OurFailedConstraints  NVARCHAR(MAX)
     EXECUTE #TestAllCheckConstraints 
          @TheResult=@OurFailedConstraints OUTPUT
     SELECT @OurFailedConstraints AS theFailedCheckConstraints
  Returns: >
  the JSON as an output variable
**/
@JsonConstraintList NVARCHAR(MAX)=null,--you can either provide 
   --a json document or you can go and get the current
@TheResult NVARCHAR(MAX) OUTPUT --the JSON document that gives 
   --the test result.
as
IF @JsonConstraintList IS NULL
  EXECUTE #ListAllCheckConstraints 
      @TheJSONList = @JsonConstraintList OUTPUT;
DECLARE @Errors TABLE (Description NVARCHAR(MAX));--to temporarily 
      --hold errors
DECLARE @Breakers TABLE (TheObject NVARCHAR(MAX));--the rows that 
      --would fail
DECLARE @TheConstraints TABLE --the list of check constraints 
      --in the database
  (
  TheOrder INT IDENTITY PRIMARY KEY, --needed to iterate 
     --through the table
  ConstraintName sysname, --the number of columns used in the index
  TheTable sysname, --the quoted name of the table wqith the schema
  Definition NVARCHAR(4000) --the actual code of the constraint
  );
--we put the constraint data we need into a table variable
INSERT INTO @TheConstraints (ConstraintName, TheTable, Definition)
  SELECT Constraintname, TheTable, Definition
    FROM OpenJson(@JsonConstraintList)
    WITH --get the relational table from the JSON
      (
      Constraintname sysname '$.constraintname', 
       TheTable sysname '$.thetable',
      Definition NVARCHAR(4000) '$.definition' --the mapping
      );
DECLARE @iiMax INT = @@RowCount;
--to do the actual check
DECLARE @CheckConstraintExecString NVARCHAR(4000);
--make sure the table is there
DECLARE @TestForTableExistenceString NVARCHAR(4000);
--to get a sample of broken rows
DECLARE @GetBreakerSampleExecString NVARCHAR(4000);
--temporarily hold the current constraint name
DECLARE @ConstraintName sysname;
--temporarily hold the current constraint's table
DECLARE @ConstraintTable sysname;
--temporarily hold the constraint code
DECLARE @ConstraintExpression NVARCHAR(4000);
--the number of rows that fail the current constraint
DECLARE @AllRowsFailed INT; 
--a sample of failed rows
DECLARE @SampleOfFailedRows NVARCHAR(MAX);
--Did the table exist in the current database
DECLARE @ThereWasATable INT;
DECLARE @ii INT = 1;--iteration variables
WHILE (@ii <= @iiMax)
  --------------------start of the loop------------------
  BEGIN --create the expressions we need to execute 
        --dynamically for each constraint
    SELECT @CheckConstraintExecString = --expression that checks 
                                        --the constraint
      N'SELECT @RowsFailed=Count(*) FROM ' + TheTable + N' WHERE NOT '
      + Definition, @ConstraintName = ConstraintName,
      @ConstraintTable = TheTable,
      @GetBreakerSampleExecString = --expression that gets 
                                    --sample of failed rows
        N'SELECT @JSONBreakerData= (Select top 3 * FROM ' + TheTable
        + N' WHERE NOT ' + Definition + N'FOR JSON AUTO)',
      @ConstraintName = ConstraintName, @ConstraintTable = TheTable,
      @ConstraintExpression=[definition],
      @TestForTableExistenceString = --expression that checks 
                                     --for the table
        N'SELECT @TableThere=case when Object_id(''' + TheTable
        + N''') is null then 0 else 1 end'
      FROM @TheConstraints
      WHERE TheOrder = @ii;
      --check that the table is there 
    EXECUTE sp_executesql @TestForTableExistenceString,
      N'@TableThere int output', @TableThere = @ThereWasATable OUTPUT;
    IF @ThereWasATable = 1
      BEGIN --it is a bit safer to check the constraint
        EXECUTE sp_executesql @CheckConstraintExecString,
          N'@RowsFailed int output', @RowsFailed = @AllRowsFailed OUTPUT;
        IF @AllRowsFailed > 0 --Ooh, at least one failed constraint
          BEGIN--so we get a sample of the bad data in JSON
            EXECUTE sp_executesql @GetBreakerSampleExecString,
              N'@JSONBreakerData nvarchar(max) output',
              @JSONBreakerData = @SampleOfFailedRows OUTPUT;
            INSERT INTO @Breakers (TheObject)
              SELECT--and save the sample of bad rows along with 
                    --information about the constraint
                (
                SELECT 
                  Convert(VARCHAR(10), @AllRowsFailed) AS RowsFailed,
                  @ConstraintName AS ConstraintName,
                  @ConstraintTable AS ConstraintTable,
                  @ConstraintExpression AS Expression,
                  Json_Query(@SampleOfFailedRows) AS BadDataSample
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                );
          END;
      END;
    ELSE INSERT INTO @Errors (Description) 
         SELECT 'We Couldn''t find the table '
+ @ConstraintTable;
    SELECT @ii = @ii + 1; -- and iterate to the next row
  END;
 SELECT @TheResult= -- so we construct the JSON report.
  (SELECT
    (SELECT Json_Query(TheObject) AS BadData 
     FROM @Breakers FOR JSON AUTO) AS FailedChecks,
  (SELECT Description FROM @Errors FOR JSON AUTO) AS errors
FOR JSON PATH);
go