IF NOT EXISTS(SELECT 1 FROM sys.databases where name = 'SSISDB')
BEGIN
    RAISERROR(N'SSIS Database Does not Exists', 15, 0)
    SET NOEXEC ON;
END
GO
USE [SSISDB]
GO
RAISERROR('Creating procedure [dbo].[sp_ssisstat]', 0, 0) WITH NOWAIT;
IF NOT EXISTS(SELECT * FROM sys.procedures WHERE object_id = OBJECT_ID('[dbo].[sp_ssisstat]'))
    EXEC (N'CREATE PROCEDURE [dbo].[sp_ssisstat] AS PRINT ''Placeholder for [dbo].[sp_ssisstat]''')
GO
/* ****************************************************
sp_ssistat v 0.30 (2018-01-02)

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
    Provides information about processes in SSISDB

Parameters:
 ******************************************************* */
ALTER PROCEDURE [dbo].[sp_ssisstat]
     @op                    nvarchar(max)   = NULL              --Operator
    ,@folder                nvarchar(max)	= '%'               --Comma separated list of folder filters. Default NLL means no filtering. See below for more details
    ,@project               nvarchar(max)   = '%'               --Comma separated list of project filters. Default NULL means no filtering. See below for more details
    ,@package               nvarchar(max)   = '%'               --Comma separated list of package filters. Default NULL means no filtering. See below for more details
    ,@status                nvarchar(max)   = NULL              --Comma separated list of execution statuses to be included in statistics. Default NULL means all. See below for more details
    ,@statistics            nvarchar(max)   = '%'               --Comma separated list of statistics to be returned
WITH EXECUTE AS 'AllSchemaOwner'
AS
SET NOCOUNT ON;

RAISERROR(N'sp_ssisstat v0.30 (2018-01-02) (c) 2017 - 2018 Pavel Pawlowski', 0, 0) WITH NOWAIT;
RAISERROR(N'==============================================================', 0, 0) WITH NOWAIT;
RAISERROR(N'sp_ssisstat provides statistics about operations in ssisdb', 0, 0) WITH NOWAIT;
RAISERROR(N'', 0, 0) WITH NOWAIT;


DECLARE
     @xr                                nvarchar(10)        = N'</i><i>'    --xml replacement'
    ,@defaultLastOp	                    int                 = 100           --default number of rows to retrieve
    ,@msg                               nvarchar(max)                   --general purpose message variable
    ,@sql                               nvarchar(max)                   --variable for storing queries to be executed
    ,@dateList                          nvarchar(max)
    ,@dateColList                       nvarchar(max)
    ,@statnameList                      nvarchar(max)
    ,@durationCondition                 nvarchar(max)       = N'(1=1)'
    ,@durationMsg                       nvarchar(max)
    ,@xml                               xml
    ,@help                              bit                 = 0
    ,@debugLevel                        int                 = 0             --debug level
    ,@lastDays                          int
    ,@defaultLastDays                   int                 = 7         --defaultLastDays
    ,@minDate                           datetime2(7)
    ,@maxDate                           datetime2(7)
    ,@minDateTZ                         datetimeoffset(7)
    ,@maxDateTZ                         datetimeoffset(7)
    ,@useStartTime                      bit                 = 1
    ,@useEndTime                        bit                 = 0
    ,@useCreateTime                     bit                 = 0
    ,@useTimeDescending                 bit                 = 1
    ,@lastOperations                    int                 = NULL
    ,@processLastStatus                 bit                 = 0
    ,@minOpID                           bigint
    ,@maxOpID                           bigint

--Update input paramters
SELECT
     @op                    = ISNULL(NULLIF(@op, N''), N'DS')  --DEFAULT @op
    ,@folder                = ISNULL(NULLIF(@folder, N''), N'%')
    ,@project               = ISNULL(NULLIF(@project, N''), N'%')
    ,@package               = ISNULL(NULLIF(@package, N''), N'%')
    ,@statistics            = ISNULL(NULLIF(@statistics, N''), N'%')
    ,@status                = NULLIF(@status, N'')


DECLARE @dates TABLE (
    operation_date  date PRIMARY KEY CLUSTERED
    ,SortAsc        int
    ,SortDesc       int
);

DECLARE @supportedStatistics TABLE (
    statistic_name  nvarchar(128)   NOT NULL 
    ,stat           char(1)         NOT NULL
    ,sort_order     int
    ,PRIMARY KEY CLUSTERED(statistic_name, stat)
)

DECLARE @generalStatNames TABLE (
    statistic_name  nvarchar(128) NOT NULL PRIMARY KEY CLUSTERED
    ,sort_order     int
)


DECLARE @dailyStatNames TABLE (
    statistic_name  nvarchar(128) NOT NULL PRIMARY KEY CLUSTERED
)

DECLARE @execStatNames TABLE (
    statistic_name  nvarchar(128) NOT NULL PRIMARY KEY CLUSTERED
)

DECLARE @valModifiers TABLE (
    Val         nvarchar(10)
    ,Modifier   nvarchar(30)
    ,LeftChars  int
)

INSERT INTO @valModifiers(Val, Modifier, LeftChars)
VALUES
     ('LD'      ,'LD'                       ,NULL)      --Last 
    ,('LD'      ,'LD:'                      ,3)         --Last 
    ,('LD'      ,'LAST_DAYS:'               ,10)        --Last 

    ,('LS'      ,'LS:'                      ,3)         --Last Status
    ,('LS'      ,'LAST_STATUS:'             ,12)        --Last Status

    ,('ST'      ,'ST'                       ,2)         --Use Start TIme
    ,('ST'      ,'START_TIME'               ,10)        --Use Start Time
    ,('ET'      ,'ET'                       ,2)         --Use End TIme
    ,('ET'      ,'END_TIME'                 ,8)         --Use EndTime
    ,('CT'      ,'CT'                       ,2)         --Use Create Time
    ,('CT'      ,'CREATE_TIME'              ,1)         --Use Create Time

    ,('GS'      ,'GS'                       ,NULL)      --General Execution Statistics
    ,('GS'      ,'GENERAL_STATISTICS'       ,NULL)      --General Execution Statistics
    ,('DS'      ,'DS'                       ,NULL)      --Daily Execution Statistics
    ,('DS'      ,'DAILY_STATISTICS'         ,NULL)      --Daily Execution Statistis

    ,('ES'      ,'ES'                       ,NULL)      --Individual execution statistics
    ,('ES'      ,'ES:'                      ,3)         --Individual execution statistics
    ,('ES'      ,'EXECUTION_STATISTICS:'    ,21)        --Individual execution statistics

    ,('S'      ,'S:'                        ,2)         --Execution status filter
    ,('S'      ,'STATUS:'                   ,7)         --Execution status filter

    ,('>'       ,'>'                        ,1)         --Duration longer than
    ,('>='      ,'>='                       ,2)         --Duration longer or equal to
    ,('<'       ,'<'                        ,1)         --Duration shorter than
    ,('<='      ,'<='                       ,2)         --Duration shorter or equal to
    ,('='       ,'='                        ,1)         --Duration equal to

    ,('?'       ,'?'                        ,NULL)      --Help


    ,('DBG','DBG', 3)    --TEMPORARY DEBUG


INSERT INTO @supportedStatistics(statistic_name, stat, sort_order)
VALUES
     (N'executions_count'            , 'D', 1)
    ,(N'executed_versions'           , 'D', 2)
    ,(N'min_success_duration'        , 'D', 3)
    ,(N'max_success_duration'        , 'D', 4)
    ,(N'avg_success_duration'        , 'D', 5)
    ,(N'max_duration'                , 'D', 6)
    ,(N'min_success_duration_ms'     , 'D', 7)
    ,(N'max_success_duration_ms'     , 'D', 8)
    ,(N'avg_success_duration_ms'     , 'D', 9)
    ,(N'max_duration_ms'             , 'D', 10)
    ,(N'status_created'              , 'D', 11)
    ,(N'status_running'              , 'D', 12)
    ,(N'status_cancelled'            , 'D', 13)
    ,(N'status_failed'               , 'D', 14)
    ,(N'status_pending'              , 'D', 15)
    ,(N'status_ended_unexpectedly'   , 'D', 16)
    ,(N'status_succeeded'            , 'D', 17)
    ,(N'status_stopping'             , 'D', 18)
    ,(N'status_completed'            , 'D', 19)
    ,(N'first_execution_start'       , 'D', 20)
    ,(N'last_execution_start'        , 'D', 21)
    ,(N'last_excution_end'           , 'D', 22)
    ,(N'duration'                    , 'E', 1)
    ,(N'duration_ms'                 , 'E', 2)
    ,(N'start_time'                  , 'E', 3)
    ,(N'end_time'                    , 'E', 4)
    ,(N'status'                      , 'E', 5)
    ,(N'status_description'          , 'E', 6)
    ,(N'created_time'                , 'E', 7)
    ,(N'project_lsn'                 , 'E', 8)
    ,(N'executions_count'            , 'G', 1)
    ,(N'success_count'               , 'G', 2)
    ,(N'failed_count'                , 'G', 3)
    ,(N'avg_success_duration'        , 'G', 4)
    ,(N'min_success_duration'        , 'G', 5)
    ,(N'max_success_duration'        , 'G', 6)
    ,(N'max_duration'                , 'G', 7)
    ,(N'avg_success_duration_ms'     , 'G', 8)
    ,(N'min_success_duration_ms'     , 'G', 9)
    ,(N'max_success_duration_ms'     , 'G', 10)
    ,(N'max_duration_ms'             , 'G', 11)
    ,(N'first_execution_start'       , 'G', 12)
    ,(N'last_execution_start'        , 'G', 13)
    ,(N'last_execution_end'          , 'G', 14)
    ,(N'executed_versions'           , 'G', 15)
    ,(N'counts_by_exec_status'       , 'G', 16)

IF OBJECT_ID(N'tempdb..#lastStatuses') IS NOT NULL
    DROP TABLE #lastStatuses;
IF OBJECT_ID(N'tempdb..#statuses') IS NOT NULL
    DROP TABLE #statuses;

CREATE TABLE #lastStatuses (
    id          smallint        NOT NULL    PRIMARY KEY CLUSTERED
)

CREATE TABLE #statuses (
    id          smallint        NOT NULL    PRIMARY KEY CLUSTERED
)

DECLARE @availStatuses TABLE (
    id          smallint        NOT NULL    PRIMARY KEY CLUSTERED
    ,[status]   nvarchar(20)
    ,short      nvarchar(2)
)

