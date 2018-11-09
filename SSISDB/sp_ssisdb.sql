IF NOT EXISTS(SELECT 1 FROM sys.databases where name = 'SSISDB')
BEGIN
    RAISERROR(N'SSIS Database Does not Exists', 15, 0)
    SET NOEXEC ON;
END
GO
USE [master]
GO
RAISERROR('Creating skeleton procedure in the master database for [dbo].[sp_ssisdb]', 0, 0) WITH NOWAIT;
IF NOT EXISTS(SELECT * FROM sys.procedures WHERE object_id = OBJECT_ID('[dbo].[sp_ssisdb]'))
    EXEC (N'CREATE PROCEDURE [dbo].[sp_ssisdb] AS PRINT ''Placeholder for [dbo].[sp_ssisdb]''')
GO
/* ****************************************************
sp_ssisdb: This is skeleton stored procedure for the sp_ssisdb located in the [SSISDB] database

Feedback: mailto:pavel.pawlowski@hotmail.cz

MIT License

Copyright (c) 2017-2018 Pavel Pawlowski

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

 ******************************************************* */
ALTER PROCEDURE [dbo].[sp_ssisdb]
     @op                    nvarchar(max)	= NULL                  --Operator parameter - universal operator for setting large range of conditions and filters
    ,@status                nvarchar(max)   = NULL                  --Comma separated list of execution statuses to return. Default NULL means all. See below for more details
    ,@folder                nvarchar(max)	= NULL                  --Comma separated list of folder filters. Default NLL means no filtering. See below for more details
    ,@project               nvarchar(max)   = NULL                  --Comma separated list of project filters. Default NULL means no filtering. See below for more details
    ,@package               nvarchar(max)   = NULL                  --Comma separated list of package filters. Default NULL means no filtering. See below for more details
    ,@msg_type              nvarchar(max)   = NULL                  --Comma separated list of Message types to show
    ,@event_filter          nvarchar(max)   = NULL                  --Comma separated list of event LIKE filters. Used only for detailed results filtering
    ,@phase_filter          nvarchar(max)   = NULL                  --Comma separated list of phase LIKE filters. Used only for detailed results filtering
    ,@task_filter           nvarchar(max)   = NULL                  --Comma separated list of task LIKE filters. Used only for detailed results filtering
    ,@subcomponent_filter   nvarchar(max)   = NULL                  --Comma separated list of sub-component LIKE filters. Used only for detailed results filtering.
    ,@package_path          nvarchar(max)   = NULL                  --LIKE filter to be applied on package path fields. Used only for detailed results filtering
    ,@execution_path        nvarchar(max)   = NULL                  --LIKE filter to be applied on execution path fields. Used only for detailed results filtering
    ,@msg_filter            nvarchar(max)   = NULL                  --LIKE filter to be applied on message text. Used only for detailed results filtering
    ,@src_component_name    nvarchar(max)   = NULL                  --LIKE filter to be applied on data statistics as srouce_component_name. Used only for detailed results filtering
    ,@dst_component_name    nvarchar(max)   = NULL                  --LIKE filter to be applied on execution data statistics as destination_component_name. Used only for detailed results filtering
AS
EXEC [SSISDB].[dbo].[sp_ssisdb]
         @op                  = @op                 
        ,@status              = @status             
        ,@folder              = @folder             
        ,@project             = @project            
        ,@package             = @package            
        ,@msg_type            = @msg_type           
        ,@event_filter        = @event_filter       
        ,@phase_filter        = @phase_filter       
        ,@task_filter         = @task_filter        
        ,@subcomponent_filter = @subcomponent_filter
        ,@package_path        = @package_path       
        ,@execution_path      = @execution_path     
        ,@msg_filter          = @msg_filter         
        ,@src_component_name  = @src_component_name 
        ,@dst_component_name  = @dst_component_name 
GO
USE [SSISDB]
GO
RAISERROR('Creating procedure [dbo].[sp_ssisdb] is [SSISDB]', 0, 0) WITH NOWAIT;
IF NOT EXISTS(SELECT * FROM sys.procedures WHERE object_id = OBJECT_ID('[dbo].[sp_ssisdb]'))
    EXEC (N'CREATE PROCEDURE [dbo].[sp_ssisdb] AS PRINT ''Placeholder for [dbo].[sp_ssisdb]''')
GO
/* ****************************************************
sp_ssisdb v 0.85 (2018-11-08)

Feedback: mailto:pavel.pawlowski@hotmail.cz

MIT License

Copyright (c) 2017-2018 Pavel Pawlowski

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
     @op                    nvarchar(max)	= NULL                  --Operator parameter - universal operator for setting large range of conditions and filters
    ,@status                nvarchar(max)   = NULL                  --Comma separated list of execution statuses to return. Default NULL means all. See below for more details
    ,@folder                nvarchar(max)	= NULL                  --Comma separated list of folder filters. Default NLL means no filtering. See below for more details
    ,@project               nvarchar(max)   = NULL                  --Comma separated list of project filters. Default NULL means no filtering. See below for more details
    ,@package               nvarchar(max)   = NULL                  --Comma separated list of package filters. Default NULL means no filtering. See below for more details
    ,@msg_type              nvarchar(max)   = NULL                  --Comma separated list of Message types to show
    ,@event_filter          nvarchar(max)   = NULL                  --Comma separated list of event LIKE filters. Used only for detailed results filtering
    ,@phase_filter          nvarchar(max)   = NULL                  --Comma separated list of phase LIKE filters. Used only for detailed results filtering
    ,@task_filter           nvarchar(max)   = NULL                  --Comma separated list of task LIKE filters. Used only for detailed results filtering
    ,@subcomponent_filter   nvarchar(max)   = NULL                  --Comma separated list of sub-component LIKE filters. Used only for detailed results filtering.
    ,@package_path          nvarchar(max)   = NULL                  --LIKE filter to be applied on package path fields. Used only for detailed results filtering
    ,@execution_path        nvarchar(max)   = NULL                  --LIKE filter to be applied on execution path fields. Used only for detailed results filtering
    ,@msg_filter            nvarchar(max)   = NULL                  --LIKE filter to be applied on message text. Used only for detailed results filtering
    ,@src_component_name    nvarchar(max)   = NULL                  --LIKE filter to be applied on data statistics as srouce_component_name. Used only for detailed results filtering
    ,@dst_component_name    nvarchar(max)   = NULL                  --LIKE filter to be applied on execution data statistics as destination_component_name. Used only for detailed results filtering
 ******************************************************* */
ALTER PROCEDURE [dbo].[sp_ssisdb]
     @op                    nvarchar(max)	= NULL                  --Operator parameter - universal operator for setting large range of conditions and filters
    ,@status                nvarchar(max)   = NULL                  --Comma separated list of execution statuses to return. Default NULL means all. See below for more details
    ,@folder                nvarchar(max)	= NULL                  --Comma separated list of folder filters. Default NLL means no filtering. See below for more details
    ,@project               nvarchar(max)   = NULL                  --Comma separated list of project filters. Default NULL means no filtering. See below for more details
    ,@package               nvarchar(max)   = NULL                  --Comma separated list of package filters. Default NULL means no filtering. See below for more details
    ,@msg_type              nvarchar(max)   = NULL                  --Comma separated list of Message types to show
    ,@event_filter          nvarchar(max)   = NULL                  --Comma separated list of event LIKE filters. Used only for detailed results filtering
    ,@phase_filter          nvarchar(max)   = NULL                  --Comma separated list of phase LIKE filters. Used only for detailed results filtering
    ,@task_filter           nvarchar(max)   = NULL                  --Comma separated list of task LIKE filters. Used only for detailed results filtering
    ,@subcomponent_filter   nvarchar(max)   = NULL                  --Comma separated list of sub-component LIKE filters. Used only for detailed results filtering.
    ,@package_path          nvarchar(max)   = NULL                  --LIKE filter to be applied on package path fields. Used only for detailed results filtering
    ,@execution_path        nvarchar(max)   = NULL                  --LIKE filter to be applied on execution path fields. Used only for detailed results filtering
    ,@msg_filter            nvarchar(max)   = NULL                  --LIKE filter to be applied on message text. Used only for detailed results filtering
    ,@src_component_name    nvarchar(max)   = NULL                  --LIKE filter to be applied on data statistics as srouce_component_name. Used only for detailed results filtering
    ,@dst_component_name    nvarchar(max)   = NULL                  --LIKE filter to be applied on execution data statistics as destination_component_name. Used only for detailed results filtering
WITH EXECUTE AS 'AllSchemaOwner'
AS
SET NOCOUNT ON;
DECLARE
	@xml						     xml
    ,@xr                                nvarchar(10)    = N'</i><i>'    --xml replacement'
    ,@defaultLastOp	                    int             = 100           --default number of rows to retrieve
    ,@msg                               nvarchar(max)                   --general purpose message variable
    ,@sql                               nvarchar(max)                   --variable for storing queries to be executed

DECLARE
     @id                                bigint          = NULL  --for storage of execution id to provide detailed output
    ,@opLastCnt                         int             = NULL  --specifies if last count is retrieved
    ,@lastSpecified                     bit             = 0     --Indicates whether the LAST keyword was specified
    ,@opLastGrp                         CHAR(1)	      = NULL  --Specifies type of grouping for Last retrieval
    ,@opFrom                            datetime                --variable to hold initial from date/time value in @op param
    ,@opTo                              datetime                --variable to hold initial to date/time value in @op param
    ,@minInt                            bigint                  --variable to hold min integer passed in @op param
    ,@maxInt                            bigint                  --variable to hold max integer passed in @op param
    ,@opFromTZ                          datetimeoffset          --variable to hold @opFrom value converted to datetimeoffset
    ,@opToTZ                            datetimeoffset          --variable to hold @opTo value converted to datetimeofset
    ,@fldFilter                         bit             = 0     --identifies whether we have a folder filter
    ,@prjFilter                         bit             = 0     --identifies whether we have a project filer
    ,@pkgFilter                         bit             = 0     --identifies whether we have a package filer
    ,@msgTypeFilter                     bit             = 0     --identifies whether we have a message type filter in place
    ,@statusFilter                      bit             = 0     --identifies whether we have a status filter
    ,@includeExecPackages               bit             = 0     --identifies whether executed packages should be included in the list.
    ,@includeMessages                   bit             = 0     --Identifies whether exclude messages in overview list
    ,@includeEDS                        bit             = 0     --Identifies whether executable data statistics should be included in detailed output
    ,@includeECP                        bit             = 0     --Identifies whether execution component phases should be included in the detailed output
    ,@projId                            bigint          = NULL  --project ID or LSN for internal purposes
    ,@force                             bit             = 0     --Specifies whether execution should be forced even large result set should be returned
    ,@totalMaxRows                      int             = NULL
    ,@edsRows                           int             = NULL  --maximum number of EDS rows
    ,@ecpRows                           int             = NULL  --maximum number of ECP rows
    ,@max_messages                      int             = NULL  --Number of messages to include as in-row details
    ,@useStartTime                      bit             = 0     --Use Start Time for searching
    ,@useEndTime                        bit             = 0     --Use End time for searching
    ,@useTimeDescending                 bit             = 1     --Use Descending sort
    ,@execRows                          int             = NULL  --Maximum number or Executable Statistics rows
    ,@includeExecutableStatistics       bit             = 0     --Indicates whether to include Executable Statistics in the output
    ,@help                              bit             = 0     --Indicates that Help should be printed
    ,@phaseFilter                       bit             = 0     --Identifies whether apply phase filter
    ,@taskFilter                        bit             = 0     --Identifies whether apply task filter
    ,@eventFilter                       bit             = 0     --Identifies whether apply event filter
    ,@subComponentFilter                bit             = 0     --Identifies whether apply sub-component filter
    ,@includeAgentReferences            bit             = 0     --Identifies whether to include Agent Job referencing packages
    ,@sourceFilter                      bit             = 0     --Identifies whether to include source_filter for messages
    ,@source_filter                     nvarchar(max)   = NULL
    ,@includeAgentJob                   bit             = 0     --Identifies whether to include information about agent job which executed the package
    ,@decryptSensitive                  bit             = 0     --Identifies whether Decryption of sensitive values in verbose mode should be handled
    ,@processID                         bit             = 0     --Identifies whether filter on process_id should be applied
    ,@callerName                        bit             = 0     --Identifies whether filter on caller names
    ,@stoppedBy                         bit             = 0     --Identifies whether filter on Stopped By Name Filter
    ,@useX86                            bit             = NULL  --Identifies whether filter on the X32 or X64 engine is used
    ,@includeParams                     bit             = 0     --Identifies whether to include execution parameters in execution details
    ,@folderDetail                      bit             = 0     --Identifies whether to include folder details
    ,@projectDetail                     bit             = 0     --Identifies whether to include project details
    ,@objectDetail                      bit             = 0     --Identifies whether to include object details (package details)
    ,@durationCondition                 nvarchar(max)   = NULL  --condition for duration
    ,@durationMsg                       nvarchar(max)   = NULL  --message for duration condition
    ,@tms                               nvarchar(30)    = NULL  --variable to store timestamp data
    ,@debugLevel                        smallint        = 0
    ,@sensitiveAccess                   bit             = 0     --Indicates whether caller have access to senstive infomration
    ,@opValCount                        int             = 0     --Count of operator modifier values
    ,@datetimeMsg                       nvarchar(max)   = NULL  --message for datetime
    ,@dateField                         nvarchar(128)   = NULL  --name of date field
    ,@duration_ms                       bit             = 0     --include duration in ms
    ,@execDetails                       bit             = 0     --include execution details
    ,@localTime                         bit             = 0     --Use LocalTime instead of the datetimeoffset
    ,@pkgSort                           smallint        = 0     --0 derfault start time sorting, 1 = name sorting, 2 = duration sorting, 3 = End time
    ,@pkgSortDesc                       bit             = 1     --1 default sort descending 0 = ascending     
    ,@pkgSortStr                        nvarchar(max)   = NULL
    ,@filterPkg                         bit             = 0     --Specifies whether @packagte filter should be applied also on Executed Packagtes
    ,@filterPkgStatus                   bit             = 0     --Specifies whether @status filter should be applied also on Executed Packages
    ,@filterPkgStatusFilter             nvarchar(max)   = NULL  --contains list of executed packages status filters.
    ,@filterExecutableStatus            bit             = 0     --Specifies whetehr @status filter is applied on Executable Statistics
    ,@filterExecutableStatusFilter      nvarchar(max)   = NULL  --contains list of status filters for Executable Statistics
    ,@availStatusFilter                 nvarchar(max)   = NULL  --contains list of status fulters for package execution statuses
    ,@messageKind                       int             = 3     --Bitmast of message Keinds (bit 1 = Operational, bit 2 = Event)
    ,@messageKindDesc                   nvarchar(max)   = N'OPERATIONAL, EVENT'
    ,@tmp                               nvarchar(max)   = NULL  --Universal temporary variable
    ,@useRuntime                        bit             = 0     --Specifies whether Runtime should be used for searching instead of Create/Start/End time
    ,@detailedMessageTracking           bit             = 0     --enables detailed message tracking to track proper source for all messages

    EXECUTE AS CALLER;
        IF IS_MEMBER('ssis_sensitive_access') = 1 OR IS_MEMBER('db_owner') = 1 OR IS_SRVROLEMEMBER('sysadmin') = 1
            SET @sensitiveAccess = 1
    REVERT;


RAISERROR(N'sp_ssisdb v0.85 (2018-11-08) (c) 2017 - 2018 Pavel Pawlowski', 0, 0) WITH NOWAIT;
RAISERROR(N'============================================================', 0, 0) WITH NOWAIT;
RAISERROR(N'sp_ssisdb provides information about operations in ssisdb', 0, 0) WITH NOWAIT;
RAISERROR(N'', 0, 0) WITH NOWAIT;


DECLARE @valModifiers TABLE (
    Val         nvarchar(10)
    ,Modifier   nvarchar(30)
    ,LeftChars  int
)

INSERT INTO @valModifiers(Val, Modifier, LeftChars)
VALUES
     ('L'       ,'L'                    ,1)         --Last
    ,('L'       ,'LAST'                 ,4)         --Last
    ,('L'       ,'L:'                   ,2)         --Last
    ,('L'       ,'LAST:'                ,5)         --Last
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
    ,('T'       ,'T'                    ,NULL)      --Created
    ,('T'       ,'CREATED'              ,NULL)      --Created
    ,('G'       ,'G'                    ,NULL)      --Stopping
    ,('G'       ,'STOPPING'             ,NULL)      --Stopping
    ,('CD'      ,'CD'                   ,NULL)      --Completed
    ,('CD'      ,'COMPLETED'            ,NULL)      --Completed
    ,('PD'      ,'PD'                   ,NULL)      --Pending
    ,('PD'      ,'PENDING '             ,NULL)      --Pending
    ,('U'       ,'U'                    ,NULL)      --Unexpected
    ,('U'       ,'UNEXPECTED'           ,NULL)      --Unexpected
    ,('FORCE'   ,'FORCE'                ,NULL)      --Force
    ,('?'       ,'?'                    ,NULL)      --Help
    ,('X'       ,'X:'                   ,2)         --Max
    ,('X'       ,'MAX:'                 ,4)         --Max
    ,('EM'      ,'EM'                  ,NULL)         --Include Event Messages
    ,('EM'      ,'EM:'                  ,3)         --Include Event Messages
    ,('EM'      ,'EVENT_MESSAGES:'      ,15)        --Include Event Messages
    ,('V'       ,'V:'                   ,2)         --Verbose
    ,('V'       ,'VERBOSE:'             ,8)         --Verbose
    ,('EDS'     ,'EDS'                  ,3)         --Execution data statistics in details
    ,('EDS'     ,'EDS:'                 ,4)         --Execution data statistics in details
    ,('EDS'     ,'EXECUTION_DATA_STATISTICS:',26)   --Execution data statistics in details
	,('RT'		,'RT'		            ,NULL)			--RunTime specifier
	,('RT'		,'RUN_TIME'		    ,NULL)			--Runtime Specifier
    ,('ST'      ,'ST'                   ,2)         --Use Start TIme
    ,('ST'      ,'START_TIME'           ,10)        --Use Start Time
    ,('ET'      ,'ET'                   ,2)         --Use End TIme
    ,('ET'      ,'END_TIME'             ,8)         --Use EndTime
    ,('CT'      ,'CT'                   ,2)         --Use Create Time
    ,('CT'      ,'CREATE_TIME'          ,1)         --Use Create Time
    ,('ECP'     ,'ECP'                 ,NULL)         --Execution Component Phases
    ,('ECP'     ,'ECP:'                 ,4)         --Execution Component Phases
    ,('ECP'     ,'EXECUTION_COMPONENT_PHASES:', 27)  --Execution Component Phases
    ,('ES'      ,'ES:'                  ,3)         --Executable Statistics
    ,('ES'      ,'EXECUTABLE_STATISTICS:', 22)      --Executable Statistics
    ,('AGR'     ,'AGR'                  ,NULL)      --Include details about SQL Server Agent Jobs referencing package
    ,('AGR'     ,'AGENT_REFERENCES'     ,NULL)      --Include details about SQL Server Agent Jobs referencing package
    ,('AGT'     ,'AGT'                  ,NULL)      --Include details about agent job which initiated the execution
    ,('AGT'     ,'AGENT_JOB'            ,NULL)      --Include details about agent job which initiated the execution
    ,('DS'      ,'DS'                   ,NULL)      --Decrypt sensitive
    ,('DS'      ,'DECRYPT_SENSITIVE'    ,NULL)      --Decrypt sensitive
    ,('>'       ,'>'                    ,1)         --Duration longer than
    ,('>='      ,'>='                   ,2)         --Duration longer or equal to
    ,('<'       ,'<'                    ,1)         --Duration shorter than
    ,('<='      ,'<='                   ,2)         --Duration shorter or equal to
    ,('='       ,'='                    ,1)         --Duration equal to
    ,('PI'      ,'PID:'                 ,4)         --Process ID
    ,('PI'      ,'PROCESS_ID:'          ,11)        --ProcessID
    ,('CN'      ,'CN:'                  ,3)         --Caller Name
    ,('CN'      ,'CALLER_NAME:'         ,12)        --Caller Name
    ,('SB'      ,'SB:'                  ,2)         --Stopped By
    ,('SB'      ,'STOPPED_BY:'          ,10)        --Stopped By
    ,('32B'     ,'32B'                  ,NULL)      --X86 filter
    ,('32B'     ,'32BIT'                ,NULL)      --X86 filter
    ,('64B'     ,'64B'                  ,NULL)      --X64 filter
    ,('64B'     ,'64BIT'                ,NULL)      --X64 filter
    ,('PM'      ,'PM'                   ,NULL)      --Include parameters in execution details - forces ED
    ,('PM'      ,'PARAMS'               ,NULL)      --Include parameters in execution details - forces ED
    ,('FD'      ,'FD'                   ,NULL)      --Include folder details
    ,('FD'      ,'FOLDER_DETAILS'       ,NULL)      --Include folder details
    ,('PRD'     ,'PRD'                  ,NULL)      --Include Project details
    ,('PRD'     ,'PROJECT_DETAILS'      ,NULL)      --Include Project Details
    ,('OD'      ,'OD'                   ,NULL)      --Include Object Details
    ,('OD'      ,'OBJECT_DETAILS'       ,NULL)      --Include Object Details
    ,('MS'      ,'MS'                   ,NULL)      --Milliseconds
    ,('MS'      ,'MILLISECONDS'         ,NULL)      --Milliseconds
    ,('ED'      ,'ED'                   ,NULL)      --include execution details
    ,('ED'      ,'EXECUTION_DETAILS'    ,NULL)      --include execution details
    ,('LT'      ,'LT'                   ,NULL)      --Use Local Time
    ,('LT'      ,'LOCAL_TIME'           ,NULL)      --Use Local Time    
    ,('SP'      ,'SP:'                  ,3)         --Sort Packages
    ,('SP'      ,'SORT_PACKAGES:'       ,14)        --Sort Packages
    ,('FP'      ,'FP'                   ,NULL)      --Filter Pacakges
    ,('FP'      ,'FILTER_PACKAGES'      ,NULL)      --Filter Pacakges
    ,('EPR'     ,'EPR:'                  ,4)        --Filter Executed Pacakges status
    ,('EPR'     ,'EXECUTED_PACKAGES_RESULT:',25)      --Filter Executed Pacakges status
    ,('ESR'     ,'ESR:'                ,4)             --Filter Executable statistics status
    ,('ESR'     ,'EXECUTABLE_STATISTICS_RESULT:',29)    --Filter Executable statistics status
    ,('PES'     ,'PES:'                 ,4)             --Package Execution Status
    ,('PES'     ,'PACKAGE_EXECUTION_STATUS', 24)        --Package Execution Status
	,('MK'		,'MK:'					,3)				--Message Kind
	,('MK'		,'MESSAGE_KIND:'		,12)			--MessageKind
    ,('DMT'     ,'DMT'                  ,NULL)          --Detailed Message Tracking
    ,('DMT'     ,'DETAILED_MESSAGE_TRACKING', NULL)     --Detailed Message Tracking

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
    ,(200   ,N'CUSTOM'                   , N'CS')
    ,(140   ,N'DIAGNOSTICS_EX'           , N'DE')
    ,(400   ,N'NON_DIAGNOSTICS'          , N'ND')
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
    ,(5, N'PENDING'     , N'PD')
    ,(6, N'UNEXPECTED'  , N'U')
    ,(7, N'SUCCESS'     , N'S')
    ,(8, N'STOPPING'    , N'G')
    ,(9, N'COMPLETED'   , N'CD')

