IF NOT EXISTS(SELECT 1 FROM sys.databases where name = 'SSISDB')
BEGIN
    RAISERROR(N'SSIS Database Does not Exists', 15, 0)
    SET NOEXEC ON;
END
GO
USE [SSISDB]
GO
IF NOT EXISTS(SELECT * FROM sys.procedures WHERE object_id = OBJECT_ID('[dbo].[usp_ExportProjectClr]'))
BEGIN
    RAISERROR(N'Deploy [dbo].[usp_ExportProjectClr] prior deploying [dbo].[sp_SSISExportProject]...', 15, 0) WITH NOWAIT;
    SET NOEXEC ON;
    RETURN;
END
RAISERROR(N'Deploying [dbo].[sp_SSISExportProject]', 0, 0) WITH NOWAIT;
IF NOT EXISTS(SELECT * FROM sys.procedures WHERE object_id = OBJECT_ID('[dbo].[sp_SSISExportProject]'))
    EXEC (N'CREATE PROCEDURE [dbo].[sp_SSISExportProject] AS PRINT ''Placeholder for [dbo].[sp_SSISExportProject]''')
GO
/* ****************************************************
sp_SSISExportProject v 0.50 (2020-10-26)

Feedback: mailto:pavel.pawlowski@hotmail.cz

MIT License

Copyright (c) 2019 Pavel Pawlowski

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
    Exports a project from SSISDB into provided .ispac file

Parameters:
    @folder             nvarchar(128)   = NULL  -- Folder name of the project to be exported
    ,@project           nvarchar(128)   = NULL  -- Project name to be exported. When not provided, then it forces @listVersion = 1
    ,@destination       nvarchar(1024)  = NULL  -- Path to destination .ispac file to which the project will be exported.
    ,@fileName          nvarchar(1024)  = NULL  -- name of the file to which export
    ,@doExport          bit             = 1     -- Identifies whether export should be done. If @destination = NULL then forced to 0
    ,@version           bigint          = NULL  -- Specifies version_lsn number of the project to be exported. When no @version or @version date is specified then he current active version is exported.
    ,@versionDate      datetime2(7)    = NULL  -- Specifies version creation timestamp of the project to be exported. When no @version or @version date is specified then he current active version is exported.
    ,@listAllVersions   bit             = 0     -- When 1 then list of projects and versions is provided and no export is performed.
    ,@createPath       bit             = 0     -- Specifies whether the path portion of the destination file should be automatically created
    ,@fileExtension     nvarchar(128)   = '.ispac'  --allows specify extension for file name for example .zip as .ispac is zip in fact
    ,@folderInFileName  bit             = 0     -- Specifies if folder should be part of file name
******************************************************* */
ALTER PROCEDURE [dbo].[sp_SSISExportProject]
    @folder             nvarchar(128)   = NULL  -- Folder name of the project to be exported
    ,@project           nvarchar(128)   = '%'  -- Project name to be exported. When not provided, then it forces @listVersion = 1
    ,@destination       nvarchar(1024)  = NULL  -- Path to destination .ispac file to which the project will be exported.
    ,@fileName          nvarchar(1024)  = NULL  -- name of the file to which export
    ,@doExport          bit             = 1     -- Identifies whether export should be done. If @destination = NULL then forced to 0
    ,@version           bigint          = NULL  -- Specifies version_lsn number of the project to be exported. When no @version or @version date is specified then he current active version is exported.
    ,@versionDate      datetime2(7)    = NULL  -- Specifies version creation timestamp of the project to be exported. When no @version or @version date is specified then he current active version is exported.
    ,@listAllVersions   bit             = 0     -- When 1 then list of projects and versions is provided and no export is performed.
    ,@createPath       bit             = 0     -- Specifies whether the path portion of the destination file should be automatically created
    ,@fileExtension     nvarchar(128)   = '.ispac'  --allows specify extension for file name for example .zip as .ispac is zip in fact
    ,@folderInFileName  bit             = 0     -- Specifies if folder should be part of file name
