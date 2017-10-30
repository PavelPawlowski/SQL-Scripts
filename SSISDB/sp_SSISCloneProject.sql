USE [SSISDB]
GO
IF NOT EXISTS(SELECT * FROM sys.procedures WHERE object_id = OBJECT_ID('[dbo].[sp_SSISCloneProject]'))
    EXEC (N'CREATE PROCEDURE [dbo].[sp_SSISCloneProject] AS PRINT ''Placeholder for [dbo].[sp_SSISCloneProject]''')
GO
/* ****************************************************
sp_SSISCloneProject v 0.11 (2017-10-28)
(C) 2017 Pavel Pawlowski

Feedback: mailto:pavel.pawlowski@hotmail.cz

License: 
    sp_SSISCloneProject is free to download and use for personal, educational, and internal 
    corporate purposes, provided that this header is preserved. Redistribution or sale 
    of sp_SSISCloneProject, in whole or in part, is prohibited without the author's express 
    written consent.

Description:
    Clones a project or multiple projects from one or multiple folders to destination or destination folders.
    Allows clonning of projects among different servers through linked servers.
    For multi server clonning a source server has to have a linked server to destination.

Parameters:
     @sourceFolder          nvarchar(4000)  = NULL      -- Comma separated list of source folders. Supports Wildcards
    ,@sourceProject         nvarchar(4000)  = '%'       -- Comma separated list of source project names. Support wildcards
    ,@destinationFolder     nvarchar(128)   = '%'       -- Destination folder name. Support wildcards
    ,@deployToExisting      bit             = 0         -- Specifies whether to deploy new version to existing proejcts
    ,@autoCreateFolders     bit             = 0         -- Specifies whether autocreate non existing folders
    ,@infoOnly              bit             = 0         -- Specifies whether only information about procesed projects should be printed
    ,@destinationServer     nvarchar(128)   = NULL      -- Specifies denstination linked server name for cross server deployment
 ******************************************************* */
