IF NOT EXISTS(SELECT 1 FROM sys.databases where name = 'SSISDB')
BEGIN
    RAISERROR(N'SSIS Database Does not Exists', 15, 0)
    SET NOEXEC ON;
END
GO
USE [SSISDB]
GO
RAISERROR('Creating procedure [dbo].[sp_SSISCloneConfiguration]', 0, 0) WITH NOWAIT;
IF NOT EXISTS(SELECT * FROM sys.procedures WHERE object_id = OBJECT_ID('[dbo].[sp_SSISCloneConfiguration]'))
    EXEC (N'CREATE PROCEDURE [dbo].[sp_SSISCloneConfiguration] AS PRINT ''Placeholder for [dbo].[sp_SSISCloneConfiguration]''')
GO
/* ****************************************************
sp_SSISCloneConfiguration v 0.66 (2017-12-07)

Feedback: mailto:pavel.pawlowski@hotmail.cz

MIT License

Copyright (c) 2017 Pavel Pawlowski

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
    Clones SSIS Project(s) Configurations.
    Allows scripting of Parameters configuration for easy transfer among environments.

Parameters:
     @folder                                nvarchar(max)   = NULL  --Comma separated list of project folders to script configurations. Supports wildcards
    ,@project                               nvarchar(max)   = '%'   --Comma separated list of projects to script configurations. Support wildcards
	,@object                                nvarchar(max)	= '%'	--Comma separated list of source objects which parameter configuration should be cloned. Supports Wildcards.
    ,@parameter                             nvarchar(max)   = '%'   --Comma separated list of parameter names which configuration should be cloned. Supports wildcards.
    ,@cloneReferences                       bit             = 1     --Specifies whether to clone References to environments
    ,@cloneReferencedEnvironments           bit             = 0     --Specifies whether to clone referenced environments
    ,@destinationFolder                     nvarchar(128)   = '%'   --Pattern for naming Destination Folder. It is a default value for the script.
    ,@destinationProject		            nvarchar(128)   = '%'   --Pattern for naming Destination Project. It is a default value for the script.
    ,@destinationEnvironment                nvarchar(128)   = '%'   --Pattern for naming destination Environments. It is a default value for the script
    ,@destinationFolderReplacements         nvarchar(max)   = NULL  -- Comma separated list of destination folder replacements. 
    ,@destinationEnvironmentReplacements    nvarchar(max)   = NULL  -- Comma separated list of destination environment replacements. 
    ,@decryptSensitive                      bit             = 0     --Specifies whether sensitive data should be decrypted
 ******************************************************* */
ALTER PROCEDURE [dbo].[sp_SSISCloneConfiguration]
     @folder                                nvarchar(max)   = NULL  --Comma separated list of project folders to script configurations. Supports wildcards
    ,@project                               nvarchar(max)   = '%'   --Comma separated list of projects to script configurations. Support wildcards
	,@object                                nvarchar(max)	= '%'	--Comma separated list of source objects which parameter configuration should be cloned. Supports Wildcards.
    ,@parameter                             nvarchar(max)   = '%'   --Comma separated list of parameter names which configuration should be cloned. Supports wildcards.
    ,@cloneReferences                       bit             = 1     --Specifies whether to clone References to environments
    ,@cloneReferencedEnvironments           bit             = 0     --Specifies whether to clone referenced environments
    ,@destinationFolder                     nvarchar(128)   = '%'   --Pattern for naming Destination Folder. It is a default value for the script.
    ,@destinationProject		            nvarchar(128)   = '%'   --Pattern for naming Destination Project. It is a default value for the script.
    ,@destinationEnvironment                nvarchar(128)   = '%'   --Pattern for naming destination Environments. It is a default value for the script
    ,@destinationFolderReplacements         nvarchar(max)   = NULL  -- Comma separated list of destination folder replacements. 
    ,@destinationEnvironmentReplacements    nvarchar(max)   = NULL  -- Comma separated list of destination environment replacements. 
    ,@decryptSensitive                      bit             = 0     --Specifies whether sensitive data should be decrypted