--available execution statuses
INSERT INTO @availStatuses(id, [status], short)
VALUES
     (1, N'CREATED'     , N'T')
    ,(2, N'RUNNING'     , N'R')
    ,(3, N'CANCELLED'   , N'C')
    ,(4, N'FAILED'      , N'F')
    ,(5, N'PENDING'     , N'PD')
    ,(6, N'UNEXPECTED'  , N'U')
    ,(7, N'SUCCESS'     , N'S')
    ,(8, N'STOPPING'    , N'G')
    ,(9, N'COMPLETED'   , N'CD')

    /* =================================
             OPERATION Retrieval 
    ====================================*/
                                         --replacing [<] with &lt; as [<] is illegal in xml building
	SET @xml = N'<i>' + REPLACE(REPLACE(@op, N'<', N'&lt;') , N' ', @xr) + N'</i>'

	DECLARE @opVal TABLE (	--Operation Validities
		Val			    varchar(10) NOT NULL PRIMARY KEY CLUSTERED
		,MinDateVal	    datetime2(7)
        ,MaxDateVal     datetime2(7)
		,MinIntVal	    bigint
        ,MaxIntVal      bigint
        ,StrVal         nvarchar(max)
        ,DurationDate   datetime2(7)
        ,OPValCount     int
	)

    DECLARE @opValData TABLE (
         Modifier       nvarchar(30)
        ,ValModifier    nvarchar(30)
        ,Val            varchar(10)
        ,DateVal        datetime2(7)
        ,IntVal         bigint
        ,StrVal         nvarchar(50)
        ,DurationDate   datetime2(7)
    )

	;WITH OPBase AS (
        SELECT
            NULLIF(LTRIM(RTRIM(n.value('.','nvarchar(128)'))), '') AS Modifier
        FROM @xml.nodes('/i') T(N)
	), OP AS (
	    SELECT
            OP.Modifier
            ,VM.Modifier AS ValModifier
            ,CASE 
                WHEN VM.Val IS NOT NULL THEN VM.Val
                WHEN TRY_CONVERT(bigint, OP.Modifier) IS NOT NULL THEN 'I'
                WHEN TRY_CONVERT(datetime2(7), OP.Modifier) IS NOT NULL THEN 'D'
                ELSE NULL 
            END AS Val
            ,CASE 
                WHEN TRY_CONVERT(datetime2(7), OP.Modifier) IS NOT NULL THEN
                    CASE
                        WHEN CONVERT(date, CONVERT(datetime2(7), OP.Modifier)) = '19000101' THEN DATEADD(NANOSECOND, DATEDIFF(NANOSECOND, DATEADD(SECOND, DATEDIFF(SECOND, '19000101', OP.Modifier), '19000101'), OP.Modifier) ,DATEADD(SECOND, DATEDIFF(SECOND, '19000101', OP.Modifier), CONVERT(datetime2(7), CONVERT(date, SYSDATETIME()))))
                        --CONVERT(datetime, CONVERT(date, GETDATE())) + CONVERT(datetime, CONVERT(time, CONVERT(datetime, OP.Modifier)))
                        ELSE CONVERT(datetime2(7), OP.Modifier)
                    END
                ELSE NULL
                END AS DateVal
            ,CASE 
                WHEN VM.LeftChars IS NOT NULL THEN TRY_CONVERT(bigint, RIGHT(OP.Modifier, LEN(OP.Modifier) - VM.LeftChars))
                ELSE TRY_CONVERT(int, OP.Modifier) 
            END AS IntVal
            ,CASE 
                WHEN VM.LeftChars IS NOT NULL THEN CONVERT(nvarchar(50), RIGHT(OP.Modifier, LEN(OP.Modifier) - VM.LeftChars))
                ELSE CONVERT(nvarchar(50), OP.Modifier) 
            END AS StrVal
            ,CASE 
                WHEN VM.VAL IN (N'>', N'>=', N'<', N'<=', N'=') THEN 
                    CASE
                        WHEN CHARINDEX('D', UPPER(RIGHT(OP.Modifier, LEN(OP.Modifier) - VM.LeftChars))) > 0 THEN  DATEADD(
                                                                        MILLISECOND, 
                                                                        DATEDIFF(MILLISECOND, 0, TRY_CONVERT(datetime2(7), RIGHT(RIGHT(OP.Modifier, LEN(OP.Modifier) - VM.LeftChars), LEN(RIGHT(OP.Modifier, LEN(OP.Modifier) - VM.LeftChars)) - CHARINDEX('D', UPPER(RIGHT(OP.Modifier, LEN(OP.Modifier) - VM.LeftChars))))))                                                        
                                                                        ,DATEADD(DAY, TRY_CONVERT(int, SUBSTRING(RIGHT(OP.Modifier, LEN(OP.Modifier) - VM.LeftChars), 1, CHARINDEX('D', UPPER(RIGHT(OP.Modifier, LEN(OP.Modifier) - VM.LeftChars))) - 1)), 0)
                                                                    ) 
                        ELSE TRY_CONVERT(datetime2(7), RIGHT(RIGHT(OP.Modifier, LEN(OP.Modifier) - VM.LeftChars), LEN(RIGHT(OP.Modifier, LEN(OP.Modifier) - VM.LeftChars)) - CHARINDEX('D', UPPER(RIGHT(OP.Modifier, LEN(OP.Modifier) - VM.LeftChars)))))
                    END

                ELSE NULL
            END AS DurationDate
	    FROM OPBase OP
        LEFT JOIN @valModifiers VM ON (OP.Modifier = VM.Modifier AND VM.LeftChars IS NULL) OR (LEFT(OP.Modifier, VM.LeftChars) = VM.Modifier)
    )
    INSERT INTO @opValData(Modifier, ValModifier, Val, DateVal, IntVal, StrVal, DurationDate)
    SELECT
        OP.Modifier
        ,OP.ValModifier
        ,OP.Val
        ,OP.DateVal
        ,OP.IntVal
        ,OP.StrVal
        ,OP.DurationDate
    FROM OP
    WHERE 
        OP.Modifier IS NOT NULL
        AND
        (
            OP.ValModifier NOT IN (N'<', N'>')
            OR
            (
                OP.ValModifier IN (N'<', N'>')
                AND
                SUBSTRING(OP.Modifier, 2, 1) <> '='
            )
            OR
            OP.ValModifier IS NULL AND OP.Val IS NOT NULL
       )

    --Check if we have a help modifier
    IF EXISTS(SELECT 1 FROM @opValData WHERE Val = '?')
        SET @help = 1            


    IF @help <> 1
    BEGIN
        RAISERROR(N'sp_ssisstat ''?'' --to print procedure help', 0, 0) WITH NOWAIT;
        RAISERROR('', 0, 0) WITH NOWAIT;
    END


