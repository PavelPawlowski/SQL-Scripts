USE [SSISDB]
GO
IF NOT EXISTS(SELECT * FROM sys.procedures WHERE object_id = OBJECT_ID('[dbo].[sp_ssisdb]'))
    EXEC (N'CREATE PROCEDURE [dbo].[sp_ssisdb] AS PRINT ''Placeholder for [dbo].[sp_ssisdb]''')
GO
/* ****************************************************
sp_ssisdb v 0.41 (2017-10-11)
(C) 2017 Pavel Pawlowski

Feedback: mailto:pavel.pawlowski@hotmail.cz

License: 
    sp_ssisdb is free to download and use for personal, educational, and internal 
    corporate purposes, provided that this header is preserved. Redistribution or sale 
    of sp_ssisdb, in whole or in part, is prohibited without the author's express 
    written consent.

Description:
    Provides information about processes in SSISDB

Parameters:
     @op                    nvarchar(max)	= NULL                  --Operator parameter - universal operator for stting large range of condidiotns and filter
    ,@status                nvarchar(max)   = NULL                  --Comma separated list of execution statuses to return. Default NULL means all. See below for more details
    ,@folder                nvarchar(max)	= NULL                  --Comma separated list of folder filters. Default NLL means no filtering. See below for more details
    ,@project               nvarchar(max)   = NULL                  --Comma separated list of project filters. Default NULL means no filtering. See below for more details
    ,@package               nvarchar(max)   = NULL                  --Comma separated list of pacakge filters. Default NULL means no filtering. See below for more details
    ,@msg_type              nvarchar(max)   = NULL                  --Comma separated list of Message types to show
    ,@event_filter          nvarchar(max)   = NULL                  --Comma separated list of event LIKE filters. Used only for detailed results filtering
    ,@phase_filter          nvarchar(max)   = NULL                  --Comma separated list of phase LIKE filters. Used only for detailed results filtering
    ,@task_filter           nvarchar(max)   = NULL                  --Comma separated list of task LIKE filters. Used only for detailed results filtering
    ,@subcomponent_filter   nvarchar(max)   = NULL                  --Comma separated list of sub-component LIKE filters. Used only for detailed results filtering.
    ,@package_path          nvarchar(max)   = NULL                  --LIKE filter to be applied on package path fields. Used only for detailed results fitering
    ,@execution_path        nvarchar(max)   = NULL                  --LIKE filter to be applied on execution path fields. Used only for detailed results filtering
    ,@msg_filter            nvarchar(max)   = NULL                  --LIKE filter to be applied on messge text. Used only for detailed results filtering
 ******************************************************* */
ALTER PROCEDURE [dbo].[sp_ssisdb]
     @op                    nvarchar(max)	= NULL                  --Operator parameter - universal operator for stting large range of condidiotns and filter
    ,@status                nvarchar(max)   = NULL                  --Comma separated list of execution statuses to return. Default NULL means all. See below for more details
    ,@folder                nvarchar(max)	= NULL                  --Comma separated list of folder filters. Default NLL means no filtering. See below for more details
    ,@project               nvarchar(max)   = NULL                  --Comma separated list of project filters. Default NULL means no filtering. See below for more details
    ,@package               nvarchar(max)   = NULL                  --Comma separated list of pacakge filters. Default NULL means no filtering. See below for more details
    ,@msg_type              nvarchar(max)   = NULL                  --Comma separated list of Message types to show
    ,@event_filter          nvarchar(max)   = NULL                  --Comma separated list of event LIKE filters. Used only for detailed results filtering
    ,@phase_filter          nvarchar(max)   = NULL                  --Comma separated list of phase LIKE filters. Used only for detailed results filtering
    ,@task_filter           nvarchar(max)   = NULL                  --Comma separated list of task LIKE filters. Used only for detailed results filtering
    ,@subcomponent_filter   nvarchar(max)   = NULL                  --Comma separated list of sub-component LIKE filters. Used only for detailed results filtering.
    ,@package_path          nvarchar(max)   = NULL                  --LIKE filter to be applied on package path fields. Used only for detailed results fitering
    ,@execution_path        nvarchar(max)   = NULL                  --LIKE filter to be applied on execution path fields. Used only for detailed results filtering
    ,@msg_filter            nvarchar(max)   = NULL                  --LIKE filter to be applied on messge text. Used only for detailed results filtering
--WITH EXECUTE AS 'AllSchemaOwner'
AS
SET NOCOUNT ON;
DECLARE
	@xml						     xml
    ,@xr                                nvarchar(10)    = N'</i><i>'    --xml replacement'
    ,@defaultLastOp	                    int             = 100           --default number of rows to retrieve
    ,@msg                               nvarchar(max)                   --general purpoe message variable
    ,@sql                               nvarchar(max)                   --variable for storing queries to be executed

DECLARE
     @id                                bigint          = NULL  --for storage of execution id to provide detailed output
    ,@opLastCnt                         int             = NULL  --specifies if last count is retrieved
    ,@lastSpecified                     bit             = 0     --Indicates whether the LAST keyword was specified
    ,@opLastGrp                         CHAR(1)	      = NULL  --Specifies type of grouing for Last retrieval
    ,@opFrom                            datetime                --variable to hold initial from date/time value in @op param
    ,@opTo                              datetime                --variable to hold initial to date/time value in @op param
    ,@minInt                            bigint                  --variable to hold min integer passed in @op param
    ,@maxInt                            bigint                  --variable to hold max integer passed in @op param
    ,@opFromTZ                          datetimeoffset          --variable to hold @opFrom value convered to datetimeoffset
    ,@opToTZ                            datetimeoffset          --variable to hold @opTo value converted to datetimeofset
    ,@fldFilter                         bit             = 0     --identifies whether we have a folder filter
    ,@prjFilter                         bit             = 0     --identifies whether we have a project filer
    ,@pkgFilter                         bit             = 0     --identifies whetthe we have a package filer
    ,@msgTypeFilter                     bit             = 0     --identifies whether we have a message typefilter in place
    ,@statusFilter                      bit             = 0     --identifies whether we have a status filter
    ,@includeExecPackages               bit             = 0     --identifies whether executed packages should be included in the list.
    ,@includeMessages                   bit             = 0     --Identifies whether exclude messages in overview list
    ,@includeEDS                        bit             = 0     --Identifies whether executable data statistics should be included in detailed output
    ,@includeECP                        bit             = 0     --Identifies whether execution component phases should be included in the detailed output
    ,@projId                            bigint          = NULL  --project ID or LSN for inernal purposes
    ,@force                             bit             = 0     --Specifies whether execution should be forced even large result set should be returned
    ,@totalMaxRows                      int             = NULL
    ,@edsRows                           int             = NULL  --maximum number of EDS rows
    ,@ecpRows                           int             = NULL  --maximu number of ECP rows
    ,@max_messages                      int             = NULL  --Number of messages to include as in-row details
    ,@useStartTime                      bit             = 0     --Use Start Time for searching
    ,@useEndTime                        bit             = 0     --Use End time for searching
    ,@useTimeDescenting                 bit             = 1     --Use Descending sort
    ,@execRows                          int             = NULL  --Maximum number or Executable Statistics rows
    ,@incoludeExecutableStatistics      bit             = 0     --Indicates whetehr to include Executable Statistics in the output
    ,@help                              bit             = 0     --Indicates taht Help should be printed
    ,@phaseFilter                       bit             = 0     --Identifies whether applly phase filter
    ,@taskFilter                        bit             = 0     --Identifies whether apply task filter
    ,@eventFilter                       bit             = 0     --Identifies whether apply event filter
    ,@subcomponentFilter                bit             = 0     --Identifies whether apply sub-component filter
    ,@includeAngetReferences            bit            = 0     --Identifies whether to include Agent Job referencing packages
    ,@includeAgentJob                   bit             = 0     --Identifies whetehr to include information about agent job which executed the package

    ,@debugLevel                        smallint        = 0


RAISERROR(N'sp_ssisdb v0.41 (2017-10-11) (c) 2017 Pavel Pawlowski', 0, 0) WITH NOWAIT;
RAISERROR(N'=====================================================', 0, 0) WITH NOWAIT;
RAISERROR(N'sp_ssisdb provides information about operations in ssisdb', 0, 0) WITH NOWAIT;
RAISERROR(N'', 0, 0) WITH NOWAIT;


DECLARE @valModifiers TABLE (
    Val         nvarchar(10)
    ,Modifier   nvarchar(30)
    ,LeftChars  int
)

INSERT INTO @valModifiers(Val, Modifier, LeftChars)
VALUES
     ('L'       ,'L'                    ,1)      --Last
    ,('L'       ,'LAST'                 ,4)      --Last
    ,('FLD'     ,'FLD'                  ,NULL)      --Per Folder
    ,('FLD'     ,'FOLDER'               ,NULL)      --Per Folder
    ,('P'       ,'P'                    ,NULL)      --Per Project
    ,('P'       ,'PRJ'                  ,NULL)      --Per Project
    ,('P'       ,'PROJECT'              ,NULL)      --Per Project
    ,('E'       ,'E'                    ,NULL)      --Per Executable
    ,('E'       ,'EXE'                  ,NULL)      --Per Executable
    ,('E'       ,'EXECUTABLE'           ,NULL)      --Per Executable
    ,('EP'      ,'EP'                   ,NULL)      --Executed Packages
    ,('EP'      ,'EXECUTED_PACKAGES'    ,NULL)      --Executed Packages
    ,('R'       ,'R'                    ,NULL)      --Running
    ,('R'       ,'RUNNING'              ,NULL)      --Running
    ,('S'       ,'S'                    ,NULL)      --Success
    ,('S'       ,'SUCCESS'              ,NULL)      --Success
    ,('F'       ,'F'                    ,NULL)      --Failure
    ,('F'       ,'FAILURE'              ,NULL)      --Failure
    ,('C'       ,'C'                    ,NULL)      --Cancelled
    ,('C'       ,'CANCELLED'            ,NULL)      --Cancelled
    ,('U'       ,'U'                    ,NULL)      --Unexpected
    ,('U'       ,'UNEXPECTED'           ,NULL)      --Unexpected
    ,('FORCE'   ,'FORCE'                ,NULL)      --Force
    ,('?'       ,'?'                    ,NULL)      --Help
    ,('X'       ,'X'                    ,1)         --Max
    ,('X'       ,'MAX'                  ,3)         --Max
    ,('EM'      ,'EM'                   ,2)         --Include Event Messages
    ,('EM'      ,'EVENT_MESSAGES'       ,14)        --Include Event Messages
    ,('V'       ,'V'                    ,1)         --Verbose
    ,('V'       ,'VERBOSE'              ,7)         --Verbose
    ,('EDS'     ,'EDS'                  ,3)         --Execution data statistics in details
    ,('EDS'     ,'EXECUTION_DATA_STATISTICS', 25)   --Execution data statistics in details
    ,('ST'      ,'ST'                   ,2)         --Use Start TIme
    ,('ST'      ,'START_TIME'           ,10)        --Use Start Time
    ,('ET'      ,'ET'                   ,2)         --Use End TIme
    ,('ET'      ,'END_TIME'             ,8)         --Use EndTime
    ,('ECP'     ,'ECP'                  ,3)         --Execution Component Phases
    ,('ECP'     ,'EXECUTION_COMPONENT_PHASES', 26)  --Execution Component Phases
    ,('ES'      ,'ES'                   ,2)         --Executable Statistics
    ,('ES'      ,'EXECUTABLE_STATISTICS' , 21)      --Executable Statistics
    ,('AGR'     ,'AGR'                  ,NULL)      --Include details about SQL Server Agent Jobs referencing package
    ,('AGR'     ,'AGENT_REFERENCES'     ,NULL)      --Include details about SQL Server Agent Jobs referencing package
    ,('AGT'     ,'AGT'                  ,NULL)      --Include details about agent job which initiated the execution
    ,('AGT'     ,'AGENT_JOB'            ,NULL)      --Include details about agent job which initiated the execution

    ,('DBG','DBG', 3)    --TEMPORARY DEBUG

DECLARE @availMsgTypes TABLE (
    id      smallint        NOT NULL PRIMARY KEY CLUSTERED
    ,msg    nvarchar(50)
    ,short  varchar(2)
)

--available message types
INSERT INTO @availMsgTypes (id, msg, short)
VALUES
     (-1    ,N'UNKNOWN'                  , N'U')
    ,(120   ,N'ERROR'                    , N'E')
    ,(110   ,N'WARNING'                  , N'W')
    ,(70    ,N'INFORMATION'              , N'I')
    ,(10    ,N'PRE_VALIDATE'             , N'PV')
    ,(20    ,N'POST_VALIDATE'            , N'TV')
    ,(30    ,N'PRE_EXECUTE'              , N'PE')
    ,(40    ,N'POST_EXECUTE'             , N'TE')
    ,(60    ,N'PROGRESS'                 , N'P')
    ,(50    ,N'STATUS_CHANGE'            , N'SC')
    ,(100   ,N'QUERY_CANCEL'             , N'QC')
    ,(130   ,N'TASK_FAILED'              , N'F')
    ,(90    ,N'DIAGNOSTICS'              , N'D')
    ,(200   ,N'CUSTOM'                   , N'C')
    ,(140   ,N'DIAGNOSTICS_EX'           , N'DE')
    ,(400   ,N'NON_DIAGNOSTIS'           , N'ND')
    ,(80    ,N'VARIABLE_VALUE_CHANGE'    , N'VC')