WITH EXECUTE AS 'AllSchemaOwner'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @printHelp                      bit             = 0
        ,@captionBegin                  nvarchar(50)    = N''   --Beginning of the caption for the purpose of the caption printing
        ,@captionEnd                    nvarchar(50)    = N''   --End of the caption line for the purpose of the caption printing
        ,@caption                       nvarchar(max)           --sp_SSISCloneEnvironment caption
        ,@xml                           xml

        ,@project_id                    bigint
        ,@folder_name                   nvarchar(128)
        ,@project_name                  nvarchar(128)
        ,@object_type                   smallint				--Object type from object configuration
        ,@object_name                   nvarchar(260)			--Object name in the objects configurations
        ,@parameter_name                nvarchar(128)			--Parameter name in the objects configurations
        ,@parameter_data_type           nvarchar(128)			--Dada type of the parameter
        ,@sensitive                     bit                     --Identifies sensitive parameter
        ,@default_value                 sql_variant             
        ,@string_value                  nvarchar(4000)          
        ,@value_type                    char(1)					--Specifies the value type of the parameter (V - direct value or R - reference)
        ,@referenced_variable_name      nvarchar(128)
        ,@reference_type                varchar(10)
        ,@environment_folder            nvarchar(128)
        ,@environment_name              nvarchar(128)
        ,@reference_id                  bigint
        ,@last_reference_id             bigint

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
        ,@sensitiveAccess               bit             = 0     --Indicates whether caller have access to senstive infomration
        ,@referenceExists               bit             = 0
        --Environment processing variables
        ,@fldDescrQuoted                nvarchar(4000)
        ,@envDescrQuoted                nvarchar(4000)
        ,@envQuoted                     nvarchar(200)
        ,@valQuoted                     nvarchar(max)
        ,@varDescrQuoted                nvarchar(4000)
        ,@varNameQuoted                 nvarchar(4000)
        ,@sensitiveDescr                nvarchar(10)
        ,@prefix                        nvarchar(10)
        ,@sensitiveInt                  int
        ,@valStr                        nvarchar(max)
        ,@FolderID                      bigint
        ,@EnvironmentID                 bigint
        ,@FolderName                    nvarchar(128)
        ,@EnvironmentName               nvarchar(128)
        ,@VariableID                    bigint
        ,@VariableName                  nvarchar(128)
        ,@VariableDescription           nvarchar(1024)
        ,@VariableType                  nvarchar(128)
        ,@Val                           sql_variant
        ,@IsSensitive                   bit
        ,@lastFolderID                  bigint          = NULL
        ,@lastEnvironmentID             bigint          = NULL
        ,@folderDescription             nvarchar(1024)
        ,@environmentDescription        nvarchar(1024)
        ,@valueDescription              nvarchar(1024)
        ,@stringval                     nvarchar(max)           --String representation of the value
        ,@environmentExists             bit             = 0

    EXECUTE AS CALLER;
        IF IS_MEMBER('ssis_sensitive_access') = 1 OR IS_MEMBER('db_owner') = 1 OR IS_SRVROLEMEMBER('sysadmin') = 1
            SET @sensitiveAccess = 1
    REVERT;

    --Table variable for holding parsed folder names list
    DECLARE @folders TABLE (
        folder_id       bigint
    )

    DECLARE @projects TABLE (
        project_id      bigint
        ,version_lsn    bigint
    )

    DECLARE @objectNames TABLE (
        object_name nvarchar(260) NOT NULL PRIMARY KEY CLUSTERED
    )
    DECLARE @paramNames TABLE (
        parameter_name nvarchar(128) NOT NULL PRIMARY KEY CLUSTERED
    )
    
    DECLARE @references TABLE (
        environment_folder  nvarchar(128)
        ,environment_name   nvarchar(128)
    )

    IF @folder IS NULL
        SET @printHelp = 1

	--Set and print the procedure output caption
    IF (@printHelp = 0)
    BEGIN
        SET @captionBegin = N'RAISERROR(N''';
        SET @captionEnd = N''', 0, 0) WITH NOWAIT;';
    END

	SET @caption =  @captionBegin + N'sp_SSISCloneConfiguration v0.66 (2017-12-07) (C) 2017 Pavel Pawlowski' + @captionEnd + NCHAR(13) + NCHAR(10) + 
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
     @folder                                nvarchar(max)   = NULL  - Comma separated list of project folders to script configurations. Supports wildcards
                                                                      Configurations for projects in matching folders will be scripted
    ,@project                               nvarchar(max)   = ''%%''   - Comma separated list of projects to script configurations. Support wildcards
                                                                      Configurations for matching projects will be scripted
	,@object                                nvarchar(max)	= ''%%''   - Comma separated list of source objects which parameter configuration should be cloned. Supports Wildcards.
                                                                      Configurations for matching objects will be scripted
    ,@parameter                             nvarchar(max)   = ''%%''   - Comma separated list of parameter names which configuration should be cloned. Supports wildcards.
                                                                      Configurations for matching parameters will be scripted
    ,@cloneReferences                       bit             = 1     - Specifies whether to clone references to environments
    ,@cloneReferencedEnvironments           bit             = 0     - Specifies whether to clone referenced environments.
                                                                      If provided then also complete referenced environments are scripted', 0, 0) WITH NOWAIT;
RAISERROR(N'    ,@destinationFolder                     nvarchar(128)   = ''%%''   - Pattern for naming Destination Folder. %% in the destination folder name is replaced by the name of the source folder.
                                                                      Allows easy cloning of multiple folders by prefixing or suffixing the %% pattern
                                                                      It sets the default value for the script
    ,@destinationProject                    nvarchar(128)   = ''%%''   - Pattern for naming destination Project. %% in the destination project name is replaced by the source project name.
                                                                      Allows easy cloning of multiple project configurations by prefixing or suffixing the %% pattern
                                                                      It sets the default value for the script
    ,@destinationEnvironment                nvarchar(128)   = ''%%''   - Pattern for naming destination Environment. %% in the destination environment name is replaced by the source environment name.                                                              
                                                                      It sets the default value for the script', 0, 0) WITH NOWAIT;
RAISERROR(N'    ,@destinationFolderReplacements         varchar(max)    = NULL  - Comma separated list of destination folder replacements. 
                                                                      Replacements are in format SourceVal1=NewVal1,SourceVal2=NewVal2
                                                                      Replacements are applied from left to right. This means if SourceVal2 is substring of NewVal1 that substring will be
                                                                      replaced by the NewVal2.
                                                                      Replacements are applied on @destinationFolder after widcards replacements.
    ,@destinationEnvironmentReplacements    nvarchar(max)   = NULL  - Comma separated list of destination environment replacements. 
                                                                      Replacements are in format OldVal1=NewVal1,OldVal2=NewVal2
                                                                      Replacements are applied from left to right. This means if OldValVal2 is substring of NewVal1 that substring will be
                                                                      replaced by the NewVal2.
                                                                      Replacements are applied on @destinationEnvironment after widcards replacements.
    ,@decryptSensitive                      bit             = 0     - Specifies whether sensitive data should be decrypted.
                                                                      Caller must be member of [db_owner] or [ssis_sensitive_access] database role or member of [sysadmin] server role
                                                                      to be able to decrypt sensitive information
        ', 0, 0) WITH NOWAIT;
RAISERROR(N'
Wildcards:
    Wildcards are standard wildcards for the LIKE statement
    Entries prefixed with [-] (minus) symbol are excluded form results and have priority over the non excluding

Samples:
--------
Clone all Configurations for all projects from folders starting with ''TEST'' or ''DEV'' but exclude all folder names ending with ''Backup''
sp_SSISCloneConfiguration @folder = N''TEST%%,DEV%%,-%%Backup'' 

Clone Configurations for all projects from all folders. Script only configuration for parameters which name starts with OLEDB_ and ends with _Password.
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
            PRJ.project_id
            ,F.name as folder_name
            ,PRJ.name AS project_name
            ,OP.object_type
            ,OP.object_name
            ,OP.parameter_name
            ,OP.parameter_data_type
            ,OP.sensitive
            ,CASE 
                WHEN OP.[sensitive] = 0                                                     THEN default_value
                WHEN OP.[sensitive] = 1 AND @decryptSensitive = 1 AND @sensitiveAccess = 1  THEN [internal].[get_value_by_data_type](DECRYPTBYKEYAUTOCERT(CERT_ID(N'MS_Cert_Proj_' + CONVERT(nvarchar(20), OP.project_id)), NULL, OP.sensitive_default_value), OP.parameter_data_type)
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
             project_id
            ,folder_name
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
         project_id
        ,folder_name
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

    RAISERROR(N'--Global definitions:', 0, 0) WITH NOWAIT;
    RAISERROR(N'---------------------', 0, 0) WITH NOWAIT;
    RAISERROR(N'DECLARE @destinationFolder                  nvarchar(128)   = N''%s''     -- Specify destination folder name/wildcard', 0, 0, @destinationFolder) WITH NOWAIT;
    RAISERROR(N'DECLARE @destinationProject                 nvarchar(128)   = N''%s''     -- Specify destination project name/wildcard', 0, 0, @destinationProject) WITH NOWAIT;
    IF @destinationFolderReplacements IS NULL
        RAISERROR(N'DECLARE @destinationFolderReplacements      nvarchar(max)   = NULL      -- Specify destination folder replacements.', 0, 0, @destinationFolderReplacements) WITH NOWAIT;
    ELSE
        RAISERROR(N'DECLARE @destinationFolderReplacements      nvarchar(max)   = N''%s''   -- Specify destination folder replacements.', 0, 0, @destinationFolderReplacements) WITH NOWAIT;
    
    IF @cloneReferences = 1 OR @cloneReferencedEnvironments = 1
        RAISERROR(N'', 0, 0) WITH NOWAIT;

    IF @cloneReferences = 1
    BEGIN
        RAISERROR(N'DECLARE @processReferences                  bit             = 1        -- Specify whether to process references', 0, 0) WITH NOWAIT;
    END

    IF @cloneReferencedEnvironments = 1
    BEGIN
        RAISERROR(N'DECLARE @processEnvironments                bit             = 1        -- Specify whether to process references', 0, 0) WITH NOWAIT;
        RAISERROR(N'DECLARE @autoCreate                         bit             = 1        -- Specify whether folder and environments should be auto-created', 0, 0) WITH NOWAIT;
        RAISERROR(N'DECLARE @overwrite                          bit             = 0        -- Specify whether value of existing variables should be overwritten', 0, 0) WITH NOWAIT;
    END

    IF @cloneReferences = 1 OR @cloneReferencedEnvironments = 1
    BEGIN
        RAISERROR(N'DECLARE @destinationEnvironment             nvarchar(128)   = N''%s''     -- Specify destination environment name/wildcard', 0, 0, @destinationProject) WITH NOWAIT;
        IF @destinationEnvironmentReplacements IS NULL
            RAISERROR(N'DECLARE @destinationEnvironmentReplacements nvarchar(max)   = NULL      -- Specify destination environment replacements.', 0, 0, @destinationEnvironmentReplacements) WITH NOWAIT;
        ELSE
            RAISERROR(N'DECLARE @destinationEnvironmentReplacements nvarchar(max)   = N''%s''   -- Specify destination environment replacements.', 0, 0, @destinationEnvironmentReplacements) WITH NOWAIT;
    END
    RAISERROR(N'', 0, 0) WITH NOWAIT;
    RAISERROR(N'', 0, 0) WITH NOWAIT;
    RAISERROR(N'--Declaration Definitions:', 0, 0) WITH NOWAIT;
    RAISERROR(N'--------------------------', 0, 0) WITH NOWAIT;
    RAISERROR(N'DECLARE
     @folder_name           nvarchar(128)
    ,@project_name          nvarchar(128)
    ,@object_type           smallint
    ,@object_name           nvarchar(260)
    ,@parameter_name        nvarchar(128)
    ,@value_type            char(1)
    ,@parameter_value       sql_variant', 0, 0) WITH NOWAIT;

    IF @cloneReferences = 1
    RAISERROR(N'    ,@reference_type        char(1)
    ,@environment_name      nvarchar(128)
    ,@environment_folder    nvarchar(128)', 0, 0) WITH NOWAIT;

    RAISERROR(N'
DECLARE @parameters TABLE (
     folder_name        nvarchar(128)
    ,project_name       nvarchar(128)
    ,object_type        smallint
    ,object_name        nvarchar(260)
    ,parameter_name     nvarchar(128)
    ,value_type         char(1)
    ,parameter_value    sql_variant
)', 0, 0) WITH NOWAIT;

IF @cloneReferences = 1
    RAISERROR(N'
DECLARE @references TABLE (
     folder_name                nvarchar(128)
    ,project_name               nvarchar(128)
    ,reference_type             char(1)
    ,environment_folder_name    nvarchar(128)
    ,environment_name           nvarchar(128)
)
', 0, 0) WITH NOWAIT;

RAISERROR(N'
SET NOCOUNT ON;
', 0, 0) WITH NOWAIT;

    OPEN cr;

    FETCH NEXT FROM cr into @project_id, @folder_name, @project_name, @object_type, @object_name, @parameter_name, @parameter_data_type, @sensitive, @default_value, @string_value, @value_type, @referenced_variable_name

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

            --log environments to be cloned
            IF @cloneReferencedEnvironments =1 
            BEGIN
                INSERT INTO @references(environment_folder, environment_name)
                SELECT
                    ISNULL(environment_folder_name, @folder_name)
                    ,environment_name
                FROM internal.environment_references
                WHERE
                    project_id = @project_id
            END

            IF @cloneReferences = 1
            BEGIN
                DECLARE rc CURSOR FAST_FORWARD FOR
                SELECT
                     reference_id
                    ,reference_type
                    ,environment_folder_name
                    ,environment_name
                FROM internal.environment_references
                WHERE project_id = @project_id

                OPEN rc;
                
                FETCH NEXT FROM rc INTO @reference_id, @reference_type, @environment_folder, @environment_name

                WHILE @@FETCH_STATUS = 0
                BEGIN
                    SET @referenceExists = 1;
                    IF @last_reference_id IS NOT NULL
                        RAISERROR(N'-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++', 0, 0) WITH NOWAIT;
                    IF @reference_type = 'A'
                        RAISERROR(N'-- Reference to environment: [%s]\[%s]', 0, 0, @environment_folder, @environment_name) WITH NOWAIT;
                    ELSE
                        RAISERROR(N'-- Reference to local environment: [%s]', 0, 0,  @environment_name) WITH NOWAIT;
                    RAISERROR(N'-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++', 0, 0) WITH NOWAIT;

                    SELECT
                         @environment_name      = N'N''' + REPLACE(@environment_name, '''', '''''') + ''''
                        ,@environment_folder    = ISNULL(N'N''' + REPLACE(@environment_folder, '''', '''''') + '''', N'NULL')
                        ,@reference_type        = N'N''' + REPLACE(@reference_type, '''', '''''') + '''';

                    RAISERROR(N'SET @environment_name   = REPLACE(@destinationEnvironment, ''%%'', %s)', 0, 0, @environment_name) WITH NOWAIT;
                    RAISERROR(N'SET @environment_folder = %s', 0, 0, @environment_folder) WITH NOWAIT;
                    RAISERROR(N'SET @reference_type     = %s', 0, 0, @reference_type) WITH NOWAIT;
                    RAISERROR(N'INSERT INTO @references(folder_name, project_name, reference_type, environment_folder_name, environment_name) VALUES (@folder_name, @project_name, @reference_type, @environment_folder, @environment_name)', 0, 0) WITH NOWAIT;
                    RAISERROR(N'-- ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++', 0, 0) WITH NOWAIT;
                    

                    SET @last_reference_id = @reference_id
                    FETCH NEXT FROM rc INTO @reference_id,@reference_type, @environment_folder, @environment_name
                END

                CLOSE rc;
                DEALLOCATE rc;
            END
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

        FETCH NEXT FROM cr into @project_id, @folder_name, @project_name, @object_type, @object_name, @parameter_name, @parameter_data_type, @sensitive, @default_value, @string_value, @value_type, @referenced_variable_name
    END

    CLOSE cr;
    DEALLOCATE cr;

    --Clone referenced environments if selected and exists
    IF @cloneReferencedEnvironments = 1 AND EXISTS(SELECT 1 FROM @references)
    BEGIN
        RAISERROR(N'', 0, 0) WITH NOWAIT;
        RAISERROR(N'-- =================================================================================', 0, 0) WITH NOWAIT;
        RAISERROR(N'--                                    ENVIRONMENTS', 0, 0) WITH NOWAIT;
        RAISERROR(N'-- =================================================================================', 0, 0) WITH NOWAIT;
        RAISERROR(N'--Declaration Definitions:', 0, 0) WITH NOWAIT;
        RAISERROR(N'--------------------------', 0, 0) WITH NOWAIT;
        RAISERROR(N'DECLARE
     @destFld       nvarchar(128)
    ,@destEnv       nvarchar(128)
    ,@fldDesc       nvarchar(1024)
    ,@envDesc       nvarchar(1024)
    ,@varName       nvarchar(128)
    ,@varDesc       nvarchar(1024)
    ,@baseDataType  nvarchar(128)
    ,@variableType  nvarchar(128)
    ,@isSensitive   bit
    ,@var           sql_variant

DECLARE @variables TABLE (
     VariableName           nvarchar(128)
    ,Value                  sql_variant
    ,IsSensitive            bit
    ,DataType               nvarchar(128)
    ,VariableDescription    nvarchar(1024)
    ,FolderName             nvarchar(128)
    ,FolderDescription      nvarchar(1024)
    ,EnvironmentName        nvarchar(128)
    ,EnvironmentDescription nvarchar(1024)
)', 0, 0) WITH NOWAIT;


        DECLARE cr CURSOR FAST_FORWARD FOR
        WITH Refs AS (
            SELECT DISTINCT
                environment_folder
                ,environment_name
            FROM @references
        ), VariableValues AS (
            SELECT
                 e.folder_id                AS FolderID
                ,e.environment_id           AS EnvironmentID
                ,ev.variable_id             AS VariableID
                ,f.name                     AS FolderName
                ,e.environment_name         AS EnvironmentName
                ,ev.[name]                  AS VariableName
                ,ev.[value] AS v
                ,ev.[sensitive_value]
                ,CASE 
                    WHEN ev.[sensitive] = 0                            THEN [value]
                    WHEN ev.[sensitive] = 1 AND @decryptSensitive = 1   THEN [internal].[get_value_by_data_type](DECRYPTBYKEYAUTOCERT(CERT_ID(N'MS_Cert_Env_' + CONVERT(nvarchar(20), ev.environment_id)), NULL, ev.[sensitive_value]), ev.[type])
                    ELSE NULL
                 END                        AS Value
                ,ev.[description]           AS VariableDescription
                ,ev.[type]                  AS VariableType
                ,ev.[base_data_type]        AS BaseDataType
                ,ev.[sensitive]             AS IsSensitive
                ,f.description              AS FolderDescription
                ,e.description              AS EnvironmentDescription
            FROM [internal].[environment_variables] ev
            INNER JOIN [internal].[environments] e ON e.environment_id = ev.environment_id
            INNER JOIN [internal].[folders] f on f.folder_id = e.folder_id
            INNER JOIN Refs r ON r.environment_folder = f.name AND r.environment_name = e.environment_name
        )
        SELECT
            FolderID
            ,EnvironmentID
            ,VariableID
            ,FolderName
            ,EnvironmentName
            ,VariableName
            ,Value
            ,CASE
                WHEN LOWER(vv.VariableType) = 'datetime' THEN CONVERT(nvarchar(50), Value, 126)
                ELSE CONVERT(nvarchar(4000), Value)
                END  AS StringValue
            ,VariableDescription
            ,VariableType
            ,BaseDataType
            ,IsSensitive
            ,FolderDescription
            ,EnvironmentDescription
        FROM VariableValues vv
        ORDER BY FolderName, EnvironmentName, VariableName

        OPEN cr;

        FETCH NEXT FROM cr INTO
             @FolderID            
            ,@EnvironmentID       
            ,@VariableID          
            ,@FolderName          
            ,@EnvironmentName     
            ,@VariableName        
            ,@Val   
            ,@stringval              
            ,@VariableDescription 
            ,@VariableType        
            ,@BaseDataType        
            ,@IsSensitive
            ,@folderDescription
            ,@environmentDescription            

        WHILE @@FETCH_STATUS = 0
        BEGIN
            --Quote string values for output
            SELECT
                 @fldQuoted         = N'N''' + REPLACE(@folderName, '''', '''''') + ''''
                ,@envQuoted         = N'N''' + REPLACE(@EnvironmentName, '''', '''''') + ''''
                ,@fldDescrQuoted    = ISNULL(N'N''' + REPLACE(@folderDescription, '''', '''''') + '''', N'NULL')
                ,@envDescrQuoted    = ISNULL(N'N''' + REPLACE(@environmentDescription, '''', '''''') + '''', N'NULL')
                ,@varDescrQuoted    = ISNULL(N'N''' + REPLACE(@VariableDescription, '''', '''''') + '''', N'NULL')
                ,@valQuoted         = ISNULL(N'N''' + REPLACE(@stringval, '''', '''''') + '''', N'NULL')
                ,@varNameQuoted     = N'N''' + REPLACE(@VariableName, '''', '''''') + ''''
                ,@VariableType      = N'N''' + REPLACE(@variableType, '''', '''''') + ''''
                ,@sensitiveInt      = CONVERT(int, @IsSensitive)


            --Different folder, generate part for folder definition
            IF @lastFolderID IS NULL OR @lastFolderID <> @FolderID
            BEGIN            
                RAISERROR(N'-- =================================================================================', 0, 0) WITH NOWAIT;
                RAISERROR(N'-- Folder: %s', 0, 0, @folderName) WITH NOWAIT;
                RAISERROR(N'-- =================================================================================', 0, 0) WITH NOWAIT;
                RAISERROR(N'SET @destFld = REPLACE(@destinationFolder, N''%%'', %s)', 0, 0, @fldQuoted) WITH NOWAIT;
                RAISERROR(N'SET @fldDesc = %s', 0, 0, @fldDescrQuoted) WITH NOWAIT;
            END

            --Different Environment, generate part for environment definition
            IF @lastEnvironmentID IS NULL OR @lastEnvironmentID <> @EnvironmentID
            BEGIN
                RAISERROR(N'-- *********************************************************************************', 0, 0) WITH NOWAIT;
                RAISERROR(N'-- Environment: %s', 0, 0, @EnvironmentName) WITH NOWAIT;
                RAISERROR(N'-- *********************************************************************************', 0, 0) WITH NOWAIT;
                RAISERROR(N'SET @destEnv = REPLACE(@destinationEnvironment, ''%%'', %s)', 0, 0, @envQuoted) WITH NOWAIT;
                RAISERROR(N'SET @envDesc = %s', 0, 0, @envDescrQuoted) WITH NOWAIT;
                RAISERROR(N'-- *********************************************************************************', 0, 0) WITH NOWAIT;
            END
            ELSE
            RAISERROR(N'-- ---------------', 0, 0) WITH NOWAIT;

            --Generate variable definition
            RAISERROR(N'SET @varName      = %s', 0, 0, @varNameQuoted) WITH NOWAIT;
            RAISERROR(N'SET @varDesc      = %s', 0, 0, @varDescrQuoted) WITH NOWAIT;

            SET @BaseDataType = CASE LOWER(@BaseDataType)
                    WHEN 'decimal' THEN 'decimal(28, 18)'
                    ELSE LOWER(@BaseDataType)
                END
        
            --In case sensitive and decrypt Sensitive is false, use NULL as value
            IF @IsSensitive = 1 AND @decryptSensitive = 0
                SET @valQuoted = N'NULL';

            SET @msg = CASE WHEN @IsSensitive = 0 THEN N'' WHEN @IsSensitive = 1 AND @decryptSensitive = 1 THEN N'    -- !! SENSITIVE !!' ELSE N'    -- !! SENSITIVE REMOVED !!! - Provide proper sensitive value' END;                 

            IF @BaseDataType = 'nvarchar'
                RAISERROR(N'SET @var          = %s;%s', 0, 0, @valQuoted, @msg) WITH NOWAIT;
            ELSE
                RAISERROR(N'SET @var          = CONVERT(%s, %s);%s', 0, 0, @BaseDataType, @valQuoted, @msg) WITH NOWAIT;

            RAISERROR(N'SET @isSensitive  = %d', 0, 0, @sensitiveInt) WITH NOWAIT;
            RAISERROR(N'SET @variableType = %s', 0, 0, @VariableType) WITH NOWAIT;
            RAISERROR(N'INSERT INTO @variables(VariableName, Value, IsSensitive , DataType, VariableDescription, FolderName, FolderDescription, EnvironmentName, EnvironmentDescription) VALUES (@varName, @var, @isSensitive, @variableType, @varDesc, @destFld, @fldDesc, @destEnv, @envDesc)', 0, 0) WITH NOWAIT;
        
            SELECT
                @lastFolderID           = @FolderID
                ,@lastEnvironmentID     = @EnvironmentID


            FETCH NEXT FROM cr INTO
                 @FolderID            
                ,@EnvironmentID       
                ,@VariableID          
                ,@FolderName          
                ,@EnvironmentName     
                ,@VariableName        
                ,@Val   
                ,@stringval              
                ,@VariableDescription 
                ,@VariableType        
                ,@BaseDataType        
                ,@IsSensitive
                ,@folderDescription
                ,@environmentDescription    

        END

        CLOSE cr;
        DEALLOCATE cr;
    
    END --IF @cloneReferencedEnvironments = 1 AND EXISTS(SELECT 1 FROM @references)


    RAISERROR(N'', 0, 0) WITH NOWAIT;
    RAISERROR(N'-- =================================================================================', 0, 0) WITH NOWAIT;
    RAISERROR(N'--                            COMMON RUNTIME', 0, 0) WITH NOWAIT;
    RAISERROR(N'-- =================================================================================', 0, 0) WITH NOWAIT;

    RAISERROR(N'
DECLARE
     @processFld            bit
    ,@lastFolderName        nvarchar(128)
    ,@fld                   nvarchar(128)
    ,@xml                   xml
    ,@msg                   nvarchar(max)
    ,@oldVal                nvarchar(128)
    ,@newVal                nvarchar(128)
    ,@error                 bit             = 0
    ', 0, 0) WITH NOWAIT;

RAISERROR(N'
--Table for holding folder replacements
DECLARE @folderReplacements TABLE (
    SortOrder       int             NOT NULL    PRIMARY KEY CLUSTERED
    ,OldValue       nvarchar(128)
    ,NewValue       nvarchar(128)
    ,Replacement    nvarchar(4000)
)', 0, 0) WITH NOWAIT;

RAISERROR(N'
--Folder Replacements
SET @xml = N''<i>'' + REPLACE(@destinationFolderReplacements, '','', ''</i><i>'') + N''</i>'';
WITH Replacements AS (
    SELECT DISTINCT
        LTRIM(RTRIM(F.value(''.'', ''nvarchar(128)''))) AS Replacement
        ,ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS Ord
    FROM @xml.nodes(N''/i'') T(F)
)
INSERT INTO @folderReplacements(SortOrder, OldValue, NewValue, Replacement)
SELECT
    Ord
    ,LEFT(Replacement, CASE WHEN CHARINDEX(''='', Replacement, 1) = 0 THEN 0 ELSE CHARINDEX(''='', Replacement, 1) - 1 END) AS OldValue
    ,RIGHT(Replacement, LEN(Replacement) - CHARINDEX(''='', Replacement, 1)) AS NewValue
    ,Replacement
FROM Replacements

IF EXISTS(SELECT 1 FROM @folderReplacements WHERE OldValue IS NULL OR OldValue = N'''')
BEGIN
    SET @msg = STUFF((SELECT N'','' + Replacement FROM @folderReplacements WHERE OldValue IS NULL OR OldValue = N'''' FOR XML PATH('''')), 1, 1, '''')
    SET @error = 1
    RAISERROR(N''Following folder replacements are not valid: %%s'', 15, 0, @msg) WITH NOWAIT;
    RETURN;
END', 0, 0) WITH NOWAIT;

IF @cloneReferences = 1 OR @cloneReferencedEnvironments = 1
BEGIN
    RAISERROR(N'
    --Table for holding environment replacements
    DECLARE @environmentReplacements TABLE (
        SortOrder       int             NOT NULL    PRIMARY KEY CLUSTERED
        ,OldValue       nvarchar(128)
        ,NewValue       nvarchar(128)
        ,Replacement    nvarchar(4000)
    )
    ', 0, 0) WITH NOWAIT;

    RAISERROR(N'
    SET @xml = N''<i>'' + REPLACE(@destinationEnvironmentReplacements, '','', ''</i><i>'') + N''</i>'';
    WITH Replacements AS (
        SELECT DISTINCT
            LTRIM(RTRIM(F.value(''.'', ''nvarchar(128)''))) AS Replacement
            ,ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS Ord
        FROM @xml.nodes(N''/i'') T(F)
    )
    INSERT INTO @environmentReplacements(SortOrder, OldValue, NewValue, Replacement)
    SELECT
        Ord
        ,LEFT(Replacement, CASE WHEN CHARINDEX(''='', Replacement, 1) = 0 THEN 0 ELSE CHARINDEX(''='', Replacement, 1) - 1 END) AS OldValue
        ,RIGHT(Replacement, LEN(Replacement) - CHARINDEX(''='', Replacement, 1)) AS NewValue
        ,Replacement
    FROM Replacements

    IF EXISTS(SELECT 1 FROM @environmentReplacements WHERE OldValue IS NULL OR OldValue = N'''')
    BEGIN
        SET @msg = STUFF((SELECT N'','' + Replacement FROM @environmentReplacements WHERE OldValue IS NULL OR OldValue = N'''' FOR XML PATH('''')), 1, 1, '''')
        SET @error = 1
        RAISERROR(N''Following environment replacements are not valid: %%s'', 15, 0, @msg) WITH NOWAIT;
        RETURN;
    END    
    ', 0, 0) WITH NOWAIT;
END

--Clone referenced environments if selected and exists
IF @cloneReferencedEnvironments = 1 AND EXISTS(SELECT 1 FROM @references)
BEGIN
    RAISERROR(N'', 0, 0) WITH NOWAIT;
    RAISERROR(N'-- =================================================================================', 0, 0) WITH NOWAIT;
    RAISERROR(N'--                            ENVIRONMENTS RUNTIME', 0, 0) WITH NOWAIT;
    RAISERROR(N'-- =================================================================================', 0, 0) WITH NOWAIT;

    RAISERROR(N'DECLARE
     @lastEnvironmentName   nvarchar(128)
    ,@processEnv            bit
    ,@env                   nvarchar(128)', 0, 0) WITH NOWAIT

RAISERROR('
RAISERROR(N'''', 0, 0) WITH NOWAIT;
RAISERROR(N''#################################################################################'', 0, 0) WITH NOWAIT;
RAISERROR(N''                       PROCESSING REFERENCED ENVIRONMENTS'', 0, 0) WITH NOWAIT;
RAISERROR(N''#################################################################################'', 0, 0) WITH NOWAIT;

DECLARE cr CURSOR FAST_FORWARD FOR
SELECT
    FolderName
    ,FolderDescription
    ,EnvironmentName
    ,EnvironmentDescription
    ,VariableName
    ,Value
    ,IsSensitive
    ,DataType
    ,VariableDescription
FROM @variables
ORDER BY FolderName, EnvironmentName, VariableName

OPEN cr;

FETCH NEXT FROM cr INTO
    @fld
    ,@fldDesc
    ,@env
    ,@envDesc
    ,@varName
    ,@var
    ,@isSensitive
    ,@variableType
    ,@varDesc
', 0, 0) WITH NOWAIT;
RAISERROR(N'WHILE @@FETCH_STATUS = 0
BEGIN
    IF @lastFolderName IS NULL OR @lastFolderName <> @fld
    BEGIN
        SET @destFld = @fld
        SET @processFld = 1
        SET @lastEnvironmentName = NULL;
        IF @lastFolderName IS NOT NULL
            RAISERROR(N''==================================================================='', 0, 0) WITH NOWAIT;
', 0, 0) WITH NOWAIT;
RAISERROR(N'
                IF EXISTS(SELECT 1 FROM @folderReplacements)
                BEGIN
                    DECLARE flr CURSOR FAST_FORWARD FOR
                    SELECT
                        OldValue
                        ,NewValue
                    FROM @folderReplacements
                    ORDER BY SortOrder

                    OPEN flr;
            
                    FETCH NEXT FROM flr INTO @oldVal, @newVal

                    WHILE @@FETCH_STATUS = 0
                    BEGIN
                        SET @destFld = REPLACE(@destFld, @oldVal, @newVal)
                        FETCH NEXT FROM flr INTO @oldVal, @newVal
                    END

                    CLOSE flr;
                    DEALLOCATE flr;
                END
', 0, 0) WITH NOWAIT;

RAISERROR(N'
        IF NOT EXISTS(SELECT 1 FROM [SSISDB].[catalog].[folders] f WHERE f.[name] = @destFld)
        BEGIN
            IF @autoCreate = 1
            BEGIN
                RAISERROR(N''Creating Folder [%%s]...'', 0, 0, @destFld) WITH NOWAIT;
                EXEC [SSISDB].[catalog].[create_folder] @folder_name = @destFld
            END
            ELSE
            BEGIN
                SET @processFld = 0
                RAISERROR(N''Destination folder [%%s] does not exist and @autoCreate is not enabled. Ignoring folder environments'', 11, 0, @destFld) WITH NOWAIT;
            END
        END
        ELSE
        BEGIN
            RAISERROR(N''Processing folder [%%s]'', 0, 0, @destFld) WITH NOWAIT;
        END
        RAISERROR(N''==================================================================='', 0, 0) WITH NOWAIT;
    END
', 0, 0) WITH NOWAIT;
RAISERROR(N'    IF @processFld = 1 AND (@lastEnvironmentName IS NULL OR @lastEnvironmentName <> @env)
    BEGIN
        SET @processEnv = 1
        SET @destEnv = @env
        IF @lastEnvironmentName IS NOT NULL
            RAISERROR(N''-------------------------------------------------------------------'', 0, 0) WITH NOWAIT;
', 0, 0) WITH NOWAIT;
RAISERROR(N'
                IF EXISTS(SELECT 1 FROM @environmentReplacements)
                BEGIN
                    DECLARE fer CURSOR FAST_FORWARD FOR
                    SELECT
                        OldValue
                        ,NewValue
                    FROM @environmentReplacements
                    ORDER BY SortOrder

                    OPEN fer;
            
                    FETCH NEXT FROM fer INTO @oldVal, @newVal

                    WHILE @@FETCH_STATUS = 0
                    BEGIN
                        SET @destEnv = REPLACE(@destEnv, @oldVal, @newVal)
                        FETCH NEXT FROM fer INTO @oldVal, @newVal
                    END

                    CLOSE fer;
                    DEALLOCATE fer;
                END
', 0, 0) WITH NOWAIT;

RAISERROR(N'
        IF NOT EXISTS(
            SELECT
                1
            FROM [SSISDB].[catalog].[environments] e
            INNER JOIN [SSISDB].[catalog].[folders] f ON f.folder_id = e.folder_id
            WHERE
                f.name = @destFld
                AND
                e.name = @destEnv
        )
        BEGIN
            IF @autoCreate = 1
            BEGIN
                RAISERROR(N''Creating Environment [%%s]\[%%s]...'', 0, 0, @destFld, @destEnv) WITH NOWAIT;
                EXEC [SSISDB].[catalog].[create_environment] @folder_name = @destFld, @environment_name = @destEnv, @environment_description = @envDesc
            END
            ELSE
            BEGIN
                SET @processEnv = 0;
                RAISERROR(N''Destination environment [%%s]\[%%s] does not exists and @autoCreate is not enabled. Ignoring environment variables'', 11, 1, @destFld, @destEnv) WITH NOWAIT;
            END
        END
        ELSE
        BEGIN
            RAISERROR(N''Processing environment: [%%s]\[%%s]'', 0, 0, @destFld, @destEnv) WITH NOWAIT;
        END            
        RAISERROR(N''-------------------------------------------------------------------'', 0, 0) WITH NOWAIT;
    END
', 0, 0) WITH NOWAIT;

    RAISERROR(N'    SELECT
        @lastFolderName         = @fld
        ,@lastEnvironmentName   = @env
', 0, 0) WITH NOWAIT;

    RAISERROR(N'    IF @processEnv = 1 AND @processFld = 1
    BEGIN
        IF EXISTS(
            SELECT
                1
            FROM [SSISDB].[catalog].[environment_variables] v
            INNER JOIN [SSISDB].[catalog].[environments] e ON e.environment_id = v.environment_id
            INNER JOIN [SSISDB].[catalog].[folders] f ON f.folder_id = e.folder_id
            WHERE
                f.name = @destFld
                AND
                e.name = @destEnv
                AND
                v.name = @varName
        )
        BEGIN
            IF @overwrite = 1
            BEGIN
                RAISERROR(N''Overwriting existing variable [%%s]\[%%s]\[%%s]'', 0, 0, @destFld, @destEnv, @varName) WITH NOWAIT
                EXEC [SSISDB].[catalog].[set_environment_variable_value] @folder_name = @destFld, @environment_name = @destEnv, @variable_name = @varName, @value = @var
            END
            ELSE
            BEGIN
                RAISERROR(N''variable [%%s]\[%%s]\[%%s] already exists and overwrite is not allowed'', 11, 3, @destFld, @destEnv, @varName) WITH NOWAIT
            END
        END
        ELSE
        BEGIN
            RAISERROR(N''Creating variable [%%s]\[%%s]\[%%ss]'', 0, 0, @destFld, @destEnv, @varName) WITH NOWAIT;
            EXEC [SSISDB].[catalog].[create_environment_variable] @folder_name=@destFld, @environment_name=@destEnv, @variable_name=@varName, @data_type=@variableType, @sensitive=@isSensitive, @value=@var, @description=@varDesc
        END
    END
', 0, 0) WITH NOWAIT;

    RAISERROR(N'    FETCH NEXT FROM cr INTO
        @fld
        ,@fldDesc
        ,@env
        ,@envDesc
        ,@varName
        ,@var
        ,@isSensitive
        ,@variableType
        ,@varDesc
END

CLOSE cr;
DEALLOCATE cr;', 0, 0) WITH NOWAIT;

    END --@cloneReferencedEnvironments = 1 AND EXISTS(SELECT 1 FROM @references)

    --Print Runtime part for the script
    RAISERROR(N'', 0, 0) WITH NOWAIT;
    RAISERROR(N'-- =================================================================================', 0, 0) WITH NOWAIT;
    RAISERROR(N'--                              CONFIGURATION RUNTIME', 0, 0) WITH NOWAIT;
    RAISERROR(N'-- =================================================================================', 0, 0) WITH NOWAIT;

    RAISERROR(N'DECLARE
     @lastProjectName       nvarchar(128)
    ,@lastObjectName        nvarchar(260)
    ,@lastObjectType        smallint
    ,@processProject        bit
    ,@processObject         bit', 0, 0) WITH NOWAIT;
IF @cloneReferences = 1
RAISERROR(N'    ,@reference_id          bigint
', 0, 0) WITH NOWAIT;

RAISERROR(N'
RAISERROR(N'''', 0, 0) WITH NOWAIT;
RAISERROR(N''#################################################################################'', 0, 0) WITH NOWAIT;
RAISERROR(N''                            PROCESSING CONFIGURATIONS'', 0, 0) WITH NOWAIT;
RAISERROR(N''#################################################################################'', 0, 0) WITH NOWAIT;

SELECT
    @lastFolderName = NULL
    ,@processFld    = NULL

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

FETCH NEXT FROM cr INTO @fld, @project_name, @object_type, @object_name, @parameter_name, @value_type, @parameter_value
WHILE @@FETCH_STATUS = 0
BEGIN', 0, 0) WITH NOWAIT;
RAISERROR(N'    IF @lastFolderName IS NULL OR @lastFolderName <> @fld
    BEGIN
        SET @processFld = 1
        SET @folder_name = @fld
        SET @lastProjectName = NULL
        IF @lastFolderName IS NOT NULL
            RAISERROR(N''==================================================================='', 0, 0) WITH NOWAIT;
', 0, 0) WITH NOWAIT;
RAISERROR(N'
        IF EXISTS(SELECT 1 FROM @folderReplacements)
        BEGIN
            DECLARE rc CURSOR FAST_FORWARD FOR
            SELECT
                OldValue
                ,NewValue
            FROM @folderReplacements
            ORDER BY SortOrder

            OPEN rc;
            
            FETCH NEXT FROM rc INTO @oldVal, @newVal

            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @folder_name = REPLACE(@folder_name, @oldVal, @newVal)
                FETCH NEXT FROM rc INTO @oldVal, @newVal
            END

            CLOSE rc;
            DEALLOCATE rc;
        END
', 0, 0) WITH NOWAIT;
RAISERROR(N'
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
', 0, 0) WITH NOWAIT;

IF @cloneReferences = 1
BEGIN
    RAISERROR(N'
        IF @processReferences = 1 AND EXISTS(SELECT 1 FROM @references WHERE folder_name = @fld and project_name = @project_name)
        BEGIN
            DECLARE rc CURSOR FAST_FORWARD FOR
            SELECT
                reference_type
                ,environment_folder_name
                ,environment_name
            FROM @references
            WHERE 
                folder_name = @fld 
                AND
                project_name = @project_name

            OPEN rc;

            FETCH NEXT FROM rc INTO @reference_type, @environment_folder, @environment_name

            WHILE @@FETCH_STATUS = 0
            BEGIN', 0, 0) WITH NOWAIT;
RAISERROR(N'
                IF @reference_type = ''A'' AND EXISTS(SELECT 1 FROM @folderReplacements)
                BEGIN
                    DECLARE fr CURSOR FAST_FORWARD FOR
                    SELECT
                        OldValue
                        ,NewValue
                    FROM @folderReplacements
                    ORDER BY SortOrder

                    OPEN fr;
            
                    FETCH NEXT FROM fr INTO @oldVal, @newVal

                    WHILE @@FETCH_STATUS = 0
                    BEGIN
                        SET @environment_folder = REPLACE(@environment_folder, @oldVal, @newVal)
                        FETCH NEXT FROM fr INTO @oldVal, @newVal
                    END

                    CLOSE fr;
                    DEALLOCATE fr;
                END
', 0, 0) WITH NOWAIT;
RAISERROR(N'
                IF EXISTS(SELECT 1 FROM @environmentReplacements)
                BEGIN
                    DECLARE re CURSOR FAST_FORWARD FOR
                    SELECT
                        OldValue
                        ,NewValue
                    FROM @environmentReplacements
                    ORDER BY SortOrder

                    OPEN re;
            
                    FETCH NEXT FROM re INTO @oldVal, @newVal

                    WHILE @@FETCH_STATUS = 0
                    BEGIN
                        SET @environment_name = REPLACE(@environment_name, @oldVal, @newVal)
                        FETCH NEXT FROM re INTO @oldVal, @newVal
                    END

                    CLOSE re;
                    DEALLOCATE re;
                END
', 0, 0) WITH NOWAIT;

RAISERROR(N'                IF EXISTS (
                    SELECT
                        1
                    FROM catalog.environment_references er
                    INNER JOIN catalog.projects p ON p.project_id = er.project_id
                    INNER JOIN catalog.folders f ON f.folder_id = p.folder_id
                    WHERE
                        f.name = @folder_name
                        AND
                        p.name = @project_name
                        AND
                        er.reference_type = @reference_type
                        AND
                        (er.environment_folder_name = @environment_folder OR (er.environment_folder_name IS NULL AND @environment_folder IS NULL))
                        AND
                        er.environment_name = @environment_name
                    )', 0, 0) WITH NOWAIT;
RAISERROR(N'
                    BEGIN
                        IF @reference_type = ''A''
                            RAISERROR(N''Reference to environment [%%s]\[%%s] already exists'', 0, 0, @environment_folder, @environment_name) WITH NOWAIT;
                        ELSE
                            RAISERROR(N''Reference to local environment [%%s] already exists.'', 0, 0, @environment_name) WITH NOWAIT;
                    END
                    ELSE
                    BEGIN
                        IF @reference_type = ''A''
                            RAISERROR(N''Setting Reference to environment [%%s]\[%%s]'', 0, 0, @environment_folder, @environment_name) WITH NOWAIT;
                        ELSE
                            RAISERROR(N''Setting Reference to local environment [%%s]'', 0, 0, @environment_name) WITH NOWAIT;

                        EXEC [SSISDB].[catalog].[create_environment_reference] @environment_name=@environment_name, @environment_folder_name=@environment_folder, @reference_id=@reference_id OUTPUT, @project_name=@project_name, @folder_name=@folder_name, @reference_type=@reference_type
                    END
                FETCH NEXT FROM rc INTO @reference_type, @environment_folder, @environment_name
            END
            CLOSE rc;
            DEALLOCATE rc;
            RAISERROR(N''+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++'', 0, 0) WITH NOWAIT;
        END', 0, 0) WITH NOWAIT;
END
RAISERROR(N'    END
    IF @processProject = 1 AND (@lastObjectName IS NULL OR @lastObjectType IS NULL OR @lastObjectName <> @object_name OR @lastObjectType <> @object_type)
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
        @lastFolderName     = @fld
        ,@lastProjectName   = @project_name
        ,@lastObjectName    = @object_name
        ,@lastObjectType    = @object_type


    FETCH NEXT FROM cr INTO @fld, @project_name, @object_type, @object_name, @parameter_name, @value_type, @parameter_value
END

CLOSE cr;
DEALLOCATE cr;

', 0, 0) WITH NOWAIT;

IF @cloneReferences = 1
    RAISERROR(N'IF @processReferences = 0
BEGIN', 0, 0) WITH NOWAIT;

RAISERROR(N'    IF EXISTS(SELECT 1 FROM @parameters WHERE value_type = ''R'')
        RAISERROR(N''==================================================================='', 0, 0) WITH NOWAIT;

    DECLARE fc CURSOR FAST_FORWARD FOR
    SELECT DISTINCT
        folder_name
        ,project_name
    FROM @parameters

    OPEN fc;
    FETCH NEXT FROM fc INTO @folder_name, @project_name

    WHILE @@FETCH_STATUS = 0
    BEGIN', 0, 0) WITH NOWAIT;
RAISERROR(N'
        IF EXISTS(SELECT 1 FROM @folderReplacements)
        BEGIN
            DECLARE rc CURSOR FAST_FORWARD FOR
            SELECT
                OldValue
                ,NewValue
            FROM @folderReplacements
            ORDER BY SortOrder

            OPEN rc;
            
            FETCH NEXT FROM rc INTO @oldVal, @newVal

            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @folder_name = REPLACE(@folder_name, @oldVal, @newVal)
                FETCH NEXT FROM rc INTO @oldVal, @newVal
            END

            CLOSE rc;
            DEALLOCATE rc;
        END
', 0, 0) WITH NOWAIT;
RAISERROR(N'
        RAISERROR(N''DON''''T FORGET TO SET ENVIRONMENT REFERENCES for project [%%s]\[%%s].'', 0, 0, @folder_name, @project_name) WITH NOWAIT;
        FETCH NEXT FROM fc INTO @folder_name, @project_name
    END

    CLOSE fc;
    DEALLOCATE fc;    
', 0, 0) WITH NOWAIT;

IF @cloneReferences = 1
    RAISERROR(N'END', 0, 0) WITH NOWAIT;

END
GO
IF NOT EXISTS(SELECT 1 FROM sys.database_principals WHERE TYPE = 'R' AND name = 'ssis_sensitive_access')
BEGIN
    RAISERROR(N'Creating database role [ssis_sensitive_access]...', 0, 0) WITH NOWAIT;
    CREATE ROLE [ssis_sensitive_access]
END
ELSE
BEGIN
    RAISERROR(N'Database role [ssis_sensitive_access] exists.', 0, 0) WITH NOWAIT;
END
GO
RAISERROR('[ssis_sensitive_access] database role allows using @decryptSensitive paramter to decrypt sensitive information', 0, 0) WITH NOWAIT;
GO
--
RAISERROR(N'Adding [ssis_admin] to [ssis_sensitive_access]', 0, 0) WITH NOWAIT;
ALTER ROLE [ssis_sensitive_access] ADD MEMBER [ssis_admin]
GO

--GRANT EXECUTE permission on the stored procedure to [ssis_admin] role
RAISERROR(N'Granting EXECUTE permission to [ssis_admin]', 0, 0) WITH NOWAIT;
GRANT EXECUTE ON [dbo].[sp_SSISCloneConfiguration] TO [ssis_admin]
GO
