/* *****************************************************************************************
	                                  AZURE SQL DB Notice

   Comment-out the unsupported USE [master] when running in Azure SQL DB/Synapse Analytics
   or ignore error caused by unsupported USE statement
******************************************************************************************** */
USE [master]
GO

IF NOT EXISTS (SELECT 1 FROM sys.all_objects WHERE object_id = OBJECT_ID('[dbo].[sp_CloneRights]') AND TYPE = 'P')
    EXECUTE ('CREATE PROCEDURE [dbo].[sp_CloneRights] AS BEGIN PRINT ''Container for sp_CloneRights (C) Pavel Pawlowski'' END');
GO
/* ****************************************************
sp_CloneRights v0.50 (2021-05-18)

Feedback: mailto:pavel.pawlowski@hotmail.cz

MIT License

Copyright (c) 2010-2021 Pavel Pawlowski

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
    Clones rights and/or group membership for specified user(s)

Parameters:
     @principal     nvarchar(max)   = NULL  - Comma separated list of database principals to script the rights
                                              Supports wildcards when eg ''%%'' means all users
                                              [-] prefix means except
    ,@newPrincipal  sysname         = NULL  - New database principal to which copy rights
                                              When NULL, permissions are scripted for the original principal.
    ,@database      nvarchar(max)   = NULL  - Comma separated list of databases to be iterated and permissions scripted. 
                                              Supports Like wildcards. NULL means current database
                                              [-] prefix means except
                                              On Azure must be NULL
    ,@scriptClass   nvarchar(max)   = NULL  - Comma separated list of permission classes to script. 
                                              Supports Like wildcards.
                                              NULL = ALL (NULL does not include MS_SHIPPED, SYSTEM_TABLE and EXTENDED_STORED_PROCEDURE).
                                              %% = All classes (including MS_SHIPPED, SYSTEM_TABLE and EXTENDED_STORED_PROCEDURE)
                                              [-] prefix means except. Usable together with [%%] to include all and remove unwated
    ,@printOnly     bit             = 1     - When 1 then only script is printed on screen, when 0 then also script is executed, when NULL, script is only executed and not printed
                                              When @newPrincipal is not provided then it is always 1
    ,@noInfoMsg      bit            = 0     --When 1 then no info messages are output into the final script. Only the commands granting permissions    


* ***************************************************** */ 
ALTER PROCEDURE [dbo].[sp_CloneRights] 
     @principal     nvarchar(max)   = NULL  --Comma separated list of database principals to script he rights. Supports LIKE wildcards
    ,@newPrincipal  sysname         = NULL  --New principal to which copy rights
    ,@database      nvarchar(max)   = NULL  --Comma separated list of databases to be iterated and permissions scripted. Supports Like wildcards NULL Means current database
    ,@scriptClass   nvarchar(max)   = NULL  --Comma separated list of permission classes to script. NULL = ALL
    ,@printOnly     bit             = 1     --When 1 then only script is printed on screen, when 0 then also script is executed, when NULL, script is only executed and not printed
    ,@noInfoMsg     bit             = 0     --When 1 then no info messages are output into the final script. Only the commands granting permissions    
AS
BEGIN

SET NOCOUNT ON;

DECLARE
    @printHelp          bit             = 0     --identifies whether help should be printed
    ,@msg               nvarchar(max)           --for messages printing
    ,@command           nvarchar(4000)          --command for permissions being processed
    ,@sql               nvarchar(max)           --for storing actual sql stagement executed
    ,@userSql           nvarchar(max)           --for storing query to fetch users list
    ,@dbName            nvarchar(128)           --db name in cursor loop
    ,@xml               xml                     --for XML storing purposes
    ,@principalName     sysname                 --principal name in cursor loop
    ,@newPrincipalName  sysname                 --new principal name in cursor loop
    ,@usersCnt          int                     --count of matching users
    ,@wrongClasses      nvarchar(max)           --list of wrong class names
    ,@ms_shipped        bit             = 0     --identifies whether permissions for MS_Shipped objects should be scripted
    ,@caption           nvarchar(max)           --caption of the function
    ,@group             int                     --current permissions group processed by cursor when generating final script
    ,@lastdb            sysname         = N''   --Last DB processed by cursor when generating final script
    ,@lastUser          sysname         = N''   --Last user processed by cursor when generating final script
    ,@lastGroup         int             = 0     --Last permissions group processed by cursor when generating final script

CREATE TABLE #userList (
    UserName sysname PRIMARY KEY CLUSTERED
)

CREATE TABLE #users (
    UserName sysname PRIMARY KEY CLUSTERED
)

DECLARE @databases TABLE (
    DBName sysname
)

--Table to hold permission classes to script
DECLARE @inputClasses TABLE (
    ClassName sysname
)

DECLARE @classes TABLE (
    ClassName sysname
)

DECLARE @allowedClasses TABLE (
     RowId              int NOT NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED
    ,ClassName          sysname
    ,ClassDescription   nvarchar(max)
)


--table for storing output
CREATE TABLE #output (
     [database] nvarchar(128)
    ,[user]     nvarchar(128)
    ,[new_user] nvarchar(128)
    ,[group]    int
    ,[message]  nvarchar(max)
    ,[command]  nvarchar(max)
);

DECLARE @finalOutput TABLE (
    RowID       int NOT NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED
    ,[command]  nvarchar(max)
)

--Set and print the procedure output caption
SET @caption = N'sp_CloneRights v0.50 (2021-05-18) (C) 2010-2021 Pavel Pawlowski'
RAISERROR(@caption, 0, 0) WITH NOWAIT;
RAISERROR(N'===============================================================', 0, 0) WITH NOWAIT;
RAISERROR(N'Repository: https://github.com/PavelPawlowski/SQL-Scripts', 0, 0) WITH NOWAIT;
RAISERROR(N'Feedback: mailto:pavel.pawlowski@hotmail.cz', 0, 0) WITH NOWAIT;

