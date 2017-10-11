USE [SSISDB]
GO
IF NOT EXISTS(SELECT * FROM sys.procedures WHERE object_id = OBJECT_ID('[dbo].[sp_SSISMapEnvironment]'))
    EXEC (N'CREATE PROCEDURE [dbo].[sp_SSISMapEnvironment] AS PRINT ''Placeholder for [dbo].[sp_SSISMapEnvironment]''')
GO
/* ****************************************************
sp_SSISMapEnvironment v 0.10 (2017-05-31)
(C) 2016 Pavel Pawlowski

Feedback: mailto:pavel.pawlowski@hotmail.cz

License: 
    sp_SSISMapEnvironment is free to download and use for personal, educational, and internal 
    corporate purposes, provided that this header is preserved. Redistribution or sale 
    of sp_SSISMapEnvironment, in whole or in part, is prohibited without the author's express 
    written consent.

Description:
    Generates script to envronment variables to corresponding project/package parameter names.
    Matching is done on name and data type.

Parameters:
     @folder            nvarchar(128)   = NULL  --Name of the Folder of the project to reset configuraions
    ,@project           nvarchar(128)   = NULL  --Name of the Project to reset configuration
    ,@environment       nvarchar(128)   = NULL	--Name of the environment to be mapped
    ,@object            nvarchar(260)   = NULL	--Comma separated list of objects which parametes should be mapped. Supports LIKE wildcards. NULL Means all objects
    ,@parameter         nvarchar(max)   = NULL  --Comma separated list of parameters to be mapped. Supports LIKE wildcards. NULL Means all parameters.
    ,@environmentFolder nvarchar(128)   = NULL	--Name of the envrionment folder to be mapped. When null, then the project folder is being used
    ,@setupReference    bit             = 1		--Specifies whether reference to the Environment should be setup on the Project
    ,@PrintOnly         bit             = 1     --Indicates whether the script will be printed only or executed
 ******************************************************* */
ALTER PROCEDURE [dbo].[sp_SSISMapEnvironment]
     @folder            nvarchar(128)   = NULL  --Name of the Folder of the project to reset configuraions
    ,@project           nvarchar(128)   = NULL  --Name of the Project to reset configuration
    ,@environment       nvarchar(128)   = NULL	--Name of the environment to be mapped
    ,@object            nvarchar(260)   = NULL	--Comma separated list of objects which parametes should be cleared. Supports LIKE wildcards
    ,@parameter         nvarchar(max)   = NULL  --Comma separated list of parameters to be cleared. Supports LIKE wildcards
    ,@environmentFolder nvarchar(128)   = NULL	--Name of the envrionment folder to be mapped. When null, then the project folder is being used
    ,@setupReference    bit             = 1     --Specifies whether reference to the Environment should be setup on the Project
    ,@PrintOnly         bit             = 1     --Indicates whether the script will be printed only or executed
