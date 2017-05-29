USE [SSISDB]
GO
IF NOT EXISTS(SELECT * FROM sys.procedures WHERE object_id = OBJECT_ID('[dbo].[sp_SSISResetConfiguration]'))
    EXEC (N'CREATE PROCEDURE [dbo].[sp_SSISResetConfiguration] AS PRINT ''Placeholder for [dbo].[sp_SSISResetConfiguration]''')
GO
/* ****************************************************
sp_SSISResetConfiguration v 0.20 (2017-05-29)
(C) 2016 Pavel Pawlowski

Feedback: mailto:pavel.pawlowski@hotmail.cz

License: 
    sp_SSISResetConfiguration is free to download and use for personal, educational, and internal 
    corporate purposes, provided that this header is preserved. Redistribution or sale 
    of sp_SSISResetConfiguration, in whole or in part, is prohibited without the author's express 
    written consent.

Description:
    Resets configured value for project, object or individual parameter int he project configuraiont

Parameters:
     @folder        nvarchar(128)   =       --Name of the Folder of the project to reset configuraions
    ,@project       nvarchar(128)   =       --Name of the Project to reset configuration
	,@object        nvarchar(260)   = NULL	--Comma separated list of objects which parametes should be cleared. Supports LIKE wildcards
    ,@parameter     nvarchar(max)   = NULL  --Comma separated list of parameters to be cleared. Supports LIKE wildcards
    ,@listOnly      bit             = 0     --specifies whether only list of parameters to be reset will be printed. No actual reset will happen
 ******************************************************* */
ALTER PROCEDURE [dbo].[sp_SSISResetConfiguration]
     @folder        nvarchar(128)   = NULL  --Name of the Folder of the project to reset configuraions
    ,@project       nvarchar(128)   = NULL  --Name of the Project to reset configuration
	,@object        nvarchar(260)   = NULL	--Comma separated list of objects which parametes should be cleared. Supports LIKE wildcards
    ,@parameter     nvarchar(max)   = NULL  --Comma separated list of parameters to be cleared. Supports LIKE wildcards
    ,@listOnly      bit             = 1     --specifies whether only list of parameters to be reset will be printed. No actual reset will happen
