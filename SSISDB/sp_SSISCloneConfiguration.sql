USE [SSISDB]
GO
IF NOT EXISTS(SELECT * FROM sys.procedures WHERE object_id = OBJECT_ID('[dbo].[sp_SSISCloneConfiguration]'))
    EXEC (N'CREATE PROCEDURE [dbo].[sp_SSISCloneConfiguration] AS PRINT ''Placeholder for [dbo].[sp_SSISCloneConfiguration]''')
GO
/* ****************************************************
sp_SSISCloneConfiguration v 0.50 (2017-10-28)
(C) 2017 Pavel Pawlowski

Feedback: mailto:pavel.pawlowski@hotmail.cz

License: 
    sp_SSISCloneConfiguration is free to download and use for personal, educational, and internal 
    corporate purposes, provided that this header is preserved. Redistribution or sale 
    of sp_SSISCloneConfiguration, in whole or in part, is prohibited without the author's express 
    written consent.

Description:
    Clones SSIS Project(s) Configurations.
    Allows scripting of Parameters configuration for easy transfer among environments.

Parameters:
     @folder                    nvarchar(max)   = NULL  --Comma separated list of project folders to script configurations. Suppots wildcards
    ,@project                   nvarchar(max)   = '%'   --Comma separated list of projects to script configurations. Support wildcards
	,@object                    nvarchar(max)	= '%'	--Comma separated list of source objects which parameter configuration should be clonned. Supports Wildcards.
    ,@parameter                 nvarchar(max)   = '%'   --Comma separated list of parameter names which configuration should be clonned. Supports wildcards.
    ,@destinationFolder         nvarchar(128)   = '%'   --Pattern for naming Desnation Folder. It is a default value for the script.
    ,@destinationProject		nvarchar(128)   = '%'   --Pattern for naming Desnation Project. It is a default value for the script.
    ,@decryptSensitive          bit             = 0     --Specifies whether sensitive data should be decrypted
 ******************************************************* */
ALTER PROCEDURE [dbo].[sp_SSISCloneConfiguration]
     @folder                    nvarchar(max)   = NULL  --Comma separated list of project folders to script configurations. Suppots wildcards
    ,@project                   nvarchar(max)   = '%'   --Comma separated list of projects to script configurations. Support wildcards
	,@object                    nvarchar(max)	= '%'	--Comma separated list of source objects which parameter configuration should be clonned. Supports Wildcards.
    ,@parameter                 nvarchar(max)   = '%'   --Comma separated list of parameter names which configuration should be clonned. Supports wildcards.
    ,@destinationFolder         nvarchar(128)   = '%'   --Pattern for naming Desnation Folder. It is a default value for the script.
    ,@destinationProject		nvarchar(128)   = '%'   --Pattern for naming Desnation Project. It is a default value for the script.
    ,@decryptSensitive          bit             = 0     --Specifies whether sensitive data should be decrypted
