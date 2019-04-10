
SELECT [p].[name] [package_name],
       [o].[name] [event_name],
       [c].[name] [event_field],
       [DurationUnit] = CASE
                            WHEN [c].[description] LIKE '%milli%' THEN SUBSTRING([c].[description],
                            CHARINDEX('milli', [c].[description]), 12)
                            WHEN [c].[description] LIKE '%micro%' THEN SUBSTRING([c].[description],
                            CHARINDEX('micro', [c].[description]), 12)
                            ELSE [c].[description]
                        END,
       [c].type_name [field_type],
       [c].[column_type] [column_type]
FROM   sys.dm_xe_objects o
JOIN sys.dm_xe_packages p
ON o.package_guid = p.guid
JOIN sys.dm_xe_object_columns c
ON o.name = c.object_name
WHERE  [o].[object_type] = 'event'
       AND [c].[name] = 'duration';