WITH EXECUTE AS 'AllSchemaOwner'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @project_id                 bigint
        ,@version_lsn               bigint
        ,@version_date_internal     datetimeoffset(7)
        ,@is_current                bit
        ,@dateStr                   nvarchar(50)
        ,@help                      bit                     = 0
        ,@xml                       xml
        ,@multiFolder               bit                     = 0


    DECLARE @folders TABLE (
        folder_id       bigint          PRIMARY KEY CLUSTERED
        ,folder_name    nvarchar(128)
    )


    DECLARE @projects TABLE (
        project_id          bigint          PRIMARY KEY CLUSTERED
        ,folder_id          bigint
        ,object_version_lsn bigint
        ,project_name       nvarchar(128)
    )

    DECLARE @versions TABLE (
	    [folder_name]           nvarchar(128),
	    [project_name]          nvarchar(128),
	    [project_id]            bigint,
	    [version]               bigint,
	    [version_date]          datetimeoffset(7),
	    [version_valid_to]      datetimeoffset(7),
	    [created_by]            nvarchar(128),
	    [description]           nvarchar(1024),
	    [restored_by]           nvarchar(128),
	    [last_restored_time]    datetimeoffset(7),
	    [is_current_version]    int,
	    [destination_path]      nvarchar(1154),
	    [destination_file]      nvarchar(1024)
    ) 



	RAISERROR(N'sp_SSISExportProject v0.50 (2020-10-26) (C) 2020 Pavel Pawlowski', 0, 0) WITH NOWAIT;
	RAISERROR(N'================================================================' , 0, 0) WITH NOWAIT;
    RAISERROR(N'sp_SSISExportProject extracts ssisdb project to .ispac file', 0, 0) WITH NOWAIT;
    RAISERROR(N'https://github.com/PavelPawlowski/SQL-Scripts', 0, 0) WITH NOWAIT;
    RAISERROR(N'', 0, 0) WITH NOWAIT;
    

    IF @folder IS NOT NULL AND @version IS NOT NULL AND @versionDate IS NOT NULL
    BEGIN
        RAISERROR(N'Only @version or @versionDate can be provided at a time', 15, 0);
        SET @help = 1
    END
    

    --help
    IF @folder IS NULL OR @help = 1
    BEGIN

        RAISERROR(N'Exports project binary data to an .ispac file quickly and effectively.
Can export any version of project stored in MSDB without explicitly activating that version as current one.

Usage:
[sp_SSISExportProject] parameters

', 0, 0) WITH NOWAIT;

        RAISERROR(N'Parameters:
    @folder             nvarchar(MAX)       = NULL      - Folder Name
                                                          Comma Separated list of folders including wildcards can be provided to export multiple folders/projects.
                                                          When multiple folders provided, @destination point to root extraction folder.
    ,@project           nvarchar(MAX)       = ''%%''       - Project name to be exported
                                                          Comma separated list of proceject names including wildcards can be provided to export multiple folders/projects
                                                          When not provided, then it forces @doExport = 0 and all projects are listed
    ,@destination       nvarchar(4000)      = NULL      - Path to destination .ispac file to which the project will be exported.
                                                          If multiple folders are extracted, then @destination represents root extraction folder unless @folderInFileName = 1.
                                                          .ispac files are then named by projects and stored in subfolders
                                                          When not provided, then it forces @doExport = 0
    ,@fileName          nvarchar(1024)      = NULL      - Name of the file without extension to which the project should be exported.
                                                          If multiple objects are exported then forced to NULL
                                                          When NULL then project_namec is used.
                                                          IF @listAllversions = 1 then is ignored and file is named project_name_version', 0, 0) WITH NOWAIT;
RAISERROR(N'    ,@doExport          bit                 = 1         - Specifies whether actual export should be done. When 0 then only list of versions is provided.
    ,@version           bigint              = NULL      - Specifies version_lsn number of the project to be exported.
                                                          When list of folders/projects is provided this is forced to NULL.
                                                          Only @version or @versionDate can be specified at a time.
                                                          When no @version or @version date is specified then he current active version is exported.
    ,@versionDate      datetimeoffset(7)   = NULL       - Specifies timestamp of a version. Extract version valid at the timestamp.
                                                          Only @version or @versionDate can be specified at a time.
                                                          When no @version or @version date is specified then he current active version is exported.
    ,@listAllVersions   bit                 = 0         - When 1 then list of all project versions is provided.
    ,@createPath       bit                 = 0          - Specifies whether the path portion of the destination file should be automatically created
                                                          Forced to 1 if multiple folders are extracted
    ,@fileExtension     nvarchar(128)       = ''.ispac''  - Allows specify extension for file name for example .zip as .ispac is zip in fact
    ,@folderInFileName  bit                 = 0         - Specifies if folder should be part of file name in case of multiple folders extraction.
                                                          When 1 then the filename is prefixed by folder_name_
', 0, 0) WITH NOWAIT;

        RETURN;
    END

    IF NULLIF(@project, N'') IS NULL
    BEGIN
        SET @doExport = 0
        SET @project = '%'
    END

    --Get list of folders
    SET @xml = N'<i>' + REPLACE(@folder, ',', '</i><i>') + N'</i>';

    WITH FolderNames AS (
        SELECT DISTINCT
            LTRIM(RTRIM(F.value('.', 'nvarchar(128)'))) AS FolderName
        FROM @xml.nodes(N'/i') T(F)
    )
    INSERT INTO @folders (folder_id, folder_name)
    SELECT DISTINCT
        folder_id
        ,name
    FROM internal.folders F
    INNER JOIN FolderNames  FN ON F.name LIKE FN.FolderName AND LEFT(FN.FolderName, 1) <> '-'
    EXCEPT
    SELECT
        folder_id
        ,name
    FROM internal.folders F
    INNER JOIN FolderNames  FN ON F.name LIKE RIGHT(FN.FolderName, LEN(FN.FolderName) - 1) AND LEFT(FN.FolderName, 1) = '-'


    --Get projects
    SET @xml = N'<i>' + REPLACE(@project, ',', '</i><i>') + N'</i>';
    WITH ProjectNames AS (
        SELECT DISTINCT
            LTRIM(RTRIM(F.value('.', 'nvarchar(128)'))) AS ProjectName
        FROM @xml.nodes(N'/i') T(F)
    )
    INSERT INTO @projects (project_id, folder_id, object_version_lsn, project_name)
    SELECT DISTINCT
        p.project_id
        ,p.folder_id
        ,p.object_version_lsn
        ,p.name
    FROM internal.projects p
    INNER JOIN @folders f ON f.folder_id = p.folder_id
    INNER JOIN ProjectNames PN ON p.[name] LIKE PN.ProjectName AND LEFT(PN.ProjectName, 1) <> '-'
    EXCEPT
    SELECT
        p.project_id
        ,p.folder_id
        ,p.object_version_lsn
        ,p.name
    FROM internal.projects p
    INNER JOIN @folders f ON f.folder_id = p.folder_id
    INNER JOIN ProjectNames PN ON p.[name] LIKE RIGHT(PN.ProjectName, LEN(PN.ProjectName) - 1) AND LEFT(PN.ProjectName, 1) = '-'

    --If multiple prolder
    IF (SELECT COUNT(1) FROM @folders) > 1
    BEGIN
        SET @multiFolder = 1
        SET @createPath = 1
        SET @fileName = NULL
    END

    --If there are more projects, force @version to NULL
    IF (SELECT COUNT(1) FROM @projects) > 1 
    BEGIN
        SET @version = NULL;
        SET @fileName = NULL;
    END

    --if No destination, disable export
    IF NULLIF(@destination, N'') IS NULL
        SET @doExport = 0;

    WITH ProjectVersions AS (
    SELECT
	    f.folder_name               AS [folder_name]
	    ,p.project_name             AS [project_name]
	    ,p.project_id               AS [project_id]
	    ,ov.object_version_lsn      AS [version]
	    ,ov.created_time            AS [version_date]
        ,LEAD(ov.created_time, 1, '2999-12-31') OVER(PARTITION BY ov.object_id, ov.object_type ORDER BY ov.created_time) AS [version_valid_to]
        ,ov.created_by              AS [created_by]
        ,ov.[description]           AS [description]  
        ,ov.[restored_by]           AS [restored_by]
        ,ov.[last_restored_time]    AS [last_restored_time]
	    ,CASE WHEN ov.object_version_lsn = p.object_version_lsn THEN 1 ELSE 0 END AS [is_current_version]
        ,@destination + ISNULL(NULLIF(N'\', RIGHT(@destination, 1)), N'') + CASE WHEN @multiFolder = 1 AND @folderInFileName = 0 THEN f.folder_name + N'\' ELSE N'' END  [destination_path] 
        ,CASE WHEN @multiFolder = 1 AND @folderInFileName = 1 THEN f.folder_name + N'_' ELSE N'' END +        
         CASE 
            WHEN @listAllVersions = 1 THEN p.project_name + N'_' + CONVERT(nvarchar(30), ov.object_version_lsn)
            WHEN @fileName IS NULL THEN p.project_name
            ELSE @fileName
         END                         AS [destination_file]
    FROM internal.object_versions ov
    INNER JOIN @projects p ON p.project_id = ov.object_id and ov.object_type = 20
    INNER JOIN @folders f ON f.folder_id = p.folder_id
    )
    INSERT INTO @versions (
        [folder_name]       
        ,[project_name]      
        ,[project_id]        
        ,[version]           
        ,[version_date]      
        ,[version_valid_to]  
        ,[created_by]        
        ,[description]       
        ,[restored_by]       
        ,[last_restored_time]
        ,[is_current_version]
        ,[destination_path]  
        ,[destination_file]  
    )
    SELECT
        [folder_name]       
        ,[project_name]      
        ,[project_id]        
        ,[version]           
        ,[version_date]      
        ,[version_valid_to]  
        ,[created_by]        
        ,[description]       
        ,[restored_by]       
        ,[last_restored_time]
        ,[is_current_version]
        ,[destination_path]  
        ,[destination_file]  
    FROM ProjectVersions pv
    WHERE
        @listAllVersions = 1 
        OR
        (@versionDate IS NULL AND @version IS NULL AND [is_current_version] = 1)
        OR
        (@versionDate IS NOT NULL AND @version IS NULL AND @versionDate >= [version_date] AND  @versionDate < [version_valid_to] )
        OR
        (@version IS NOT NULL AND @versionDate IS NULL AND [version] = @version)

    IF @doExport = 0
    BEGIN
        SELECT 
            [folder_name]       
            ,[project_name]      
            ,[project_id]        
            ,[version]           
            ,[version_date]      
            ,[version_valid_to]  
            ,[created_by]        
            ,[description]       
            ,[restored_by]       
            ,[last_restored_time]
            ,[is_current_version]
            --,[destination_path]  
            --,[destination_file]  
            ,N'sp_SSISExportProject @folder = ''' + [folder_name] + N''', @project = ''' + [project_name] + N''', @doExport = 1, @version = ' + CONVERT(nvarchar(20), [version]) + N', @destination = ''' + ISNULL([destination_path], N'<<path_to_file>>') + N'''' +
                N', @fileName = ''' + [destination_file] + N''', @fileExtension = ''' +  @fileExtension + N''', @createPath = ' + CONVERT(nvarchar(10), @createPath)                       
                AS [export_command]
            ,N'EXECUTE [catalog].[restore_project] @folder_name = ''' + [folder_name] + N''', @project_name = ''' + [project_name] + N''', @object_version_lsn = ' + CONVERT(nvarchar(20), [version]) AS [restore_command]
        FROM @versions
        ORDER BY
            folder_name, project_name, [version_date] DESC
    END
    ELSE
    BEGIN
        DECLARE
             @export_folder nvarchar(128)
            ,@export_project nvarchar(128)
            ,@export_project_id bigint
            ,@export_version bigint
            ,@destination_file_name nvarchar(4000)

        DECLARE cr CURSOR FAST_FORWARD FOR
        SELECT
            [folder_name]
            ,[project_name]
            ,[project_id]
            ,[version]
            ,[destination_path] + [destination_file] + @fileExtension AS [destination_file_name]
        FROM @versions

        OPEN cr;

        FETCH NEXT FROM cr INTO @export_folder, @export_project, @export_project_id, @export_version, @destination_file_name

        RAISERROR(N'-----------------', 0, 0) WITH NOWAIT;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            RAISERROR(N'Exporting project [%s]\[%s](id: %I64d, v: %I64d) to file: %s', 0, 0, @export_folder, @export_project, @export_project_id, @export_version, @destination_file_name) WITH NOWAIT;

            EXECUTE [dbo].[usp_ExportProjectClr]
                @project_name           = @export_project
                ,@project_id            = @export_project_id
                ,@project_version       = @export_version
                ,@destination_file      = @destination_file_name
                ,@create_path           = @createPath            

            FETCH NEXT FROM cr INTO @export_folder, @export_project, @export_project_id, @export_version, @destination_file_name
        END

    END
END
GO
--GRANT EXECUTE permission on the stored procedure to [ssis_admin] role
RAISERROR(N'Granting EXECUTE permission to [ssis_admin]', 0, 0) WITH NOWAIT;
GRANT EXECUTE ON [dbo].[sp_SSISExportProject] TO [ssis_admin]
GO