INSERT INTO @allowedClasses(ClassName, ClassDescription)
VALUES
         (N'MS_SHIPPED'                     , 'Scripts permissions on MS_Shipped objects. Must be explicitly specified')
        ,(N''                               , '')
        ,(N'ROLES_MEMBERSHIP'               , 'Scripts roles membership')
        ,(N'DATABASE'                       , 'Scripts permissions on Database')
        ,(N'SCHEMA'                         , 'Scripts permissions on all schemas')
        ,(N''                               , '')
        ,(N'OBJECT'                         , 'Scripts permissions on all schema scoped objects')
        ,(N'TABLE'                          , 'Scripts permissions on user tables and/or table columns')
        ,(N'SYSTEM_TABLE'                   , 'Scripts permissions on system tables and/or table columns. SYSTEM_TABLE must be explicitly specified')
        ,(N'VIEW'                           , 'Scripts permissions on all views and/or view columns')
        ,(N'STORED_PROCEDURE'               , 'Scripts permissions on stored procedures')
        ,(N'SQL_STORED_PROCEDURE'           , 'Scripts permissions on SQL stored procedures')
        ,(N'CLR_STORED_PROCEDURE'           , 'Scripts permissions on CLR stored procedures')
        ,(N'EXTENDED_STORED_PROCEDURE'      , 'Scripts permissions on Extended stored procedures. EXTENDED_STORED_PROCEDURE must be explicitly specified')
        ,(N'FUNCTION'                       , 'Scripts permissions on all functions')
        ,(N'SQL_FUNCTION'                   , 'Scripts permissions on all SQL functions')
        ,(N'CLR_FUNCTION'                   , 'Scripts permissions on all CLR functions')
        ,(N'INLINE_FUNCTION'                , 'Scripts permissions on all inline table-valued functions')
        ,(N'SCALAR_FUNCTION'                , 'Scripts permissions on all scalar functions')
        ,(N'TABLE_VALUED_FUNCTION'          , 'Scripts permissions on all table-valued functions')
        ,(N'SQL_SCALAR_FUNCTION'            , 'Scripts permissions on all SQL scalar functions')
        ,(N'SQL_TABLE_VALUED_FUNCTION'      , 'Scripts permissions on all SQL table-valued functions')
        ,(N'CLR_SCALAR_FUNCTION'            , 'Scripts permissions on all CLR functions')
        ,(N'CLR_TABLE_VALUED_FUNCTION'      , 'Scripts permissions on all CLR table-valued functions')
        ,(N'AGGREGATE_FUNCTION'             , 'Scripts permissions on all CLR aggregate functions')
        ,(N'SYNONYM'                        , 'Scripts permissions on all synonyms')
        ,(N'SEQUENCE'                       , 'Scripts permissions on all sequences')

        ,(N''                               , '')
        ,(N'DATABASE_PRINCIPAL'             , 'Scripts permissions on all database principals')
        ,(N'ROLE'                           , 'Scripts permissions on all roles')
        ,(N'APPLICATION_ROLE'               , 'Scripts permissions on all application Roles')
        ,(N'DATABASE_ROLE'                  , 'Scripts permissions on all database Roles')
        ,(N'USER'                           , 'Scripts permissions on all users')
        ,(N'WINDOWS_GROUP'                  , 'Scripts permissions on all Windows group users')
        ,(N'SQL_USER'                       , 'Scripts permissions on all SQL users')
        ,(N'WINDOWS_USER'                   , 'Scripts permissions on all Windows users')
        ,(N'CERTIFICATE_MAPPED_USER'        , 'Scripts permissions on all certificate mapped users')
        ,(N'ASYMMETRIC_KEY_MAPPED_USER'     , 'Scripts permissions on all asymmetric key mapped users')

        ,(N''                               , '')
        ,(N'TYPE'                           , 'Scripts permissions on all Types')
        ,(N'ASSEMBLY'                       , 'Scripts permissions on all assemblies')
        ,(N'XML_SCHEMA_COLLECTION'          , 'Scripts permissions on all XML schema collections')
        
        ,(N''                               ,'')
        ,(N'SERVICE_BROKER'                 , 'Scripts permissions on all service broker related objects')
        ,(N'MESSAGE_TYPE'                   , 'Scripts permissions on all message types')
        ,(N'SERVICE_CONTRACT'               , 'Scripts permissions on all service contracts')
        ,(N'SERVICE'                        , 'Scripts permissions on all services')
        ,(N'REMOTE_SERVICE_BINDING'         , 'Scripts permissions on all remote service bindings')
        ,(N'ROUTE'                          , 'Scripts permissions on all routes')

        ,(N''                               , '')
        ,(N'FULLTEXT'                       , 'Scripts permissions on all Fulltext related objects (catalogs and stoplists)')
        ,(N'FULLTEXT_CATALOG'               , 'Scripts permissions on all fulltext catalogs')
        ,(N'FULLTEXT_STOPLIST'              , 'Scripts permissions on all fulltext stoplists')

        ,(N''                               , '')
        ,(N'ENCRYPTION'                     , 'Scripts permissions on all encryptions related objects')
        ,(N'SYMMETRIC_KEY'                  , 'Scripts permissions on all symmetric keys')
        ,(N'ASYMMETRIC_KEY'                 , 'Scripts permissions on all asymmetric keys')
        ,(N'CERTIFICATE'                    , 'Scripts permissions on all certificates')


--Get Databases list to iterate through
SET @xml = CONVERT(xml, N'<db>' + REPLACE(ISNULL(@database, DB_NAME()), N',', N'</db><db>') + N'</db>');

WITH DBNames AS (
	SELECT
		LTRIM(RTRIM(N.value('.', 'nvarchar(128)'))) AS DBName
	FROM @xml.nodes('/db') R(N)
)
INSERT INTO @databases(DBName)
SELECT DISTINCT
    QUOTENAME(d.[name]) AS DBName
FROM sys.databases d
INNER JOIN DBNames dn ON  d.name LIKE dn.DBName
WHERE Left(dn.DBName, 1) <> '-'
EXCEPT
SELECT DISTINCT
	QUOTENAME(d.[name]) AS DBName
FROM sys.databases d
INNER JOIN DBNames dn ON  d.name LIKE RIGHT(dn.DBName, LEN(dn.DBName) - 1)
WHERE Left(dn.DBName, 1) = '-'


--Parse the source principals list
SET @xml = CONVERT(xml, N'<usr>' + REPLACE(@principal, N',', N'</usr><usr>') + N'</usr>');

INSERT INTO #userList(UserName)
SELECT DISTINCT
    LTRIM(RTRIM(n.value(N'.', N'sysname')))
FROM @xml.nodes(N'usr') AS T(n)

--Split provided object classed and store them
IF ISNULL(RTRIM(LTRIM(@scriptClass)), N'') <> N''
BEGIN
    SET @xml = CONVERT(xml, N'<class>'+ REPLACE(@scriptClass, N',', N'</class><class>') + N'</class>')

    INSERT INTO @inputClasses(ClassName)
    SELECT
        LTRIM(RTRIM(n.value(N'.', N'nvarchar(128)'))) AS ObjectType
    FROM @xml.nodes(N'class') AS T(n)
END

--Detect object classes not in @allowedClasses
SET @wrongClasses = ISNULL(STUFF((SELECT
                                    N',' + c.ClassName
                                FROM (
                                    SELECT 
                                        c.ClassName
                                    FROM @inputClasses c
                                    LEFT JOIN @allowedClasses ac ON ac.ClassName <> '' AND ac.ClassName LIKE LTRIM(RTRIM(c.ClassName)) AND LEFT(c.ClassName, 1) <> '-'
                                    WHERE 
                                        LEFT(c.ClassName, 1) <> '-'
                                        AND
                                        ac.ClassName IS NULL
                                    UNION ALL
                                    SELECT
                                        c.ClassName
                                    FROM @inputClasses c
                                    LEFT JOIN @allowedClasses ac ON ac.ClassName <> '' AND ac.ClassName LIKE LTRIM(RTRIM(RIGHT(c.ClassName, LEN(c.ClassName) -1))) AND LEFT(c.ClassName, 1) = '-'
                                    WHERE 
                                        LEFT(c.ClassName, 1) = '-'
                                        AND
                                        ac.ClassName IS NULL
                                ) c(ClassName)
                                FOR XML PATH(N''))
                        , 1, 1, N'')
                    , N'');

