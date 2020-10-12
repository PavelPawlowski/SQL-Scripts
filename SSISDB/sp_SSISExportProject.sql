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
sp_SSISExportProject v 0.20 (2020-10-12)

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
    ,@destination       nvarchar(4000)  = NULL  -- Path to destination .ispac file to which the project will be exported. When not provided, then it forces @listVersion = 1
    ,@version           bigint          = NULL  -- Specifies version_lsn number of the project to be exported. When no @version or @version date is specified then he current active version is exported.
    ,@version_date      datetime2(7)    = NULL  -- Specifies version creation timestamp of the project to be exported. When no @version or @version date is specified then he current active version is exported.
    ,@listVersion       bit             = 0     -- When 1 then list of projects and versions is provided and no export is performed.
    ,@create_path       bit             = 0     --Specifies whether the path portion of the destination file should be automatically created
******************************************************* */
ALTER PROCEDURE [dbo].[sp_SSISExportProject]
    @folder             nvarchar(128)   = NULL  -- Folder name of the project to be exported
    ,@project           nvarchar(128)   = NULL  -- Project name to be exported. When not provided, then it forces @listVersion = 1
    ,@destination       nvarchar(4000)  = NULL  -- Path to destination .ispac file to which the project will be exported. When not provided, then it forces @listVersion = 1
    ,@version           bigint          = NULL  -- Specifies version_lsn number of the project to be exported. When no @version or @version date is specified then he current active version is exported.
    ,@version_date      datetime2(7)    = NULL  -- Specifies version creation timestamp of the project to be exported. When no @version or @version date is specified then he current active version is exported.
    ,@listVersion       bit             = 0     -- When 1 then list of projects and versions is provided and no export is performed.
    ,@create_path       bit             = 0     --Specifies whether the path portion of the destination file should be automatically created
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


	RAISERROR(N'sp_SSISExportProject v0.20 (2020-10-12) (C) 2019 Pavel Pawlowski', 0, 0) WITH NOWAIT;
	RAISERROR(N'================================================================' , 0, 0) WITH NOWAIT;
    RAISERROR(N'sp_SSISExportProject extracts ssisdb project to .ispac file', 0, 0) WITH NOWAIT;
    RAISERROR(N'https://github.com/PavelPawlowski/SQL-Scripts', 0, 0) WITH NOWAIT;
    RAISERROR(N'', 0, 0) WITH NOWAIT;
    

    IF @folder IS NOT NULL AND @version IS NOT NULL AND @version_date IS NOT NULL
    BEGIN
        RAISERROR(N'Only @version or @version_date can be provided at a time', 15, 0);
        SET @help = 1
    END
    
    IF @project IS NULL OR @destination IS NULL
        SET @listVersion = 1

    --help
    IF @folder IS NULL OR @help = 1
    BEGIN
        RAISERROR(N'Exports project binary data to an .ispac file quickly and effectively.
Can export any version of project stored in MSDB without explicitly activating that version as current one.

Usage:
[sp_SSISExportProject] parameters

', 0, 0) WITH NOWAIT;

        RAISERROR(N'Parameters:
    @folder             nvarchar(128)       = NULL  - Folder name of the project to be exported
    ,@project           nvarchar(128)       = NULL  - Project name to be exported
                                                      When not provided, then it forces @listVersion = 1
    ,@destination       nvarchar(4000)      = NULL  - Path to destination .ispac file to which the project will be exported.
                                                      When not provided, then it forces @listVersion = 1              
    ,@version           bigint              = NULL  - Specifies version_lsn number of the project to be exported.
                                                      Only @version or @version_date can be specified at a time.
                                                      When no @version or @version date is specified then he current active version is exported.
    ,@version_date      datetimeoffset(7)   = NULL  - Specifies version creation timestamp of the project to be exported.
                                                      Only @version or @version_date can be specified at a time.
                                                      When no @version or @version date is specified then he current active version is exported.
    ,@listVersion       bit                 = 0     - When 1 then list of projects and versions is provided and no export is performed.
                                                      When versions a relisted a command for exporting concrete version as well as command
                                                      for eventual restoring of the version in SSISDB catalog is provided.
    ,@create_path       bit                 = 0     - Specifies whether the path portion of the destination file should be automatically created

', 0, 0) WITH NOWAIT;

        RETURN;
    END


    IF @listVersion = 1
    BEGIN
        SELECT
	        f.[name]                    AS [folder_name]
	        ,p.[name]                   AS [project_name]
	        ,p.project_id               AS [project_id]
	        ,ov.object_version_lsn      AS [version]
	        ,ov.created_time            AS [version_date]
            ,ov.created_by              AS [created_by]
            ,ov.[description]           AS [description]  
            ,ov.[restored_by]           AS [restored_by]
            ,ov.[last_restored_time]    AS [last_restored_time]
	        ,CASE WHEN ov.object_version_lsn = p.object_version_lsn THEN 1 ELSE 0 END AS [is_current_version]
            ,N'sp_SSISExportProject @folder = ''' + f.[name] + N''', @project = ''' + p.[name] + N''', @version = ' + CONVERT(nvarchar(20), ov.object_version_lsn) + N', @destination = ''' + ISNULL(@destination, N'<<path_to.ispac>>') + N'''' AS [export_command]
            ,N'EXECUTE [catalog].[restore_project] @folder_name = ''' + f.[Name] + N''', @project_name = ''' + p.[name] + N''', @object_version_lsn = ' + CONVERT(nvarchar(20), ov.object_version_lsn) AS [restore_command]
        FROM internal.object_versions ov
        INNER JOIN internal.projects p ON p.project_id = ov.object_id AND ov.object_type = 20
        INNER JOIN internal.folders f ON f.folder_id = p.folder_id
        WHERE
	        f.name = @folder
            AND
            (p.name = @project OR @project IS NULL)

        ORDER BY
        f.name, p.name, ov.created_time DESC
    END
    ELSE
    BEGIN
        SELECT
	        @project_id                 = p.project_id
	        ,@version_lsn               = ov.object_version_lsn
	        ,@version_date_internal     = ov.created_time
	        ,@is_current                = CASE WHEN ov.object_version_lsn = p.object_version_lsn THEN 1 ELSE 0 END
        FROM internal.object_versions ov
        INNER JOIN internal.projects p ON p.project_id = ov.object_id AND ov.object_type = 20
        INNER JOIN internal.folders f ON f.folder_id = p.folder_id
        WHERE
	        f.name = @folder
            AND
            (p.name = @project )
            AND
            (
                (@version_date IS NULL AND @version IS NULL AND p.object_version_lsn = ov.object_version_lsn)
                OR
                (@version_date IS NOT NULL AND ov.created_time = @version_date AND @version IS NULL)
                OR
                (@version IS NOT NULL AND ov.object_version_lsn = @version AND @version_date IS NULL)
            )

        IF @project_id IS NULL
        BEGIN
            SET @dateStr = CONVERT(nvarchar(50), @version_date);

            IF (@version_date IS NOT NULL)
                RAISERROR(N'Could not find project [%s]\[%s] with version_date: %s', 15, 10, @folder, @project, @dateStr) WITH NOWAIT;
            ELSE IF (@version IS NOT NULL)
                RAISERROR(N'Could not find project [%s]\[%s] with version: %I64d', 15, 10, @folder, @project, @version) WITH NOWAIT;
            ELSE
                RAISERROR(N'Could not find project [%s]\[%s]', 15, 10, @folder, @project) WITH NOWAIT;
                
            RETURN;
        END

        RAISERROR(N'-----------------', 0, 0) WITH NOWAIT;
        RAISERROR(N'Exporting project [%s]\[%s] to file: %s', 0, 0, @folder, @project, @destination) WITH NOWAIT;

        EXECUTE [dbo].[usp_ExportProjectClr]
            @project_name			= @project
	        ,@project_id			= @project_id
	        ,@project_version		= @version_lsn
	        ,@destination_file		= @destination
            ,@create_path           = @create_path            
    END
END
GO
--GRANT EXECUTE permission on the stored procedure to [ssis_admin] role
RAISERROR(N'Granting EXECUTE permission to [ssis_admin]', 0, 0) WITH NOWAIT;
GRANT EXECUTE ON [dbo].[sp_SSISExportProject] TO [ssis_admin]
GO