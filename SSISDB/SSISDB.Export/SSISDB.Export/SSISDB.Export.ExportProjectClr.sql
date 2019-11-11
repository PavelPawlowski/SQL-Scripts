USE [SSISDB]
GO
IF (OBJECT_ID('[dbo].[usp_ExportProjectClr]') IS NOT NULL)
BEGIN
	RAISERROR(N'-Dropping [dbo].[usp_ExportProjectClr]', 0, 0) WITH NOWAIT;
	DROP PROCEDURE [dbo].[usp_ExportProjectClr]
END

PRINT '+Creating [dbo].[usp_ExportProjectClr]'
GO
/* ==========================================================================
   [dbo].[usp_ExportProjectClr]

   Exports SSIS Project to an .ispac file

   Parameters:

        @project_name			nvarchar(128)		--name of the SSIS project
	    ,@project_id			bigint				--Id of the SSIS project
	    ,@project_version		bigint				--version id of the SSIS project
	    ,@destination_file		nvarchar(4000)		--Destination file name
        ,@create_path           bit                 --Specifies whether the path portion of the destination file should be automatically created
========================================================================== */
CREATE PROCEDURE [dbo].[usp_ExportProjectClr]
    @project_name			nvarchar(128)		--name of the SSIS project
	,@project_id			bigint				--Id of the SSIS project
	,@project_version		bigint				--version id of the SSIS project
	,@destination_file		nvarchar(4000)		--Destination file name
    ,@create_path           bit                 --Specifies whether the path portion of the destination file should be automatically created
AS
EXTERNAL NAME [SSISDB.Export].[SSISDBExport].[ExportProject]
GO
GRANT EXECUTE TO [ssis_admin];
GRANT EXECUTE TO [AllSchemaOwner]