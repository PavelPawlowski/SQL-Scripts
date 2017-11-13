USE [SSISDB]
GO
RAISERROR('Creating procedure [dbo].[sp_SSISClonePermissions]', 0, 0) WITH NOWAIT;
IF NOT EXISTS(SELECT * FROM sys.procedures WHERE object_id = OBJECT_ID('[dbo].[sp_SSISClonePermissions]'))
    EXEC (N'CREATE PROCEDURE [dbo].[sp_SSISClonePermissions] AS PRINT ''Placeholder for [dbo].[sp_SSISClonePermissions]''')
GO
/* ****************************************************
sp_SSISClonePermissions v 0.10 (2017-11-13)
(C) 2017 Pavel Pawlowski

Feedback: mailto:pavel.pawlowski@hotmail.cz

License: 
    sp_SSISClonePermissions is free to download and use for personal, educational, and internal 
    corporate purposes, provided that this header is preserved. Redistribution or sale 
    of sp_SSISClonePermissions, in whole or in part, is prohibited without the author's express 
    written consent.

Description:
    Clones permissions for FOLDERS, PROJEECTS or ENVIRONMETNS to allow their easy transfer among environments

Parameters:
     @folder                    nvarchar(max)   = NULL  --Comma separated list of folders to script Permissions. Supports wildcards
	,@object                    nvarchar(max)	= '%'	--Comma separated list of object names (project or environment). Supports wildcards
    ,@type                      nvarchar(MAX)   = 'FOLDER,PROJECT,ENVIRONMENT'  --Comma separate list of object types to script permissions.
 ******************************************************* */
ALTER PROCEDURE [dbo].[sp_SSISClonePermissions]
     @folder                    nvarchar(max)   = NULL  --Comma separated list of folders to script Permissions. Supports wildcards
	,@object                    nvarchar(max)	= '%'	--Comma separated list of object names (project or environment). Supports wildcards
    ,@type                      nvarchar(MAX)   = 'FOLDER,PROJECT,ENVIRONMENT'  --Comma separate list of object types to script permissions.