DECLARE @availExecStatuses TABLE (
    id          smallint NOT NULL
    ,[status]   nvarchar(20)
    ,short      nvarchar(2)
);

INSERT INTO @availExecStatuses(id, [status], short)
VALUES 
     (0,    N'Success'     , N'S')
    ,(1,    N'Failure'     , N'F')
    ,(2,    N'Completion'  , N'CD')
    ,(3,    N'Cancelled'   , N'C')
    ,(6,    N'Unexpected'  , N'U')
    ,(9,    N'Completed'   , N'P')
    ,(99,   N'Running'     , N'R')


DECLARE @messageKinds TABLE (
    Kind        CHAR(1)         NOT NULL PRIMARY KEY CLUSTERED
    ,BitValue   int             NOT NULL
    ,KindName   nvarchar(20)    NOT NULL
)

INSERT INTO @messageKinds (Kind, BitValue, KindName)
VALUES
    ('O', 1, N'OPERATIONAL')
   ,('E', 2, N'EVENT')

/* Update parameters to NULL where empty strings are passed */
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
    ,@src_component_name    = NULLIF(@src_component_name, N'')
    ,@dst_component_name    = NULLIF(@dst_Component_name, N'')

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
        LEFT JOIN @valModifiers VM ON (OP.Modifier = VM.Modifier AND VM.LeftChars IS NULL) OR (LEFT(OP.Modifier, VM.LeftChars) = VM.Modifier AND OP.Modifier NOT IN (N'LT', N'SP'))
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
       );


    IF EXISTS(SELECT 1 FROM @opValData WHERE Val = N'DBG')
    BEGIN
        SET @debugLevel = ISNULL(NULLIF((SELECT MAX(IntVal) FROM @opValData WHERE Val = N'DBG'), 0), 1)
        
        if(@debugLevel > 1)
            SELECT '@opValData' AS TableName, * FROM @opValData
    END

    IF @debugLevel > 4
    BEGIN
        WITH OPBase AS (
            SELECT
                NULLIF(LTRIM(RTRIM(n.value('.','nvarchar(128)'))), '') AS Modifier
            FROM @xml.nodes('/i') T(N)
	    ), Unknown AS (
            SELECT DISTINCT
                Modifier
            FROM OPBase opb
            EXCEPT
            SELECT
                Modifier
            FROM  @opValData
        )
        SELECT
            Modifier AS UnknownModifier
        FROM Unknown


    END

    --Check for unknown modifiers
    DECLARE @unknownModifiers nvarchar(max) = NULL;
    WITH OPBase AS (
        SELECT
            NULLIF(LTRIM(RTRIM(n.value('.','nvarchar(128)'))), '') AS Modifier
        FROM @xml.nodes('/i') T(N)
	), Unknown AS (
        SELECT DISTINCT
            Modifier
        FROM OPBase opb
        EXCEPT
        SELECT
            Modifier
        FROM  @opValData
    )
    SELECT @unknownModifiers = (
    SELECT
        N'
'+ Modifier
    FROM Unknown
    WHERE Modifier IS NOT NULL AND Modifier <> N''
    FOR XML PATH(N''))

    IF NULLIF(@unknownModifiers, '') IS NOT NULL
    BEGIN        
        SET @help = 1
        SET @unknownModifiers = REPLACE(@unknownModifiers, N'&#x0D;', NCHAR(13));
        RAISERROR(N'There are unknown modifiers specified: %s
        ', 11, 0, @unknownModifiers) WITH NOWAIT;
    END
    ELSE --Check if we have a help modifier
    IF EXISTS(SELECT 1 FROM @opValData WHERE Val = '?')
        SET @help = 1            

    IF @help <> 1
    BEGIN
        RAISERROR('sp_ssisdb ''?'' --to print procedure help', 0, 0) WITH NOWAIT;
        RAISERROR('', 0, 0) WITH NOWAIT;
    END


IF @help <> 1
BEGIN
	INSERT INTO @opVal (Val,  MinDateVal, MaxDateVal, MinIntVal, MaxIntVal, StrVal, DurationDate, OPValCount)
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
            WHEN Val IN ('ST', 'ET', 'CT') THEN MAX(ISNULL(StrVal, ''))
            ELSE NULL
        END AS StrVal
        ,CASE 
            WHEN Val IN (N'>', N'>=') THEN MAX(ISNULL(DurationDate, '1900-01-01'))
            WHEN Val IN (N'<', N'<=', N'=') THEN MIN(ISNULL(DurationDate, '1900-01-01')) 
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

    IF (@debugLevel > 0)
        SELECT '@opVal' AS TableName,  * FROM @opVal

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

    --process_id filter
    IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'PI')
    BEGIN
        SET @msg = STUFF((
            SELECT
                N',' + StrVal
            FROM @opValData
            WHERE 
                Val = N'PI'
                AND
                IntVal IS NULL
            FOR XML PATH('')
        ), 1, 1, N'')

        IF @msg IS NOT NULL
        BEGIN
            RAISERROR(N'"%s" values are not valid integer values for PROCESS_ID filter', 11, 0, @msg) WITH NOWAIT;
            SET @help = 1
        END
        ELSE
        BEGIN
            CREATE TABLE #ProcessID (
                process_id int NOT NULL PRIMARY KEY CLUSTERED
            );

            INSERT INTO #ProcessID(process_id)
            SELECT DISTINCT
                IntVal
            FROM @opValData
            WHERE 
                Val = N'PI'
                AND
                IntVal IS NOT NULL

            SET @processID = 1;
        END
    END

    --created by filter
    IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'CN')
    BEGIN
        SET @callerName = 1;
        CREATE TABLE #callers (
            caller_name nvarchar(128) COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY CLUSTERED
        )

        INSERT INTO #callers (caller_name)
        SELECT DISTINCT
            StrVal
        FROM @opValData
        WHERE 
            Val = N'CN'
    END

    --stopped by filter
    IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'SB')
    BEGIN
        SET @stoppedBy = 1;
        CREATE TABLE #stoppedBy (
            stopped_by_name nvarchar(128) COLLATE DATABASE_DEFAULT NOT NULL PRIMARY KEY CLUSTERED
        )

        INSERT INTO #stoppedBy (stopped_by_name)
        SELECT DISTINCT
            StrVal
        FROM @opValData
        WHERE 
            Val = N'SB'
    END

    --X32 and X64 filter
    IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'32B' OR Val = N'64B')
    BEGIN
        IF NOT (EXISTS(SELECT 1 FROM @opVal WHERE Val = N'32B') AND EXISTS(SELECT 1 FROM @opVal WHERE Val = N'64B'))
        BEGIN
            IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'32B')
                SET @useX86 = 1
            ELSE
                SET @useX86 = 0
        END
    END

    --Add milliseconds duraiton
    IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'MS')
    BEGIN
        SET @duration_ms = 1
    END

    --Local TIme
    IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'LT')
    BEGIN
        SET @localTime = 1
    END

    IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'RT')
    BEGIN
        SET @useRuntime = 1
    END

    --Executed Packages Status Filter
    IF EXISTS(SELECT 1 FROM @opVal WHERE Val = 'EPR')
    BEGIN
         SELECT @filterPkgStatusFilter = NULLIF(StrVal, N'') FROM @opValData WHERE Val = 'EPR' AND StrVal <> 'EPR';
         SET @filterPkgStatus = 1
    END

    --Executable Statistics Status Filter
    IF EXISTS(SELECT 1 FROM @opVal WHERE Val = 'ESR')
    BEGIN
         SELECT @filterExecutableStatusFilter = NULLIF(StrVal, N'') FROM @opValData WHERE Val = 'ESR' AND StrVal <> 'ESR';
         SET @filterExecutableStatus = 1         
    END


    --Sort Packages
    IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'SP')
    BEGIN
        DECLARE @pkgSorts TABLE (
            val nvarchar(128)
        )
        DECLARE 
            @pkgMultiSort   bit = 0
            ,@pkgOrdSpec    bit = 0
            ,@pkgSortSpec   bit = 0

        IF (SELECT OPValCount FROM @opVal WHERE Val = N'SP') > 1
        BEGIN
            RAISERROR(N'Multiple Sort Packages modifiers specified', 11, 0) WITH NOWAIT;
            SET @help = 1
        END
        ELSE
        BEGIN
            SELECT @pkgSortStr = NULLIF(StrVal, N'') FROM @opValData WHERE Val = 'SP';
            IF @pkgSortStr IS NULL
            BEGIN
                RAISERROR(N'No Sort Order specifies for the Sort Pacakges Modifier', 11, 0) WITH NOWAIT;
                SET @help = 1;
            END
            ELSE
            BEGIN
                SET @xml = '<i>' + REPLACE(@pkgSortStr, ',', @xr) + '</i>';
                WITH Sorts AS (
                    SELECT DISTINCT
                        RTRIM(LTRIM(N.value('.', 'nvarchar(128)'))) val
                    FROM @xml.nodes('i') T(N)
                )
                INSERT INTO @pkgSorts(val)
                SELECT
                    val
                FROM Sorts;

                SET @pkgSortStr = NULL;
                SET @pkgSortStr = STUFF((
                SELECT
                    ', ' + val
                FROM @pkgSorts
                WHERE
                    UPPER(val) NOT IN (N'N', N'NAME', N'D', N'S', N'START', N'START_TIME', N'DUR', N'DURATION', N'E', N'END', N'END_TIME', N'R', 'RES', 'RESULT', N'RC', 'RES_CODE', 'RESULT_CODE', N'A', N'ASC', N'ASCENDING', N'DESC', N'DESCENDING')
                FOR XML PATH('')), 1, 2, '');
                
                IF @pkgSortStr IS NOT NULL
                BEGIN
                    RAISERROR (N'Unknown Package Sort Order Specifiers: %s', 11, 0, @pkgSortStr) WITH NOWAIT;
                    SET @help = 1
                END
                ELSE
                BEGIN                
                    IF EXISTS(SELECT 1 FROM @pkgSorts WHERE UPPER(val) IN (N'N', N'NAME'))
                    BEGIN
                        SET @pkgSort = 1;
                        SET @pkgSortSpec = 1
                    END
                    IF EXISTS(SELECT 1 FROM @pkgSorts WHERE UPPER(val) IN (N'S', N'START', N'START_TIME'))
                    BEGIN
                        IF @pkgSortSpec <> 0 
                            SET @pkgMultiSort = 1;
                        ELSE 
                            SET @pkgSort = 0;
                        SET @pkgSortSpec = 1
                    END
                    IF EXISTS(SELECT 1 FROM @pkgSorts WHERE UPPER(val) IN (N'D', N'DUR', N'DURATION'))
                    BEGIN
                        IF @pkgSortSpec <> 0 
                            SET @pkgMultiSort = 1;
                        ELSE 
                            SET @pkgSort = 2;
                        SET @pkgSortSpec = 1
                    END
                    IF EXISTS(SELECT 1 FROM @pkgSorts WHERE UPPER(val) IN (N'E', N'END', N'END_TIME'))
                    BEGIN
                        IF @pkgSortSpec <> 0 
                            SET @pkgMultiSort = 1;
                        ELSE 
                            SET @pkgSort = 3;
                        SET @pkgSortSpec = 1
                    END
                    IF EXISTS(SELECT 1 FROM @pkgSorts WHERE UPPER(val) IN (N'R', 'RES', 'RESULT'))
                    BEGIN
                        IF @pkgSortSpec <> 0 
                            SET @pkgMultiSort = 1;
                        ELSE 
                            SET @pkgSort = 4;
                        SET @pkgSortSpec = 1
                    END
                    IF EXISTS(SELECT 1 FROM @pkgSorts WHERE UPPER(val) IN (N'RC', 'RES_CODE', 'RESULT_CODE'))
                    BEGIN
                        IF @pkgSortSpec <> 0 
                            SET @pkgMultiSort = 1;
                        ELSE 
                            SET @pkgSort = 5;
                        SET @pkgSortSpec = 1
                    END


                    IF EXISTS(SELECT 1 FROM @pkgSorts WHERE UPPER(val) IN (N'A', N'ASC', N'ASCENDING'))
                    BEGIN
                        SET @pkgSortDesc = 0;
                        SET @pkgOrdSpec = 1;
                    END
                    IF EXISTS(SELECT 1 FROM @pkgSorts WHERE UPPER(val) IN (N'DESC', N'DESCENDING'))
                    BEGIN
                        IF @pkgOrdSpec = 1
                            SET @pkgMultiSort = 1;
                        ELSE
                            SET @pkgSortDesc = 1;
                    END

                    IF @pkgMultiSort = 1
                    BEGIN
                        RAISERROR(N'Multiple Sort Package Sort Orders defined for packages Sort', 11, 0) WITH NOWAIT;
                        SET @help = 1
                    END
                END
            END
        END
    END

END