WITH EXECUTE AS 'AllSchemaOwner'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
         @src_folder_id                 bigint                  --ID of the source folder
		,@src_project_id                bigint					--ID of the source project
		,@src_project_lsn               bigint					--current source project lsn

        ,@printHelp                     bit             = 0     --Identifies whether Help should be printed (in case of no parameters provided or error)
        ,@msg                           nvarchar(max)           --Variable to hold messages
        ,@parameter_id                  bigint                  --ID of the parameter to reset
        ,@object_name                   nvarchar(260)           --name of the object being reset
        ,@parameter_name                nvarchar(128)           --name of the parameter being reset
        ,@preview                       nvarchar(128)           --variable to hold preview message
        ,@cnt                           int             = 0     --count of parameters which were reset
		,@xmlObj						xml						--variable for holding xml for parsing input parameters
		,@xmlPar						xml						--variable for holding xml for parsing input parameters


	--Table for holding list of paramters to be dropped
	CREATE TABLE #parametersToClear (
		parameter_id	bigint			NOT NULL	PRIMARY KEY CLUSTERED
		,object_name	nvarchar(128)
		,parameter_name	nvarchar(128)
	)

    --If the required input parameters are null, print help
    IF @folder IS NULL OR @project IS NULL 
        SET @printHelp = 1


	RAISERROR(N'sp_SSISResetConfiguration v0.20 (2017-05-29) (C) 2016 Pavel Pawlowski', 0, 0) WITH NOWAIT;
    RAISERROR(N'=====================================================================', 0, 0) WITH NOWAIT;

    --PRINT HELP
    IF @printHelp = 1
    BEGIN
        RAISERROR(N'Resets configuration of a Project/ObjectName/Parameter', 0, 0) WITH NOWAIT; 
        RAISERROR(N'', 0, 0) WITH NOWAIT; 
        RAISERROR(N'Usage:', 0, 0) WITH NOWAIT; 
        RAISERROR(N'[sp_SSISResetConfiguration] parameters', 0, 0) WITH NOWAIT; 
        RAISERROR(N'', 0, 0) WITH NOWAIT; 
        SET @msg = N'Parameters:
     @folder        nvarchar(128)   =       --Name of the Folder of the project to reset configuraions.
                                              Folder is required and must exist.
    ,@project       nvarchar(128)   =       --Name of the Project to reset configuration.
                                              Project is required and must exists.
	,@object        nvarchar(260)   = NULL	--Comma separated list of object names within project to reset configuration. Support LIKE wildcards
                                              Object is optional and if provided then only configuration for that prticular objects will be reset.
    ,@parameter     nvarchar(128)   = NULL  --Comma separated list of parameter names within project to reset configuration. Support LIKE wildcards
                                              Parameter is optional and if provided then only configuration for that parameter are reset
                                              When @parameter is provided and @object not, then all parameters with that particular name
                                              are reset within the project configurations.
    ,@listOnly      bit             = 0     --Specifies whether only list of parameters to be reset will be printed. 
                                              No actual reset will happen.
    '
        RAISERROR(@msg, 0, 0) WITH NOWAIT;

        RAISERROR(N'',0, 0) WITH NOWAIT; 

        RETURN;
    END

    --get source folder_id
    SELECT
        @src_folder_id = folder_id
    FROM internal.folders f
    WHERE f.name = @folder;

    --check source folder
    IF @src_folder_id IS NULL
    BEGIN
        RAISERROR(N'Source folder [%s] does not exists.', 15, 1, @folder) WITH NOWAIT;
        RETURN;
    END

    --get source project_id
    SELECT
         @src_project_id    = p.project_id
        ,@src_project_lsn   = p.object_version_lsn
    FROM [catalog].projects p
    WHERE
        p.folder_id = @src_folder_id
        AND
        p.name = @project;


    --chek source project
    IF @src_project_id IS NULL
    BEGIN
        RAISERROR(N'Project [%s]\[%s] does not exists.', 15, 2, @folder, @project) WITH NOWAIT;
        RETURN;
    END

	SET @xmlObj = N'<i>' + REPLACE(ISNULL(@object, N'%'), N',', N'</i><i>') + N'</i>';
	SET @xmlPar = N'<i>' + REPLACE(ISNULL(@parameter, N'%'), N',', N'</i><i>') + N'</i>';

	WITH ObjNames AS (
		SELECT DISTINCT
			LTRIM(RTRIM(n.value(N'.', N'nvarchar(128)'))) AS ObjectName
		FROM @xmlObj.nodes(N'i') T(N)
	),
	ParamNames AS (
		SELECT DISTINCT
			LTRIM(RTRIM(n.value(N'.', N'nvarchar(128)'))) AS ParamName
		FROM @xmlPar.nodes(N'i') T(N)
	)
	INSERT INTO #parametersToClear (
		parameter_id
        ,object_name
        ,parameter_name
	)
	SELECT DISTINCT
        parameter_id
        ,object_name
        ,parameter_name
    FROM [internal].[object_parameters] op
	INNER JOIN ObjNames o ON op.object_name LIKE o.ObjectName
	INNER JOIN ParamNames p ON op.parameter_name LIKE p.ParamName
    WHERE 
        op.project_id = @src_project_id
        AND
        op.project_version_lsn = @src_project_lsn
		AND
		op.value_set = 1

	IF NOT EXISTS(SELECT 1 FROM #parametersToClear)
	BEGIN
		RAISERROR(N'No parameters configuration exists for input parameters provided...', 0, 0) WITH NOWAIT;
		RETURN;
	END


    RAISERROR(N'', 0, 0) WITH NOWAIT;
    RAISERROR( N'Reseting configurations for project [%s]\[%s]', 0, 0, @folder, @project) WITH NOWAIT;
    SET @msg = N'-----------------------------------------' + REPLICATE('-', LEN(@folder) + LEN(@project));
    RAISERROR(@msg, 0, 0) WITH NOWAIT;
    RAISERROR(N'', 0, 0) WITH NOWAIT;

    IF (@listOnly = 0)
        SET @preview = N''
    ELSE
        SET @preview = N'PREVIEW ONLY: '

    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
    BEGIN TRAN

    DECLARE cr CURSOR FAST_FORWARD FOR
	SELECT
        parameter_id
        ,object_name
        ,parameter_name
    FROM #parametersToClear

    OPEN cr;

    FETCH NEXT FROM cr INTO @parameter_id, @object_name, @parameter_name

    WHILE @@FETCH_STATUS = 0
    BEGIN
        RAISERROR ('%sReseting configuraion of parameter [SSISDB]\[%s]\[%s]\[%s]\[%s]', 0, 0, @preview, @folder, @project, @object_name, @parameter_name) WITH NOWAIT;
        
        IF @listOnly = 0
        BEGIN
            UPDATE [internal].[object_parameters] SET
                 referenced_variable_name = NULL
                ,value_set = 0
                ,sensitive_default_value = NULL
                ,default_value = NULL
                ,base_data_type = NULL
                ,value_type = 'V'
            WHERE 
                parameter_id = @parameter_id
        END

        SET @cnt = @cnt + 1
        FETCH NEXT FROM cr INTO @parameter_id, @object_name, @parameter_name
    END

    IF @cnt = 0
    BEGIN
        RAISERROR(N'Nothing to RESET. There is no parameter matching critera passed.', 0, 0) WITH NOWAIT;
    END

    CLOSE cr;
    DEALLOCATE cr;

    COMMIT TRAN;
END
GO
--GRANT EXECUTE permission on the stored procedure to [ssis_admin] role
GRANT EXECUTE ON [dbo].[sp_SSISResetConfiguration] TO [ssis_admin]
GO
