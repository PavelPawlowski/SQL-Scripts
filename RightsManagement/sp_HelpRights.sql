  
/* *****************************************************************************************
	                                  AZURE SQL DB Notice
   Comment-out the unsupported USE [master] when running in Azure SQL DB/Synapse Analytics
   or ignore error caused by unsupported USE statement
******************************************************************************************** */
USE [master]
GO

IF NOT EXISTS (SELECT 1 FROM sys.all_objects WHERE object_id = OBJECT_ID('[dbo].[sp_HelpRights]') AND TYPE = 'P')
    EXECUTE ('CREATE PROCEDURE [dbo].[sp_HelpRights] AS BEGIN PRINT ''Container for sp_HelpRights (C) Pavel Pawlowski'' END');
GO
/* *********************************************************************************************************
sp_HelpRights v1.00 (2020-11-04)

Feedback: mailto:pavel.pawlowski@hotmail.cz

MIT License

Copyright (c) 2015-2020 Pavel Pawlowski

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
    Lists database objects Rights assignment overview

Parameters:
     @databases		    nvarchar(max)	= NULL	- Comma separated list of databases to retrieve permissions
											    - Supports LIKE wildcards
											    - names starting with [-] are removed form the list
											    - NULL represents current database
    @principals         nvarchar(max)   = NULL  - Comma separated list of database principal names for which the permissions should be retrieved
                                                - Supports LIKE wildcards
                                                - Names starting with [-]are removed from the list
                                                - NULL represents all grantees
    @permissions        nvarchar(max)   = '%'   - Comma separated list of database permissions to output.
                                                - Supports LIKE wildcards. Permissions starting with [-] are removed from list
                                                - To get list of supported permissions use: SELECT * FROM sys.fn_builtin_permissions(DEFAULT)', 0, 0) WITH NOWAIT;
    @securable_class    nvarchar(max)   = '%'   - Comma separated list of securable classes for which the permissions should be listed
                                                - Supports LIKE wildcards. Permissions starting with [-] are removed from list
                                                - See list below for supported classes
    @output_table      nvarchar(260)   = NULL  - Name of the output temp table name to which the result should be printed
                                                - When provided then output is inserted into provided table name
    @print_result      bit             = NULL  - Specifies whether result should be returned to user
                                                - When NULL (default) then result is returned if not @output_table is provided. When @output_table is provided then result is not returned
                                                - When 1 then result is always returned
                                                - When 0 then result is not returned in case @output_table is provided. When @output_table is not provided, then it has no effect

SAMPLE CALL:
sp_HelpRights						-- Processes rights for current database
sp_HelpRights '%'					-- Processes rights for all databases
sp_HelpRights '%,-m%'				-- Processes rights for all databases except databases starting with m
sp_HelpRights 'DBA, User%, -User1%'	-- Processes rights for database [DBA] and all databases starting with User but not starting with User1
sp_HelpRights '?'					-- Prints this help
*********************************************************************************************************** */
ALTER PROCEDURE [dbo].[sp_HelpRights]
	@databases	        nvarchar(max)	= NULL --Comma separated list of databases to retrieve database permissions. Supports wildcards, NULL means current database
    ,@principals        nvarchar(max)   = NULL --Comma separated list of database principal names for which permissions should be retrieved. Supports wildcards, NULL means any
    ,@permissions       nvarchar(max)   = '%'  --Comma separated list of permissions to output rights assignments.
    ,@securable_class   nvarchar(max)   = '%'  --Comma separated list of securable classes to output rights assignments
    ,@output_table      nvarchar(260)   = NULL --name of the output temp table name to which the result should be printed
    ,@print_result      bit             = NULL --Specifies whether result should be outputted
AS
BEGIN
	SET NOCOUNT ON;
	RAISERROR(N'sp_HelpRights v1.00 (2020-11-04) (C) 2015-2020 Pavel Pawlowski', 0, 0) WITH NOWAIT;
    RAISERROR(N'==============================================================', 0, 0) WITH NOWAIT;


DECLARE
    @printHelp              bit             = 0
    ,@msg                   nvarchar(max)
    ,@xml                   xml                         --variable for storing XML to split database names
    ,@sql                   nvarchar(max)               --variable tor store dynamic SQL
	,@dbName                nvarchar(128)               --variable tor store actual DB name to retrieve rights
    ,@output_table_name     nvarchar(260)

DECLARE @supported_classes TABLE (
    class_name  nvarchar(60) PRIMARY KEY CLUSTERED
)

INSERT INTO @supported_classes (class_name) VALUES
 ('DATABASE')
,('OBJECT_OR_COLUMN')
,('SCHEMA')
,('DATABASE_PRINCIPAL')
,('ASSEMBLY')
,('TYPE')
,('XML_SCHEMA_COLLECTION')
,('MESSAGE_TYPE')
,('SERVICE_CONTRACT')
,('SERVICE')
,('REMOTE_SERVICE_BINDING')
,('ROUTE')
,('FULLTEXT_CATALOG')
,('SYMMETRIC_KEYS')
,('CERTIFICATE')
,('ASYMMETRIC_KEY')