WITH EXECUTE AS 'AllSchemaOwner'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
         @src_folder_id                 bigint                  --ID of the source folder
		,@src_project_id                bigint					--ID of the source project
		,@src_project_lsn               bigint					--current source project lsn
        ,@env_folder_id                 bigint                  --ID of the environment folder
        ,@env_id                        bigint                  --ID of the environment
        ,@env_folder_name               nvarchar(128)           --name of the environment folder 
        ,@maxLen                        int                     --max len of names for printing purposes
        ,@printHelp                     bit             = 0     --Identifies whether Help should be printed (in case of no parameters provided or error)
        ,@msg                           nvarchar(max)           --Variable to hold messages
        ,@sql                           nvarchar(max)           --Variable to hold dynamic SQL statements
        ,@object_name                   nvarchar(260)           --name of the object being reset
        ,@object_type                   smallint                --Object type for the purpose of scripting
        ,@parameter_name                nvarchar(128)           --name of the parameter being reset
		,@xmlObj						xml						--variable for holding xml for parsing input parameters
		,@xmlPar						xml						--variable for holding xml for parsing input parameters
        ,@headerPrefix                  nvarchar(20)    = N'RAISERROR(N'''
        ,@headerSuffix                  nvarchar(20)    = N''', 0, 0) WITH NOWAIT' 

	--Table for holding list of paramters to be dropped
	CREATE TABLE #parametersToMap (
         parameter_id           bigint          NOT NULL	PRIMARY KEY CLUSTERED
        ,object_name	        nvarchar(128)
        ,object_type            smallint
        ,parameter_name	        nvarchar(128)
        ,parameter_data_type    nvarchar(128)
        ,sensitive              bit
        ,variable_name          nvarchar(128)
	)

    SET @env_folder_name = ISNULL(@environmentFolder, @folder);

    --If the required input parameters are null, print help
    IF @folder IS NULL OR @project IS NULL  OR @environment IS NULL
    BEGIN
        SELECT
            @printHelp = 1
            ,@headerPrefix = N''
            ,@headerSuffix = N''    
    END

    
	RAISERROR(N'%ssp_SSISMapEnvironment v0.10 (2017-05-29) (C) 2016 Pavel Pawlowski%s', 0, 0, @headerPrefix, @headerSuffix) WITH NOWAIT;
    RAISERROR(N'%s=================================================================%s', 0, 0, @headerPrefix, @headerSuffix) WITH NOWAIT;

    --PRINT HELP
    IF @printHelp = 1
    BEGIN
        RAISERROR(N'Maps Project/Object configuraiton parameters to corresponding Environment variables', 0, 0) WITH NOWAIT; 
        RAISERROR(N'Mapping is done on parameter and variable name as well as data type.', 0, 0) WITH NOWAIT; 
        RAISERROR(N'', 0, 0) WITH NOWAIT; 
        RAISERROR(N'Usage:', 0, 0) WITH NOWAIT; 
        RAISERROR(N'[sp_SSISMapEnvironment] parameters', 0, 0) WITH NOWAIT; 
        RAISERROR(N'', 0, 0) WITH NOWAIT; 
        SET @msg = N'Parameters:
     @folder            nvarchar(128)   =       --Name of the Folder of the project to reset configuraions.
                                                  Folder is required and must exist.
    ,@project           nvarchar(128)   =       --Name of the Project to reset configuration.
                                                  Project is required and must exists.
    ,@environment       nvarchar(128)   = NULL	--Name of the environment to be mapped
	,@object            nvarchar(260)   = NULL	--Comma separated list of object names within project to include in matching. Supports LIKE wildcards
                                                  Object is optional and if provided then only matching for that prticular objects will be done.
    ,@parameter         nvarchar(128)   = NULL  --Comma separated list of parameter names within project to include in matching. Supports LIKE wildcards
                                                  Parameter is optional and if provided then only matching for that parameters will be done
                                                  When @parameter is provided and @object not, then all parameters with that particular name
                                                  are are include in matching.
    ,@environmentFolder nvarchar(128)   = NULL	--Name of the envrionment folder to be mapped. When null, then the project folder is being used
                                                  Also when NULL then eventual Reference is created as reference to local environment.
                                                  If Provided then the reference to a 
    ,@setupReference    bit             = 1     --Specifies whether reference to the Environment should be setup on the Project
    ,@PrintOnly         bit             = 1     --Indicates whether the script will be printed only or printed and executed                                                
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

    --get environment folder
    SELECT
        @env_folder_id = folder_id
    FROM internal.folders f
    WHERE f.name = @env_folder_name;

    --check source folder
    IF @env_folder_id IS NULL
    BEGIN
        RAISERROR(N'Environment folder [%s] does not exists.', 15, 1, @env_folder_name) WITH NOWAIT;
        RETURN;
    END

    --get environment id
    SELECT
        @env_id = environment_id
    FROM internal.environments e
    WHERE
        e.folder_id = @env_folder_id
        AND
        e.environment_name = @environment


    IF @env_id IS NULL
    BEGIN
        RAISERROR(N'Environment [%s]\[%s] does not exists.', 15, 1, @env_folder_name, @environment) WITH NOWAIT;
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
    INSERT INTO #parametersToMap (
         parameter_id
        ,object_name
        ,object_type
        ,parameter_name
        ,parameter_data_type
        ,sensitive
    )
	SELECT DISTINCT
         parameter_id
        ,object_name
        ,object_type
        ,parameter_name
        ,parameter_data_type
        ,sensitive
    FROM [internal].[object_parameters] op
    INNER JOIN ObjNames o ON op.object_name LIKE o.ObjectName
    INNER JOIN ParamNames p ON op.parameter_name LIKE p.ParamName
    WHERE 
        op.project_id = @src_project_id
        AND
        op.project_version_lsn = @src_project_lsn


	IF NOT EXISTS(SELECT 1 FROM #parametersToMap)
	BEGIN
		RAISERROR(N'--No parameters for mapping matching input criteria...', 0, 0) WITH NOWAIT;
		RETURN;
	END

    UPDATE pm SET
        variable_name = ev.name
    FROM #parametersToMap pm
    INNER JOIN internal.environment_variables ev ON
        pm.parameter_name COLLATE database_default = ev.name COLLATE database_default
        AND
        pm.parameter_data_type COLLATE database_default = ev.type COLLATE database_default
        AND
        pm.sensitive = ev.sensitive
    WHERE
    ev.environment_id = @env_id


    IF NOT EXISTS(SELECT 1 FROM #parametersToMap WHERE variable_name IS NOT NULL)
    BEGIN
        RAISERROR(N'Environment [%s]\[%s] does not contain any variable matching parameters specified by input criteria.', 0, 0, @env_folder_name, @environment) WITH NOWAIT;
        RETURN;
    END

    SET @maxLen = LEN(@folder);
    IF LEN(@project) > @maxLen
        SET @maxLen = LEN(@project);
    IF LEN(@environment) > @maxLen
        SET @maxLen = LEN(@environment);
    IF LEN(@environmentFolder) > @maxLen
        SET @maxLen = LEN(@environmentFolder);

    SET @maxLen = @maxLen + 2


    RAISERROR(N'', 0, 0) WITH NOWAIT;
    SET @msg = N'DECLARE @folder             nvarchar(128) = N''%s''' + SPACE(@maxLen - LEN(@folder)) +   N'--Update for appropriate folder name'
    RAISERROR(@msg, 0, 0, @folder) WITH NOWAIT;
    SET @msg = N'DECLARE @project            nvarchar(128) = N''%s''' + SPACE(@maxLen - LEN(@project)) +   N'--Update for appropriate project name'
    RAISERROR(@msg, 0, 0, @project) WITH NOWAIT;

    IF @setupReference = 1
    BEGIN
        IF @environmentFolder IS NULL
        BEGIN
            SET @msg = N'DECLARE @environmentFolder  nvarchar(128) = NULL' + SPACE(@maxLen - 1) +   N'--Update for appropriate folder name';
            RAISERROR(@msg, 0, 0) WITH NOWAIT;
        END
        ELSE
        BEGIN
            SET @msg = N'DECLARE @environmentFolder  nvarchar(128) = N''%s''' + SPACE(@maxLen - LEN(@environmentFolder)) +   N'--Update for appropriate folder name'
            RAISERROR(@msg, 0, 0, @environmentFolder) WITH NOWAIT;
        END
        SET @msg = N'DECLARE @environment        nvarchar(128) = N''%s''' + SPACE(@maxLen - LEN(@environment)) +   N'--Update for appropriate environment name'
        RAISERROR(@msg, 0, 0, @environment) WITH NOWAIT;
    END


    RAISERROR(N'', 0, 0) WITH NOWAIT;
    RAISERROR(N'', 0, 0) WITH NOWAIT;
    RAISERROR( N'RAISERROR(N''Setting Environment and Parameter references for project [%%s]\[%%s]'', 0, 0, @folder, @project) WITH NOWAIT', 0, 0) WITH NOWAIT;
    SET @msg = N'RAISERROR(N''--------------------------------------------------------------' + REPLICATE('-', LEN(@folder) + LEN(@project)) + N''', 0, 0) WITH NOWAIT' ;
    RAISERROR(@msg, 0, 0) WITH NOWAIT;

    IF @setupReference = 1
    BEGIN
        RAISERROR(N'', 0, 0) WITH NOWAIT;

        RAISERROR( N'RAISERROR(N''Setting Environment reference...'', 0, 0) WITH NOWAIT', 0, 0) WITH NOWAIT;

        RAISERROR(N'DECLARE @reference_id bigint', 0, 0) WITH NOWAIT;
        RAISERROR(N'IF @environmentFolder IS NULL AND NOT EXISTS(SELECT 1 FROM [SSISDB].[catalog].[environment_references] WHERE environment_folder_name IS NULL AND environment_name = @environment)', 0, 0) WITH NOWAIT;
        RAISERROR(N'    EXEC [SSISDB].[catalog].[create_environment_reference] @environment_name=@environment, @reference_id=@reference_id OUTPUT, @project_name=@project, @folder_name=@folder, @reference_type=''R''', 0, 0) WITH NOWAIT;
        RAISERROR(N'ELSE IF @environmentFolder IS NOT NULL AND NOT EXISTS(SELECT 1 FROM [SSISDB].[catalog].[environment_references] WHERE environment_folder_name=@environmentFolder AND environment_name = @environment)', 0, 0) WITH NOWAIT;
        RAISERROR(N'    EXEC [SSISDB].[catalog].[create_environment_reference] @environment_name=@environment, @environment_folder_name=@environmentFolder, @reference_id=@reference_id OUTPUT, @project_name=@project, @folder_name=@folder, @reference_type=''A''', 0, 0) WITH NOWAIT;
    END

    RAISERROR(N'', 0, 0) WITH NOWAIT;

    DECLARE cr CURSOR FAST_FORWARD FOR
    SELECT
         object_name
        ,object_type
        ,parameter_name
    FROM #parametersToMap 
    WHERE variable_name IS NOT NULL

    OPEN cr;

    FETCH NEXT FROM cr INTO @object_name, @object_type, @parameter_name

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @object_name = @project
            RAISERROR(N'RAISERROR(N''Setting mapping for Parameter [%%s]\[%%s]\[%%s]\[%s]'', 0, 0, @folder, @project, @project) WITH NOWAIT', 0, 0, @parameter_name) WITH NOWAIT;
        ELSE
            RAISERROR(N'RAISERROR(N''Setting mapping for Parameter [%%s]\[%%s]\[%s]\[%s]'', 0, 0, @folder, @project) WITH NOWAIT', 0, 0, @object_name, @parameter_name) WITH NOWAIT;

        IF @object_name = @project
        BEGIN
            SET @msg = 'EXEC [SSISDB].[catalog].[set_object_parameter_value] @object_type=' + CONVERT(nvarchar(10), @object_type) + N', @parameter_name=N''' + @parameter_name + N'''' +
                N', @object_name=@project, @folder_name=@folder, @project_name=@project' + N', @value_type=N''R'', @parameter_value=N''' + @parameter_name + N''''
        END
        ELSE
        BEGIN
            SET @msg = 'EXEC [SSISDB].[catalog].[set_object_parameter_value] @object_type=' + CONVERT(nvarchar(10), @object_type) + N', @parameter_name=N''' + @parameter_name + N'''' +
                N', @object_name=N''' + @object_name + N'''' + N', @folder_name=@folder, @project_name=@project' + N', @value_type=N''R'', @parameter_value=N''' + @parameter_name + N''''
        END

        RAISERROR(@msg, 0, 0) WITH NOWAIT;

        IF @PrintOnly = 0
        BEGIN
            
            SET @sql = 'EXEC [SSISDB].[catalog].[set_object_parameter_value] @object_type=' + CONVERT(nvarchar(10), @object_type) + N', @parameter_name=N''' + @parameter_name + N'''' +
                N', @object_name=N''' + @object_name + N'''' + N', @folder_name=N''' + @folder + N'''' + N', @project_name=N''' + @project + N'''' + N', @value_type=N''R'', @parameter_value=N''' + @parameter_name + N''''
            EXECUTE AS CALLER;
            EXEC(@sql);
            REVERT;
        END

        RAISERROR(N'', 0, 0) WITH NOWAIT;

        FETCH NEXT FROM cr INTO @object_name, @object_type, @parameter_name
    END

    IF @PrintOnly = 0
    BEGIN
        RAISERROR(N'--*******************************', 0, 0) WITH NOWAIT;
        RAISERROR(N'--Script was executed and applied', 0, 0) WITH NOWAIT;
    END

    CLOSE cr;
    DEALLOCATE cr;
END
GO
--GRANT EXECUTE permission on the stored procedure to [ssis_admin] role
GRANT EXECUTE ON [dbo].[sp_SSISMapEnvironment] TO [ssis_admin]
GO
