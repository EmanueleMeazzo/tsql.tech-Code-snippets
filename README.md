# tsql.tech Code snippets

List of contents:

* ## DMV (Estract useful informations from DMVs)
  - Find Key Lookup in Plan Cache
  - Find Long Running Queries in PlanCache
  - Find Most Expensive Queries in PlanCache
  - Find Plans of your query in PlanCache
  - Find implicit Conversion Queries in PlanCache.
  - Index Usage Statis
  - LatchesStats
  - SpinlockStats
  - Table Sizes
  - Waitstats

* ## Dynamic SQL
  - Execute and Track the performance and behavior of Dynamic SQL Statements
    [REFERENCE ARTICLE](https://tsql.tech/tracking-dynamic-sql-performance-automatically-with-a-wrapper-on-sp_executesql-dynamic-sql-inception/)

* ## Extended Events
  - Backup-Restore duration troubleshoot
  - Capture Plans with warning

* ## Functions
  - DelimitedSplit8K - The powerful splitting function by [Jeff Moden](http://www.sqlservercentral.com/articles/Tally+Table/72993/)
  - fn_KeepInString - Keep only certain values in a sting [See Article](https://tsql.tech/a-quick-function-to-remove-or-keep-only-string-patterns-from-sql-server-strings/)
  - fn_RemoveFromString - remove certain patterns from a string [See Article](https://tsql.tech/a-quick-function-to-remove-or-keep-only-string-patterns-from-sql-server-strings/)
  - fn_TrasposeString - Trasposes strings into tables [See Article](https://tsql.tech/a-quick-function-to-remove-or-keep-only-string-patterns-from-sql-server-strings/)

* ## Maintenance
  - Align Columnstore Index - [Automatically align columnstore indexes to enhance segment elimination (and hence performances)](https://tsql.tech/a-script-to-automatically-align-columnstore-indexes-to-enhance-segment-elimination-and-hence-performances/)
  - Data type consistency check
  - Rebuild Fragmented Heaps
  - Truncate All Transaction Log
  - VLF_Shrink

* ## PowerBI
  - Job Information - [A report to analyze the Agent Job performance, comes with companion procedure](https://tsql.tech/a-powerbi-report-for-sql-server-agent-jobs/)
  - Permission Information - [A report to analyze the granular permissions on your SQL Server instance](https://tsql.tech/a-sql-server-permission-report-in-powerbi/)

* ## QueryStore
  - Query Tuning Reccomandations
  - QueryStore_Duration

* ## Schema-Related
  - Bulk Move Schema
  - Find Column by name
  - Find Stored Procedure
  - Find primary key candidates

* ## Troubleshooting
  - How Many Rows has a DML Operation modified until now
  - ParallelTasks of a Session
  - Read TransactionLog User Actions [HOW TO FIND A SAFE RESTORE POINT (AND WHO MESSED UP) BY READING FROM THE TRANSACTION LOG](https://tsql.tech/find-who-e-when-something-was-messed-up-in-order-to-restore-to-a-safe-point-using-the-transaction-log/)
  - TempDB Page Contention
  - sp_whoisactive_find_longrunning_blocked_query
  
* ## Views
  - BlitzCache_MissingIndexesView - Filters the BlitzCache historic table for misssing indexes reports
  - JobAndSchedules - Shows SQL Agent Jobs and Schedules, by [M.Pearson](http://www.sqlservercentral.com/scripts/Maintenance+and+Management/30381/)