DECLARE @classNames TABLE (
    class_name nvarchar(60) PRIMARY KEY CLUSTERED
)

DECLARE @permissionNames TABLE(
    perm_name nvarchar(60) PRIMARY KEY CLUSTERED
)

/* ********************
       CLASS NAMES
*********************** */
SET @xml = N'<i>' + REPLACE(@securable_class, N',', N'</i><i>') + N'</i>'

INSERT INTO @classNames(class_name)
SELECT DISTINCT
    C.value('.', N'nvarchar(60)')
FROM @xml.nodes(N'/i') T(C)

--verify class names
SET @msg = STUFF((
SELECT
    N', ' +CASE WHEN LEFT(cn.class_name, 1) = '-' THEN RIGHT(cn.class_name, LEN(cn.class_name) - 1)
        ELSE cn.class_name
    END
FROM @classNames cn
WHERE NOT EXISTS(
    SELECT
        sc.class_name
    FROM @supported_classes sc
    WHERE sc.class_name LIKE cn.class_name AND LEFT(cn.class_name, 1) <> '-'
    UNION
    SELECT
        sc.class_name
    FROM @supported_classes sc
    WHERE sc.class_name LIKE RIGHT(cn.class_name, LEN(cn.class_name) - 1) AND LEFT(cn.class_name, 1) = N'-'
)
FOR XML PATH('')), 1, 2, N'')

IF NULLIF(@msg, N'') IS NOT NULL
BEGIN
    SET @printHelp = 1
    RAISERROR(N'Unsupported @securable_class: %s', 11, 1, @msg) WITH NOWAIT;
END

--Securable Classes
IF OBJECT_ID('tempdb..#securableClasses') IS NOT NULL
    DROP TABLE #securableClasses;

CREATE TABLE #securableClasses (
    class_name nvarchar(60) NOT NULL PRIMARY KEY CLUSTERED
);

INSERT INTO #securableClasses(class_name)
SELECT DISTINCT
    sc.class_name
FROM @supported_classes sc
INNER JOIN @classNames cn ON sc.class_name LIKE cn.class_name AND LEFT(cn.class_name, 1) <> N'-'
EXCEPT
SELECT
    sc.class_name
FROM @supported_classes sc
INNER JOIN @classNames cn ON sc.class_name LIKE RIGHT(cn.class_name, LEN(cn.class_name) - 1) AND LEFT(cn.class_name, 1) = N'-'


/* ******************************
       PERMISSION NAMES
********************************* */
SET @xml = N'<i>' + REPLACE(@permissions, N',', N'</i><i>') + N'</i>'

INSERT INTO @permissionNames(perm_name)
SELECT DISTINCT
    C.value('.', N'nvarchar(60)')
FROM @xml.nodes(N'/i') T(C)

--verify permission names
SET @msg = STUFF((
SELECT
    N', ' +CASE WHEN LEFT(pn.perm_name, 1) = '-' THEN RIGHT(pn.perm_name, LEN(pn.perm_name) - 1)
        ELSE pn.perm_name
    END
FROM @permissionNames pn
WHERE NOT EXISTS(
    SELECT
        bp.[permission_name]
    FROM sys.fn_builtin_permissions(DEFAULT) bp
    WHERE bp.[permission_name] LIKE pn.perm_name COLLATE DATABASE_DEFAULT AND LEFT(pn.perm_name, 1) <> '-'
    UNION
    SELECT
        bp.[permission_name]
    FROM sys.fn_builtin_permissions(DEFAULT) bp
    WHERE bp.[permission_name] LIKE RIGHT(pn.perm_name, LEN(pn.perm_name) - 1) COLLATE DATABASE_DEFAULT  AND LEFT(pn.perm_name, 1) = N'-'
)
FOR XML PATH('')), 1, 2, N'')

IF NULLIF(@msg, N'') IS NOT NULL
BEGIN
    SET @printHelp = 1
    RAISERROR(N'Unsupported @permission: %s', 11, 1, @msg) WITH NOWAIT;
END

--Securable Classes
IF OBJECT_ID('tempdb..#permissionNames') IS NOT NULL
    DROP TABLE #permissionNames;

CREATE TABLE #permissionNames (
    perm_name nvarchar(60) NOT NULL PRIMARY KEY CLUSTERED
);

INSERT INTO #permissionNames(perm_name)
SELECT DISTINCT
    bp.[permission_name]
FROM sys.fn_builtin_permissions(DEFAULT) bp
INNER JOIN @permissionNames pn ON bp.[permission_name] LIKE pn.perm_name COLLATE DATABASE_DEFAULT  AND LEFT(pn.perm_name, 1) <> N'-'
EXCEPT
SELECT
    bp.[permission_name]
FROM sys.fn_builtin_permissions(DEFAULT) bp
INNER JOIN @permissionNames pn ON bp.[permission_name] LIKE RIGHT(pn.perm_name, LEN(pn.perm_name) - 1) COLLATE DATABASE_DEFAULT  AND LEFT(pn.perm_name, 1) = N'-'