WITH EXECUTE AS 'AllSchemaOwner'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @printHelp                      bit             = 0
        ,@captionBegin                  nvarchar(50)    = N''   --Beginning of the caption for the purpose of the caption printing
        ,@captionEnd                    nvarchar(50)    = N''   --End of the caption line for the purpose of the caption printing
        ,@caption                       nvarchar(max)           --sp_SSISClonePermissions caption
        ,@xml                           xml

        ,@object_type                   smallint
        ,@ObjectType                    nvarchar(20)
        ,@ObjectTypeQuoted              nvarchar(20)
        ,@ObjectFolder                  nvarchar(128)
        ,@ObjectFolderQuoted            nvarchar(256)
        ,@ObjectName                    nvarchar(128)
        ,@PrincipalName                 nvarchar(128)
        ,@GrantorPrincipalName          nvarchar(128)
        ,@PermissionType                smallint
        ,@IsDeny                        bit
        ,@last_object_type              smallint
        ,@last_object_folder            nvarchar(128)
        ,@isDenyInt                     int
        ,@firstInGroup                  bit                 = 1


    --Table variable for holding ids of folders to process
    DECLARE @folders TABLE (
        folder_id       bigint
    )

    --contains list of object names to match
    DECLARE @objectNames TABLE(
        object_name nvarchar(128) NOT NULL PRIMARY KEY CLUSTERED
    )
    
    --contains list of object types to script permissions
    DECLARE @types TABLE (
        TypeName    nvarchar(20) NOT NULL PRIMARY KEY CLUSTERED
        ,[Type]     smallint
    )

    IF @folder IS NULL
        SET @printHelp = 1

	--Set and print the procedure output caption
    IF (@printHelp = 0)
    BEGIN
        SET @captionBegin = N'RAISERROR(N''';
        SET @captionEnd = N''', 0, 0) WITH NOWAIT;';
    END

	SET @caption =  @captionBegin + N'sp_SSISClonePermissions v0.10 (2017-11-13) (C) 2017 Pavel Pawlowski' + @captionEnd + NCHAR(13) + NCHAR(10) + 
					@captionBegin + N'===================================================================' + @captionEnd + NCHAR(13) + NCHAR(10);
	RAISERROR(@caption, 0, 0) WITH NOWAIT;
    RAISERROR(N'', 0, 0) WITH NOWAIT;



    --get object types to script permissions
    SET @xml = N'<i>' + REPLACE(@type, ',', '</i><i>') + N'</i>';

    
    WITH ObjTypes AS (
        SELECT DISTINCT
            LTRIM(RTRIM(F.value('.', 'nvarchar(20)'))) AS TypeName
        FROM @xml.nodes(N'/i') T(F)
    )
    INSERT INTO @types(TypeName, [Type])
    SELECT
        TypeName
        ,CASE TypeName
            WHEN N'FOLDER' THEN 1
            WHEN N'PROJECT' THEN 2
            WHEN N'ENVIRONMENT' THEN 3
            WHEN N'OPERATION' THEN 4
            ELSE NULL
        END AS [Type]
    FROM ObjTypes

    IF EXISTS(SELECT 1 FROM @types WHERE TypeName NOT IN (N'FOLDER', N'PROJECT', N'ENVIRONMENT'))
    BEGIN
        SET @printHelp = 1
        RAISERROR(N'Only FOLDER,PROJECT,ENVIRONMENT is allowed as @type', 11, 0);
    END


    IF @printHelp = 1
    BEGIN
        RAISERROR(N'Clones permissions for FOLDERS, PROJEECTS or ENVIRONMETNS to allow their easy transfer among environments', 0, 0) WITH NOWAIT; 
        RAISERROR(N'', 0, 0) WITH NOWAIT; 
        RAISERROR(N'Usage:', 0, 0) WITH NOWAIT; 
        RAISERROR(N'[sp_SSISClonePermissions] parameters', 0, 0) WITH NOWAIT; 
        RAISERROR(N'', 0, 0) WITH NOWAIT; 
        RAISERROR(N'Parameters:
     @folder                    nvarchar(max)   = NULL                          - Comma separated list of folders to script Permissions. Supports wildcards
	,@object                    nvarchar(max)	= ''%%''	                        - Comma separated list of object names (project or environment). Supports wildcards
    ,@type                      nvarchar(MAX)   = ''FOLDER,PROJECT,ENVIRONMENT''  - Comma separate list of object types to script permissions.
                                                                                  Currently Supports FOLDER, PROJECT and ENVIRONMENT
        ', 0, 0) WITH NOWAIT;
RAISERROR(N'Wildcards:
----------
    Wildcards are standard wildcards for the LIKE statement
    Entries prefixed with [-] (minus) symbol are excluded form results and have priority over the non excluding

Samples:
--------

    ', 0, 0) WITH NOWAIT;

        RETURN;
    END

    --Get list of folders
    SET @xml = N'<i>' + REPLACE(@folder, ',', '</i><i>') + N'</i>';

    WITH FolderNames AS (
        SELECT DISTINCT
            LTRIM(RTRIM(F.value('.', 'nvarchar(128)'))) AS FolderName
        FROM @xml.nodes(N'/i') T(F)
    )
    INSERT INTO @folders (folder_id)
    SELECT DISTINCT
        folder_id
    FROM internal.folders F
    INNER JOIN FolderNames  FN ON F.name LIKE FN.FolderName AND LEFT(FN.FolderName, 1) <> '-'
    EXCEPT
    SELECT
        folder_id
    FROM internal.folders F
    INNER JOIN FolderNames  FN ON F.name LIKE RIGHT(FN.FolderName, LEN(FN.FolderName) - 1) AND LEFT(FN.FolderName, 1) = '-'

    IF NOT EXISTS(SELECT 1 FROM @folders)
    BEGIN
        RAISERROR(N'No Folder matching [%s] exists.', 15, 1, @folder) WITH NOWAIT;
        RETURN;
    END;


    --get object names
    SET @xml = N'<i>' + REPLACE(@object, ',', '</i><i>') + N'</i>';

    
    INSERT INTO @objectNames(object_name)
    SELECT DISTINCT
        LTRIM(RTRIM(F.value('.', 'nvarchar(128)'))) AS ObjectName
    FROM @xml.nodes(N'/i') T(F);


RAISERROR(N'
-- Declarations:
-- -------------

DECLARE
         @ObjectType                    nvarchar(20)
        ,@ObjectFolder                  nvarchar(128)
        ,@ObjectName                    nvarchar(128)
        ,@PrincipalName                 nvarchar(128)
        ,@GrantorPrincipalName          nvarchar(128)
        ,@PermissionType                smallint
        ,@IsDeny                        bit;

DECLARE @permissions TABLE (
    ObjectType              nvarchar(20)
    ,ObjectFolder           nvarchar(128)
    ,ObjectName             nvarchar(128)
    ,PrincipalName          nvarchar(128)
    ,GrantorPrincipalName   nvarchar(128)
    ,PermissionType         smallint
    ,IsDeny                 bit
)

SET NOCOUNT ON;

', 0, 0) WITH NOWAIT;

    DECLARE cr CURSOR FAST_FORWARD FOR
    WITH ObjectPermissions AS (
        SELECT
            op.object_type
            ,CASE op.object_type
                WHEN 1 THEN 'FOLDER'
                WHEN 2 THEN 'PROJECT'
                WHEN 3 THEN 'ENVIRONMENT'
                WHEN 4 THEN 'OPERATION'
                ELSE NULL
            END                                 AS ObjectType
            ,CASE op.object_type
                WHEN 1 THEN op.object_id
                WHEN 2 THEN p.folder_id
                WHEN 3 THEN e.folder_id
                ELSE NULL
            END                                 AS ObjectFolderID
            ,CASE op.object_type
                WHEN 1 THEN f.name
                WHEN 2 THEN pf.name
                WHEN 3 THEN ef.name
                ELSE NULL
            END                                 AS ObjectFolder
            ,CASE op.object_type
                WHEN 1 THEN f.name
                WHEN 2 THEN p.name
                WHEN 3 THEN e.environment_name
            END                                 AS ObjectName    
            ,dp.name                            AS PrincipalName
            ,gp.name                            AS GrantorPrincipalName
            ,op.permission_type                 AS PermissionType
            ,op.is_deny                         AS IsDeny
        FROM internal.object_permissions op
        LEFT JOIN internal.folders f ON f.folder_id = op.object_id and op.object_type = 1
        LEFT JOIN internal.projects p ON p.project_id = op.object_id AND op.object_type = 2
        LEFT JOIN internal.folders pf ON pf.folder_id = p.folder_id
        LEFT JOIN internal.environments e ON e.environment_id = op.object_id AND op.object_type = 3
        LEFT JOIN internal.folders ef ON ef.folder_id = e.folder_id
        INNER JOIN sys.database_principals dp ON dp.sid = op.sid
        INNER JOIN sys.database_principals gp ON gp.sid = op.grantor_sid
        WHERE
            op.object_type IN (SELECT [Type] FROM @types)
    )
    SELECT
         op.object_type
        ,op.ObjectType
        ,op.ObjectFolder
        ,op.ObjectName
        ,op.PrincipalName
        ,op.GrantorPrincipalName
        ,op.PermissionType
        ,op.IsDeny
    FROM ObjectPermissions op
    INNER JOIN @folders f ON f.folder_id = op.ObjectFolderID
    INNER JOIN @objectNames o ON op.ObjectName LIKE o.object_name AND LEFT(o.object_name, 1) <> '-'        
    EXCEPT 
    SELECT
         op.object_type
        ,op.ObjectType
        ,op.ObjectFolder
        ,op.ObjectName
        ,op.PrincipalName
        ,op.GrantorPrincipalName
        ,op.PermissionType
        ,op.IsDeny
    FROM ObjectPermissions op
    INNER JOIN @folders f ON f.folder_id = op.ObjectFolderID
    INNER JOIN @objectNames o ON op.ObjectName LIKE RIGHT(o.object_name, LEN(o.object_name) - 1) AND LEFT(o.object_name, 1) = '-'   
    ORDER BY object_type, ObjectFolder, ObjectName, PrincipalName


    OPEN cr;

    FETCH NEXT FROM cr INTO
         @object_type
        ,@ObjectType            
        ,@ObjectFolder          
        ,@ObjectName            
        ,@PrincipalName         
        ,@GrantorPrincipalName  
        ,@PermissionType        
        ,@IsDeny                


    WHILE @@FETCH_STATUS = 0
    BEGIN
        --Quote values for printing
        SELECT
             @ObjectFolderQuoted        = N'N''' + REPLACE(@ObjectFolder, '''', '''''') + ''''
            ,@ObjectName                = N'N''' + REPLACE(@ObjectName, '''', '''''') + ''''
            ,@PrincipalName             = N'N''' + REPLACE(@PrincipalName, '''', '''''') + ''''
            ,@GrantorPrincipalName      = N'N''' + REPLACE(@GrantorPrincipalName, '''', '''''') + ''''
            ,@ObjectTypeQuoted          = N'N''' + REPLACE(@ObjectType, '''', '''''') + ''''
            ,@isDenyInt                 = @IsDeny


        IF @last_object_type IS NULL OR @last_object_type <> @object_type
        BEGIN
            RAISERROR(N'-- =================================================================================', 0, 0) WITH NOWAIT;
            RAISERROR(N'-- Object Types: %s', 0, 0, @ObjectType) WITH NOWAIT;
            RAISERROR(N'-- =================================================================================', 0, 0) WITH NOWAIT;
            RAISERROR(N'SET @ObjectType             = %s', 0, 0, @ObjectTypeQuoted           ) WITH NOWAIT;
            RAISERROR(N'-- =================================================================================', 0, 0) WITH NOWAIT;
            SET @last_object_folder = NULL
            SET @firstInGroup = 1
        END

        IF @object_type <> 1 AND (@last_object_folder IS NULL OR @last_object_folder <> @ObjectFolder)
        BEGIN
            RAISERROR(N'-- *********************************************************************************', 0, 0) WITH NOWAIT;
            RAISERROR(N'-- Folder: %s', 0, 0, @ObjectFolder) WITH NOWAIT;
            RAISERROR(N'-- *********************************************************************************', 0, 0) WITH NOWAIT;
            RAISERROR(N'SET @ObjectFolder           = %s', 0, 0, @ObjectFolderQuoted         ) WITH NOWAIT;
            RAISERROR(N'-- *********************************************************************************', 0, 0) WITH NOWAIT;
            SET @firstInGroup = 1
        END
        
        IF @firstInGroup = 0
            RAISERROR(N'-- ---------------', 0, 0) WITH NOWAIT;

        RAISERROR(N'SET @ObjectName             = %s', 0, 0, @ObjectName           ) WITH NOWAIT;
        RAISERROR(N'SET @PrincipalName          = %s', 0, 0, @PrincipalName        ) WITH NOWAIT;
        RAISERROR(N'SET @GrantorPrincipalName   = %s', 0, 0, @GrantorPrincipalName ) WITH NOWAIT;
        RAISERROR(N'SET @PermissionType         = %d', 0, 0, @PermissionType       ) WITH NOWAIT;
        RAISERROR(N'SET @IsDeny                 = %d', 0, 0, @IsDenyInt            ) WITH NOWAIT;

        IF @object_type <> 1
            RAISERROR(N'INSERT INTO @permissions(ObjectType, ObjectFolder, ObjectName, PrincipalName, GrantorPrincipalName, PermissionType, IsDeny) VALUES(@ObjectType, @ObjectFolder, @ObjectName, @PrincipalName, @GrantorPrincipalName, @PermissionType, @isDeny)', 0, 0) WITH NOWAIT;
        ELSE
            RAISERROR(N'INSERT INTO @permissions(ObjectType, ObjectFolder, ObjectName, PrincipalName, GrantorPrincipalName, PermissionType, IsDeny) VALUES(@ObjectType, @ObjectName, @ObjectName, @PrincipalName, @GrantorPrincipalName, @PermissionType, @isDeny)', 0, 0) WITH NOWAIT;

        SELECT
            @last_object_folder     = @ObjectFolder
            ,@last_object_type      = @object_type
            ,@firstInGroup          = 0

        FETCH NEXT FROM cr INTO
             @object_type
            ,@ObjectType            
            ,@ObjectFolder          
            ,@ObjectName            
            ,@PrincipalName         
            ,@GrantorPrincipalName  
            ,@PermissionType        
            ,@IsDeny                
    END


    CLOSE cr;
    DEALLOCATE cr;


    --Print Runtime part for the script
    RAISERROR(N'', 0, 0) WITH NOWAIT;
    RAISERROR(N'-- =================================================================================', 0, 0) WITH NOWAIT;
    RAISERROR(N'--                                     RUNTIME', 0, 0) WITH NOWAIT;
    RAISERROR(N'-- =================================================================================', 0, 0) WITH NOWAIT;

RAISERROR(N'
DECLARE
    @lastObjectType         nvarchar(20)
    ,@lastObjectFolder      nvarchar(128)
    ,@lastObjectName        nvarchar(128)
    ,@lastPrincipal         nvarchar(128)
    ,@processFld            bit
    ,@processObj            bit
    ,@processPrinc          bit
    ,@object_id             bigint
    ,@principal_id          int
    ,@object_type           smallint
    ,@isDenyInt             int
    ,@permissionDesc        nvarchar(50)

DECLARE cr CURSOR FAST_FORWARD FOR
SELECT
     ObjectType
    ,ObjectFolder
    ,ObjectName
    ,PrincipalName
    ,GrantorPrincipalName
    ,PermissionType
    ,IsDeny
FROM @permissions
ORDER BY ObjectType, ObjectFolder, ObjectName, PrincipalName', 0, 0) WITH NOWAIT;
RAISERROR(N'
OPEN cr;

FETCH NEXT FROM cr INTO
     @ObjectType            
    ,@ObjectFolder          
    ,@ObjectName            
    ,@PrincipalName         
    ,@GrantorPrincipalName  
    ,@PermissionType   
    ,@isDeny     

WHILE @@FETCH_STATUS = 0
BEGIN ', 0, 0) WITH NOWAIT;
RAISERROR(N'
    SET @isDenyInt = @IsDeny

    IF @lastObjectType IS NULL OR @lastObjectType <> @ObjectType
    BEGIN
        SET @lastObjectFolder   = NULL;
        SET @lastObjectName     = NULL;
        SET @lastPrincipal      = NULL
        SET @processFld         = 1
        SET @processObj         = 1
        SET @processPrinc       = 1
        SET @object_type = CASE @ObjectType
                                WHEN N''FOLDER'' THEN 1
                                WHEN N''PROJECT'' THEN 2
                                WHEN ''ENVIRONMENT'' THEN 3
                                ELSE NULL
                            END

        IF @lastObjectType IS NOT NULL
            RAISERROR(N''==================================================================='', 0, 0) WITH NOWAIT;

        RAISERROR(N''Processing ObjectTypes [%%s]'', 0, 0, @ObjectType) WITH NOWAIT;        
        RAISERROR(N''==================================================================='', 0, 0) WITH NOWAIT;                    
        SET @lastObjectFolder = NULL
    END', 0, 0) WITH NOWAIT;
RAISERROR(N'

    IF @ObjectType <> N''FOLDER'' AND @lastObjectFolder IS NULL OR @lastObjectFolder <> @ObjectFolder
    BEGIN
        SET @processFld         = 1
        SET @processObj         = 1
        SET @processPrinc       = 1
        SET @lastObjectName = NULL;
        SET @lastPrincipal = NULL

        IF @lastObjectFolder IS NOT NULL
            RAISERROR(N''*******************************************************************'', 0, 0) WITH NOWAIT;

        IF NOT EXISTS(SELECT 1 FROM [SSISDB].[catalog].[folders] f WHERE f.[name] = @ObjectFolder)
        BEGIN
            SET @processFld = 0;
            RAISERROR(N''Destination folder [%%s] does not exist. Ignoring objects in folder.'', 11, 0, @ObjectFolder) WITH NOWAIT;
        END
        ELSE
        BEGIN
            RAISERROR(N''Processing folder [%%s]'', 0, 0, @ObjectFolder) WITH NOWAIT;
        END
        RAISERROR(N''*******************************************************************'', 0, 0) WITH NOWAIT;
    END', 0, 0) WITH NOWAIT;
RAISERROR(N'
    IF @processFld = 1
    BEGIN
        IF @lastObjectName IS NULL OR @lastObjectName <> @ObjectName
        BEGIN
            SELECT
                @processObj         = 1
                ,@processPrinc      = 1
                ,@object_id         = NULL

            IF @ObjectType = N''FOLDER''
            BEGIN
                SELECT @object_id = folder_id FROM [SSISDB].[catalog].[folders] f WHERE f.[name] = @ObjectName

                IF @object_id IS NULL
                BEGIN
                    SET @processFld = 0;
                    RAISERROR(N''Destination folder [%%s] does not exist. Ignoring Folder Permissions.'', 11, 0, @ObjectName) WITH NOWAIT;
                END
                ELSE
                    RAISERROR(N''Setting Permissions on Folder [%%s]'', 0, 0, @ObjectName) WITH NOWAIT;
            END', 0, 0) WITH NOWAIT;
RAISERROR(N'            ELSE IF @ObjectType = N''PROJECT''
            BEGIN
                SELECT @object_id = project_id FROM [SSISDB].[catalog].[projects] p WHERE p.[name] = @ObjectName

                IF @object_id IS NULL
                BEGIN
                    SET @processFld = 0;
                    RAISERROR(N''Destination Project [%%s]\[%%s] does not exist. Ignoring Project Permissions.'', 11, 0, @ObjectFolder, @ObjectName) WITH NOWAIT;
                END
                ELSE
                RAISERROR(N''Setting Permissions on Project [%%s]'', 0, 0, @ObjectName) WITH NOWAIT;
            END
            ELSE IF @objectType = N''ENVIRONMENT''
            BEGIN
                SELECT @object_id = environment_id FROM [SSISDB].[catalog].[environments] e WHERE e.[name] = @ObjectName

                IF @object_id IS NULL
                BEGIN
                    SET @processFld = 0;
                    RAISERROR(N''Destination Environment [%%s]\[%%s] does not exist. Ignoring Environment Permissions.'', 11, 0, @ObjectFolder, @ObjectName) WITH NOWAIT;
                END
                ELSE
                RAISERROR(N''Setting Permissions on Environment [%%s]'', 0, 0, @ObjectName) WITH NOWAIT;
            END

            RAISERROR(N''-------------------------------------------------------------------'', 0, 0) WITH NOWAIT;
        END', 0, 0) WITH NOWAIT;
RAISERROR(N'
        IF @lastPrincipal IS NULL OR @lastPrincipal <> @PrincipalName
        BEGIN
            SET @principal_id = NULL
            SELECT @principal_id = principal_id FROM [SSISDB].sys.database_principals WHERE name = @PrincipalName

            IF @principal_id IS NULL
            BEGIN
                RAISERROR(N''Database Principal [%%s] does not exists in SSISDB. Ignoring permissions for database principal'', 11, 0, @PrincipalName) WITH NOWAIT;
                SET @processPrinc = 1
            END
            ELSE
                RAISERROR(N''Granting Permissions for Database Principal [%%s]'', 0, 0, @PrincipalName) WITH NOWAIT;
        END', 0, 0) WITH NOWAIT;
RAISERROR(N'

        IF @processPrinc = 1
        BEGIN
            SET  @permissionDesc = 
                CASE @PermissionType
                    WHEN 1      THEN N''READ''
                    WHEN 2      THEN N''MODIFY''
                    WHEN 3      THEN N''EXECUTE''
                    WHEN 4      THEN N''MANAGE_PERMISSIONS''
                    WHEN 100    THEN N''CREATE_OBJECTS''
                    WHEN 101    THEN N''READ_OBJECTS''
                    WHEN 102    THEN N''MODIFY_OBJECTS''
                    WHEN 103    THEN N''EXECUTE_OBJECTS''
                    WHEN 104    THEN N''MANAGE_OBJECT_PERMISSIONS''
                    ELSE N''Unknown''
                END


            IF @IsDeny = 1
            BEGIN
                RAISERROR(N''    - DENYING  PermissionType: %%d - %%s'', 0, 0, @PermissionType, @permissionDesc) WITH NOWAIT;
                EXEC [SSISDB].[catalog].[deny_permission] @object_type=@object_type, @object_id=@object_id, @principal_id=@principal_id, @permission_type=@PermissionType
            END
            ELSE
            BEGIN
                RAISERROR(N''    - GRANTING PermissionType: %%d - %%s'', 0, 0, @PermissionType, @permissionDesc) WITH NOWAIT;
                EXEC [SSISDB].[catalog].[grant_permission] @object_type=@object_type, @object_id=@object_id, @principal_id=@principal_id, @permission_type=@PermissionType
            END

        END
    END', 0, 0) WITH NOWAIT;
RAISERROR(N'

    SELECT
        @lastObjectType     = @ObjectType
        ,@lastObjectFolder  = @ObjectFolder
        ,@lastObjectName    = @ObjectName
        ,@lastPrincipal     = @PrincipalName

    FETCH NEXT FROM cr INTO
         @ObjectType            
        ,@ObjectFolder          
        ,@ObjectName            
        ,@PrincipalName         
        ,@GrantorPrincipalName  
        ,@PermissionType        
        ,@IsDeny                
END



CLOSE cr;
DEALLOCATE cr;', 0, 0) WITH NOWAIT;

END
GO

--GRANT EXECUTE permission on the stored procedure to [ssis_admin] role
RAISERROR(N'Granting EXECUTE permission to [ssis_admin]', 0, 0) WITH NOWAIT;
GRANT EXECUTE ON [dbo].[sp_SSISClonePermissions] TO [ssis_admin]
GO
