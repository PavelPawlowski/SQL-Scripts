USE [msdb]
IF NOT EXISTS(SELECT * FROM sys.procedures WHERE object_id = OBJECT_ID('[dbo].[sp_JobStatus]'))
    EXEC (N'CREATE PROCEDURE [dbo].[sp_JobStatus] AS PRINT ''Placeholder for [dbo].[sp_JobStatus]''')
GO
/* ****************************************************
sp_JobStatus v 0.20 (2017-03-02)
(C) 2017 Pavel Pawlowski

Feedback: mailto:pavel.pawlowski@hotmail.cz

License: 
    sp_JobStatus is free to download and use for personal, educational, and internal 
    corporate purposes, provided that this header is preserved. Redistribution or sale 
    of sp_JobStatus, in whole or in part, is prohibited without the author's express 
    written consent.

Description:
    Provides information about processes in SSISDB

Parameters:
    @filter     nvarchar(max)   = NULL      --Comma separated list of LIKE filter to limit jobs. When not provided all jobs are printed
    ,@status    bit             = 1         --Status of the jobs to be printed. 1 = Enabled, 0 - Disabled, NULL = both disable and enabled
 ******************************************************* */
ALTER PROCEDURE [dbo].[sp_JobStatus]
    @filter     nvarchar(max)   = NULL      --Comma separated list of LIKE filter to limit jobs. When not provided all jobs are printed
    ,@status    bit             = 1         --Status of the jobs to be printed. 1 = Enabled, 0 - Disabled, NULL = both disable and enabled
AS
SET NOCOUNT ON;
DECLARE
    @job_id         uniqueidentifier
    ,@name          nvarchar(128)
    ,@msg           nvarchar(max)
    ,@job_id_str    nvarchar(50)
    ,@xml           xml

RAISERROR(N'--sp_JobStatus v0.21 (2017-11-21) (c) 2017 Pavel Pawlowski', 0, 0) WITH NOWAIT;
RAISERROR(N'--========================================================', 0, 0) WITH NOWAIT;
RAISERROR(N'--sp_JobStatus enables or disables jobs', 0, 0) WITH NOWAIT;
RAISERROR(N'', 0, 0) WITH NOWAIT;

IF @filter = N'?'
BEGIN
    RAISERROR(N'
Usage: sp_JobStatus [parameters]

Params:
    @filter     nvarchar(max)   = NULL  --Comma separated list of LIKE filter to limit jobs. When not provided all jobs are printed.
                                          filter prefixed by [-] removes jobs from selection
    ,@status    bit             = 1     --Status of the jobs to be printed. 1 = Enabled, 0 - Disabled, NULL = both disable and enabled

', 0, 0) WITH NOWAIT;
    RETURN;
END
ELSE
BEGIN
    RAISERROR(N'--sp_jobstatus ''?'' for help
    ', 0, 0) WITH NOWAIT;
END

SET @filter = ISNULL(NULLIF(@filter, N''), N'%')
SET @xml = N'<i>' + REPLACE(@filter, N',', N'</i><i>') + N'</i>'


SET @msg ='DECLARE @enabled bit = ' + CASE WHEN @status = 0 THEN N'0' ELSE N'1' END + N'    --Specify status to set 1 = Enabled, 0 = Disabled'
RAISERROR(@msg, 0, 0) WITH NOWAIT;

RAISERROR(N'', 0,0) WITH NOWAIT;
RAISERROR(N'DECLARE @status nvarchar(10) = CASE WHEN @enabled = 0 THEN N''Disabling'' ELSE N''Enabling'' END', 0,0) WITH NOWAIT;


DECLARE cr CURSOR FAST_FORWARD FOR
SELECT DISTINCT
    job_id
    ,name
FROM msdb.dbo.sysjobs j
INNER JOIN (SELECT LTRIM(RTRIM(n.value('.', 'nvarchar(128)'))) FROM @xml.nodes('/i') T(n)) F(n) ON j.name LIKE F.n
WHERE 
    enabled = @status OR @status IS NULL
    AND
    LEFT(F.n, 1) <> '-'
EXCEPT
SELECT
    job_id
    ,name
FROM msdb.dbo.sysjobs j
INNER JOIN (SELECT LTRIM(RTRIM(n.value('.', 'nvarchar(128)'))) FROM @xml.nodes('/i') T(n)) F(n) ON j.name LIKE RIGHT(F.n, LEN(F.n) - 1) AND LEFT(F.n, 1) = '-'
WHERE 
    enabled = @status OR @status IS NULL
    AND
    LEFT(F.n, 1) = '-'


OPEN cr;

RAISERROR(N'', 0,0) WITH NOWAIT;

FETCH NEXT FROM cr INTO @job_id, @name

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @job_id_str = CONVERT(nvarchar(50), @job_id);
    RAISERROR(N'RAISERROR(N''%%s job [%s] (%s)'', 0, 0, @status) WITH NOWAIT;', 0, 0, @name, @job_id_str) WITH NOWAIT;
    RAISERROR(N'EXEC msdb.dbo.sp_update_job @job_id=N''%s'', @enabled = @enabled', 0, 0, @job_id_str) WITH NOWAIT;
    FETCH NEXT FROM cr INTO @job_id, @name
END


CLOSE cr;
DEALLOCATE cr;
GO
