USE [msdb]
IF NOT EXISTS(SELECT * FROM sys.procedures WHERE object_id = OBJECT_ID('[dbo].[sp_ScheduleStatus]'))
    EXEC (N'CREATE PROCEDURE [dbo].[sp_ScheduleStatus] AS PRINT ''Placeholder for [dbo].[sp_ScheduleStatus]''')
GO
/* ****************************************************
sp_ScheduleStatus v 0.16 (2017-11-21)

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
    Generates script for enabling or disabling job schedules

Parameters:
    @filter         nvarchar(max)   = NULL      --Comma separated list of LIKE filter to limit schedules. When not provided all schedules are scripted
    ,@status        bit             = 1         --Status of the schedule to be printed. 1 = Enabled, 0 - Disabled, NULL = both disable and enabled
    ,@job           nvarchar(max)   = NULL      --Comma separated list of LIKE filter to limit schedules by job names
    ,@category      nvarchar(max)   = NULL      --Comma separated list of LIKE filter to limit schedules by job categories
 ******************************************************* */
ALTER PROCEDURE [dbo].[sp_ScheduleStatus]
    @filter         nvarchar(max)   = NULL      --Comma separated list of LIKE filter to limit schedules. When not provided all schedules are scripted
    ,@status        bit             = 1         --Status of the schedule to be printed. 1 = Enabled, 0 - Disabled, NULL = both disable and enabled
    ,@job           nvarchar(max)   = NULL      --Comma separated list of LIKE filter to limit schedules by job names
    ,@category      nvarchar(max)   = NULL      --Comma separated list of LIKE filter to limit schedules by job categories
AS
SET NOCOUNT ON;
DECLARE
    @schedule_id    int
    ,@name          nvarchar(128)
    ,@msg           nvarchar(max)
    ,@xml           xml


DECLARE @categories TABLE (
    category_id INT NOT NULL PRIMARY KEY CLUSTERED
)

DECLARE @jobSchedules TABLE (
    schedule_id int NOT NULL PRIMARY KEY CLUSTERED
);

DECLARE @schedules TABLE (
    schedule_id int             NOT NULL PRIMARY KEY CLUSTERED
    ,name       nvarchar(128)
)

RAISERROR(N'--sp_ScheduleStatus v0.16 (2017-11-21) (c) 2017 Pavel Pawlowski', 0, 0) WITH NOWAIT;
RAISERROR(N'--=============================================================', 0, 0) WITH NOWAIT;
RAISERROR(N'--sp_ScheduleStatus Generates script for enabling or disabling job schedules', 0, 0) WITH NOWAIT;
RAISERROR(N'', 0, 0) WITH NOWAIT;