IF @output_table IS NOT NULL
BEGIN
    SELECT
        @output_table_name = 
            CASE 
                WHEN OBJECT_ID(@output_table) IS NOT NULL THEN QUOTENAME(OBJECT_SCHEMA_NAME(OBJECT_ID(@output_table))) + N'.' +QUOTENAME(OBJECT_NAME(OBJECT_ID(@output_table)))
                WHEN OBJECT_ID(N'tempdb..' + @output_table) IS NOT NULL THEN @output_table
                ELSE NULL
            END
    IF @output_table_name IS NULL
    BEGIN
        RAISERROR(N'@output_table "%s" does not exists', 15, 0, @output_table) WITH NOWAIT;
       -- RETURN;
    END
END



	IF @databases = '?' OR @printHelp = 1
	BEGIN
		RAISERROR(N'Description:
	Lists database objects Rights assignment overview.
    It lists all Rights assignments to individual database principals, even those granted through hierarchy of roles membership
    and not directly visible for particular database principal

Usage:
sp_HelpRights [parameters]

Parameters:
     @databases		    nvarchar(max)   = NULL	- Comma separated list of databases to retrieve permissions
											    - Supports LIKE Wildcards
											    - Names starting with [-] are removed form the list
											    - NULL represents current database
    @principals         nvarchar(max)   = NULL  - Comma separated list of database principal names for which the permissions should be retrieved
                                                - Supports LIKE Wildcards
                                                - Names starting with [-]are removed from the list
                                                - NULL represents all grantees
    @permissions        nvarchar(max)   = ''%%''   - Comma separated list of database permissions to output.
                                                - Supports LIKE wildcards. Permissions starting with [-] are removed from list
                                                - To get list of supported permissions use: SELECT * FROM sys.fn_builtin_permissions(DEFAULT)', 0, 0) WITH NOWAIT;
RAISERROR(N'    @securable_class    nvarchar(max)   = ''%%''   - Comma separated list of securable classes for which the permissions should be listed
                                                - Supports LIKE wildcards. Permissions starting with [-] are removed from list
                                                - See list below for supported classes
    ,@output_table      nvarchar(260)   = NULL  - Name of the output temp table name to which the result should be printed
                                                - When provided then output is inserted into provided table name
    ,@print_result      bit             = NULL  - Specifies whether result should be returned to user
                                                - When NULL (default) then result is returned if not @output_table is provided. When @output_table is provided then result is not returned
                                                - When 1 then result is always returned
                                                - When 0 then result is not returned in case @output_table is provided. When @output_table is not provided, then it has no effect
                                            
                                            ', 0, 0) WITH NOWAIT;

SET @msg = N''
SELECT @msg = @msg + class_name + NCHAR(13) + NCHAR(10)  FROM @supported_classes;
RAISERROR(N'Supported Securable Classes:
----------------------------
%s', 0, 0, @msg) WITH NOWAIT;

RAISERROR(N'
SAMPLE CALLs:
sp_HelpRights                       -- Processes rights for current database
sp_HelpRights ''%%''                   -- Processes rights for all databases
sp_HelpRights ''%%,-m%%''               -- Processes rights for all databases except databases starting with m
sp_HelpRights ''DBA, User%%, -User1%%'' -- Processes rights for database [DBA] and all databases starting with User but not starting with User1
sp_HelpRights @principals=''R%%''      -- Processes rights for current database and displays rights for all database principals starting with R
sp_HelpRights ''?''                   -- Prints this help

', 0, 0) WITH NOWAIT;

RAISERROR(N'

Table Structure for output collection
-------------------------------------
CREATE TABLE #rightsAssignments (
  	 [DatabaseName]                          nvarchar(128)   NULL       --Name of the database
	,[SecurableClass]                        nvarchar(60)    NULL       --Type of the Permission object
	,[DatabaseObjectType]                    nvarchar(60)    NOT NULL   --Type of the Database object with which the permission is associated
	,[DatabaseObjectSchemaName]              sysname         NULL       --Schema name for schema bound database objects
	,[DatabaseObjectName]                    sysname         NULL       --Database object to which the permission is related
    ,[DatabaseObjectFullName]                varchar(124)    NULL       --Full scoped database object name. Including Column Name in case of permission to column
	,[ColumnID]                              int             NOT NULL   --ID of column in case the permission is related to a column
	,[DatabasePrincipalName]                 sysname         NULL       --Name of the database principal to which the permission is associated. The one to which the permission is finally granted or revoked.
	,[DatabasePrincipalTypeName]             nvarchar(60)    NULL       --Name of the database principal Type
	,[PermissionName]                        nvarchar(128)   NULL       --Name of the permission
	,[PermissionStateName]                   nvarchar(60)    NULL       --Name of the permission state GRANT,DENY,..
	,[GranteePrincipalName]                  sysname         NULL       --Database principal to which the permission is originally granted/denied.', 0, 0) WITH NOWAIT;
RAISERROR(N'	,[GranteePrincipalTypeName]              nvarchar(60)    NULL       --Type of the grantee principal
	,[PermissionInheritancePath]             nvarchar(max)   NULL       --The complete inheritance path from the Grantee to the DatabasePrincipal
	,[ServerPrincipalName]                   sysname         NULL       --Name of Server principal corresponding to database principal if available
	,[GrantedByDatabasePrincipalName]        sysname         NULL       --Name of the database principal which granted the permission to the grantee
	,[GrantedByDatabasePrincipalTypeName]    nvarchar(60)    NULL       --Type of the database principal which granted the permission to the grantee
	,[DatabaseID]                            smallint        NULL       --ID of the database
	,[DatabaseObjectSchemaID]                int             NULL       --ID of the schema for the schema bound objects
	,[DatabaseObjectID]                      int             NOT NULL   --ID of the database object with which the permission is associated
	,[DatabasePrincipalID]                   int             NULL       --ID of the database principal to which the permission is associated.The one to which the permission is finally granted', 0, 0) WITH NOWAIT;
RAISERROR(N'	,[DatabasePrincipalType]                 char(1)         NULL       --Type of the database principal
	,[PermissionType]                        char(4)         NOT NULL   --Type of the permission
	,[PermissionState]                       char(1)         NOT NULL   --State of the permission
	,[GranteePrincipalID]                    int             NOT NULL   --ID of the grantee database principal
	,[GranteePrincipalType]                  char(1)         NULL       --Type of the grantee database principal
	,[ServerPrincipalID]                     int             NULL       --ID of the server principal associated with the database principal if available
	,[GrantedByDatabasePrincipalID]          int             NOT NULL   --ID of the database principal by which the permission was granted/denied
	,[GrantedByDatabasePrincipalType]        char(1)         NULL       --Type of the database principal by which the permission was granted/denied
);
', 0, 0) WITH NOWAIT;
		RETURN;
	END;
    ELSE
    BEGIN
        RAISERROR(N'', 0, 0) WITH NOWAIT;
        RAISERROR(N'sp_HelpRights ''?'' for help', 0, 0) WITH NOWAIT;
        RAISERROR(N'', 0, 0) WITH NOWAIT;
    END


    --Create temp table for storing the rights overview
    IF OBJECT_id('tempdb..#rightsHelp') IS NOT NULL
        DROP TABLE #rightsHelp;
    CREATE TABLE #rightsHelp (
  	     [DatabaseName]                          nvarchar(128)   NULL       --Name of the database
	    ,[SecurableClass]                        nvarchar(60)    NULL       --Type of the Permission object
	    ,[DatabaseObjectType]                    nvarchar(60)    NOT NULL   --Type of the Database object with which the permission is associated
	    ,[DatabaseObjectSchemaName]              sysname         NULL       --Schema name for schema bound database objects
	    ,[DatabaseObjectName]                    sysname         NULL       --Database object to which the permission is related
	    ,[ColumnID]                              int             NOT NULL   --ID of column in case the permission is related to a column
        ,[DatabaseObjectFullName]                varchar(124)    NULL       --Full scoped database object name. Including Column Name in case of permission to column
	    ,[DatabasePrincipalName]                 sysname         NULL       --Name of the database principal to which the permission is associated. The one to which the permission is finally granted or revoked.
	    ,[DatabasePrincipalTypeName]             nvarchar(60)    NULL       --Name of the database principal Type
	    ,[PermissionName]                        nvarchar(128)   NULL       --Name of the permission
	    ,[PermissionStateName]                   nvarchar(60)    NULL       --Name of the permission state GRANT,DENY,..
	    ,[GranteePrincipalName]                  sysname         NULL       --Database principal to which the permission is originally granted/denied.
	    ,[GranteePrincipalTypeName]              nvarchar(60)    NULL       --Type of the grantee principal
	    ,[PermissionInheritancePath]             nvarchar(max)   NULL       --The complete inheritance path from the Grantee to the DatabasePrincipal
	    ,[ServerPrincipalName]                   sysname         NULL       --Name of Server principal corresponding to database principal if available
	    ,[GrantedByDatabasePrincipalName]        sysname         NULL       --Name of the database principal which granted the permission to the grantee
	    ,[GrantedByDatabasePrincipalTypeName]    nvarchar(60)    NULL       --Type of the database principal which granted the permission to the grantee
	    ,[DatabaseID]                            smallint        NULL       --ID of the database
	    ,[DatabaseObjectSchemaID]                int             NULL       --ID of the schema for the schema bound objects
	    ,[DatabaseObjectID]                      int             NOT NULL   --ID of the database object with which the permission is associated
	    ,[DatabasePrincipalID]                   int             NULL       --ID of the database principal to which the permission is associated The one to which the permission is finally granted.
	    ,[DatabasePrincipalType]                 char(1)         NULL       --Type of the database principal
	    ,[PermissionType]                        char(4)         NOT NULL   --Type of the permission
	    ,[PermissionState]                       char(1)         NOT NULL   --State of the permission
	    ,[GranteePrincipalID]                    int             NOT NULL   --ID of the grantee database principal
	    ,[GranteePrincipalType]                  char(1)         NULL       --Type of the grantee database principal
	    ,[ServerPrincipalID]                     int             NULL       --ID of the server principal associated with the database principal if available
	    ,[GrantedByDatabasePrincipalID]          int             NOT NULL   --ID of the database principal by which the permission was granted/denied
	    ,[GrantedByDatabasePrincipalType]        char(1)         NULL       --Type of the database principal by which the permission was granted/denied
    )


    --Temp table to hold distinct principal names wildcards
    IF OBJECT_ID('tempdb..#principals') IS NOT NULL
        DROP TABLE #principals;

    CREATE TABLE #principals (PrincipalNameWildcard nvarchar(128) PRIMARY KEY CLUSTERED);

    --Extract principals wildcards (in case of NULL use %)
    SET @xml = '<item>' + ISNULL(REPLACE(@principals, ',', '</item><item>'), '%') + '</item>';
    INSERT INTO #principals(PrincipalNameWildcard)
    SELECT 
	    LTRIM(RTRIM(N.value('.', 'nvarchar(128)'))) AS PrincipalNameWildcard
    FROM @xml.nodes('/item') R(N);



    --Base query for rights extraction
DECLARE @baseQuery nvarchar(max) = N'
WITH FilteredPrincipals AS (
    SELECT DISTINCT
	    dp.principal_id
    FROM sys.database_principals dp
    INNER JOIN #principals pl ON  dp.[name] COLLATE Latin1_General_100_CI_AS LIKE pl.PrincipalNameWildcard COLLATE Latin1_General_100_CI_AS
    WHERE Left(pl.PrincipalNameWildcard, 1) <> ''-''

    EXCEPT --remove principals which names do not start with -

    SELECT DISTINCT
	    dp.principal_id
    FROM sys.database_principals dp
    INNER JOIN #principals pl ON dp.[name] COLLATE Latin1_General_100_CI_AS LIKE RIGHT(pl.PrincipalNameWildcard, LEN(pl.PrincipalNameWildcard) - 1) COLLATE Latin1_General_100_CI_AS
    WHERE Left(pl.PrincipalNameWildcard, 1) = ''-''
),
DPRecursion AS (
	SELECT DISTINCT
		 rm.role_principal_id
		,rm.role_principal_id	AS member_principal_id
		,CONVERT(nvarchar(max), dp.name)  AS inheritance
	FROM sys.database_role_members rm
	INNER JOIN sys.database_principals dp ON dp.principal_id = rm.role_principal_id

	UNION ALL

	SELECT
		 rr.role_principal_id
		,rm.member_principal_id
		,rr.inheritance + '' => '' + dp.name
	FROM sys.database_role_members rm
	INNER JOIN sys.database_principals dp ON dp.principal_id = rm.member_principal_id
	INNER JOIN DPRecursion rr ON rm.role_principal_id = rr.member_principal_id
), DatabasePrincipals AS (
	SELECT
		drp.role_principal_id	AS ParentPrincipalID
		,dp.principal_id		AS DatabasePrincipalID
		,dp.name				AS DatabasePrincipalName
		,dp.type				AS DatabasePrincipalType
		,dp.type_desc			AS DatabasePrincipalTypeName
		,drp.inheritance		AS PermissionInheritancePath
		,dp.sid					AS sid
	FROM DPRecursion drp
	INNER JOIN sys.database_principals dp ON drp.member_principal_id = dp.principal_id
	WHERE drp.role_principal_id <> drp.member_principal_id and dp.type NOT IN (''A'', ''R'')
	UNION
	SELECT
		dp.principal_id		AS ParentPrincipalID
		,dp.principal_id	AS DatabasePrincipalID
		,dp.name			AS DatabasePrincipalName
		,dp.type			AS DatabasePrincipalType
		,dp.type_desc		AS DatabasePrincipalTypeName
		,dp.name			AS PermissionInheritancePath
		,dp.sid				AS sid
	FROM sys.database_principals dp
), RightsAssignment AS (
SELECT
	DB_ID()								AS DatabaseID
	,DB_NAME()							AS DatabaseName
	,dpp.class_desc						AS SecurableClass
    ,CASE dpp.class_desc 
        WHEN N''OBJECT_OR_COLUMN'' THEN o.type_desc
        ELSE dpp.class_desc
    END                                 AS DatabaseObjectType
	,s.name								AS DatabaseObjectSchemaName
    ,CASE dpp.class_desc 
        WHEN N''OBJECT_OR_COLUMN''        THEN o.name COLLATE DATABASE_DEFAULT
        WHEN N''DATABASE''                THEN DB_NAME() COLLATE DATABASE_DEFAULT
        WHEN N''SCHEMA''                  THEN SCHEMA_NAME(dpp.major_id) COLLATE DATABASE_DEFAULT
        WHEN N''DATABASE_PRINCIPAL''      THEN dpn.[name] COLLATE DATABASE_DEFAULT
        WHEN N''ASSEMBLY''                THEN asn.name COLLATE DATABASE_DEFAULT
        WHEN N''TYPE''                    THEN tpn.name COLLATE DATABASE_DEFAULT
        WHEN N''XML_SCHEMA_COLLECTION''   THEN xsn.name COLLATE DATABASE_DEFAULT
        WHEN N''MESSAGE_TYPE''            THEN smn.name COLLATE DATABASE_DEFAULT
        WHEN N''SERVICE_CONTRACT''        THEN scn.name COLLATE DATABASE_DEFAULT
        WHEN N''SERVICE''                 THEN ssn.name COLLATE DATABASE_DEFAULT
        WHEN N''REMOTE_SERVICE_BINDING''  THEN sbn.name COLLATE DATABASE_DEFAULT
        WHEN N''ROUTE''                   THEN rn.name  COLLATE DATABASE_DEFAULT
        WHEN N''FULLTEXT_CATALOG''        THEN fcn.name COLLATE DATABASE_DEFAULT
        WHEN N''SYMMETRIC_KEYS''          THEN skn.name COLLATE DATABASE_DEFAULT
        WHEN N''CERTIFICATE''             THEN ctn.name COLLATE DATABASE_DEFAULT
        WHEN N''ASYMMETRIC_KEY''          THEN akn.name COLLATE DATABASE_DEFAULT
        ELSE NULL
    END                                 AS DatabaseObjectName
    ,tcn.name                           AS ColumnName
	,s.schema_id						AS DatabaseObjectSchemaID
	,dpp.major_id						AS DatabaseObjectID
	,dpp.minor_id						AS ColumnID
	,dpp.grantee_principal_id			AS GranteePrincipalID
	,gdp.name							AS GranteePrincipalName
	,gdp.type							AS GranteePrincipalType
	,gdp.type_desc						AS GranteePrincipalTypeName
	,dp.DatabasePrincipalID
	,dp.DatabasePrincipalName
	,dp.DatabasePrincipalType
	,dp.DatabasePrincipalTypeName
	,dp.PermissionInheritancePath
	,sp.principal_id					AS ServerPrincipalID
	,sp.name							AS ServerPrincipalName
	,dpp.type							AS PermissionType
	,dpp.permission_name				AS PermissionName
	,dpp.state							AS PermissionState
	,dpp.state_desc						AS PermissionStateName
	,dpp.grantor_principal_id			AS GrantedByDatabasePrincipalID
	,gbp.name							AS GrantedByDatabasePrincipalName
	,gbp.type							AS GrantedByDatabasePrincipalType
	,gbp.type_desc						AS GrantedByDatabasePrincipalTypeName
FROM sys.database_permissions dpp
INNER JOIN #securableClasses sc ON dpp.class_desc = sc.class_name COLLATE DATABASE_DEFAULT
INNER JOIN #permissionNames pn ON dpp.permission_name = pn.perm_name COLLATE DATABASE_DEFAULT
LEFT JOIN sys.all_objects o ON o.object_id = dpp.major_id
LEFT JOIN sys.schemas s ON s.schema_id = o.schema_id
LEFT JOIN sys.database_principals gdp ON gdp.principal_id = dpp.grantee_principal_id
LEFT JOIN DatabasePrincipals dp ON dp.ParentPrincipalID = gdp.principal_id
LEFT JOIN sys.server_principals sp ON dp.sid = sp.sid
LEFT JOIN sys.database_principals gbp ON gbp.principal_id = dpp.grantor_principal_id

LEFT JOIN sys.database_principals dpn ON dpn.principal_id = dpp.major_id AND dpp.class_desc = N''DATABASE_PRINCIPAL''
LEFT JOIN sys.assemblies asn ON asn.assembly_id = dpp.major_id AND dpp.class_desc = N''ASSEMBLY''
LEFT JOIN sys.types tpn ON tpn.user_type_id = dpp.major_id AND dpp.class_desc = N''TYPE''
LEFT JOIN sys.xml_schema_collections xsn ON xsn.xml_collection_id = dpp.major_id AND dpp.class_desc = N''XML_SCHEMA_COLLECTION''
LEFT JOIN sys.service_message_types smn ON smn.message_type_id = dpp.major_id AND dpp.class_desc = N''MESSAGE_TYPE''
LEFT JOIN sys.service_contracts scn ON scn.service_contract_id = dpp.major_id AND dpp.class_desc = N''SERVICE_CONTRACT''
LEFT JOIN sys.services ssn ON ssn.service_id = dpp.major_id and dpp.class_desc = N''SERVICE''
LEFT JOIN sys.remote_service_bindings sbn ON sbn.remote_service_binding_id = dpp.major_id AND dpp.class_desc = N''REMOTE_SERVICE_BINDING''
LEFT JOIN sys.routes rn ON rn.route_id = dpp.major_id AND dpp.class_desc = N''ROUTE''
LEFT JOIN sys.fulltext_catalogs fcn ON fcn.fulltext_catalog_id = dpp.major_id AND dpp.class_desc = N''FULLTEXT_CATALOG''
LEFT JOIN sys.symmetric_keys skn ON skn.symmetric_key_id = dpp.major_id AND dpp.class_desc = N''SYMMETRIC_KEYS''
LEFT JOIN sys.certificates ctn ON ctn.certificate_id = dpp.major_id AND dpp.class_desc = N''CERTIFICATE''
LEFT JOIN sys.asymmetric_keys akn ON akn.asymmetric_key_id = dpp.major_id AND dpp.class_desc = N''ASYMMETRIC_KEY''
LEFT JOIN sys.all_columns tcn ON tcn.object_id = dpp.major_id and tcn.column_id = dpp.minor_id AND dpp.class_desc = N''OBJECT_OR_COLUMN''

WHERE dp.DatabasePrincipalID IN (SELECT principal_id FROM FilteredPrincipals)
)
INSERT INTO #rightsHelp (
    [DatabaseID]                        
    ,[DatabaseName]                      
    ,[SecurableClass]               
    ,[DatabaseObjectType]                
    ,[DatabaseObjectSchemaName]          
    ,[DatabaseObjectName]                 
    ,[DatabaseObjectFullName]
    ,[DatabaseObjectSchemaID]            
    ,[DatabaseObjectID]                 
    ,[ColumnID]                          
    ,[GranteePrincipalID]                
    ,[GranteePrincipalName]              
    ,[GranteePrincipalType]              
    ,[GranteePrincipalTypeName]          
    ,[DatabasePrincipalID]               
    ,[DatabasePrincipalName]             
    ,[DatabasePrincipalType]             
    ,[DatabasePrincipalTypeName]         
    ,[PermissionInheritancePath]         
    ,[ServerPrincipalID]                 
    ,[ServerPrincipalName]               
    ,[PermissionType]                    
    ,[PermissionName]                    
    ,[PermissionState]                   
    ,[PermissionStateName]               
    ,[GrantedByDatabasePrincipalID]      
    ,[GrantedByDatabasePrincipalName]    
    ,[GrantedByDatabasePrincipalType]    
    ,[GrantedByDatabasePrincipalTypeName]
)
SELECT
    [DatabaseID]                        
    ,[DatabaseName]                      
    ,[SecurableClass]               
    ,[DatabaseObjectType]                
    ,[DatabaseObjectSchemaName]          
    ,[DatabaseObjectName]                 
    ,CASE [SecurableClass]
        WHEN N''OBJECT_OR_COLUMN'' THEN QUOTENAME([DatabaseObjectSchemaName]) + N''.'' + QUOTENAME([DatabaseObjectName]) + ISNULL(QUOTENAME(N''('' + ColumnName + N'')'' ), N'''')
        ELSE QUOTENAME([DatabaseObjectName])
     END AS [DatabaseObjectFullName]
    ,[DatabaseObjectSchemaID]            
    ,[DatabaseObjectID]                 
    ,[ColumnID]                          
    ,[GranteePrincipalID]                
    ,[GranteePrincipalName]              
    ,[GranteePrincipalType]              
    ,[GranteePrincipalTypeName]          
    ,[DatabasePrincipalID]               
    ,[DatabasePrincipalName]             
    ,[DatabasePrincipalType]             
    ,[DatabasePrincipalTypeName]         
    ,[PermissionInheritancePath]         
    ,[ServerPrincipalID]                 
    ,[ServerPrincipalName]               
    ,[PermissionType]                    
    ,[PermissionName]                    
    ,[PermissionState]                   
    ,[PermissionStateName]               
    ,[GrantedByDatabasePrincipalID]      
    ,[GrantedByDatabasePrincipalName]    
    ,[GrantedByDatabasePrincipalType]    
    ,[GrantedByDatabasePrincipalTypeName]
FROM RightsAssignment
WHERE
    [DatabaseObjectType] IS NOT NULL;  --In Azure SQL Database there are some grants for [public] to object IDs which are representing PDW views but objects do not exists
';


	--Retrieve Database Lists to process - for NULL entry uses current DB
	SET @xml = '<item>' + ISNULL(REPLACE(@databases, ',', '</item><item>'), DB_NAME()) + '</item>';
	DECLARE dbc CURSOR FAST_FORWARD FOR
	WITH DBNames AS (
		SELECT
			LTRIM(RTRIM(N.value('.', 'nvarchar(128)'))) AS DBName
		FROM @xml.nodes('/item') R(N)
	)
	SELECT DISTINCT
		QUOTENAME(d.name) AS DBName
	FROM sys.databases d
	INNER JOIN DBNames dn ON  d.name LIKE dn.DBName
	WHERE Left(dn.DBName, 1) <> '-'

	EXCEPT --remove databases which match pattern starting with -

	SELECT DISTINCT
		QUOTENAME(d.name) AS DBName
	FROM sys.databases d
	INNER JOIN DBNames dn ON  d.name LIKE RIGHT(dn.DBName, LEN(dn.DBName) - 1)
	WHERE Left(dn.DBName, 1) = '-'

	OPEN dbc;

	FETCH NEXT FROM dbc INTO @dbName;

	--process Rights for each selected database
	WHILE @@FETCH_STATUS = 0
	BEGIN
		RAISERROR('Fetching Rights for Database %s...', 0, 0, @dbName) WITH NOWAIT;

		--Construct query for actual database and execute it
		SET @sql = 'USE ' + @dbName + ';' + @baseQuery
		EXEC sp_executesql @sql

		FETCH NEXT FROM dbc INTO @dbName;
	END


	CLOSE dbc;
	DEALLOCATE dbc;


    IF NULLIF(@output_table, N'') IS NOT NULL
    BEGIN
        RAISERROR(N'Writing results to %s', 0, 0, @output_table_name) WITH NOWAIT;

        SET @sql = N'INSERT INTO ' + @output_table_name + N'(
         [DatabaseName]                      
        ,[SecurableClass]               
        ,[DatabaseObjectType]                
        ,[DatabaseObjectSchemaName]          
        ,[DatabaseObjectName]                 
        ,[ColumnID]              
        ,[DatabaseObjectFullName]
        ,[DatabasePrincipalName]             
        ,[DatabasePrincipalTypeName]         
        ,[PermissionName]                    
        ,[PermissionStateName]               
        ,[GranteePrincipalName]              
        ,[GranteePrincipalTypeName]          
        ,[PermissionInheritancePath]         
        ,[ServerPrincipalName]               
        ,[GrantedByDatabasePrincipalName]    
        ,[GrantedByDatabasePrincipalTypeName]
        ,[DatabaseID]                        
        ,[DatabaseObjectSchemaID]            
        ,[DatabaseObjectID]                 
        ,[DatabasePrincipalID]               
        ,[DatabasePrincipalType]             
        ,[PermissionType]                    
        ,[PermissionState]                   
        ,[GranteePrincipalID]                
        ,[GranteePrincipalType]              
        ,[ServerPrincipalID]                 
        ,[GrantedByDatabasePrincipalID]      
        ,[GrantedByDatabasePrincipalType]    
    )
    SELECT
         [DatabaseName]                      
        ,[SecurableClass]               
        ,[DatabaseObjectType]                
        ,[DatabaseObjectSchemaName]          
        ,[DatabaseObjectName]                 
        ,[ColumnID]              
        ,[DatabaseObjectFullName]
        ,[DatabasePrincipalName]             
        ,[DatabasePrincipalTypeName]         
        ,[PermissionName]                    
        ,[PermissionStateName]               
        ,[GranteePrincipalName]              
        ,[GranteePrincipalTypeName]          
        ,[PermissionInheritancePath]         
        ,[ServerPrincipalName]               
        ,[GrantedByDatabasePrincipalName]    
        ,[GrantedByDatabasePrincipalTypeName]
        ,[DatabaseID]                        
        ,[DatabaseObjectSchemaID]            
        ,[DatabaseObjectID]                 
        ,[DatabasePrincipalID]               
        ,[DatabasePrincipalType]             
        ,[PermissionType]                    
        ,[PermissionState]                   
        ,[GranteePrincipalID]                
        ,[GranteePrincipalType]              
        ,[ServerPrincipalID]                 
        ,[GrantedByDatabasePrincipalID]      
        ,[GrantedByDatabasePrincipalType]    
    FROM #rightsHelp;'

        EXEC sp_executesql @sql;
    END

    IF NULLIF(@output_table, N'') IS NULL OR @print_result <> 0
    BEGIN
        SELECT
             [DatabaseName]                      
            ,[SecurableClass]               
            ,[DatabaseObjectType]                
            ,[DatabaseObjectSchemaName]          
            ,[DatabaseObjectName]                 
            ,[ColumnID]              
            ,[DatabaseObjectFullName]
            ,[DatabasePrincipalName]             
            ,[DatabasePrincipalTypeName]         
            ,[PermissionName]                    
            ,[PermissionStateName]               
            ,[GranteePrincipalName]              
            ,[GranteePrincipalTypeName]          
            ,[PermissionInheritancePath]         
            ,[ServerPrincipalName]               
            ,[GrantedByDatabasePrincipalName]    
            ,[GrantedByDatabasePrincipalTypeName]
            ,[DatabaseID]                        
            ,[DatabaseObjectSchemaID]            
            ,[DatabaseObjectID]                 
            ,[DatabasePrincipalID]               
            ,[DatabasePrincipalType]             
            ,[PermissionType]                    
            ,[PermissionState]                   
            ,[GranteePrincipalID]                
            ,[GranteePrincipalType]              
            ,[ServerPrincipalID]                 
            ,[GrantedByDatabasePrincipalID]      
            ,[GrantedByDatabasePrincipalType]    
        FROM #rightsHelp;
    END

    DROP TABLE #rightsHelp;
    DROP TABLE #principals;
    DROP TABLE #securableClasses
    DROP TABLE #permissionNames
END
GO

--Mark Stored Procedure as system object, so it executes in the context of current database.
IF SERVERPROPERTY('EngineEdition') IN (1, 2, 3, 4, 8)
    EXEC(N'EXECUTE sp_ms_marksystemobject ''dbo.sp_HelpRights''');
GO