WITH EXECUTE AS 'AllSchemaOwner'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @printHelp                      bit             = 0
        ,@captionBegin                  nvarchar(50)    = N''   --Beginning of the caption for the purpose of the catpion printing
        ,@captionEnd                    nvarchar(50)    = N''   --End of the caption linef or the purpose of the caption printing
        ,@caption                       nvarchar(max)           --sp_SSISCloneEnvironment caption
        ,@xml                           xml

        ,@folder_name                   nvarchar(128)
        ,@project_name                  nvarchar(128)
        ,@object_type                   smallint				--Object type from object configuration
        ,@object_name                   nvarchar(260)			--Object name in the objects configurations
        ,@parameter_name                nvarchar(128)			--Parameter name in the objects configurations
        ,@parameter_data_type           nvarchar(128)			--Dada type of the parameter
        ,@sensitive                     bit                     --Identifies sensitive parameter
        ,@default_value                 sql_variant             
        ,@string_value                  nvarchar(4000)          
        ,@value_type                    char(1)					--Specifies the value type of the parameter (V - direct value or R - reference
        ,@referenced_variable_name      nvarchar(128)

        ,@lastFolderName                nvarchar(128)
        ,@lastProjectName               nvarchar(128)
        ,@lastObjName                   nvarchar(260)
        ,@lastObjType                   smallint
        ,@fldQuoted                     nvarchar(4000)
        ,@prjQuoted                     nvarchar(4000)
        ,@objNameQuoted                 nvarchar(4000)
        ,@paramNameQuoted               nvarchar(4000)
        ,@refVarQuoted                  nvarchar(4000)
        ,@paramValQuoted                nvarchar(max)
        ,@baseDataType                  nvarchar(128)
        ,@msg                           nvarchar(max)
        ,@valueTypeDesc                 nvarchar(10)
        ,@objectTypeDesc                nvarchar(10)

    --Table variable for holding parsed folder names list
    DECLARE @folders TABLE (
        folder_id       bigint
    )

    DECLARE @projects TABLE (
        project_id      bigint
        ,version_lsn    bigint
    )

    DECLARE @objectNames TABLE(
        object_name nvarchar(260) NOT NULL PRIMARY KEY CLUSTERED
    )
    DECLARE @paramNames TABLE(
        parameter_name nvarchar(128) NOT NULL PRIMARY KEY CLUSTERED
    )
    

    IF @folder IS NULL
        SET @printHelp = 1

	--Set and print the procedure output caption
    IF (@printHelp = 0)
    BEGIN
        SET @captionBegin = N'RAISERROR(N''';
        SET @captionEnd = N''', 0, 0) WITH NOWAIT;';
    END

	SET @caption =  @captionBegin + N'sp_SSISCloneConfiguration v0.50 (2017-10-28) (C) 2017 Pavel Pawlowski' + @captionEnd + NCHAR(13) + NCHAR(10) + 
					@captionBegin + N'=====================================================================' + @captionEnd + NCHAR(13) + NCHAR(10);
	RAISERROR(@caption, 0, 0) WITH NOWAIT;
    RAISERROR(N'', 0, 0) WITH NOWAIT;

    IF @printHelp = 1
    BEGIN
        RAISERROR(N'Clones SSIS Project configurations from one or multiple projects', 0, 0) WITH NOWAIT; 
        RAISERROR(N'Allows scripting of the configurations for easy transfer among environments.', 0, 0) WITH NOWAIT;
        RAISERROR(N'', 0, 0) WITH NOWAIT; 
        RAISERROR(N'Usage:', 0, 0) WITH NOWAIT; 
        RAISERROR(N'[sp_SSISCloneConfiguration] parameters', 0, 0) WITH NOWAIT; 
        RAISERROR(N'', 0, 0) WITH NOWAIT; 
        RAISERROR(N'Parameters:
     @folder                    nvarchar(max)   = NULL  - Comma separated list of project folders to script configurations. Suppots wildcards
                                                          Configurations for projects in matching folders will be scripted
    ,@project                   nvarchar(max)   = ''%%''   - Comma separated list of projects to script configurations. Support wildcards
                                                          Configurations for matching projects will be scripted
	,@object                    nvarchar(max)	= ''%%''   - Comma separated list of source objects which parameter configuration should be clonned. Supports Wildcards.
                                                          Configurations for matching objects will be scripted
    ,@parameter                 nvarchar(max)   = ''%%''   - Comma separated list of parameter names which configuration should be clonned. Supports wildcards.
                                                          Configurations for matching paramters will be scripted
    ,@destinationFolder         nvarchar(128)   = ''%%''   - Pattern for naming Desnation Folder. %% in the destinaton folder name is replaced by the name of the source folder.
                                                          Allows easy clonning of multiple folders by prefixing or suffixing the %% patttern
                                                          It sets the default value for the script
    ,@destinationProject		nvarchar(128)   = ''%%''   - Pattern for naming destination Project. %% in the destination project name is rpelaced by the source project name.
                                                          Allows easy clonning of multiple project configurations by prefixing or suffixing the %% pattern
                                                          It sets the default value for the script
    ,@decryptSensitive          bit             = 0     - Specifies whether sensitive data shuld be descrypted.
        ', 0, 0) WITH NOWAIT;
RAISERROR(N'
Wildcards:
    Wildcards are standard wildcards for the LIKE statement
    Entries prefixed with [-] (minus) symbol are excluded form results and have priority over the non excluding

Samples:
--------
Clone all Configurations for all projects from folders starting with ''TEST'' or ''DEV'' but exclude all folder names ending with ''Backup''
sp_SSISCloneConfiguration @folder = N''TEST%%,DEV%%,-%%Backup'' 

Clone Configurations for all projects from all folders. Script only configuraion for parameters which name starts with OLEDB_ and ends with _Password.
Sensitive values will be revealed.
sp_SSISCloneConfiguration
    @folder             = ''%%''
    ,@parameter         = ''OLEDB_%%_Password''
    ,@decryptSensitive  = 1
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
    END

    --Get list of Projects
    SET @xml = N'<i>' + REPLACE(ISNULL(@project, N'%'), ',', '</i><i>') + N'</i>';

    WITH ProjectNames AS (
        SELECT DISTINCT
            LTRIM(RTRIM(F.value('.', 'nvarchar(128)'))) AS ProjectName
        FROM @xml.nodes(N'/i') T(F)
    )
    INSERT INTO @projects (project_id, version_lsn)
    SELECT DISTINCT
        project_id
        ,object_version_lsn
    FROM [internal].[projects] P
    INNER JOIN @folders F ON F.folder_id = p.folder_id
    INNER JOIN ProjectNames PN ON P.name LIKE PN.ProjectName AND LEFT(PN.ProjectName, 1) <> '-'
    EXCEPT
    SELECT
        project_id
        ,object_version_lsn
    FROM [internal].[projects] P
    INNER JOIN @folders F ON F.folder_id = p.folder_id
    INNER JOIN ProjectNames PN ON P.name LIKE RIGHT(PN.ProjectName, LEN(PN.ProjectName) - 1) AND LEFT(PN.ProjectName, 1) = '-'

    IF NOT EXISTS(SELECT 1 FROM @projects)
    BEGIN
        RAISERROR(N'No Project matching [%s] exists in folders matching [%s]', 15, 2, @project, @folder) WITH NOWAIT;
        RETURN;
    END

    --Get list of ObjectNames
    SET @xml = N'<i>' + REPLACE(ISNULL(@object, N'%'), ',', '</i><i>') + N'</i>';

    WITH ObjectNames AS (
        SELECT DISTINCT
            LTRIM(RTRIM(F.value('.', 'nvarchar(128)'))) AS object_name
        FROM @xml.nodes(N'/i') T(F)
    )
    INSERT INTO @objectNames (object_name)
    SELECT DISTINCT
        OP.object_name
    FROM [internal].[object_parameters] OP
    INNER JOIN @projects P ON P.project_id = OP.project_id AND P.version_lsn = OP.project_version_lsn
    INNER JOIN ObjectNames N ON OP.object_name LIKE N.object_name AND LEFT(N.object_name, 1) <> '-'
    EXCEPT
    SELECT DISTINCT
        OP.object_name
    FROM [internal].[object_parameters] OP
    INNER JOIN @projects P ON P.project_id = OP.project_id AND P.version_lsn = OP.project_version_lsn
    INNER JOIN ObjectNames N ON OP.object_name LIKE RIGHT(N.object_name, LEN(N.object_name) - 1) AND LEFT(N.object_name, 1) = '-'

    IF NOT EXISTS(SELECT 1 FROM @objectNames)
    BEGIN
        RAISERROR(N'No Objects matching [%s] exists in Projects matching [%s] and folders matching [%s]', 15, 2, @object, @project, @folder) WITH NOWAIT;
        RETURN;
    END

    --Get list of ParameterNames
    SET @xml = N'<i>' + REPLACE(ISNULL(@parameter, N'%'), ',', '</i><i>') + N'</i>';

    WITH ParamNames AS (
        SELECT DISTINCT
            LTRIM(RTRIM(F.value('.', 'nvarchar(128)'))) AS parameter_name
        FROM @xml.nodes(N'/i') T(F)
    )
    INSERT INTO @paramNames (parameter_name)
    SELECT DISTINCT
        OP.parameter_name
    FROM [internal].[object_parameters] OP
    INNER JOIN @projects P ON P.project_id = OP.project_id AND P.version_lsn = OP.project_version_lsn
    INNER JOIN ParamNames N ON OP.parameter_name LIKE N.parameter_name AND LEFT(N.parameter_name, 1) <> '-'
    EXCEPT
    SELECT DISTINCT
        OP.parameter_name
    FROM [internal].[object_parameters] OP
    INNER JOIN @projects P ON P.project_id = OP.project_id AND P.version_lsn = OP.project_version_lsn
    INNER JOIN ParamNames N ON OP.parameter_name LIKE RIGHT(N.parameter_name, LEN(N.parameter_name) - 1) AND LEFT(N.parameter_name, 1) = '-';

    IF NOT EXISTS(SELECT 1 FROM @paramNames)
    BEGIN
        RAISERROR(N'No Parameters matching [%s] exists in Projects matching [%s] and folders matching [%s]', 15, 2, @parameter, @project, @folder) WITH NOWAIT;
        RETURN;
    END

    IF NOT EXISTS (
        SELECT
            1
        FROM [internal].[object_parameters] OP
        INNER JOIN [internal].[projects] PRJ ON PRJ.project_id = OP.project_id AND PRJ.object_version_lsn= OP.project_version_lsn
        INNER JOIN [internal].[folders] F ON f.folder_id = PRJ.folder_id
        INNER JOIN @projects P ON P.project_id = OP.project_id AND p.version_lsn = OP.project_version_lsn
        INNER JOIN @objectNames N ON OP.object_name = N.object_name
        INNER JOIN @paramNames PN ON OP.parameter_name = PN.parameter_name
        WHERE
            op.value_set = 1
    )
    BEGIN
        RAISERROR(N'No Parameter Configuration exists matching input criteria', 15, 2, @parameter, @project, @folder) WITH NOWAIT;
        RETURN;
    END

    --Process the parameter configurations
    DECLARE cr CURSOR FAST_FORWARD FOR
    WITH ParameterValues AS (
        SELECT
             F.name as folder_name
            ,PRJ.name AS project_name
            ,OP.object_type
            ,OP.object_name
            ,OP.parameter_name
            ,OP.parameter_data_type
            ,OP.sensitive
            ,CASE 
                WHEN OP.[sensitive] = 0                            THEN default_value
                WHEN OP.[sensitive] = 1 AND @decryptSensitive = 1   THEN [internal].[get_value_by_data_type](DECRYPTBYKEYAUTOCERT(CERT_ID(N'MS_Cert_Proj_' + CONVERT(nvarchar(20), OP.project_id)), NULL, OP.sensitive_default_value), OP.parameter_data_type)
                ELSE NULL
                END                        AS default_value
            ,OP.value_type
            ,OP.referenced_variable_name
        FROM [internal].[object_parameters] OP
        INNER JOIN [internal].[projects] PRJ ON PRJ.project_id = OP.project_id AND PRJ.object_version_lsn= OP.project_version_lsn
        INNER JOIN [internal].[folders] F ON f.folder_id = PRJ.folder_id
        INNER JOIN @projects P ON P.project_id = OP.project_id AND p.version_lsn = OP.project_version_lsn
        INNER JOIN @objectNames N ON OP.object_name = N.object_name
        INNER JOIN @paramNames PN ON OP.parameter_name = PN.parameter_name
        WHERE
            op.value_set = 1
    ), ParameterValuesString AS (
        SELECT
             folder_name
            ,project_name
            ,object_type
            ,object_name
            ,parameter_name
            ,parameter_data_type
            ,sensitive
            ,default_value
            ,CASE
                WHEN LOWER(parameter_data_type) = 'datetime' THEN CONVERT(nvarchar(50), default_value, 126)
                ELSE CONVERT(nvarchar(4000), default_value)
             END  AS StringValue
            ,value_type
            ,referenced_variable_name
        FROM ParameterValues
    )
    SELECT
         folder_name
        ,project_name
        ,object_type
        ,object_name
        ,parameter_name
        ,parameter_data_type
        ,sensitive
        ,default_value
        ,StringValue
        ,value_type
        ,referenced_variable_name
    FROM ParameterValuesString
    ORDER BY
        folder_name, project_name, object_type, object_name, parameter_name

    RAISERROR(N'', 0, 0) WITH NOWAIT;
    RAISERROR(N'--Global definitions:', 0, 0) WITH NOWAIT;
    RAISERROR(N'---------------------', 0, 0) WITH NOWAIT;
    RAISERROR(N'DECLARE @destinationFolder      nvarchar(128) = N''%s''     -- Specify destination folder name/wildcard', 0, 0, @destinationFolder) WITH NOWAIT;
    RAISERROR(N'DECLARE @destinationProject     nvarchar(128) = N''%s''     -- Specify destination project name/wildcard', 0, 0, @destinationProject) WITH NOWAIT;
    RAISERROR(N'', 0, 0) WITH NOWAIT;
    RAISERROR(N'', 0, 0) WITH NOWAIT;
    RAISERROR(N'--Declaration Definitions:', 0, 0) WITH NOWAIT;
    RAISERROR(N'--------------------------', 0, 0) WITH NOWAIT;
    RAISERROR(N'DECLARE
     @folder_name       nvarchar(128)
    ,@project_name      nvarchar(128)
    ,@object_type       smallint
    ,@object_name       nvarchar(260)
    ,@parameter_name    nvarchar(128)
    ,@value_type        char(1)
    ,@parameter_value   sql_variant

DECLARE @parameters TABLE (
        folder_name        nvarchar(128)
    ,project_name       nvarchar(128)
    ,object_type        smallint
    ,object_name        nvarchar(260)
    ,parameter_name     nvarchar(128)
    ,value_type         char(1)
    ,parameter_value    sql_variant
)

SET NOCOUNT ON;
', 0, 0) WITH NOWAIT;

    OPEN cr;

    FETCH NEXT FROM cr into @folder_name, @project_name, @object_type, @object_name, @parameter_name, @parameter_data_type, @sensitive, @default_value, @string_value, @value_type, @referenced_variable_name

    WHILE @@FETCH_STATUS = 0
    BEGIN
        --Quote values for printing
        SELECT
             @fldQuoted         = N'N''' + REPLACE(@folder_name, '''', '''''') + ''''
            ,@prjQuoted         = N'N''' + REPLACE(@project_name, '''', '''''') + ''''
            ,@objNameQuoted     = N'N''' + REPLACE(@object_name, '''', '''''') + ''''
            ,@paramNameQuoted   = N'N''' + REPLACE(@parameter_name, '''', '''''') + ''''
            ,@paramValQuoted    = N'N''' + REPLACE(@string_value, '''', '''''') + ''''
            ,@refVarQuoted      = N'N''' + REPLACE(@referenced_variable_name, '''', '''''') + ''''

        SELECT
            @msg                = CASE WHEN @sensitive = 0 THEN N'' WHEN @sensitive = 1 AND @decryptSensitive = 1 THEN N'    -- !! SENSITIVE !!' ELSE N'    -- !! SENSITIVE REMOVED !!! - Provide proper sensitive value' END
            ,@valueTypeDesc     = CASE WHEN @value_type = 'R' THEN N'Reference' ELSE N'Value' END
            ,@objectTypeDesc    = CASE @object_type WHEN 20 THEN N'Project' WHEN 30 THEN N'Package' ELSE N'Unknown' END

        --Different folder, generate part for folder definition
        IF @lastFolderName IS NULL OR @lastFolderName <> @folder_name
        BEGIN
            SET @lastProjectName = NULL;
            RAISERROR(N'-- =================================================================================', 0, 0) WITH NOWAIT;
            RAISERROR(N'-- Folder: %s', 0, 0, @folder_name) WITH NOWAIT;
            RAISERROR(N'-- =================================================================================', 0, 0) WITH NOWAIT;
            RAISERROR(N'SET @folder_name = REPLACE(@destinationFolder, N''%%'', %s)', 0, 0, @fldQuoted) WITH NOWAIT;
        END

        --Different Environment, generate part for environment definition
        IF @lastProjectName IS NULL OR @lastProjectName <> @project_name
        BEGIN
            SET @lastObjName = NULL;
            RAISERROR(N'-- *********************************************************************************', 0, 0) WITH NOWAIT;
            RAISERROR(N'-- Project: %s', 0, 0, @project_name) WITH NOWAIT;
            RAISERROR(N'-- *********************************************************************************', 0, 0) WITH NOWAIT;
            RAISERROR(N'SET @project_name = REPLACE(@destinationProject, ''%%'', %s)', 0, 0, @prjQuoted) WITH NOWAIT;
            RAISERROR(N'-- *********************************************************************************', 0, 0) WITH NOWAIT;
        END

        --Different Object, generate part for Object definition
        IF @lastObjName IS NULL OR @lastObjType IS NULL OR @lastObjName <> @object_name OR @lastObjType <> @object_type
        BEGIN
            IF @lastObjName IS NOT NULL
                RAISERROR(N'-- --------------------------------------------------------------------------------', 0, 0) WITH NOWAIT;
            RAISERROR(N'-- Object: %s', 0, 0, @object_name) WITH NOWAIT;
            RAISERROR(N'-- --------------------------------------------------------------------------------', 0, 0) WITH NOWAIT;
            RAISERROR(N'SET @object_name = %s', 0, 0, @objNameQuoted) WITH NOWAIT;
            RAISERROR(N'SET @object_type = %d   -- %s', 0, 0, @object_type, @objectTypeDesc) WITH NOWAIT;
            RAISERROR(N'-- --------------------------------------------------------------------------------', 0, 0) WITH NOWAIT;
        END
        ELSE
            RAISERROR(N'-- ---------------', 0, 0) WITH NOWAIT;

        
        SET @baseDataType = CONVERT(nvarchar(128), SQL_VARIANT_PROPERTY (@default_value, 'BaseType') )
        SET @baseDataType = CASE LOWER(@baseDataType)
                                WHEN 'decimal' THEN 'decimal(28, 18)'
                                ELSE LOWER(@baseDataType)
                            END

        --In case sensitive and decrypt Sensitive is false, use NULL as value
        IF @sensitive = 1 AND @decryptSensitive = 0
            SET @paramValQuoted = N'NULL';

        RAISERROR(N'SET @parameter_name     = %s', 0, 0, @paramNameQuoted) WITH NOWAIT;
        RAISERROR(N'SET @value_type         = ''%s'' --%s', 0, 0, @value_type, @valueTypeDesc) WITH NOWAIT;

        IF @value_type = 'R'
            RAISERROR(N'SET @parameter_value    = %s', 0, 0, @refVarQuoted) WITH NOWAIT;
        ELSE IF @BaseDataType = 'nvarchar'
            RAISERROR(N'SET @parameter_value    = %s;%s', 0, 0, @paramValQuoted, @msg) WITH NOWAIT;
        ELSE
            RAISERROR(N'SET @parameter_value    = CONVERT(%s, %s);%s', 0, 0, @baseDataType, @paramValQuoted, @msg) WITH NOWAIT;

        RAISERROR(N'INSERT INTO @parameters(folder_name, project_name, object_type, object_name, parameter_name, value_type, parameter_value) VALUES (@folder_name, @project_name, @object_type, @object_name, @parameter_name, @value_type, @parameter_value) ', 0, 0) WITH NOWAIT;

        SELECT
            @lastFolderName     = @folder_name
            ,@lastProjectName   = @project_name
            ,@lastObjName       = @object_name
            ,@lastObjType       = @object_type

        FETCH NEXT FROM cr into @folder_name, @project_name, @object_type, @object_name, @parameter_name, @parameter_data_type, @sensitive, @default_value, @string_value, @value_type, @referenced_variable_name
    END

    CLOSE cr;
    DEALLOCATE cr;

    --Print Runtime part for the script
    RAISERROR(N'', 0, 0) WITH NOWAIT;
    RAISERROR(N'-- =================================================================================', 0, 0) WITH NOWAIT;
    RAISERROR(N'--                                     RUNTIME', 0, 0) WITH NOWAIT;
    RAISERROR(N'-- =================================================================================', 0, 0) WITH NOWAIT;

    RAISERROR(N'DECLARE
    @lastFolderName         nvarchar(128)
    ,@lastProjectName       nvarchar(128)
    ,@lastObjectName        nvarchar(260)
    ,@lastObjectType        smallint
    ,@processFld            bit
    ,@processProject        bit
    ,@processObject         bit
    ', 0, 0) WITH NOWAIT;
RAISERROR(N'
DECLARE cr CURSOR FAST_FORWARD FOR
SELECT
     folder_name
    ,project_name
    ,object_type
    ,object_name
    ,parameter_name
    ,value_type
    ,parameter_value
FROM @parameters

OPEN cr;

FETCH NEXT FROM cr INTO @folder_name, @project_name, @object_type, @object_name, @parameter_name, @value_type, @parameter_value
WHILE @@FETCH_STATUS = 0
BEGIN', 0, 0) WITH NOWAIT;
RAISERROR(N'    IF @lastFolderName IS NULL OR @lastFolderName <> @folder_name
    BEGIN
        SET @processFld = 1
        SET @lastProjectName = NULL
        IF @lastFolderName IS NOT NULL
            RAISERROR(N''==================================================================='', 0, 0) WITH NOWAIT;

        IF NOT EXISTS(SELECT 1 FROM [SSISDB].[catalog].[folders] f WHERE f.[name] = @folder_name)
        BEGIN
            SET @processFld = 0
            RAISERROR(N''Destination folder [%%s] does not exist. Ignoring projects in folder'', 11, 0, @folder_name) WITH NOWAIT;
        END
        ELSE
        BEGIN
            RAISERROR(N''Processing folder [%%s]'', 0, 0, @folder_name) WITH NOWAIT;
        END
        RAISERROR(N''==================================================================='', 0, 0) WITH NOWAIT;
    END
', 0, 0) WITH NOWAIT;
RAISERROR(N'    IF @processFld = 1 AND (@lastProjectName IS NULL OR @lastProjectName <> @project_name)
    BEGIN
        SET @processProject = 1;
        SET @lastObjectName = NULL;
        IF @lastProjectName IS NOT NULL
            RAISERROR(N''*******************************************************************'', 0, 0) WITH NOWAIT;

        IF NOT EXISTS(
            SELECT
                1
            FROM [SSISDB].[catalog].[projects] p
            INNER JOIN [SSISDB].[catalog].[folders] f ON f.folder_id = p.folder_id
            WHERE
                f.name = @folder_name
                AND
                p.name = @project_name
        )
        BEGIN
            SET @processProject = 0;
            RAISERROR(N''Destination project [%%s]\[%%s] does not exists. Ignoring project objects'', 11, 1, @folder_name, @project_name) WITH NOWAIT;
        END
        ELSE
        BEGIN
            RAISERROR(N''Processing Project: [%%s]\[%%s]'', 0, 0, @folder_name, @project_name) WITH NOWAIT;
        END            
        RAISERROR(N''*******************************************************************'', 0, 0) WITH NOWAIT;
    END
', 0, 0) WITH NOWAIT;
RAISERROR(N'    IF @processProject = 1 AND (@lastObjectName IS NULL OR @lastObjectType IS NULL OR @lastObjectName <> @object_name OR @lastObjectType <> @object_type)
    BEGIN
        SET @processObject = 1
        IF @lastObjectName IS NOT NULL
            RAISERROR(N''-------------------------------------------------------------------'', 0, 0) WITH NOWAIT;

        IF NOT EXISTS(
            SELECT
                *
            FROM [SSISDB].[catalog].[object_parameters] op
            INNER JOIN [SSISDB].[catalog].[projects] p ON p.project_id = op.project_id
            INNER JOIN [SSISDB].[catalog].folders f ON f.folder_id = p.folder_id
            WHERE
                f.name = @folder_name
                AND
                p.name = @project_name
                AND
                op.object_name = @object_name
                AND
                op.object_type = @object_type
        )
        BEGIN
            SET @processObject = 0;
            RAISERROR(N''Destination Object [%%s]\[%%s]\[%%s] does not exists or does not have any parameters. Ignoring object parameters.'', 11, 2, @folder_name, @project_name, @object_name) WITH NOWAIT;
        END
        ELSE
        BEGIN
            RAISERROR(N''Processing Object: [%%s]\[%%s]\[%%s]'', 0, 0, @folder_name, @project_name, @object_name) WITH NOWAIT;
        END
        RAISERROR(N''-------------------------------------------------------------------'', 0, 0) WITH NOWAIT;
    END
', 0, 0) WITH NOWAIT;
RAISERROR(N'    IF @processObject = 1
    BEGIN        
        RAISERROR(N''Setting Parameter:  [%%s]\[%%s]\[%%s]\[%%s]'', 0, 0, @folder_name, @project_name, @object_name, @parameter_name) WITH NOWAIT;
        EXEC [SSISDB].[catalog].[set_object_parameter_value] @object_type = @object_type, @folder_name = @folder_name, @project_name = @project_name, @parameter_name = @parameter_name, @parameter_value = @parameter_value, @object_name=@object_name, @value_type = @value_type
    END
        
    SELECT
        @lastFolderName     = @folder_name
        ,@lastProjectName   = @project_name
        ,@lastObjectName    = @object_name
        ,@lastObjectType    = @object_type


    FETCH NEXT FROM cr INTO @folder_name, @project_name, @object_type, @object_name, @parameter_name, @value_type, @parameter_value
END

CLOSE cr;
DEALLOCATE cr;

IF EXITS(SELECT 1 FROM @parameters WHERE value_type = ''R'')
    RAISERROR(N''==================================================================='', 0, 0) WITH NOWAIT;

DECLARE fc CURSOR FAST_FORWARD FOR
SELECT DISTINCT
    folder_name
    ,project_name
FROM @parameters

OPEN fc;
FETCH NEXT FROM fc INTO @folderName, @project_name

WHILE @@FETCH_STATUS = 0
BEGIN
    RAISERROR(N''DON''''T FORGET TO SET ENVIRONMENT REFERENCES for project [%%s]\[%%s].'', 0, 0, @folder_name, @project_name) WITH NOWAIT;
    FETCH NEXT FROM fc INTO @folderName, @project_name
END

CLOSE fc;
DEALLOCATE fc;
    
', 0, 0) WITH NOWAIT;
END