--Check if correct object classed were provided. If not, raise error and list all possible object classes
IF ISNULL(@wrongClasses, N'') <> N'' OR @scriptClass = N''
BEGIN    
    SET @printHelp = 1;
    RAISERROR(N'ScriptClass(es) "%s" are not from within allowed list', 15, 2, @wrongClasses);
END

--Get matching script classes
INSERT INTO @classes(ClassName)
SELECT
    ac.ClassName
FROM @inputClasses c
INNER JOIN @allowedClasses ac ON ac.ClassName <> '' AND ac.ClassName LIKE LTRIM(RTRIM(c.ClassName)) AND LEFT(c.ClassName, 1) <> '-'
EXCEPT
SELECT
    ac.ClassName
FROM @inputClasses c
INNER JOIN @allowedClasses ac ON ac.ClassName <> '' AND ac.ClassName LIKE LTRIM(RTRIM(RIGHT(c.ClassName, LEN(c.ClassName) -1))) AND LEFT(c.ClassName, 1) = '-'

--if MS_SHIPPED script class was provided, set @ms_shipped to 1 (Used by Permissions on Objects)
IF EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'MS_SHIPPED'))
    SET @ms_shipped = 1


IF NOT EXISTS(SELECT 1 FROM @databases)
BEGIN
    SET @printHelp = 1;
    RAISERROR(N'No databases matching "%s" found', 15, 3, @database);
END

IF @principal IS NULL OR @printHelp = 1
BEGIN
    RAISERROR(N'', 0, 0) WITH NOWAIT;
    RAISERROR(N'Clones rights and/or role membership for specified principal(s)', 0, 0) WITH NOWAIT;;
    RAISERROR(N'For details see: https://github.com/PavelPawlowski/SQL-Scripts/wiki/sp_CloneRights', 0, 0) WITH NOWAIT;
    RAISERROR(N'', 0, 0);
    RAISERROR(N'Usage:', 0, 0);
    RAISERROR(N'[sp_CloneRights] parameters', 0, 0)
    RAISERROR(N'', 0, 0)
    SET @msg = N'Parameters:
     @principal     nvarchar(max)   = NULL  - Comma separated list of database principals to script the rights
                                              Supports wildcards when eg ''%%'' means all users
                                              [-] prefix means except
    ,@newPrincipal  sysname         = NULL  - New database principal to which copy rights.
                                              When NULL, permissions are cloned for the original principal.
    ,@database      nvarchar(max)   = NULL  - Comma separated list of databases to be iterated and permissions scripted. 
                                              Supports Like wildcards. NULL means current database
                                              [-] prefix means except
                                              On Azure must be NULL
    ,@scriptClass   nvarchar(max)   = NULL  - Comma separated list of permission classes to script. 
                                              Supports Like wildcards.
                                              NULL = ALL (NULL does not include MS_SHIPPED, SYSTEM_TABLE and EXTENDED_STORED_PROCEDURE).
                                              %% = All classes (including MS_SHIPPED, SYSTEM_TABLE and EXTENDED_STORED_PROCEDURE)
                                              [-] prefix means except. Usable together with [%%] to include all and remove unwated
    ,@printOnly     bit             = 1     - When 1 then only script is printed on screen otherwise script is executed
                                            - When @newPrincipal is not provided then it is always 1
    ,@noInfoMsg      bit            = 0     --When 1 then no info messages (except header) are output into the final script, only the commands granting permissions.'
    RAISERROR(@msg, 0, 0) WITH NOWAIT;

    RAISERROR(N'', 0, 0) WITH NOWAIT;
    RAISERROR(N'ScriptClass                        Description', 0, 0) WITH NOWAIT;
    RAISERROR(N'--------------------------------   -------------------------------------------------------------------------------', 0, 0) WITH NOWAIT;;

                                                                     
    DECLARE tc CURSOR FAST_FORWARD FOR
        SELECT 
            LEFT(ClassName + SPACE(35), 35) 
            + ClassDescription
        FROM @allowedClasses 
        ORDER BY RowId;
    OPEN tc;

    FETCH NEXT FROM tc INTO @msg;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        RAISERROR(@msg, 0, 0) WITH NOWAIT;
        FETCH NEXT FROM tc INTO @msg;
    END
    CLOSE tc;
    DEALLOCATE tc;

    RETURN;
END

--Empty line after header
RAISERROR(N'', 0, 0) WITH NOWAIT;


DECLARE dbs CURSOR FAST_FORWARD FOR
    SELECT
        DBName
    FROM @databases;

OPEN dbs;

FETCH NEXT FROM dbs INTO @dbName