ALTER PROCEDURE [dbo].[sp_SSISCloneProject]
     @sourceFolder          nvarchar(4000)  = NULL      -- Comma separated list of source folders. Supports Wildcards
    ,@sourceProject         nvarchar(4000)  = '%'       -- Comma separated list of source project names. Support wildcards
    ,@destinationFolder     nvarchar(128)   = '%'       -- Destination folder name. Support wildcards
    ,@deployToExisting      bit             = 0         -- Specifies whether to deploy new version to existing proejcts
    ,@autoCreateFolders     bit             = 0         -- Specifies whether autocreate non existing folders
    ,@infoOnly              bit             = 0         -- Specifies whether only information about procesed projects should be printed
    ,@destinationServer     nvarchar(128)   = NULL      -- Specifies denstination linked server name for cross server deployment
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @sql                    nvarchar(max)
        ,@checkSql              nvarchar(max)
        ,@folderSql             nvarchar(max)
        ,@row_id                int
        ,@project_id            bigint
        ,@project_version_lsn   bigint
        ,@folder_name           nvarchar(128)
        ,@project_name          nvarchar(128)
        ,@msg                   nvarchar(max)
        ,@data                  varbinary(max)
        ,@xml                   xml
        ,@srcCount              int
        ,@destination_folder    nvarchar(120)
        ,@destination_project   nvarchar(128)
        ,@folder_exists         bit
        ,@project_exists        bit
        ,@destinationProject    nvarchar(128)   = '%'
        ,@printHelp             bit             = 0

    DECLARE @sourceProjects TABLE (
         row_id                 int             NOT NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED
        ,folder_id              bigint
        ,project_version_lsn    bigint
        ,project_id             bigint
        ,folder_name            nvarchar(128)
        ,project_name           nvarchar(128)
        ,project_data           varbinary(max)
    )

    DECLARE @folders TABLE (
        folder_id       bigint
        ,folder_name    nvarchar(128)
    )

    DECLARE @project_data TABLE (
        data    varbinary(max)
    )

    IF @sourceFolder IS NULL OR @sourceProject IS NULL OR @destinationFolder IS NULL
        SET @printHelp = 1

	RAISERROR(N'sp_SSISCloneProject v0.11 (2017-10-28) (C) 2017 Pavel Pawlowski', 0, 0) WITH NOWAIT;
	RAISERROR(N'===============================================================' , 0, 0) WITH NOWAIT;
    RAISERROR(N'', 0, 0) WITH NOWAIT;

    IF @printHelp = 1
    BEGIN
        RAISERROR(N'
Clones a project or multiple projects from one or multiple folders to destination or destination folders.
Allows clonning of projects among different servers through linked servers.
For multi server clonning a source server has to have a linked server to destination.
User running the stored procedure has to have appropriate permissions in SSISDB catalog

Usage:
[sp_SSISCloneProject] parameters', 0, 0) WITH NOWAIT;
RAISERROR(N'
Parameters:
     @sourceFolder          nvarchar(4000)  = NULL      - Comma separated list of source folders. Supports Wildcards
    ,@sourceProject         nvarchar(4000)  = ''%%''       - Comma separated list of source project names. Support wildcards
    ,@destinationFolder     nvarchar(128)   = ''%%''       - Destination folder name. Support wildcards
                                                          %% widcard in the destination folder behaves differently than in @sourceFolder parameter
                                                          Each occurence of the %% wildcard is replaced by corresponding source folder name.
                                                          Default value %% means the desnatination folder name is the same as source.
                                                          Wildcard can be utilized to prefix or suffix source folder names when clonning
    ,@deployToExisting      bit             = 0         - Specifies whether to deploy new version to existing proejcts.
                                                          When enabled then if destiantion project with the same name already exists, then a new version is deployed to that project
                                                          When not enabled, then an error is raised if the project with the same name exists in destination
    ,@autoCreateFolders     bit             = 0         - Specifies whether autocreate non existing folders
                                                          When enabled, destination non-existing folders are automatically created
                                                          When not enabled an error is printed in case destination folder does not exists', 0, 0) WITH NOWAIT;
RAISERROR(N'    ,@infoOnly              bit             = 0         - Specifies whether only information about procesed projects should be printed
    ,@destinationServer     nvarchar(128)   = NULL      - Specifies denstination linked server name for cross server deployment
                                                          When destination server is specified, user has to have appropriate permissions on destination server.                                                          
                                                          RPC has to be enabled for the linked server
', 0, 0) WITH NOWAIT;
    RAISERROR(N'
Wildcards:
    Wildcards are standard wildcards for the LIKE statement
    Entries prefixed with [-] (minus) symbol are excluded form results and have priority over the non excluding

', 0, 0) WITH NOWAIT;
RAISERROR(N'Samples:
-------
sp_SSISCloneProject                         - Clones all projects from all folders startring with DEV_
     @sourceFolder      = ''DEV_%%''             Destination folder names will be equal to source folder names with suffix _Copy
    ,@destinationFolder = ''%%_Copy''

sp_SSISCloneProject                         - Clones all projects except project starting with TMP from all folders startring with DEV_, but excluding all folders ending with _temp
     @sourceFolder      = ''DEV_%%,-%%_temp''     Destination folder names will be equal to source folder names
    ,@sourceProject     = ''%%,-TMP%%''           Projects will be clonned to SSISDB catalog on server represented by Linked Server TESTSRV
    ,@destinationFolder = ''%%''
    ,@destinationServer = ''TESTSRV''   

sp_SSISCloneProject                         - Clones all projects from all folders startring with DEV_ into single destination folder TestFolder
     @sourceFolder      = ''DEV_%%''             Source project names has to be unique as we are clonning to single destination folder. Otherwise error will be raised.
    ,@destinationFolder = ''TestFolder''

', 0, 0) WITH NOWAIT;
        RETURN;
    END

    IF (@infoOnly  = 1)
    BEGIN
        RAISERROR(N'<<<   Information only is printed. NO OPERATIONS ARE PERFORMED   >>>', 0, 0) WITH NOWAIT;
        RAISERROR(N'', 0, 0) WITH NOWAIT;
    END
    
    --Get Folder Names
    SET @xml = N'<i>' + REPLACE(@sourceFolder, ',', '</i><i>') + N'</i>';

    WITH FolderNames AS (
        SELECT DISTINCT
            LTRIM(RTRIM(F.value('.', 'nvarchar(128)'))) AS FolderName
        FROM @xml.nodes(N'/i') T(F)
    )
    INSERT INTO @folders (folder_id, folder_name)
    SELECT DISTINCT
        folder_id
        ,name
    FROM [catalog].folders F
    INNER JOIN FolderNames  FN ON F.name LIKE FN.FolderName AND LEFT(FN.FolderName, 1) <> '-'
    EXCEPT
    SELECT
        folder_id
        ,name
    FROM [catalog].folders F
    INNER JOIN FolderNames  FN ON F.name LIKE RIGHT(FN.FolderName, LEN(FN.FolderName) - 1) AND LEFT(FN.FolderName, 1) = '-';

    --Get Projects
    SET @xml = N'<i>' + REPLACE(@sourceProject, ',', '</i><i>') + N'</i>';
    WITH ProjectNames AS (
        SELECT DISTINCT
            LTRIM(RTRIM(F.value('.', 'nvarchar(128)'))) AS ProjectName
        FROM @xml.nodes(N'/i') T(F)
    )
    INSERT INTO @sourceProjects(folder_id, project_id, project_version_lsn, folder_name, project_name)
    SELECT DISTINCT
        F.folder_id
        ,P.project_id
        ,P.object_version_lsn
        ,F.folder_name
        ,P.name         AS project_name
    FROM [catalog].projects P
    INNER JOIN @folders F ON F.folder_id = p.folder_id
    INNER JOIN ProjectNames PN ON P.name LIKE PN.ProjectName AND LEFT(PN.ProjectName, 1) <> '-'
    EXCEPT
    SELECT
        F.folder_id
        ,P.project_id
        ,P.object_version_lsn
        ,F.folder_name
        ,P.name         AS project_name
    FROM [catalog].projects P
    INNER JOIN @folders F ON F.folder_id = p.folder_id
    INNER JOIN ProjectNames  PN ON P.name LIKE RIGHT(PN.ProjectName, LEN(PN.ProjectName) - 1) AND LEFT(PN.ProjectName, 1) = '-';


    IF NOT EXISTS(SELECT 1 FROM @sourceProjects)
    BEGIN
        RAISERROR(N'No projects are matching entered criteria...', 0, 0) WITH NOWAIT;
        RETURN
    END

    --multiple results - check destination if corresponds
    IF (SELECT COUNT(1) FROM @sourceProjects) > 1
    BEGIN
        --if Destination Project is not pattern
        IF CHARINDEX('%', @destinationProject) = 0
        BEGIN
            --If there exists multiple projects per folder then raise exception
            IF EXISTS(
                SELECT
                    folder_name
                FROM @sourceProjects
                GROUP BY folder_name
                HAVING COUNT(project_name) > 1
            )
            BEGIN
                RAISERROR(N'Multiple projects are matching source parttern, but destination is not written as pattern', 15, 0);
                RETURN;
            END        
        END
        ELSE IF CHARINDEX('%', @destinationFolder) = 0
        BEGIN
            IF EXISTS(
                SELECT
                    project_name
                FROM @sourceProjects
                GROUP BY project_name
                HAVING COUNT(1) > 1
            )
            BEGIN
                RAISERROR(N'Multiple source projects with the same name would be cloned into single folder', 15, 1);
                RETURN
            END

        END
    END

    --Build dynamic SQL to check the dstination folder and project for existence
    SET @checkSql = REPLACE(N'
        IF EXISTS(SELECT 1 FROM /*@Destination@*/catalog.folders f WHERE f.name = @destination_folder) 
            SET @folder_exists = 1
        ELSE
            SET @folder_exists = 0

        IF EXISTS(        
            SELECT
                p.project_id
            FROM /*@Destination@*/catalog.projects p
            INNER JOIN /*@Destination@*/catalog.folders f ON f.folder_id = p.folder_id
            WHERE 
                f.name = @destination_folder
                and
                p.name = @destination_project
        )
            SET @project_exists = 1    
        ELSE
            SET @project_exists = 0
    '
        , N'/*@Destination@*/'
        , ISNULL(QUOTENAME(@destinationServer) + N'.[SSISDB].', N'')
    )

    --Build dynamic SQL for creating destination folder
    SET @folderSql = REPLACE(N'EXEC /*@Destination@*/catalog.create_folder @destination_folder', N'/*@Destination@*/', ISNULL(QUOTENAME(@destinationServer) + N'.[SSISDB].', N''))

    --Build dynamic SQL for deploying SSIS project to destination folder
    SET @sql = REPLACE(N'EXEC /*@Destination@*/catalog.deploy_project @folder_name = @destination_folder, @project_name = @destination_project, @project_stream = @data', N'/*@Destination@*/', ISNULL(QUOTENAME(@destinationServer) + N'.[SSISDB].', N''))

    --Cursor for iteration through proejcts
    DECLARE spc CURSOR FAST_FORWARD FOR
    SELECT
        row_id
        ,project_id
        ,project_version_lsn
        ,folder_name
        ,project_name    
    FROM @sourceProjects

    OPEN spc;

    FETCH NEXT FROM spc INTO @row_id, @project_id, @project_version_lsn, @folder_name, @project_name

    WHILE @@FETCH_STATUS = 0
    BEGIN    
        --Reset variables
        SELECT
            @data                   = NULL

        SET @msg = CONVERT(nvarchar(30), SYSDATETIME(), 121)
        RAISERROR(N'%s - Processing [%s]\[%s]', 0, 0,@msg, @folder_name, @project_name) WITH NOWAIT;

        --Get project binary data (ispac) content
        INSERT INTO @project_data(data)
        EXEC [catalog].get_project @folder_name, @project_name

        --Store the content in @data variable
        SELECT
            @data = data 
        FROM @project_data

        IF (@data IS NULL)
            RAISERROR('Could not retrieve project data for project [%s]\[%s]', 11, 0, @folder_name, @project_name);
        
        --get the destination folder/project by replacing the pattern with current folder/project name
        SELECT
            @destination_folder     = REPLACE(@destinationFolder, N'%', @folder_name)
            ,@destination_project   = REPLACE(@destinationProject, N'%', @project_name);

        RAISERROR(N'                            - Will Deploy to: [%s]\[%s]', 0, 0, @destination_folder, @destination_project) WITH NOWAIT;

        --Check if destination folder and project exists
        EXEC sp_executesql @checkSql, N'@destination_folder nvarchar(128), @destination_project nvarchar(128), @folder_exists bit OUTPUT, @project_exists bit OUTPUT',
            @destination_folder = @destination_folder, @destination_project = @destination_project, @folder_exists = @folder_exists OUTPUT, @project_exists = @project_exists OUTPUT

        --if project exists and @deployToExisting is not enabled, then raise exception
        IF @deployToExisting = 0 AND @project_exists = 1
        BEGIN
            RAISERROR(N'                            - Destination already exists and @deployToExisting is not enabled', 11, 0) WITH NOWAIT;
        END
        ELSE IF @folder_exists = 0 AND @autoCreateFolders = 0
        BEGIN
            RAISERROR(N'                            - Destination folder does not exists and @autoCreateFolders is not enabled', 11, 0) WITH NOWAIT;
        END
        ELSE
        BEGIN
            --If folder does not exists then create the folder
            IF @folder_exists = 0 
            BEGIN
                RAISERROR(N'                            - Creating folder: [%s]', 0, 0, @destination_folder) WITH NOWAIT;
                IF @infoOnly = 0
                BEGIN
                    EXEC sp_executesql @folderSql, N'@destination_folder nvarchar(128)', @destination_folder = @destination_folder
                END
            END
        
            RAISERROR(N'                            - Deploying project: [%s]', 0, 0, @destination_project) WITH NOWAIT;
            
            --Deploy project to destination folder
            IF @infoOnly = 0 
            BEGIN
                EXEC sp_executesql @sql, N'@destination_folder nvarchar(128), @destination_project nvarchar(128), @data varbinary(max)',
                    @destination_folder = @destination_folder, @destination_project = @destination_project, @data = @data
            END 
        END

        FETCH NEXT FROM spc INTO @row_id, @project_id, @project_version_lsn, @folder_name, @project_name
    END

    CLOSE spc;
    DEALLOCATE spc;
END
GO
--GRANT EXECUTE permission on the stored procedure to [ssis_admin] role
GRANT EXECUTE ON [dbo].[sp_SSISCloneProject] TO [ssis_admin]
GO