DECLARE @availStatuses TABLE (
    id          smallint        NOT NULL
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
    ,(5, N'PENDING'     , N'P')
    ,(6, N'UNEXPECTED'  , N'U')
    ,(7, N'SUCCESS'     , N'S')
    ,(8, N'STOPPING'    , N'G')
    ,(9, N'COMPLETED'   , N'D')

/* Update paramters to NULL where empty strings are passed */
SELECT
     @status                = NULLIF(@status, N'')
    ,@folder                = NULLIF(@folder, N'')
    ,@project               = NULLIF(@project, N'')
    ,@package               = NULLIF(@package, N'')
    ,@msg_type              = NULLIF(@msg_type, N'')
    ,@event_filter          = NULLIF(@event_filter, N'')
    ,@phase_filter          = NULLIF(@phase_filter, N'')
    ,@task_filter           = NULLIF(@task_filter, N'')
    ,@subcomponent_filter   = NULLIF(@subcomponent_filter, N'')
    ,@package_path          = NULLIF(@package_path, N'')
    ,@execution_path        = NULLIF(@execution_path, N'')
    ,@msg_filter            = NULLIF(@msg_filter, N'')

    /* =================================
             OPERATION Retrival 
    ====================================*/
	SET @xml = N'<i>' + REPLACE(REPLACE(REPLACE(@op, N' ', @xr), N',', @xr), N';', @xr) + N'</i>'

	DECLARE @opVal TABLE (	--Operaton Validities
		Val			varchar(10) NOT NULL PRIMARY KEY CLUSTERED
		,MinDateVal	datetime
        ,MaxDateVal datetime
		,MinIntVal	bigint
        ,MaxIntVal  bigint
        ,StrVal  nvarchar(max)
	)

    DECLARE @opValData TABLE (
         Modifier   nvarchar(30)
        ,Val        varchar(10)
        ,DateVal    datetime
        ,IntVal     bigint
        ,StrVal     nvarchar(50)
    )

	;WITH OP AS (
        SELECT DISTINCT
            NULLIF(LTRIM(RTRIM(n.value('.','nvarchar(128)'))), '') AS Modifier
        FROM @xml.nodes('/i') T(N)
	)
    INSERT INTO @opValData(Modifier, Val, DateVal, IntVal, StrVal)
	SELECT
        OP.Modifier
        ,CASE 
            WHEN VM.Val IS NOT NULL THEN VM.Val
            WHEN TRY_CONVERT(bigint, OP.Modifier) IS NOT NULL THEN 'I'
            WHEN TRY_CONVERT(datetime, OP.Modifier) IS NOT NULL THEN 'D'
            ELSE NULL 
        END AS Val
        ,CASE 
            WHEN TRY_CONVERT(datetime, OP.Modifier) IS NOT NULL THEN
                CASE
                    WHEN CONVERT(date, CONVERT(datetime, OP.Modifier)) = '1900-01-01' THEN CONVERT(datetime, CONVERT(date, GETDATE())) + CONVERT(datetime, CONVERT(time, CONVERT(datetime, OP.Modifier)))
                    ELSE CONVERT(datetime, OP.Modifier)
                END
            ELSE NULL
            END AS DateVal
        ,CASE 
            WHEN VM.LeftChars IS NOT NULL THEN TRY_CONVERT(int, RIGHT(OP.Modifier, LEN(OP.Modifier) - VM.LeftChars))
            ELSE TRY_CONVERT(int, OP.Modifier) 
        END AS IntVal
        ,CASE 
            WHEN VM.LeftChars IS NOT NULL THEN CONVERT(nvarchar(50), RIGHT(OP.Modifier, LEN(OP.Modifier) - VM.LeftChars))
            ELSE CONVERT(nvarchar(50), OP.Modifier) 
        END AS StrVal
	FROM OP
    LEFT JOIN @valModifiers VM ON (OP.Modifier = VM.Modifier AND VM.LeftChars IS NULL) OR (LEFT(OP.Modifier, VM.LeftChars) = VM.Modifier)
    WHERE OP.Modifier IS NOT NULL

    --Check if we have a help modifier
    IF EXISTS(SELECT 1 FROM @opValData WHERE Val = '?')
        SET @help = 1            

    IF @help <> 1
    BEGIN
        RAISERROR('sp_ssisdb ''?'' --to print procedure help', 0, 0) WITH NOWAIT;
        RAISERROR('', 0, 0) WITH NOWAIT;
    END


IF @help <> 1
BEGIN
    IF EXISTS(SELECT 1 FROM @opValData WHERE Val IS NULL)
    BEGIN
        SET @msg = 'There are unsupported values, keywords or modifiers passed in the @op parameter. Check the parameters and/or formattings: ' + NCHAR(13) +
            QUOTENAME(STUFF((SELECT ', ' + op.Modifier FROM  @opValData op WHERE Val IS NULL FOR XML PATH('')), 1, 2, ''), '"') + NCHAR(13);
        RAISERROR(@msg, 11, 0) WITH NOWAIT;

        SET @help = 1
    END
END

IF @help <> 1
BEGIN
	INSERT INTO @opVal (Val,  MinDateVal, MaxDateVal, MinIntVal, MaxIntVal, StrVal)
    SELECT
        Val
        ,CASE WHEN Val = 'D' THEN MIN(ISNULL(DateVal, '1900-01-01')) ELSE NULL END AS MinDateVal
        ,CASE WHEN Val = 'D' THEN MAX(ISNULL(DateVal, '1900-01-01')) ELSE NULL END AS MaxDateVal
        ,CASE WHEN Val = 'I' THEN MIN(ISNULL(IntVal, 0)) ELSE NULL END AS MinIntVal
        ,CASE 
            WHEN Val IN ('I', 'L', 'X', 'DBG', 'EDS', 'EM', 'V','ECP', 'ES') THEN MAX(ISNULL(IntVal, 0)) 
            ELSE NULL 
         END AS MaxIntVal
        ,CASE
            WHEN Val IN ('ST', 'ET') THEN MAX(StrVal)
            ELSE NULL
        END AS StrVal
    FROM @opValData
    	WHERE Val IS NOT NULL OR DateVal IS NOT NULL OR IntVal IS NOT NULL
    GROUP BY Val

    IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'DBG')
    BEGIN
        SET @debugLevel = ISNULL(NULLIF((SELECT MaxIntVal FROM @opVal WHERE Val = N'DBG'), 0), 1)
        
        if (@debugLevel > 1)
            SELECT * FROM @opVal
    END
END

