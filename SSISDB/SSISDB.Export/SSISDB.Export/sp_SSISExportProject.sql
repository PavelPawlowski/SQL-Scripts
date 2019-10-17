IF NOT EXISTS(SELECT 1 FROM sys.databases where name = 'SSISDB')
BEGIN
    RAISERROR(N'SSIS Database Does not Exists', 15, 0)
    SET NOEXEC ON;
END
GO
USE [SSISDB]
GO
IF NOT EXISTS(SELECT * FROM sys.procedures WHERE object_id = OBJECT_ID('[dbo].[sp_SSISExportProject]'))
    EXEC (N'CREATE PROCEDURE [dbo].[sp_SSISExportProject] AS PRINT ''Placeholder for [dbo].[sp_SSISExportProject]''')
GO
