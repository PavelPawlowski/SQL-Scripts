USE [master]
GO
IF NOT EXISTS (SELECT 1 FROM sys.all_objects WHERE object_id = OBJECT_ID('[dbo].[sp_CloneRights]') AND TYPE = 'P')
    EXECUTE ('CREATE PROCEDURE [dbo].[sp_CloneRights] AS BEGIN PRINT ''Container for sp_CloneRights (C) Pavel Pawlowski'' END');
GO
/* ****************************************************
sp_CloneRights v0.40 (2017-11-14)
(C) 2010 - 2017 Pavel Pawlowski

Feedback: mailto:pavel.pawlowski@hotmail.cz

License: 
    sp_CloneRights is free to download and use for personal, educational, and internal 
    corporate purposes, provided that this header is preserved. Redistribution or sale 
    of sp_CloneRights, in whole or in part, is prohibited without the author's express 
    written consent.

Description:
    Clones rights and/or group membership for specified user(s)

Parameters:
     @user                      nvarchar(max)   = NULL  - Supports LIKE wildcards
    ,@newUser                   sysname         = NULL  - New user to which copy rights. If New users is provided, @Old user must return exactly one record
    ,@database                  nvarchar(max)   = NULL  - Comma separated list of databases to be iterated and permissions scripted. 
                                                        - Supports Like wildcards. NULL means current database
                                                        - [-] prefix means except
    ,@scriptClass               nvarchar(max)   = NULL  - Comma separated list of permission classes to script. NULL = ALL
    ,@printOnly                 bit             = 1     - When 1 then only script is printed on screen, when 0 then also script is executed, when NULL, script is only executed and not printed
                                                        - When @newUser is not provided then it is always 1'


* ***************************************************** */ 
ALTER PROCEDURE [dbo].[sp_CloneRights] 
    @user                       nvarchar(max)   = NULL, --Comma separated list of database principals to script he rights. Supports LIKE wildcards
    @newUser                    sysname         = NULL, --New user to which copy rights
    @database                   nvarchar(max)   = NULL, --Comma separated list of databases to be iterated and permissions scripted. Supports Like wildcards NULL Means current database
    @scriptClass                nvarchar(max)   = NULL, --Comma separated list of permission classes to script. NULL = ALL
    @printOnly                  bit             = 1     --When 1 then only script is printed on screen, when 0 then also script is executed, when NULL, script is only executed and not printed
AS
BEGIN

SET NOCOUNT ON;

DECLARE
    @printHelp      bit = 0
    ,@msg           nvarchar(max)
    ,@command       nvarchar(4000)
    ,@sql           nvarchar(max)
    ,@userSql       nvarchar(max)       --for storing query to fetch users list
    ,@dbName        nvarchar(128)
    ,@xml           xml                 --for XML storing purposes
    ,@userName      sysname
    ,@newUserName   sysname
    ,@usersCnt      int                 --count of matching users
    ,@wrongClasses  nvarchar(max)       --list of wrong class names


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
    ClassName sysname,
    ClassDescription nvarchar(max)
)


--table for storing output
CREATE TABLE #output (
    command nvarchar(max)
);


--Set and print the procedure output caption
RAISERROR(N'PRINT ''sp_CloneRights v0.40 (2017-11-14) (C) 2010-2017 Pavel Pawlowski''', 0, 0) WITH NOWAIT;
RAISERROR(N'PRINT ''===============================================================''', 0, 0) WITH NOWAIT;

INSERT INTO @allowedClasses(ClassName, ClassDescription)
VALUES
         (N'ROLES_MEMBERSHIP'               , 'Scripts roles membership')
        ,(N'DATABASE'                       , 'Scripts permissions on Database')
        ,(N'SCHEMA'                         , 'Scripts permissions on all schemas')
        ,(N''                               ,'')
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

        ,(N''                               ,'')
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

        ,(N''                               ,'')
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

        ,(N''                               ,'')
        ,(N'FULLTEXT'                       , 'Scripts permissions on all Fulltext related objects (catalogs and stoplists)')
        ,(N'FULLTEXT_CATALOG'               , 'Scripts permissions on all fulltext catalogs')
        ,(N'FULLTEXT_STOPLIST'              , 'Scripts permissions on all fulltext stoplists')

        ,(N''                               ,'')
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
    QUOTENAME(d.name)
FROM sys.databases d
INNER JOIN DBNames dn ON  d.name LIKE dn.DBName
WHERE Left(dn.DBName, 1) <> '-'

EXCEPT

SELECT DISTINCT
	QUOTENAME(d.name) AS DBName
FROM sys.databases d
INNER JOIN DBNames dn ON  d.name LIKE RIGHT(dn.DBName, LEN(dn.DBName) - 1)
WHERE Left(dn.DBName, 1) = '-'


--Parse the source users list
SET @xml = CONVERT(xml, N'<usr>' + REPLACE(@user, N',', N'</usr><usr>') + N'</usr>');

INSERT INTO #userList(UserName)
SELECT DISTINCT
    LTRIM(RTRIM(n.value(N'.', N'sysname')))
FROM @xml.nodes(N'usr') AS T(n)

--Split provided ObjectTypes and store them
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
                                FROM @inputClasses c
                                LEFT JOIN @allowedClasses ac ON ac.ClassName LIKE LTRIM(RTRIM(c.ClassName))
                                WHERE ac.ClassName IS NULL
                                FOR XML PATH(N''))
                        , 1, 1, N'')
                    , N'');