IF @help <> 1
BEGIN
        RAISERROR(N'Retrieving...', 0, 0) WITH NOWAIT;

        IF @id IS NOT NULL OR EXISTS(SELECT 1 FROM @opVal WHERE Val = 'V')
        BEGIN   /*Verbose params processing */            
            SET @id = (SELECT MaxIntVal FROM @opVal WHERE Val = 'V')
            IF @id <= 1
                SET @id = (SELECT MAX(execution_id) FROM internal.executions)

            SET @msg = N' - Verbose information for execution_id = ' + CONVERT(nvarchar(20), @id);
            RAISERROR(@msg, 0, 0) WITH NOWAIT;

            IF @id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM internal.operations WHERE operation_id = @id)
            BEGIN
                SET @msg = N'   << No Executable statistics were found for execution_id = ' + CONVERT(nvarchar(20), @id) + N' >>';
                RAISERROR(@msg, 0, 0) WITH NOWAIT;
                RETURN;
            END

            /*Get EVENT MESSAGES param */
            IF EXISTS(SELECT 1 FROM @opVal WHERE Val = 'EM')
            BEGIN
                SET @includeMessages = 1
                SET @max_messages = (SELECT MaxIntVal FROM @opVal WHERE Val = 'EM')
                IF @max_messages < 0
                    SET @max_messages = NULL
                ELSE IF @max_messages = 0
                    SET @max_messages = 1000
            END

            IF EXISTS(SELECT 1 FROM @opVal WHERE Val = 'EDS')
            BEGIN
                SET @includeEDS = 1
                SET @edsRows = (SELECT MaxIntVal FROM @opVal WHERE Val = 'EDS')

                IF @edsRows < 0 
                    SET @edsRows = NULL
                ELSE IF @edsRows = 0
                    SET @edsRows = 1000
            END

            IF EXISTS(SELECT 1 FROM @opVal WHERE Val = 'ECP')
            BEGIN
                SET @includeECP = 1;
                SET @ecpRows = (SELECT MaxIntVal FROM @opVal WHERE Val = 'ECP')

                IF @ecpRows < 0
                    SET @ecpRows = NULL
                ELSE IF @ecpRows = 0
                    SET @ecpRows = 1000
            END

            IF EXISTS(SELECT 1 FROM @opVal WHERE Val = 'ES')
            BEGIN
                SET @incoludeExecutableStatistics = 1
                SET @execRows = (SELECT MaxIntVal FROM @opVal WHERE Val = 'ES')

                IF @execRows < 0
                    SET @execRows = NULL;
                ELSE IF @execRows = 0
                    SET @execRows = 1000;

            END

        END 
        ELSE 
        BEGIN /*Non Verbose Params processing */
            --Force  status filter according the @op param
            IF EXISTS(SELECT 1 FROM @opVal WHERE Val IN ('R', 'S', 'F', 'U'))
                SET @status = STUFF((SELECT ',' + Val FROM @opVal WHERE Val IN ('R', 'S', 'F', 'U') FOR XML PATH('')), 1, 1, '');

            --Last XXX was specified
            IF EXISTS(SELECT 1 FROM @opVal WHERE Val IN ('L'))
            BEGIN
                SET @lastSpecified = 1
                SET @opLastCnt = ISNULL((SELECT MaxIntVal FROM @opVal WHERE Val = 'L'), 1)
                IF @opLastCnt IS NULL OR @opLastCnt < 0
                BEGIN
                    IF @lastSpecified = 1
                        SET @opLastCnt = NULL
                    ELSE
                        SET @opLastCnt = 1
                END
                ELSE IF @opLastCnt = 0 SET @opLastCnt = 1

                IF @opLastCnt IS NOT NULL
                    RAISERROR(N' - Last %d operations', 0, 0, @opLastCnt) WITH NOWAIT;
                ELSE
                    RAISERROR(N' - All Operations', 0, 0) WITH NOWAIT;
            END

            --Date values are specified
            IF EXISTS(SELECT 1 FROM @opVal WHERE Val IN (N'D'))
            BEGIN
	            SET @opFrom = CONVERT(datetime, ISNULL((SELECT MinDateVal FROM @opVal WHERE Val = N'D'), CONVERT(date, GETDATE())))

	            SET @opTo = CONVERT(datetime, ISNULL((SELECT MaxDateVal FROM @opVal WHERE Val = N'D'), CONVERT(date, GETDATE())))

	            SET @opFromTZ = TODATETIMEOFFSET(@opFrom, DATEPART(TZ, SYSDATETIMEOFFSET()))
	            
                IF @opFrom <> @opTo
                BEGIN
                    SET @opToTZ = TODATETIMEOFFSET(@opTo, DATEPART(TZ, SYSDATETIMEOFFSET()))
                    SET @msg = '   - Between ' +  CONVERT(nvarchar(30), @opFromTZ, 120) + N' and ' + CONVERT(nvarchar(30), @opToTZ, 120);
                END
                ELSE
                BEGIN
                    SET @msg = '   - From ' + CONVERT(nvarchar(30), @opFromTZ, 120)    
                END

                RAISERROR(@msg, 0, 0) WITH NOWAIT;
            END


            IF EXISTS(SELECT 1 FROM @opVal WHERE Val IN ('I'))
            BEGIN                
	            SET @minInt = ISNULL((SELECT MinIntVal FROM @opVal WHERE Val = 'I'), 1)
	            SET @maxInt = ISNULL((SELECT MaxIntVal FROM @opVal WHERE Val = 'I'), 1)
                IF @minInt < 0
                    SET @minInt = 0
                IF @maxInt < 0
                    SET @maxInt = 0
            END

            IF @maxInt IS NOT NULL AND @minInt IS NOT NULL
            BEGIN
                
                IF @maxInt = @minInt
                    SET @msg = '   - From execution_id ' + CONVERT(nvarchar(20), @minInt)
                ELSE
                    SET @msg = '   - Execution_id(s) Between ' + CONVERT(nvarchar(20), @minInt) + N' and ' + CONVERT(nvarchar(20), @maxInt)

                RAISERROR(@msg, 0, 0) WITH NOWAIT;
            END

            IF EXISTS(SELECT Val FROM @opVal WHERE Val IN (N'P', N'FLD',  N'E'))
            BEGIN
                SET @msg = ' - Grouped by ';

	            IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'E')
                BEGIN
		            SET @msg = @msg + N'FOLDER, PROJECT, EXECUTABLE'
                    SET @opLastGrp = 'E'
                END
	            ELSE IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'P')
                BEGIN
		            SET @msg = @msg + N'FOLDER, PROJECT';
                    SET @opLastGrp = 'P'
                END
	            ELSE IF EXISTS(SELECT 1 FROM @opVal WHERE Val IN (N'FLD'))
                BEGIN
		            SET @msg = @msg + N'FOLDER';
                    SET @opLastGrp = 'FLD'
                END

                RAISERROR(@msg, 0, 0) WITH NOWAIT;
            END


            /*Get EVENT MESSAGES param */
            IF EXISTS(SELECT 1 FROM @opVal WHERE Val = 'EM')
            BEGIN
                SET @includeMessages = 1
                SET @max_messages = (SELECT MaxIntVal FROM @opVal WHERE Val = 'EM')
                IF @max_messages < 0
                    SET @max_messages = NULL
                ELSE IF @max_messages = 0
                    SET @max_messages = 100
            END


            IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'EP')
            BEGIN
                SET @includeExecPackages = 1;
                RAISERROR(N' - Including information about executed packages', 0, 0) WITH NOWAIT;
            END

        END /*Non Verbose Params processing */


    /* General Params processing */

    IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'AGR')
    BEGIN
        SET @includeAngetReferences = 1;
        RAISERROR(N' - Including information about Agent Job Steps referencing the package', 0, 0) WITH NOWAIT;
    END

    IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'AGT')
    BEGIN
        SET @includeAgentJob = 1
        RAISERROR(N' - Including information about Agent Job Step invoking the execution', 0, 0) WITH NOWAIT;
    END

    IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'ST')
    BEGIN
        IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'ST' AND StrVal IN ('_A', '_ASC','A','ASC'))
            SET @useTimeDescenting = 0;

        SET @useStartTime = 1;
    END

    IF EXISTS(SELECT 1 FROM @opVal WHERE Val = 'ET')
    BEGIN
        IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'ET' AND StrVal IN ('_A', '_ASC','A','ASC'))
            SET @useTimeDescenting = 0;

        SET @useEndTime = 1;
    END

    IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'X')
        SET @totalMaxRows = (SELECT MaxIntVal FROM @opVal WHERE Val = N'X')


    
    IF @id IS NULL AND @opLastCnt IS NULL AND @opFromTZ IS NULL AND @minInt IS NULL  AND @lastSpecified = 0
    BEGIN
        SET @opLastCnt = @defaultLastOp;
        RAISERROR(N' - default Last %d operations', 0, 0, @opLastCnt) WITH NOWAIT;
    END

    /* END OF OPERATION  Retrieval */

    /* BEGIN PROCESS MESSAGE TYPES */
    IF OBJECT_ID('tempdb..#msgTypes') IS NOT NULL
        DROP TABLE #msgTypes;

    CREATE TABLE #msgTypes (
         id     smallint        NOT NULL PRIMARY KEY CLUSTERED
        ,msg    nvarchar(50)    NOT NULL        
    )
    CREATE INDEX #msgTypes ON #msgTypes (msg)

    IF @id IS NULL AND ISNULL(@msg_type, N'') = N''
        SET @msg_type = N'ERROR,TASK_FAILED'

    SET @xml = N'<i>' + REPLACE(REPLACE(@msg_type, N',', @xr), N' ', @xr) + N'</i>'

    INSERT INTO #msgTypes(id, msg)
    SELECT
        amt.id
        ,amt.msg
    FROM @availMsgTypes amt
    INNER JOIN (SELECT n.value(N'.', 'nvarchar(50)') value FROM @xml.nodes('/i') T(n)) mt(msg) ON mt.msg = amt.msg OR mt.msg = amt.short

    IF EXISTS(SELECT 1 FROM #msgTypes)
        SET @msgTypeFilter = 1

    IF @includeMessages = 1
    BEGIN
        SET @msg = N'   - Including base Event Messages... (' + ISNULL(N'last ' + CONVERT(nvarchar(10), @max_messages), N'All') + N' rows)';
        IF  (@msgTypeFilter = 1)
            SET @msg = @msg + N' (' + STUFF((SELECT ', ' + m.msg FROM #msgTypes m FOR XML PATH('')), 1, 2, '') + N')';
        RAISERROR(@msg, 0, 0) WITH NOWAIT;
    END

    /* END PROCESS MESSAGE TYPES */


    /* BEGIN PROCESS STATUSES */
    IF OBJECT_ID('tempdb..#statuses') IS NOT NULL
        DROP TABLE #statuses;
    CREATE TABLE #statuses (
        id          int          NOT NULL PRIMARY KEY CLUSTERED
        ,[status]   nvarchar(50)
    )

    SET @xml = N'<i>' + REPLACE(REPLACE(@status, N',', @xr), N' ', @xr) + N'</i>'

    IF @id IS NULL AND @help <> 1
    BEGIN
        INSERT INTO #statuses(id, [status])
        SELECT DISTINCT
            ast.id
            ,ast.[status]
        FROM @availStatuses ast
        INNER JOIN (SELECT n.value(N'.', 'nvarchar(50)') value FROM @xml.nodes('/i') T(n)) st([status]) ON st.[status] = ast.[status] OR st.status = ast.short OR st.[status] = 'ALL'

        --if there are some statuses selected but not all, then set status filter
        IF (SELECT COUNT(1) FROM #statuses) BETWEEN 1 AND 8
        BEGIN
            SET @statusFilter = 1
            SET @msg = N' - Filtering for statuses: ' + STUFF((SELECT ', ' + s.status FROM #statuses s FOR XML PATH('')), 1, 2, '')
            RAISERROR(@msg, 0, 0) WITH NOWAIT;
        END
        /* END PROCESS STATUSES */
    
        /* START Folder Filters Processing */
        IF @folder IS NOT NULL
        BEGIN

            --temp table to hold folders
            IF OBJECT_ID('tempdb..#folders') IS NOT NULL
	            DROP TABLE #folders;
            CREATE TABLE #folders (
	            folder_name	nvarchar(128) COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY CLUSTERED
            )

            SET @xml = N'<i>' + REPLACE(@folder, N',', N'</i><i>') + N'</i>'

            INSERT INTO #folders(folder_name)
            SELECT
                name
            FROM SSISDB.internal.folders f
            INNER JOIN (SELECT DISTINCT LTRIM(RTRIM(n.value('.','nvarchar(128)'))) fld FROM @xml.nodes('/i') T(n)) T(Fld) ON f.name LIKE T.Fld AND LEFT(T.Fld, 1) <> '-'
            EXCEPT
	        SELECT
		        name
	        FROM SSISDB.internal.folders f
            INNER JOIN (SELECT DISTINCT LTRIM(RTRIM(n.value('.','nvarchar(128)'))) fld FROM @xml.nodes('/i') T(n)) T(Fld) ON f.name LIKE RIGHT(T.Fld, LEN(T.Fld) -1) AND LEFT(T.Fld, 1) = '-'
    

            IF EXISTS(SELECT 1 fld FROM @xml.nodes('/i') T(n))
            BEGIN
                SET @fldFilter = 1

                SET @msg = N' - Using Folder Filter(s): ' + REPLACE(STUFF((SELECT DISTINCT ', ' + LTRIM(RTRIM(n.value('.','nvarchar(128)'))) FROM @xml.nodes('/i') T(n) FOR XML PATH('')), 1, 2, ''), N'%', N'%%')
                RAISERROR(@msg, 0, 0) WITH NOWAIT;
            END
        END
        /* END Folder Filter Processing */

        /* START Project Filters Processing */
        IF @project IS NOT NULL
        BEGIN
            --temp table to hold folders
            IF OBJECT_ID('tempdb..#projects') IS NOT NULL
	            DROP TABLE #projects;
            CREATE TABLE #projects (
	            project_name	nvarchar(128) COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY CLUSTERED
            )

            SET @xml = N'<i>' + REPLACE(@project, N',', N'</i><i>') + N'</i>'            

            INSERT INTO #projects(project_name)
            SELECT DISTINCT
                name
            FROM SSISDB.internal.projects p            
            INNER JOIN (SELECT DISTINCT LTRIM(RTRIM(n.value('.','nvarchar(128)'))) fld FROM @xml.nodes('/i') T(n)) T(Fld) ON p.name LIKE T.Fld AND LEFT(T.Fld, 1) <> '-'
            EXCEPT
            SELECT
                name
            FROM SSISDB.internal.projects  p
            INNER JOIN (SELECT DISTINCT LTRIM(RTRIM(n.value('.','nvarchar(128)'))) fld FROM @xml.nodes('/i') T(n)) T(Fld) ON p.name LIKE RIGHT(T.Fld, LEN(T.Fld) -1) AND LEFT(T.Fld, 1) = '-'
        
            IF EXISTS(SELECT 1 fld FROM @xml.nodes('/i') T(n))
            BEGIN
                SET @prjFilter = 1
                SET @msg = N' - Using Project Filter(s): ' + REPLACE(STUFF((SELECT DISTINCT ', ' + LTRIM(RTRIM(n.value('.','nvarchar(128)'))) FROM @xml.nodes('/i') T(n) FOR XML PATH('')), 1, 2, ''), N'%', N'%%')
                RAISERROR(@msg, 0, 0) WITH NOWAIT;
            END
        END
        /* END Project Filter Processing */

    END --IF @id IS NULL AND @help <> 1



    /* START Package Filters Processing */
    IF @package IS NOT NULL
    BEGIN
        --temp table to hold folders
        IF OBJECT_ID('tempdb..#packages') IS NOT NULL
	        DROP TABLE #packages;
        CREATE TABLE #packages (
	        package_name	nvarchar(260) COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY CLUSTERED
        )

        SET @xml = N'<i>' + REPLACE(@package, N',', N'</i><i>') + N'</i>'

        IF @id IS NOT NULL
            SELECT @projId = (SELECT e.project_lsn FROM internal.executions e WHERE execution_id = @id)


        INSERT INTO #packages(package_name)
        SELECT DISTINCT
            pkg.name
        FROM internal.packages pkg
        --INNER JOIN internal.projects prj ON prj.project_id = pkg.project_id --AND prj.object_version_lsn = pkg.project_version_lsn
        --INNER JOIN internal.folders f ON f.folder_id = prj.folder_id
        INNER JOIN (SELECT LTRIM(RTRIM(n.value('.','nvarchar(260)'))) fld FROM @xml.nodes('/i') T(n)) T(name) ON pkg.name LIKE T.name AND LEFT(T.name, 1) <> '-'
        WHERE  @projId IS NULL OR pkg.project_version_lsn = @projId
        EXCEPT
        SELECT DISTINCT
            pkg.name
        FROM internal.packages pkg
        --INNER JOIN internal.projects prj ON prj.project_id = pkg.project_id AND prj.object_version_lsn = pkg.project_version_lsn
        --INNER JOIN internal.folders f ON f.folder_id = prj.folder_id
        INNER JOIN (SELECT LTRIM(RTRIM(n.value('.','nvarchar(260)'))) fld FROM @xml.nodes('/i') T(n)) T(name) ON pkg.name LIKE RIGHT(T.name, LEN(T.name) -1) AND LEFT(T.name, 1) = '-'
        WHERE  @projId IS NULL OR pkg.project_version_lsn = @projId
        

        IF EXISTS(SELECT 1 pkg FROM @xml.nodes('/i') T(n))
            SET @pkgFilter = 1
    END
    /* END Package Filter Processing */


    IF @totalMaxRows IS NOT NULL
        RAISERROR(N' - Limiting total rows to: %d', 0, 0, @totalMaxRows) WITH NOWAIT;

END /*IF @help <> 1 */



/*======================================================
                      HELP PROCESSING 
========================================================*/
IF @help = 1 
BEGIN
    RAISERROR('Usage: sp_ssisdb [params]', 0, 0) WITH NOWAIT;
    RAISERROR('-------------------------', 0, 0) WITH NOWAIT;
    RAISERROR('', 0, 0) WITH NOWAIT;
    --RAISERROR('sp_ssisdb [params]', 0, 0) WITH NOWAIT;	
    --RAISERROR('', 0, 0) WITH NOWAIT;

    RAISERROR(N'Parametes:
     @op                    nvarchar(max)   = NULL  --Operator parameter - universal operator for setting large range of condidions and filters
    ,@status                nvarchar(MAX)   = NULL  --Comma separated list of execution statuses to return. Default NULL means all. See below for more details
    ,@folder                nvarchar(max)   = NULL  --Comma separated list of folder filters. Default NLL means no filtering. See below for more details
    ,@project               nvarchar(max)   = NULL  --Comma separated list of project filters. Default NULL means no filtering. See below for more details
    ,@package               nvarchar(max)   = NULL  --Comma separated list of pacakge filters. Default NULL means no filtering. See below for more details
    ,@msg_type              nvarchar(max)   = NULL  --Comma separated list of Message types. When not provided, then for in row data a default combination of ERROR,TASK_FAILED is beging used.
    ,@event_filter          nvarchar(max)   = NULL  --Comma separated list of event LIKE filters. Used only for detailed results filtering
    ,@phase_filter          nvarchar(max)   = NULL  --Comma separated list of phase LIKE filters. Used only for detailed results filtering
    ,@task_filter           nvarchar(max)   = NULL  --Comma separated list of task LIKE filters. Used only for detailed results filtering
    ,@subcomponent_filter   nvarchar(max)   = NULL  --Comma separated list of sub-component LIKE filters. Used only for detailed results filtering.
    ,@package_path          nvarchar(max)   = NULL  --Comma separated list of package_path LIKE filters. Used only for detailed results fitering
    ,@execution_path        nvarchar(max)   = NULL  --Comma separated list of execution_path LIKE filters. Used only for detailed results filtering
    ,@msg_filter            nvarchar(max)   = NULL  --Comma separated list of message LIKE filters. Used only for detailed results filtering
    ', 0, 0) WITH NOWAIT

RAISERROR('', 0, 0) WITH NOWAIT;
RAISERROR('@op - Operator Parameter', 0, 0) WITH NOWAIT;
RAISERROR('------------------------', 0, 0) WITH NOWAIT;
RAISERROR('Comma, semicolon or space separated list of operations parameters. Specifies operations, filtering and grouping of the resuls.', 0, 0) WITH NOWAIT;
--RAISERROR('', 0, 0) WITH NOWAIT;
RAISERROR(N'
  iiiiiiiiiiiiii            - (integer values) Specifies range of execution_id(s) to return basic information. If single initeger is provided than executios starting with that id will be returned. 
                              In case of multiple initegers, range between minimum and maximum id is returned
  (L)ASTiiiii               - Optional Keywork which modifies output only to LAST iiiii records. THe LAST records are returned per group. 
                              If iiiii is not provided then then last 1 execution is returned. 
                              If Keyword is missing the default LAST 100 records are retrieved
  Date/Time                 - If provided then executions since that Date/Time are returned. If multiple Date/Time values are provided then executions between MIN and MAX values are returned.
  hh:MM (hh:MM:ss)          - If only time is provided, then the time is interpreted as Time of current day
  yyyy-mm-dd                - If only date is provided, then it is intepreted as midnigth of that day (YYYY-MM-DDTHH:MM:SS)
  yyyy-mm-ddThh:MM:ss       - When Date/Time is passed, then Time is separated by T from date. In that case hours have to be provided as two digits

  FOLDER (FLD)              - Optional keyword which specifies the result will be grouped by FOLDER. Nunmber of last records is per folder.
  (P)ROJECT                 - Optional keyword which specifeis the result will be grouped by FOLDER, PROJECT. Number of last records is per project
  (E)XECUTABLE              - Optional keyword which specifies the result will be grouped by FOLDER, PROJET, EXECUTABLE. Number of last records is per EXECUTABLE
  EXECUTED_PACKAGES (EP)    - Include information about executed packages per reult in the overview list. (Slow-downs the retrieval)
  AGENT_REFERENCES (AGR)    - Include information about Agent Jobs referencing the packages (Slow-downs the retrieval)
  AGENT_JOB (AGT)           - If available, Retrieve information aboutagent Job which executed the execution. (Slow-down the retrieval).
  MA(X)iiiii                - Optional keyword which specifies that when the LAST rows are returned per FOLDER, PROJECT, EXECUTABLE, then maximum of LAST iiiii rows
                              will be retrieved and those grouped and returned as per above specification', 0, 0) WITH NOWAIT;
RAISERROR(N'
  (V)ERBOSEiiiiii           - Used to pass exeuction ID for which detailed overview should be provided. it has priority over the overview ranges.
                              In case multiple integer numbers are provided, it produces verbose information for the maximum integer provided.
                              If verbose is specified without any integer number, then verbose invormation is provided for the last operation.

  EXECUTABLE_STATISTICS(ES)iiiii        - Include executablew statistics in the details verbose output.
                                          iiiii specifies max number of rows. If not provided then default 1000 rows are returned.
                                          iiiii < 0 = All rows are returned and is the same as not including the keyword
  EXECUTION_MESSAGES(EM)iiiii           - Include event messages details in the overview list and in details list. 
                                          iiiii specifies max number of rows. If not provided then default 100 for overview and 1000 for details is used.
                                          iiiii < 0 = All rows are returned.
                                          For Overview by default only ERROR and TASK_FAILED are included. (Slow downs data retrieval)
  EXECUTION_DATA_STATISTICS(EDS)iiiii   - Include Execution Data Statistics in the details verbose output
                                          iiiii specifies max number of rows. If not provided then default 100 for overview and 1000 for details is used.
                                          iiiii < 0 = All rows are returned.                                    
  EXECUTION_COMPONENT_PHASES(ECP)iiiii  - Include Execution Componetn Phases in the details verbose output
                                          iiiii specifies max number of rows. If not provided then default 100 for overview and 1000 for details is used.
                                          iiiii < 0 = All rows are returned.

  START_TIME (ST)           - Use Start Time for searching (By Default Create Time is used)
  END_TIME (ET)             - Use End Time for searching (By Default Creati TIme is used)
', 0, 0) WITH NOWAIT;
RAISERROR(N'
  (R)UNNING         - Filter Modifier applies RUNNING @status filter
  (S)UCCESS         - Filter Modifier applie SUCCESS @status filter
  (F)AILURE         - Filter modifier applies FAILURE @status filter
  (C)ANCELLED       - Filter modifier applies CANCELLED @status filter
  (U)NEXPECTED      - Filter modifier applies UNEXPECTED @status filter

  ?                 - Print this help
', 0, 0) WITH NOWAIT;
RAISERROR(N'
Samples:  
  LAST10                                    - Last 10 executions will be returned
  LAST5 FOLDER                              - Last 5 executions per folder will be returned
  LAST10 PROJECT                            - last 10 executions per folder/project will be returned
  E L6 EM EP                                - last 6 executions per Executable (package) will be returned including overview of error messages and executed packages
  LS F E 5                                  - last 5 exectutions per executable with status Success or Failure will be returned
  815350 815500                             - executions with execution_id betwen 815350 and 815500 are returned
  06:00:00                                  - all executions since 06:00:00 today will be returned
  06:00:00 12:30:00                         - all executions from today between 06:00:00 and 12:30:00 today will be returned
  2017-01-20T06:00:00 2017-01-21T13:35:00   - all executions between 2017-01-206:00:00 and 2017-01-21 13:35:00 will be returned
  2017-01-20T06:00:00 12:30:00              - all executions between 2017-01-206:00:00 and today 12:30:00 will be returned
', 0, 0) WITH NOWAIT;
RAISERROR(N'
LIKE Filters
------------
LIKE filters allow passing comma separated list of filters.
Filter suports LIKE wildcards %% and _.
Filter can be prefixed with [-]. In that case it means that matching results should be excluded. This has precedence.

Samples:
    SC%%,%%IT         - Specifies that all matches starting with "SC" or ending with "IT" will be returned
    %%SAP%%           - Specifies that all matches containing "SAP" will be returned
    SC%%,-%%SAP%%      - Specifies that all matches starting with "SC" but not containing "SAP" will be returned
    %%,-%%OnPost%%     - Specifies that all matches except those containing "OnPost" will be returned
', 0, 0) WITH NOWAIT;

RAISERROR(N'
@status - Execution Statuses
----------------------------
Below list of execution statuses are available for filter:

  CREA(T)ED     - Operation was created but not executed yet
  (R)UNNING     - Operation is running
  (S)UCCESS     - Operation ended successfully
  (F)FAILED     - Operation execution failed
  (C)CANCELLED  - Operation execution was cancelled
  (P)ENDING     - Operation was set for exectuion, but he execution is stil pending
  (U)NEXPECTED  - Operetion edend unexpectedly
  STOPPIN(G)    - Operation is in process of stpping
  COMPLETE(D)   - Operation was completed
', 0, 0) WITH NOWAIT;

RAISERROR(N'
@msg_type - Message Types
-------------------------
Below message filters are supported. By default ERROR and TASK_FAILED messages are included

  (E)  ERROR                   - error message
  (W)  WARNING                 - warning message
  (F)  TASK_FAILED             - task failed message
  (I)  INFORMATION             - invormation message
  (PV) PRE_VALIDATE            - Pre validate message
  (TV) POST_VALIDATE           - Post validate message
  (PE) PRE_EXECUTE             - pre-exectue message
  (TV) POST_EXECUTE            - post-execute message
  (P)  PROGRESS                - progress message
  (SC) STATUS_CHANGE           - status change message
  (QC) QUERY_CANCEL            - query cancel message
  (D)  DIAGNOSTICS             - diagnostics message
  (C)  CUSTOM                  - custom message
  (DE) DIAGNOSTICS_EX          - extended diagnostics message (Fired when a child package is being executed. Message containt XML with parametes passed to child package)
  (ND) NON_DIAGNOSTIS          - non diagnostics message
  (VC) VARIABLE_VALUE_CHANGE   - variable value change mesasge
  (U)  UNKNOWN                 - represents uknown message type
', 0, 0) WITH NOWAIT;

RETURN;
END
/* END HELP PROCESSING */

SET @sql = CONVERT(nvarchar(max), N'
WITH Data AS (
    SELECT ' + CASE WHEN @id IS NOT NULL THEN N'TOP (1) ' WHEN @totalMaxRows IS NOT NULL THEN N'TOP (@totalMaxRows) ' ELSE N'' END + N'
        e.execution_id
        ,e.folder_name
        ,e.project_name
        ,e.package_name
        ,o.start_time
        ,o.end_time
        ,RIGHT(''     '' + CONVERT(nvarchar(3), DATEDIFF(SECOND, start_time, ISNULL(end_time, SYSDATETIMEOFFSET())) / 86400) + ''d '', 5) +
        CONVERT(nchar(8), CONVERT(time, DATEADD(SECOND, DATEDIFF(SECOND, start_time, ISNULL(end_time, SYSDATETIMEOFFSET())) % 86400, 0))) AS duration
        ,CASE o.[status]
            WHEN 1 THEN ''Created''
            WHEN 2 THEN ''Running''
            WHEN 3 THEN ''Cancelled''
            WHEN 4 THEN ''!! FAILED !!''
            WHEN 5 THEN ''Pending''
            WHEN 6 THEN ''Unexpected''
            WHEN 7 THEN ''Success''
            WHEN 8 THEN ''Stoping''
            WHEN 9 THEN ''Completed''
            ELSE ''Unknown''
        END AS [status]
        ,o.object_type
        ,o.object_id
        ,o.object_name
        ,o.created_time
        ,o.status as status_code
        ,o.process_id
        ,e.project_lsn
        ,e.use32bitruntime
        ,e.environment_folder_name
        ,e.environment_name
        ,e.reference_id
        ,e.reference_type
        ,e.executed_as_name
        ,e.executed_as_sid
') + CASE 
        WHEN @id IS NULL AND @opLastCnt IS NOT NULL AND @opLastGrp IS NOT NULL THEN
            N',ROW_NUMBER() OVER(PARTITION BY ' +
                CASE @opLastGrp
                    WHEN 'F' THEN 'e.folder_name'
                    WHEN 'P' THEN 'e.folder_name, e.project_name'
                    WHEN 'E' THEN 'e.folder_name, e.project_name, e.package_name'
                END
            + N' ORDER BY ' + CASE WHEN @useStartTime =1 THEN N'ISNULL(start_time, ''9999-12-31'')' WHEN @useEndTime = 1 THEN N'ISNULL(end_time, ''9999-12-31'')' ELSE N'created_time' END + CASE WHEN @useTimeDescenting = 1THEN  N' DESC' ELSE N' ASC' END + N') AS row_no'
        ELSE ',ROW_NUMBER() OVER(ORDER BY ' + CASE WHEN @useStartTime =1 THEN N'ISNULL(start_time, ''9999-12-31'')' WHEN @useEndTime = 1 THEN N'ISNULL(end_time, ''9999-12-31'')' ELSE N'created_time' END + CASE WHEN @useTimeDescenting = 1THEN  N' DESC' ELSE N' ASC' END + N') AS row_no'
    END + N'
' + CASE 
        WHEN @opLastGrp IS NOT NULL THEN
            N',DENSE_RANK() OVER(ORDER BY ' +
                CASE @opLastGrp
                    WHEN 'F' THEN 'e.folder_name'
                    WHEN 'P' THEN 'e.folder_name, e.project_name'
                    WHEN 'E' THEN 'e.folder_name, e.project_name, e.package_name'
                END
            + N') AS rank'
        ELSE ',ROW_NUMBER() OVER(ORDER BY ' + CASE WHEN @useStartTime =1 THEN N'ISNULL(start_time, ''9999-12-31'')' WHEN @useEndTime = 1 THEN N'ISNULL(end_time, ''9999-12-31'')' ELSE N'created_time' END + CASE WHEN @useTimeDescenting = 1THEN  N' DESC' ELSE N' ASC' END + N') AS rank'
    END + N'
    FROM internal.operations o WITH(NOLOCK)
    INNER JOIN internal.executions e WITH(NOLOCK) ON e.execution_id = o.operation_id
' +
    CASE
        WHEN @id IS NULL AND @fldFilter = 1 THEN ' INNER JOIN #folders fld ON fld.folder_name = e.folder_name'
        ELSE ''
    END + N'
' +
    CASE
        WHEN @id IS NULL AND @prjFilter = 1 THEN ' INNER JOIN #projects prj ON prj.project_name = e.project_name'
        ELSE ''
    END + N'
' +
    CASE
        WHEN @id IS NULL AND @pkgFilter = 1 THEN ' INNER JOIN #packages pkg ON pkg.package_name = e.package_name'
        ELSE ''
    END + N'
' +
    CASE
        WHEN @id IS NULL AND @statusFilter = 1 THEN ' INNER JOIN #statuses st ON st.id = o.[status]'
        ELSE ''
    END + N'
' +  /*WHERE Condition - each line as part of VALUES */
  REPLACE(REPLACE(ISNULL(
    ' WHERE ' +
    NULLIF(
        STUFF(
            (SELECT
                N' AND ' + Val

            FROM (VALUES
                (CASE WHEN @id IS NOT NULL THEN 'e.execution_id = @id' ELSE NULL END)
                ,(CASE
                    WHEN @id IS NOT NULL THEN NULL
                    WHEN @opFromTZ IS NOT NULL AND @opToTZ IS NOT NULL THEN CASE WHEN @useStartTime =1 THEN N'(ISNULL(start_time, ''9999-12-31'')' WHEN @useEndTime = 1 THEN N'(end_time' ELSE N'(created_time' END + N' BETWEEN  @fromTZ AND @toTZ)'
                    WHEN @opFromTZ IS NOT NULL THEN CASE WHEN @useStartTime =1 THEN N'(ISNULL(start_time, ''9999-12-31'')' WHEN @useEndTime = 1 THEN N'(ISNULL(end_time, ''9999-12-31'')' ELSE N'(created_time' END +' > @fromTZ)'
                  END
                )
                ,(CASE
                    WHEN @id IS NOT NULL THEN NULL
                    WHEN @maxInt IS NOT NULL AND @minInt IS NOT NULL AND @minInt = @maxInt THEN '(e.execution_id >= @minInt)'
                    WHEN @maxInt IS NOT NULL AND @minInt IS NOT NULL THEN '(execution_id BETWEEN @minInt AND @maxInt)'
                  END
                )
                )T(val)
            FOR XML PATH('')
            )
            ,1, 5, N''
        )
        ,''
    )
  ,N''
  ), N'&gt;', N'>'), N'&lt;', N'<') +
    CASE  
        WHEN @totalMaxRows IS NOT NULL THEN N' ORDER BY ' + CASE WHEN @useStartTime =1 THEN N'ISNULL(start_time, ''9999-12-31'')' WHEN @useEndTime = 1 THEN N'ISNULL(end_time, ''9999-12-31'')' ELSE N'created_time' END + N' DESC ' 
        ELSE N'' 
    END
        + N'
)
SELECT
    d.execution_id
    ,d.folder_name
    ,d.project_name
    ,d.package_name
' +
    CASE WHEN @includeAgentJob = 1 THEN N'
    ,je.job_name
    ,je.step_name      AS job_step_name'
    ELSE N''
    END + 
N'
    ,d.rank
    ,d.row_no           AS r_no
    ,d.start_time
    ,d.end_time
    ,d.duration
    ,d.status' +
    CASE WHEN @id IS NULL AND @includeMessages = 1 THEN N'
    ,(SELECT 
        @messages_inrow              ''@maxMessages''
        ,(SELECT ' + CASE WHEN @max_messages IS NULL THEN N'' ELSE N'TOP (@messages_inrow)' END + N'
            mt.msg                      ''@type''
            ,om.message_time            ''@message_time''
            ,em.event_name              ''@event_name''
            ,em.message_code            ''@message_code''
            ,CASE om.message_source_type
                WHEN 10 THEN ''Entry APIs (T-SQL, CRL stored procs etc)''
                WHEN 20 THEN ''External process''
                WHEN 30 THEN ''Pacakge-level objects''
                WHEN 40 THEN ''Control flow tasks''
                WHEN 50 THEN ''Control flow containers''
                WHEN 60 THEN ''Data flow task''
                ELSE ''Unknown''
            END                         ''@source_type''
            ,em.event_message_id        ''@message_id''
            ,em.operation_id            ''@execution_id''
            ,om.message_source_type     ''@source_type_id''
            ,em.threadID                ''@thread_id''
            ,em.package_name            ''package/@package_name''
            ,em.subcomponent_name       ''package/@subcomponent_name''
            ,em.package_path            ''package/@package_path''
            ,em.execution_path          ''package/@execution_path''
            ,em.package_location_type   ''package/@location_type''
            ,''SELECT * FROM catalog.event_message_context WITH(NOLOCK) WHERE operation_id = '' + FORMAT(d.execution_id, ''G'') + '' AND event_message_id = '' + FORMAT(em.event_message_id, ''G'') ''message/context/@info''
            --,om.message                 ''message/msg''
            ,CONVERT(xml, N''<?msg --
'' + REPLACE(REPLACE(om.message, N''<?'', N''''), N''?>'', N'''') + N''
--?>'') ''message''
        FROM internal.event_messages em WITH(NOLOCK)
        INNER JOIN internal.operation_messages om WITH(NOLOCK) ON om.operation_id = em.operation_id and om.operation_message_id = em.event_message_id 
        INNER JOIN #msgTypes mt ON mt.id = om.message_type
        WHERE 
            em.operation_id = d.execution_id
        ORDER BY om.message_time DESC, om.operation_message_id DESC
        FOR XML PATH(''event_message''), TYPE
        )
    FOR XML PATH(''event_messages''), TYPE) AS event_messages'
    ELSE N''
    END + N'
' +
    CASE WHEN @id IS NOT NULL OR @includeExecPackages = 1 THEN N'
    ,(
        SELECT
            CASE WHEN d.status_code <= 2 THEN ''Incomplete Preliminary Information based on already executed tasks'' ELSE NULL END ''@status_info''
            ,(
				SELECT
					ROW_NUMBER() OVER(ORDER BY start_time)  ''@no''
					,res					AS ''@res''
					,start_time				AS ''@start_time''
					,duration				AS ''@duration''
					,package_name			AS ''@package_name''
					,result					AS ''@result''
					,end_time				AS ''@end_time''
					,result_code			AS ''@result_code''
				FROM (
				  SELECT
					 ROW_NUMBER() OVER(PARTITION BY e.package_name ORDER BY CASE WHEN e.package_path = ''\Package'' THEN 0 ELSE 1 END ASC, es.start_time ASC) AS pno
					,CASE
						(CASE WHEN e.package_path = ''\Package'' THEN es.execution_result ELSE -9999 END)
						WHEN -9999 THEN
							CASE 
								WHEN d.status_code = 1 THEN N''T''  --Created
								WHEN d.status_code = 2 THEN N''R''  --Running
								WHEN d.status_code = 3 THEN N''C''  --Cancelled
								WHEN d.status_code = 4 THEN N''F''  --Failed
								WHEN d.status_code = 5 THEN N''P''  --Pending
								WHEN d.status_code = 6 THEN N''U''  --Unexpected
								WHEN d.status_code = 7 THEN N''S''  --Succeeded
								WHEN d.status_code = 8 THEN N''G''  --Stopping
								WHEN d.status_code = 9 THEN N''O''  --Completed
								ELSE N''U''
							END             
						WHEN 0 THEN N''S''  --Success
						WHEN 1 THEN N''F''  --Failure
						WHEN 2 THEN N''O''  --Completed
						WHEN 3 THEN N''C''  --Cancelled
						ELSE N''Unknown''
					END                 AS res

					,CONVERT(nvarchar(36), es.start_time)       AS start_time
    
					,CONVERT(nvarchar(3), DATEDIFF(SECOND, es.start_time, ISNULL(NULLIF(CASE WHEN e.package_path = ''\Package'' THEN es.end_time ELSE ''0001-01-01'' END, ''0001-01-01''), 
						CASE WHEN d.status_code IN (6, 9) THEN d.end_time ELSE SYSDATETIMEOFFSET() END)) / 86400) + N''d '' +
					CONVERT(nvarchar(8), CONVERT(time, DATEADD(SECOND, DATEDIFF(SECOND, es.start_time, ISNULL(NULLIF(CASE WHEN e.package_path = ''\Package'' THEN es.end_time ELSE ''0001-01-01'' END, ''0001-01-01''), 
						CASE WHEN d.status_code IN (6, 9) THEN d.end_time ELSE SYSDATETIMEOFFSET() END)) % 86400, 0)))  duration
					,e.package_name              package_name

					,CASE
						(CASE WHEN e.package_path = ''\Package'' THEN es.execution_result ELSE -9999 END)
						WHEN -9999 THEN
							CASE 
								WHEN d.status_code = 1 THEN N''Created''
								WHEN d.status_code = 2 THEN N''Running''
								WHEN d.status_code = 3 THEN N''Cancelled''
								WHEN d.status_code = 4 THEN N''Failed''
								WHEN d.status_code = 5 THEN N''Pending''
								WHEN d.status_code = 6 THEN N''Ended unexpectedly''
								WHEN d.status_code = 7 THEN N''Succeeded''
								WHEN d.status_code = 8 THEN N''Stopping''
								WHEN d.status_code = 9 THEN N''Completed''             
								ELSE N''Unknown''
							END             
						WHEN 0 THEN N''Success''
						WHEN 1 THEN N''Failure''
						WHEN 2 THEN N''Completion''
						WHEN 3 THEN N''Cancelled''
						ELSE N''Unknown''
					END                 AS result

					,CONVERT(nvarchar(36), ISNULL(NULLIF(CASE WHEN e.package_path = ''\Package'' THEN es.end_time ELSE ''0001-01-01'' END, ''0001-01-01''), CASE WHEN d.status_code IN (6, 9) THEN d.end_time ELSE NULL END))  end_time
					,NULLIF(CASE WHEN e.package_path = ''\Package'' THEN es.execution_result ELSE -9999 END, -9999)      result_code
				FROM internal.executable_statistics es WITH(NOLOCK)
				INNER JOIN internal.executables e WITH(NOLOCK) ON e.executable_id = es.executable_id
				INNER JOIN  (
				SELECT
					 package_name 
					,ISNULL(MIN(es1.start_time), ''9999-12-31'') AS start_time
					,ISNULL(MAX(es1.end_time), ''0001-01-01'')  AS end_time
				FROM internal.executable_statistics es1 WITH(NOLOCK) 
				INNER JOIN internal.executables e1 WITH(NOLOCK) ON e1.executable_id = es1.executable_id 
				WHERE 
					e1.package_path = ''\Package'' AND es1.execution_id = d.execution_id
				GROUP BY e1.package_name
				) MM ON e.package_name = MM.package_name
				WHERE 
					es.execution_id = d.execution_id
					AND
					(
						e.package_path = ''\Package'' 
						OR
						(
							d.status_code IN (2, 5, 8)
							AND
							(
								es.start_time < MM.start_time
								OR
								es.end_time > MM.end_time
							)
						)
					)
		) EPD
		WHERE EPD.pno = 1
		ORDER BY ''@no'' DESC
        FOR XML PATH(''package''), TYPE)
    FOR XML PATH(''executed_packages''), TYPE
    ) AS executed_packages
' ELSE N'
' END + 
    CASE WHEN @includeAgentJob = 1 THEN N'
        ,(SELECT
            job_name                    ''@name''
            ,is_enabled                 ''@is_enabled''
            ,job_id                     ''@id''
            ,step_name                  ''job_step/@name''
            ,step_id                    ''job_step/@id''
            ,step_uid                   ''job_step/@uid''
            ,run_status                 ''job_step/@run_status''
            ,run_date_time              ''job_step/@run_date_time''
            ,run_duration               ''job_step/@run_duration''
            ,retries_attempted          ''job_step/@retries_attempted''
            ,o.name                     ''job_step/@operator_emailed_name''
            ,o.email_address            ''job_step/@operator_email_address''
            ,p.name                     ''job_step/@proxy_name''
            ,c.name                     ''job_step/@credentail_name''
            ,c.credential_identity      ''job_step/@credential_identity''
            ,folder_name                ''job_step/package/@folder_name''
            ,project_name               ''job_step/package/@project_name''
            ,package_name               ''job_step/package/@package_name''
            ,er.reference_id            ''job_step/environment_reference/@id''
            ,er.reference_type          ''job_step/environment_reference/@type''
            ,er.environment_name        ''job_step/environment_reference/@environment_name''
            ,er.environment_folder_name ''job_step/environment_reference/@folder_name''
            ,CONVERT(xml, N''<?command-- '' + REPLACE(REPLACE(command, N''<?'', N''''), N''?>'', N'''') + N'' --?>'') ''job_step''
            ,CONVERT(xml, N''<?message-- '' + REPLACE(REPLACE(step_message, N''<?'', N''''), N''?>'', N'''') + N'' --?>'') ''job_step''
        FROM #JobsExecutionData jed
        LEFT JOIN internal.environment_references er WITH(NOLOCK) ON er.reference_id = jed.environment_reference_id
        LEFT JOIN msdb.dbo.sysproxies p WITH(NOLOCK) ON jed.proxy_id = p.proxy_id
        LEFT JOIN sys.credentials c WITH(NOLOCK) ON c.credential_id = p.credential_id
        LEFT JOIN msdb.dbo.sysoperators o WITH(NOLOCK) ON o.id = jed.operator_id_emailed
        WHERE jed.execution_id = d.execution_id
        FOR XML PATH(''agent_job''), TYPE
        ) AS agent_job_detail'
        ELSE N''
    END +
    CASE WHEN @includeAngetReferences > 0 THEN N'
        ,(SELECT
             job_name                       ''@job_name''
            ,is_enabled                     ''@is_enabled''
            ,j.next_scheduled_run_date      ''@next_run_date''
            ,j.start_execution_date         ''@start_execution_date''
            ,j.stop_execution_date          ''@stop_execution_date''
            ,start_step_id                  ''@start_step_id''
            ,job_id                         ''@job_id''
            ,(
                SELECT
                     step_id                ''@step_id''
                    ,step_name              ''@name''
                    ,last_run               ''@last_run''
                    ,last_run_status        ''@last_status''
                    ,last_run_duration      ''@last_duration''
                    ,last_run_retries       ''@last_retries''
                    ,last_run_outcome       ''@last_outcome''
                    ,step_uid               ''@step_uid''
                    ,proxy_name             ''@proxy_name''
                    ,credential_name        ''@proxy_credential''
                    ,credential_identity    ''@proxy_credential_identity''
                    ,package_name           ''package/@name''
                    ,project_name           ''package/@project_name''
                    ,folder_name            ''package/@folder_name''
                    ,er.reference_id        ''environment_reference/@id''
                    ,er.reference_type      ''environment_reference/@type''
                    ,er.environment_name        ''environment_reference/@environment_name''
                    ,er.environment_folder_name ''environment_reference/@folder_name''
                    ,CONVERT(xml, N''<?command-- '' + REPLACE(REPLACE(command, N''<?'', N''''), N''?>'', N'''') + N'' --?>'')
                FROM #JobsData J1
                LEFT JOIN internal.environment_references er WITH(NOLOCK) ON er.reference_id = J1.environment_reference_id
                --LEFT JOIN msdb.dbo.sysproxies p WITH(NOLOCK) ON js.proxy_id = p.proxy_id
                --LEFT JOIN sys.credentials c WITH(NOLOCK) ON p.credential_id = p.credential_id
                --LEFT JOIN msdb.dbo.sysoperators o WITH(NOLOCK) ON o.id = jh.operator_id_emailed

                WHERE
                    j1.job_id = j.job_id
                    AND
                    j1.folder_name COLLATE DATABASE_DEFAULT = d.folder_name COLLATE DATABASE_DEFAULT
                    AND
                    j1.project_name COLLATE DATABASE_DEFAULT = d.project_name COLLATE DATABASE_DEFAULT
                    AND
                    j1.package_name COLLATE DATABASE_DEFAULT = d.package_name COLLATE DATABASE_DEFAULT
                FOR XML PATH(''job_step''), TYPE
            )
        FROM #JobsData J
        WHERE 
            j.folder_name COLLATE DATABASE_DEFAULT = d.folder_name COLLATE DATABASE_DEFAULT
            AND
            j.project_name COLLATE DATABASE_DEFAULT = d.project_name COLLATE DATABASE_DEFAULT
            AND
            j.package_name COLLATE DATABASE_DEFAULT = d.package_name COLLATE DATABASE_DEFAULT
        GROUP BY job_name, job_id, start_step_id, is_enabled, start_execution_date, stop_execution_date, next_scheduled_run_date
        ORDER BY job_name, job_id
        FOR XML PATH(''Job''), ROOT(''Jobs''), TYPE
        ) AS agent_job_references
        '
        ELSE N'
'
    END +
N'
    ,(
    SELECT 
        d.execution_id              ''@executon_id''
        ,d.folder_name              ''@folder''
        ,d.project_name             ''@project''
        ,d.package_name             ''@package''
        ,d.object_type              ''@object_type''
        ,d.object_id                ''@object_id''
        ,d.object_name              ''@object_name''
        ,d.status                   ''Operation/@status''
        ,d.created_time             ''Operation/@created_time''
        ,d.start_time               ''Operation/@start_time''
        ,d.end_time                 ''Operation/@end_time''
        ,d.status_code              ''Operation/@status_code''
        ,d.process_id               ''Operation/@process_id''
        ,d.project_lsn              ''Execution/@project_lsn''
        ,d.use32bitruntime          ''Execution/@use32BitRuntime''
        ,d.environment_name         ''Execution/Environment/@name''
        ,d.environment_folder_name  ''Execution/Environment/@folder''
        ,d.reference_id             ''Execution/Environment/@reference_id''
        ,d.reference_type           ''Execution/Environment/@reference_type''
        ,d.executed_as_name         ''Execution/ExecutedAs/@name''
        ,d.executed_as_sid          ''Execution/ExecutedAs/@sid''
        ,CONVERT(xml, (SELECT
                    os.available_physical_memory_kb   ''@available_physical_memory_kb''
                ,os.total_physical_memory_kb       ''@total_physical_memory_kb''
                ,os.available_page_file_kb         ''@available_page_file_kb''
                ,os.total_page_file_kb             ''@total_page_file_kb''
                ,os.cpu_count                      ''@cpu_count''
            FROM internal.operation_os_sys_info os WITH(NOLOCK) 
            WHERE os.operation_id = d.execution_id
            FOR XML PATH(''os_info''), TYPE
        ))                          ''Execution''
    FOR XML PATH(''execution_details''), TYPE
    ) AS execution_details

    ,d.created_time
' +
    CASE
        WHEN @id IS NULL THEN N',''sp_ssisdb ''''V'' + FORMAT(d.execution_ID, ''G'') + N'' ES1000 EM1000 EDS1000 ECP1000'''',@package = '''''''', @msg_type = '''''''', @event_filter = '''''''', @phase_filter = '''''''', @task_filter = '''''''',
@subcomponent_filter = '''''''', @package_path = '''''''', @execution_path = '''''''', @msg_filter = '''''''' '' as execution_details_command'
        ELSE N''
    END + N'
FROM Data d
' +
    CASE
        WHEN @includeAgentJob = 1 THEN N'
LEFT JOIN #JobsExecutionData je ON je.execution_id = d.execution_id 
'
        ELSE N''
    END +
    CASE 
        WHEN @id IS NOT NULL THEN ''
        WHEN @opLastCnt IS NOT NULL THEN 'WHERE row_no <= @opLastCnt'
        WHEN @maxInt IS NOT NULL AND @minInt IS NOT NULL AND @minInt = @maxInt THEN ''
        WHEN @maxInt IS NOT NULL AND @minInt IS NOT NULL THEN ''
        WHEN @opFromTZ IS NOT NULL AND @opToTZ IS NOT NULL THEN ''
        WHEN @opFromTZ IS NOT NULL THEN ''
        ELSE 'WHERE row_no < 100'
    END + N'
ORDER BY d.rank, d.row_no
' 

/* DEBUG PRINT */
IF @debugLevel > 0
BEGIN
    SELECT
        @debugLevel             [@debugLevel]
        ,@id                    [@id]
        ,@opLastCnt             [@opLastCnt]
        ,@totalMaxRows          [@totalMaxRows]
        ,@minInt                [@minInt]
        ,@maxInt                [@maxInt]
        ,@opLastGrp             [@opLastGrp]
        ,@opFrom                [@opFrom]  
        ,@opTo                  [@opTo]
        ,@opFromTZ              [@opFromTZ]
        ,@opToTZ                [@opToTZ]          
        ,@includeExecPackages   [@includeExecPackages]
        ,@fldFilter             [@fldFilter]
        ,@prjFilter             [@prjFilter]
        ,@statusFilter          [@statusFilter]
        ,@sql                   [@sql]
END


/* END DEBUG PRINT*/

    IF @includeAngetReferences = 1
    BEGIN
        IF OBJECT_ID('tempdb..#JobsData') IS NOT NULL
            DROP TABLE #JobsData;

        CREATE TABLE #JobsData (
	        job_id                      uniqueidentifier    NOT NULL
	        ,job_name                   sysname             NOT NULL
	        ,start_step_id              int                 NOT NULL
	        ,is_enabled                 tinyint             NOT NULL
	        ,start_execution_date       datetime            NULL
	        ,stop_execution_date        datetime            NULL
	        ,next_scheduled_run_date    datetime            NULL
	        ,step_id                    int                 NOT NULL
	        ,step_name                  sysname             NOT NULL
	        ,folder_name                nvarchar(128)       NULL
	        ,project_name               nvarchar(128)       NULL
	        ,package_name               nvarchar(260)       NULL
	        ,environment_reference_id   bigint              NULL
	        ,last_run                   datetime            NULL
	        ,last_run_status            varchar(9)          NOT NULL
	        ,last_run_duration          char(12)            NULL
	        ,last_run_outcome           int                 NOT NULL
	        ,last_run_retries           int                 NOT NULL
	        ,proxy_name                 sysname             NULL
	        ,credential_name            sysname             NULL
	        ,credential_identity        nvarchar(4000)      NULL
	        ,step_uid                   uniqueidentifier    NULL
	        ,command                    nvarchar(max) NULL
        );


        WITH JobsData AS (
            SELECT
                js.job_id               AS job_id
                ,j.name                 AS job_name
                ,j.start_step_id        AS start_step_id
                ,j.enabled              AS is_enabled
                ,ja.start_execution_date    AS start_execution_date
                ,ja.stop_execution_date     AS stop_execution_date
                ,ja.next_scheduled_run_date AS next_scheduled_run_date
                ,step_id                AS step_id
                ,step_name              AS step_name
                ,SUBSTRING(command, PATINDEX('%\SSISDB\%', command) + 8, CHARINDEX('\', command, PATINDEX('%\SSISDB\%', command) + 8) - PATINDEX('%\SSISDB\%', command) - 8) AS folder_name
                ,SUBSTRING(
                    command
                    ,CHARINDEX('\', command, PATINDEX('%\SSISDB\%', command) + 8) + 1
                    ,CHARINDEX('\', command, CHARINDEX('\', command, PATINDEX('%\SSISDB\%', command) + 8) + 1) - (CHARINDEX('\', command, PATINDEX('%\SSISDB\%', command) + 8) + 1)
                )                       AS project_name
                ,SUBSTRING(
                    command
                    ,CHARINDEX('\', command, CHARINDEX('\', command, PATINDEX('%\SSISDB\%', command) + 8) + 1) + 1
                    ,CHARINDEX('\', command, CHARINDEX('\', command, CHARINDEX('\', command, PATINDEX('%\SSISDB\%', command) + 8) + 1) + 1) - (CHARINDEX('\', command, CHARINDEX('\', command, PATINDEX('%\SSISDB\%', command) + 8) + 1) + 1)
                 )                      AS package_name
                ,SUBSTRING(
                    command
                    ,NULLIF(PATINDEX('%/ENVREFERENCE%', command), 0) + 14
                    ,CHARINDEX(' ', command, NULLIF(PATINDEX('%/ENVREFERENCE%', command), 0) + 14) - NULLIF(PATINDEX('%/ENVREFERENCE%', command), 0) - 14
                 ) AS environment_reference_id
                ,CONVERT(datetime, CONVERT(char(8), NULLIF(last_run_date, 0))) + CONVERT(datetime, TRY_CONVERT(time, STUFF(STUFF(RIGHT(REPLICATE('0', 6) +  CAST(NULLIF(last_run_time, 0) as varchar(6)), 6), 3, 0, ':'), 6, 0, ':'))) AS last_run
                ,CASE last_run_outcome 
                    WHEN 0 THEN 'Failed'
                    WHEN 1 THEN 'Succeeded'
                    WHEN 2 THEN 'Retry'
                    WHEN 3 THEN 'Cancelled'
                    ELSE 'Unknown'
                END AS                  last_run_status
                ,STUFF(STUFF(STUFF(RIGHT(REPLICATE('0', 8) + CAST(last_run_duration as varchar(8)), 8), 3, 0, 'd '), 7, 0, ':'),10, 0, ':') AS last_run_duration
                ,last_run_outcome       AS last_run_outcome
                ,last_run_retries       AS last_run_retries
                ,p.name                 AS proxy_name
                ,c.name                 AS credential_name
                ,c.credential_identity  AS credential_identity
                ,step_uid
                ,command
            FROM msdb.dbo.sysjobsteps js WITH(NOLOCK)
            INNER JOIN msdb.dbo.sysjobs j WITH(NOLOCK) ON j.job_id = js.job_id
            INNER JOIN msdb.dbo.sysjobactivity ja WITH(NOLOCK) ON ja.job_id = j.job_id AND ja.session_id = (SELECT MAX(session_id) FROM msdb.dbo.sysjobactivity)
            LEFT JOIN msdb.dbo.sysproxies p WITH(NOLOCK) ON js.proxy_id = p.proxy_id
            LEFT JOIN sys.credentials c WITH(NOLOCK) ON p.credential_id = p.credential_id
            WHERE 
                js.subsystem = 'SSIS'
        )
        INSERT INTO #JobsData (
             job_id
            ,job_name
            ,start_step_id
            ,is_enabled
            ,start_execution_date
            ,stop_execution_date
            ,next_scheduled_run_date
            ,step_id
            ,step_name
            ,folder_name
            ,project_name
            ,package_name
            ,environment_reference_id
            ,last_run
            ,last_run_status
            ,last_run_duration
            ,last_run_outcome
            ,last_run_retries
            ,proxy_name
            ,credential_name
            ,credential_identity
            ,step_uid
            ,command
        )
        SELECT
             job_id
            ,job_name
            ,start_step_id
            ,is_enabled
            ,start_execution_date
            ,stop_execution_date
            ,next_scheduled_run_date
            ,step_id
            ,step_name
            ,folder_name
            ,project_name
            ,package_name
            ,environment_reference_id
            ,last_run
            ,last_run_status
            ,last_run_duration
            ,last_run_outcome
            ,last_run_retries
            ,proxy_name
            ,credential_name
            ,credential_identity
            ,step_uid
            ,command
        FROM JobsData
    END

    IF @includeAgentJob = 1
    BEGIN
        IF OBJECT_ID('tempdb..#JobsExecutionData') IS NOT NULL
            DROP TABLE #JobsExecutionData;

            CREATE TABLE #JobsExecutionData(
	             execution_id               bigint              NOT NULL --PRIMARY KEY CLUSTERED
	            ,job_id                     uniqueidentifier    NOT NULL
	            ,job_name                   sysname             NOT NULL
	            ,start_step_id              int                 NOT NULL
	            ,is_enabled                 tinyint             NOT NULL
	            ,step_id                    int                 NOT NULL
	            ,step_name                  sysname             NOT NULL
	            ,folder_name                nvarchar(128)       NULL
	            ,project_name               nvarchar(128)       NULL
	            ,package_name               nvarchar(260)       NULL
	            ,environment_reference_id   bigint              NULL
	            ,step_uid                   uniqueidentifier    NULL
	            ,step_message               nvarchar(4000)      NULL
	            ,command                    nvarchar(max)       NULL
                ,run_status                 nvarchar(10)        NULL
                ,run_date_time              datetime            NULL
                ,run_duration               nchar(12)           NULL
                ,retries_attempted          int                 NULL
                ,operator_id_emailed        int                 NULL
                ,proxy_id                   int                 NULL

        )

        ;WITH JobsExecutionData AS (
            SELECT
                 j.job_id                       AS job_id
                ,j.name                         AS job_name
                ,j.start_step_id                AS start_step_id
                ,j.enabled                      AS is_enabled
                ,jh.step_id                     AS step_id
                ,jh.step_name                   AS step_name
                ,jh.message                     AS step_message
                ,ISNULL(
                    TRY_CONVERT(bigint, SUBSTRING(message, NULLIF(PATINDEX('%Execution ID: %', message), 0) + 14, CHARINDEX('.', message, NULLIF(PATINDEX('%Execution ID: %', message), 0) + 14) - NULLIF(PATINDEX('%Execution ID: %', message), 0) - 14)) 
                    ,TRY_CONVERT(bigint, SUBSTRING(message, NULLIF(PATINDEX('%Execution ID: %', message), 0) + 14, CHARINDEX(',', message, NULLIF(PATINDEX('%Execution ID: %', message), 0) + 14) - NULLIF(PATINDEX('%Execution ID: %', message), 0) - 14)) 
                 ) AS execution_id
                ,LEFT(SUBSTRING(command, PATINDEX('%\SSISDB\%', command) + 8, CHARINDEX('\', command, PATINDEX('%\SSISDB\%', command) + 8) - PATINDEX('%\SSISDB\%', command) - 8), 128) AS folder_name
                ,LEFT(SUBSTRING(
                    command
                    ,CHARINDEX('\', command, PATINDEX('%\SSISDB\%', command) + 8) + 1
                    ,CHARINDEX('\', command, CHARINDEX('\', command, PATINDEX('%\SSISDB\%', command) + 8) + 1) - (CHARINDEX('\', command, PATINDEX('%\SSISDB\%', command) + 8) + 1)
                ), 128)                       AS project_name
                ,LEFT(SUBSTRING(
                    command
                    ,CHARINDEX('\', command, CHARINDEX('\', command, PATINDEX('%\SSISDB\%', command) + 8) + 1) + 1
                    ,CHARINDEX('\', command, CHARINDEX('\', command, CHARINDEX('\', command, PATINDEX('%\SSISDB\%', command) + 8) + 1) + 1) - (CHARINDEX('\', command, CHARINDEX('\', command, PATINDEX('%\SSISDB\%', command) + 8) + 1) + 1)
                    ), 260)                      AS package_name
                ,TRY_CONVERT(bigint, SUBSTRING(
                    command
                    ,NULLIF(PATINDEX('%/ENVREFERENCE%', command), 0) + 14
                    ,CHARINDEX(' ', command, NULLIF(PATINDEX('%/ENVREFERENCE%', command), 0) + 14) - NULLIF(PATINDEX('%/ENVREFERENCE%', command), 0) - 14
                    )) AS environment_reference_id
                ,step_uid
                ,command
                ,CASE jh.run_status
                    WHEN 0 THEN 'Failed'
                    WHEN 1 THEN 'Succeeded'
                    WHEN 2 THEN 'Retry'
                    WHEN 3 THEN 'Cancelled'
                    ELSE 'Unknown'
                END as run_status
               ,CONVERT(datetime, CONVERT(char(8), jh.run_date)) + CONVERT(datetime, TRY_CONVERT(time, STUFF(STUFF(RIGHT(REPLICATE('0', 6) +  CAST(jh.run_time as varchar(6)), 6), 3, 0, ':'), 6, 0, ':'))) AS run_date_time
               ,STUFF(STUFF(STUFF(RIGHT(REPLICATE('0', 8) + CAST(jh.run_duration as varchar(8)), 8), 3, 0, 'd '), 7, 0, ':'),10, 0, ':') AS run_duration
               ,jh.operator_id_emailed
               ,jh.retries_attempted
               ,js.proxy_id
            FROM msdb.dbo.sysjobhistory jh WITH(NOLOCK)
            INNER JOIN msdb.dbo.sysjobsteps js WITH(NOLOCK) ON js.job_id = jh.job_id AND js.step_id = jh.step_id
            INNER JOIN msdb.dbo.sysjobs j WITH(NOLOCK) ON j.job_id = js.job_id
            WHERE
            js.subsystem = 'SSIS'
        )
        INSERT INTO #JobsExecutionData(
             execution_id
            ,job_id
            ,job_name
            ,start_step_id
            ,is_enabled
            ,step_id
            ,step_name
            ,folder_name
            ,project_name
            ,package_name
            ,environment_reference_id
            ,step_uid
            ,step_message
            ,command
            ,run_status
            ,run_date_time
            ,run_duration
            ,retries_attempted
            ,operator_id_emailed
            ,proxy_id
        )
        SELECT
             execution_id
            ,job_id
            ,job_name
            ,start_step_id
            ,is_enabled
            ,step_id
            ,step_name
            ,folder_name
            ,project_name
            ,package_name
            ,environment_reference_id
            ,step_uid
            ,step_message
            ,command
            ,run_status
            ,run_date_time
            ,run_duration
            ,retries_attempted
            ,operator_id_emailed
            ,proxy_id
        FROM JobsExecutionData
        WHERE execution_id IS NOT NULL

        CREATE INDEX #JobsExecutionData ON #JobsExecutionData (execution_id)
    END


/* EXECUTION OF THE MAIN QUERY */
EXEC sp_executesql @sql, N'@opLastCnt int, @messages_inrow int, @fromTZ datetimeoffset, @toTZ datetimeoffset, @minInt bigint, @maxInt bigint, @id bigint, @totalMaxRows int', @opLastCnt, @max_messages, @opFromTZ, @opToTZ, @minInt, @maxInt, @id, @totalMaxRows






IF @id IS NOT NULL
BEGIN
    IF OBJECT_ID('tempdb..#tasks') IS NOT NULL
	    DROP TABLE #tasks;
    CREATE TABLE #tasks (
	    task_name   nvarchar(4000) COLLATE DATABASE_DEFAULT NOT NULL --PRIMARY KEY CLUSTERED
    )

    IF OBJECT_ID('tempdb..#subComponents') IS NOT NULL
	    DROP TABLE #subComponents;
    CREATE TABLE #subComponents (
	    subcomponent_name   nvarchar(4000) COLLATE DATABASE_DEFAULT NOT NULL --PRIMARY KEY CLUSTERED
    )


    --@package_path filters
    SET @xml = N'<i>' + REPLACE(@package_path, N',', @xr) + N'</i>'

    CREATE TABLE #package_paths (
         filter     nvarchar(4000) COLLATE DATABASE_DEFAULT
        ,exclusive  bit
    )
    
    ;WITH FilterValues AS (
        SELECT DISTINCT
            LTRIM(RTRIM(n.value(N'.', 'nvarchar(50)'))) value
        FROM @xml.nodes('/i') T(n)
    )
    INSERT INTO #package_paths (filter, exclusive)
    SELECT
        CASE WHEN LEFT(value, 1) = '-' THEN RIGHT(value, LEN(value) -1) ELSE value END
        ,CASE WHEN LEFT(value, 1) = '-' THEN 1 ELSE 0 END
    FROM FilterValues


    --@execution_paths filters
    SET @xml = N'<i>' + REPLACE(@execution_path, N',', @xr) + N'</i>'

    CREATE TABLE #execution_paths (
         filter     nvarchar(4000) COLLATE DATABASE_DEFAULT
        ,exclusive  bit
    )

    ;WITH FilterValues AS (
        SELECT DISTINCT
            LTRIM(RTRIM(n.value(N'.', 'nvarchar(50)'))) value
        FROM @xml.nodes('/i') T(n)
    )
    INSERT INTO #execution_paths (filter, exclusive)
    SELECT
        CASE WHEN LEFT(value, 1) = '-' THEN RIGHT(value, LEN(value) -1) ELSE value END
        ,CASE WHEN LEFT(value, 1) = '-' THEN 1 ELSE 0 END
    FROM FilterValues




    /*EXECUTABLE STATISTICS */
    IF @incoludeExecutableStatistics = 1
    BEGIN
        SET @sql = N'
            SELECT ' + CASE WHEN @execRows IS NOT NULL THEN N'TOP (@execRows)' ELSE N'' END + N'
                es.[statistics_id]
                ,e.package_name
                ,e.package_path
                ,es.[execution_path]
                ,es.[start_time]
                ,es.[end_time]
                ,FORMAT(es.[execution_duration] / 86400000, ''##0\d '') +
                CONVERT(nchar(12), CONVERT(time, DATEADD(MILLISECOND, es.[execution_duration] % 86400000, CONVERT(datetime2, ''1900-01-01'')))) AS duration
                ,es.[execution_duration] AS duration_ms
                ,CASE es.execution_result
                    WHEN 0 THEN N''Success''
                    WHEN 1 THEN N''Failure''
                    WHEN 2 THEN N''Completion''
                    WHEN 3 THEN N''Cancelled''
                    ELSE N''Unknown''
                END AS result
                ,es.[execution_result] AS result_code
                ,es.[executable_id]
                ,es.[execution_value]
                ,es.[execution_hierarchy]
                ,e.project_version_lsn
                ,e.package_location_type
                ,e.package_path_full
                ,e.executable_guid
             FROM [internal].[executable_statistics] es WITH(NOLOCK)
             INNER JOIN [internal].[executables] e  WITH(NOLOCK) ON e.executable_id = es.executable_id
    ' +
        CASE 
            WHEN @pkgFilter = 1 THEN N' INNER JOIN #packages pkg ON pkg.package_name = e.package_name'
            ELSE ''
        END + N'
             WHERE es.execution_id = @id' +
        CASE
            WHEN NULLIF(@execution_path, '') IS NOT NULL THEN N' AND (EXISTS(SELECT 1 FROM #execution_paths f WHERE es.execution_path LIKE f.filter AND f.exclusive = 0) AND NOT EXISTS(SELECT 1 FROM #execution_paths f WHERE es.execution_path LIKE f.filter AND f.exclusive = 1))'
            ELSE N''
        END + 
        CASE
            WHEN NULLIF(@package_path, '') IS NOT NULL THEN N' AND (EXISTS(SELECT 1 FROM #package_paths f WHERE e.package_path LIKE f.filter AND f.exclusive = 0) AND NOT EXISTS(SELECT 1 FROM #package_paths f WHERE e.package_path LIKE f.filter AND f.exclusive = 1))'
            ELSE N''
        END + N'
             ORDER BY ' + CASE WHEN @useStartTime =1 THEN N'ISNULL(es.start_time, ''9999-12-31'')' WHEN @useEndTime = 1 THEN N'ISNULL(es.end_time, ''9999-12-31'')' ELSE N'es.end_time' END + CASE WHEN @useTimeDescenting = 1THEN  N' DESC' ELSE N' ASC' END

        IF EXISTS(SELECT 1 FROM [internal].[executable_statistics] es WHERE es.execution_id = @id)
        BEGIN
            SET @msg = N' - Processing executable statistics... (' + ISNULL(N'last ' + CONVERT(nvarchar(10), @execRows), N'All') + N' rows)';
            RAISERROR(@msg, 0, 0) WITH NOWAIT;

            EXEC sp_executesql @sql, N'@id bigint, @execRows int, @package_path nvarchar(max), @execution_path nvarchar(max)', @id, @execRows, @package_path, @execution_path
        END
        ELSE
        BEGIN
            SET @msg = N' - No Executable statistics were found for execution_id = ' + CONVERT(nvarchar(20), @id)
            RAISERROR(@msg, 0, 0) WITH NOWAIT;
        END
    END --IF @incoludeExecutableStatistics = 1

    IF @includeMessages = 1
    BEGIN
        /* EVENT MESSAGES */
        IF EXISTS(SELECT 1 FROM internal.operation_messages om WHERE om.operation_id = @id)
        BEGIN        

            IF (@task_filter IS NOT NULL)
            BEGIN
                --temp table to hold folders
                TRUNCATE TABLE #tasks;

                SET @xml = N'<i>' + REPLACE(@task_filter, N',', N'</i><i>') + N'</i>'

                --get unique phases
                DECLARE @baseTasksM TABLE (
                    task_name nvarchar(4000)
                )
                INSERT INTO @baseTasksM(task_name) 
                SELECT em.message_source_name
                FROM internal.event_messages em
                WHERE operation_id = @id AND message_source_name IS NOT NULL
                GROUP BY em.message_source_name

            
                INSERT INTO #tasks(task_name)
                SELECT
                    bt.task_name
                FROM @baseTasksM bt
                INNER JOIN (SELECT DISTINCT LTRIM(RTRIM(n.value('.','nvarchar(128)'))) fld FROM @xml.nodes('/i') T(n)) T(Fld) ON bt.task_name LIKE T.Fld AND LEFT(T.Fld, 1) <> '-'
                EXCEPT
	            SELECT
		            bt.task_name
	            FROM @baseTasksM bt
                INNER JOIN (SELECT DISTINCT LTRIM(RTRIM(n.value('.','nvarchar(128)'))) fld FROM @xml.nodes('/i') T(n)) T(Fld) ON bt.task_name LIKE RIGHT(T.Fld, LEN(T.Fld) -1) AND LEFT(T.Fld, 1) = '-'
            
                IF EXISTS(SELECT 1 fld FROM @xml.nodes('/i') T(n))
                BEGIN
                    SET @taskFilter = 1               
                    SET @task_filter = REPLACE(STUFF((SELECT DISTINCT ', ' + LTRIM(RTRIM(n.value('.','nvarchar(128)'))) FROM @xml.nodes('/i') T(n) FOR XML PATH('')), 1, 2, ''), N'%', N'%%')
                END
                ELSE
                    SET @taskFilter = 0
            END

            IF (@event_filter IS NOT NULL)
            BEGIN
                --temp table to hold events
                IF OBJECT_ID('tempdb..#events') IS NOT NULL
	                DROP TABLE #events;
                CREATE TABLE #events (
	                event_name	nvarchar(1024) COLLATE DATABASE_DEFAULT NOT NULL --PRIMARY KEY CLUSTERED
                )

                SET @xml = N'<i>' + REPLACE(@event_filter, N',', N'</i><i>') + N'</i>'

                --get unique phases
                DECLARE @baseEvents TABLE (
                    event_name nvarchar(128)
                )
                INSERT INTO @baseEvents(event_name) 
                SELECT em.event_name
                FROM internal.event_messages em
                WHERE operation_id = @id AND event_name IS NOT NULL
                GROUP BY em.event_name

            
                INSERT INTO #events(event_name)
                SELECT
                    be.event_name
                FROM @baseEvents be
                INNER JOIN (SELECT DISTINCT LTRIM(RTRIM(n.value('.','nvarchar(128)'))) fld FROM @xml.nodes('/i') T(n)) T(Fld) ON be.event_name LIKE T.Fld AND LEFT(T.Fld, 1) <> '-'
                EXCEPT
	            SELECT
		            be.event_name
	            FROM @baseEvents be
                INNER JOIN (SELECT DISTINCT LTRIM(RTRIM(n.value('.','nvarchar(128)'))) fld FROM @xml.nodes('/i') T(n)) T(Fld) ON be.event_name LIKE RIGHT(T.Fld, LEN(T.Fld) -1) AND LEFT(T.Fld, 1) = '-'
            
                IF EXISTS(SELECT 1 fld FROM @xml.nodes('/i') T(n))
                BEGIN
                    SET @eventFilter = 1               
                    SET @event_filter = REPLACE(STUFF((SELECT DISTINCT ', ' + LTRIM(RTRIM(n.value('.','nvarchar(128)'))) FROM @xml.nodes('/i') T(n) FOR XML PATH('')), 1, 2, ''), N'%', N'%%')
                END
                ELSE
                    SET @eventFilter = 0
            END

            IF (@subcomponent_filter IS NOT NULL)
            BEGIN
                --temp table to hold folders
                TRUNCATE TABLE #subComponents;

                SET @xml = N'<i>' + REPLACE(@subcomponent_filter, N',', N'</i><i>') + N'</i>'

                --get unique phases
                DECLARE @baseSubcomponents TABLE (
                    subcomponent_name nvarchar(4000)
                )

                INSERT INTO @baseSubcomponents(subcomponent_name) 
                SELECT em.subcomponent_name
                FROM internal.event_messages em
                WHERE operation_id = @id AND subcomponent_name IS NOT NULL
                GROUP BY em.subcomponent_name

            
                INSERT INTO #subComponents(subcomponent_name)
                SELECT
                    bs.subcomponent_name
                FROM @baseSubcomponents bs
                INNER JOIN (SELECT DISTINCT LTRIM(RTRIM(n.value('.','nvarchar(128)'))) fld FROM @xml.nodes('/i') T(n)) T(Fld) ON bs.subcomponent_name LIKE T.Fld AND LEFT(T.Fld, 1) <> '-'
                EXCEPT
	            SELECT
		            bs.subcomponent_name
	            FROM @baseSubcomponents bs
                INNER JOIN (SELECT DISTINCT LTRIM(RTRIM(n.value('.','nvarchar(128)'))) fld FROM @xml.nodes('/i') T(n)) T(Fld) ON bs.subcomponent_name LIKE RIGHT(T.Fld, LEN(T.Fld) -1) AND LEFT(T.Fld, 1) = '-'
            
                IF EXISTS(SELECT 1 fld FROM @xml.nodes('/i') T(n))
                BEGIN
                    SET @subcomponentFilter = 1               
                    SET @subcomponent_filter = REPLACE(STUFF((SELECT DISTINCT ', ' + LTRIM(RTRIM(n.value('.','nvarchar(128)'))) FROM @xml.nodes('/i') T(n) FOR XML PATH('')), 1, 2, ''), N'%', N'%%')
                END
                ELSE
                    SET @subcomponentFilter = 0
            END

            --Messsage Filters
            SET @xml = N'<i>' + REPLACE(@msg_filter, N',', @xr) + N'</i>'

            CREATE TABLE #msg_filters (
                 filter     nvarchar(4000) COLLATE DATABASE_DEFAULT
                ,exclusive  bit
            )

            ;WITH FilterValues AS (
                SELECT DISTINCT
                    LTRIM(RTRIM(n.value(N'.', 'nvarchar(50)'))) value
                FROM @xml.nodes('/i') T(n)
            )
            INSERT INTO #msg_filters (filter, exclusive)
            SELECT
                CASE WHEN LEFT(value, 1) = '-' THEN RIGHT(value, LEN(value) -1) ELSE value END
                ,CASE WHEN LEFT(value, 1) = '-' THEN 1 ELSE 0 END
            FROM FilterValues



            SET @sql = CONVERT(nvarchar(max), N'
            SELECT ' + CASE WHEN @max_messages IS NOT NULL THEN N'TOP (@max_messages)' ELSE N'' END + N'
                em.event_message_id
                ,em.package_name
                ,em.message_source_name                     AS source_name
                ,em.subcomponent_name
                ,em.event_name
                ,om.message_time
                ,CASE om.message_type
                    WHEN 120 THEN N''ERROR''
                    WHEN 110 THEN N''WARNING''
                    WHEN 70	 THEN N''INFORMATION''
                    WHEN 10	 THEN N''PRE_VALIDATE''
                    WHEN 20	 THEN N''POST_VALIDATE''
                    WHEN 30	 THEN N''PRE_EXECUTE''
                    WHEN 40	 THEN N''POST_EXECUTE''
                    WHEN 60	 THEN N''PROGRESS''
                    WHEN 50	 THEN N''STATUS_CHANGE''
                    WHEN 100 THEN N''QUERY_CANCEL''
                    WHEN 130 THEN N''TASK_FAILED''
                    WHEN 90	 THEN N''DIAGNOSTICS''
                    WHEN 200 THEN N''CUSTOM''
                    WHEN 140 THEN N''DIAGNOSTICS_EX''
                    WHEN 400 THEN N''NON_DIAGNOSTIS''
                    WHEN 80	THEN  N''VARIABLE_VALUE_CHANGE''
                    ELSE N''UNKNOWN''
                END                                         AS message_type_desc
                ,(SELECT
                CONVERT(xml, ''<?msg --
        '' +  REPLACE(REPLACE(om.message, N''<?'', ''''), ''?>'', '''') + ''
        --?>'') 
                ,CASE WHEN om.message_type = 120 THEN
                (
                SELECT
                    mc.context_depth    ''@depth''
                    ,CASE mc.context_type
                        WHEN 10	THEN N''Task''
                        WHEN 20	THEN N''Pipeline''
                        WHEN 30	THEN N''Sequence''
                        WHEN 40	THEN N''For Loop''
                        WHEN 50	THEN N''Foreach Loop''
                        WHEN 60	THEN N''Package''
                        WHEN 70	THEN N''Variable''
                        WHEN 80	THEN N''Connection manager''
                        ELSE N''Unknown''
                    END                 ''@type_desc''
                    ,mc.context_type    ''@type''
                    ,mc.property_name   ''@property_name''
                    ,CONVERT(xml, N''<?val -- '' + REPLACE(REPLACE(CONVERT(nvarchar(max), mc.property_value), N''<?'', N''''), N''?>'', N'''') + N''--?>'')
                FROM internal.event_message_context mc WITH(NOLOCK) 
                WHERE mc.event_message_id = om.operation_message_id
                FOR XML PATH(''context''), ROOT(''message_context''), TYPE
                )
                ELSE NULL END
                FOR XML PATH(''message''), TYPE)
                as message
                ,CASE om.message_source_type
                    WHEN 10 THEN ''Entry APIs (T-SQL, CRL stored procs etc)''
                    WHEN 20 THEN ''External process''
                    WHEN 30 THEN ''Pacakge-level objects''
                    WHEN 40 THEN ''Control flow tasks''
                    WHEN 50 THEN ''Control flow containers''
                    WHEN 60 THEN ''Data flow task''
                    ELSE ''Unknown''
                END                                         AS source_type_desc
                ,em.package_path
                ,em.execution_path
                ,em.message_source_id
                ,em.package_location_type
                ,om.message_source_type                     AS source_type
                ,om.message_type                            AS message_type
                ,em.threadID
            FROM internal.operation_messages om WITH(NOLOCK)
            INNER JOIN internal.event_messages em WITH(NOLOCK) ON em.event_message_id = om.operation_message_id ') +
            CASE 
                WHEN @pkgFilter = 1 THEN N' INNER JOIN #packages pkg ON pkg.package_name = em.package_name'
                ELSE ''
            END + 
            CASE
                WHEN @msgTypeFilter = 1 THEN N'INNER JOIN #msgTypes mt ON mt.id = om.message_type'
                ELSE N''
            END +
            CASE 
                WHEN @taskFilter = 1 THEN N' INNER JOIN #tasks tf ON tf.task_name = em.message_source_name'
                ELSE N''
            END +
            CASE 
                WHEN @eventFilter = 1 THEN N' INNER JOIN #events ef ON ef.event_name = em.event_name'
                ELSE N''
            END +
            CASE 
                WHEN @subcomponentFilter = 1 THEN N' INNER JOIN #subComponents cf ON cf.subcomponent_name = em.subcomponent_name'
                ELSE N''
            END + N'
            WHERE om.operation_id = @id' +
            CASE
                WHEN NULLIF(@execution_path, '') IS NOT NULL THEN N' AND (EXISTS(SELECT 1 FROM #execution_paths f WHERE em.execution_path LIKE f.filter AND f.exclusive = 0) AND NOT EXISTS(SELECT 1 FROM #execution_paths f WHERE em.execution_path LIKE f.filter AND f.exclusive = 1))'
                ELSE N''
            END + 
            CASE
                WHEN NULLIF(@msg_filter, '') IS NOT NULL THEN  N' AND (EXISTS(SELECT 1 FROM #msg_filters mf WHERE om.message LIKE mf.filter AND mf.exclusive = 0) AND NOT EXISTS(SELECT 1 FROM #msg_filters mf WHERE om.message LIKE mf.filter AND mf.exclusive = 1))'
                ELSE N''
            END +
            CASE
                WHEN NULLIF(@package_path, '') IS NOT NULL THEN N' AND (EXISTS(SELECT 1 FROM #package_paths f WHERE em.package_path LIKE f.filter AND f.exclusive = 0) AND NOT EXISTS(SELECT 1 FROM #package_paths f WHERE em.package_path LIKE f.filter AND f.exclusive = 1))'
                ELSE N''
            END + N'
            ORDER BY 
                 om.message_time' + CASE WHEN @useTimeDescenting = 1THEN  N' DESC' ELSE N' ASC' END + N'
                ,om.operation_message_id' + CASE WHEN @useTimeDescenting = 1THEN  N' DESC' ELSE N' ASC' END 



            SET @msg = N' - Processing Event Messages... (' + ISNULL(N'last ' + CONVERT(nvarchar(10), @max_messages), N'All') + N' rows)';
            RAISERROR(@msg, 0, 0) WITH NOWAIT;
            IF @taskFilter = 1
            BEGIN
                SET @msg = N'   - Using Task Filter(s): ' + @task_filter
                RAISERROR(@msg, 0, 0) WITH NOWAIT;
            END
            IF @taskFilter = 1
            BEGIN
                SET @msg = N'   - Using Event Filter(s): ' + @event_filter
                RAISERROR(@msg, 0, 0) WITH NOWAIT;
            END
            IF @subcomponentFilter = 1
            BEGIN
                SET @msg = N'   - Using SubComponent Filter(s): ' + @subcomponent_filter
                RAISERROR(@msg, 0, 0) WITH NOWAIT;
            END

            EXEC sp_executesql @sql, N'@id bigint, @max_messages int, @execution_path nvarchar(max), @package_path nvarchar(max), @event_filter nvarchar(max), @msg_filter nvarchar(max)', 
                @id, @max_messages, @execution_path, @package_path, @event_filter, @msg_filter
        END
        ELSE
        BEGIN
            SET @msg = N' - No Event Messasges were found for execution_id = ' + CONVERT(nvarchar(20), @id)
            RAISERROR(@msg, 0, 0) WITH NOWAIT;
        END
    END --IF @includeMessages = 1

    /* EXECUTABLE DATA STATISTICS */
    IF @includeEDS = 1 AND EXISTS(SELECT 1 FROM [internal].[execution_data_statistics] WHERE execution_id = @id)
    BEGIN
        SET @sql = N'
            SELECT ' + CASE WHEN @edsRows IS NOT NULL THEN N' TOP (@edsRows) ' ELSE N'' END + N'
                 eds.[data_stats_id]
                ,eds.[created_time]
                ,eds.[package_name]
                ,eds.[task_name]
                ,eds.[rows_sent]
                ,eds.[source_component_name]
                ,eds.[destination_component_name]
                ,eds.[dataflow_path_id_string]
                ,eds.[dataflow_path_name]
                ,eds.[execution_path]
                ,eds.[package_path_full]
                ,eds.[package_location_type]
              FROM [SSISDB].[internal].[execution_data_statistics] eds WITH(NOLOCK) 
    ' +
        CASE 
            WHEN @pkgFilter = 1 THEN N' INNER JOIN #packages pkg ON pkg.package_name = eds.package_name'
            ELSE ''
        END + N'
             WHERE eds.execution_id = @id' +
        CASE
            WHEN NULLIF(@execution_path, '') IS NOT NULL THEN N' AND (EXISTS(SELECT 1 FROM #execution_paths f WHERE eds.execution_path LIKE f.filter AND f.exclusive = 0) AND NOT EXISTS(SELECT 1 FROM #execution_paths f WHERE eds.execution_path LIKE f.filter AND f.exclusive = 1))'
            ELSE N''
        END + 
        CASE
            WHEN NULLIF(@package_path, '') IS NOT NULL THEN N' AND (EXISTS(SELECT 1 FROM #package_paths f WHERE eds.package_path_full LIKE f.filter AND f.exclusive = 0) AND NOT EXISTS(SELECT 1 FROM #package_paths f WHERE eds.package_path_full LIKE f.filter AND f.exclusive = 1))'
            ELSE N''
        END + N'
             ORDER BY created_time ' + CASE WHEN @useTimeDescenting = 1THEN  N' DESC' ELSE N' ASC' END 
        
        SET @msg = N' - Processing Execution Data Statistics... (' + ISNULL(N'last ' + CONVERT(nvarchar(10), @edsRows), N'All') + N' rows)';
        RAISERROR(@msg, 0, 0) WITH NOWAIT;

        EXEC sp_executesql @sql, N'@id bigint, @edsRows int, @package_path nvarchar(max), @execution_path nvarchar(max)', @id, @edsRows, @package_path, @execution_path
    END --IF @includeEDS = 1 AND EXISTS(SELECT 1 FROM [internal].[execution_data_statistics] WHERE execution_id = @id)
    ELSE IF @includeEDS = 1
    BEGIN
        SET @msg = N' - No Execution Data Statistics were found for execution_id = ' + CONVERT(nvarchar(20), @id)
        RAISERROR(@msg, 0, 0) WITH NOWAIT;
    END --ELSE IF @includeEDS = 1

    /* EXECUTION COMPONENT PHASES */
    IF @includeECP = 1 AND EXISTS(SELECT 1 FROM internal.execution_component_phases WHERE execution_id = @id)
    BEGIN
        IF (@phase_filter IS NOT NULL)
        BEGIN
            --temp table to hold folders
            IF OBJECT_ID('tempdb..#phases') IS NOT NULL
	            DROP TABLE #phases;
            CREATE TABLE #phases (
	            phase	nvarchar(128) COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY CLUSTERED
            )

            SET @xml = N'<i>' + REPLACE(@phase_filter, N',', N'</i><i>') + N'</i>'

            --get unique phases
            DECLARE @basePhases TABLE (
                phase nvarchar(128)
            )
            INSERT INTO @basePhases(phase) 
            SELECT phase 
            FROM internal.execution_component_phases 
            WHERE execution_id = @id  AND phase IS NOT NULL
            GROUP BY phase

            
            INSERT INTO #phases(phase)
            SELECT
                bp.phase
            FROM @basePhases bp
            INNER JOIN (SELECT DISTINCT LTRIM(RTRIM(n.value('.','nvarchar(128)'))) fld FROM @xml.nodes('/i') T(n)) T(Fld) ON bp.phase LIKE T.Fld AND LEFT(T.Fld, 1) <> '-'
            EXCEPT
	        SELECT
		        bp.phase
	        FROM @basePhases bp
            INNER JOIN (SELECT DISTINCT LTRIM(RTRIM(n.value('.','nvarchar(128)'))) fld FROM @xml.nodes('/i') T(n)) T(Fld) ON bp.phase LIKE RIGHT(T.Fld, LEN(T.Fld) -1) AND LEFT(T.Fld, 1) = '-'
            
            IF EXISTS(SELECT 1 fld FROM @xml.nodes('/i') T(n))
            BEGIN
                SET @phaseFilter = 1               
                SET @phase_filter = REPLACE(STUFF((SELECT DISTINCT ', ' + LTRIM(RTRIM(n.value('.','nvarchar(128)'))) FROM @xml.nodes('/i') T(n) FOR XML PATH('')), 1, 2, ''), N'%', N'%%')
            END
        END

        IF (@task_filter IS NOT NULL)
        BEGIN
            --temp table to hold folders
            TRUNCATE TABLE #tasks

            SET @xml = N'<i>' + REPLACE(@task_filter, N',', N'</i><i>') + N'</i>'

            --get unique phases
            DECLARE @baseTasks TABLE (
                task_name nvarchar(128)
            )
            INSERT INTO @baseTasks(task_name) 
            SELECT task_name 
            FROM internal.execution_component_phases 
            WHERE execution_id = @id  AND task_name IS NOT NULL
            GROUP BY task_name

            
            INSERT INTO #tasks(task_name)
            SELECT
                bt.task_name
            FROM @baseTasks bt
            INNER JOIN (SELECT DISTINCT LTRIM(RTRIM(n.value('.','nvarchar(128)'))) fld FROM @xml.nodes('/i') T(n)) T(Fld) ON bt.task_name LIKE T.Fld AND LEFT(T.Fld, 1) <> '-'
            EXCEPT
	        SELECT
		        bt.task_name
	        FROM @baseTasks bt
            INNER JOIN (SELECT DISTINCT LTRIM(RTRIM(n.value('.','nvarchar(128)'))) fld FROM @xml.nodes('/i') T(n)) T(Fld) ON bt.task_name LIKE RIGHT(T.Fld, LEN(T.Fld) -1) AND LEFT(T.Fld, 1) = '-'
            
            IF EXISTS(SELECT 1 fld FROM @xml.nodes('/i') T(n))
            BEGIN
                SET @taskFilter = 1               
                SET @task_filter = REPLACE(STUFF((SELECT DISTINCT ', ' + LTRIM(RTRIM(n.value('.','nvarchar(128)'))) FROM @xml.nodes('/i') T(n) FOR XML PATH('')), 1, 2, ''), N'%', N'%%')
            END
            ELSE
                SET @taskFilter = 0
        END

        IF (@subcomponent_filter IS NOT NULL)
        BEGIN
            --temp table to hold folders
            TRUNCATE TABLE #subComponents;

            SET @xml = N'<i>' + REPLACE(@subcomponent_filter, N',', N'</i><i>') + N'</i>'

            --get unique phases
            DECLARE @baseSubcomponentsP TABLE (
                subcomponent_name nvarchar(4000)
            )

            INSERT INTO @baseSubcomponentsP(subcomponent_name) 
            SELECT cp.subcomponent_name
            FROM internal.execution_component_phases cp
            WHERE execution_id = @id AND subcomponent_name IS NOT NULL
            GROUP BY cp.subcomponent_name


            INSERT INTO #subComponents(subcomponent_name)
            SELECT
                bs.subcomponent_name
            FROM @baseSubcomponentsP bs
            INNER JOIN (SELECT DISTINCT LTRIM(RTRIM(n.value('.','nvarchar(4000)'))) fld FROM @xml.nodes('/i') T(n)) T(Fld) ON bs.subcomponent_name LIKE T.Fld AND LEFT(T.Fld, 1) <> '-'
            EXCEPT
            SELECT
                bs.subcomponent_name
            FROM @baseSubcomponentsP bs
            INNER JOIN (SELECT DISTINCT LTRIM(RTRIM(n.value('.','nvarchar(4000)'))) fld FROM @xml.nodes('/i') T(n)) T(Fld) ON bs.subcomponent_name LIKE RIGHT(T.Fld, LEN(T.Fld) -1) AND LEFT(T.Fld, 1) = '-'

            
            IF EXISTS(SELECT 1 fld FROM @xml.nodes('/i') T(n))
            BEGIN
                SET @subcomponentFilter = 1               
                SET @subcomponent_filter = REPLACE(STUFF((SELECT DISTINCT ', ' + LTRIM(RTRIM(n.value('.','nvarchar(128)'))) FROM @xml.nodes('/i') T(n) FOR XML PATH('')), 1, 2, ''), N'%', N'%%')
            END
            ELSE
                SET @subcomponentFilter = 0
        END


        SET @sql = N'
            SELECT ' + CASE WHEN @ecpRows IS NOT NULL THEN N' TOP (@ecpRows) ' ELSE N'' END + N'
                sp.phase_stats_id       AS [phase_stats_id]
                ,sp.package_name        AS [package_name]
                ,sp.task_name           AS [task_name]
                ,sp.subcomponent_name   AS [subcomponent_name]
                ,sp.phase               AS [phase]
                ,sp.phase_time          AS [start_time]
                ,ep.phase_time          AS [end_time]
                ,CONVERT(time, DATEADD(MICROSECOND, DATEDIFF(MILLISECOND, sp.phase_time, ISNULL(ep.phase_time, SYSDATETIMEOFFSET())), CONVERT(datetime2, ''1900-01-01''))) AS Duration
                ,sp.sequence_id         AS [sequence]   
                ,sp.execution_path      AS [execution_path]
                ,sp.package_path_full   AS [package_path]

            FROM internal.execution_component_phases sp WITH(NOLOCK) 
        ' +
        CASE 
            WHEN @pkgFilter = 1 THEN N' INNER JOIN #packages pkg ON pkg.package_name = sp.package_name'
            ELSE N''
        END +
        CASE 
            WHEN @phaseFilter = 1 THEN N' INNER JOIN #phases ph ON ph.phase = sp.phase'
            ELSE N''
        END +
        CASE 
            WHEN @taskFilter = 1 THEN N' INNER JOIN #tasks tf ON tf.task_name = sp.task_name'
            ELSE N''
        END +
        CASE 
            WHEN @subcomponentFilter = 1 THEN N' INNER JOIN #subComponents cf ON cf.subcomponent_name = sp.subcomponent_name'
            ELSE N''
        END + N'
            LEFT JOIN internal.execution_component_phases ep WITH(NOLOCK) ON   sp.[phase_stats_id] != ep.[phase_stats_id]
                                                                        AND sp.[execution_id] = ep.[execution_id]
                                                                        AND sp.[sequence_id] = ep.[sequence_id]
            WHERE
                sp.[is_start] = 1 
                AND 
                (ep.[is_start] = 0 OR ep.[is_start] is null)
                AND 
                sp.execution_id = @id' +
        CASE
            WHEN NULLIF(@execution_path, '') IS NOT NULL THEN N' AND sp.execution_path LIKE @execution_path'
            ELSE N''
        END + 
        CASE
            WHEN NULLIF(@package_path, '') IS NOT NULL THEN N' AND sp.package_path_full LIKE @package_path'
            ELSE N''
        END + N'
             ORDER BY ' + CASE WHEN @useStartTime =1 THEN N'ISNULL(sp.phase_time, ''9999-12-31'')' WHEN @useEndTime = 1 THEN N'ISNULL(ep.phase_time, ''9999-12-31'')' ELSE N'sp.sequence_id' END + CASE WHEN @useTimeDescenting = 1THEN  N' DESC' ELSE N' ASC' END 
        
        SET @msg = N' - Processing Execution Component Phases... (' + ISNULL(N'last ' + CONVERT(nvarchar(10), @ecpRows), N'All') + N' rows)';
        RAISERROR(@msg, 0, 0) WITH NOWAIT;
        IF @phaseFilter = 1
        BEGIN
            SET @msg = N'   - Using Phase Filter(s): ' + @phase_filter
            RAISERROR(@msg, 0, 0) WITH NOWAIT;
        END
        IF @taskFilter = 1
        BEGIN
            SET @msg = N'   - Using Task Filter(s): ' + @task_filter
            RAISERROR(@msg, 0, 0) WITH NOWAIT;
        END
        IF @subcomponentFilter = 1
        BEGIN
            SET @msg = N'   - Using SubComponent Filter(s): ' + @subcomponent_filter
            RAISERROR(@msg, 0, 0) WITH NOWAIT;
        END
        
        EXEC sp_executesql @sql, N'@id bigint, @ecpRows int, @package_path nvarchar(max), @execution_path nvarchar(max)', @id, @ecpRows, @package_path, @execution_path
    END --IF @includeECP = 1 AND EXISTS(SELECT 1 FROM internal.execution_component_phases WHERE execution_id = @id)
    ELSE IF @includeECP = 1
    BEGIN
        SET @msg = N' - No Execution Component Phases were found for execution_id = ' + CONVERT(nvarchar(20), @id);
        RAISERROR(@msg, 0, 0) WITH NOWAIT;
    END --ELSE IF @includeECP = 1

END
GO
--GRANT EXECUTE permission on the stored procedure to [ssis_admin] role
GRANT EXECUTE ON [dbo].[sp_ssisdb] TO [ssis_admin]
GO