IF @help <> 1
BEGIN
    RAISERROR(N'Global Statistics Parameters:', 0, 0) WITH NOWAIT;

	INSERT INTO @opVal (Val,  MinDateVal, MaxDateVal, MinIntVal, MaxIntVal, StrVal, DurationDate, OPValCount)
    SELECT
        Val
        ,CASE WHEN Val = 'D' THEN MIN(ISNULL(DateVal, '19000101')) ELSE NULL END AS MinDateVal
        ,CASE WHEN Val = 'D' THEN MAX(ISNULL(DateVal, '19000101')) ELSE NULL END AS MaxDateVal
        ,CASE WHEN Val IN ('I', 'L', 'LD', 'DBG') 
            THEN MIN(ISNULL(IntVal, 0)) 
            ELSE NULL 
        END AS MinIntVal
        ,CASE 
            WHEN Val IN ('I', 'L', 'LD', 'ES', 'DBG') THEN MAX(ISNULL(IntVal, 0)) 
            ELSE NULL
         END AS MaxIntVal
        ,CASE
            WHEN Val IN ('LS', 'S', 'ST', 'ET', 'CT') THEN MAX(ISNULL(StrVal, ''))
            ELSE NULL
        END AS StrVal
        ,CASE 
            WHEN Val IN (N'>', N'>=') THEN MAX(ISNULL(DurationDate, '19000101'))
            WHEN Val IN (N'<', N'<=', N'=') THEN MIN(ISNULL(DurationDate, '19000101')) 
            ELSE NULL
        END AS DurationDate
        ,COUNT(1) AS OPValCount
    FROM @opValData
    	WHERE 
            (
                (Val IS NOT NULL AND Val NOT IN (N'>', N'>=', N'<', N'<=', N'='))
                OR 
                DateVal IS NOT NULL 
                OR 
                IntVal IS NOT NULL
            )
            OR
            (
                Val IN (N'>', N'>=', N'<', N'<=', N'=')
                AND
                DurationDate IS NOT NULL
            )
    GROUP BY Val

    IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'DBG')
    BEGIN
        SET @debugLevel = ISNULL(NULLIF((SELECT MaxIntVal FROM @opVal WHERE Val = N'DBG'), 0), 1)
        
        if(@debugLevel > 1)
            SELECT '@opValData' AS TableName, * FROM @opValData

        if (@debugLevel > 2)
            SELECT '@opVal' AS TableName,  * FROM @opVal
    END

    IF EXISTS(SELECT 1 FROM @opValData WHERE Val IS NULL) 
    BEGIN
        SET @msg = 'There are unsupported values, keywords or modifiers passed in the @op parameter. Check the parameters and/or formatting: ' + NCHAR(13) +
            QUOTENAME(STUFF((SELECT ', ' + op.Modifier FROM  @opValData op WHERE Val IS NULL FOR XML PATH('')), 1, 2, ''), '"') + NCHAR(13);
        RAISERROR(@msg, 11, 0) WITH NOWAIT;

        SET @help = 1
    END

    IF EXISTS (SELECT 1 FROM @opValData WHERE Val IN (N'>', N'>=', N'<', N'<=', N'=') AND DurationDate IS NULL)
    BEGIN
        SET @msg = 'There are unsupported duration modifiers passed in the @op parameter. Check parameters and/or formatting: ' + NCHAR(13) +
            QUOTENAME(REPLACE(REPLACE(STUFF((SELECT ', ' + op.Modifier FROM  @opValData op WHERE Val IN (N'>', N'>=', N'<', N'<=', N'=') AND DurationDate IS NULL FOR XML PATH(N'')), 1, 2, N''), N'&gt;', N'>'), N'&lt;', N'<'), '"') + NCHAR(13);
        RAISERROR(@msg, 11, 0) WITH NOWAIT;

        SET @help = 1
    END

    --Process Statuses (@status variable has priority over the S: @op specifier
    IF @status IS NULL AND EXISTS(SELECT 1 FROM @opVal WHERE Val = 'S' AND StrVal IS NOT NULL AND StrVal <> '')
        SET @status = (SELECT StrVal FROM @opVal WHERE Val = 'S')

    IF @status IS NOT NULL
    BEGIN
        SET @xml = N'<i>' + REPLACE(@status, N',', @xr) + N'</i>';
        WITH Statuses AS (
            SELECT DISTINCT
                NULLIF(LTRIM(RTRIM(n.value('.','nvarchar(128)'))), '') AS status
            FROM @xml.nodes('/i') T(n)
        )
        INSERT INTO #statuses(id)
        SELECT
            ss.id
        FROM Statuses s
        INNER JOIN @availStatuses ss ON s.status = ss.short OR s.status = ss.status;

        WITH Statuses AS (
            SELECT DISTINCT
                NULLIF(LTRIM(RTRIM(n.value('.','nvarchar(128)'))), '') AS status
            FROM @xml.nodes('/i') T(n)
        )
        SELECT @msg = STUFF((
        SELECT
            N',' + s.status
        FROM Statuses s
        LEFT JOIN @availStatuses ss ON s.status = ss.short OR s.status = ss.status
        WHERE ss.id IS NULL
        FOR XML PATH(N'')), 1, 1, '')

        IF @msg IS NOT NULL
        BEGIN
            RAISERROR(N'Unsupported statuses: %s', 11, 0, @msg) WITH NOWAIT;
            SET @help = 1
        END
        ELSE
        BEGIN
            SET @msg = STUFF((
                SELECT
                    N', ' +s.status
                FROM #statuses ls
                INNER JOIN @availStatuses s ON s.id = ls.id
                FOR XML PATH(N'')), 1, 2, N''
            )

            RAISERROR(N'   - Execution Statuses: %s', 0, 0, @msg) WITH NOWAIT;
        END
    END


    --Get Last Statuses
    IF EXISTS(SELECT 1 FROM @opVal WHERE Val = 'LS')
    BEGIN
        SET @processLastStatus = 1;
        SET @xml = N'<i>' + REPLACE((SELECT StrVal FROM @opVal WHERE Val = 'LS'), N',', @xr) + N'</i>';
        WITH Statuses AS (
            SELECT DISTINCT
                NULLIF(LTRIM(RTRIM(n.value('.','nvarchar(128)'))), '') AS status
            FROM @xml.nodes('/i') T(n)
        )
        INSERT INTO #lastStatuses(id)
        SELECT
            ss.id
        FROM Statuses s
        INNER JOIN @availStatuses ss ON s.status = ss.short OR s.status = ss.status;

        WITH Statuses AS (
            SELECT DISTINCT
                NULLIF(LTRIM(RTRIM(n.value('.','nvarchar(128)'))), '') AS status
            FROM @xml.nodes('/i') T(n)
        )
        SELECT @msg = STUFF((
        SELECT
            N',' + s.status
        FROM Statuses s
        LEFT JOIN @availStatuses ss ON s.status = ss.short OR s.status = ss.status
        WHERE ss.id IS NULL
        FOR XML PATH(N'')), 1, 1, '')

        IF @msg IS NOT NULL
        BEGIN
            RAISERROR(N'Unsupported last statuses: %s', 11, 0, @msg) WITH NOWAIT;
            SET @help = 1
        END
        ELSE IF NOT EXISTS(SELECT 1 FROM #lastStatuses)
        BEGIN
            RAISERROR(N'No last status was specified', 11, 0) WITH NOWAIT;
            SET @help = 1
        END
        ELSE
        BEGIN
            SET @msg = STUFF((
                SELECT
                    N', ' +s.status
                FROM #lastStatuses ls
                INNER JOIN @availStatuses s ON s.id = ls.id
                FOR XML PATH(N'')), 1, 2, N''
            )

            RAISERROR(N'   - Last Execution Statuses: %s', 0, 0, @msg) WITH NOWAIT;
        END
    END

    --Get statistics
    --General Statistics
    IF EXISTS(SELECT 1 FROM @OpVal WHERE Val = 'GS')
    BEGIN
        SET @xml = N'<i>' + REPLACE(@statistics, N',', '</i><i>') + N'</i>';
        WITH StatNames AS (
            SELECT DISTINCT
                NULLIF(LTRIM(RTRIM(n.value('.','nvarchar(128)'))), '') AS name
            FROM @xml.nodes('/i') T(n)
        )
        INSERT INTO @generalStatNames(statistic_name, sort_order)
        SELECT DISTINCT
            s.statistic_name
            ,s.sort_order
        FROM  @supportedStatistics s
        INNER JOIN StatNames sn ON s.stat = 'G' AND s.statistic_name LIKE sn.name AND LEFT(sn.name, 1) <> N'-'
        EXCEPT
        SELECT DISTINCT
            s.statistic_name
            ,s.sort_order
        FROM @supportedStatistics s
        INNER JOIN StatNames sn ON s.stat = 'G' AND s.statistic_name LIKE RIGHT(sn.name, LEN(sn.name) - 1) AND LEFT(sn.name, 1) = N'-';

        IF NOT EXISTS(SELECT 1 from @generalStatNames)
        BEGIN
            RAISERROR(N'At least one General statistics has to be selected', 11, 0) WITH NOWAIT;
            SET @help = 1
        END

    END

    --Daily Statistics
    IF EXISTS(SELECT 1 FROM @OpVal WHERE Val = N'DS')
    BEGIN
        SET @xml = N'<i>' + REPLACE(@statistics, N',', '</i><i>') + N'</i>';
        WITH StatNames AS (
            SELECT DISTINCT
                NULLIF(LTRIM(RTRIM(n.value('.','nvarchar(128)'))), '') AS name
            FROM @xml.nodes('/i') T(n)
        )
        INSERT INTO @dailyStatNames(statistic_name)
        SELECT DISTINCT
            s.statistic_name
        FROM  @supportedStatistics s
        INNER JOIN StatNames sn ON s.stat = 'D' AND s.statistic_name LIKE sn.name AND LEFT(sn.name, 1) <> N'-'
        EXCEPT
        SELECT DISTINCT
            s.statistic_name
        FROM @supportedStatistics s
        INNER JOIN StatNames sn ON s.stat = 'D' AND s.statistic_name LIKE RIGHT(sn.name, LEN(sn.name) - 1) AND LEFT(sn.name, 1) = N'-';

        IF NOT EXISTS(SELECT 1 from @dailyStatNames)
        BEGIN
            RAISERROR(N'At least one Daily statistics has to be selected', 11, 0) WITH NOWAIT;
            SET @help = 1
        END

    END

    IF EXISTS(SELECT 1 FROM @OpVal WHERE Val = N'ES')
    BEGIN

        SET @xml = N'<i>' + REPLACE(@statistics, N',', '</i><i>') + N'</i>';
        WITH StatNames AS (
            SELECT DISTINCT
                NULLIF(LTRIM(RTRIM(n.value('.','nvarchar(128)'))), '') AS name
            FROM @xml.nodes('/i') T(n)
        )
        INSERT INTO @execStatNames(statistic_name)
        SELECT DISTINCT
            s.statistic_name
        FROM  @supportedStatistics s
        INNER JOIN StatNames sn ON s.stat = 'E' AND s.statistic_name LIKE sn.name AND LEFT(sn.name, 1) <> N'-'
        EXCEPT
        SELECT DISTINCT
            s.statistic_name
        FROM @supportedStatistics s
        INNER JOIN StatNames sn ON s.stat = 'E' AND s.statistic_name LIKE RIGHT(sn.name, LEN(sn.name) - 1) AND LEFT(sn.name, 1) = N'-';

        IF NOT EXISTS(SELECT 1 from @execStatNames)
        BEGIN
            RAISERROR(N'At least one Execution statistics has to be selected', 11, 0) WITH NOWAIT;
            SET @help = 1
        END
    END


    IF OBJECT_ID('tempdb..#folders') IS NOT NULL
    DROP TABLE #folders;
    IF OBJECT_ID('tempdb..#projects') IS NOT NULL
    DROP TABLE #projects;
    IF OBJECT_ID('tempdb..#packages') IS NOT NULL
    DROP TABLE #packages;


    CREATE TABLE #folders (
    folder_id       bigint                                      NOT NULL    PRIMARY KEY CLUSTERED
    ,folder_name    nvarchar(128)   COLLATE DATABASE_DEFAULT    NOT NULL
    )

    CREATE TABLE #projects (
    project_id      bigint                                      NOT NULL    PRIMARY KEY CLUSTERED
    ,project_name   nvarchar(128)   COLLATE DATABASE_DEFAULT    NOT NULL
    ,folder_name    nvarchar(128)   COLLATE DATABASE_DEFAULT    NOT NULL
    )


    CREATE TABLE #packages (
    folder_name     nvarchar(128)   COLLATE DATABASE_DEFAULT    NOT NULL
    ,project_name   nvarchar(128)   COLLATE DATABASE_DEFAULT    NOT NULL
    ,package_name   nvarchar(250)   COLLATE DATABASE_DEFAULT    NOT NULL
    )


    --Execution IDs are provided
    IF EXISTS(SELECT 1 FROM @opVal WHERE VAL ='I')
    BEGIN
        SELECT
            @minOpID    = CASE WHEN MinIntVal < 0 THEN 0 ELSE MinIntVal END
            ,@maxOpID   = CASE WHEN MaxIntVal < 0 THEN 0 ELSE MaxIntVal END
        FROM @opVal
        WHERE Val = 'I'
        

        IF @minOpID = @maxOpID
            SET @maxOpID = NULL;

        IF @maxOpID IS NULL
            RAISERROR('   - From execution_id %I64d', 0, 0, @minOpID) WITH NOWAIT;
        ELSE
            RAISERROR('   - Execution_id(s) Between %I64d and %I64d', 0, 0, @minOpID, @maxOpID) WITH NOWAIT;

    END
    --Get Date params
    ELSE IF EXISTS(SELECT 1 FROM @opVal WHERE Val = 'D')
    BEGIN
        SELECT @minDate = ov.MinDateVal FROM @opVal ov WHERE Val = 'D';
        SELECT @maxDate = ov.MaxDateVal FROM @opVal ov WHERE Val = 'D' AND OPValCount > 1

        SELECT
            @minDateTZ = TODATETIMEOFFSET(@minDate, DATEPART(TZ, SYSDATETIMEOFFSET()))
            ,@maxDateTZ = TODATETIMEOFFSET(@maxDate, DATEPART(TZ, SYSDATETIMEOFFSET()))

        IF @maxDateTZ IS NOT NULL
        BEGIN
            SET @msg = '   - Statistics:    Between ' +  CONVERT(nvarchar(30), @minDateTZ, 120) + N' and ' + CONVERT(nvarchar(30), @maxDateTZ, 120);
        END
        ELSE
        BEGIN
            SET @msg = '   - Statistics:    From ' + CONVERT(nvarchar(30), @minDateTZ, 120)    
        END

        RAISERROR(@msg, 0, 0) WITH NOWAIT;

    END
    ELSE --Get last days
    BEGIN        
        SET @lastDays = (SELECT MaxIntVal FROM @opVal WHERE Val = 'LD');

        IF (@lastDays IS NULL OR @lastDays = 0)
        BEGIN
            IF EXISTS(SELECT 1 FROM @opVal WHERE Val = 'LD')
                SET @lastDays = 1
            ELSE
                SET @lastDays = @defaultLastDays
        END
    
        SET @minDate = DATEADD(DAY, DATEDIFF(DAY,'19000101', DATEADD(DAY, -@lastDays + 1, SYSUTCDATETIME())), '19000101')        
        SET @minDateTZ = TODATETIMEOFFSET(@minDate, DATEPART(TZ, SYSDATETIMEOFFSET()))

        RAISERROR(N'   - Statistics:    For last: %d day(s)', 0, 0, @lastDays) WITH NOWAIT;
    END

    --duration was specified - build duration condition and message
    IF EXISTS(SELECT 1 FROM @opVal WHERE Val IN (N'>', N'>=', N'<', N'<=', N'='))
    BEGIN
        SELECT 
            @durationCondition = 
                N'(' + REPLACE(REPLACE(STUFF((
                    SELECT
                        N' AND durationDate ' + Val + N' ''' + CONVERT(varchar(27), DurationDate, 121) + N''''
                    FROM @opVal
                    FOR XML PATH('')
                ), 1, 5, N''), N'&lt;', N'<'), N'&gt;', N'>') + N')'

        SET @durationMsg = 
            REPLACE(REPLACE(STUFF((
                SELECT
                    N' AND ' + Val + N' ''' + CONVERT(nvarchar(10), DATEDIFF(DAY, 0, DurationDate)) + 'd ' + CONVERT(varchar(16), CONVERT(time, DurationDate)) + N''''
                FROM @opVal
                FOR XML PATH('')
            ), 1, 5, N''), N'&lt;', N'<'), N'&gt;', N'>')

        RAISERROR(N'   - Duration:      %s', 0, 0, @durationMsg) WITH NOWAIT;
    END


        --Sorting processing
        IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'ST') OR NOT EXISTS(SELECT 1 FROM @opVal WHERE Val IN ('ST', 'ET', 'CT'))
        BEGIN
            IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'ST' AND StrVal IN ('_A', '_ASC' ,'A', 'ASC'))
                SET @useTimeDescending = 0;
                
            SET @useStartTime = 1;

            SET @msg = CASE WHEN @useTimeDescending = 0 THEN 'Ascending' ELSE N'Descending' END
            RAISERROR(N'   - Sort by Start Time %s', 0, 0, @msg) WITH NOWAIT;
        END 
        ELSE IF EXISTS(SELECT 1 FROM @opVal WHERE Val = 'ET')
        BEGIN
            IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'ET' AND StrVal IN ('_A', '_ASC','A','ASC'))
                SET @useTimeDescending = 0;

            SET @useEndTime = 1;
            SET @msg = CASE WHEN @useTimeDescending = 0 THEN 'Ascending' ELSE N'Descending' END
            RAISERROR(N'   - Sort by End Time %s', 0, 0, @msg) WITH NOWAIT;
        END
        ELSE
        BEGIN
            IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'CT' AND StrVal IN ('_A', '_ASC','A','ASC'))
                SET @useTimeDescending = 0;

            SET @msg = CASE WHEN @useTimeDescending = 0 THEN 'Ascending' ELSE N'Descending' END
            RAISERROR(N'   - Sort by Create Time %s', 0, 0, @msg) WITH NOWAIT;
        END

    

    IF @debugLevel > 0
    BEGIN
        SELECT
            'Global Params'         AS 'Param Table'
            ,@minDate               AS '@minDate'
            ,@minDateTZ             AS '@minDateTZ'
            ,@maxDate               AS '@maxDate'
            ,@maxDateTZ             AS '@maxDateTZ'
            ,@lastDays              AS '@lastDays'
            ,@durationCondition     AS '@durationCondition'
            ,@minOpID               AS '@minOpID'
            ,@maxOpID               AS '@maxOpID'
            ,@useStartTime          AS '@useStartTime'
            ,@useEndTime            AS '@useEndTime'
            ,@useTimeDescending     AS '@useTimeDescending'
    END
END --IF @help <> 1

/*   HELP   */
IF @help = 1
BEGIN
    RAISERROR('Usage: sp_ssisstat [params]', 0, 0) WITH NOWAIT;
    RAISERROR('--------------------------', 0, 0) WITH NOWAIT;
    RAISERROR('', 0, 0) WITH NOWAIT;

    RAISERROR(N'Parametes:
     @op                    nvarchar(max)   = NULL  - Operator parameter - universal operator for setting large range of condidions and filters
    ,@folder                nvarchar(max)   = ''%%''   - Comma separated list of folder filters. Default NULL means no filtering. See below for more details
    ,@project               nvarchar(max)   = ''%%''   - Comma separated list of project filters. Default NULL means no filtering. See below for more details
    ,@package               nvarchar(max)   = ''%%''   - Comma separated list of pacakge filters. Default NULL means no filtering. See below for more details
    ,@statistics            nvarchar(MAX)   = ''%%''   - Comma separated list of statistics to be returned.
', 0, 0) WITH NOWAIT;

RAISERROR(N'
@op
===
  ?                             - Print this help

  STATISTICS SPECIFIERS:
  ----------------------

  GENERAL_STATISTICS(GS)        - Return General statistics about executions
  DAILY_STATISTICS(DS)          - Regurn Daily aggregated statitstics
                                  This is default statistics if no statistics specifier is provided
  EXECUTION_STATISTICS(ES):iiii - Return Execution statistics

 ', 0, 0) WITH NOWAIT;

RAISERROR(N'
  LAST_DAYS(LD):iiiii           - Says that statistics should be collected for last iiiii days.
                                  If iiiii is not provided then then last 1 execution is returned. 
                                  If Keyword is missing the default LAST 7 days are used

  STATUS(S):ssssssss            - Optional STATTUS parameters
                                  ssssssss is comma separated list of @status filter. Support shortcut or full status name 
                                  it can be used instead of the @status parameter. If both are specified @status parameter has priority
                                  See @status parameter for details.', 0, 0) WITH NOWAIT;

RAISERROR(N'
  LAST_STATUS(LS):ssssssss      - Optionnal LAST_STATUS parameter
                                  ssssssss is a comma separated list of status_filter(s). Support shortcut or full status name
                                  If specified then only packages which last execution status is equal to one from the provided list.
                                  See @status parameter for list of supported values.
                                  If LAST_STATUS and STATUS is used together then first LAST_STATUS is used to retrieve the lsit of packages
                                  but the only operations with STATUS are returned in the statistics.

  Date/Time                     - If provided then executions since that Date/Time are considered for statistics. 
                                  If multiple Date/Time values are provided then executions between MIN and MAX values are returned.
                                  Date/Time modifier has priority over the LAST_DAYS(LD):iiiii modifier
  hh:MM[:ss]                    - If only time is provided, then the time is interpreted as Time of current day
  yyyy-mm-dd                    - If only date is provided, then it is intepreted as midnigth of that day (YYYY-MM-DDT00:00:00)
  yyyy-mm-ddThh:MM:ss           - When Date/Time is passed, then Time is separated by T from date. In that case hours have to be provided as two digits

  >|>=|<|<=|=dddddd             - Duration Specifier. If provided then only operations with duration corresponding to the specifier are considered for statistics. Multiple specifiers are combined with AND.
                                  If multiple durations are specified for the same specifier, MAX duration is used for [>] and [>=] and and MIN durtion for [<], [<=], [=]                                  
  dddddd                        - Specifies duration in below allowed formats
  hh:MM[:ss[.fff]]              - If only time is specified, it represents duration in hours, minutes, seconds and fraction of second
  iiid[hh:MM[:ss[.fff]]]        - iii followed by d specifies number of days. Optionaly additional time can follow

', 0, 0) WITH NOWAIT;

RAISERROR(N'
  iiiiiiiiiiiiii               - (integer values) Specifies range of execution_id(s) to return statistics. If single initeger is provided than executios starting with that id will be considered for statistics. 
                                 In case of multiple initegers, then range between minimum and maximum execution_id is processed
                                 The execution_id has priority over Date/Time and LAST_DAYS(LD):iiiii modifiers
', 0, 0) WITH NOWAIT;

RAISERROR(N'
@status - Execution Statuses
----------------------------
Comma separated list of operation execution statuses to be included in the statistics.

Below list of execution statuses are available for filter:

  (R)UNNING         - Filter Modifier applies RUNNING status filter
  (S)UCCESS         - Filter Modifier applie SUCCESS status filter
  (F)AILURE         - Filter modifier applies FAILURE status filter
  (C)ANCELLED       - Filter modifier applies CANCELLED status filter
  (U)NEXPECTED      - Filter modifier applies UNEXPECTED status filter
  CREATED(TD)       - Filter modifier applies CREATED status filter
  (P)ENDING         - Filter modifier applies PENDING status filter
  STOPPIN(G)        - Filter modifier applies STOPPING status filter
  COMPLETED(CD)     - Filter modifier applies COMPLETED status filter
', 0, 0) WITH NOWAIT;


RAISERROR(N'
@folder
=======
Comma separated list of Folder filters. When specified only executions of packages from projects belonging to providedl folders list are shown.
Supports LIKE wildcards. Default NULL means any folder.

@project
========
Comma separated list of project filters. When specified, only executions of packages from projects matching the filter are shown.
All matching project cross beloding to folders specified by @folder parameter are used.
Supports LIKE wildcards. Default NULL means any project.', 0, 0) WITH NOWAIT;

RAISERROR(N'
@package
========
Comma separated list of package filters. When specified only executions of packages whose name is matching the @package filer are shown.
Package are shown from all folders/projects matching the @folder/@project parameter.
Supports LIKE wildcards. Default NULL means any package.', 0, 0) WITH NOWAIT;

RAISERROR(N'
@statistics
-----------
Comma separated list of statistics to be returned. Supports LIKE wildcards. Different statistics are suppoerted by different statistics specifiers

GENERAL_STATISTICS:
-------------------
executions_count
success_count
failed_count
avg_success_duration
min_success_duration
max_success_duration
max_duration
avg_success_duration_ms
min_success_duration_ms
max_success_duration_ms
max_duration_ms
first_execution_start
last_execution_start
last_execution_end
executed_versions
counts_by_exec_status', 0, 0) WITH NOWAIT
RAISERROR(N'
DAILY_STATISTICS:
-----------------
executions_count
executed_versions
min_success_duration
max_success_duration
avg_success_duration
max_duration
status_created
status_running
status_cancelled
status_failed
status_pending
status_ended_unexpectedly
status_succeeded
status_stopping
status_completed
first_execution_start
last_execution_start
last_execution_end

EXECUTION_STATISTICS:
---------------------
duration
start_time
end_time
status
status_description
created_time
project_lsn
', 0, 0) WITH NOWAIT;

    RETURN;
END

/*   End of HELP   */
        

/*======================   PROCESSING  of Folders, projects and packages  s====================*/

--Get Folders
SET @xml = N'<i>' + REPLACE(@folder, N',', '</i><i>') + N'</i>';
WITH FolderNames AS (
    SELECT DISTINCT
        NULLIF(LTRIM(RTRIM(n.value('.','nvarchar(128)'))), '') AS name
    FROM @xml.nodes('/i') T(n)
)
INSERT INTO #folders(folder_id, folder_name)
SELECT DISTINCT
    f.folder_id
    ,f.name
FROM internal.folders f
INNER JOIN FolderNames fn ON f.name LIKE fn.name AND LEFT(fn.name, 1) <> N'-'
EXCEPT
SELECT DISTINCT
    f.folder_id
    ,f.name
FROM internal.folders f
INNER JOIN FolderNames fn ON f.name LIKE RIGHT(fn.name, LEN(fn.name) - 1) AND LEFT(fn.name, 1) = N'-'

--Get Projects
SET @xml = N'<i>' + REPLACE(@project, N',', '</i><i>') + N'</i>';
WITH ProjectNames AS (
    SELECT DISTINCT
        NULLIF(LTRIM(RTRIM(n.value('.','nvarchar(128)'))), '') AS name
    FROM @xml.nodes('/i') T(n)
)
INSERT INTO #projects(project_id, project_name, folder_name)
SELECT DISTINCT
    p.project_id
    ,p.name
    ,fn.folder_name
FROM internal.projects p
INNER JOIN #folders fn ON p.folder_id = fn.folder_id
INNER JOIN ProjectNames pn ON p.name LIKE pn.name AND LEFT(pn.name, 1) <> N'-'
EXCEPT
SELECT DISTINCT
    p.project_id
    ,p.name
    ,fn.folder_name
FROM internal.projects p
INNER JOIN #folders fn ON p.folder_id = fn.folder_id
INNER JOIN ProjectNames pn ON p.name LIKE RIGHT(pn.name, LEN(pn.name) - 1) AND LEFT(pn.name, 1) = N'-'


--Get Packages
SET @xml = N'<i>' + REPLACE(@package, N',', '</i><i>') + N'</i>';
WITH PackageNames AS (
    SELECT DISTINCT
        NULLIF(LTRIM(RTRIM(n.value('.','nvarchar(250)'))), '') AS name
    FROM @xml.nodes('/i') T(n)
)
INSERT INTO #packages(folder_name, project_name, package_name)
SELECT DISTINCT
        prj.folder_name
    ,prj.project_name
    ,p.name
FROM internal.packages p
INNER JOIN #projects prj ON prj.project_id = p.project_id
INNER JOIN PackageNames pn ON p.name LIKE pn.name AND LEFT(pn.name, 1) <> N'-'
EXCEPT
SELECT DISTINCT
        prj.folder_name
    ,prj.project_name
    ,p.name
FROM internal.packages p
INNER JOIN #projects prj ON prj.project_id = p.project_id
INNER JOIN PackageNames pn ON p.name LIKE RIGHT(pn.name, LEN(pn.name) - 1) AND LEFT(pn.name, 1) = N'-';

IF @processLastStatus = 1
BEGIN
    WITH CoreData AS (            
        SELECT
            p.folder_name
            ,p.project_name
            ,p.package_name
            ,o.status
            ,ROW_NUMBER() OVER(PARTITION BY p.folder_name, p.project_name, p.package_name ORDER BY 
                CASE
                    WHEN @useStartTime = 1 THEN o.start_time
                    WHEN @useEndTime = 1 THEN o.end_time
                    WHEN @useCreateTime = 1 THEN o.created_time
                    ELSE o.start_time
                END DESC) AS [operation_no]
        FROM internal.operations o WITH(NOLOCK)
        INNER JOIN internal.executions e WITH(NOLOCK) ON e.execution_id = o.operation_id
        INNER JOIN #packages p ON p.folder_name = e.folder_name AND p.project_name = e.project_name AND p.package_name = e.package_name
        WHERE
            o.operation_type = 200
            AND
            o.start_time >= @minDateTZ
            AND
            (o.end_time < @maxDateTZ OR @maxDateTZ IS NULL)
    ), CorePackages AS (
        SELECT
            cd.folder_name
            ,cd.project_name
            ,cd.package_name
        FROM CoreData cd
        INNER JOIN #lastStatuses ls ON ls.id = cd.status
        WHERE operation_no = 1
    )
    DELETE p
    FROM #packages p
    LEFT JOIN CorePackages cp ON p.folder_name = cp.folder_name AND p.project_name = cp.project_name AND p.package_name = cp.package_name
    WHERE cp.package_name IS NULL;
END;

/* ************************************************************************************************************
                                        STATISTICS RETRIEVAL
*************************************************************************************************************** */

--General Statistics
IF EXISTS(SELECT 1 FROM @opVal WHERE Val = 'GS')
BEGIN
    DECLARE @genStatNamesList NVARCHAR(max)
    RAISERROR(N'', 0, 0) WITH NOWAIT;
    RAISERROR(N'Retrieving General Statistics', 0, 0) WITH NOWAIT;    

    SET @genStatNamesList = (
        SELECT
            N', ' + sn.statistic_name
        FROM @generalStatNames sn
        ORDER BY sort_order
        FOR XML PATH(N'')
    )

    SET @msg = STUFF(@genStatNamesList, 1, 2, N'')

    RAISERROR(N'   - General Statistics: %s', 0, 0, @msg) WITH NOWAIT;

SET @sql = N'
    WITH CoreData AS (
        SELECT
            o.operation_id
            ,p.folder_name
            ,p.project_name
            ,p.package_name
            ,o.start_time
            ,o.end_time
            ,o.status
            ,e.project_lsn
            ,CONVERT(bigint, DATEDIFF(MILLISECOND, DATEADD(DAY, DATEDIFF(day, start_time, ISNULL(end_time, SYSDATETIMEOFFSET())), start_time), ISNULL(end_time, SYSDATETIMEOFFSET())))
             + CONVERT(bigint, DATEDIFF(day, start_time, ISNULL(end_time, SYSDATETIMEOFFSET()))) * 86400000 AS duration_ms
            ,DATEADD(MILLISECOND, DATEDIFF(MILLISECOND, DATEADD(DAY, DATEDIFF(day, start_time, ISNULL(end_time, SYSDATETIMEOFFSET())), start_time), ISNULL(end_time, SYSDATETIMEOFFSET())), DATEADD(DAY, DATEDIFF(day, start_time, ISNULL(end_time, SYSDATETIMEOFFSET())), CONVERT(datetime2(7), ''19000101''))) durationDate
        FROM internal.operations o WITH(NOLOCK)
        INNER JOIN internal.executions e WITH(NOLOCK) ON e.execution_id = o.operation_id
        INNER JOIN #packages p ON p.folder_name = e.folder_name AND p.project_name = e.project_name AND p.package_name = e.package_name'
        + CASE 
            WHEN @status IS NOT NULL THEN N'        INNER JOIN #statuses s ON s.id = o.status'
            ELSE N''
        END +
N'        WHERE
            o.operation_type = 200
            AND
            (o.start_time >= @minDateTZ OR @minDateTZ IS NULL)
            AND
            (o.end_time < @maxDateTZ OR @maxDateTZ IS NULL)
            AND
            (@minOpID IS NULL OR o.operation_id >= @minOpID)
            AND
            (@maxOpID IS NULL OR o.operation_id <= @maxOpID)
    ), AGGData AS (
    SELECT
         d.folder_name
        ,d.project_name
        ,d.package_name
        ,COUNT(1)                       AS executions_count
        ,COUNT(DISTINCT project_lsn)    AS executed_versions
        ,MIN(CASE WHEN d.status = 7 THEN duration_ms ELSE NULL END)           AS min_success_duration_ms
        ,MAX(CASE WHEN d.status = 7 THEN duration_ms ELSE NULL END)           AS max_success_duration_ms
        ,AVG(CASE WHEN d.status = 7 THEN duration_ms ELSE NULL END)           AS avg_success_duration_ms
        ,MAX(duration_ms)                                                     AS max_duration_ms

        ,SUM(CASE WHEN d.status = 1 THEN 1 ELSE 0 END)  AS status_created
        ,SUM(CASE WHEN d.status = 2 THEN 1 ELSE 0 END)  AS status_running
        ,SUM(CASE WHEN d.status = 3 THEN 1 ELSE 0 END)  AS status_cancelled
        ,SUM(CASE WHEN d.status = 4 THEN 1 ELSE 0 END)  AS status_failed
        ,SUM(CASE WHEN d.status = 5 THEN 1 ELSE 0 END)  AS status_pending
        ,SUM(CASE WHEN d.status = 6 THEN 1 ELSE 0 END)  AS status_ended_unexpectedly
        ,SUM(CASE WHEN d.status = 7 THEN 1 ELSE 0 END)  AS status_succeeded
        ,SUM(CASE WHEN d.status = 8 THEN 1 ELSE 0 END)  AS status_stopping
        ,SUM(CASE WHEN d.status = 9 THEN 1 ELSE 0 END)  AS status_completed

        ,MIN(d.start_time)          AS first_execution_start
        ,MAX(d.start_time)          AS last_execution_start
        ,MAX(d.end_time)            AS last_execution_end
    FROM CoreData d 
    WHERE
        @durationCondition@
    GROUP BY
            d.folder_name
        ,d.project_name
        ,d.package_name
    ), AGGResult AS (
        SELECT
             d.folder_name
            ,d.project_name
            ,d.package_name
            ,d.executions_count
            ,status_succeeded   AS success_count
            ,status_failed      as failed_count

            ,RIGHT(N''     '' + CONVERT(nvarchar(10), avg_success_duration_ms / 86400000) + ''d '', 5)
            + CONVERT(nvarchar(12), CONVERT(time, DATEADD(MILLISECOND,  avg_success_duration_ms % 86400000, ''19000101'')))   AS avg_success_duration
            ,RIGHT(N''     '' + CONVERT(nvarchar(10), min_success_duration_ms / 86400000) + ''d '', 5)
            + CONVERT(nvarchar(12), CONVERT(time, DATEADD(MILLISECOND,  min_success_duration_ms % 86400000, ''19000101'')))   AS min_success_duration
            ,RIGHT(N''     '' + CONVERT(nvarchar(10), max_success_duration_ms / 86400000) + ''d '', 5)
            + CONVERT(nvarchar(12), CONVERT(time, DATEADD(MILLISECOND,  max_success_duration_ms % 86400000, ''19000101'')))   AS max_success_duration
            ,RIGHT(N''     '' + CONVERT(nvarchar(10), max_duration_ms / 86400000) + ''d '', 5)
            + CONVERT(nvarchar(12), CONVERT(time, DATEADD(MILLISECOND,  max_duration_ms % 86400000, ''19000101'')))           AS max_duration

            ,avg_success_duration_ms
            ,min_success_duration_ms
            ,max_success_duration_ms
            ,max_duration_ms

            ,d.first_execution_start
            ,d.last_execution_start
            ,d.last_execution_end
            ,d.executed_versions
            ,(
                SELECT
                    CASE WHEN status_created = 0 THEN NULL ELSE (SELECT ''created'' ''@name'', status_created ''@count'' FOR XML PATH(''status''), TYPE) END
                    ,CASE WHEN status_running = 0 THEN NULL ELSE (SELECT ''running'' ''@name'', status_running ''@count'' FOR XML PATH(''status''), TYPE) END
                    ,CASE WHEN status_cancelled = 0 THEN NULL ELSE (SELECT ''cancelled'' ''@name'', status_cancelled ''@count'' FOR XML PATH(''status''), TYPE) END
                    ,CASE WHEN status_failed = 0 THEN NULL ELSE (SELECT ''failed'' ''@name'', status_failed ''@count'' FOR XML PATH(''status''), TYPE) END
                    ,CASE WHEN status_pending = 0 THEN NULL ELSE (SELECT ''pending'' ''@name'', status_pending ''@count'' FOR XML PATH(''status''), TYPE) END
                    ,CASE WHEN status_ended_unexpectedly = 0 THEN NULL ELSE (SELECT ''ended unexceptedly'' ''@name'', status_ended_unexpectedly ''@count'' FOR XML PATH(''status''), TYPE) END
                    ,CASE WHEN status_succeeded = 0 THEN NULL ELSE (SELECT ''success'' ''@name'', status_succeeded ''@count'' FOR XML PATH(''status''), TYPE) END
                    ,CASE WHEN status_stopping = 0 THEN NULL ELSE (SELECT ''stopping'' ''@name'', status_stopping ''@count'' FOR XML PATH(''status''), TYPE) END
                    ,CASE WHEN status_completed = 0 THEN NULL ELSE (SELECT ''completed'' ''@name'', status_completed ''@count'' FOR XML PATH(''status''), TYPE) END
                FOR XML PATH(''''), ROOT(''counts_by_exec_status''), TYPE
            )   AS counts_by_exec_status
        FROM AGGData d
    )
    SELECT
        folder_name
        ,project_name
        ,package_name '

    + @genStatNamesList +
 N'
    FROM AGGResult 
    ORDER BY folder_name, project_name, package_name
'

    SET @sql = REPLACE(@sql, N'@durationCondition@', @durationCondition)

    IF @debugLevel > 3
        SELECT
            'General Statistis'     AS 'Param Table' 
            ,@sql                   AS '@sql';

    EXEC sp_executesql @sql, N'@minDateTZ datetimeoffset, @maxDateTZ datetimeoffset, @useStartTime bit, @useEndTime bit, @useCreateTime bit, @minOpID bigint, @maxOpID bigint', @minDateTZ, @maxDateTZ, @useStartTime, @useEndTime, @useCreateTime, @minOpID, @maxOpID
END

/* ************************
--Daily Statistics
*************************** */
IF EXISTS(SELECT 1 FROM @opVal WHERE Val = 'DS')
BEGIN
    RAISERROR(N'', 0, 0) WITH NOWAIT;
    RAISERROR(N'Retrieving Daily Aggregated Statistics', 0, 0) WITH NOWAIT;    

    SET @msg = STUFF((
        SELECT
            N', ' + sn.statistic_name
        FROM @dailyStatNames sn
        FOR XML PATH(N'')), 1, 2, N''
    )

    RAISERROR(N'   - Daily Statistics: %s', 0, 0, @msg) WITH NOWAIT;

    --Get unique dates for 
    WITH CoreData AS (
        SELECT
            CONVERT(date, CASE
                WHEN @useStartTime = 1 THEN o.start_time
                WHEN @useEndTime = 1 THEN o.end_time
                WHEN @useCreateTime = 1 THEN o.created_time
                ELSE o.start_time
            END) AS operation_date
        FROM internal.operations o WITH(NOLOCK)
        INNER JOIN internal.executions e WITH(NOLOCK) ON e.execution_id = o.operation_id
        INNER JOIN #packages p ON p.folder_name = e.folder_name AND p.project_name = e.project_name AND p.package_name = e.package_name
        WHERE
            o.operation_type = 200
            AND
            (o.start_time >= @minDateTZ OR @minDateTZ IS NULL)
            AND
            (o.end_time < @maxDateTZ OR @maxDateTZ IS NULL)
            AND
            (@minOpID IS NULL OR o.operation_id >= @minOpID)
            AND
            (@maxOpID IS NULL OR o.operation_id <= @maxOpID)
    )
    INSERT INTO @dates(operation_date, SortAsc, SortDesc)
    SELECT
        operation_date
        ,ROW_NUMBER() OVER(ORDER BY operation_date ASC) AS SortAsc
        ,ROW_NUMBER() OVER(ORDER BY operation_date DESC) AS SortDesc
    FROM CoreData
    GROUP BY operation_date

    SELECT
        @dateList = STUFF((
        SELECT
            N',[' + CONVERT(nchar(10), operation_date, 120) + N']'
        FROM @dates
        ORDER BY operation_date DESC
        FOR XML PATH(N'')), 1, 1, '')
        ,@dateColList = ''

    --Build statistic names list
    SELECT
        @statnameList = STUFF((
        SELECT
            N',[' + statistic_name +  N']'
        FROM @dailyStatNames
        FOR XML PATH(N'')
        ), 1, 1, '')

--@dateColList = @dateColList + 
    SET @dateColList = REPLACE(CONVERT(nvarchar(max), (
    SELECT        
        N',
        CASE 
            WHEN [Statistics] IN ( ''min_success_duration'', ''max_success_duration'',''avg_success_duration'',''max_duration'') THEN
                RIGHT(N''     '' + CONVERT(nvarchar(10), ' + N'[' + CONVERT(nchar(10), operation_date, 120) + N']'+ N' / 86400000) + ''d '', 5)
                    + CONVERT(nvarchar(12), CONVERT(time, DATEADD(MILLISECOND,  ' + N'[' + CONVERT(nchar(10), operation_date, 120) + N']'+ N' % 86400000, ''19000101'')))
            WHEN [Statistics] IN ( ''first_execution_start'', ''last_execution_start'',''last_end_time'') THEN 
                CONVERT(nvarchar(50), DATEADD(MILLISECOND, ' + N'[' + CONVERT(nchar(10), operation_date, 120) + N'] % 86400000, DATEADD(DAY, ' +  N'[' + CONVERT(nchar(10), operation_date, 120) + N'] / 86400000, ''19000101'')), 121)
            ELSE
            CONVERT(nvarchar(50), ' + N'[' + CONVERT(nchar(10), operation_date, 120) + N'])
        END   AS ' + + N'[' + CONVERT(nchar(10), operation_date, 120) + N']'
    FROM @dates d
    ORDER BY CASE WHEN @useTimeDescending = 1 THEN d.SortDesc ELSE d.SortAsc END ASC
    FOR XML PATH(''), TYPE
    )), N'&#x0D;', N'')


SET @sql = REPLACE(REPLACE(REPLACE(N'SET ANSI_WARNINGS OFF;
    WITH CoreData AS (
        SELECT
            o.operation_id
            ,p.folder_name
            ,p.project_name
            ,p.package_name
            ,o.start_time
            ,o.end_time
            ,CONVERT(date, 
                CASE
                    WHEN @useStartTime = 1 THEN o.start_time
                    WHEN @useEndTime = 1 THEN o.end_time
                    WHEN @useCreateTime = 1 THEN o.created_time
                    ELSE o.start_time
                END
                ) AS operation_date
            ,o.status
            ,e.project_lsn
            ,CONVERT(bigint, DATEDIFF(MILLISECOND, DATEADD(DAY, DATEDIFF(day, start_time, ISNULL(end_time, SYSDATETIMEOFFSET())), start_time), ISNULL(end_time, SYSDATETIMEOFFSET())))
            + CONVERT(bigint, DATEDIFF(day, start_time, ISNULL(end_time, SYSDATETIMEOFFSET()))) * 86400000 AS duration_ms

            ,CONVERT(bigint, DATEDIFF(MILLISECOND, DATEADD(DAY, DATEDIFF(day, TODATETIMEOFFSET(''19000101'', DATEPART(TZ, start_time)), ISNULL(start_time, SYSDATETIMEOFFSET())), TODATETIMEOFFSET(''19000101'', DATEPART(TZ, start_time))), ISNULL(start_time, SYSDATETIMEOFFSET())))
            + CONVERT(bigint, DATEDIFF(day, TODATETIMEOFFSET(''19000101'', DATEPART(TZ, start_time)), ISNULL(start_time, SYSDATETIMEOFFSET()))) * 86400000 AS start_time_ms

            ,CONVERT(bigint, DATEDIFF(MILLISECOND, DATEADD(DAY, DATEDIFF(day, TODATETIMEOFFSET(''19000101'', DATEPART(TZ, start_time)), ISNULL(end_time, SYSDATETIMEOFFSET())), TODATETIMEOFFSET(''19000101'', DATEPART(TZ, start_time))), ISNULL(end_time, SYSDATETIMEOFFSET())))
            + CONVERT(bigint, DATEDIFF(day, TODATETIMEOFFSET(''19000101'', DATEPART(TZ, start_time)), ISNULL(end_time, SYSDATETIMEOFFSET()))) * 86400000 AS end_time_ms
            ,DATEADD(MILLISECOND, DATEDIFF(MILLISECOND, DATEADD(DAY, DATEDIFF(day, start_time, ISNULL(end_time, SYSDATETIMEOFFSET())), start_time), ISNULL(end_time, SYSDATETIMEOFFSET())), DATEADD(DAY, DATEDIFF(day, start_time, ISNULL(end_time, SYSDATETIMEOFFSET())), CONVERT(datetime2(7), ''19000101''))) durationDate
        FROM internal.operations o WITH(NOLOCK)
        INNER JOIN internal.executions e WITH(NOLOCK) ON e.execution_id = o.operation_id
        INNER JOIN #packages p ON p.folder_name = e.folder_name AND p.project_name = e.project_name AND p.package_name = e.package_name'
        + CASE 
            WHEN @status IS NOT NULL THEN N'        INNER JOIN #statuses s ON s.id = o.status'
            ELSE N''
        END +
N'
        WHERE
            o.operation_type = 200
            AND
            (o.start_time >= @minDateTZ OR @minDateTZ IS NULL)
            AND
            (o.end_time < @maxDateTZ OR @maxDateTZ IS NULL)
            AND
            (@minOpID IS NULL OR o.operation_id >= @minOpID)
            AND
            (@maxOpID IS NULL OR o.operation_id <= @maxOpID)
    ), AGGData AS (
    SELECT
         d.folder_name
        ,d.project_name
        ,d.package_name
        ,d.operation_date
        ,COUNT_BIG(1)                                                       AS executions_count
        ,COUNT_BIG(DISTINCT project_lsn)                                    AS executed_versions
        ,MIN(CASE WHEN d.status = 7 THEN duration_ms ELSE NULL END)         AS min_success_duration
        ,MAX(CASE WHEN d.status = 7 THEN duration_ms ELSE NULL END)         AS max_success_duration
        ,AVG(CASE WHEN d.status = 7 THEN duration_ms ELSE NULL END)         AS avg_success_duration
        ,MAX(duration_ms)                                                   AS max_duration

        ,MIN(CASE WHEN d.status = 7 THEN duration_ms ELSE NULL END)         AS min_success_duration_ms
        ,MAX(CASE WHEN d.status = 7 THEN duration_ms ELSE NULL END)         AS max_success_duration_ms
        ,AVG(CASE WHEN d.status = 7 THEN duration_ms ELSE NULL END)         AS avg_success_duration_ms
        ,MAX(duration_ms)                                                   AS max_duration_ms

        ,CONVERT(bigint, SUM(CASE WHEN d.status = 1 THEN 1 ELSE 0 END))     AS status_created
        ,CONVERT(bigint, SUM(CASE WHEN d.status = 2 THEN 1 ELSE 0 END))     AS status_running
        ,CONVERT(bigint, SUM(CASE WHEN d.status = 3 THEN 1 ELSE 0 END))     AS status_cancelled
        ,CONVERT(bigint, SUM(CASE WHEN d.status = 4 THEN 1 ELSE 0 END))     AS status_failed
        ,CONVERT(bigint, SUM(CASE WHEN d.status = 5 THEN 1 ELSE 0 END))     AS status_pending
        ,CONVERT(bigint, SUM(CASE WHEN d.status = 6 THEN 1 ELSE 0 END))     AS status_ended_unexpectedly
        ,CONVERT(bigint, SUM(CASE WHEN d.status = 7 THEN 1 ELSE 0 END))     AS status_succeeded
        ,CONVERT(bigint, SUM(CASE WHEN d.status = 8 THEN 1 ELSE 0 END))     AS status_stopping
        ,CONVERT(bigint, SUM(CASE WHEN d.status = 9 THEN 1 ELSE 0 END))     AS status_completed

        ,MIN(d.start_time_ms)                                               AS first_execution_start
        ,MAX(d.start_time_ms)                                               AS last_execution_start
        ,MAX(d.end_time_ms)                                                 AS last_execution_end
    FROM CoreData d 
    WHERE
        @durationCondition@
    GROUP BY
         d.folder_name
        ,d.project_name
        ,d.package_name
        ,d.operation_date
    ), UnpivotData AS (
        SELECT 
            folder_name
            ,project_name
            ,package_name
            ,CONVERT(nchar(10), operation_date, 120) AS operation_date
            ,[Statistics]
            ,CASE [Statistics] 
                WHEN N''min_success_duration''        THEN 0
                WHEN N''max_success_duration''        THEN 1
                WHEN N''avg_success_duration''        THEN 2
                WHEN N''max_duration''                THEN 3
                WHEN N''min_success_duration_ms''     THEN 4
                WHEN N''max_success_duration_ms''     THEN 5
                WHEN N''avg_success_duration_ms''     THEN 6
                WHEN N''max_duration_ms''             THEN 7
                WHEN N''executions_count''            THEN 8
                WHEN N''status_succeeded''            THEN 9
                WHEN N''status_failed''               THEN 10
                WHEN N''status_ended_unexpectedly''   THEN 11
                WHEN N''status_cancelled''            THEN 12
                WHEN N''status_created''              THEN 13
                WHEN N''status_running''              THEN 14
                WHEN N''status_pending''              THEN 15
                WHEN N''status_stopping''             THEN 16
                WHEN N''status_completed''            THEN 17
                WHEN N''executed_versions''           THEN 18
                WHEN N''first_execution_start''       THEN 19
                WHEN N''last_execution_start''        THEN 20
                WHEN N''last_execution_end''          THEN 21
            END AS StatisticsOrder

            ,ISNULL(Value, 0)   AS Value
        FROM AGGData
        UNPIVOT
            (
                Value FOR [Statistics] IN (@statNameList@)
            ) AS unpvt
    )
    SELECT
        folder_name
        ,project_name
        ,package_name
        ,[Statistics]
        @dateColList@
    FROM (SELECT * FROM UnpivotData WHERE Value <> CONVERT(bigint, 0) AND Value IS NOT NULL) AS data
    PIVOT (
        SUM(Value)
        FOR [operation_date] IN (@dateList@)
    ) AS pvt
    ORDER BY folder_name, project_name, package_name, StatisticsOrder
', N'@dateList@', @dateList), N'@dateColList@', @dateColList), N'@statNameList@', @statnameList)

    SET @sql = REPLACE(@sql, N'@durationCondition@', @durationCondition)

    IF @debugLevel > 3
        SELECT
            'DailyStatistis'        AS 'Param Table' 
            ,@dateList              AS '@dateList'
            ,@dateColList           AS '@dateColList'
            ,@statnameList          AS '@statnameList'
            ,@sql                   AS '@sql';

    
    EXEC sp_executesql @sql, N'@minDateTZ datetimeoffset, @maxDateTZ datetimeoffset, @useStartTime bit, @useEndTime bit, @useCreateTime bit, @minOpID bigint, @maxOpID bigint', @minDateTZ, @maxDateTZ, @useStartTime, @useEndTime, @useCreateTime, @minOpID, @maxOpID
END


/*  **********************************************
               EXECUTION STATISTICS
************************************************** */
IF EXISTS(SELECT 1 FROM @opVal WHERE Val = 'ES')
BEGIN
    RAISERROR(N'', 0, 0) WITH NOWAIT;
    RAISERROR(N'Retrieving Execution Statistics for Operations', 0, 0) WITH NOWAIT;
    
    SET @msg = STUFF((
        SELECT
            N', ' + sn.statistic_name
        FROM @execStatNames sn
        FOR XML PATH(N'')), 1, 2, N''
    )

    RAISERROR(N'   - Execution Statistics: %s', 0, 0, @msg) WITH NOWAIT;


    SET @lastOperations = NULLIF((SELECT MaxIntVal FROM @opVal WHERE Val = 'ES'), 0);

    IF @lastOperations IS NULL OR @lastOperations <= 0
    BEGIN
        SET @lastOperations = 100

        RAISERROR(N'   - Retrieving operations per package: DEFAULT last %d ', 0, 0, @lastOperations) WITH NOWAIT;
    END
    ELSE
    BEGIN
        RAISERROR(N'   - Retrieving operations per package: last %d ', 0, 0, @lastOperations) WITH NOWAIT;
    END

    IF OBJECT_ID(N'tempdb..#operations') IS NOT NULL
        DROP TABLE #operations;
    CREATE TABLE #operations (op int NOT NULL PRIMARY KEY CLUSTERED);

    DECLARE
        @opList             nvarchar(max)
        ,@opColList         nvarchar(max);

SET @sql = N'
    WITH CoreData AS (
        SELECT
             p.folder_name
            ,p.project_name
            ,p.package_name
            ,DATEADD(MILLISECOND, DATEDIFF(MILLISECOND, DATEADD(DAY, DATEDIFF(day, start_time, ISNULL(end_time, SYSDATETIMEOFFSET())), start_time), ISNULL(end_time, SYSDATETIMEOFFSET())), DATEADD(DAY, DATEDIFF(day, start_time, ISNULL(end_time, SYSDATETIMEOFFSET())), CONVERT(datetime2(7), ''19000101''))) durationDate
        FROM internal.operations o WITH(NOLOCK)
        INNER JOIN internal.executions e WITH(NOLOCK) ON e.execution_id = o.operation_id
        INNER JOIN #packages p ON p.folder_name = e.folder_name AND p.project_name = e.project_name AND p.package_name = e.package_name
        WHERE
            o.operation_type = 200
            AND
            (o.start_time >= @minDateTZ OR @minDateTZ IS NULL)
            AND
            (o.end_time < @maxDateTZ OR @maxDateTZ IS NULL)
            AND
            (@minOpID IS NULL OR o.operation_id >= @minOpID)
            AND
            (@maxOpID IS NULL OR o.operation_id <= @maxOpID)
    ), BaseData AS (
        SELECT
            ROW_NUMBER() OVER(PARTITION BY folder_name, project_name, package_name ORDER BY (SELECT NULL)) AS [operation_no]
        FROM CoreData
        WHERE
            @durationCondition@
    )
    INSERT INTO #operations(op)
    SELECT
        [operation_no]
    FROM BaseData
    WHERE [operation_no] <= @lastOperations
    GROUP BY [operation_no]'

    SET @sql = REPLACE(@sql, N'@durationCondition@', @durationCondition)

    EXEC sp_executesql @sql, N'@minDateTZ datetimeoffset, @maxDateTZ datetimeoffset, @lastOperations int, @minOpID bigint, @maxOpID bigint', @minDateTZ, @maxDateTZ, @lastOperations, @minOpID, @maxOpID

    SELECT 
        @opList = STUFF((
        SELECT
            N',[' + CONVERT(nvarchar(10), op) + N']'
        FROM #operations
        FOR XML PATH(N'')
    ), 1, 1, N'')
    ,@opColList = N'';

    SELECT
        @opColList = @opColList + 
        N',
        CASE 
            WHEN [Statistics] IN ( ''duration'') THEN
                RIGHT(N''     '' + CONVERT(nvarchar(10), ' + N'[' + CONVERT(nvarchar(10), op, 120) + N']'+ N' / 86400000) + ''d '', 5)
                    + CONVERT(nvarchar(12), CONVERT(time, DATEADD(MILLISECOND,  ' + N'[' + CONVERT(nvarchar(10), op, 120) + N']'+ N' % 86400000, ''19000101'')))
            WHEN [Statistics] IN ( ''start_time'', ''end_time'',''created_time'') THEN 
                CONVERT(nvarchar(50), DATEADD(MILLISECOND, ' + N'[' + CONVERT(nvarchar(10), op, 120) + N'] % 86400000, DATEADD(DAY, ' +  N'[' + CONVERT(nvarchar(10), op, 120) + N'] / 86400000, ''19000101'')), 121)
            WHEN [Statistics] IN (''status_description'') THEN
                CASE ' + N'[' + CONVERT(nvarchar(10), op, 120) + N']
                    WHEN 1 THEN ''created''
                    WHEN 2 THEN ''running''
                    WHEN 3 THEN ''cancelled''
                    WHEN 4 THEN ''failed''
                    WHEN 5 THEN ''pending''
                    WHEN 6 THEN ''ended_unexpectedly''
                    WHEN 7 THEN ''succeeded''
                    WHEN 8 THEN ''stopping''
                    WHEN 9 THEN ''completed''
                END
            ELSE
            CONVERT(nvarchar(50), ' + N'[' + CONVERT(nvarchar(10), op, 120) + N'])
        END   AS ' + + N'[' + CONVERT(nvarchar(10), op, 120) + N']'
    FROM #operations
    ORDER BY op;

    --Build statistic names list
    SELECT
        @statnameList = STUFF((
        SELECT
            N',[' + statistic_name +  N']'
        FROM @execStatNames
        FOR XML PATH(N'')
        ), 1, 1, '')


SET @sql = REPLACE(REPLACE(REPLACE(CONVERT(nvarchar(max), N'
    WITH CoreData AS (
        SELECT
            o.operation_id
            ,p.folder_name
            ,p.project_name
            ,p.package_name
            ,CONVERT(bigint, o.status) AS status
            ,CONVERT(bigint, o.status) AS status_description
            ,e.project_lsn AS project_lsn
            ,CONVERT(bigint, DATEDIFF(MILLISECOND, DATEADD(DAY, DATEDIFF(day, start_time, ISNULL(end_time, SYSDATETIMEOFFSET())), start_time), ISNULL(end_time, SYSDATETIMEOFFSET())))
            + CONVERT(bigint, DATEDIFF(day, start_time, ISNULL(end_time, SYSDATETIMEOFFSET()))) * 86400000 AS duration

            ,CONVERT(bigint, DATEDIFF(MILLISECOND, DATEADD(DAY, DATEDIFF(day, TODATETIMEOFFSET(''19000101'', DATEPART(TZ, created_time)), ISNULL(created_time, SYSDATETIMEOFFSET())), TODATETIMEOFFSET(''19000101'', DATEPART(TZ, created_time))), ISNULL(created_time, SYSDATETIMEOFFSET())))
            + CONVERT(bigint, DATEDIFF(day, TODATETIMEOFFSET(''19000101'', DATEPART(TZ, created_time)), ISNULL(created_time, SYSDATETIMEOFFSET()))) * 86400000 AS created_time

            ,CONVERT(bigint, DATEDIFF(MILLISECOND, DATEADD(DAY, DATEDIFF(day, TODATETIMEOFFSET(''19000101'', DATEPART(TZ, created_time)), start_time), TODATETIMEOFFSET(''19000101'', DATEPART(TZ, created_time))), start_time))
            + CONVERT(bigint, DATEDIFF(day, TODATETIMEOFFSET(''19000101'', DATEPART(TZ, created_time)), start_time)) * 86400000 AS start_time

            ,CONVERT(bigint, DATEDIFF(MILLISECOND, DATEADD(DAY, DATEDIFF(day, TODATETIMEOFFSET(''19000101'', DATEPART(TZ, created_time)), end_time), TODATETIMEOFFSET(''19000101'', DATEPART(TZ, created_time))), end_time))
            + CONVERT(bigint, DATEDIFF(day, TODATETIMEOFFSET(''19000101'', DATEPART(TZ, created_time)), end_time)) * 86400000 AS end_time
            ,DATEADD(MILLISECOND, DATEDIFF(MILLISECOND, DATEADD(DAY, DATEDIFF(day, start_time, ISNULL(end_time, SYSDATETIMEOFFSET())), start_time), ISNULL(end_time, SYSDATETIMEOFFSET())), DATEADD(DAY, DATEDIFF(day, start_time, ISNULL(end_time, SYSDATETIMEOFFSET())), CONVERT(datetime2(7), ''19000101''))) durationDate
        FROM internal.operations o WITH(NOLOCK)
        INNER JOIN internal.executions e WITH(NOLOCK) ON e.execution_id = o.operation_id
        INNER JOIN #packages p ON p.folder_name = e.folder_name AND p.project_name = e.project_name AND p.package_name = e.package_name'
        + CONVERT(nvarchar(max), CASE 
            WHEN @status IS NOT NULL THEN N'        INNER JOIN #statuses s ON s.id = o.status'
            ELSE N''
        END )+
CONVERT(nvarchar(max), N'
        WHERE
            o.operation_type = 200
            AND
            (o.start_time >= @minDateTZ OR @minDateTZ IS NULL)
            AND
            (o.end_time < @maxDateTZ OR @maxDateTZ IS NULL)
            AND
            (@minOpID IS NULL OR o.operation_id >= @minOpID)
            AND
            (@maxOpID IS NULL OR o.operation_id <= @maxOpID)
    ), BaseData AS (
        SELECT
             folder_name
            ,project_name
            ,package_name
            ,status
            ,status_description
            ,project_lsn
            ,duration
            ,created_time
            ,start_time
            ,end_time
            ,CONVERT(bigint, ROW_NUMBER() OVER(PARTITION BY folder_name, project_name, package_name ORDER BY                 CASE
                    WHEN @useStartTime = 1 THEN start_time
                    WHEN @useEndTime = 1 THEN end_time
                    WHEN @useCreateTime = 1 THEN created_time
                    ELSE start_time
                END ' + CASE WHEN @useTimeDescending = 1 THEN N'DESC' ELSE N'ASC' END + N')) AS [operation_no]
        FROM CoreData d
        WHERE
            @durationCondition@
    ), UnpivotData AS (
        SELECT 
            folder_name
            ,project_name
            ,package_name
            ,operation_no
            ,[Statistics]
            ,[Value]
            ,CASE [Statistics] 
                WHEN N''duration''            THEN 0
                WHEN N''duration_ms''         THEN 1
                WHEN N''status''              THEN 2
                WHEN N''status_description''  THEN 3
                WHEN N''start_time''          THEN 4
                WHEN N''end_time''            THEN 5
                WHEN N''created_time''        THEN 6
                WHEN N''project_lsn''         THEN 7
            END AS StatisticsOrder

        FROM (SELECT *, duration duration_ms FROM BaseData WHERE [operation_no] <= @lastOperations) AS bd
        UNPIVOT
            (
                Value FOR [Statistics] IN ( @statnameList@ )
            ) AS unpvt
    )
    SELECT
        folder_name
        ,project_name
        ,package_name
        ,[Statistics]
        @opColList@
    FROM UnpivotData
    PIVOT (
        MIN(Value)
        FOR [operation_no] IN (@opList@)
    ) AS pvt
    ORDER BY folder_name, project_name, package_name, StatisticsOrder
')), '@opList@', @opList), '@opColList@', @opColList), '@statnameList@', @statnameList)

    SET @sql = REPLACE(@sql, N'@durationCondition@', @durationCondition)

    IF @debugLevel > 3
        SELECT
            'Execution Statistis'   AS 'Param Table' 
            ,@lastOperations        AS '@lastOperations'
            ,@opList                AS '@opList'
            ,@opColList             AS '@opColList'
            ,@statnameList          AS '@statnameList'
            ,@sql                   AS '@sql';

    EXEC sp_executesql @sql, N'@minDateTZ datetimeoffset, @maxDateTZ datetimeoffset, @useStartTime bit, @useEndTime bit, @useCreateTime bit, @lastOperations int, @minOpID bigint, @maxOpID bigint', @minDateTZ, @maxDateTZ, @useStartTime, @useEndTime, @useCreateTime, @lastOperations, @minOpID, @maxOpID

END

GO

--GRANT EXECUTE permission on the stored procedure to [ssis_admin] role
RAISERROR(N'Granting EXECUTE permission to [sp_ssisstat]', 0, 0) WITH NOWAIT;
GRANT EXECUTE ON [dbo].[sp_ssisstat] TO [ssis_admin]
GO