--Check if correct object types were provided. If not, raise error and list all possible object types
IF ISNULL(@wrongClasses, N'') <> N'' OR @scriptClass = N''
BEGIN    
    SET @printHelp = 1;
    RAISERROR(N'ScriptClasses "%s" are not from within allowed types', 15, 2, @wrongClasses);
END


INSERT INTO @classes(ClassName)
SELECT
    ac.ClassName
FROM @inputClasses c
INNER JOIN @allowedClasses ac ON ac.ClassName LIKE LTRIM(RTRIM(c.ClassName))

IF @user IS NULL OR @printHelp = 1
BEGIN
    RAISERROR(N'', 0, 0) WITH NOWAIT;
    RAISERROR(N'Clones rights and/or group membership for specified user(s)', 0, 0);
    RAISERROR(N'', 0, 0);
    RAISERROR(N'Usage:', 0, 0);
    RAISERROR(N'[sp_CloneRights] parameters', 0, 0)
    RAISERROR(N'', 0, 0)
    SET @msg = N'Parameters:
     @user          nvarchar(max)   = NULL  - Comma separated list of database principals to script the rights
                                            - Supports wildcards when eg ''%%'' means all users
                                            - [-] prefix means except
    ,@newUser       sysname         = NULL  - New database principal to which copy rights. If @newUser is provided, @user must match exactly one database principal
    ,@database      nvarchar(max)   = NULL  - Comma separated list of databases to be iterated and permissions scripted. 
                                            - Supports Like wildcards. NULL means current database
                                            - [-] prefix means except
    ,@scriptClass   nvarchar(max)   = NULL  - Comma separated list of permission classes to script. NULL = ALL
    ,@printOnly     bit             = 1     - When 1 then only script is printed on screen, when 0 then also script is executed, when NULL, script is only executed and not printed
                                            - When @newUser is not provided then it is always 1'
    RAISERROR(@msg, 0, 0);

    RAISERROR(N'', 0, 0);
    --RAISERROR(N'Allowed Script Classes:', 0, 0);
    --RAISERROR(N'-----------------------', 0, 0);
    RAISERROR(N'ScriptClass                        Description', 0, 0)
    RAISERROR(N'--------------------------------   -------------------------------------------------------------------------------', 0, 0);

                                                                     
    DECLARE tc CURSOR FAST_FORWARD FOR
        SELECT 
            LEFT(ClassName + SPACE(35), 35) 
            + ClassDescription
        FROM @allowedClasses 
        --ORDER BY ClassName;
    OPEN tc;

    FETCH NEXT FROM tc INTO @msg;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        RAISERROR(@msg, 0, 0);
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

