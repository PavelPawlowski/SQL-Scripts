USE master
GO
IF NOT EXISTS (SELECT 1 FROM sys.all_objects WHERE object_id = OBJECT_ID('[dbo].[sp_HelpRights]') AND TYPE = 'P')
    EXECUTE ('CREATE PROCEDURE [dbo].[sp_HelpRights] AS BEGIN PRINT ''Container for sp_HelpRights (C) Pavel Pawlowski'' END');
GO
/* *********************************************************************************************************
sp_HelpRights v0.5 (2016-03-31)
(C) 2015 - 2016 Pavel Pawlowski

Feedback: mailto:pavel.pawlowski@hotmail.cz

License: 
    sp_HelpRights is free to download and use for personal, educational, and internal 
    corporate purposes, provided that this header is preserved. Redistribution or sale 
    of sp_HelpRights, in whole or in part, is prohibited without the author's express 
    written consent.

Description:
    Lists database objects Rights assignment overview

Parameters:
     @databases		nvarchar(max)	= NULL	--Comma separated list of databases to retrieve permissions
											--Supports LIKE Wildcards
											--names starting with [-] are removed form the list
											--NULL represetns current database
    @principals     nvarchar(max)   = NULL  --Comma separated list of database principal names for which the permissions should be retrieved
                                            --Supports LIKE Wildcards
                                            --Names starting with [-]are removed from the list
                                            --NULL represetnts all grantees

SAMPLE CALL:
sp_HelpRights						-- Processes rights for current database
sp_HelpRights '%'					-- Processes rights for all databases
sp_HelpRights '%,-m%'				-- Processes rights for all databases except databases starting with m
sp_HelpRights 'DBA, User%, -User1%'	-- Processes rights for database [DBA] and all databases starting with User but not starting with User1
sp_HelpRights '?'					-- Prints this help
*********************************************************************************************************** */
ALTER PROCEDURE [dbo].[sp_HelpRights]
	@databases	    nvarchar(max)	= NULL --Comma separated list of databases to retrieve database permissions. Supports Wildcards, NULL means curent database
    ,@principals    nvarchar(max)   = NULL --Comma separated list of database principal names for which permissions should be retrieved. Supports wildcards, NULL means any