--Loop through Databases
WHILE @@FETCH_STATUS = 0
BEGIN
    TRUNCATE TABLE #users;
    SET @userSql = N'USE ' + @dbName + N';
    SELECT DISTINCT
        dp.name COLLATE database_default
    FROM sys.database_principals dp
    INNER JOIN #userList u ON dp.name COLLATE database_default LIKE u.UserName COLLATE database_default
    WHERE LEFT(u.UserName,1) <> ''-'' AND dp.name <> ''dbo''

    EXCEPT 

    SELECT DISTINCT
        dp.name COLLATE database_default
    FROM sys.database_principals dp
    INNER JOIN #userList u ON dp.name COLLATE database_default LIKE RIGHT(u.UserName, LEN(u.UserName) -1) COLLATE database_default
    WHERE LEFT(u.UserName,1) = ''-''
    '
    INSERT INTO #users
    EXEC (@userSql);


    IF NOT EXISTS(SELECT 1 FROM #users)
    BEGIN
        RAISERROR(N'DB: %s - No principal matching pattern: "%s"', 0, 0, @dbName, @principal) WITH NOWAIT;
        FETCH NEXT FROM dbs INTO @dbName
        CONTINUE;
    END
    ELSE
    BEGIN
        TRUNCATE TABLE #output;

        --Cursor for users
        DECLARE usr CURSOR FAST_FORWARD FOR
            SELECT
                UserName
            FROM #users

        OPEN usr;

        FETCH NEXT FROM usr INTO @principalName

        --iterate through users and script rights
        WHILE (@@FETCH_STATUS = 0)
        BEGIN
            SELECT
                @newPrincipalName = CASE WHEN @newPrincipal IS NOT NULL THEN @newPrincipal ELSE @principalName END;

            --Script Group Memberhip
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'ROLES_MEMBERSHIP'))
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                INSERT INTO #output([database], [user], [new_user], [group], [message], [command])
                SELECT 
                    @dbName AS [database],
                    @OldUser AS [user],
                    @newPrincipal AS [new_user],
                    @group AS [group],
                    @msg AS [message],
                    CASE 
                        WHEN CONVERT(int, SERVERPROPERTY(''ProductMajorVersion'')) >= 11 THEN
                            ''ALTER ROLE '' + QUOTENAME(USER_NAME(rm.role_principal_id)) + '' ADD MEMBER '' + QUOTENAME(@newPrincipal)
                        ELSE
                        ''EXEC sp_addrolemember @rolename ='' 
                        + SPACE(1) + QUOTENAME(USER_NAME(rm.role_principal_id), '''''''') + '', @membername ='' + SPACE(1) + QUOTENAME(@newPrincipal, '''''''')
                    END AS command
                FROM sys.database_role_members AS rm
                WHERE USER_NAME(rm.member_principal_id) COLLATE database_default = @OldUser
                ORDER BY rm.role_principal_id ASC';

                SET @msg = 'Role Memberships'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @msg nvarchar(max)', 
                    @dbName=@dbName, @group = 1, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @msg = @msg
            END

            --Script databse level permissions
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'DATABASE'))
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                INSERT INTO #output([database], [user], [new_user], [group], [message], [command])
                SELECT   
                    @dbName AS [database],
                    @OldUser AS [user],
                    @newPrincipal AS [new_user],
                    @group AS [group],
                    @msg AS [message],    
                    CASE 
                        WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                        + SPACE(1) + perm.permission_name + SPACE(1)
                        + ''TO'' + SPACE(1) + QUOTENAME(@newPrincipal) COLLATE database_default
                        + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
                        + N'' AS '' + QUOTENAME(gp.name)
                FROM    sys.database_permissions AS perm
                INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id
                INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id
                WHERE    usr.name = @OldUser
                AND    perm.major_id = 0
                ORDER BY perm.permission_name ASC, perm.state_desc ASC';

                SET @msg = 'Database Level Permissions'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @msg nvarchar(max)', 
                    @dbName=@dbName, @group = 2, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @msg = @msg
            END

            --Scripts permissions on Schemas
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'SCHEMA') )
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                INSERT INTO #output([database], [user], [new_user], [group], [message], [command])
                    SELECT   
                        @dbName AS [database],
                        @OldUser AS [user],
                        @newPrincipal AS [new_user],
                        @group AS [group],
                        @msg AS [message],
                        CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                            + SPACE(1) + perm.permission_name + SPACE(1)
                            + N''ON'' + SPACE(1) + @className +''::''
                            + QUOTENAME(s.name)
                            + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@newPrincipal) COLLATE database_default
                            + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
                            + N'' AS '' + QUOTENAME(gp.name)
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.schemas s ON perm.major_id = s.schema_id
                    WHERE
                        usr.name = @OldUser
                        AND perm.class_desc = ''SCHEMA''
                    ORDER BY perm.permission_name ASC, perm.state_desc ASC'

                SET @msg = 'permission on schemas'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @msg nvarchar(max), @className nvarchar(50)', 
                    @dbName=@dbName, @group = 3, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @className = 'SCHEMA', @msg = @msg
            END

            --Common query for all object types
            SET @sql = N'USE ' + @dbName + N';
            INSERT INTO #output([database], [user], [new_user], [group], [message], [command])
            SELECT    
                @dbName AS [database],
                @OldUser AS [user],
                @newPrincipal AS [new_user],
                @group AS [group],
                @msg AS [message],
                CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                    + SPACE(1) + perm.permission_name + SPACE(1) + ''ON OBJECT::'' + QUOTENAME(SCHEMA_NAME(obj.schema_id)) + ''.'' + QUOTENAME(obj.name) 
                    + CASE WHEN cl.column_id IS NULL THEN SPACE(0) ELSE ''('' + QUOTENAME(cl.name) + '')'' END
                    + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@newPrincipal) COLLATE database_default
                    + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
                    + N'' AS '' + QUOTENAME(gp.name)
            FROM    sys.database_permissions AS perm
            INNER JOIN sys.all_objects AS obj ON perm.major_id = obj.[object_id]
            INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
            INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
            LEFT JOIN sys.columns AS cl ON cl.column_id = perm.minor_id AND cl.[object_id] = perm.major_id
            WHERE usr.name = @OldUser and obj.type = @objType AND (obj.is_ms_shipped = 0 OR @ms_shipped = 1)
            ORDER BY perm.permission_name ASC, perm.state_desc ASC'

            --Scripts permissions on User tables
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'OBJECT', 'TABLE') )
            BEGIN
                SET @msg = 'permission on user tables'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @objType char(2), @ms_shipped bit, @msg nvarchar(max)', 
                    @dbName=@dbName, @group = 4, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @objType='U', @ms_shipped = @ms_shipped, @msg = @msg
            END

            --Scripts permissions on System tables
            IF EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN ('SYSTEM_TABLE') )
            BEGIN
                SET @msg = 'permission on system tables'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @objType char(2), @ms_shipped bit, @msg nvarchar(max)', 
                    @dbName=@dbName, @group = 5, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @objType='S', @ms_shipped = @ms_shipped, @msg = @msg
            END

            --Scripts permissions on Views
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'OBJECT', 'VIEW') )
            BEGIN
                SET @msg = 'permission on views'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @objType char(2), @ms_shipped bit, @msg nvarchar(max)', 
                    @dbName=@dbName, @group = 6, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @objType='V', @ms_shipped = @ms_shipped, @msg = @msg
            END

            --Scripts permissions on SQL Stored Procs
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'OBJECT', 'STORED_PROCEDURE', 'SQL_STORED_PROCEDURE') )
            BEGIN
                SET @msg = 'permission on SQL stored procedures'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @objType char(2), @ms_shipped bit, @msg nvarchar(max)', 
                    @dbName=@dbName, @group = 7, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @objType='P', @ms_shipped = @ms_shipped, @msg = @msg
            END
            --Scripts permissions on CLR Stored Procs
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'OBJECT', 'STORED_PROCEDURE', 'CLR_STORED_PROCEDURE') )
            BEGIN
                SET @msg = 'permission on CLR stored procedures'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @objType char(2), @ms_shipped bit, @msg nvarchar(max)', 
                    @dbName=@dbName, @group = 8, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @objType='PC', @ms_shipped = @ms_shipped, @msg = @msg
            END
            --Scripts permissions on Extended Stored Procs
            IF EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN ('EXTENDED_STORED_PROCEDURE') )
            BEGIN
                SET @msg = 'permission on extended stored procedures'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @objType char(2), @ms_shipped bit, @msg nvarchar(max)', 
                    @dbName=@dbName, @group = 9, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @objType='X', @ms_shipped = @ms_shipped, @msg = @msg
            END

            --Scripts permissions on SQL inline table-valued fucntions
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'OBJECT', 'FUNCTION', 'SQL_FUNCTION', 'INLINE_FUNCTION') )
            BEGIN
                SET @msg = 'permission on SQL inline table-valued functions'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @objType char(2), @ms_shipped bit, @msg nvarchar(max)', 
                    @dbName=@dbName, @group = 10, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @objType='IF', @ms_shipped = @ms_shipped, @msg = @msg
            END

            --Scripts permissions on SQL Scalar functions
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'OBJECT', 'FUNCTION', 'SQL_FUNCTION', 'SCALAR_FUNCTION', 'SQL_SCALAR_FUNCTION') )
            BEGIN
                SET @msg = 'permission on SQL scalar functions'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @objType char(2), @ms_shipped bit, @msg nvarchar(max)', 
                    @dbName=@dbName, @group = 11, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @objType='FN', @ms_shipped = @ms_shipped, @msg = @msg
            END

            --Scripts permissions on SQL table valued functions
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'OBJECT', 'FUNCTION', 'SQL_FUNCTION', 'TABLE_VALUED_FUNCTION', 'SQL_TABLE_VALUED_FUNCTION') )
            BEGIN
                SET @msg = 'Clonning permission on SQL table-valued functions'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @objType char(2), @ms_shipped bit, @msg nvarchar(max)', 
                    @dbName=@dbName, @group = 12, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @objType='TF', @ms_shipped = @ms_shipped, @msg = @msg
            END

            --Scripts permissions on CLR table valued functions
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'OBJECT', 'FUNCTION', 'CLR_FUNCTION', 'TABLE_VALUED_FUNCTION', 'CLR_TABLE_VALUED_FUNCTION') )
            BEGIN
                SET @msg = 'permission on CLR table-valued functions'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @objType char(2), @ms_shipped bit, @msg nvarchar(max)', 
                    @dbName=@dbName, @group = 13, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @objType='FT', @ms_shipped = @ms_shipped, @msg = @msg
            END

            --Scripts permissions on CLR tscalar functions
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'OBJECT', 'FUNCTION', 'CLR_FUNCTION', 'SCALAR_FUNCTION', 'CLR_SCALAR_FUNCTION') )
            BEGIN
                SET @msg = 'permission on CLR scalar functions'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @objType char(2), @ms_shipped bit, @msg nvarchar(max)', 
                    @dbName=@dbName, @group = 14, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @objType='FS', @ms_shipped = @ms_shipped, @msg = @msg
            END

            --Scripts permissions on CLR aggregate functions
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'OBJECT', 'FUNCTION', 'CLR_FUNCTION', 'AGGREGATE_FUNCTION') )
            BEGIN
                SET @msg = 'permission on aggregate functions (CLR)'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @objType char(2), @ms_shipped bit, @msg nvarchar(max)', 
                    @dbName=@dbName, @group = 15, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @objType='AF', @ms_shipped = @ms_shipped, @msg = @msg
            END

            --Scripts permissions on synonyms
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'OBJECT', 'SYNONYM') )
            BEGIN
                SET @msg = 'permission on synonyms'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @objType char(2), @ms_shipped bit, @msg nvarchar(max)', 
                    @dbName=@dbName, @group = 16, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @objType='SN', @ms_shipped = @ms_shipped, @msg = @msg
            END

            --Scripts permissions on Sequences
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'OBJECT', 'SEQUENCE') )
            BEGIN
                SET @msg = 'permission on sequences'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @objType char(2), @ms_shipped bit, @msg nvarchar(max)', 
                    @dbName=@dbName, @group = 17, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @objType='SO', @ms_shipped = @ms_shipped, @msg = @msg
            END
    
            --Common query for all database principals
            SET @sql = N'USE ' + @dbName + N';
            INSERT INTO #output([database], [user], [new_user], [group], [message], [command])
                SELECT   
                    @dbName AS [database],
                    @OldUser AS [user],
                    @newPrincipal AS [new_user],
                    @group AS [group],
                    @msg AS [message],
                    CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                        + SPACE(1) + perm.permission_name + SPACE(1)
                        + N''ON'' + SPACE(1) + @className +''::''
                        + QUOTENAME(dp.name)
                        + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@newPrincipal) COLLATE database_default
                        + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
                        + N'' AS '' + QUOTENAME(gp.name)
                FROM    sys.database_permissions AS perm
                INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                INNER JOIN sys.database_principals dp ON perm.major_id = dp.principal_id
                WHERE
                    usr.name = @OldUser
                    AND dp.type = @type
                    AND perm.class_desc = ''DATABASE_PRINCIPAL''
                ORDER BY perm.permission_name ASC, perm.state_desc ASC'

            --Scripts permissions on application roles
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'DATABASE_PRINCIPAL', 'ROLE', 'APPLICATION_ROLE') )
            BEGIN
                SET @msg = 'permission on application roles'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @type char(1), @msg nvarchar(max), @className nvarchar(50)', 
                    @dbName=@dbName, @group = 18, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @type='A', @className = 'APPLICATION ROLE', @msg = @msg
            END
            --Scripts permissions on database roles
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'DATABASE_PRINCIPAL', 'ROLE', 'DATABASE_ROLE') )
            BEGIN
                SET @msg = 'permission on database roles'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @type char(1), @msg nvarchar(max), @className nvarchar(50)', 
                    @dbName=@dbName, @group = 19, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @type='R', @className = 'ROLE', @msg = @msg
            END
            --Script permissions on Windows groups
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'DATABASE_PRINCIPAL', 'USER', 'WINDOWS_GROUP') )
            BEGIN
                SET @msg = 'permission on Windows groups'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @type char(1), @msg nvarchar(max), @className nvarchar(50)', 
                    @dbName=@dbName, @group = 20, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @type='G', @className = 'USER', @msg = @msg
            END
            --Script permissions on SQL users
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'DATABASE_PRINCIPAL', 'USER', 'SQL_USER') )
            BEGIN
                SET @msg = 'permission on SQL Users'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @type char(1), @msg nvarchar(max), @className nvarchar(50)', 
                    @dbName=@dbName, @group = 21, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @type='S', @className = 'USER', @msg = @msg
            END
            --Script permissions on Windows users
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'DATABASE_PRINCIPAL', 'USER', 'WINDOWS_USER') )
            BEGIN
                SET @msg = 'permission on Windows users'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @type char(1), @msg nvarchar(max), @className nvarchar(50)', 
                    @dbName=@dbName, @group = 22, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @type='U', @className = 'USER', @msg = @msg
            END
            --Script permissions on certificate mapped users
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'DATABASE_PRINCIPAL', 'USER', 'CERTIFICATE_MAPPED_USER') )
            BEGIN
                SET @msg = 'permission on certificate mapped users'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @type char(1), @msg nvarchar(max), @className nvarchar(50)', 
                    @dbName=@dbName, @group = 23, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @type='C', @className = 'USER', @msg = @msg
            END
            --Script permission on asymmetric key mapped users
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'DATABASE_PRINCIPAL', 'USER', 'ASYMMETRIC_KEY_MAPPED_USER') )
            BEGIN
                SET @msg = 'permission on asymmetric key mapped users'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @type char(1), @msg nvarchar(max), @className nvarchar(50)', 
                    @dbName=@dbName, @group = 23, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @type='K', @className = 'USER', @msg = @msg
            END

            --Scripts permissions on Types
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'TYPE') )
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                INSERT INTO #output([database], [user], [new_user], [group], [message], [command])
                    SELECT   
                        @dbName AS [database],
                        @OldUser AS [user],
                        @newPrincipal AS [new_user],
                        @group AS [group],
                        @msg AS [message],
                        CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                            + SPACE(1) + perm.permission_name + SPACE(1)
                            + N''ON'' + SPACE(1) + @className +''::''
                            + QUOTENAME(SCHEMA_NAME(t.schema_id)) + ''.'' + QUOTENAME(t.name)
                            + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@newPrincipal) COLLATE database_default
                            + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
                            + N'' AS '' + QUOTENAME(gp.name)
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.types t ON perm.major_id = t.user_type_id
                    WHERE
                        usr.name = @OldUser
                        AND perm.class_desc = ''TYPE''
                    ORDER BY perm.permission_name ASC, perm.state_desc ASC'

                SET @msg = 'permission on user types'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @msg nvarchar(max), @className nvarchar(50)', 
                    @dbName=@dbName, @group = 25, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @className = 'TYPE', @msg = @msg
            END

            --Scripts permissions on assemblies
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'ASSEMBLY') )
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                INSERT INTO #output([database], [user], [new_user], [group], [message], [command])
                    SELECT   
                        @dbName AS [database],
                        @OldUser AS [user],
                        @newPrincipal AS [new_user],
                        @group AS [group],
                        @msg AS [message],
                        CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                            + SPACE(1) + perm.permission_name + SPACE(1)
                            + N''ON'' + SPACE(1) + @className +''::''
                            + QUOTENAME(a.name)
                            + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@newPrincipal) COLLATE database_default
                            + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
                            + N'' AS '' + QUOTENAME(gp.name)
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.assemblies a ON perm.major_id = a.assembly_id
                    WHERE
                        usr.name = @OldUser
                        AND perm.class_desc = ''ASSEMBLY''
                    ORDER BY perm.permission_name ASC, perm.state_desc ASC'

                SET @msg = 'permission on assemblies'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @msg nvarchar(max), @className nvarchar(50)', 
                    @dbName=@dbName, @group = 26, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @className = 'ASSEMBLY', @msg = @msg
            END

            --Scripts permissions on XML schema collections
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'XML_SCHEMA_COLLECTION') )
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                INSERT INTO #output([database], [user], [new_user], [group], [message], [command])
                    SELECT   
                        @dbName AS [database],
                        @OldUser AS [user],
                        @newPrincipal AS [new_user],
                        @group AS [group],
                        @msg AS [message],
                        CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                            + SPACE(1) + perm.permission_name + SPACE(1)
                            + N''ON'' + SPACE(1) + @className +''::''
                            + QUOTENAME(SCHEMA_NAME(x.schema_id)) + ''.'' + QUOTENAME(x.name)
                            + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@newPrincipal) COLLATE database_default
                            + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
                            + N'' AS '' + QUOTENAME(gp.name)
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.xml_schema_collections x ON perm.major_id = x.xml_collection_id
                    WHERE
                        usr.name = @OldUser
                        AND perm.class_desc = ''XML_SCHEMA_COLLECTION''
                    ORDER BY perm.permission_name ASC, perm.state_desc ASC'

                SET @msg = 'permission on XMNL schema collections'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @msg nvarchar(max), @className nvarchar(50)', 
                    @dbName=@dbName, @group = 27, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @className = 'XML SCHEMA COLLECTION', @msg = @msg
            END

            --Scripts permissions on message typess
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'SERVICE_BROKER', N'MESSAGE_TYPE') )
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                INSERT INTO #output([database], [user], [new_user], [group], [message], [command])
                    SELECT
                        @dbName AS [database],
                        @OldUser AS [user],
                        @newPrincipal AS [new_user],
                        @group AS [group],
                        @msg AS [message],
                        CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                            + SPACE(1) + perm.permission_name + SPACE(1)
                            + N''ON'' + SPACE(1) + @className +''::''
                            + QUOTENAME(mt.name)
                            + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@newPrincipal) COLLATE database_default
                            + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
                            + N'' AS '' + QUOTENAME(gp.name)
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.service_message_types mt ON perm.major_id = mt.message_type_id
                    WHERE    usr.name = @OldUser
                    AND perm.class_desc = ''MESSAGE_TYPE''
                    ORDER BY perm.permission_name ASC, perm.state_desc ASC'

                SET @msg = 'permission on message types'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @msg nvarchar(max), @className nvarchar(50)', 
                    @dbName=@dbName, @group = 28, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @className = 'MESSAGE TYPE', @msg = @msg
            END

            --Scripts permissions on service contracts
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'SERVICE_BROKER', N'SERVICE_CONTRACT') )
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                INSERT INTO #output([database], [user], [new_user], [group], [message], [command])
                    SELECT
                        @dbName AS [database],
                        @OldUser AS [user],
                        @newPrincipal AS [new_user],
                        @group AS [group],
                        @msg AS [message],
                        CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                            + SPACE(1) + perm.permission_name + SPACE(1)
                            + N''ON'' + SPACE(1) + @className +''::''
                            + QUOTENAME(sc.name)
                            + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@newPrincipal) COLLATE database_default
                            + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
                            + N'' AS '' + QUOTENAME(gp.name)
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.service_contracts sc ON perm.major_id = sc.service_contract_id
                    WHERE    usr.name = @OldUser
                    AND perm.class_desc = ''SERVICE_CONTRACT''
                    ORDER BY perm.permission_name ASC, perm.state_desc ASC'

                SET @msg = 'permission on service contracts'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @msg nvarchar(max), @className nvarchar(50)', 
                    @dbName=@dbName, @group = 29, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @className = 'CONTRACT', @msg = @msg
            END

            --Scripts permissions on services
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'SERVICE_BROKER', N'SERVICE') )
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                INSERT INTO #output([database], [user], [new_user], [group], [message], [command])
                    SELECT
                        @dbName AS [database],
                        @OldUser AS [user],
                        @newPrincipal AS [new_user],
                        @group AS [group],
                        @msg AS [message],
                        CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                            + SPACE(1) + perm.permission_name + SPACE(1)
                            + N''ON'' + SPACE(1) + @className +''::''
                            + QUOTENAME(s.name)
                            + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@newPrincipal) COLLATE database_default
                            + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
                            + N'' AS '' + QUOTENAME(gp.name)
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.services s ON perm.major_id = s.service_id
                    WHERE    usr.name = @OldUser
                    AND perm.class_desc = ''SERVICE''
                    ORDER BY perm.permission_name ASC, perm.state_desc ASC'

                SET @msg = 'permission on services'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @msg nvarchar(max), @className nvarchar(50)', 
                    @dbName=@dbName, @group = 30, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @className = 'SERVICE', @msg = @msg
            END
     
            --Scripts permissions on remote service bindings
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'SERVICE_BROKER', N'REMOTE_SERVICE_BINDING') )
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                INSERT INTO #output([database], [user], [new_user], [group], [message], [command])
                    SELECT
                        @dbName AS [database],
                        @OldUser AS [user],
                        @newPrincipal AS [new_user],
                        @group AS [group],
                        @msg AS [message],
                        CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                            + SPACE(1) + perm.permission_name + SPACE(1)
                            + N''ON'' + SPACE(1) + @className +''::''
                            + QUOTENAME(b.name)
                            + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@newPrincipal) COLLATE database_default
                            + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
                            + N'' AS '' + QUOTENAME(gp.name)
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.remote_service_bindings b ON perm.major_id = b.remote_service_binding_id
                    WHERE    usr.name = @OldUser
                    AND perm.class_desc = ''REMOTE_SERVICE_BINDING''
                    ORDER BY perm.permission_name ASC, perm.state_desc ASC'

                SET @msg = 'permission on remote service bindings'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @msg nvarchar(max), @className nvarchar(50)', 
                    @dbName=@dbName, @group = 31, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @className = 'REMOTE SERVICE BINDING', @msg = @msg
            END

            --Scripts permissions on routes
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'SERVICE_BROKER', N'ROUTE') )
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                INSERT INTO #output([database], [user], [new_user], [group], [message], [command])
                    SELECT
                        @dbName AS [database],
                        @OldUser AS [user],
                        @newPrincipal AS [new_user],
                        @group AS [group],
                        @msg AS [message],
                        CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                            + SPACE(1) + perm.permission_name + SPACE(1)
                            + N''ON'' + SPACE(1) + @className +''::''
                            + QUOTENAME(r.name)
                            + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@newPrincipal) COLLATE database_default
                            + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
                            + N'' AS '' + QUOTENAME(gp.name)
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.routes r ON perm.major_id = r.route_id
                    WHERE    usr.name = @OldUser
                    AND perm.class_desc = ''ROUTE''
                    ORDER BY perm.permission_name ASC, perm.state_desc ASC'

                SET @msg = 'permission on routes'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @msg nvarchar(max), @className nvarchar(50)', 
                    @dbName=@dbName, @group = 32, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @className = 'ROUTE', @msg = @msg
            END


            --Scripts permissions on fulltext catalogs
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'FULLTEXT', N'FULLTEXT_CATALOG') )
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                INSERT INTO #output([database], [user], [new_user], [group], [message], [command])
                    SELECT
                        @dbName AS [database],
                        @OldUser AS [user],
                        @newPrincipal AS [new_user],
                        @group AS [group],
                        @msg AS [message],
                        CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                            + SPACE(1) + perm.permission_name + SPACE(1)
                            + N''ON'' + SPACE(1) + @className +''::''
                            + QUOTENAME(c.name)
                            + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@newPrincipal) COLLATE database_default
                            + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
                            + N'' AS '' + QUOTENAME(gp.name)
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.fulltext_catalogs c ON perm.major_id = c.fulltext_catalog_id
                    WHERE    usr.name = @OldUser
                    AND perm.class_desc = ''FULLTEXT_CATALOG''
                    ORDER BY perm.permission_name ASC, perm.state_desc ASC'

                SET @msg = 'permission on fulltext catalogs'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @msg nvarchar(max), @className nvarchar(50)', 
                    @dbName=@dbName, @group = 33, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @className = 'FULLTEXT CATALOG', @msg = @msg
            END

            --Scripts permissions on fulltext stoplists
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'FULLTEXT', N'FULLTEXT_STOPLIST') )
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                INSERT INTO #output([database], [user], [new_user], [group], [message], [command])
                    SELECT
                        @dbName AS [database],
                        @OldUser AS [user],
                        @newPrincipal AS [new_user],
                        @group AS [group],
                        @msg AS [message],
                        CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                            + SPACE(1) + perm.permission_name + SPACE(1)
                            + N''ON'' + SPACE(1) + @className +''::''
                            + QUOTENAME(sl.name)
                            + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@newPrincipal) COLLATE database_default
                            + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
                            + N'' AS '' + QUOTENAME(gp.name)
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.fulltext_stoplists sl ON perm.major_id = sl.stoplist_id
                    WHERE    usr.name = @OldUser
                    AND perm.class_desc = ''FULLTEXT_STOPLIST''
                    ORDER BY perm.permission_name ASC, perm.state_desc ASC'

                SET @msg = 'permission on fulltext stoplists'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @msg nvarchar(max), @className nvarchar(50)', 
                    @dbName=@dbName, @group = 34, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @className = 'FULLTEXT STOPLIST', @msg = @msg
            END

            --Scripts permissions on symmetric keys
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'ENCRYP{TION', N'SYMMETRIC_KEY') )
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                INSERT INTO #output([database], [user], [new_user], [group], [message], [command])
                    SELECT
                        @dbName AS [database],
                        @OldUser AS [user],
                        @newPrincipal AS [new_user],
                        @group AS [group],
                        @msg AS [message],
                        CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                            + SPACE(1) + perm.permission_name + SPACE(1)
                            + N''ON'' + SPACE(1) + @className +''::''
                            + QUOTENAME(sk.name)
                            + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@newPrincipal) COLLATE database_default
                            + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
                            + N'' AS '' + QUOTENAME(gp.name)
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.symmetric_keys sk ON perm.major_id = sk.symmetric_key_id
                    WHERE    usr.name = @OldUser
                    AND perm.class_desc = ''SYMMETRIC_KEYS''
                    ORDER BY perm.permission_name ASC, perm.state_desc ASC'

                SET @msg = 'permission on symmetric keys'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @msg nvarchar(max), @className nvarchar(50)', 
                    @dbName=@dbName, @group = 35, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @className = 'SYMMETRIC KEY', @msg = @msg
            END

            --Scripts permissions on asymmetric keys
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'ENCRYP{TION', N'ASYMMETRIC_KEY') )
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                INSERT INTO #output([database], [user], [new_user], [group], [message], [command])
                    SELECT
                        @dbName AS [database],
                        @OldUser AS [user],
                        @newPrincipal AS [new_user],
                        @group AS [group],
                        @msg AS [message],
                        CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                            + SPACE(1) + perm.permission_name + SPACE(1)
                            + N''ON'' + SPACE(1) + @className +''::''
                            + QUOTENAME(ak.name)
                            + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@newPrincipal) COLLATE database_default
                            + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
                            + N'' AS '' + QUOTENAME(gp.name)
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.asymmetric_keys ak ON perm.major_id = ak.asymmetric_key_id
                    WHERE    usr.name = @OldUser
                    AND perm.class_desc = ''ASYMMETRIC_KEY''
                    ORDER BY perm.permission_name ASC, perm.state_desc ASC'

                SET @msg = 'permission on asymmetric keys'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @msg nvarchar(max), @className nvarchar(50)', 
                    @dbName=@dbName, @group = 36, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @className = 'ASYMMETRIC KEY', @msg = @msg
            END

            --Scripts permissions on certificates
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'ENCRYP{TION', N'CERTIFICATE') )
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                INSERT INTO #output([database], [user], [new_user], [group], [message], [command])
                    SELECT
                        @dbName AS [database],
                        @OldUser AS [user],
                        @newPrincipal AS [new_user],
                        @group AS [group],
                        @msg AS [message],
                        CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                            + SPACE(1) + perm.permission_name + SPACE(1)
                            + N''ON'' + SPACE(1) + @className +''::''
                            + QUOTENAME(c.name)
                            + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@newPrincipal) COLLATE database_default
                            + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
                            + N'' AS '' + QUOTENAME(gp.name)
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.certificates c ON perm.major_id = c.certificate_id
                    WHERE    usr.name = @OldUser
                    AND perm.class_desc = ''CERTIFICATE''
                    ORDER BY perm.permission_name ASC, perm.state_desc ASC'

                SET @msg = 'permission on certificates'
                RAISERROR(N'DB: %s, Principal: [%s], Clonning: "%s"', 0, 0, @dbName, @principalName, @msg) WITH NOWAIT;
                EXEC sp_executesql @sql, N'@dbName sysname, @group int, @OldUser sysname, @newPrincipal sysname, @msg nvarchar(max), @className nvarchar(50)', 
                    @dbName=@dbName, @group = 37, @OldUser = @principalName, @newPrincipal = @newPrincipalName, @className = 'CERTIFICATE', @msg = @msg
            END

            FETCH NEXT FROM usr INTO @principalName
        END --Loop through users

        CLOSE usr;
        DEALLOCATE usr;

        FETCH NEXT FROM dbs INTO @dbName
    END --IF NOT EXISTS(SELECT 1 FROM #users)
END --Loop through Databases

CLOSE dbs;
DEALLOCATE dbs;

--cursor for iterating the generated commands
DECLARE cr CURSOR FAST_FORWARD FOR
SELECT
    o.[database]
    ,o.[user]
    ,o.[new_user]
    ,o.[group]
    ,o.[message]
    ,o.command
FROM #output o
ORDER BY [database], [user], [new_user], [group]

OPEN cr;
FETCH NEXT FROM cr INTO @dbName, @principalName, @newPrincipalName, @group, @msg, @command

/* BUILD FINAL SCRIPT
   ================== */

INSERT INTO @finalOutput(command) VALUES(N'RAISERROR(N''' + @caption + N''', 0, 0) WITH NOWAIT;')
INSERT INTO @finalOutput(command) VALUES(N'RAISERROR(N''==============================================================='', 0, 0) WITH NOWAIT;');
INSERT INTO @finalOutput(command) VALUES(N'RAISERROR(N''Repository: https://github.com/PavelPawlowski/SQL-Scripts'', 0, 0) WITH NOWAIT;');
INSERT INTO @finalOutput(command) VALUES(N'RAISERROR(N''Feedback: mailto:pavel.pawlowski@hotmail.cz'', 0, 0) WITH NOWAIT;');
INSERT INTO @finalOutput(command) VALUES(N'RAISERROR(N''---------------------------------------------------------------'', 0, 0) WITH NOWAIT;');


IF @@FETCH_STATUS <> 0 
    INSERT INTO @finalOutput(command) VALUES (N'-- << NO PERMISSIONS TO CLONE >> --');
ELSE
    INSERT INTO @finalOutput(command) VALUES (N'SET XACT_ABORT ON;');

--loop through the #output table
WHILE @@FETCH_STATUS = 0 
BEGIN
    --database changed, add information about database into the script
    IF @lastdb <> @dbName
    BEGIN
        SELECT
            @lastdb = @dbName
            ,@lastUser = N''
            ,@lastGroup = 0

        IF @printOnly = 0 OR @noInfoMsg = 0
        BEGIN
            INSERT INTO @finalOutput(command) VALUES(N'RAISERROR(N''Granting permissions for database ' + @dbName + N''', 0, 0) WITH NOWAIT;')
            INSERT INTO @finalOutput(command) VALUES(N'--===============================================================')
            --Write the USE statement only on non azure SQLDB
        END

        --Add USE statement to the script only if not Azure edition.
        IF SERVERPROPERTY('EngineEdition') IN (1, 2, 3, 4, 8)
        BEGIN
            INSERT INTO @finalOutput VALUES(N'USE ' + @dbName + N';');
        END
    END

    --User changed, add information about user to the script
    IF @lastUser <> @principalName AND (@printOnly = 0 OR @noInfoMsg = 0)
    BEGIN
        SELECT
            @lastUser = @principalName
            ,@lastGroup = 0
        INSERT INTO @finalOutput(command) VALUES(N'---------------------------------------------------------------')
        INSERT INTO @finalOutput(command) VALUES(N'RAISERROR(N''  - Granting permissions from principal ' + QUOTENAME(@principalName) + N' to ' + QUOTENAME(@newPrincipalName) + N' '', 0, 0) WITH NOWAIT;');
    END

    IF @lastGroup <> @group AND (@printOnly = 0 OR @noInfoMsg = 0)
    BEGIN
        SET @lastGroup = @group
        INSERT INTO @finalOutput(command) VALUES(N'RAISERROR(N' + QUOTENAME(N'    - Granting ' + @msg, N'''') + N', 0, 0) WITH NOWAIT;');
    END

    IF (@printOnly = 0 OR @noInfoMsg = 0)
        INSERT INTO @finalOutput(command) VALUES(N'RAISERROR(N' + QUOTENAME(N'      ' + @command, N'''') + N', 0, 0) WITH NOWAIT;');    

    --insert GRANT command into finel output script
    INSERT INTO @finalOutput(command) VALUES(N'    ' + @command + N';');

    FETCH NEXT FROM cr INTO @dbName, @principalName, @newPrincipalName, @group, @msg, @command
END --loop through the #output table


CLOSE cr;
DEALLOCATE cr;


IF @printOnly = 1
BEGIN
    SELECT
        command
    FROM @finalOutput
    ORDER BY RowID
END
ELSE
BEGIN
    DECLARE ex CURSOR FAST_FORWARD FOR
    SELECT
        command
    FROM @finalOutput
    ORDER BY RowID

    OPEN ex;

    FETCH NEXT FROM ex INTO @command;

    --Loop through commands and execute
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC sp_executesql @command;
        FETCH NEXT FROM ex INTO @command;
    END

    CLOSE ex;
    DEALLOCATE ex;
END

DROP TABLE #output;
END;
GO

--Mark Stored Procedure as system object, so it executes in the context of current database.
IF SERVERPROPERTY('EngineEdition') IN (1, 2, 3, 4, 8)
    EXEC(N'EXECUTE sp_ms_marksystemobject ''dbo.sp_CloneRights''');
GO
