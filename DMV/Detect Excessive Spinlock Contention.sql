/**

Code by Michael J Swart
Source: https://michaeljswart.com/2020/10/detect-excessive-spinlock-contention-on-sql-server/
**/

EXEC sys.xp_readerrorlog 0, 1, N'detected', N'socket';
-- SQL Server detected 1 sockets with 8 cores per socket ...
 
declare @Sockets int = 1;
declare @PhysicalCoresPerSocket int = 8;
declare @TicksPerSpin int = 4;
 
declare @SpinlockSnapshot TABLE ( 
    SpinLockName VARCHAR(100), 
    SpinTotal BIGINT
);
 
INSERT @SpinlockSnapshot ( SpinLockName, SpinTotal )
SELECT name, spins
FROM   sys.dm_os_spinlock_stats
WHERE  spins > 0;
 
DECLARE @Ticks bigint
SELECT @Ticks = cpu_ticks 
FROM sys.dm_os_sys_info
 
WAITFOR DELAY '00:00:10'
 
DECLARE @TotalTicksInInterval BIGINT
DECLARE @CPU_GHz NUMERIC(20, 2);
 
SELECT @TotalTicksInInterval = (cpu_ticks - @Ticks) * @Sockets * @PhysicalCoresPerSocket,
       @CPU_GHz = ( cpu_ticks - @Ticks ) / 10000000000.0
FROM sys.dm_os_sys_info;
 
SELECT ISNULL(Snap.SpinLockName, 'Total') as [Spinlock Name], 
       SUM(Stat.spins - Snap.SpinTotal) as [Spins In Interval],
       @TotalTicksInInterval as [Ticks In Interval],
       @CPU_Ghz as [Measured CPU GHz],
       100.0 * SUM(Stat.spins - Snap.SpinTotal) * @TicksPerSpin / @TotalTicksInInterval as [%]
FROM @SpinlockSnapshot Snap
JOIN sys.dm_os_spinlock_stats Stat
     ON Snap.SpinLockName = Stat.name
GROUP BY ROLLUP (Snap.SpinLockName)
HAVING SUM(Stat.spins - Snap.SpinTotal) > 0
ORDER BY [Spins In Interval] DESC;