AS
BEGIN
	SET NOCOUNT ON;
	RAISERROR(N'sp_HelpRights v0.6 (2016-10-11) (C) 2015-2016 Pavel Pawlowski', 0, 0) WITH NOWAIT;
    RAISERROR(N'=============================================================', 0, 0) WITH NOWAIT;

	IF @databases = '?'
	BEGIN
		RAISERROR(N'Description:
	Lists database objects Rights assignment overview.
    It lists all Rights asignments to individual database principals, even those granted through hierarchy of roles membership
    and not directly visible for particular database principal

Usage:
sp_HelpRights [parameters]

Parameters:
     @databases		nvarchar(max)	= NULL	--Comma separated list of databases to retrieve permissions
											--Supports LIKE Wildcards
											--Names starting with [-] are removed form the list
											--NULL represents current database
    @principals     nvarchar(max)   = NULL  --Comma separated list of database principal names for which the permissions should be retrieved
                                            --Supports LIKE Wildcards
                                            --Names starting with [-]are removed from the list
                                            --NULL represetnts all grantees

SAMPLE CALLs:
sp_HelpRights                       -- Processes rights for current database
sp_HelpRights ''%%''                   -- Processes rights for all databases
sp_HelpRights ''%%,-m%%''               -- Processes rights for all databases except databases starting with m
sp_HelpRights ''DBA, User%%, -User1%%'' -- Processes rights for database [DBA] and all databases starting with User but not starting with User1
sp_HelpRights @principals=''R%%''      -- Processes rights for current database and displaysrights for all database principals starting with R
sp_HelpRights ''?''                   -- Prints this help

', 0, 0) WITH NOWAIT;

RAISERROR(N'--Table Strcuture for output collection
CREATE TABLE #rightsHelp (
  	 [DatabaseName]                          nvarchar(128)   NULL       --Name of the database
	,[PermissionOjectType]                   nvarchar(60)    NULL       --Type of the Permission object
	,[DatabaseObjectType]                    nvarchar(60)    NOT NULL   --Type of the Database object with which the permission is associated
	,[DatabaseObjectSchemaName]              sysname         NULL       --Schema name for schema bound database objectsd
	,[DatbaseObjectName]                     sysname         NULL       --Datbase object to which the permission is related
	,[ColumnID]                              int             NOT NULL   --ID of column in case the permission is related to a column
	,[DatabasePrincipalName]                 sysname         NULL       --Name of the database principal to which the permission is associated. The one to which the permission is finally granted or revoked.
	,[DatabasePrincipalTypeName]             nvarchar(60)    NULL       --Name of the database principal Type
	,[PermissionName]                        nvarchar(128)   NULL       --Name of the permission
	,[PermissionStateName]                   nvarchar(60)    NULL       --Name of the permission state GRANT,DENY,..
	,[GranteePrincipalName]                  sysname         NULL       --Database principal to which the permission is originally granted/denied.', 0, 0) WITH NOWAIT;
RAISERROR(N'	,[GranteePrincipalTypeName]              nvarchar(60)    NULL       --Type of the grantee principal
	,[PermissionInheritancePath]             nvarchar(max)   NULL       --Thecomplete inheritance path from the Grantee to the DatabasePrincipal
	,[ServerPrincipalName]                   sysname         NULL       --Name of Server principal corresponding to database principal if available
	,[GrantedByDatabasePrincipalName]        sysname         NULL       --Name of the database principal which granted the permission to the grantee
	,[GrantedByDatabasePrincipalTypeName]    nvarchar(60)    NULL       --Type of the datbase principal which granted the permission to the grantee
	,[DatabaseID]                            smallint        NULL       --ID of the database
	,[DatabaseObjectSchemaID]                int             NULL       --ID of the schema for the schema boudn objects
	,[DatabaseObjeectID]                     int             NOT NULL   --ID of the dtabase object with which the permission is associated
	,[DatabasePrincipalID]                   int             NULL       --ID of the database principal to which the permission is associated.Theone to which the permission is finally granted orrevoked.', 0, 0) WITH NOWAIT;
RAISERROR(N'	,[DatabasePrincipalType]                 char(1)         NULL       --Type of the database principla
	,[PermissionType]                        char(4)         NOT NULL   --Type of the permission
	,[PermissionState]                       char(1)         NOT NULL   --State of the permission
	,[GranteePrincipalID]                    int             NOT NULL   --ID of the grantee database principal
	,[GranteePrincipalType]                  char(1)         NULL       --Type of the grantee database principal
	,[ServerPrincipalID]                     int             NULL       --ID of the server principal associated with the database principal if available
	,[GrantedByDatabasePrincipalID]          int             NOT NULL   --ID of the database principal by which the permission was granted/denied
	,[GrantedByDatabasePrincipalType]        char(1)         NULL       --Type of the database principal by which the permission was granted/denied
)
', 0, 0) WITH NOWAIT;
		RETURN;
	END;

	DECLARE @xml xml;						--variable for storing XML to split database names
	DECLARE @sql nvarchar(max);				--variable tor store dynamic SQL
	DECLARE @dbName nvarchar(128);			--variable tor store actual DB name to retrive rights


    --Create temp table for storing the rights overview
    CREATE TABLE #rightsHelp (
  	     [DatabaseName]                          nvarchar(128)   NULL       --Name of the database
	    ,[PermissionOjectType]                   nvarchar(60)    NULL       --Type of the Permission object
	    ,[DatabaseObjectType]                    nvarchar(60)    NOT NULL   --Type of the Database object with which the permission is associated
	    ,[DatabaseObjectSchemaName]              sysname         NULL       --Schema name for schema bound database objectsd
	    ,[DatbaseObjectName]                     sysname         NULL       --Datbase object to which the permission is related
	    ,[ColumnID]                              int             NOT NULL   --ID of column in case the permission is related to a column
	    ,[DatabasePrincipalName]                 sysname         NULL       --Name of the database principal to which the permission is associated. The one to which the permission is finally granted or revoked.
	    ,[DatabasePrincipalTypeName]             nvarchar(60)    NULL       --Name of the database principal Type
	    ,[PermissionName]                        nvarchar(128)   NULL       --Name of the permission
	    ,[PermissionStateName]                   nvarchar(60)    NULL       --Name of the permission state GRANT,DENY,..
	    ,[GranteePrincipalName]                  sysname         NULL       --Database principal to which the permission is originally granted/denied.
	    ,[GranteePrincipalTypeName]              nvarchar(60)    NULL       --Type of the grantee principal
	    ,[PermissionInheritancePath]             nvarchar(max)   NULL       --Thecomplete inheritance path from the Grantee to the DatabasePrincipal
	    ,[ServerPrincipalName]                   sysname         NULL       --Name of Server principal corresponding to database principal if available
	    ,[GrantedByDatabasePrincipalName]        sysname         NULL       --Name of the database principal which granted the permission to the grantee
	    ,[GrantedByDatabasePrincipalTypeName]    nvarchar(60)    NULL       --Type of the datbase principal which granted the permission to the grantee
	    ,[DatabaseID]                            smallint        NULL       --ID of the database
	    ,[DatabaseObjectSchemaID]                int             NULL       --ID of the schema for the schema boudn objects
	    ,[DatabaseObjeectID]                     int             NOT NULL   --ID of the dtabase object with which the permission is associated
	    ,[DatabasePrincipalID]                   int             NULL       --ID of the database principal to which the permission is associated.Theone to which the permission is finally granted orrevoked.
	    ,[DatabasePrincipalType]                 char(1)         NULL       --Type of the database principla
	    ,[PermissionType]                        char(4)         NOT NULL   --Type of the permission
	    ,[PermissionState]                       char(1)         NOT NULL   --State of the permission
	    ,[GranteePrincipalID]                    int             NOT NULL   --ID of the grantee database principal
	    ,[GranteePrincipalType]                  char(1)         NULL       --Type of the grantee database principal
	    ,[ServerPrincipalID]                     int             NULL       --ID of the server principal associated with the database principal if available
	    ,[GrantedByDatabasePrincipalID]          int             NOT NULL   --ID of the database principal by which the permission was granted/denied
	    ,[GrantedByDatabasePrincipalType]        char(1)         NULL       --Type of the database principal by which the permission was granted/denied
    )

    --Temp table to hold disticnt principal names wildcards
    CREATE TABLE #principals (PrincipalNameWildcard nvarchar(128) PRIMARY KEY CLUSTERED);

    --Extract principals wildcards (in case of NULL use %)
    SET @xml = '<item>' + ISNULL(REPLACE(@principals, ',', '</item><item>'), '%') + '</item>';
    INSERT INTO #principals(PrincipalNameWildcard)
    SELECT 
	    LTRIM(RTRIM(N.value('.', 'nvarchar(128)'))) AS PrincipalNameWildcard
    FROM @xml.nodes('/item') R(N)



    --Base query for rigths extraction
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
)
INSERT INTO #rightsHelp (
    [DatabaseID]                        
    ,[DatabaseName]                      
    ,[PermissionOjectType]               
    ,[DatabaseObjectType]                
    ,[DatabaseObjectSchemaName]          
    ,[DatbaseObjectName]                 
    ,[DatabaseObjectSchemaID]            
    ,[DatabaseObjeectID]                 
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
	DB_ID()								AS DatabaseID
	,DB_NAME()							AS DatabaseName
	,dpp.class_desc						AS PermissionOjectType
	,ISNULL(o.type_desc, ''DATABASE'')	AS DatabaseObjectType
	,s.name								AS DatabaseObjectSchemaName
	,o.name								AS DatbaseObjectName
	,s.schema_id						AS DatabaseObjectSchemaID
	,dpp.major_id						AS DatabaseObjeectID
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
LEFT JOIN sys.all_objects o ON o.object_id = dpp.major_id
LEFT JOIN sys.schemas s ON s.schema_id = o.schema_id
LEFT JOIN sys.database_principals gdp ON gdp.principal_id = dpp.grantee_principal_id
LEFT JOIN DatabasePrincipals dp ON dp.ParentPrincipalID = gdp.principal_id
LEFT JOIN sys.server_principals sp ON dp.sid = sp.sid
LEFT JOIN sys.database_principals gbp ON gbp.principal_id = dpp.grantor_principal_id
WHERE dp.DatabasePrincipalID IN (SELECT principal_id FROM FilteredPrincipals)
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

	EXCEPT --remove datbases which match pattern starting with -

	SELECT DISTINCT
		QUOTENAME(d.name) AS DBName
	FROM sys.databases d
	INNER JOIN DBNames dn ON  d.name LIKE RIGHT(dn.DBName, LEN(dn.DBName) - 1)
	WHERE Left(dn.DBName, 1) = '-'

	OPEN dbc;

	FETCH NEXT FROM dbc INTO @dbName;

	--processRights for each selected database
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


    SELECT
         [DatabaseName]                      
        ,[PermissionOjectType]               
        ,[DatabaseObjectType]                
        ,[DatabaseObjectSchemaName]          
        ,[DatbaseObjectName]                 
        ,[ColumnID]                          
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
        ,[DatabaseObjeectID]                 
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

    DROP TABLE #rightsHelp;
    DROP TABLE #principals;
END
GO
EXECUTE sp_ms_marksystemobject N'dbo.sp_HelpRights'
GO