IF @help <> 1
BEGIN
        RAISERROR(N'Information to Retrieve:', 0, 0) WITH NOWAIT;
        RAISERROR(N'------------------------', 0, 0) WITH NOWAIT;

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

            RAISERROR(N'   - Duration: %s', 0, 0, @durationMsg  ) WITH NOWAIT;
        END


        IF @id IS NOT NULL OR EXISTS(SELECT 1 FROM @opVal WHERE Val = 'V')
        BEGIN   /*Verbose params processing */      
            SET @id = (SELECT MaxIntVal FROM @opVal WHERE Val = 'V')
            IF @id <= 1
                SET @id = (SELECT MAX(execution_id) FROM internal.executions WITH(NOLOCK))
            RAISERROR(N' - Verbose information for execution_id = %I64d', 0, 0, @id)


            SET @msg = CASE WHEN @pkgSortDesc = 1 THEN 'Descending' ELSE 'Ascending' END;
            SET @pkgSortStr = CASE @pkgSort 
                                WHEN 1 THEN N'package_name'
                                WHEN 2 THEN N'duration'
                                WHEN 3 THEN N'end_time'
                                WHEN 4 THEN N'result'
                                WHEN 5 THEN N'result_code'
                                ELSE 'start_time'
                              END
            RAISERROR(N'   - Sorting Executed Packages by: %s %s', 0, 0, @pkgSortStr, @msg) WITH NOWAIT;    

            IF @id IS NOT NULL AND NOT EXISTS(SELECT 1 FROM internal.operations WITH(NOLOCK) WHERE operation_id = @id)
            BEGIN
                RAISERROR(N'   << No Executable statistics were found for execution_id = %I64d >>' , 0, 0, @id) WITH NOWAIT;
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

                IF EXISTS(SELECT 1 FROM @opVal WHERE Val = 'DMT')
                    SET @detailedMessageTracking = 1
            END

            IF EXISTS(SELECT 1 FROM @opVal WHERE Val = 'EDS')
            BEGIN
                SET @includeEDS = 1
                SET @edsRows = (SELECT MaxIntVal FROM @opVal WHERE Val = 'EDS')

                IF @edsRows < 0 
                    SET @edsRows = NULL
                ELSE IF @edsRows = 0
                    SET @edsRows = 1000
                SET @msg = CASE WHEN @edsRows IS NULL THEN N'' ELSE N' (last ' + CONVERT(nvarchar(10), @edsRows) + N' rows)' END
                RAISERROR(N'   - Including Executable Data Statistics%s', 0, 0, @msg) WITH NOWAIT;
            END

            IF EXISTS(SELECT 1 FROM @opVal WHERE Val = 'ECP')
            BEGIN
                SET @includeECP = 1;
                SET @ecpRows = (SELECT MaxIntVal FROM @opVal WHERE Val = 'ECP')

                IF @ecpRows < 0
                    SET @ecpRows = NULL
                ELSE IF @ecpRows = 0
                    SET @ecpRows = 1000
                SET @msg = CASE WHEN @edsRows IS NULL THEN N'' ELSE N' (last ' + CONVERT(nvarchar(10), @ecpRows) + N' rows)' END
                RAISERROR(N'   - Including Execution Component Phases%s', 0, 0, @msg) WITH NOWAIT;
            END

            IF EXISTS(SELECT 1 FROM @opVal WHERE Val = 'ES')
            BEGIN
                SET @includeExecutableStatistics = 1
                SET @execRows = (SELECT MaxIntVal FROM @opVal WHERE Val = 'ES')

                IF @execRows < 0
                    SET @execRows = NULL;
                ELSE IF @execRows = 0
                    SET @execRows = 1000;
                SET @msg = CASE WHEN @edsRows IS NULL THEN N'' ELSE N' (last ' + CONVERT(nvarchar(10), @execRows) + N' rows)' END
                RAISERROR(N'   - Including Executable Statistics%s', 0, 0, @msg) WITH NOWAIT;
            END

            --Filter Executed packages
            IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'FP')
            BEGIN
                SET @filterPkg = 1
            END

        END 
        ELSE 
        BEGIN /*Non Verbose Params processing */
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

            --PROCESS_ID filter
            IF @processID = 1
            BEGIN
                SET @msg = STUFF((
                    SELECT
                        N', ' + CONVERT(nvarchar(10), process_id)
                    FROM #ProcessID
                    FOR XML PATH(N'')
                ), 1, 2, N'')

                RAISERROR(N'   - Process ID(s): %s', 0, 0, @msg) WITH NOWAIT;
            END
            
            --Caller Name Filter
            IF @callerName = 1
            BEGIN
                SET @msg = STUFF((
                    SELECT
                        N', ' + caller_name
                    FROM #callers
                    FOR XML PATH(N'')
                ), 1, 2, N'')

                RAISERROR(N' - Callers: %s', 0, 0, @msg) WITH NOWAIT;
            END

            --Stopped By Name Filter
            IF @stoppedBy = 1
            BEGIN
                SET @msg = STUFF((
                    SELECT
                        N', ' + stopped_by_name
                    FROM #stoppedBy
                    FOR XML PATH(N'')
                ), 1, 2, N'')

                RAISERROR(N' - Callers: %s', 0, 0, @msg) WITH NOWAIT;
            END

            --X32 and X64 filters
            IF @useX86 IS NOT NULL
            BEGIN
                SET @msg = CASE WHEN @useX86 = 1 THEN '32' ELSE N'64' END;
                RAISERROR(N' - %s bit executions only', 0, 0, @msg) WITH NOWAIT;
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

                IF @useRuntime = 1 
                    RAISERROR(N'   - Using Runtime for Searching', 0, 0) WITH NOWAIT;

            END


            IF EXISTS(SELECT 1 FROM @opVal WHERE Val IN ('I'))
            BEGIN                
                SELECT
                    @minInt         = MinIntVal
                    ,@maxInt        = MaxIntVal
                    ,@opValCount    = OPValCount
                FROM @opVal
                WHERE Val = 'I'


                IF ISNULL(@minInt, -1) < 0
                    SET @minInt = 0
                IF ISNULL(@maxInt, -1) < 0
                    SET @maxInt = 0
            END

            IF @maxInt IS NOT NULL AND @minInt IS NOT NULL
            BEGIN
                
                IF @maxInt = @minInt 
                    IF @opValCount > 1
                        RAISERROR('   - For execution_id %I64d', 0, 0, @minInt) WITH NOWAIT;
                    ELSE
                        RAISERROR('   - From execution_id %I64d', 0, 0, @minInt) WITH NOWAIT;
                ELSE
                    RAISERROR('   - Execution_id(s) Between %I64d and %I64d', 0, 0, @minInt, @maxInt) WITH NOWAIT;
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

        END /*Non Verbose Params processing */



        /* BEGIN PROCESS STATUSES */
        IF OBJECT_ID('tempdb..#statuses') IS NOT NULL
            DROP TABLE #statuses;
        CREATE TABLE #statuses (
            id          int          NOT NULL PRIMARY KEY CLUSTERED
            ,[status]   nvarchar(50) COLLATE DATABASE_DEFAULT
        );

        IF OBJECT_ID('tempdb..#EPstatuses') IS NOT NULL
            DROP TABLE #EPstatuses;
        CREATE TABLE #EPstatuses (
            id          int          NOT NULL PRIMARY KEY CLUSTERED
            ,[status]   nvarchar(50) COLLATE DATABASE_DEFAULT
        );

        --Force  status filter according the @op param
        IF EXISTS(SELECT 1 FROM @opVal WHERE Val IN ('R', 'S', 'F', 'U', 'C', 'PD', 'T', 'G', 'CD'))
            SET @status = STUFF((SELECT ',' + Val FROM @opVal WHERE Val IN ('R', 'S', 'F', 'U', 'C', 'PD', 'T', 'G', 'CD') FOR XML PATH('')), 1, 1, '');

        --Executable Statistics Status Filter
        IF EXISTS(SELECT 1 FROM @opVal WHERE Val = 'PES')
        BEGIN
            SELECT @availStatusFilter = NULLIF(StrVal, N'') FROM @opValData WHERE Val = 'PES' AND StrVal <> 'PES';
            IF @availStatusFilter IS NOT NULL
                SET @status = @availStatusFilter

        END

        SET @xml = N'<i>' + REPLACE(REPLACE(@status, N',', @xr), N' ', @xr) + N'</i>';

        INSERT INTO #statuses(id, [status])
        SELECT DISTINCT
            ast.id
            ,ast.[status]
        FROM @availStatuses ast
        INNER JOIN (SELECT n.value(N'.', 'nvarchar(50)') value FROM @xml.nodes('/i') T(n)) st([status]) ON LEFT(st.[status], 1) <> '-' AND (st.[status] = ast.[status] OR st.status = ast.short OR st.[status] = 'ALL')
        EXCEPT
        SELECT DISTINCT
            ast.id
            ,ast.[status]
        FROM @availStatuses ast
        INNER JOIN (SELECT n.value(N'.', 'nvarchar(50)') value FROM @xml.nodes('/i') T(n)) st([status]) ON LEFT(st.[status], 1) = '-' AND (RIGHT(st.[status], LEN(st.[status]) -1) = ast.[status] OR RIGHT(st.[status], LEN(st.[status]) -1) = ast.short)

        --if there are some statuses selected but not all, then set status filter
        IF @id IS NULL AND (SELECT COUNT(1) FROM #statuses) BETWEEN 1 AND 8
        BEGIN
            SET @statusFilter = 1
            SET @msg = N' - Filtering for statuses: ' + STUFF((SELECT ', ' + s.status FROM #statuses s FOR XML PATH('')), 1, 2, '')
            RAISERROR(@msg, 0, 0) WITH NOWAIT;
        END    
        
        --Check if we have executed packages status filter
        IF @filterPkgStatus = 1
        BEGIN
            IF @filterPkgStatusFilter IS NOT NULL AND @filterPkgStatusFilter <> N'' --Only if statuses were provided
            BEGIN
                SET @xml = N'<i>' + REPLACE(REPLACE(@filterPkgStatusFilter, N',', @xr), N' ', @xr) + N'</i>'

                INSERT INTO #EPstatuses(id, [status])
                SELECT DISTINCT
                    ast.id
                    ,ast.[status]
                FROM @availExecStatuses ast
                INNER JOIN (SELECT n.value(N'.', 'nvarchar(50)') value FROM @xml.nodes('/i') T(n)) st([status]) ON LEFT(st.[status], 1) <> '-' AND (st.[status] = ast.[status] OR st.status = ast.short OR st.[status] = 'ALL')
                EXCEPT
                SELECT DISTINCT
                    ast.id
                    ,ast.[status]
                FROM @availExecStatuses ast
                INNER JOIN (SELECT n.value(N'.', 'nvarchar(50)') value FROM @xml.nodes('/i') T(n)) st([status]) ON LEFT(st.[status], 1) = '-' AND (RIGHT(st.[status], LEN(st.[status]) -1) = ast.[status] OR RIGHT(st.[status], LEN(st.[status]) -1) = ast.short)

            END

            IF NOT((SELECT COUNT(1) FROM #EPstatuses) BETWEEN 1 AND 6)
            BEGIN
                SET @filterPkgStatus = 0
            END
        END              

        --Event Messages
        IF EXISTS(SELECT 1 FROM @opVal WHERE Val = 'MK')
        BEGIN
            SELECT @tmp = NULLIF(StrVal, N'') FROM @opValData WHERE Val = 'MK' AND StrVal <> 'MK';
            IF @tmp IS NOT NULL
            BEGIN
                SET @xml = N'<i>' + REPLACE(REPLACE(@tmp, N',', @xr), N' ', @xr) + N'</i>'

                SET @messageKind = 0;
                SET @messageKindDesc = N'';

                SELECT 
                    @messageKind = @messageKind | mk.BitValue
                    ,@messageKindDesc = @messageKindDesc + N', ' + mk.KindName                    
                FROM @xml.nodes('/i') T(n)
                INNER JOIN @messageKinds mk ON RTRIM(LTRIM(T.n.value('.', N'char(1)'))) = mk.Kind

                SET @messageKindDesc = STUFF(@messageKindDesc, 1, 2, N'');
            END
        END



    IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'EP')
    BEGIN
        SET @includeExecPackages = 1;
        RAISERROR(N' - Including information about executed packages', 0, 0) WITH NOWAIT;
        SET @msg = CASE WHEN @pkgSortDesc = 1 THEN 'Descending' ELSE 'Ascending' END;
        SET @pkgSortStr = CASE @pkgSort 
                                WHEN 1 THEN N'package_name'
                                WHEN 2 THEN N'duration'
                                WHEN 3 THEN N'end_time'
                                WHEN 4 THEN N'result'
                                WHEN 5 THEN N'result_code'
                                ELSE 'start_time'
                          END
        RAISERROR(N'   - Sorting Packages by: %s %s', 0, 0, @pkgSortStr, @msg) WITH NOWAIT;   
        
        IF @filterPkgStatus = 1
        BEGIN
            SET @msg = N'   - Using Result Filter(s): ' + STUFF((SELECT ', ' + s.status FROM #EPstatuses s FOR XML PATH('')), 1, 2, '')
            RAISERROR(@msg, 0, 0) WITH NOWAIT;        
        END 
    END
    
    /* General Params processing */  
    IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'AGR')
    BEGIN
        SET @includeAgentReferences = 1;
        RAISERROR(N' - Including information about Agent Job Steps referencing the package', 0, 0) WITH NOWAIT;
    END

    IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'AGT')
    BEGIN
        SET @includeAgentJob = 1
        RAISERROR(N' - Including information about Agent Job Step invoking the execution', 0, 0) WITH NOWAIT;
    END

    IF @id IS NULL AND @opLastCnt IS NULL AND @opFromTZ IS NULL AND @minInt IS NULL AND @lastSpecified = 0 AND @processID = 0
    BEGIN
        SET @opLastCnt = @defaultLastOp;
        RAISERROR(N'   - default Last %d operations', 0, 0, @opLastCnt) WITH NOWAIT;
    END


    --Include parameters
    IF EXISTS(SELECT 1 FROM @opVal WHERE Val IN  (N'ED', N'PM'))
    BEGIN
        SET @execDetails   = 1
        RAISERROR(N'   - Including Execution Details', 0, 0) WITH NOWAIT;
    END
    --Include parameters
    IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'PM')
    BEGIN
        SET @includeParams = 1
        SET @execDetails   = 1
        RAISERROR(N'   - Including Execution Paramteres in details', 0, 0) WITH NOWAIT;
    END

    --Decrypting sensitive
    IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'DS' AND @sensitiveAccess = 1)
    BEGIN
        SET @decryptSensitive = 1;
        RAISERROR(N'   - DECRYPTING SENSITIVE DATA', 0, 0) WITH NOWAIT;
    END

    --Folder Detail
    IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'FD')
    BEGIN
        SET @folderDetail = 1;
        RAISERROR(N'   - Including Folder Details', 0, 0) WITH NOWAIT;
    END

    --Project Detail
    IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'PRD')
    BEGIN
        SET @projectDetail = 1;
        RAISERROR(N'   - Including Project Details', 0, 0) WITH NOWAIT;
    END

    --Object Detail
    IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'OD')
    BEGIN
        SET @objectDetail = 1;
        RAISERROR(N'   - Including Object Details', 0, 0) WITH NOWAIT;
    END


    --Sorting processing
    IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'ST')
    BEGIN
        IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'ST' AND StrVal IN ('_A', '_ASC','A','ASC'))
            SET @useTimeDescending = 0;

        SET @useStartTime = 1;

        SET @msg = CASE WHEN @useTimeDescending = 0 THEN 'Ascending' ELSE N'Descending' END
        RAISERROR(N' - Sort by Start Time %s', 0, 0, @msg) WITH NOWAIT;
    END 
    ELSE IF EXISTS(SELECT 1 FROM @opVal WHERE Val = 'ET')
    BEGIN
        IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'ET' AND StrVal IN ('_A', '_ASC','A','ASC'))
            SET @useTimeDescending = 0;

        SET @useEndTime = 1;
        SET @msg = CASE WHEN @useTimeDescending = 0 THEN 'Ascending' ELSE N'Descending' END
        RAISERROR(N' - Sort by End Time %s', 0, 0, @msg) WITH NOWAIT;
    END
    ELSE
    BEGIN
        IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'CT' AND StrVal IN ('_A', '_ASC','A','ASC'))
            SET @useTimeDescending = 0;

        SET @msg = CASE WHEN @useTimeDescending = 0 THEN 'Ascending' ELSE N'Descending' END
        RAISERROR(N' - Sort by Create Time %s', 0, 0, @msg) WITH NOWAIT;
    END

    IF EXISTS(SELECT 1 FROM @opVal WHERE Val = N'X')
        SET @totalMaxRows = (SELECT MaxIntVal FROM @opVal WHERE Val = N'X')

    /* END OF OPERATION  Retrieval */

    /* BEGIN PROCESS MESSAGE TYPES */
    IF OBJECT_ID('tempdb..#msgTypes') IS NOT NULL
        DROP TABLE #msgTypes;

    CREATE TABLE #msgTypes (
         id     smallint        NOT NULL PRIMARY KEY CLUSTERED
        ,msg    nvarchar(50) COLLATE DATABASE_DEFAULT  NOT NULL
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
        SET @msg = N' - Including Execution Messages... (' + ISNULL(N'last ' + CONVERT(nvarchar(10), @max_messages), N'All') + N' rows)';
        IF  (@msgTypeFilter = 1)
            SET @msg = @msg + N' (' + STUFF((SELECT ', ' + m.msg FROM #msgTypes m FOR XML PATH('')), 1, 2, '') + N')';
        RAISERROR(@msg, 0, 0) WITH NOWAIT;

        IF @messageKind < 3
            RAISERROR(N'    - Filtering Execution Messages for message kind: %s', 0, 0, @messageKindDesc) WITH NOWAIT;

        IF @detailedMessageTracking = 1
            RAISERROR(N'    - Using Detailed Messages Tracking', 0, 0) WITH NOWAIT;
    END

    /* END PROCESS MESSAGE TYPES */

    /* PROCES MESSAGE FILTERS */
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

    IF NULLIF(@msg_filter, N'') IS NOT NULL
        RAISERROR(N' - Using Message Filter(s): %s', 0, 0, @msg_filter) WITH NOWAIT;


    /* END PROCES MESSAGE FILTERS */

    IF @id IS NULL AND @help <> 1
    BEGIN    
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
            FROM SSISDB.internal.folders f WITH(NOLOCK)
            INNER JOIN (SELECT DISTINCT LTRIM(RTRIM(n.value('.','nvarchar(128)'))) fld FROM @xml.nodes('/i') T(n)) T(Fld) ON f.name LIKE T.Fld AND LEFT(T.Fld, 1) <> '-'
            EXCEPT
	        SELECT
		        name
	        FROM SSISDB.internal.folders f WITH(NOLOCK)
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
            FROM SSISDB.internal.projects p WITH(NOLOCK)
            INNER JOIN (SELECT DISTINCT LTRIM(RTRIM(n.value('.','nvarchar(128)'))) fld FROM @xml.nodes('/i') T(n)) T(Fld) ON p.name LIKE T.Fld AND LEFT(T.Fld, 1) <> '-'
            EXCEPT
            SELECT
                name
            FROM SSISDB.internal.projects  p WITH(NOLOCK)
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
            SELECT @projId = (SELECT 
                                e.project_lsn 
                            FROM internal.executions e WITH(NOLOCK)
                            INNER JOIN internal.object_versions ov WITH(NOLOCK) ON ov.object_version_lsn = e.project_lsn
                            WHERE execution_id = @id)


        INSERT INTO #packages(package_name)
        SELECT DISTINCT
            pkg.name
        FROM internal.packages pkg WITH(NOLOCK)
        INNER JOIN (SELECT LTRIM(RTRIM(n.value('.','nvarchar(260)'))) fld FROM @xml.nodes('/i') T(n)) T(name) ON pkg.name LIKE T.name AND LEFT(T.name, 1) <> '-'
        WHERE  @projId IS NULL OR pkg.project_version_lsn = @projId
        EXCEPT
        SELECT DISTINCT
            pkg.name
        FROM internal.packages pkg WITH(NOLOCK)
        INNER JOIN (SELECT LTRIM(RTRIM(n.value('.','nvarchar(260)'))) fld FROM @xml.nodes('/i') T(n)) T(name) ON pkg.name LIKE RIGHT(T.name, LEN(T.name) -1) AND LEFT(T.name, 1) = '-'
        WHERE  @projId IS NULL OR pkg.project_version_lsn = @projId
        
        IF @debugLevel > 4
        BEGIN
            SELECT '#packages' AS [#packages], * FROM #packages;
        END


        IF EXISTS(SELECT 1 pkg FROM @xml.nodes('/i') T(n))
        BEGIN
            SET @pkgFilter = 1
            SET @msg = N' - Using Package Filter(s): ' + REPLACE(STUFF((SELECT DISTINCT ', ' + LTRIM(RTRIM(n.value('.','nvarchar(128)'))) FROM @xml.nodes('/i') T(n) FOR XML PATH('')), 1, 2, ''), N'%', N'%%')
            RAISERROR(@msg, 0, 0) WITH NOWAIT;
            IF @filterPkg = 1 AND (@includeExecPackages = 1 OR @id IS NOT NULL)
                RAISERROR(N'   - Applying also on executed packages', 0, 0) WITH NOWAIT;
        END
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

    RAISERROR(N'Parametes:
     @op                    nvarchar(max)   = NULL  - Operator parameter - universal operator for setting large range of condidions and filters
    ,@status                nvarchar(MAX)   = NULL  - Comma separated list of execution statuses to return. Default NULL means all. See below for more details
    ,@folder                nvarchar(max)   = NULL  - Comma separated list of folder filters. Default NULL means no filtering. See below for more details
    ,@project               nvarchar(max)   = NULL  - Comma separated list of project filters. Default NULL means no filtering. See below for more details
    ,@package               nvarchar(max)   = NULL  - Comma separated list of pacakge filters. Default NULL means no filtering. See below for more details
    ,@msg_type              nvarchar(max)   = NULL  - Comma separated list of Message types. When not provided, then for in row data a default combination of ERROR,TASK_FAILED is beging used.
    ,@event_filter          nvarchar(max)   = NULL  - Comma separated list of event LIKE filters. Used only for detailed results filtering
    ,@phase_filter          nvarchar(max)   = NULL  - Comma separated list of phase LIKE filters. Used only for detailed results filtering
    ,@task_filter           nvarchar(max)   = NULL  - Comma separated list of task LIKE filters. Used only for detailed results filtering
    ,@subcomponent_filter   nvarchar(max)   = NULL  - Comma separated list of sub-component LIKE filters. Used only for detailed results filtering
    ,@package_path          nvarchar(max)   = NULL  - Comma separated list of package_path LIKE filters. Used only for detailed results fitering
    ,@execution_path        nvarchar(max)   = NULL  - Comma separated list of execution_path LIKE filters. Used only for detailed results filtering
    ,@msg_filter            nvarchar(max)   = NULL  - Comma separated list of message LIKE filters. Used for detailed results filtering as well for filtering in-row event mesages.
    ,@src_component_name    nvarchar(max)   = NULL  - Comma separated list of source_component_name LIKE filters. Used only for detailed results filtering in execution_data_statistics
    ,@dst_component_name    nvarchar(max)   = NULL  - Comma separated list of destination_component_name LIKE filters. Used only for detailed results filtering in execution_data_statistics
    ', 0, 0) WITH NOWAIT

RAISERROR('', 0, 0) WITH NOWAIT;
RAISERROR('@op - Operator Parameter', 0, 0) WITH NOWAIT;
RAISERROR('------------------------', 0, 0) WITH NOWAIT;
RAISERROR('Comma or space separated list of operations parameters. Specifies operations, filtering and grouping of the resuls.', 0, 0) WITH NOWAIT;
--RAISERROR('', 0, 0) WITH NOWAIT;
RAISERROR(N'
  ?                                 - Print this help

  iiiiiiiiiiiiii                    - (integer values) Specifies range of execution_id(s) to return basic information. If single initeger is provided than executios starting with that id will be returned. 
                                      In case of multiple initegers, range between minimum and maximum id is returned
  (L)AST:iiiii                      - Optional Keywork which modifies output only to LAST iiiii records. THe LAST records are returned per group. 
                                      If iiiii is not provided then then last 1 execution is returned. 
                                      If Keyword is missing the default LAST 100 records are retrieved

  Date/Time                         - If provided then executions since that Date/Time are returned. If multiple Date/Time values are provided then executions between MIN and MAX values are returned.
                                      If provided in verbose mode, then the filter is applied on the executable_statistics, event_messages, execution_data_statistics and execution_component_phases respectively.
  hh:MM[:ss]                        - If only time is provided, then the time is interpreted as Time of current day
  yyyy-mm-dd                        - If only date is provided, then it is intepreted as midnigth of that day (YYYY-MM-DDTHH:MM:SS)
  yyyy-mm-ddThh:MM:ss               - When Date/Time is passed, then Time is separated by T from date. In that case hours have to be provided as two digits

  RUN_TIME (RT)                     - Use Run Time for searching. This means if Above Date/Time specifiers are provided, then it returns all jobs which Start or End time fits to specified period.
                                      Can be combined with below specifies for appropriate sorting.
  START_TIME (ST)[_A|_ASC]          - Use Start Time for searching (By Default Create Time is used). Optional [_A] or [_ASC] modifier can be used to use Ascending Sorting. Default is Descending. Used also for Data Filters.
  END_TIME (ET)[_A|_ASC]            - Use End Time for searching (By Default Create Time is used). Optional [_A] or [_ASC] modifier can be used to use Ascending Sorting. Default is Descending. Used Also for Date Filters.
  CREATE_TIME (CT)[_A|_ASC]         - Use Create Time forr searching. This is the default. Optional [_A] or [_ASC] modifier can be used to use Ascending Sorting. Default is Descending.', 0, 0) WITH NOWAIT;

RAISERROR(N'  
  >|>=|<|<=|=dddddd                 - Duration Specifier. If provided then only operations with duration corresponding to the specifier are returned. Multiple specifiers are combined with AND.
                                      If multiple durations are specified for the same specifier, MAX duration is used for [>] and [>=] and and MIN durtion for [<], [<=], [=]
                                      If provided in verbose mode, then the filter is applied on executable statistics, execution_data_statistics and execution_component_phases respecively.
  dddddd                            - Specifies duration in below allowed formats
  hh:MM[:ss[.fff]]                  - If only time is specified, it represents duration in hours, minutes, seconds and fraction of second
  iiid[hh:MM[:ss[.fff]]]            - iii specifies followed by d specifies number of days. Optional additional time can follow

  PROCESS_ID(PID):iiiiii            - ProcessID specifier. If provided then only operations with specific process_id are returned. iiiiii is integer value representing process_id.
                                      Multiple declarations can be specified to filter for multiple process_ids.
  CALLER_NAME(CN):xxxxxxxx          - Caller Name specifier. If provided then only operations which caller corresponds to provided value. xxxxxxxx is string representing caller name.
                                      Multiple declarations can be specified to filter for multiple callers. Caller name supports LIKE wildcards.
  STOPPED_BY(SB):xxxxxxxx           - Stopped By specifier. if provided then only operations which were stopped by user with provided name are returned. xxxxxxxx is string representing user name.
                                      Multiple declarations can be specified to filter for multiple user names. Stopped by name suppors LIKE wildcards.
  (32B)IT                           - Filter only 32 bit executions
  (64B)IT                           - Filter only 64 bit executions
  MILLISECONDS(MS)                  - Include duration in milliseconds (for Execution Component Phases it in nanoseconds)', 0, 0) WITH NOWAIT;

RAISERROR(N'  LOCAL_TIME(LT)                    - Use local time in the time-stamps
  EXECUTION_DETAILS(ED)             - Include Execution Details
  PARAMS(PM)                        - Include Execution Parameters in Execution Details. If DECRYPT_SENSITIVE(DS) is included, sensitive values are decrypted.
  DECRYPT_SENSITIVE(DS)             - Decrypt sensitive information. If specified, sensitive data will be decrypted and the values provided
                                      Caller must be member of [db_owner] or [ssis_sensitive_access] database role or member of [sysadmin] server role
                                      to be able to decrypt sensitive information
  FOLDER_DETAILS(FD)                - Include detailed information about folder from which the executed package originates. Information is provided in form of xml in the objects_details column.
                                      Included is information about projects and environments in the folder.
  PROJECT_DETAILS(PRD)              - Include detailed information about project from which the executed package originates. Information is provided in form of xml in the objects_details column.
                                      Included is information about project parameters and packages in the project. If DECRYPT_SENSITIVE(DS) is included, sensitive values are decrypted.
  OBJECT_DETAILS(OD)                - Include detailed information about the executed pacakge. Information is provided in form of xml in the objects_details column.
                                      Included is information about package parameters. If DECRYPT_SENSITIVE(DS) is included, sensitive values are decrypted.
', 0, 0) WITH NOWAIT;
RAISERROR(N'
  FOLDER (FLD)                      - Optional keyword which specifies the result will be grouped by FOLDER. Nunmber of last records is per folder.
  (P)ROJECT                         - Optional keyword which specifeis the result will be grouped by FOLDER, PROJECT. Number of last records is per project
  (E)XECUTABLE                      - Optional keyword which specifies the result will be grouped by FOLDER, PROJET, EXECUTABLE. Number of last records is per EXECUTABLE
  
  AGENT_REFERENCES (AGR)            - Include information about Agent Jobs referencing the packages (Slow-downs the retrieval). Runs in caller context. Caller must have permissions to msdb.
  AGENT_JOB (AGT)                   - If available, Retrieve information about agent Job which started the execution. (Slow-down the retrieval). Runs in caller context. Caller must have permissions to msdb.


  MA(X):iiiii                       - Optional keyword which specifies that when the LAST rows are returned per FOLDER, PROJECT, EXECUTABLE, then maximum of LAST iiiii rows
                                      will be retrieved and those grouped and returned as per above specification', 0, 0) WITH NOWAIT;
RAISERROR(N'
  (V)ERBOSE:iiiiii                  - Used to pass exeuction ID for which detailed overview should be provided. it has priority over the overview ranges.
                                      In case multiple integer numbers are provided, it produces verbose information for the maximum integer provided.
                                      If verbose is specified without any integer number, then verbose invormation is provided for the last operation.', 0, 0) WITH NOWAIT;
RAISERROR(N'
  PACKAGE_EXECUTION_STATUS(PES):sss - Package Execution Status Filter. sss is comma separated list of @status filters.
                                      For details see the @status filter below. It overrides the filters pased in the @status parameter as well as the inline status filters below
                                      

  (R)UNNING         - Filter Modifier applies RUNNING @status filter
  (S)UCCESS         - Filter Modifier applie SUCCESS @status filter
  (F)AILURE         - Filter modifier applies FAILURE @status filter
  (C)ANCELLED       - Filter modifier applies CANCELLED @status filter
  (U)NEXPECTED      - Filter modifier applies UNEXPECTED @status filter
  CREATED(TD)       - Filter modifier applies CREATED @status filter
  (P)ENDING         - Filter modifier applies PENDING @status filter
  STOPPIN(G)        - Filter modifier applies STOPPING @status filter
  COMPLETED(CD)     - Filter modifier applies COMPLETED @status filter
', 0, 0) WITH NOWAIT;

RAISERROR(N'
  EXECUTED_PACKAGES (EP)                 - Include information about executed packages per reult in the overview list. (Slow-downs the retrieval)
                                           In Verbose mode executed packages are always listed as separate result by default.
                                           When specified in Verbose mode then the executed_pacakges column is not filtered by other filters.
  SORT_PACKAGES(SP):ccc,ooo              - Sort Executed packages where the ccc,ooo is comma separated list of the sort orders specifiers.
                                           Only one specifier for column and one for order can be provided at a time.
                                           Allowed column specifiers (ccc):
                                           S|START|START_TIME        = sort by start_time (default)
                                           E|END|END_TIME            = sort by end_time
                                           N|NAME                    = sort by name
                                           D|DUR|DURATION            = sort by duration
                                           R|RES|RESULT              = sort by result
                                           RC|RES_CODE|RESULT_CODE   = sort by result_code
                                        
                                           Allowed orders pecifiers (ooo):
                                           A|ASC|ASCENDING           = sort ascending
                                           DESC|DESCENDING           = sort descending (default)', 0, 0) WITH NOWAIT;
RAISERROR(N'  FILTER_PACKAGES(FP)                    - Apply @package filter also on Executed Packages list in the verbose mode.
  EXECUTED_PACKAGES_RESULT(EPR):rrr      - Apply Result filter on Executed Packages list
                                           rrr is comma separated list of Result filters. See Result Filters below.
  EXECUTABLE_STATISTICS(ES):iiiii        - Include executablew statistics in the details verbose output.
                                           iiiii specifies max number of rows. If not provided then default 1000 rows are returned.
                                           iiiii < 0 = All rows are returned and is the same as not including the keyword
  EXECUTABLE_STATISTICS_RESULT(ESR):rrr  - Apply Result filter on Executed Executable Statistics
                                           rrr is comma separated list of Result filters. See Result Filters below.
  EXECUTION_MESSAGES(EM):iiiii           - Include event messages details in the overview list and in details list. 
                                           iiiii specifies max number of rows. If not provided then default 100 for overview and 1000 for details is used.
                                           iiiii < 0 = All rows are returned.
                                           For Overview by default only ERROR and TASK_FAILED are included. (Slow downs data retrieval)
  MESSAGE_KIND(MK):m                     - Allows filering the messages by message kind. 
                                           m is comma seeparated list of message kinds. Supported O = Operations, E = Event messages. Default are both kinds of messages
  DETAILED_MESSAGE_TRACKING(DMT)         - Enables detailed messages tracking. This allows tracking of proper package and package path for log messages from scripts
                                           which are otherwise logged under control package
                                           ', 0, 0) WITH NOWAIT;

RAISERROR(N'  EXECUTION_DATA_STATISTICS(EDS):iiiii   - Include Execution Data Statistics in the details verbose output
                                           iiiii specifies max number of rows. If not provided then default 100 for overview and 1000 for details is used.
                                           iiiii < 0 = All rows are returned.                                    
  EXECUTION_COMPONENT_PHASES(ECP):iiiii  - Include Execution Componetn Phases in the details verbose output
                                           iiiii specifies max number of rows. If not provided then default 100 for overview and 1000 for details is used.
                                           iiiii < 0 = All rows are returned.

  Execution Result Filters:
    (R)UNNING           - Filter for Running result
    (S)UCCESS           - Filter for Success result
    (F)AILURE           - Filter for Failure result
    COMPLETION(CD)      - Filter for Completion result
    (C)CANCELLED        - Filter for Cancelled result
    (U)NEXPECTED        - Filter for Unexpected execution result
    COM(P)LETED         - Filter for Completed execution result
    ALL                 - All above filters usefull with [-] prefist status

    Statuses with prefix [-] are removed from selecting
', 0, 0) WITH NOWAIT;

RAISERROR(N'
Samples:  
  LAST10                                    - Last 10 executions will be returned
  LAST5 FOLDER                              - Last 5 executions per folder will be returned
  LAST10 PROJECT                            - last 10 executions per folder/project will be returned
  E L6 EM EP                                - last 6 executions per Executable (package) will be returned including overview of error messages and executed packages
  L5 E S F                                  - last 5 exectutions per executable with status Success or Failure will be returned
  L10 >00:15:30                             - Last 10 executions with duration longer than 15 minutes and 30 seconds
  815350 815500                             - Executions with execution_id betwen 815350 and 815500 are returned
  06:00:00                                  - All executions since 06:00:00 today will be returned
  06:00:00 12:30:00                         - All executions from today between 06:00:00 and 12:30:00 today will be returned
  2017-01-20T06:00:00 2017-01-21T13:35:00   - All executions between 2017-01-206:00:00 and 2017-01-21 13:35:00 will be returned
  2017-01-20T06:00:00 12:30:00              - All executions between 2017-01-206:00:00 and today 12:30:00 will be returned
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

  CREATED(TD)   - Operation was created but not executed yet
  (R)UNNING     - Operation is running
  (S)UCCESS     - Operation ended successfully
  (F)FAILED     - Operation execution failed
  (C)CANCELLED  - Operation execution was cancelled
  (P)ENDING     - Operation was set for exectuion, but he execution is stil pending
  (U)NEXPECTED  - Operetion edend unexpectedly
  STOPPIN(G)    - Operation is in process of stpping
  COMPLETED(CD) - Operation was completed
  ALL           - All above statuses

  Statuses prefixed with [-] are removed from the filter: ALL,-S means all statuses except Success
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
  (ND) NON_DIAGNOSTICS         - non diagnostics message
  (VC) VARIABLE_VALUE_CHANGE   - variable value change mesasge
  (U)  UNKNOWN                 - represents uknown message type
', 0, 0) WITH NOWAIT;

RAISERROR(N'
@folder
-------
Comma separated list of Folder filters. When specified only executions of packages from projects belonging to providedl folders list are shown.
Supports LIKE wildcards. Default NULL means any folder.

@project
--------
Comma separated list of project filters. When specified, only executions of packages from projects matching the filter are shown.
All matching project cross beloding to folders specified by @folder parameter are used.
Supports LIKE wildcards. Default NULL means any project.', 0, 0) WITH NOWAIT;

RAISERROR(N'
@package
--------
Comma separated list of package filters. When specified only executions of packages whose name is matching the @package filer are shown.
Package are shown from all folders/projects matching the @folder/@project parameter.
Supports LIKE wildcards. Default NULL means any package.

@event_filter
-------------
Used only for detailed results filtering in VERBOSE mode.
Comma separated list of event filters. Only messages for events whose name is matching the filter are returned.
Supports LIKE wildcards. Default NULL means filter is not applied.

@phase_filter
-------------
Used only for detailed results filtering in VERBOSE mode.
Comma separated list of phase filters. Only execution component phases which name is matching the filter are returned.
EXECUTION_COMPONENT_PHASES(ECP)iiiii has to be active for the filter to take effect.
Supports LIKE wildcards. Default NULL means filter is not applied.', 0, 0) WITH NOWAIT;

RAISERROR(N'
@task_filter
------------
Used only for detailed results filtering in VERBOSE mode.
Comma separated lists of task filters. Only events, phases and messages for tasks (source_name in messages) which name is matching the filter are returned.
Supports LIKE wildcards. Default NULL means filter is not applied.

@subcomponent_filter
--------------------
Used only for detailed results filtering in VERBOSE mode.
Comma separated list of sub-componetn filters. Only messages for subcomponents which name is matching the filter are returned.
Supports LIKE wildcards. Default NULL means filter is not applied.', 0, 0) WITH NOWAIT;

RAISERROR(N'
@package_path
-------------
Used only for detailed results filtering in VERBOSE mode.
Comma separeted list of package paths. Only executable statistics and messages, execution component phases
and execution data statistics which match the @package_path filter are returned.
Supports LIKE wildcards. Default NULL means filter is not applied.

@execution_path
---------------
Used only for detailed results filtering in VERBOSE mode.
Comma separated list of package paths.Only executable statistics and messages, execution component phases
and execution data statistics which match the @execution_path filter are returned.
Supports LIKE wildcards. Default NULL means filter is not applied.', 0, 0) WITH NOWAIT;

RAISERROR(N'
@msg_filter
-----------
Used for detailed results filtering in VERBOSE mode as well as for filtering in-row event messages which are included by the EVENT_MESSAGES(ME) specifier.
Comma separated list of filters which are applied on the message body.
Supports LIKE filters. Default NULL means filter is not applied.
', 0, 0) WITH NOWAIT;

RAISERROR(N'
@src_component_name
-------------------
Used only for detailed results filtering in VERBOSE mode.
Comma separated list of filters which are applied on field source_component_name for the execution_data_statistics and source_name in the execution_messages
Supports LIKE filters. Default NULL means filter is not applied.
', 0, 0) WITH NOWAIT;

RAISERROR(N'
@dst_component_name
-------------------
Used only for detailed results filtering in VERBOSE mode.
Comma separated list of filters which are applied on field destination_component_name for the execution_data_statistics
Supports LIKE filters. Default NULL means filter is not applied.
', 0, 0) WITH NOWAIT;

RAISERROR(N'--------------------------------------------- END OF HELP ---------------------------------------------', 0, 0) WITH NOWAIT;

RETURN;
END
/* END HELP PROCESSING */

SET @sql = CONVERT(nvarchar(max),  N'
WITH BaseOperations AS (
    SELECT
        DATEADD(MILLISECOND, DATEDIFF(MILLISECOND, DATEADD(DAY, DATEDIFF(MINUTE, start_time, ISNULL(end_time, SYSDATETIMEOFFSET())) / 1440, start_time), ISNULL(end_time, SYSDATETIMEOFFSET())), DATEADD(DAY, DATEDIFF(MINUTE, start_time, ISNULL(end_time, SYSDATETIMEOFFSET())) / 1440, CONVERT(datetime2(7), ''19000101''))) durationDate
        ,o.*
    FROM internal.operations o WITH(NOLOCK)'
+
CASE 
    WHEN @id IS NOT NULL OR @processID = 0 THEN N''
    ELSE N' INNER JOIN #ProcessID p ON p.process_id = o.process_id'
END 
+
CASE 
    WHEN @id IS NOT NULL OR @callerName = 0 THEN N''
    ELSE N' INNER JOIN #callers c ON o.caller_name LIKE c.caller_name'
END 
+
CASE 
    WHEN @id IS NOT NULL OR @stoppedBy = 0 THEN N''
    ELSE N' INNER JOIN #stoppedBy s ON o.stopped_by_name LIKE s.stopped_by_name'
END 

+ N'
),
Data AS (
    SELECT ' + CASE WHEN @id IS NOT NULL THEN N'TOP (1) ' WHEN @totalMaxRows IS NOT NULL THEN N'TOP (@totalMaxRows) ' ELSE N'' END + N'
        e.execution_id
        ,e.folder_name
        ,e.project_name
        ,e.package_name
        ,o.start_time
        ,o.end_time
        ,RIGHT(''     '' + CONVERT(nvarchar(5), DATEDIFF(DAY, 0, durationDate)) + ''d '', 6) + CONVERT(varchar(12), CONVERT(time, durationDate)) AS duration
        ,CONVERT(bigint, DATEDIFF(DAY, CONVERT(datetime2(7), ''19000101''), durationDate)) * 86400000 + DATEDIFF(MILLISECOND, DATEADD(DAY, DATEDIFF(DAY, ''19000101'', durationDate), ''19000101''), durationDate) AS duration_ms
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
        ,o.stopped_by_name
        ,o.stopped_by_sid
') + CASE 
        WHEN @id IS NULL AND @opLastCnt IS NOT NULL AND @opLastGrp IS NOT NULL THEN
            N',ROW_NUMBER() OVER(PARTITION BY ' +
                CASE @opLastGrp
                    WHEN 'F' THEN 'e.folder_name'
                    WHEN 'P' THEN 'e.folder_name, e.project_name'
                    WHEN 'E' THEN 'e.folder_name, e.project_name, e.package_name'
                END
            + N' ORDER BY ' + CASE WHEN @useStartTime =1 THEN N'ISNULL(start_time, ''99991231'')' WHEN @useEndTime = 1 THEN N'ISNULL(end_time, ''99991231'')' ELSE N'created_time' END + CASE WHEN @useTimeDescending = 1THEN  N' DESC' ELSE N' ASC' END + N') AS row_no'
        ELSE ',ROW_NUMBER() OVER(ORDER BY ' + CASE WHEN @useStartTime =1 THEN N'ISNULL(start_time, ''99991231'')' WHEN @useEndTime = 1 THEN N'ISNULL(end_time, ''99991231'')' ELSE N'created_time' END + CASE WHEN @useTimeDescending = 1THEN  N' DESC' ELSE N' ASC' END + N') AS row_no'
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
        ELSE ',ROW_NUMBER() OVER(ORDER BY ' + CASE WHEN @useStartTime =1 THEN N'ISNULL(start_time, ''99991231'')' WHEN @useEndTime = 1 THEN N'ISNULL(end_time, ''99991231'')' ELSE N'created_time' END + CASE WHEN @useTimeDescending = 1THEN  N' DESC' ELSE N' ASC' END + N') AS rank'
    END + N'
    FROM BaseOperations o 
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
                (CASE WHEN @id IS NOT NULL THEN N'e.execution_id = @id' ELSE NULL END)
                ,(CASE
                    WHEN @id IS NOT NULL THEN NULL
                    WHEN @useRuntime = 0 THEN
                        CASE
                            WHEN @opFromTZ IS NOT NULL AND @opToTZ IS NOT NULL THEN CASE WHEN @useStartTime =1 THEN N'(ISNULL(start_time, ''99991231'')' WHEN @useEndTime = 1 THEN N'(end_time' ELSE N'(created_time' END + N' BETWEEN  @fromTZ AND @toTZ)'
                            WHEN @opFromTZ IS NOT NULL THEN CASE WHEN @useStartTime =1 THEN N'(ISNULL(start_time, ''99991231'')' WHEN @useEndTime = 1 THEN N'(ISNULL(end_time, ''99991231'')' ELSE N'(created_time' END +' > @fromTZ)'
                        END
                    WHEN @useRuntime = 1 THEN
                        CASE
                            WHEN @opFromTZ IS NOT NULL AND @opToTZ IS NOT NULL THEN N'( ((ISNULL(start_time, ''99991231'') BETWEEN  @fromTZ AND @toTZ) AND end_time IS NULL) OR (end_time BETWEEN  @fromTZ AND @toTZ) OR (start_time < @fromTZ AND (end_time IS NULL or end_time > @toTZ)))'
                            WHEN @opFromTZ IS NOT NULL THEN N'((ISNULL(start_time, ''99991231'')  > @fromTZ OR ISNULL(start_time, ''99991231'')  > @fromTZ))'
                        END
                  END
                )
                ,(CASE
                    WHEN @id IS NOT NULL THEN NULL
                    WHEN @maxInt IS NOT NULL AND @maxInt = @minInt AND @opValCount > 1 THEN N'(e.execution_id = @minInt)'
                    WHEN @maxInt IS NOT NULL AND @minInt IS NOT NULL AND @minInt = @maxInt THEN N'(e.execution_id >= @minInt)'
                    WHEN @maxInt IS NOT NULL AND @minInt IS NOT NULL THEN N'(execution_id BETWEEN @minInt AND @maxInt)'
                  END
                )
                ,(CASE
                    WHEN @id IS NOT NULL OR @useX86 IS NULL THEN NULL
                    WHEN @useX86 = 1 THEN N'(e.use32bitruntime = 1)'
                    WHEN @useX86 = 0 THEN N'(e.use32bitruntime = 0)'
                END
                )
                ,(@durationCondition)
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
        WHEN @totalMaxRows IS NOT NULL THEN N' ORDER BY ' + CASE WHEN @useStartTime =1 THEN N'ISNULL(start_time, ''99991231'')' WHEN @useEndTime = 1 THEN N'ISNULL(end_time, ''99991231'')' ELSE N'created_time' END + N' DESC ' 
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
    ,' + CASE WHEN @localTime = 1 THEN N'CONVERT(datetime2(7), d.start_time) AS start_time' ELSE N' d.start_time' END + N'
    ,' + CASE WHEN @localTime = 1 THEN N'CONVERT(datetime2(7), d.end_time) AS end_time' ELSE N' d.end_time' END + N'
    ,d.duration ' +
    CASE
        WHEN @duration_ms = 1 THEN N',d.duration_ms'
        ELSE N''
    END + N'
    ,d.status' +
    CASE WHEN @id IS NULL AND @includeMessages = 1 THEN N'
    ,(SELECT 
        @messages_inrow              ''@maxMessages'' '
        + CASE WHEN @messageKind < 3 THEN N', ''' + @messageKindDesc + N''' ''@messages_kind''' ELSE N'' END + N'
        ,(SELECT ' + CASE WHEN @max_messages IS NULL THEN N'' ELSE N'TOP (@messages_inrow)' END + N'
            mt.msg                      ''@type''
			,CASE WHEN em.event_message_id IS NULL THEN ''OPERATION'' ELSE ''EVENT'' END ''@kind''
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
            ,''SELECT * FROM internal.event_message_context WITH(NOLOCK) WHERE event_message_id = '' + FORMAT(em.event_message_id, ''G'') ''message/context/@info''
            --,om.message                 ''message/msg''
            ,CONVERT(xml, N''<?msg --
'' + REPLACE(REPLACE(om.message, N''<?'', N''''), N''?>'', N'''') + N''
--?>'') ''message''
        FROM internal.operation_messages om WITH(NOLOCK) 
        LEFT JOIN internal.event_messages em WITH(NOLOCK) ON om.operation_id = em.operation_id and om.operation_message_id = em.event_message_id 
        INNER JOIN #msgTypes mt ON mt.id = om.message_type
        WHERE 
            om.operation_id = d.execution_id' +
            CASE
                WHEN NULLIF(@msg_filter, '') IS NOT NULL THEN  N' AND (EXISTS(SELECT 1 FROM #msg_filters mf WHERE om.message LIKE mf.filter AND mf.exclusive = 0) AND NOT EXISTS(SELECT 1 FROM #msg_filters mf WHERE om.message LIKE mf.filter AND mf.exclusive = 1))'
                ELSE N''
            END +
            CASE 
                WHEN @messageKind >= 3 THEN N''
                WHEN (@messageKind & 1) = 1 THEN N' AND em.event_message_id IS NULL'
                WHEN (@messageKind & 2) = 2 THEN N' AND em.event_message_id IS NOT NULL'
                ELSE N''
            END
            + N'
        ORDER BY om.message_time DESC, om.operation_message_id DESC
        FOR XML PATH(''event_message''), TYPE
        )
    FOR XML PATH(''event_messages''), TYPE) AS event_messages'
    ELSE N''
    END + N'
' +
    CASE WHEN @includeExecPackages = 1 THEN CONVERT(nvarchar(max), N'
    ,(
        SELECT
            CASE WHEN d.status_code <= 2 THEN ''Incomplete Preliminary Information based on already executed tasks'' ELSE NULL END ''@status_info''
            ,(STUFF((SELECT '', '' + s.status FROM #EPstatuses s FOR XML PATH('''')), 1, 2, '''')) ''@result_filter''
            ,(
				SELECT
					ROW_NUMBER() OVER(ORDER BY start_time)  ''@no''
					,res					AS ''@result''
					,start_time				AS ''@start_time''
        ,CONVERT(nvarchar(5), DATEDIFF(DAY, 0, durationDate)) + ''d '' + CONVERT(varchar(12), CONVERT(time, durationDate)) AS ''@duration'' ' ) +
        CASE WHEN  @duration_ms = 1 THEN N'
        ,CONVERT(bigint, DATEDIFF(DAY, CONVERT(datetime2(7), ''19000101''), durationDate)) * 86400000 + DATEDIFF(MILLISECOND, DATEADD(DAY, DATEDIFF(DAY, ''19000101'', durationDate), ''19000101''), durationDate) AS ''@duration_ms''
         ' ELSE N'' END + N'    
					,package_name			AS ''@package_name''
					,result					AS ''@result_description''
					,end_time				AS ''@end_time''
					,result_code			AS ''@result_code''
                    ,status_info            AS ''@status_info''
				FROM (
				  SELECT
					 ROW_NUMBER() OVER(PARTITION BY e.package_name ORDER BY CASE WHEN e.package_path = ''\Package'' THEN 0 ELSE 1 END ASC, es.start_time ASC) AS pno
                    ,CASE WHEN e.package_path = ''\Package'' OR d.status_code IN (3, 4, 6, 7, 9) THEN N''Final'' ELSE N''Preliminary'' END AS status_info
					,CASE
						(CASE WHEN e.package_path = ''\Package'' THEN es.execution_result WHEN d.status_code = 3 THEN 3 WHEN d.status_code = 6 THEN 6 WHEN d.status_code = 7 THEN 0 WHEN d.status_code = 4 THEN 1 WHEN d.status_code = 9 THEN 2 ELSE 99 END)
						WHEN 0 THEN N''S''  --Success
						WHEN 1 THEN N''F''  --Failure
						WHEN 2 THEN N''O''  --Completed
						WHEN 3 THEN N''C''  --Cancelled
                        WHEN 6 THEN N''U''  --Unexpected
                        WHEN 9 THEN N''P''  --Completed
                        WHEN 99 THEN N''R'' --Running
						ELSE N''K'' --Unknown
					END                 AS res

					,CONVERT(nvarchar(36), es.start_time)       AS start_time
    
					,CONVERT(nvarchar(3), DATEDIFF(SECOND, es.start_time, ISNULL(NULLIF(CASE WHEN e.package_path = ''\Package'' THEN es.end_time ELSE ''00010101'' END, ''00010101''), 
						CASE WHEN d.status_code IN (6, 9) THEN d.end_time ELSE SYSDATETIMEOFFSET() END)) / 86400) + N''d '' +
					CONVERT(nvarchar(8), CONVERT(time, DATEADD(SECOND, DATEDIFF(SECOND, es.start_time, ISNULL(NULLIF(CASE WHEN e.package_path = ''\Package'' THEN es.end_time ELSE ''00010101'' END, ''00010101''), 
						CASE WHEN d.status_code IN (6, 9) THEN d.end_time ELSE SYSDATETIMEOFFSET() END)) % 86400, 0)))  duration 

                    ,DATEADD(MILLISECOND, DATEDIFF(MILLISECOND, DATEADD(DAY, DATEDIFF(MINUTE, es.start_time, ISNULL(NULLIF(CASE WHEN e.package_path = ''\Package'' THEN es.end_time ELSE ''00010101'' END, ''00010101''), 
						CASE WHEN d.status_code IN (6, 9) THEN d.end_time ELSE SYSDATETIMEOFFSET() END)) / 1440, es.start_time), ISNULL(NULLIF(CASE WHEN e.package_path = ''\Package'' THEN es.end_time ELSE ''00010101'' END, ''00010101''), 
						CASE WHEN d.status_code IN (6, 9) THEN d.end_time ELSE SYSDATETIMEOFFSET() END)), DATEADD(DAY, DATEDIFF(MINUTE, es.start_time, ISNULL(NULLIF(CASE WHEN e.package_path = ''\Package'' THEN es.end_time ELSE ''00010101'' END, ''00010101''), 
						CASE WHEN d.status_code IN (6, 9) THEN d.end_time ELSE SYSDATETIMEOFFSET() END)) / 1400, CONVERT(datetime2(7), ''19000101''))) durationDate

					,e.package_name              package_name

					,CASE
						(CASE WHEN e.package_path = ''\Package'' THEN es.execution_result WHEN d.status_code = 3 THEN 3 WHEN d.status_code = 6 THEN 6 WHEN d.status_code = 7 THEN 0 WHEN d.status_code = 4 THEN 1 WHEN d.status_code = 9 THEN 2 ELSE 99 END)
						WHEN 0 THEN N''Success''
						WHEN 1 THEN N''Failure''
						WHEN 2 THEN N''Completion''
						WHEN 3 THEN N''Cancelled''
                        WHEN 6 THEN N''Unexpected''
                        WHEN 9 THEN N''Completed''
                        WHEN 99 THEN N''Running''
						ELSE N''Unknown''
					END                 AS result

					,CONVERT(nvarchar(36), ISNULL(NULLIF(CASE WHEN e.package_path = ''\Package'' THEN es.end_time ELSE ''00010101'' END, ''00010101''), CASE WHEN d.status_code IN (3, 4, 6, 7, 9) THEN d.end_time ELSE NULL END))  end_time
					,NULLIF(CASE WHEN e.package_path = ''\Package'' THEN es.execution_result WHEN d.status_code = 3 THEN 3 WHEN d.status_code = 6 THEN 6 WHEN d.status_code = 7 THEN 0 WHEN d.status_code = 4 THEN 1 WHEN d.status_code = 9 THEN 2 ELSE 99 END, -9999)      result_code
				FROM internal.executable_statistics es WITH(NOLOCK)
				INNER JOIN internal.executables e WITH(NOLOCK) ON e.executable_id = es.executable_id
				LEFT JOIN  (
				SELECT
					 package_name 
					,ISNULL(MIN(es1.start_time), ''99991231'') AS start_time
					,ISNULL(MAX(es1.end_time), ''00010101'')  AS end_time
				FROM internal.executable_statistics es1 WITH(NOLOCK) 
				INNER JOIN internal.executables e1 WITH(NOLOCK) ON e1.executable_id = es1.executable_id 
				WHERE 
					e1.package_path = ''\Package'' AND es1.execution_id = d.execution_id
				GROUP BY e1.package_name
				) MM ON e.package_name = MM.package_name
				WHERE 
					es.execution_id = d.execution_id
		) EPD
		WHERE EPD.pno = 1 ' + 
        CASE WHEN @filterPkgStatus = 1 
            THEN N' AND result_code IN (SELECT id FROM #EPStatuses)' 
            ELSE N''
        END + N'
        ORDER BY ' +
        CASE @pkgSort
            WHEN 1 THEN N'package_name'
            WHEN 2 THEN N'durationDate'
            WHEN 3 THEN N'end_time'
            WHEN 4 THEN N'result'
            WHEN 5 THEN N'result_code'
          ELSE N'''@no'''
        END + 
        CASE WHEN @pkgSortDesc = 1 THEN N' DESC' ELSE ' ASC' END + N'        
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
            ,o.name                     ''job_step/@operator_name''
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
        LEFT JOIN #proxies p WITH(NOLOCK) ON jed.proxy_id = p.proxy_id
        LEFT JOIN #credentials c WITH(NOLOCK) ON c.credential_id = p.credential_id
        LEFT JOIN #operators o WITH(NOLOCK) ON o.id = jed.operator_id_emailed
        WHERE jed.execution_id = d.execution_id
        FOR XML PATH(''agent_job''), TYPE
        ) AS agent_job_detail'
        ELSE N''
    END +
    CASE WHEN @includeAgentReferences > 0 THEN N'
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
    CASE WHEN @folderDetail = 1 OR @projectDetail = 1 OR @objectDetail = 1 THEN N'
,(SELECT 
    f.name                  ''@name''
    ,f.folder_id            ''@folder_id''
    ,f.created_by_name      ''@created_by_name''
    ,f.created_time         ''@created_time''
    ,f.created_by_sid       ''@created_by_sid''
    ,f.description          ''@description''
    ,(
        SELECT
             pd.name                    ''@name''
            ,pd.project_id              ''@project_id''
            ,pd.created_time            ''@created_time''
            ,pd.deployed_by_name        ''@deployed_by_name''
            ,pd.last_deployed_time      ''@last_deployed_time''
            ,pd.object_version_lsn      ''@object_version_lsn''
            ,pd.last_validation_time    ''@last_validation_time''
            ,pd.validation_status       ''@validation_status''
            ,pd.description             ''@description''
            ,pd.project_format_version  ''@project_format_version''
            ,CASE WHEN pd.object_version_lsn = p.object_version_lsn AND @projectDetail = 1 THEN
                (SELECT
                    op.parameter_name               ''@parameter_name''
                    ,op.description                 ''@description''
                    ,op.parameter_data_type         ''@parameter_data_type''
                    ,op.last_validation_time        ''@last_validation_time''
                    ,op.validation_status           ''@validation_status''
                    ,op.sensitive                   ''values/@sensitive''
                    ,op.value_set                   ''values/@value_set''
                    ,op.value_type                  ''values/@value_type''
                    ,op.referenced_variable_name    ''values/@referenced_variable_name''
                    ,op.design_default_value        ''values/design_default_value/processing-instruction(value)''
                    ,CASE
						WHEN op.sensitive = 1 AND @decryptSensitive = 0 THEN
                            (SELECT ''''  ''values/default_value/sensitive-value-protected'' FOR XML PATH(''''), TYPE)
						WHEN op.sensitive = 1 AND @decryptSensitive = 1 AND op.sensitive_default_value IS NULL THEN
                            (SELECT ''''  ''values/default_value/sensitive-value-not-available'' FOR XML PATH(''''), TYPE)
                        WHEN op.sensitive = 1 AND @decryptSensitive = 1 THEN
                            (SELECT
                            CASE [parameter_data_type]
                                WHEN ''datetime'' THEN CONVERT(nvarchar(50), [internal].[get_value_by_data_type](DECRYPTBYKEYAUTOCERT(CERT_ID(N''MS_Cert_Proj_'' + CONVERT(nvarchar(20), op.project_id)), NULL, op.sensitive_default_value), [parameter_data_type]), 126)
                                ELSE CONVERT(nvarchar(4000), [internal].[get_value_by_data_type](DECRYPTBYKEYAUTOCERT(CERT_ID(N''MS_Cert_Proj_'' + CONVERT(nvarchar(20), op.project_id)), NULL, op.sensitive_default_value), [parameter_data_type]))
                            END ''values/default_value/processing-instruction(sensitive-value)''
                            FOR XML PATH(''''), TYPE
                            )                     
                        ELSE 
                            (SELECT op.default_value  ''values/default_value/processing-instruction(value)'' FOR XML PATH(''''), TYPE)
                    END
                FROM internal.object_parameters op WITH(NOLOCK)
                WHERE
                    op.project_version_lsn = pd.object_version_lsn
                    AND
                    op.object_name = pd.name
                FOR XML PATH(''parameter''), ROOT(''parameters''), TYPE
                )
                ELSE NULL
            END
            ,CASE WHEN pd.object_version_lsn = p.object_version_lsn  AND (@projectDetail = 1 OR @objectDetail = 1) THEN
                (
                SELECT
                    pk.name                     ''@name''
                    ,pk.package_id              ''@package_id''
                    ,PK.entry_point             ''@entry_point''
                    ,pk.package_guid            ''@package_guid''
                    ,pk.description             ''@description''
                    ,pk.package_format_version  ''@package_format_version''
                    ,pk.version_major           ''@version_major''
                    ,pk.version_minor           ''@version_minor''
                    ,pk.version_build           ''@version_build''
                    ,pk.version_guid            ''@version_guid''
                    ,pk.version_comments        ''@version_comments''
                    ,pk.last_validation_time    ''@last_validation_time''
                    ,pk.validation_status       ''@validation_status''
                    ,CASE WHEN @objectDetail = 1 AND pk.name = d.package_name THEN
                        (SELECT
                            op.parameter_name               ''@parameter_name''
                            ,op.description                 ''@description''
                            ,op.parameter_data_type         ''@parameter_data_type''
                            ,op.last_validation_time        ''@last_validation_time''
                            ,op.validation_status           ''@validation_status''
                            ,op.sensitive                   ''values/@sensitive''
                            ,op.value_set                   ''values/@value_set''
                            ,op.value_type                  ''values/@value_type''
                            ,op.referenced_variable_name    ''values/@referenced_variable_name''
                            ,op.design_default_value        ''values/design_default_value/processing-instruction(value)''
                            ,CASE
								WHEN op.sensitive = 1 AND @decryptSensitive = 0 THEN
									(SELECT ''''  ''values/default_value/sensitive-value-protected'' FOR XML PATH(''''), TYPE)
								WHEN op.sensitive = 1 AND @decryptSensitive = 1 AND op.sensitive_default_value IS NULL THEN
									(SELECT ''''  ''values/default_value/sensitive-value-not-available'' FOR XML PATH(''''), TYPE)
                                WHEN op.sensitive = 1 AND @decryptSensitive = 1 THEN
                                    (SELECT
                                    CASE [parameter_data_type]
                                        WHEN ''datetime'' THEN CONVERT(nvarchar(50), [internal].[get_value_by_data_type](DECRYPTBYKEYAUTOCERT(CERT_ID(N''MS_Cert_Proj_'' + CONVERT(nvarchar(20), op.project_id)), NULL, op.sensitive_default_value), [parameter_data_type]), 126)
                                        ELSE CONVERT(nvarchar(4000), [internal].[get_value_by_data_type](DECRYPTBYKEYAUTOCERT(CERT_ID(N''MS_Cert_Proj_'' + CONVERT(nvarchar(20), op.project_id)), NULL, op.sensitive_default_value), [parameter_data_type]))
                                    END ''values/default_value/processing-instruction(sensitive-value)''
                                    FOR XML PATH(''''), TYPE
                                    ) 
                    
                                ELSE 
                                    (SELECT op.default_value  ''values/devalue_value/processing-instruction(value)'' FOR XML PATH(''''), TYPE)
                            END
                        FROM internal.object_parameters op WITH(NOLOCK)
                        WHERE
                            op.project_version_lsn = pk.project_version_lsn
                            AND
                            op.object_name = pk.name
                        FOR XML PATH(''parameter''), ROOT(''parameters''), TYPE
                        )
                        ELSE NULL
                    END
                FROM internal.packages pk WITH(NOLOCK)
                WHERE 
                    pk.project_version_lsn = p.object_version_lsn
                    AND
                    (@projectDetail = 1 OR pk.name = d.package_name)
                FOR XML PATH(''package''), ROOT(''packages''), TYPE
            )
            ELSE NULL
           END
        FROM internal.projects pd WITH(NOLOCK)
        WHERE 
            pd.folder_id = f.folder_id
            AND
            (@folderDetail = 1 OR pd.object_version_lsn = p.object_version_lsn)
        FOR XML PATH(''project''), ROOT(''projects''), TYPE
    )
    ,CASE WHEN @folderDetail = 1 THEN
        (
            SELECT
                e.environment_name          ''@environment_name''
                ,e.environment_id           ''@environment_id''
                ,e.created_by_name          ''@created_by_name''
                ,e.created_time             ''@created_time''
                ,e.created_by_sid           ''@created_by_sid''
                ,e.description              ''@description''
            FROM internal.environments e WITH(NOLOCK)
            WHERE e.folder_id = f.folder_id
            FOR XML PATH(''environment''), ROOT(''environments''), TYPE
        )
        ELSE NULL
    END
FROM internal.projects p WITH(NOLOCK) 
INNER JOIN internal.folders f WITH(NOLOCK) ON f.folder_id = p.folder_id
WHERE 
    p.object_version_lsn = d.project_lsn
FOR XML PATH(''Folder''), TYPE
) AS objects_details
'
        ELSE N''
    END
    +
    CASE WHEN @execDetails = 1 THEN 
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
        
        ,CONVERT(nvarchar(10), DATEDIFF(DAY, d.start_time, ISNULL(d.end_time, SYSDATETIMEOFFSET()))) + ''d '' + CONVERT(nvarchar(15), CONVERT(time, DATEADD(MILLISECOND, DATEDIFF(MILLISECOND, DATEADD(DAY, DATEDIFF(day, d.start_time, ISNULL(end_time, SYSDATETIMEOFFSET())), d.start_time), ISNULL(d.end_time, SYSDATETIMEOFFSET())), DATEADD(DAY, DATEDIFF(day, d.start_time, ISNULL(d.end_time, SYSDATETIMEOFFSET())), 0)))) ''Operation/@duration''

        ,d.status_code              ''Operation/@status_code''
        ,d.process_id               ''Operation/@process_id''
        ,d.stopped_by_name          ''Operation/@stopped_by_name''
        ,d.stopped_by_sid           ''Operation/@stopped_by_sid''
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
        ))                          ''Execution'' ' 
ELSE '' END +

CASE WHEN @execDetails = 1 AND @includeParams = 1 THEN N'

        ,(SELECT 
             [execution_parameter_id]     ''@id''
            ,CASE [object_type]
                WHEN 20 THEN N''Project''
                WHEN 30 THEN N''Package''
                WHEN 50 THEN N''Execution''
                ELSE N''Unknown''
            END                           ''@type''
            ,[parameter_name]             ''@name''

            ,[sensitive]                  ''@sensitive''
            ,[parameter_data_type]        ''@data_type''
            ,[base_data_type]             ''@base_data_type''
            ,[required]                   ''@required''
            ,[value_set]                  ''@value_set''
            ,[object_type]                ''@object_type''
            ,[runtime_override]           ''@runtime_override''
            ,CASE
				WHEN epv.sensitive = 1 AND @decryptSensitive = 0 THEN
                    (SELECT ''''  ''sensitive-value-protected'' FOR XML PATH(''''), TYPE)
				WHEN epv.sensitive = 1 AND @decryptSensitive = 1 AND epv.[sensitive_parameter_value] IS NULL THEN
                    (SELECT ''''  ''sensitive-value-not-available'' FOR XML PATH(''''), TYPE)
                WHEN sensitive = 1 AND @decryptSensitive = 1 THEN 
					CASE 
						WHEN CERT_ID(N''MS_Cert_Exec_'' + CONVERT(nvarchar(20), d.execution_id)) IS NOT NULL THEN
							(SELECT
							CASE [parameter_data_type]
								WHEN ''datetime'' THEN CONVERT(nvarchar(50), [internal].[get_value_by_data_type](DECRYPTBYKEYAUTOCERT(CERT_ID(N''MS_Cert_Exec_'' + CONVERT(nvarchar(20), d.execution_id)), NULL, [sensitive_parameter_value]), [parameter_data_type]), 126)
								ELSE CONVERT(nvarchar(4000), [internal].[get_value_by_data_type](DECRYPTBYKEYAUTOCERT(CERT_ID(N''MS_Cert_Exec_'' + CONVERT(nvarchar(20), d.execution_id)), NULL, epv.[sensitive_parameter_value]), epv.[parameter_data_type]))
							END ''processing-instruction(sensitive-value)'' FOR XML PATH(''''), TYPE
							) 
						ELSE
							(SELECT
							CASE [parameter_data_type]
								WHEN ''datetime'' THEN CONVERT(nvarchar(50), [internal].[get_value_by_data_type](DECRYPTBYKEYAUTOCERT(CERT_ID(N''MS_Cert_Proj_Param_'' + CONVERT(nvarchar(20), d.object_id)), NULL, [sensitive_parameter_value]), [parameter_data_type]), 126)
								ELSE CONVERT(nvarchar(4000), [internal].[get_value_by_data_type](DECRYPTBYKEYAUTOCERT(CERT_ID(N''MS_Cert_Proj_Param_'' + CONVERT(nvarchar(20), d.object_id)), NULL, epv.[sensitive_parameter_value]), epv.[parameter_data_type]))
							END ''processing-instruction(sensitive-value)'' FOR XML PATH(''''), TYPE
							) 
					END
                ELSE 
                    (SELECT [parameter_value]  ''processing-instruction(value)'' FOR XML PATH(''''), TYPE)
            END
        FROM [internal].[execution_parameter_values] epv WITH(NOLOCK)
        WHERE epv.execution_id = d.execution_id
        ORDER BY [object_type], [parameter_name]
        FOR XML PATH(''Parameter''), ROOT(''Parameters''), TYPE)'
ELSE N''
END +
CASE WHEN @execDetails = 1 THEN
N'
        ,(SELECT 
               [property_id]        ''@id''
              ,[property_path]      ''@property_path''
              ,[sensitive]          ''@sensitive''
            --,CASE
            --    WHEN sensitive = 1 AND @decryptSensitive = 1 THEN 
            --        (SELECT
            --            CONVERT(nvarchar(4000), DECRYPTBYKEY([sensitive_property_value])) 
            --            ''processing-instruction(sensitive-value)''
            --        FOR XML PATH(''''), TYPE
            --        )                     
            --    ELSE 
            --        (SELECT [property_value]  ''processing-instruction(value)'' FOR XML PATH(''''), TYPE)
            --END

            ,CASE
				WHEN sensitive = 1 AND @decryptSensitive = 0 THEN
                    (SELECT ''''  ''sensitive-value-protected'' FOR XML PATH(''''), TYPE)
				WHEN sensitive = 1 AND @decryptSensitive = 1 AND [sensitive_property_value] IS NULL THEN
                    (SELECT ''''  ''sensitive-value-not-available'' FOR XML PATH(''''), TYPE)
                WHEN sensitive = 1 AND @decryptSensitive = 1 THEN 
					CASE 
						WHEN CERT_ID(N''MS_Cert_Exec_'' + CONVERT(nvarchar(20), d.execution_id)) IS NOT NULL THEN
							(SELECT
								CONVERT(nvarchar(4000), DECRYPTBYKEYAUTOCERT(CERT_ID(N''MS_Cert_Exec_'' + CONVERT(nvarchar(20), d.execution_id)), NULL, [sensitive_property_value]))
							''processing-instruction(sensitive-value)'' FOR XML PATH(''''), TYPE
							) 
						ELSE
							(SELECT
								CONVERT(nvarchar(4000), DECRYPTBYKEYAUTOCERT(CERT_ID(N''MS_Cert_Proj_Param_'' + CONVERT(nvarchar(20), d.object_id)), NULL, [sensitive_property_value]))
							''processing-instruction(sensitive-value)'' FOR XML PATH(''''), TYPE
							) 
					END
                ELSE 
                    (SELECT [property_value]  ''processing-instruction(value)'' FOR XML PATH(''''), TYPE)
            END

        FROM [internal].[execution_property_override_values] epo WITH(NOLOCK)
        WHERE epo.execution_id = d.execution_id
        ORDER BY [property_path]
        FOR XML PATH(''PropertyOverride''), ROOT(''PropertyOverrides''), TYPE)


    FOR XML PATH(''execution_details''), TYPE
    ) AS execution_details '
ELSE N'' END + N'

    ,' + CASE WHEN @localTime = 1 THEN N'CONVERT(datetime2(7), d.created_time) AS created_time' ELSE N'd.created_time' END + N'
' +
    CASE
        WHEN @id IS NULL THEN N',''sp_ssisdb ''''V:'' + FORMAT(d.execution_ID, ''G'') + N'' PM ES:1000 EM:1000 EDS:1000 ECP:1000 EPR:ALL, ESR:ALL'''',@package = '''''''', @msg_type = '''''''', @event_filter = '''''''', @phase_filter = '''''''', @task_filter = '''''''',
@subcomponent_filter = '''''''', @package_path = '''''''', @execution_path = '''''''', @msg_filter = '''''''', @src_component_name = '''''''', @dst_component_name = '''''''' '' as execution_details_command'
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
        'VariableValues'        [TableName]
        ,@debugLevel            [@debugLevel]
        ,@id                    [@id]
        ,@opLastCnt             [@opLastCnt]
        ,@totalMaxRows          [@totalMaxRows]
        ,@minInt                [@minInt]
        ,@maxInt                [@maxInt]
        ,@opValCount            [@opValCount]
        ,@opLastGrp             [@opLastGrp]
        ,@opFrom                [@opFrom]  
        ,@opTo                  [@opTo]
        ,@opFromTZ              [@opFromTZ]
        ,@opToTZ                [@opToTZ]          
        ,@includeExecPackages   [@includeExecPackages]
        ,@fldFilter             [@fldFilter]
        ,@prjFilter             [@prjFilter]
        ,@statusFilter          [@statusFilter]
        ,@durationCondition     [@durationCondition]
        ,@sql                   [@sql]
END


/* END DEBUG PRINT*/

    /**************              EXECUTION SECTION                ****************** */
    RAISERROR(N'', 0, 0) WITH NOWAIT;
    RAISERROR(N'', 0, 0) WITH NOWAIT;
    RAISERROR(N'Processing Information:', 0, 0) WITH NOWAIT;
    RAISERROR(N'-----------------------', 0, 0) WITH NOWAIT;

    IF @includeAgentReferences = 1
    BEGIN

        SET @tms = CONVERT(nvarchar(30), SYSDATETIME(), 121)
        RAISERROR(N'%s - Starting retrieving Agent references data...', 0, 0, @tms) WITH NOWAIT;

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

        BEGIN TRY
            EXECUTE AS CALLER;

            BEGIN TRY
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
            END TRY
            BEGIN CATCH
                SELECT
                    @msg = ERROR_MESSAGE()
                    ,@tms = CONVERT(nvarchar(30), SYSDATETIME(), 121)
                RAISERROR(N'%s - !!! Agent Job References data NOT AVAILABLE due to errors !!!, msg: %s', 0, 0, @tms, @msg) WITH NOWAIT;
            END CATCH

            REVERT
        END TRY
        BEGIN CATCH
            REVERT;
            THROW;
        END CATCH

        SET @tms = CONVERT(nvarchar(30), SYSDATETIME(), 121)
        RAISERROR(N'%s - Agent references data retrieval completed...', 0, 0, @tms) WITH NOWAIT;
    END

    IF @includeAgentJob = 1
    BEGIN
        SET @tms = CONVERT(nvarchar(30), SYSDATETIME(), 121)
        RAISERROR(N'%s - Starting retrieving Agent execution data...', 0, 0, @tms) WITH NOWAIT;

            IF OBJECT_ID('tempdb..#JobsExecutionData') IS NOT NULL
                DROP TABLE #JobsExecutionData;

            IF OBJECT_ID('tempdb..#credentials') IS NOT NULL
                DROP TABLE #credentials;

            IF OBJECT_ID('tempdb..#proxies') IS NOT NULL
                DROP TABLE #proxies;

            IF OBJECT_ID('tempdb..#operators') IS NOT NULL
                DROP TABLE #operators;

            CREATE TABLE #credentials (
                credential_id           int     NOT NULL PRIMARY KEY CLUSTERED
                ,name                   sysname 
                ,credential_identity    nvarchar(4000)
            )

            CREATE TABLE #proxies (
                proxy_id                int     NOT NULL PRIMARY KEY CLUSTERED
                ,name                   sysname
                ,credential_id          int
            )

            CREATE TABLE  #operators (
                id                      int     NOT NULL PRIMARY KEY CLUSTERED
                ,name                   sysname 
                ,email_address          nvarchar(100)
            )

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

        BEGIN TRY
            --Change context to caller as AllSchemaOwner has no access to msdb
            EXECUTE AS CALLER;

            BEGIN TRY
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
        END TRY
        BEGIN CATCH
            SELECT
                @msg = ERROR_MESSAGE()
                ,@tms = CONVERT(nvarchar(30), SYSDATETIME(), 121)
            RAISERROR(N'%s - !!! Agent Job Execution data NOT AVAILABLE due to errors !!!, msg: %s', 0, 0, @tms, @msg) WITH NOWAIT;
        END CATCH
        
            BEGIN TRY
                INSERT INTO #credentials (
                    credential_id
                    ,name
                    ,credential_identity
                )
                SELECT
                    credential_id
                    ,name
                    ,credential_id
                FROM sys.credentials WITH(NOLOCK)
            END TRY
            BEGIN CATCH
            SELECT
                @msg = ERROR_MESSAGE()
                ,@tms = CONVERT(nvarchar(30), SYSDATETIME(), 121)
                RAISERROR(N'%s - !!! Credentials data NOT AVAILABLE due to errors !!!, msg: %s', 0, 0, @tms, @msg) WITH NOWAIT;
            END CATCH

            BEGIN TRY
                INSERT INTO #proxies (
                    proxy_id
                    ,name
                    ,credential_id
                )
                SELECT
                    proxy_id
                    ,name
                    ,credential_id
                FROM msdb.dbo.sysproxies WITH(NOLOCK)
            END TRY
            BEGIN CATCH
            SELECT
                @msg = ERROR_MESSAGE()
                ,@tms = CONVERT(nvarchar(30), SYSDATETIME(), 121)
                RAISERROR(N'%s - !!! Proxies data NOT AVAILABLE due to errors !!!, msg: %s', 0, 0, @tms, @msg) WITH NOWAIT;
            END CATCH


            BEGIN TRY
                INSERT INTO   #operators (
                    id
                    ,name
                    ,email_address
                )
                SELECT
                    id,
                    name
                    ,email_address
                FROM msdb.dbo.sysoperators WITH(NOLOCK)
            END TRY
            BEGIN CATCH
            SELECT
                @msg = ERROR_MESSAGE()
                ,@tms = CONVERT(nvarchar(30), SYSDATETIME(), 121)
                RAISERROR(N'%s - !!! Operators data NOT AVAILABLE due to errors !!!', 0, 0, @tms, @msg) WITH NOWAIT;                
            END CATCH

            REVERT
        END TRY
        BEGIN CATCH
            REVERT;
            THROW;
        END CATCH

        CREATE INDEX #JobsExecutionData ON #JobsExecutionData (execution_id)

        SET @tms = CONVERT(nvarchar(30), SYSDATETIME(), 121)
        RAISERROR(N'%s - Agent execution data retrieval completed...', 0, 0, @tms) WITH NOWAIT;
    END


SET @tms = CONVERT(nvarchar(30), SYSDATETIME(), 121)
RAISERROR(N'%s - Starting retrieving SSISDB core operations data...', 0, 0, @tms) WITH NOWAIT;

/* EXECUTION OF THE MAIN QUERY */
EXEC sp_executesql @sql, N'@opLastCnt int, @messages_inrow int, @fromTZ datetimeoffset, @toTZ datetimeoffset, @minInt bigint, @maxInt bigint, @id bigint, @totalMaxRows int, @decryptSensitive bit, @folderDetail bit, @projectDetail bit, @objectDetail bit', 
    @opLastCnt, @max_messages, @opFromTZ, @opToTZ, @minInt, @maxInt, @id, @totalMaxRows, @decryptSensitive, @folderDetail, @projectDetail, @objectDetail

SET @tms = CONVERT(nvarchar(30), SYSDATETIME(), 121)
RAISERROR(N'%s - SSISDB core operations data retrieval completed...', 0, 0, @tms) WITH NOWAIT;





IF @id IS NOT NULL
BEGIN
    SET @tms = CONVERT(nvarchar(30), SYSDATETIME(), 121)
    RAISERROR(N'%s - Verbose mode filters preparation...', 0, 0, @tms) WITH NOWAIT;

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


    --from/To datetime is specified
    IF EXISTS(SELECT 1 FROM @opVal WHERE Val IN (N'D'))
    BEGIN
	    SET @opFrom = CONVERT(datetime, ISNULL((SELECT MinDateVal FROM @opVal WHERE Val = N'D'), CONVERT(date, GETDATE())))

	    SET @opTo = CONVERT(datetime, ISNULL((SELECT MaxDateVal FROM @opVal WHERE Val = N'D'), CONVERT(date, GETDATE())))

	    SET @opFromTZ = TODATETIMEOFFSET(@opFrom, DATEPART(TZ, SYSDATETIMEOFFSET()))
	            
        IF @opFrom <> @opTo
        BEGIN
            SET @opToTZ = TODATETIMEOFFSET(@opTo, DATEPART(TZ, SYSDATETIMEOFFSET()))
            SET @datetimeMsg = '                            - %s: Between ' +  CONVERT(nvarchar(30), @opFromTZ, 120) + N' and ' + CONVERT(nvarchar(30), @opToTZ, 120);
        END
        ELSE
        BEGIN
            SET @datetimeMsg = '                            - %s: From ' + CONVERT(nvarchar(30), @opFromTZ, 120)    
        END
    END


    /*EXECUTED PACKAGES */

        SET @tms = CONVERT(nvarchar(30), SYSDATETIME(), 121)
        SET @msg = N'%s - Starting retrieval of Executed packages';
        RAISERROR(@msg, 0, 0, @tms) WITH NOWAIT;
        IF @filterPkgStatus = 1
        BEGIN
            SET @msg = N'                            - Using Result Filter(s): ' + STUFF((SELECT ', ' + s.status FROM #EPstatuses s FOR XML PATH('')), 1, 2, '')
            RAISERROR(@msg, 0, 0) WITH NOWAIT;        
        END 


        SET @dateField = CASE WHEN @useEndTime = 1 THEN 'end_time' ELSE 'start_time' END;
        IF @opFromTZ IS NOT NULL
            RAISERROR(@datetimeMsg, 0, 0, @dateField) WITH NOWAIT;
        IF @durationCondition IS NOT NULL
            RAISERROR(N'                            - Duration: %s', 0, 0, @durationMsg) WITH NOWAIT;
    
    SET @sql = N'
				SELECT
					ROW_NUMBER() OVER(ORDER BY start_time)  package_no
					,package_name
                     ' +
                    CASE WHEN @localTime = 1 THEN N'
					,CONVERT(datetime2(7), start_time) AS start_time
					,CONVERT(datetime2(7), end_time) As end_time
                    '
                    ELSE N'
					,start_time
					,end_time
                    ' END + N'
                    ,RIGHT(''     '' + CONVERT(nvarchar(5), DATEDIFF(DAY, 0, durationDate)) + ''d '', 6) + CONVERT(varchar(12), CONVERT(time, durationDate)) AS duration' + 
                    CASE WHEN @duration_ms = 1 THEN N'
                    ,CONVERT(bigint, DATEDIFF(DAY, CONVERT(datetime2(7), ''19000101''), durationDate)) * 86400000 + DATEDIFF(MILLISECOND, DATEADD(DAY, DATEDIFF(DAY, ''19000101'', durationDate), ''19000101''), durationDate) AS duration_ms'
                    ELSE N'' END + N'
					,res AS result
                    ,result AS result_description
					,result_code
                    ,status_info' +
                    CASE 
                        WHEN @filterPkgStatus = 1 OR (@pkgFilter = 1 AND @filterPkg = 1) THEN  N',additional_info'
                        ELSE N''
                    END + N'
				FROM (
				  SELECT
					 ROW_NUMBER() OVER(PARTITION BY e.package_name ORDER BY CASE WHEN e.package_path = ''\Package'' THEN 0 ELSE 1 END ASC, es.start_time ASC) AS pno
                    ,CASE WHEN e.package_path = ''\Package'' OR d.status IN (3, 4, 6, 7, 9) THEN N''Final'' ELSE N''Preliminary'' END AS status_info
					,CASE
						(CASE WHEN e.package_path = ''\Package'' THEN es.execution_result WHEN d.status = 3 THEN 3 WHEN d.status = 6 THEN 6 WHEN d.status = 7 THEN 0 WHEN d.status = 4 THEN 1 WHEN d.status = 9 THEN 2 ELSE 99 END)
						WHEN 0 THEN N''S''  --Success
						WHEN 1 THEN N''F''  --Failure
						WHEN 2 THEN N''O''  --Completed
						WHEN 3 THEN N''C''  --Cancelled
                        WHEN 6 THEN N''U''  --Unexpected
                        WHEN 9 THEN N''P''  --Completed
                        WHEN 99 THEN N''R'' --Running
						ELSE N''K''
					END                 AS res

					,es.start_time
					,ISNULL(NULLIF(CASE WHEN e.package_path = ''\Package'' THEN es.end_time ELSE ''00010101'' END, ''00010101''), CASE WHEN d.status IN (3, 4, 6, 7, 9) THEN d.end_time ELSE NULL END)  end_time

                    ,DATEADD(MILLISECOND, DATEDIFF(MILLISECOND, DATEADD(DAY, DATEDIFF(MINUTE, es.start_time, ISNULL(NULLIF(CASE WHEN e.package_path = ''\Package'' THEN es.end_time ELSE ''00010101'' END, ''00010101''), 
						CASE WHEN d.status IN (3, 6, 9) THEN d.end_time ELSE SYSDATETIMEOFFSET() END)) / 1440, es.start_time), ISNULL(NULLIF(CASE WHEN e.package_path = ''\Package'' THEN es.end_time ELSE ''00010101'' END, ''00010101''), 
						CASE WHEN d.status IN (3, 6, 9) THEN d.end_time ELSE SYSDATETIMEOFFSET() END)), DATEADD(DAY, DATEDIFF(MINUTE, es.start_time, ISNULL(NULLIF(CASE WHEN e.package_path = ''\Package'' THEN es.end_time ELSE ''00010101'' END, ''00010101''), 
						CASE WHEN d.status IN (3, 6, 9) THEN d.end_time ELSE SYSDATETIMEOFFSET() END)) / 1400, CONVERT(datetime2(7), ''19000101''))) durationDate
					,e.package_name              package_name

					,CASE
						(CASE WHEN e.package_path = ''\Package'' THEN es.execution_result WHEN d.status = 3 THEN 3 WHEN d.status = 6 THEN 6 WHEN d.status = 7 THEN 0 WHEN d.status = 4 THEN 1 WHEN d.status = 9 THEN 2 ELSE 99 END)
						WHEN 0 THEN N''Success''
						WHEN 1 THEN N''Failure''
						WHEN 2 THEN N''Completion''
						WHEN 3 THEN N''Cancelled''
                        WHEN 6 THEN N''Unexpected''
                        WHEN 9 THEN N''Completed''
                        WHEN 99 THEN N''Running''
						ELSE N''Unknown''
					END                 AS result

					,NULLIF(CASE WHEN e.package_path = ''\Package'' THEN es.execution_result WHEN d.status = 3 THEN 3 WHEN d.status = 6 THEN 6 WHEN d.status = 7 THEN 0 WHEN d.status = 4 THEN 1 WHEN d.status = 9 THEN 2 ELSE 99 END, -9999)      result_code
                     ' +

                    CASE 
                        WHEN @filterPkgStatus = 1 OR (@pkgFilter = 1 AND @filterPkg = 1) THEN
                            N', N' + QUOTENAME(STUFF((SELECT
                                    N', ' + Info 
                                FROM (
                                    SELECT CASE WHEN @pkgFilter = 1 AND @filterPkg = 1 THEN N'PKG_FILTER' ELSE NULL END AS Info
                                    UNION ALL
                                    SELECT CASE WHEN @filterPkgStatus = 1 THEN 'STATUS_FILTER' ELSE NULL END AS Info
                                ) fltr
                                FOR XML PATH('')), 1, 2, N''), '''') + N' AS additional_info'
                        ELSE N''
                    END + N'
                FROM internal.operations d WITH(NOLOCK)
				INNER JOIN internal.executable_statistics es WITH(NOLOCK) ON es.execution_id = d.operation_id 
				INNER JOIN internal.executables e WITH(NOLOCK) ON e.executable_id = es.executable_id ' + 
                CASE
                    WHEN @pkgFilter = 1 AND @filterPkg = 1 THEN ' INNER JOIN #packages pkg ON pkg.package_name = e.package_name'
                    ELSE ''
                END +   
                CONVERT(nvarchar(max), N'
				LEFT JOIN  (
				SELECT
					 package_name 
					,ISNULL(MIN(es1.start_time), ''99991231'') AS start_time
					,ISNULL(MAX(es1.end_time), ''00010101'')  AS end_time
				FROM internal.executable_statistics es1 WITH(NOLOCK) 
				INNER JOIN internal.executables e1 WITH(NOLOCK) ON e1.executable_id = es1.executable_id 
				WHERE 
					e1.package_path = ''\Package'' AND es1.execution_id = @id
				GROUP BY e1.package_name
				) MM ON e.package_name = MM.package_name
				WHERE 
					d.operation_id = @id
					--AND
					--(
					--	e.package_path = ''\Package'' 
						--OR
						--(
						--	d.status IN (2, 5, 8)
						--	AND
						--	(
      --                          MM.start_time IS NULL
						--	)
						--)
					--)
		) EPD
		WHERE EPD.pno = 1 ') +
        CASE
            WHEN @filterPkgStatus = 1 THEN N' AND result_code IN (SELECT id FROM #EPStatuses) '
            ELSE N''
        END +                      
        CASE
            WHEN @durationCondition IS NOT NULL THEN N' AND ' + @durationCondition
            ELSE N''
        END +
        CASE
            WHEN @opFromTZ IS NOT NULL AND @opToTZ IS NOT NULL THEN CASE WHEN @useEndTime = 1 THEN N' AND (end_time' ELSE N' AND (start_time' END + N' BETWEEN  @fromTZ AND @toTZ)'
            WHEN @opFromTZ IS NOT NULL THEN CASE WHEN @useEndTime = 1 THEN N' AND (end_time' ELSE N' AND (start_time' END +' > @fromTZ)'
            ELSE N''
            END + N'
		ORDER BY ' +
        CASE @pkgSort
            WHEN 1 THEN N'package_name'
            WHEN 2 THEN N'durationDate'
            WHEN 3 THEN N'end_time'
            WHEN 4 THEN N'result'
            WHEN 5 THEN N'result_code'
          ELSE N'package_no'  
        END + 
        CASE WHEN @pkgSortDesc = 1 THEN N' DESC' ELSE ' ASC' END;


        IF @debugLevel > 3 
            SELECT @sql AS [executed_packages_query]

        IF EXISTS(SELECT 1 FROM [internal].[executable_statistics] es WITH(NOLOCK) WHERE es.execution_id = @id)
        BEGIN
            EXEC sp_executesql @sql, N'@id bigint, @fromTZ datetimeoffset, @toTZ datetimeoffset', @id, @opFromTZ, @opToTZ
        END
        ELSE
        BEGIN
            SET @tms = CONVERT(nvarchar(30), SYSDATETIME(), 121)
            SET @msg = N'%s - No information about executed pacakges was found for execution_id = %I64d'
            RAISERROR(@msg, 0, 0, @tms, @id) WITH NOWAIT;
        END

        SET @tms = CONVERT(nvarchar(30), SYSDATETIME(), 121)
        RAISERROR(N'%s - Executed pacakges retrieval completed...', 0, 0, @tms) WITH NOWAIT;

    /*EXECUTED PACKAGES END */

    /*EXECUTABLE STATISTICS */
    IF @includeExecutableStatistics = 1
    BEGIN
        SET @tms = CONVERT(nvarchar(30), SYSDATETIME(), 121)
        SET @msg = N'%s - Starting retrieval of Executable Statistics... (' + ISNULL(N'last ' + CONVERT(nvarchar(10), @execRows), N'All') + N' rows)';
        RAISERROR(@msg, 0, 0, @tms) WITH NOWAIT;
        

        IF OBJECT_ID('tempdb..#ESstatuses') IS NOT NULL
            DROP TABLE #ESstatuses;
        CREATE TABLE #ESstatuses (
            id          int          NOT NULL PRIMARY KEY CLUSTERED
            ,[status]   nvarchar(50) COLLATE DATABASE_DEFAULT
        );

        --Check if we have executable status filter
        IF @filterExecutableStatus = 1
        BEGIN
            IF @filterExecutableStatusFilter IS NOT NULL AND @filterExecutableStatusFilter <> N'' --process only if filter was specified
            BEGIN
                SET @xml = N'<i>' + REPLACE(REPLACE(@filterExecutableStatusFilter, N',', @xr), N' ', @xr) + N'</i>'
                
                INSERT INTO #ESstatuses(id, [status])
                SELECT DISTINCT
                    ast.id
                    ,ast.[status]
                FROM @availExecStatuses ast
                INNER JOIN (SELECT n.value(N'.', 'nvarchar(50)') value FROM @xml.nodes('/i') T(n)) st([status]) ON LEFT(st.[status], 1) <> '-' AND (st.[status] = ast.[status] OR st.status = ast.short OR st.[status] = 'ALL')
                EXCEPT
                SELECT DISTINCT
                    ast.id
                    ,ast.[status]
                FROM @availExecStatuses ast
                INNER JOIN (SELECT n.value(N'.', 'nvarchar(50)') value FROM @xml.nodes('/i') T(n)) st([status]) ON LEFT(st.[status], 1) = '-' AND (RIGHT(st.[status], LEN(st.[status]) -1) = ast.[status] OR RIGHT(st.[status], LEN(st.[status]) -1) = ast.short)
                
            END

            IF NOT((SELECT COUNT(1) FROM #ESstatuses) BETWEEN 1 AND 6)
            BEGIN
                SET @filterExecutableStatus = 0
            END
        END              



        SET @dateField = CASE WHEN @useEndTime = 1 THEN 'end_time' ELSE 'start_time' END;
        IF @opFromTZ IS NOT NULL
            RAISERROR(@datetimeMsg, 0, 0, @dateField) WITH NOWAIT;
        IF @durationCondition IS NOT NULL
            RAISERROR(N'                            - Duration: %s', 0, 0, @durationMsg) WITH NOWAIT;
        IF @execution_path IS NOT NULL
            RAISERROR(N'                            - Using execution_path Filter(s): %s', 0, 0, @execution_path) WITH NOWAIT;
        IF @package_path IS NOT NULL
            RAISERROR(N'                            - Using package_path Filter(s): %s', 0, 0, @package_path) WITH NOWAIT;
        IF @filterExecutableStatus = 1
        BEGIN
           SET @msg = N'                            - Using Result Filter(s): ' + STUFF((SELECT ', ' + s.status FROM #ESstatuses s FOR XML PATH('')), 1, 2, '')
            RAISERROR(@msg, 0, 0) WITH NOWAIT;        
        END 

        SET @sql = N'
            WITH ExecStat AS (
                SELECT
                    *
                    ,DATEADD(MILLISECOND, DATEDIFF(MILLISECOND, DATEADD(DAY, DATEDIFF(MINUTE, start_time, ISNULL(end_time, SYSDATETIMEOFFSET())) / 1440, start_time), ISNULL(end_time, SYSDATETIMEOFFSET())), DATEADD(DAY, DATEDIFF(MINUTE, start_time, ISNULL(end_time, SYSDATETIMEOFFSET())) / 1400, CONVERT(datetime2(3), ''19000101''))) durationDate
                FROM [internal].[executable_statistics] WITH(NOLOCK)
                WHERE execution_id = @id '+
                CASE
                    WHEN @opFromTZ IS NOT NULL AND @opToTZ IS NOT NULL THEN CASE WHEN @useEndTime = 1 THEN N' AND (end_time' ELSE N' AND (ISNULL(start_time, ''99991231'')' END + N' BETWEEN  @fromTZ AND @toTZ)'
                    WHEN @opFromTZ IS NOT NULL THEN CASE WHEN @useEndTime = 1 THEN N' AND (end_time' ELSE N' AND (ISNULL(start_time, ''99991231'')' END +' > @fromTZ)'
                    ELSE N''
                  END + N'
            )
            SELECT ' + CASE WHEN @execRows IS NOT NULL THEN N'TOP (@execRows)' ELSE N'' END + N'
                es.[statistics_id]
                ,e.package_name
                ,e.package_path
                ,es.[execution_path] ' +
                CASE WHEN @localTime = 1  THEN N'
                ,CONVERT(datetime2(7), es.[start_time]) AS [start_time]
                ,CONVERT(datetime2(7), es.[end_time]) AS [end_time]'
                ELSE N'
                ,es.[start_time]
                ,es.[end_time] '
                END + N'
                ,FORMAT(es.[execution_duration] / 86400000, ''##0\d '') +
                CONVERT(nchar(12), CONVERT(time, DATEADD(MILLISECOND, es.[execution_duration] % 86400000, CONVERT(datetime2, ''19000101'')))) AS duration ' +
                CASE WHEN @duration_ms = 1 THEN N'
                ,es.[execution_duration] AS duration_ms '
                ELSE N'' END + N'
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
             FROM ExecStat es
             INNER JOIN [internal].[executables] e WITH(NOLOCK) ON e.executable_id = es.executable_id
    ' +
        CASE 
            WHEN @pkgFilter = 1 THEN N' INNER JOIN #packages pkg ON pkg.package_name = e.package_name'
            ELSE ''
        END + N'
             WHERE 1=1' +
        CASE
            WHEN @durationCondition IS NOT NULL THEN N' AND ' + @durationCondition
            ELSE N''
        END +
        CASE
            WHEN NULLIF(@execution_path, '') IS NOT NULL THEN N' AND (EXISTS(SELECT 1 FROM #execution_paths f WHERE es.execution_path LIKE f.filter AND f.exclusive = 0) AND NOT EXISTS(SELECT 1 FROM #execution_paths f WHERE es.execution_path LIKE f.filter AND f.exclusive = 1))'
            ELSE N''
        END + 
        CASE
            WHEN NULLIF(@package_path, '') IS NOT NULL THEN N' AND (EXISTS(SELECT 1 FROM #package_paths f WHERE e.package_path LIKE f.filter AND f.exclusive = 0) AND NOT EXISTS(SELECT 1 FROM #package_paths f WHERE e.package_path LIKE f.filter AND f.exclusive = 1))'
            ELSE N''
        END +
        CASE WHEN @filterExecutableStatus = 1 
            THEN N' AND (es.[execution_result] IN (SELECT id FROM #ESStatuses))' 
            ELSE N''
        END + N'
             ORDER BY ' + CASE WHEN @useStartTime =1 THEN N'ISNULL(es.start_time, ''99991231'')' WHEN @useEndTime = 1 THEN N'ISNULL(es.end_time, ''99991231'')' ELSE N'es.end_time' END + CASE WHEN @useTimeDescending = 1THEN  N' DESC' ELSE N' ASC' END

        IF @debugLevel > 3 
            SELECT @sql AS [executable_statistics_query]

        IF EXISTS(SELECT 1 FROM [internal].[executable_statistics] es WITH(NOLOCK) WHERE es.execution_id = @id)
        BEGIN
            EXEC sp_executesql @sql, N'@id bigint, @execRows int, @package_path nvarchar(max), @execution_path nvarchar(max), @fromTZ datetimeoffset, @toTZ datetimeoffset', @id, @execRows, @package_path, @execution_path, @opFromTZ, @opToTZ
        END
        ELSE
        BEGIN
            SET @tms = CONVERT(nvarchar(30), SYSDATETIME(), 121)
            SET @msg = N'%s - No Executable statistics exists for execution_id = %I64d'
            RAISERROR(@msg, 0, 0, @tms, @id) WITH NOWAIT;
        END

        SET @tms = CONVERT(nvarchar(30), SYSDATETIME(), 121)
        RAISERROR(N'%s - Executable Statistics retrieval completed...', 0, 0, @tms) WITH NOWAIT;

    END --IF @includeExecutableStatistics = 1

    IF @includeMessages = 1
    BEGIN
        SET @tms = CONVERT(nvarchar(30), SYSDATETIME(), 121)
        SET @msg = N'%s - Starting retrieval of Event Messages... (' + ISNULL(N'last ' + CONVERT(nvarchar(10), @max_messages), N'All') + N' rows)';
        RAISERROR(@msg, 0, 0, @tms) WITH NOWAIT;

        /* EVENT MESSAGES */
        IF EXISTS(SELECT 1 FROM internal.operation_messages om WITH(NOLOCK) WHERE om.operation_id = @id)
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
                FROM internal.event_messages em WITH(NOLOCK)
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
                FROM internal.event_messages em WITH(NOLOCK)
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
                FROM internal.event_messages em WITH(NOLOCK)
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
                    SET @subComponentFilter = 1               
                    SET @subcomponent_filter = REPLACE(STUFF((SELECT DISTINCT ', ' + LTRIM(RTRIM(n.value('.','nvarchar(128)'))) FROM @xml.nodes('/i') T(n) FOR XML PATH('')), 1, 2, ''), N'%', N'%%')
                END
                ELSE
                    SET @subComponentFilter = 0
            END

        --@src_component_name = source_name
        IF @src_component_name IS NOT NULL
        BEGIN
            SET @xml = N'<i>' + REPLACE(@src_component_name, N',', @xr) + N'</i>'

            CREATE TABLE #src_names (
                 filter     nvarchar(4000) COLLATE DATABASE_DEFAULT
                ,exclusive  bit
            )

            ;WITH FilterValues AS (
                SELECT DISTINCT
                    LTRIM(RTRIM(n.value(N'.', 'nvarchar(50)'))) value
                FROM @xml.nodes('/i') T(n)
            )
            INSERT INTO #src_names (filter, exclusive)
            SELECT
                CASE WHEN LEFT(value, 1) = '-' THEN RIGHT(value, LEN(value) -1) ELSE value END
                ,CASE WHEN LEFT(value, 1) = '-' THEN 1 ELSE 0 END
            FROM FilterValues

            IF EXISTS(SELECT 1 fROM #src_names)
            BEGIN
                    SET @sourceFilter = 1               
                    SET @source_filter = REPLACE(STUFF((SELECT DISTINCT ', ' + LTRIM(RTRIM(n.value('.','nvarchar(128)'))) FROM @xml.nodes('/i') T(n) FOR XML PATH('')), 1, 2, ''), N'%', N'%%')
            END

        END


            SET @sql = CONVERT(nvarchar(max), N'WITH MessageData AS (
            SELECT ' + CASE WHEN @max_messages IS NOT NULL THEN N'TOP (@max_messages)' ELSE N'' END + N'
                om.operation_message_id ' +
                CASE WHEN @detailedMessageTracking = 1 THEN N'
                ,ISNULL(mpk.package_name, em.package_name) AS package_name
                ,ISNULL(mpk.package_path, em.package_path) AS package_path'
                ELSE N'
                ,em.package_name
                ,em.package_path'
                END + N'
                ,em.message_source_name                     AS source_name
                ,em.subcomponent_name
                ,em.event_name ') +
                CASE WHEN @localTime = 1 THEN N',CONVERT(datetime2(7), om.message_time) AS message_time' ELSE N',om.message_time' END + N'
				,CASE WHEN em.event_message_id IS NULL THEN ''OPERATION'' ELSE ''EVENT'' END AS message_kind
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
                    mc.context_depth                            ''@depth''
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
                    END                                         ''@type_desc''
                     ,mc.property_name                           ''@property_name''
                    ,mc.context_source_name                     ''@source_name''
                    ,mc.package_path                            ''@package_path''
                    ,mc.context_type                            ''@type''
                    ,CONVERT(xml, N''<?value -- '' + REPLACE(REPLACE(CONVERT(nvarchar(max), mc.property_value), N''<?'', N''''), N''?>'', N'''') + N''--?>'')
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

                ,em.execution_path
                ,em.message_source_id
                ,em.package_location_type
                ,om.message_source_type                     AS source_type
                ,om.message_type                            AS message_type
                ,em.threadID
            FROM internal.operation_messages om WITH(NOLOCK)
            INNER JOIN internal.executions ex WITH(NOLOCK) ON om.operation_id = ex.execution_id
            LEFT JOIN internal.event_messages em WITH(NOLOCK) ON em.event_message_id = om.operation_message_id ' +
            CASE 
                WHEN @detailedMessageTracking = 1 THEN N'
                OUTER APPLY (SELECT TOP 1 package_name, package_path FROM internal.executables e WHERE e.project_version_lsn = ex.project_lsn AND e.executable_guid = em.message_source_id) mpk'
                ELSE N''
            END +
            CASE 
                WHEN @detailedMessageTracking = 0 AND @pkgFilter = 1 THEN N'
                 INNER JOIN #packages pkg ON pkg.package_name = em.package_name'
                ELSE N''
            END + 
            CASE
                WHEN @msgTypeFilter = 1 THEN N'
                 INNER JOIN #msgTypes mt ON mt.id = om.message_type'
                ELSE N''
            END +
            CASE 
                WHEN @taskFilter = 1 THEN N'
                 INNER JOIN #tasks tf ON tf.task_name = em.message_source_name'
                ELSE N''
            END +
            CASE 
                WHEN @eventFilter = 1 THEN N'
                 INNER JOIN #events ef ON ef.event_name = em.event_name'
                ELSE N''
            END +
            CASE 
                WHEN @subComponentFilter = 1 THEN N'
                 INNER JOIN #subComponents cf ON cf.subcomponent_name = em.subcomponent_name'
                ELSE N''
            END + N'
            WHERE om.operation_id = @id' +
            CASE 
                WHEN @messageKind >= 3 THEN N''
                WHEN (@messageKind & 1) = 1 THEN N' AND em.event_message_id IS NULL'
                WHEN (@messageKind & 2) = 2 THEN N' AND em.event_message_id IS NOT NULL'
                ELSE N''
            END + N')
            SELECT
                 md.operation_message_id
                ,md.package_name
                ,md.source_name
                ,md.subcomponent_name
                ,md.event_name
                ,md.message_time
                ,md.message_kind
                ,md.message_type_desc
                ,md.message
                ,md.source_type_desc
                ,md.package_path
                ,md.execution_path
                ,md.message_source_id
                ,md.package_location_type
                ,md.source_type
                ,md.message_type
                ,md.threadID
            FROM MessageData md ' +
            CASE 
                WHEN @detailedMessageTracking = 1 AND @pkgFilter = 1 THEN N'
                 INNER JOIN #packages pkg ON pkg.package_name = md.package_name'
                ELSE N''
            END +  N'
            WHERE (1=1) ' +
            CASE
                WHEN @sourceFilter = 1 THEN N'
                 AND (EXISTS(SELECT 1 FROM #src_names f WHERE md.source_name LIKE f.filter AND f.exclusive = 0) AND NOT EXISTS(SELECT 1 FROM #src_names f WHERE md.source_name LIKE f.filter AND f.exclusive = 1))'
                ELSE N''
            END + 
            CASE
                WHEN NULLIF(@execution_path, '') IS NOT NULL THEN N'
                 AND (EXISTS(SELECT 1 FROM #execution_paths f WHERE md.execution_path LIKE f.filter AND f.exclusive = 0) AND NOT EXISTS(SELECT 1 FROM #execution_paths f WHERE md.execution_path LIKE f.filter AND f.exclusive = 1))'
                ELSE N''
            END + 
            CASE
                WHEN NULLIF(@msg_filter, '') IS NOT NULL THEN  N'
                 AND (EXISTS(SELECT 1 FROM #msg_filters mf WHERE md.message LIKE mf.filter AND mf.exclusive = 0) AND NOT EXISTS(SELECT 1 FROM #msg_filters mf WHERE md.message LIKE mf.filter AND mf.exclusive = 1))'
                ELSE N''
            END +
            CASE
                WHEN NULLIF(@package_path, '') IS NOT NULL THEN N'
                 AND (EXISTS(SELECT 1 FROM #package_paths f WHERE md.package_path LIKE f.filter AND f.exclusive = 0) AND NOT EXISTS(SELECT 1 FROM #package_paths f WHERE md.package_path LIKE f.filter AND f.exclusive = 1))'
                ELSE N''
            END +
            CASE
                WHEN @opFromTZ IS NOT NULL AND @opToTZ IS NOT NULL THEN N' AND (message_time BETWEEN @fromTZ AND @toTZ)'
                WHEN @opFromTZ IS NOT NULL THEN N' AND (message_time  > @fromTZ)'
                ELSE N''
            END + N'
            ORDER BY 
                 md.message_time' + CASE WHEN @useTimeDescending = 1 THEN  N' DESC' ELSE N' ASC' END + N'
                ,md.operation_message_id' + CASE WHEN @useTimeDescending = 1 THEN  N' DESC' ELSE N' ASC' END 


            IF @opFromTZ IS NOT NULL
                RAISERROR(@datetimeMsg, 0, 0, 'message_time') WITH NOWAIT;
            IF @taskFilter = 1
            BEGIN                             
                SET @msg = N'                            - Using Task Filter(s): ' + @task_filter
                RAISERROR(@msg, 0, 0) WITH NOWAIT;
            END
            IF @taskFilter = 1
            BEGIN                             
                SET @msg = N'                            - Using Event Filter(s): ' + @event_filter
                RAISERROR(@msg, 0, 0) WITH NOWAIT;
            END
            IF @sourceFilter = 1
                RAISERROR(N'                            - Using source_name Filter(s): %s', 0, 0, @source_filter) WITH NOWAIT;
            IF @subComponentFilter = 1
            BEGIN                             
                SET @msg = N'                            - Using SubComponent Filter(s): ' + @subcomponent_filter
                RAISERROR(@msg, 0, 0) WITH NOWAIT;
            END
            IF @execution_path IS NOT NULL
                RAISERROR(N'                            - Using execution_path Filter(s): %s', 0, 0, @execution_path) WITH NOWAIT;
            IF @package_path IS NOT NULL
                RAISERROR(N'                            - Using package_path Filter(s): %s', 0, 0, @package_path) WITH NOWAIT;

            IF @debugLevel > 3
                SELECT @sql AS [event_messages_query]

            EXEC sp_executesql @sql, N'@id bigint, @max_messages int, @execution_path nvarchar(max), @package_path nvarchar(max), @event_filter nvarchar(max), @msg_filter nvarchar(max), @fromTZ datetimeoffset, @toTZ datetimeoffset', 
                @id, @max_messages, @execution_path, @package_path, @event_filter, @msg_filter, @opFromTZ, @opToTZ

            SET @tms = CONVERT(nvarchar(30), SYSDATETIME(), 121)
            RAISERROR(N'%s - Retrieval of Event Messages completed...', 0, 0, @tms) WITH NOWAIT;

        END
        ELSE
        BEGIN
             SET @tms = CONVERT(nvarchar(30), SYSDATETIME(), 121)
            SET @msg = N'%s - No Event Messasges exists for execution_id = %I64d'
            RAISERROR(@msg, 0, 0, @tms, @id) WITH NOWAIT;
        END
    END --IF @includeMessages = 1

    /* EXECUTABLE DATA STATISTICS */
    IF @includeEDS = 1 AND EXISTS(SELECT 1 FROM [internal].[execution_data_statistics] WITH(NOLOCK) WHERE execution_id = @id)
    BEGIN
        SET @tms = CONVERT(nvarchar(30), SYSDATETIME(), 121)
        SET @msg = N'%s - Starting retrieval of Execution Data Statistics... (' + ISNULL(N'last ' + CONVERT(nvarchar(10), @edsRows), N'All') + N' rows)';
        RAISERROR(@msg, 0, 0, @tms) WITH NOWAIT;

        IF @opFromTZ IS NOT NULL
            RAISERROR(@datetimeMsg, 0, 0, 'created_time') WITH NOWAIT;


        --@src_component_name
        IF @src_component_name IS NOT NULL
        BEGIN
            SET @xml = N'<i>' + REPLACE(@src_component_name, N',', @xr) + N'</i>'

            CREATE TABLE #src_component_names (
                 filter     nvarchar(4000) COLLATE DATABASE_DEFAULT
                ,exclusive  bit
            )

            ;WITH FilterValues AS (
                SELECT DISTINCT
                    LTRIM(RTRIM(n.value(N'.', 'nvarchar(50)'))) value
                FROM @xml.nodes('/i') T(n)
            )
            INSERT INTO #src_component_names (filter, exclusive)
            SELECT
                CASE WHEN LEFT(value, 1) = '-' THEN RIGHT(value, LEN(value) -1) ELSE value END
                ,CASE WHEN LEFT(value, 1) = '-' THEN 1 ELSE 0 END
            FROM FilterValues

            RAISERROR(N'                            - Using source_component_name Filter(s): %s', 0, 0, @src_component_name) WITH NOWAIT;
        END

        --@dst_component_name
        IF @dst_component_name IS NOT NULL
        BEGIN
            SET @xml = N'<i>' + REPLACE(@dst_component_name, N',', @xr) + N'</i>'

            CREATE TABLE #dst_component_names (
                 filter     nvarchar(4000) COLLATE DATABASE_DEFAULT
                ,exclusive  bit
            )

            ;WITH FilterValues AS (
                SELECT DISTINCT
                    LTRIM(RTRIM(n.value(N'.', 'nvarchar(50)'))) value
                FROM @xml.nodes('/i') T(n)
            )
            INSERT INTO #dst_component_names (filter, exclusive)
            SELECT
                CASE WHEN LEFT(value, 1) = '-' THEN RIGHT(value, LEN(value) -1) ELSE value END
                ,CASE WHEN LEFT(value, 1) = '-' THEN 1 ELSE 0 END
            FROM FilterValues

            RAISERROR(N'                            - Using destination_component_name Filter(s): %s', 0, 0, @dst_component_name) WITH NOWAIT;
        END

        IF @execution_path IS NOT NULL
            RAISERROR(N'                            - Using execution_path Filter(s): %s', 0, 0, @execution_path) WITH NOWAIT;
        IF @package_path IS NOT NULL
            RAISERROR(N'                            - Using package_path Filter(s): %s', 0, 0, @package_path) WITH NOWAIT;

        SET @sql = N'
            SELECT ' + CASE WHEN @edsRows IS NOT NULL THEN N' TOP (@edsRows) ' ELSE N'' END + N'
                 eds.[data_stats_id] ' +
                 CASE WHEN @localTime = 1 THEN N',CONVERT(datetime2(7), eds.[created_time]) AS [created_time]' ELSE ',eds.[created_time]' END + N'                
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
              FROM [internal].[execution_data_statistics] eds WITH(NOLOCK) 
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
            WHEN NULLIF(@src_component_name, '') IS NOT NULL THEN N' AND (EXISTS(SELECT 1 FROM #src_component_names f WHERE eds.source_component_name LIKE f.filter AND f.exclusive = 0) AND NOT EXISTS(SELECT 1 FROM #src_component_names f WHERE eds.source_component_name LIKE f.filter AND f.exclusive = 1))'
            ELSE N''
        END + 
        CASE
            WHEN NULLIF(@dst_component_name, '') IS NOT NULL THEN N' AND (EXISTS(SELECT 1 FROM #dst_component_names f WHERE eds.destination_component_name LIKE f.filter AND f.exclusive = 0) AND NOT EXISTS(SELECT 1 FROM #dst_component_names f WHERE eds.destination_component_name LIKE f.filter AND f.exclusive = 1))'
            ELSE N''
        END + 
        CASE
            WHEN NULLIF(@package_path, '') IS NOT NULL THEN N' AND (EXISTS(SELECT 1 FROM #package_paths f WHERE eds.package_path_full LIKE f.filter AND f.exclusive = 0) AND NOT EXISTS(SELECT 1 FROM #package_paths f WHERE eds.package_path_full LIKE f.filter AND f.exclusive = 1))'
            ELSE N''
        END +
        CASE
            WHEN @opFromTZ IS NOT NULL AND @opToTZ IS NOT NULL THEN N' AND (created_time BETWEEN @fromTZ AND @toTZ)'
            WHEN @opFromTZ IS NOT NULL THEN N' AND (created_time > @fromTZ)'
            ELSE N''
        END + N'
             ORDER BY created_time ' + CASE WHEN @useTimeDescending = 1THEN  N' DESC' ELSE N' ASC' END 
        
        EXEC sp_executesql @sql, N'@id bigint, @edsRows int, @package_path nvarchar(max), @execution_path nvarchar(max), @fromTZ datetimeoffset, @toTZ datetimeoffset', @id, @edsRows, @package_path, @execution_path, @opFromTZ, @opToTZ

        SET @tms = CONVERT(nvarchar(30), SYSDATETIME(), 121)
        RAISERROR(N'%s - Execution Data Statistics retrieval completed...', 0, 0, @tms) WITH NOWAIT;

    END --IF @includeEDS = 1 AND EXISTS(SELECT 1 FROM [internal].[execution_data_statistics] WHERE execution_id = @id)
    ELSE IF @includeEDS = 1
    BEGIN
        SET @tms = CONVERT(nvarchar(30), SYSDATETIME(), 121)
        SET @msg = N'%s - No Execution Data Statistics exists for execution_id = %I64d'
        RAISERROR(@msg, 0, 0, @tms, @id) WITH NOWAIT;
        SET @tms = CONVERT(nvarchar(30), SYSDATETIME(), 121)
        RAISERROR(N'%s - Execution Data Statistics retrieval completed...', 0, 0, @tms) WITH NOWAIT;
    END --ELSE IF @includeEDS = 1

    /* EXECUTION COMPONENT PHASES */
    IF @includeECP = 1
    BEGIN
        SET @tms = CONVERT(nvarchar(30), SYSDATETIME(), 121)
        SET @msg = N'%s - Processing Execution Component Phases... (' + ISNULL(N'last ' + CONVERT(nvarchar(10), @ecpRows), N'All') + N' rows)';
        RAISERROR(@msg, 0, 0, @tms) WITH NOWAIT;

    END
    IF @includeECP = 1 AND EXISTS(SELECT 1 FROM internal.execution_component_phases WITH(NOLOCK) WHERE execution_id = @id)
    BEGIN
        
        SET @dateField = CASE WHEN @useEndTime = 1 THEN 'end_time' ELSE 'start_time' END;
        IF @opFromTZ IS NOT NULL
            RAISERROR(@datetimeMsg, 0, 0, @dateField) WITH NOWAIT;

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
            FROM internal.execution_component_phases  WITH(NOLOCK)
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
            FROM internal.execution_component_phases WITH(NOLOCK)
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
            FROM internal.execution_component_phases cp WITH(NOLOCK)
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
                SET @subComponentFilter = 1               
                SET @subcomponent_filter = REPLACE(STUFF((SELECT DISTINCT ', ' + LTRIM(RTRIM(n.value('.','nvarchar(128)'))) FROM @xml.nodes('/i') T(n) FOR XML PATH('')), 1, 2, ''), N'%', N'%%')
            END
            ELSE
                SET @subComponentFilter = 0
        END

        IF @durationCondition IS NOT NULL
            RAISERROR(N'                            - Duration: %s', 0, 0, @durationMsg) WITH NOWAIT;
        IF @execution_path IS NOT NULL
            RAISERROR(N'                            - Using execution_path Filter(s): %s', 0, 0, @execution_path) WITH NOWAIT;
        IF @package_path IS NOT NULL
            RAISERROR(N'                            - Using package_path Filter(s): %s', 0, 0, @package_path) WITH NOWAIT;


        SET @sql = N'WITH ComponentPhases AS (
            SELECT 
                sp.phase_stats_id       AS [phase_stats_id]
                ,sp.package_name        AS [package_name]
                ,sp.task_name           AS [task_name]
                ,sp.subcomponent_name   AS [subcomponent_name]
                ,sp.phase               AS [phase]
                ,sp.phase_time          AS [start_time]
                ,ep.phase_time          AS [end_time]
                ,DATEADD(NANOSECOND, DATEDIFF(NANOSECOND, DATEADD(second, DATEDIFF(second, sp.phase_time, ISNULL(ep.phase_time, SYSDATETIMEOFFSET())), sp.phase_time), ISNULL(ep.phase_time, SYSDATETIMEOFFSET())), DATEADD(second, DATEDIFF(second, sp.phase_time, ISNULL(ep.phase_time, SYSDATETIMEOFFSET())), CONVERT(datetime2(7), ''19000101''))) AS durationDate
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
            WHEN @subComponentFilter = 1 THEN N' INNER JOIN #subComponents cf ON cf.subcomponent_name = sp.subcomponent_name'
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
            WHEN NULLIF(@execution_path, '') IS NOT NULL THEN N' AND (EXISTS(SELECT 1 FROM #execution_paths f WHERE sp.execution_path LIKE f.filter AND f.exclusive = 0) AND NOT EXISTS(SELECT 1 FROM #execution_paths f WHERE sp.execution_path LIKE f.filter AND f.exclusive = 1))'
            ELSE N''
        END + 
        CASE
            WHEN NULLIF(@package_path, '') IS NOT NULL THEN N' AND (EXISTS(SELECT 1 FROM #package_paths f WHERE sp.package_path_full LIKE f.filter AND f.exclusive = 0) AND NOT EXISTS(SELECT 1 FROM #package_paths f WHERE sp.package_path_full LIKE f.filter AND f.exclusive = 1))'
            ELSE N''
        END + N'
        )
        SELECT ' + CASE WHEN @ecpRows IS NOT NULL THEN N' TOP (@ecpRows) ' ELSE N'' END + N'
            [phase_stats_id]
            ,[package_name]
            ,[task_name]
            ,[subcomponent_name]
            ,[phase] ' +
            CASE WHEN @localTime = 1 THEN N'
            ,CONVERT(datetime2(7), [start_time]) AS [start_time]
            ,CONVERT(datetime2(7), [end_time]) AS [end_time]'
            ELSE  N'
            ,[start_time]
            ,[end_time]'
            END + N'
            ,CASE WHEN durationDate >= ''19000102'' THEN CONVERT(varchar(3), DATEDIFF(DAY, ''19000101'', durationDate)) + ''d '' + CONVERT(varchar(16),  CONVERT(time, [durationDate])) ELSE CONVERT(varchar(16),  CONVERT(time, [durationDate])) END AS [duration] ' +
            CASE WHEN @duration_ms = 1 THEN N'
            ,CONVERT(bigint, DATEDIFF(SECOND, CONVERT(datetime2(7), ''19000101''), durationDate)) * 1000000000 +
             CONVERT(bigint, DATEDIFF(NANOSECOND, DATEADD(SECOND, DATEDIFF(SECOND, CONVERT(datetime2(7), ''19000101''), durationDate), ''19000101''), durationDate)) AS [duration_ns]'
             ELSE N'' END + N'
            ,[sequence]   
            ,[execution_path]
            ,[package_path]
        FROM ComponentPhases
        WHERE (1=1) ' +
        CASE
            WHEN @opFromTZ IS NOT NULL AND @opToTZ IS NOT NULL THEN CASE WHEN @useEndTime = 1 THEN N' AND (end_time' ELSE N' AND (ISNULL(start_time, ''99991231'')' END + N' BETWEEN  @fromTZ AND @toTZ)'
            WHEN @opFromTZ IS NOT NULL THEN CASE WHEN @useEndTime = 1 THEN N' AND (end_time' ELSE N' AND (ISNULL(start_time, ''99991231'')' END +' > @fromTZ)'
            ELSE N''
        END + 
        CASE
            WHEN @durationCondition IS NOT NULL THEN N' AND ' + @durationCondition 
            ELSE N''
        END +N'
        ORDER BY ' + CASE WHEN @useStartTime =1 THEN N'ISNULL(start_time, ''99991231'')' WHEN @useEndTime = 1 THEN N'ISNULL(end_time, ''99991231'')' ELSE N'sequence' END + CASE WHEN @useTimeDescending = 1THEN  N' DESC' ELSE N' ASC' END 
        
        IF @phaseFilter = 1
        BEGIN
            RAISERROR(N'                            - Using Phase Filter(s): %s', 0, 0, @phase_filter) WITH NOWAIT;
        END
        IF @taskFilter = 1
        BEGIN
            RAISERROR(N'                            - Using Task Filter(s): %s', 0, 0, @task_filter) WITH NOWAIT;
        END
        IF @subComponentFilter = 1
        BEGIN
            RAISERROR(N'                            - Using SubComponent Filter(s): %s', 0, 0, @subcomponent_filter) WITH NOWAIT;
        END

        IF @debugLevel > 3 
            SELECT @sql as [Execution_Component_Phases_query]
        
        EXEC sp_executesql @sql, N'@id bigint, @ecpRows int, @package_path nvarchar(max), @execution_path nvarchar(max), @fromTZ datetimeoffset, @toTZ datetimeoffset', @id, @ecpRows, @package_path, @execution_path, @opFromTZ, @opToTZ

        SET @tms = CONVERT(nvarchar(30), SYSDATETIME(), 121)
        RAISERROR(N'%s - Execution Component Phases retrieval completed...', 0, 0, @tms) WITH NOWAIT;

    END --IF @includeECP = 1 AND EXISTS(SELECT 1 FROM internal.execution_component_phases WITH(NOLOCK) WHERE execution_id = @id)
    ELSE IF @includeECP = 1
    BEGIN
        SET @tms = CONVERT(nvarchar(30), SYSDATETIME(), 121)
        RAISERROR(N'%s - No Execution Component Phases exits for execution_id = %I64d', 0, 0, @tms, @id) WITH NOWAIT;
        SET @tms = CONVERT(nvarchar(30), SYSDATETIME(), 121)
        RAISERROR(N'%s - Execution Component Phases retrieval completed...', 0, 0, @tms) WITH NOWAIT;
    END --ELSE IF @includeECP = 1
END
GO
IF NOT EXISTS(SELECT 1 FROM sys.database_principals WHERE TYPE = 'R' AND name = 'ssis_sensitive_access')
BEGIN
    RAISERROR(N'Creating database role [ssis_sensitive_access]...', 0, 0) WITH NOWAIT;
    CREATE ROLE [ssis_sensitive_access]
END
ELSE
BEGIN
    RAISERROR(N'Database role [ssis_sensitive_access] exists.', 0, 0) WITH NOWAIT;
END
GO
RAISERROR('[ssis_sensitive_access] database role allows using DECRYPT_SENSITIVE (DS) option to decrypt sensitive information', 0, 0) WITH NOWAIT;
GO
--
RAISERROR(N'Adding [ssis_admin] to [ssis_sensitive_access]', 0, 0) WITH NOWAIT;
ALTER ROLE [ssis_sensitive_access] ADD MEMBER [ssis_admin]
GO

--GRANT EXECUTE permission on the stored procedure to [ssis_admin] role
RAISERROR(N'Granting EXECUTE permission to [ssis_admin]', 0, 0) WITH NOWAIT;
GRANT EXECUTE ON [dbo].[sp_ssisdb] TO [ssis_admin]
GO