WHILE @@FETCH_STATUS = 0
BEGIN
    TRUNCATE TABLE #users;

    SET @userSql = N'USE ' + @dbName + N';
    SELECT DISTINCT
        dp.name COLLATE database_default
    FROM sys.database_principals dp
    INNER JOIN #userList u ON dp.name COLLATE database_default LIKE u.UserName COLLATE database_default
    WHERE LEFT(u.UserName,1) <> ''-''

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
        RAISERROR(N'--Database %s: No users matching pattern: "%s"', 0, 0, @dbName, @user) WITH NOWAIT;
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

        FETCH NEXT FROM usr INTO @userName

        --Get Current Database Name
        SELECT
            @sql = N''

        --Script Database Context
        INSERT INTO #output(command)
        SELECT '' UNION ALL
        SELECT '--===================================================================' UNION ALL
        SELECT 'PRINT N''Cloning permissions in database' + SPACE(1) + @dbName + N'''' UNION ALL
        SELECT '--===================================================================' UNION ALL
        SELECT 'USE' + SPACE(1) + @dbName UNION ALL
        SELECT 'SET XACT_ABORT ON'


        --iterate through users and script rights
        WHILE (@@FETCH_STATUS = 0)
        BEGIN
            SELECT
                @newUserName = CASE WHEN @newUser IS NOT NULL THEN @newUser ELSE @userName END;

            INSERT INTO #output(command)
            SELECT '' UNION ALL
            SELECT '--===================================================================' UNION ALL
            SELECT 'PRINT N''Cloning permissions from' + SPACE(1) + QUOTENAME(@userName) + SPACE(1) + 'to' + SPACE(1) + QUOTENAME(@newUserName) +'''' UNION ALL
            SELECT '--==================================================================='

            --Script Group Memberhip
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'ROLES_MEMBERSHIP'))
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                IF EXISTS(SELECT 1 
                    FROM sys.database_role_members AS rm
                    WHERE USER_NAME(rm.member_principal_id) COLLATE database_default = @OldUser)
                INSERT INTO #output(command)
                SELECT '''' UNION ALL SELECT ''PRINT N'''''' + @msg + '''''''' AS command
                UNION ALL SELECT ''-----------------------------------------------------------'';

                INSERT INTO #output(command)
                SELECT 
                    CASE 
                        WHEN CONVERT(int, SERVERPROPERTY(''ProductMajorVersion'')) >= 11 THEN
                            ''ALTER ROLE '' + QUOTENAME(USER_NAME(rm.role_principal_id)) + '' ADD MEMBER '' + QUOTENAME(@NewUser)
                        ELSE
                        ''EXEC sp_addrolemember @rolename ='' 
                        + SPACE(1) + QUOTENAME(USER_NAME(rm.role_principal_id), '''''''') + '', @membername ='' + SPACE(1) + QUOTENAME(@NewUser, '''''''')
                    END AS command
                FROM sys.database_role_members AS rm
                WHERE USER_NAME(rm.member_principal_id) COLLATE database_default = @OldUser
                ORDER BY rm.role_principal_id ASC';

                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @msg nvarchar(max)', 
                    @OldUser = @userName, @NewUser = @newUserName, @msg = 'Clonning Role Memberships'
            END

            --Script databse level permissions
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'DATABASE'))
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                IF EXISTS(SELECT 1 
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id
                    WHERE    usr.name = @OldUser
                    AND    perm.major_id = 0)
                INSERT INTO #output(command)
                SELECT '''' UNION ALL SELECT ''PRINT N'''''' + @msg + '''''''' AS command
                UNION ALL SELECT ''-----------------------------------------------------------'';

                INSERT INTO #output(command)
                SELECT   CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                    + SPACE(1) + perm.permission_name + SPACE(1)
                    + ''TO'' + SPACE(1) + QUOTENAME(@NewUser) COLLATE database_default
                    + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
                    + N'' AS '' + QUOTENAME(gp.name)
                FROM    sys.database_permissions AS perm
                INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id
                INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id
                WHERE    usr.name = @OldUser
                AND    perm.major_id = 0
                ORDER BY perm.permission_name ASC, perm.state_desc ASC';

                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @msg nvarchar(max)', 
                    @OldUser = @userName, @NewUser = @newUserName, @msg = 'Clonning Database Level Permissions'
            END

            --Scripts permissions on Schemas
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'SCHEMA') )
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                IF EXISTS(SELECT 1 
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.schemas s ON perm.major_id = s.schema_id
                    WHERE
                        usr.name = @OldUser
                        AND perm.class_desc = ''SCHEMA'')
                    INSERT INTO #output(command)
                    SELECT '''' UNION ALL SELECT ''PRINT N'''''' + @msg + '''''''' AS command
                    UNION ALL SELECT ''-----------------------------------------------------------'';

                INSERT INTO #output(command)
                    SELECT   CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                        + SPACE(1) + perm.permission_name + SPACE(1)
                        + N''ON'' + SPACE(1) + @className +''::''
                        + QUOTENAME(s.name)
                        + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@NewUser) COLLATE database_default
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

                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @msg nvarchar(max), @className nvarchar(50)', 
                    @OldUser = @userName, @NewUser = @newUserName, @className = 'SCHEMA', @msg='Clonning permission on schemas'
            END

            --Common query for all object types
            SET @sql = N'USE ' + @dbName + N';
            IF EXISTS(SELECT 1 
                FROM    sys.database_permissions AS perm
                INNER JOIN sys.objects AS obj ON perm.major_id = obj.[object_id]
                INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id
                LEFT JOIN sys.columns AS cl ON cl.column_id = perm.minor_id AND cl.[object_id] = perm.major_id
                WHERE usr.name = @OldUser and obj.type = @objType)
                INSERT INTO #output(command)
                SELECT '''' UNION ALL SELECT ''PRINT N'''''' + @msg + '''''''' AS command
                UNION ALL SELECT ''-----------------------------------------------------------'';

            INSERT INTO #output(command)
            SELECT    CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                + SPACE(1) + perm.permission_name + SPACE(1) + ''ON OBJECT::'' + QUOTENAME(SCHEMA_NAME(obj.schema_id)) + ''.'' + QUOTENAME(obj.name) 
                + CASE WHEN cl.column_id IS NULL THEN SPACE(0) ELSE ''('' + QUOTENAME(cl.name) + '')'' END
                + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@NewUser) COLLATE database_default
                + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
                + N'' AS '' + QUOTENAME(gp.name)
            FROM    sys.database_permissions AS perm
            INNER JOIN sys.all_objects AS obj ON perm.major_id = obj.[object_id]
            INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
            INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
            LEFT JOIN sys.columns AS cl ON cl.column_id = perm.minor_id AND cl.[object_id] = perm.major_id
            WHERE usr.name = @OldUser and obj.type = @objType
            ORDER BY perm.permission_name ASC, perm.state_desc ASC'

            --Scripts permissions on User tables
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'OBJECT', 'TABLE') )
            BEGIN
                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @objType char(2), @msg nvarchar(max)', 
                    @OldUser = @userName, @NewUser = @newUserName, @objType='U', @msg='Clonning permission on user tables'
            END
            --Scripts permissions on System tables
            IF EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN ('SYSTEM_TABLE') )
            BEGIN
                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @objType char(2), @msg nvarchar(max)', 
                    @OldUser = @userName, @NewUser = @newUserName, @objType='S', @msg='Clonning permission on system tables'
            END
            --Scripts permissions on Views
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'OBJECT', 'VIEW') )
            BEGIN
                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @objType char(2), @msg nvarchar(max)', 
                    @OldUser = @userName, @NewUser = @newUserName, @objType='V', @msg='Clonning permission on views'
            END

            --Scripts permissions on SQL Stored Procs
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'OBJECT', 'STORED_PROCEDURE', 'SQL_STORED_PROCEDURE') )
            BEGIN
                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @objType char(2), @msg nvarchar(max)', 
                    @OldUser = @userName, @NewUser = @newUserName, @objType='P', @msg='Clonning permission on SQL stored procedures'
            END
            --Scripts permissions on CLR Stored Procs
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'OBJECT', 'STORED_PROCEDURE', 'CLR_STORED_PROCEDURE') )
            BEGIN
                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @objType char(2), @msg nvarchar(max)', 
                    @OldUser = @userName, @NewUser = @newUserName, @objType='PC', @msg='Clonning permission on CLR stored procedures'
            END
            --Scripts permissions on Extended Stored Procs
            IF EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN ('EXTENDED_STORED_PROCEDURE') )
            BEGIN
                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @objType char(2), @msg nvarchar(max)', 
                    @OldUser = @userName, @NewUser = @newUserName, @objType='X', @msg='Clonning permission on extended stored procedures'
            END

            --Scripts permissions on SQL inline table-valued fucntions
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'OBJECT', 'FUNCTION', 'SQL_FUNCTION', 'INLINE_FUNCTION') )
            BEGIN
                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @objType char(2), @msg nvarchar(max)', 
                    @OldUser = @userName, @NewUser = @newUserName, @objType='IF', @msg='Clonning permission on SQL inline table-valued functions'
            END

            --Scripts permissions on SQL Scalar functions
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'OBJECT', 'FUNCTION', 'SQL_FUNCTION', 'SCALAR_FUNCTION', 'SQL_SCALAR_FUNCTION') )
            BEGIN
                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @objType char(2), @msg nvarchar(max)', 
                    @OldUser = @userName, @NewUser = @newUserName, @objType='FN', @msg='Clonning permission on SQL scalar functions'
            END

            --Scripts permissions on SQL table valued functions
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'OBJECT', 'FUNCTION', 'SQL_FUNCTION', 'TABLE_VALUED_FUNCTION', 'SQL_TABLE_VALUED_FUNCTION') )
            BEGIN
                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @objType char(2), @msg nvarchar(max)', 
                    @OldUser = @userName, @NewUser = @newUserName, @objType='TF', @msg='Clonning permission on SQL table-valued functions'
            END

            --Scripts permissions on CLR table valued functions
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'OBJECT', 'FUNCTION', 'CLR_FUNCTION', 'TABLE_VALUED_FUNCTION', 'CLR_TABLE_VALUED_FUNCTION') )
            BEGIN
                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @objType char(2), @msg nvarchar(max)', 
                    @OldUser = @userName, @NewUser = @newUserName, @objType='FT', @msg='Clonning permission on CLR table-valued functions'
            END

            --Scripts permissions on CLR tscalar functions
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'OBJECT', 'FUNCTION', 'CLR_FUNCTION', 'SCALAR_FUNCTION', 'CLR_SCALAR_FUNCTION') )
            BEGIN
                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @objType char(2), @msg nvarchar(max)', 
                    @OldUser = @userName, @NewUser = @newUserName, @objType='FS', @msg='Clonning permission on CLR scalar functions'
            END

            --Scripts permissions on CLR aggregate functions
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'OBJECT', 'FUNCTION', 'CLR_FUNCTION', 'AGGREGATE_FUNCTION') )
            BEGIN
                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @objType char(2), @msg nvarchar(max)', 
                    @OldUser = @userName, @NewUser = @newUserName, @objType='AF', @msg='Clonning permission on aggregate functions (CLR)'
            END

            --Scripts permissions on synonyms
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'OBJECT', 'SYNONYM') )
            BEGIN
                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @objType char(2), @msg nvarchar(max)', 
                    @OldUser = @userName, @NewUser = @newUserName, @objType='SN', @msg='Clonning permission on synonyms'
            END

            --Scripts permissions on Sequences
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'OBJECT', 'SEQUENCE') )
            BEGIN
                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @objType char(2), @msg nvarchar(max)', 
                    @OldUser = @userName, @NewUser = @newUserName, @objType='SO', @msg='Clonning permission on sequences'
            END

    
            --Common query for all database principals
            SET @sql = N'USE ' + @dbName + N';
            IF EXISTS(SELECT 1 
                FROM    sys.database_permissions AS perm
                INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                INNER JOIN sys.database_principals dp ON perm.major_id = dp.principal_id
                WHERE    usr.name = @OldUser
                AND    dp.type = @type)
                INSERT INTO #output(command)
                SELECT '''' UNION ALL SELECT ''PRINT N'''''' + @msg + '''''''' AS command
                UNION ALL SELECT ''-----------------------------------------------------------'';

            INSERT INTO #output(command)
                SELECT   CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                    + SPACE(1) + perm.permission_name + SPACE(1)
                    + N''ON'' + SPACE(1) + @className +''::''
                    + QUOTENAME(dp.name)
                    + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@NewUser) COLLATE database_default
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

            --Scripts permissions on Application Roles
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'DATABASE_PRINCIPAL', 'ROLE', 'APPLICATION_ROLE') )
            BEGIN
                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @type char(1), @msg nvarchar(max), @className nvarchar(50)', 
                    @OldUser = @userName, @NewUser = @newUserName, @type='A', @className = 'APPLICATION ROLE', @msg='Clonning permission on application roles'
            END
            --Scripts permissions on Application Roles
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'DATABASE_PRINCIPAL', 'ROLE', 'DATABASE_ROLE') )
            BEGIN
                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @type char(1), @msg nvarchar(max), @className nvarchar(50)', 
                    @OldUser = @userName, @NewUser = @newUserName, @type='R', @className = 'ROLE', @msg='Clonning permission on database roles'
            END
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'DATABASE_PRINCIPAL', 'USER', 'WINDOWS_GROUP') )
            BEGIN
                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @type char(1), @msg nvarchar(max), @className nvarchar(50)', 
                    @OldUser = @userName, @NewUser = @newUserName, @type='G', @className = 'USER', @msg='Clonning permission on windows groups'
            END
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'DATABASE_PRINCIPAL', 'USER', 'SQL_USER') )
            BEGIN
                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @type char(1), @msg nvarchar(max), @className nvarchar(50)', 
                    @OldUser = @userName, @NewUser = @newUserName, @type='S', @className = 'USER', @msg='Clonning permission on SQL Users'
            END
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'DATABASE_PRINCIPAL', 'USER', 'WINDOWS_USER') )
            BEGIN
                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @type char(1), @msg nvarchar(max), @className nvarchar(50)', 
                    @OldUser = @userName, @NewUser = @newUserName, @type='U', @className = 'USER', @msg='Clonning permission on Windows users'
            END
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'DATABASE_PRINCIPAL', 'USER', 'CERTIFICATE_MAPPED_USER') )
            BEGIN
                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @type char(1), @msg nvarchar(max), @className nvarchar(50)', 
                    @OldUser = @userName, @NewUser = @newUserName, @type='C', @className = 'USER', @msg='Clonning permission on certificate mapped users'
            END
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'DATABASE_PRINCIPAL', 'USER', 'ASYMMETRIC_KEY_MAPPED_USER') )
            BEGIN
                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @type char(1), @msg nvarchar(max), @className nvarchar(50)', 
                    @OldUser = @userName, @NewUser = @newUserName, @type='K', @className = 'USER', @msg='Clonning permission on asymmetric key mapped users'
            END


            --Scripts permissions on Types
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'TYPE') )
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                IF EXISTS(SELECT 1 
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.types t ON perm.major_id = t.user_type_id
                    WHERE
                        usr.name = @OldUser
                        AND perm.class_desc = ''TYPE'')
                    INSERT INTO #output(command)
                    SELECT '''' UNION ALL SELECT ''PRINT N'''''' + @msg + '''''''' AS command
                    UNION ALL SELECT ''-----------------------------------------------------------'';

                INSERT INTO #output(command)
                    SELECT   CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                        + SPACE(1) + perm.permission_name + SPACE(1)
                        + N''ON'' + SPACE(1) + @className +''::''
                        + QUOTENAME(SCHEMA_NAME(t.schema_id)) + ''.'' + QUOTENAME(t.name)
                        + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@NewUser) COLLATE database_default
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

                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @msg nvarchar(max), @className nvarchar(50)', 
                    @OldUser = @userName, @NewUser = @newUserName, @className = 'TYPE', @msg='Clonning permission on user types'
            END



            --Scripts permissions on assemblies
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'ASSEMBLY') )
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                IF EXISTS(SELECT 1 
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.assemblies a ON perm.major_id = a.assembly_id
                    WHERE
                        usr.name = @OldUser
                        AND perm.class_desc = ''ASSEMBLY'')
                    INSERT INTO #output(command)
                    SELECT '''' UNION ALL SELECT ''PRINT N'''''' + @msg + '''''''' AS command
                    UNION ALL SELECT ''-----------------------------------------------------------'';

                INSERT INTO #output(command)
                    SELECT   CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                        + SPACE(1) + perm.permission_name + SPACE(1)
                        + N''ON'' + SPACE(1) + @className +''::''
                        + QUOTENAME(a.name)
                        + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@NewUser) COLLATE database_default
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

                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @msg nvarchar(max), @className nvarchar(50)', 
                    @OldUser = @userName, @NewUser = @newUserName, @className = 'ASSEMBLY', @msg='Clonning permission on assemblies'
            END

            --Scripts permissions on XML schema collections
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'XML_SCHEMA_COLLECTION') )
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                IF EXISTS(SELECT 1 
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.xml_schema_collections x ON perm.major_id = x.xml_collection_id
                    WHERE
                        usr.name = @OldUser
                        AND perm.class_desc = ''XML_SCHEMA_COLLECTION'')
                    INSERT INTO #output(command)
                    SELECT '''' UNION ALL SELECT ''PRINT N'''''' + @msg + '''''''' AS command
                    UNION ALL SELECT ''-----------------------------------------------------------'';

                INSERT INTO #output(command)
                    SELECT   CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                        + SPACE(1) + perm.permission_name + SPACE(1)
                        + N''ON'' + SPACE(1) + @className +''::''
                        + QUOTENAME(SCHEMA_NAME(x.schema_id)) + ''.'' + QUOTENAME(x.name)
                        + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@NewUser) COLLATE database_default
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

                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @msg nvarchar(max), @className nvarchar(50)', 
                    @OldUser = @userName, @NewUser = @newUserName, @className = 'XML SCHEMA COLLECTION', @msg='Clonning permission on XMNL schema collections'
            END

            --Scripts permissions on message typess
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'SERVICE_BROKER', N'MESSAGE_TYPE') )
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                IF EXISTS(SELECT 1 
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.service_message_types mt ON perm.major_id = mt.message_type_id
                    WHERE    usr.name = @OldUser
                    AND perm.class_desc = ''MESSAGE_TYPE'')
                    INSERT INTO #output(command)
                    SELECT '''' UNION ALL SELECT ''PRINT N'''''' + @msg + '''''''' AS command
                    UNION ALL SELECT ''-----------------------------------------------------------'';

                INSERT INTO #output(command)
                    SELECT   CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                        + SPACE(1) + perm.permission_name + SPACE(1)
                        + N''ON'' + SPACE(1) + @className +''::''
                        + QUOTENAME(mt.name)
                        + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@NewUser) COLLATE database_default
                        + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
                        + N'' AS '' + QUOTENAME(gp.name)
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.service_message_types mt ON perm.major_id = mt.message_type_id
                    WHERE    usr.name = @OldUser
                    AND perm.class_desc = ''MESSAGE_TYPE''
                    ORDER BY perm.permission_name ASC, perm.state_desc ASC'

                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @msg nvarchar(max), @className nvarchar(50)', 
                    @OldUser = @userName, @NewUser = @newUserName, @className = 'MESSAGE TYPE', @msg='Clonning permission on message types'
            END


            --Scripts permissions on service contracts
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'SERVICE_BROKER', N'SERVICE_CONTRACT') )
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                IF EXISTS(SELECT 1 
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.service_contracts sc ON perm.major_id = sc.service_contract_id
                    WHERE    usr.name = @OldUser
                    AND perm.class_desc = ''SERVICE_CONTRACT'')
                    INSERT INTO #output(command)
                    SELECT '''' UNION ALL SELECT ''PRINT N'''''' + @msg + '''''''' AS command
                    UNION ALL SELECT ''-----------------------------------------------------------'';

                INSERT INTO #output(command)
                    SELECT   CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                        + SPACE(1) + perm.permission_name + SPACE(1)
                        + N''ON'' + SPACE(1) + @className +''::''
                        + QUOTENAME(sc.name)
                        + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@NewUser) COLLATE database_default
                        + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
                        + N'' AS '' + QUOTENAME(gp.name)
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.service_contracts sc ON perm.major_id = sc.service_contract_id
                    WHERE    usr.name = @OldUser
                    AND perm.class_desc = ''SERVICE_CONTRACT''
                    ORDER BY perm.permission_name ASC, perm.state_desc ASC'

                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @msg nvarchar(max), @className nvarchar(50)', 
                    @OldUser = @userName, @NewUser = @newUserName, @className = 'CONTRACT', @msg='Clonning permission on service contracts'
            END


            --Scripts permissions on services
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'SERVICE_BROKER', N'SERVICE') )
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                IF EXISTS(SELECT 1 
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.services s ON perm.major_id = s.service_id
                    WHERE    usr.name = @OldUser
                    AND perm.class_desc = ''SERVICE'')
                    INSERT INTO #output(command)
                    SELECT '''' UNION ALL SELECT ''PRINT N'''''' + @msg + '''''''' AS command
                    UNION ALL SELECT ''-----------------------------------------------------------'';

                INSERT INTO #output(command)
                    SELECT   CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                        + SPACE(1) + perm.permission_name + SPACE(1)
                        + N''ON'' + SPACE(1) + @className +''::''
                        + QUOTENAME(s.name)
                        + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@NewUser) COLLATE database_default
                        + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
                        + N'' AS '' + QUOTENAME(gp.name)
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.services s ON perm.major_id = s.service_id
                    WHERE    usr.name = @OldUser
                    AND perm.class_desc = ''SERVICE''
                    ORDER BY perm.permission_name ASC, perm.state_desc ASC'

                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @msg nvarchar(max), @className nvarchar(50)', 
                    @OldUser = @userName, @NewUser = @newUserName, @className = 'SERVICE', @msg='Clonning permission on services'
            END

     
            --Scripts permissions on remote service bindings
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'SERVICE_BROKER', N'REMOTE_SERVICE_BINDING') )
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                IF EXISTS(SELECT 1 
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.remote_service_bindings b ON perm.major_id = b.remote_service_binding_id
                    WHERE    usr.name = @OldUser
                    AND perm.class_desc = ''REMOTE_SERVICE_BINDING'')
                    INSERT INTO #output(command)
                    SELECT '''' UNION ALL SELECT ''PRINT N'''''' + @msg + '''''''' AS command
                    UNION ALL SELECT ''-----------------------------------------------------------'';

                INSERT INTO #output(command)
                    SELECT   CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                        + SPACE(1) + perm.permission_name + SPACE(1)
                        + N''ON'' + SPACE(1) + @className +''::''
                        + QUOTENAME(b.name)
                        + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@NewUser) COLLATE database_default
                        + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
                        + N'' AS '' + QUOTENAME(gp.name)
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.remote_service_bindings b ON perm.major_id = b.remote_service_binding_id
                    WHERE    usr.name = @OldUser
                    AND perm.class_desc = ''REMOTE_SERVICE_BINDING''
                    ORDER BY perm.permission_name ASC, perm.state_desc ASC'

                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @msg nvarchar(max), @className nvarchar(50)', 
                    @OldUser = @userName, @NewUser = @newUserName, @className = 'REMOTE SERVICE BINDING', @msg='Clonning permission on remote service bindings'
            END

            --Scripts permissions on routes
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'SERVICE_BROKER', N'ROUTE') )
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                IF EXISTS(SELECT 1 
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.routes r ON perm.major_id = r.route_id
                    WHERE    usr.name = @OldUser
                    AND perm.class_desc = ''ROUTE'')
                    INSERT INTO #output(command)
                    SELECT '''' UNION ALL SELECT ''PRINT N'''''' + @msg + '''''''' AS command
                    UNION ALL SELECT ''-----------------------------------------------------------'';

                INSERT INTO #output(command)
                    SELECT   CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                        + SPACE(1) + perm.permission_name + SPACE(1)
                        + N''ON'' + SPACE(1) + @className +''::''
                        + QUOTENAME(r.name)
                        + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@NewUser) COLLATE database_default
                        + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
                        + N'' AS '' + QUOTENAME(gp.name)
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.routes r ON perm.major_id = r.route_id
                    WHERE    usr.name = @OldUser
                    AND perm.class_desc = ''ROUTE''
                    ORDER BY perm.permission_name ASC, perm.state_desc ASC'

                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @msg nvarchar(max), @className nvarchar(50)', 
                    @OldUser = @userName, @NewUser = @newUserName, @className = 'ROUTE', @msg='Clonning permission on routes'
            END


            --Scripts permissions on fulltext catalogs
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'FULLTEXT', N'FULLTEXT_CATALOG') )
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                IF EXISTS(SELECT 1 
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.fulltext_catalogs c ON perm.major_id = c.fulltext_catalog_id
                    WHERE    usr.name = @OldUser
                    AND perm.class_desc = ''FULLTEXT_CATALOG'')
                    INSERT INTO #output(command)
                    SELECT '''' UNION ALL SELECT ''PRINT N'''''' + @msg + '''''''' AS command
                    UNION ALL SELECT ''-----------------------------------------------------------'';

                INSERT INTO #output(command)
                    SELECT   CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                        + SPACE(1) + perm.permission_name + SPACE(1)
                        + N''ON'' + SPACE(1) + @className +''::''
                        + QUOTENAME(c.name)
                        + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@NewUser) COLLATE database_default
                        + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
                        + N'' AS '' + QUOTENAME(gp.name)
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.fulltext_catalogs c ON perm.major_id = c.fulltext_catalog_id
                    WHERE    usr.name = @OldUser
                    AND perm.class_desc = ''FULLTEXT_CATALOG''
                    ORDER BY perm.permission_name ASC, perm.state_desc ASC'

                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @msg nvarchar(max), @className nvarchar(50)', 
                    @OldUser = @userName, @NewUser = @newUserName, @className = 'FULLTEXT CATALOG', @msg='Clonning permission on fulltext catalogs'
            END

            --Scripts permissions on fulltext stoplists
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'FULLTEXT', N'FULLTEXT_STOPLIST') )
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                IF EXISTS(SELECT 1 
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.fulltext_stoplists sl ON perm.major_id = sl.stoplist_id
                    WHERE    usr.name = @OldUser
                    AND perm.class_desc = ''FULLTEXT_STOPLIST'')
                    INSERT INTO #output(command)
                    SELECT '''' UNION ALL SELECT ''PRINT N'''''' + @msg + '''''''' AS command
                    UNION ALL SELECT ''-----------------------------------------------------------'';

                INSERT INTO #output(command)
                    SELECT   CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                        + SPACE(1) + perm.permission_name + SPACE(1)
                        + N''ON'' + SPACE(1) + @className +''::''
                        + QUOTENAME(sl.name)
                        + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@NewUser) COLLATE database_default
                        + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
                        + N'' AS '' + QUOTENAME(gp.name)
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.fulltext_stoplists sl ON perm.major_id = sl.stoplist_id
                    WHERE    usr.name = @OldUser
                    AND perm.class_desc = ''FULLTEXT_STOPLIST''
                    ORDER BY perm.permission_name ASC, perm.state_desc ASC'

                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @msg nvarchar(max), @className nvarchar(50)', 
                    @OldUser = @userName, @NewUser = @newUserName, @className = 'FULLTEXT STOPLIST', @msg='Clonning permission on fulltext stoplists'
            END

            --Scripts permissions on symmetric keys
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'ENCRYP{TION', N'SYMMETRIC_KEY') )
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                IF EXISTS(SELECT 1 
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.symmetric_keys sk ON perm.major_id = sk.symmetric_key_id
                    WHERE    usr.name = @OldUser
                    AND perm.class_desc = ''SYMMETRIC_KEYS'')
                    INSERT INTO #output(command)
                    SELECT '''' UNION ALL SELECT ''PRINT N'''''' + @msg + '''''''' AS command
                    UNION ALL SELECT ''-----------------------------------------------------------'';

                INSERT INTO #output(command)
                    SELECT   CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                        + SPACE(1) + perm.permission_name + SPACE(1)
                        + N''ON'' + SPACE(1) + @className +''::''
                        + QUOTENAME(sk.name)
                        + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@NewUser) COLLATE database_default
                        + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
                        + N'' AS '' + QUOTENAME(gp.name)
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.symmetric_keys sk ON perm.major_id = sk.symmetric_key_id
                    WHERE    usr.name = @OldUser
                    AND perm.class_desc = ''SYMMETRIC_KEYS''
                    ORDER BY perm.permission_name ASC, perm.state_desc ASC'

                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @msg nvarchar(max), @className nvarchar(50)', 
                    @OldUser = @userName, @NewUser = @newUserName, @className = 'SYMMETRIC KEY', @msg='Clonning permission on symmetric keys'
            END

            --Scripts permissions on asymmetric keys
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'ENCRYP{TION', N'ASYMMETRIC_KEY') )
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                IF EXISTS(SELECT 1 
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.asymmetric_keys ak ON perm.major_id = ak.asymmetric_key_id
                    WHERE    usr.name = @OldUser
                    AND perm.class_desc = ''ASYMMETRIC_KEY'')
                    INSERT INTO #output(command)
                    SELECT '''' UNION ALL SELECT ''PRINT N'''''' + @msg + '''''''' AS command
                    UNION ALL SELECT ''-----------------------------------------------------------'';

                INSERT INTO #output(command)
                    SELECT   CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                        + SPACE(1) + perm.permission_name + SPACE(1)
                        + N''ON'' + SPACE(1) + @className +''::''
                        + QUOTENAME(ak.name)
                        + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@NewUser) COLLATE database_default
                        + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
                        + N'' AS '' + QUOTENAME(gp.name)
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.asymmetric_keys ak ON perm.major_id = ak.asymmetric_key_id
                    WHERE    usr.name = @OldUser
                    AND perm.class_desc = ''ASYMMETRIC_KEY''
                    ORDER BY perm.permission_name ASC, perm.state_desc ASC'

                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @msg nvarchar(max), @className nvarchar(50)', 
                    @OldUser = @userName, @NewUser = @newUserName, @className = 'ASYMMETRIC KEY', @msg='Clonning permission on asymmetric keys'
            END

            --Scripts permissions on certificates
            IF @scriptClass IS NULL OR EXISTS(SELECT ClassName FROM @classes WHERE ClassName IN (N'ENCRYP{TION', N'CERTIFICATE') )
            BEGIN
                SET @sql = N'USE ' + @dbName + N';
                IF EXISTS(SELECT 1 
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.certificates c ON perm.major_id = c.certificate_id
                    WHERE    usr.name = @OldUser
                    AND perm.class_desc = ''CERTIFICATE'')
                    INSERT INTO #output(command)
                    SELECT '''' UNION ALL SELECT ''PRINT N'''''' + @msg + '''''''' AS command
                    UNION ALL SELECT ''-----------------------------------------------------------'';

                INSERT INTO #output(command)
                    SELECT   CASE WHEN perm.state <> ''W'' THEN perm.state_desc ELSE ''GRANT'' END
                        + SPACE(1) + perm.permission_name + SPACE(1)
                        + N''ON'' + SPACE(1) + @className +''::''
                        + QUOTENAME(c.name)
                        + SPACE(1) + ''TO'' + SPACE(1) + QUOTENAME(@NewUser) COLLATE database_default
                        + CASE WHEN perm.state <> ''W'' THEN SPACE(0) ELSE SPACE(1) + ''WITH GRANT OPTION'' END
                        + N'' AS '' + QUOTENAME(gp.name)
                    FROM    sys.database_permissions AS perm
                    INNER JOIN sys.database_principals AS usr ON perm.grantee_principal_id = usr.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.database_principals AS gp ON perm.grantor_principal_id = gp.principal_id AND perm.major_id <> 0
                    INNER JOIN sys.certificates c ON perm.major_id = c.certificate_id
                    WHERE    usr.name = @OldUser
                    AND perm.class_desc = ''CERTIFICATE''
                    ORDER BY perm.permission_name ASC, perm.state_desc ASC'

                EXEC sp_executesql @sql, N'@OldUser sysname, @NewUser sysname, @msg nvarchar(max), @className nvarchar(50)', 
                    @OldUser = @userName, @NewUser = @newUserName, @className = 'CERTIFICATE', @msg='Clonning permission on certificates'
            END

            FETCH NEXT FROM usr INTO @userName
        END
        CLOSE usr;
        DEALLOCATE usr;



        --pring and/or execute the script
        DECLARE cr CURSOR FOR
            SELECT command FROM #output;

        OPEN cr;

        FETCH NEXT FROM cr INTO @command;

        SET @sql = '';

        WHILE @@FETCH_STATUS = 0
        BEGIN
            IF (@printOnly IS NOT NULL)
                RAISERROR(@command, 0, 0) WITH NOWAIT;

            SET @sql = @sql + @command + CHAR(13) + CHAR(10);
            FETCH NEXT FROM cr INTO @command;
        END  --WHILE @@FETCH_STATUS = 0

        CLOSE cr;
        DEALLOCATE cr;

        IF (@printOnly IS NULL OR @printOnly = 0) AND @newUser IS NOT NULL
            EXEC (@sql);

        FETCH NEXT FROM dbs INTO @dbName
    END --IF NOT EXISTS(SELECT 1 FROM #users)    
END


CLOSE dbs;
DEALLOCATE dbs;

    

DROP TABLE #output;

END
GO

--Mark Stored Procedure as system object, so it executes in the context of current database.
EXECUTE sp_ms_marksystemobject 'dbo.sp_CloneRights'
GO