IF @filter = N'?'
BEGIN
    RAISERROR(N'
Usage: sp_ScheduleStatus [parameters]

Params:
    @filter         nvarchar(max)   = NULL      - Comma separated list of LIKE filter to limit schedules. When not provided all schedules are printed.
                                                  filter prefixed by [-] removes schedules from selection
    ,@status        bit             = 1         - Status of the schedules to be printed. 1 = Enabled, 0 - Disabled, NULL = both disabled and enabled
    ,@job           nvarchar(max)   = NULL      - Comma separated list of LIKE filter to limit schedules by job names.
                                                  If provided then only schedules for jobs with matching names are scripted
    ,@category      nvarchar(max)   = NULL      - Comma separated list of LIKE filter to limit schedules by job categories.
                                                  If provided then only schedules for jobs from matching job categories are scripted

@filter, @status, @job and @category are combined with AND when provided together.
', 0, 0) WITH NOWAIT;
    RETURN;
END
ELSE
BEGIN
    RAISERROR(N'--sp_ScheduleStatus ''?'' for help
    ', 0, 0) WITH NOWAIT;
END

IF @job IS NOT NULL OR @category IS NOT NULL
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

    SET @xml = N'<i>' + REPLACE(ISNULL(@job, N'%'), N',', N'</i><i>') + N'</i>';

    WITH JobNames AS (
        SELECT DISTINCT
            LTRIM(RTRIM(n.value('.', 'nvarchar(128)'))) AS JobName
        FROM @xml.nodes('/i') T(n)
    ),JobsBase AS (
        SELECT DISTINCT
            job_id
            ,category_id
        FROM msdb.dbo.sysjobs j
        INNER JOIN JobNames jn ON j.name LIKE jn.JobName AND LEFT(jn.JobName, 1) <> '-'
        EXCEPT
        SELECT DISTINCT
            job_id
            ,category_id
        FROM msdb.dbo.sysjobs j
        INNER JOIN JobNames jn ON j.name LIKE RIGHT(jn.JobName, LEN(jn.JobName) - 1) AND LEFT(jn.JobName, 1) = '-'
    ), Jobs AS(
        SELECT
            job_id
        FROM JobsBase j 
        WHERE
            @category IS NULL OR EXISTS(SELECT 1 FROM @categories c WHERE c.category_id = j.category_id)
    )
    INSERT INTO @jobSchedules(schedule_id)
    SELECT DISTINCT 
        js.schedule_id
    FROM msdb.dbo.sysjobschedules js
    INNER JOIN jobs j ON j.job_id = js.job_id
END


SET @filter = ISNULL(NULLIF(@filter, N''), N'%');
SET @xml = N'<i>' + REPLACE(@filter, N',', N'</i><i>') + N'</i>';


WITH Schedules AS (
    SELECT DISTINCT
        schedule_id
        ,name
    FROM msdb.dbo.sysschedules s
    INNER JOIN (SELECT LTRIM(RTRIM(n.value('.', 'nvarchar(128)'))) FROM @xml.nodes('/i') T(n)) F(n) ON s.name LIKE F.n
    WHERE 
        enabled = @status OR @status IS NULL
        AND
        LEFT(F.n, 1) <> '-'
    EXCEPT
    SELECT
        schedule_id
        ,name
    FROM msdb.dbo.sysschedules s
    INNER JOIN (SELECT LTRIM(RTRIM(n.value('.', 'nvarchar(128)'))) FROM @xml.nodes('/i') T(n)) F(n) ON s.name LIKE RIGHT(F.n, LEN(F.n) - 1) AND LEFT(F.n, 1) = '-'
    WHERE 
        enabled = @status OR @status IS NULL
        AND
        LEFT(F.n, 1) = '-'
)
INSERT INTO @schedules(schedule_id, name)
SELECT
    schedule_id
    ,name
FROM Schedules s
WHERE
    (@job IS NULL AND @category IS NULL) OR EXISTS(SELECT 1 FROM @jobSchedules js WHERE js.schedule_id = s.schedule_id)


IF NOT EXISTS(SELECT 1 FROM @schedules)
BEGIN
    RAISERROR(N'No job schedules matching provided criteria exists', 15, 0) WITH NOWAIT;
    RETURN;
END

SET @msg ='DECLARE @enabled bit = ' + CASE WHEN @status = 0 THEN N'0' ELSE N'1' END + N'    --Specify status to set: 1 = Enabled, 0 = Disabled'
RAISERROR(@msg, 0, 0) WITH NOWAIT;

RAISERROR(N'', 0,0) WITH NOWAIT;
RAISERROR(N'DECLARE @status nvarchar(10) = CASE WHEN @enabled = 0 THEN N''Disabling'' ELSE N''Enabling'' END', 0,0) WITH NOWAIT;


DECLARE cr CURSOR FAST_FORWARD FOR
SELECT
    schedule_id
    ,name
FROM @schedules

OPEN cr;

RAISERROR(N'', 0,0) WITH NOWAIT;

FETCH NEXT FROM cr INTO @schedule_id, @name

WHILE @@FETCH_STATUS = 0
BEGIN
    RAISERROR(N'-- [%s] (%d)', 0, 0, @name, @schedule_id) WITH NOWAIT;
    RAISERROR(N'RAISERROR(N''%%s schedule [%s] (%d)'', 0, 0, @status) WITH NOWAIT;', 0, 0, @name, @schedule_id) WITH NOWAIT;
    RAISERROR(N'EXEC msdb.dbo.sp_update_schedule @schedule_id=%d, @enabled = @enabled', 0, 0, @schedule_id) WITH NOWAIT;
    FETCH NEXT FROM cr INTO @schedule_id, @name
END


CLOSE cr;
DEALLOCATE cr;
GO