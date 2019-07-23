USE [msdb]
IF NOT EXISTS(SELECT * FROM sys.procedures WHERE object_id = OBJECT_ID('[dbo].[sp_JobStatus]'))
    EXEC (N'CREATE PROCEDURE [dbo].[sp_JobStatus] AS PRINT ''Placeholder for [dbo].[sp_JobStatus]''')
GO
/* ****************************************************
sp_JobStatus v 0.30 (2019-07-23)

Feedback: mailto:pavel.pawlowski@hotmail.cz

MIT License

Copyright (c) 2017 Pavel Pawlowski

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Description:
    Generates script for enabling or disabling jbos

Parameters:
    @filter         nvarchar(max)   = NULL      --Comma separated list of LIKE filter to limit jobs. When not provided all jobs are printed
    ,@status        bit             = 1         --Status of the jobs to be printed. 1 = Enabled, 0 - Disabled, NULL = both disable and enabled
    ,@category      nvarchar(max)   = NULL      --Comma separated list of LIKE filter to limit schedules by job categories
    ,@scriptName    bit             = 0         --Specifes whether Name should be scripted instead of job_id. Default 0 = job_id is used
 ******************************************************* */
ALTER PROCEDURE [dbo].[sp_JobStatus]
    @filter         nvarchar(max)   = NULL      --Comma separated list of LIKE filter to limit jobs. When not provided all jobs are printed
    ,@status        bit             = 1         --Status of the jobs to be printed. 1 = Enabled, 0 - Disabled, NULL = both disable and enabled
    ,@category      nvarchar(max)   = NULL      --Comma separated list of LIKE filter to limit schedules by job categories
    ,@scriptName    bit             = 0         --Specifes whether Name should be scripted instead of job_id. Default 0 = job_id is used
AS
SET NOCOUNT ON;
DECLARE
    @job_id         uniqueidentifier
    ,@name          nvarchar(128)
    ,@msg           nvarchar(max)
    ,@job_id_str    nvarchar(50)
    ,@xml           xml

DECLARE @categories TABLE (
    category_id INT NOT NULL PRIMARY KEY CLUSTERED
)

DECLARE @jobs TABLE (
    job_id  uniqueidentifier NOT NULL PRIMARY KEY CLUSTERED
    ,name   nvarchar(128)
)

RAISERROR(N'--sp_JobStatus v0.30 (2019-07-23) (c) 2017-2019 Pavel Pawlowski', 0, 0) WITH NOWAIT;
RAISERROR(N'--=============================================================', 0, 0) WITH NOWAIT;
RAISERROR(N'--sp_JobStatus Generates script for enabling or disabling jobs', 0, 0) WITH NOWAIT;
RAISERROR(N'', 0, 0) WITH NOWAIT;

IF @filter = N'?'
BEGIN
    RAISERROR(N'
Usage: sp_JobStatus [parameters]

Params:
    @filter     nvarchar(max)   = NULL  - Comma separated list of LIKE filter to limit jobs. When not provided all jobs are printed.
                                          filter prefixed by [-] removes jobs from selection
    ,@status    bit             = 1     - Status of the jobs to be printed. 1 = Enabled, 0 - Disabled, NULL = both disable and enabled
    ,@category  nvarchar(max)   = NULL  - Comma separated list of LIKE filter to limit schedules by job categories.
                                          If provided then only jobs from matching job categories are scripted.
    ,@scriptName    bit         = 0     - Specifes whether Name should be scripted instead of job_id. Default 0 = job_id is used

@filter, @status and @category are combined with AND when provided together.

', 0, 0) WITH NOWAIT;
    RETURN;
END
ELSE
BEGIN
    RAISERROR(N'--sp_jobstatus ''?'' for help
    ', 0, 0) WITH NOWAIT;
END

IF @category IS NOT NULL
BEGIN
    IF @category IS NOT NULL
    BEGIN
        SET @xml = N'<i>' + REPLACE(ISNULL(@category, N'%'), N',', N'</i><i>') + N'</i>';
        WITH CategoryNames AS (
            SELECT DISTINCT
                LTRIM(RTRIM(n.value('.', 'nvarchar(128)'))) AS Categoryname
            FROM @xml.nodes('/i') T(n)
        )
        INSERT INTO @categories(category_id)
        SELECT DISTINCT
            c.category_id
        FROM msdb.dbo.syscategories c
        INNER JOIN CategoryNames cn  ON c.name LIKE cn.Categoryname AND LEFT(cn.Categoryname, 1) <> '-'
        EXCEPT
        SELECT DISTINCT
            c.category_id
        FROM msdb.dbo.syscategories c
        INNER JOIN CategoryNames cn  ON c.name LIKE RIGHT(cn.Categoryname, LEN(cn.Categoryname) - 1) AND LEFT(cn.Categoryname, 1) = '-'
    END
END

SET @filter = ISNULL(NULLIF(@filter, N''), N'%');
SET @xml = N'<i>' + REPLACE(@filter, N',', N'</i><i>') + N'</i>';

WITH Jobs AS (
    SELECT DISTINCT
        job_id
        ,name
        ,category_id
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
        ,category_id
    FROM msdb.dbo.sysjobs j
    INNER JOIN (SELECT LTRIM(RTRIM(n.value('.', 'nvarchar(128)'))) FROM @xml.nodes('/i') T(n)) F(n) ON j.name LIKE RIGHT(F.n, LEN(F.n) - 1) AND LEFT(F.n, 1) = '-'
    WHERE 
        enabled = @status OR @status IS NULL
        AND
        LEFT(F.n, 1) = '-'
)
INSERT INTO @jobs(job_id, name)
SELECT
    job_id
    ,name
FROM Jobs j
WHERE
    @category IS NULL OR EXISTS(SELECT 1 FROM @categories c WHERE c.category_id = j.category_id)


IF NOT EXISTS(SELECT 1 FROM @jobs)
BEGIN
    RAISERROR(N'No jobs matching provided criteria exists', 15, 0) WITH NOWAIT;
    RETURN;
END

SET @msg ='DECLARE @enabled bit = ' + CASE WHEN @status = 0 THEN N'0' ELSE N'1' END + N'    --Specify status to set: 1 = Enabled, 0 = Disabled'
RAISERROR(@msg, 0, 0) WITH NOWAIT;

RAISERROR(N'', 0,0) WITH NOWAIT;
RAISERROR(N'DECLARE @status nvarchar(10) = CASE WHEN @enabled = 0 THEN N''Disabling'' ELSE N''Enabling'' END', 0,0) WITH NOWAIT;


DECLARE cr CURSOR FAST_FORWARD FOR
SELECT
    job_id
    ,name
FROM @jobs

OPEN cr;

RAISERROR(N'', 0,0) WITH NOWAIT;

FETCH NEXT FROM cr INTO @job_id, @name

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @job_id_str = CONVERT(nvarchar(50), @job_id);
    RAISERROR(N'RAISERROR(N''%%s job [%s] (%s)'', 0, 0, @status) WITH NOWAIT;', 0, 0, @name, @job_id_str) WITH NOWAIT;
    IF @scriptName = 1
        RAISERROR(N'EXEC msdb.dbo.sp_update_job @job_name=N''%s'', @enabled = @enabled', 0, 0, @name) WITH NOWAIT;
    ELSE
        RAISERROR(N'EXEC msdb.dbo.sp_update_job @job_id=N''%s'', @enabled = @enabled', 0, 0, @job_id_str) WITH NOWAIT;
    FETCH NEXT FROM cr INTO @job_id, @name
END


CLOSE cr;
DEALLOCATE cr;
GO
