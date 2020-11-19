IF NOT EXISTS(SELECT 1 FROM sys.databases where name = 'SSISDB')
BEGIN
    RAISERROR(N'SSIS Database Does not Exists', 15, 0)
    SET NOEXEC ON;
END
GO
USE [SSISDB]
GO
RAISERROR('Creating procedure [dbo].[sp_SSISCloneEnvironment]', 0, 0) WITH NOWAIT;
IF NOT EXISTS(SELECT * FROM sys.procedures WHERE object_id = OBJECT_ID('[dbo].[sp_SSISCloneEnvironment]'))
    EXEC (N'CREATE PROCEDURE [dbo].[sp_SSISCloneEnvironment] AS PRINT ''Placeholder for [dbo].[sp_SSISCloneEnvironment]''')
GO
/* ****************************************************
sp_SSISCloneEnvironment v 0.66 (2018-08-08)

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
    Clones SSIS environment variables from one environment to another.
    Allows scripting of the environments for easy transfer among environments.

Parameters:
     @folder                                nvarchar(max)   = NULL --comma separated list of environment folder. Supports wildcards.
    ,@environment                           nvarchar(max)   = '%'  --comma separated lists of environments. Supports wildcards.
    ,@variables                             nvarchar(max)   = NULL --Comma separated lists of environment variables to list. Supports wildcards.
    ,@destinationFolder                     nvarchar(128)   = '%'  --Name of the destination folder(s). Supports wildcards. It sets default value for the script
    ,@destinationEnvironment                nvarchar(max)   = '%'  --Name of the destination Environment(s). Support wildcards. It sets default value for the script
    ,@destinationFolderReplacements         nvarchar(max)   = NULL  -- Comma separated list of destination folder replacements. 
    ,@destinationEnvironmentReplacements    nvarchar(max)   = NULL  -- Comma separated list of destination environment replacements. 
    ,@autoCreate                            bit             = 0    --Specifies whether the destination Folder/Environment should be auto-created if not exists. It sets default value for the script
    ,@overwrite                             bit             = 0    --Specifies whether destination environment variables should be overwritten. It sets default value for the script 
    ,@value                                 nvarchar(max)   = NULL --Comma separated list of environment variable values. Supports wildcards
    ,@exactValue                            nvarchar(max)   = NULL --Exact value of variables to be matched. Have priority above value
    ,@decryptSensitive                      bit             = 0    --Specifies whether sensitive data should be decrypted.
 ******************************************************* */
ALTER PROCEDURE [dbo].[sp_SSISCloneEnvironment]
     @folder                                nvarchar(max)   = NULL --comma separated list of environment folder. Supports wildcards.
    ,@environment                           nvarchar(max)   = '%'  --comma separated lists of environments. Supports wildcards.
    ,@variables                             nvarchar(max)   = NULL --Comma separated lists of environment variables to list. Supports wildcards.
    ,@destinationFolder                     nvarchar(128)   = '%'  --Name of the destination folder(s). Supports wildcards. It sets default value for the script
    ,@destinationEnvironment                nvarchar(max)   = '%'  --Name of the destination Environment(s). Support wildcards. It sets default value for the script
    ,@destinationFolderReplacements         nvarchar(max)   = NULL  -- Comma separated list of destination folder replacements. 
    ,@destinationEnvironmentReplacements    nvarchar(max)   = NULL  -- Comma separated list of destination environment replacements. 
    ,@autoCreate                            bit             = 0    --Specifies whether the destination Folder/Environment should be auto-created if not exists. It sets default value for the script
    ,@overwrite                             bit             = 0    --Specifies whether destination environment variables should be overwritten. It sets default value for the script 
    ,@value                                 nvarchar(max)   = NULL --Comma separated list of environment variable values. Supports wildcards
    ,@exactValue                            nvarchar(max)   = NULL --Exact value of variables to be matched. Have priority above value
    ,@decryptSensitive                      bit             = 0    --Specifies whether sensitive data should be decrypted.
WITH EXECUTE AS 'AllSchemaOwner'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @src_folder_id                  bigint                  --ID of the source folder
        ,@src_Environment_id            bigint                  --ID of the source Environment
        ,@msg                           nvarchar(max)           --General purpose message variable (used for printing output)
        ,@printHelp                     bit             = 0     --Identifies whether Help should be printed (in case of no parameters provided or error)
        ,@name                          sysname                 --Name of the variable
        ,@description                   nvarchar(1024)          --Description of the variable
        ,@type                          nvarchar(128)           --DataType of the variable
        ,@sensitive                     bit                     --Identifies sensitive variable
        ,@valueInternal                 sql_variant             --Non sensitive value of the variable
        ,@sensitive_value               varbinary(max)          --Sensitive value of the variable
        ,@base_data_type                nvarchar(128)           --Base data type of the variable
        ,@sql                           nvarchar(max)           --Variable for storing dynamic SQL statements
        ,@src_keyName                   nvarchar(256)           --Name of the symmetric key for decryption of the source sensitive values from the source environment
        ,@src_certificateName           nvarchar(256)           --Name of the certificate for decryption of the source symmetric key
        ,@decrypted_value               varbinary(max)          --Variable to store decrypted sensitive value
        ,@stringval                     nvarchar(max)           --String representation of the value
        ,@xml                           xml
        ,@src_environment_name          nvarchar(128)
        ,@src_folder_name               nvarchar(128)
        ,@variable_id                   bigint
        ,@FolderID                      bigint
        ,@EnvironmentID                 bigint
        ,@FolderName                    nvarchar(128)
        ,@EnvironmentName               nvarchar(128)
        ,@VariableID                    bigint
        ,@VariableName                  nvarchar(128)
        ,@VariableDescription           nvarchar(1024)
        ,@VariableType                  nvarchar(128)
        ,@BaseDataType                  nvarchar(128)
        ,@Val                           sql_variant
        ,@IsSensitive                   bit
        ,@lastFolderID                  bigint          = NULL
        ,@lastEnvironmentID             bigint          = NULL
        ,@folderDescription             nvarchar(1024)
        ,@environmentDescription        nvarchar(1024)
        ,@valueDescription              nvarchar(1024)
        ,@fldQuoted                     nvarchar(200)
        ,@envQuoted                     nvarchar(200)
        ,@fldDescrQuoted                nvarchar(4000)
        ,@envDescrQuoted                nvarchar(4000)
        ,@autoCreateInt                 int             = ISNULL(@autoCreate, 0)
        ,@overwriteInt                  int             = ISNULL(@overwrite, 0)
        ,@valQuoted                     nvarchar(max)
        ,@varDescrQuoted                nvarchar(4000)
        ,@varNameQuoted                 nvarchar(4000)
        ,@sensitiveDescr                nvarchar(10)
        ,@prefix                        nvarchar(10)
        ,@sensitiveInt                  int
        ,@valStr                        nvarchar(max)
        ,@sensitiveAccess               bit             = 0     --Indicates whether caller have access to senstive infomration

    EXECUTE AS CALLER;
        IF IS_MEMBER('ssis_sensitive_access') = 1 OR IS_MEMBER('db_owner') = 1 OR IS_SRVROLEMEMBER('sysadmin') = 1
            SET @sensitiveAccess = 1
    REVERT;

    --Table variable for holding parsed folder names list
    DECLARE @folders TABLE (
        folder_id       bigint
        ,folder_name    nvarchar(128)
    )

    --Table variable for holding parsed variable names list
    DECLARE @variableNames TABLE (
        name    nvarchar(128)
    )
    
    --Table variable for holding parsed variable values list
    DECLARE @values TABLE (
        Value   nvarchar(4000)
    )

    --Table variable fo holding intermediate environment list
    DECLARE @environments TABLE (
        FolderID                bigint
        ,EnvironmentID          bigint
        ,FolderName             nvarchar(128)
        ,EnvironmentName        nvarchar(128)
        ,FolderDescription      nvarchar(1024)
        ,EnvironmentDescription nvarchar(1024)
    )

    --Table variable for holding extracted environment variables
    DECLARE @outputTable TABLE (
         FolderID               bigint
        ,EnvironmentID          bigint
        ,FolderName             nvarchar(128)
        ,EnvironmentName        nvarchar(128)
        ,VariableID             bigint
        ,VariableName           nvarchar(128)
        ,VariableDescription    nvarchar(1024)
        ,VariableType           nvarchar(128)
        ,BaseDataType           nvarchar(128)
        ,Value                  sql_variant
        ,StringValue            nvarchar(4000)
        ,IsSensitive            bit
        ,FolderDescription      nvarchar(1024)
        ,EnvironmentDescription nvarchar(1024)
    )

    --If the needed input parameters are null, print help
    IF @folder IS NULL OR @environment IS NULL
    BEGIN
        SET @printHelp = 1
    END

    SET @msg = CASE WHEN @printHelp = 1 THEN N'' ELSE N'RAISERROR(N''' END + N'sp_SSISCloneEnvironment v0.66 (2018-08-08) (C) 2017 - 2018 Pavel Pawlowski' + CASE WHEN @printHelp = 1 THEN '' ELSE N''', 0, 0) WITH NOWAIT;' END;
	RAISERROR(@msg, 0, 0) WITH NOWAIT;
    SET @msg = CASE WHEN @printHelp = 1 THEN N'' ELSE N'RAISERROR(N''' END + N'==========================================================================' + CASE WHEN @printHelp = 1 THEN '' ELSE N''', 0, 0) WITH NOWAIT;' END;
	RAISERROR(@msg, 0, 0) WITH NOWAIT;

    IF @value IS NOT NULL AND @exactValue IS NOT NULL
    BEGIN
        RAISERROR(N'Only @value or @exactValue can be specified at a time', 11, 0) WITH NOWAIT;
        SET @printHelp = 1
    END



    --PRINT HELP
    IF @printHelp = 1
    BEGIN
        RAISERROR(N'', 0, 0) WITH NOWAIT; 
        RAISERROR(N'Generates script for cloning of SSIS environment variables.
Multiple environments from multiple folders can be scripted at a time.
Variables can be filtered by names as well as values.
    ', 0, 0) WITH NOWAIT; 
        RAISERROR(N'', 0, 0) WITH NOWAIT; 
        RAISERROR(N'Usage:', 0, 0) WITH NOWAIT; 
        RAISERROR(N'[sp_SSISCloneEnvironment] parameters', 0, 0) WITH NOWAIT; 
        RAISERROR(N'', 0, 0) WITH NOWAIT; 
        RAISERROR(N'Parameters:
     @folder                                nvarchar(max)   = NULL - Comma separated list of environment folders. Supports wildcards
                                                                     Variables from environments in matching folders will be scripted
    ,@environment                           nvarchar(max)   = ''%%''  - Comma separated lists of environments.  support wildcards
                                                                     Variables from all environment matching the condition will be scripted.
    ,@variables                             nvarchar(max)   = NULL - Comma separated lists of environment variables to script. Supports wildcards
                                                                     Only variables which name is matching pattern are scripted
    ,@destinationFolder                     nvarchar(128)   = ''%%''  - Pattern for naming Destination Folder. %% in the destination folder name is replaced by the name of the source folder.
                                                                     Allows easy cloning of multiple folders by prefixing or suffixing the %% pattern
                                                                     It sets the default value for the final script
    ,@destinationEnvironment                nvarchar(max)   = ''%%''  - Pattern for naming destination Environment. %% in the destination environment name is replaced by the source environment name.
                                                                     Allows easy cloning of multiple environments by prefixing or suffixing the %% pattern
                                                                     It sets the default value for the final script
                                                                     It supports comma delimited list of desination environments. If multiple environments are provided then all the scripted variables
                                                                     are applied in the loop for each such environment in the list. This allows easy replication of variable(s) to multiple
                                                                     destination environments', 0, 0) WITH NOWAIT;
RAISERROR(N'    ,@destinationFolderReplacements         varchar(max)    = NULL - Comma separated list of destination folder replacements. 
                                                                     Replacements are in format SourceVal1=NewVal1,SourceVal2=NewVal2
                                                                     Replacements are applied from left to right. This means if SourceVal2 is substring of NewVal1 that substring will be
                                                                     replaced by the NewVal2.
                                                                     Replacements are applied on @destinationFolder after widcards replacements.
    ,@destinationEnvironmentReplacements    nvarchar(max)   = NULL - Comma separated list of destination environment replacements. 
                                                                     Replacements are in format OldVal1=NewVal1,OldVal2=NewVal2
                                                                     Replacements are applied from left to right. This means if OldValVal2 is substring of NewVal1 that substring will be
                                                                     replaced by the NewVal2.
                                                                     Replacements are applied on @destinationEnvironment after widcards replacements.', 0, 0) WITH NOWAIT;
RAISERROR(N'    ,@autoCreate                            bit             = 0    - Specifies whether the destination Folder/Environment should be auto-created if not exists. 
                                                                     It sets default value for the script
    ,@overwrite                             bit             = 0    - Specifies whether destination environment variables should be overwritten. 
                                                                     It sets default value for the script 
    ,@value                                 nvarchar(max)   = NULL - Comma separated list of environment variable values. Supports wildcards
                                                                     Only variables which value matches the provided pattern are scripted
    ,@exactValue                            nvarchar(max)   = NULL - Exact value of variables to be matched. Have priority above @value
                                                                     Only variables which value exactly matching the @exactValue are scripted.
    ,@decryptSensitive                      bit             = 0    - Specifies whether sensitive data should be decrypted.
                                                                     Caller must be member of [db_owner] or [ssis_sensitive_access] database role or member of [sysadmin] server role
                                                                     to be able to decrypt sensitive information
', 0, 0) WITH NOWAIT;
RAISERROR(N'
Wildcards:
    Wildcards are standard wildcards for the LIKE statement
    Entries prefixed with [-] (minus) symbol are excluded form results and have priority over the non excluding

Samples:
--------
Clone all environments and its variables from folders starting with ''TEST'' or ''DEV'' but exclude all folder names ending with ''Backup''
sp_SSISCloneEnvironment @folder = N''TEST%%,DEV%%,-%%Backup'' 

Clone variables from all folders and environments which name starts with OLEDB_ and ends with _Password and containing value "AAA" or "BBB"
sp_SSISClonenvironment
    @folder         = ''%%''
    ,@environment   = ''%%''
    ,@variables     = ''OLEDB_%%_Password''
    ,@value         = ''AAA,BBB''

Clone all Environments and variables from all folders starting with ''DEV_''. Destination folders will contain suffix "_Copy" and Environments will be prefixed by "Clone_
Sensitive information will be decrypted into the script. Destination Folders and Environment will be automatically created if they do not exits.
In case variable in destination environment already exists its value will be overwritten
sp_SSISCloneEnvironment
    @folder                     = ''DEV_%%''
    ,@environment               = ''%%''
    ,@destinationFolder         = ''%%_Copy''
    ,@destinationEnvironment    = ''Clone_%%''
    ,@autoCreate                = 1
    ,@owerwrite                 = 1
    ,@decryptSensitive          = 1
    ', 0, 0) WITH NOWAIT;

        RAISERROR(N'',0, 0) WITH NOWAIT; 

        RETURN;
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

    

    IF NOT EXISTS(SELECT 1 FROM @folders)
    BEGIN
        RAISERROR(N'No Folder matching [%s] exists.', 15, 1, @folder) WITH NOWAIT;
        RETURN;
    END

    --Get list of environments
    SET @xml = N'<i>' + REPLACE(@environment, ',', '</i><i>') + N'</i>';

    WITH EnvironmentNames AS (
        SELECT DISTINCT
            LTRIM(RTRIM(F.value('.', 'nvarchar(128)'))) AS EnvName
        FROM @xml.nodes(N'/i') T(F)
    )
    INSERT INTO @environments (
        FolderID
        ,EnvironmentID
        ,FolderName
        ,EnvironmentName
        ,FolderDescription
        ,EnvironmentDescription
    )
    SELECT DISTINCT
        E.folder_id
        ,E.environment_id
        ,F.folder_name
        ,E.environment_name
        ,fld.description
        ,E.description
    FROM internal.environments E
    INNER JOIN internal.folders fld ON fld.folder_id = E.folder_id
    INNER JOIN @folders F ON E.folder_id = F.folder_id
    INNER JOIN EnvironmentNames EN ON E.environment_name LIKE EN.EnvName AND LEFT(EN.EnvName, 1) <> '-'
    EXCEPT
    SELECT
        E.folder_id
        ,E.environment_id
        ,F.folder_name
        ,E.environment_name
        ,fld.description
        ,E.description
    FROM internal.environments E
    INNER JOIN internal.folders fld ON fld.folder_id = E.folder_id
    INNER JOIN @folders F ON E.folder_id = F.folder_id
    INNER JOIN EnvironmentNames EN ON E.environment_name LIKE RIGHT(EN.EnvName, LEN(EN.EnvName) -1) AND LEFT(EN.EnvName, 1) = '-'

    IF NOT EXISTS(SELECT 1 FROM @environments)
    BEGIN
        RAISERROR(N'No Environments matching [%s] exists in folders matching [%s]', 15, 2, @environment, @folder) WITH NOWAIT;
        RETURN;
    END

    --Get variable values list
    SET @xml = N'<i>' + REPLACE(@value, ',', '</i><i>') + N'</i>';

    INSERT INTO @values (Value)
    SELECT DISTINCT
        LTRIM(RTRIM(V.value(N'.', N'nvarchar(4000)'))) AS Value
    FROM @xml.nodes(N'/i') T(V)

    --parse variable names
    SET @xml = N'<i>' + REPLACE(ISNULL(@variables, N'%'), ',', '</i><i>') + N'</i>';
    INSERT INTO @variableNames (
        Name
    )
    SELECT DISTINCT
        LTRIM(RTRIM(V.value(N'.', N'nvarchar(128)'))) AS VariableName
    FROM @xml.nodes(N'/i') T(V);

    --Retrieve environment variables based on the input criteria
    WITH Variables AS (
        SELECT DISTINCT
            ev.variable_id
        FROM [internal].[environment_variables] ev
        INNER JOIN @environments e ON e.EnvironmentID = ev.environment_id
        INNER JOIN @variableNames vn ON ev.name LIKE vn.name AND LEFT(vn.name, 1) <> '-'

        EXCEPT

        SELECT DISTINCT
            ev.variable_id
        FROM [internal].[environment_variables] ev
        INNER JOIN @environments e ON e.EnvironmentID = ev.environment_id
        INNER JOIN @variableNames vn ON ev.name LIKE RIGHT(vn.name, LEN(vn.name) -1) AND LEFT(vn.name, 1) = '-'
    ), VariableValues AS (
        SELECT
             e.FolderID
            ,e.EnvironmentID
            ,ev.variable_id             AS VariableID
            ,e.FolderName
            ,e.EnvironmentName
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
        FROM [internal].[environment_variables] ev
        INNER JOIN Variables v ON v.variable_id = ev.variable_id
        INNER JOIN @environments e ON e.EnvironmentID = ev.environment_id
    ), VariableValuesString AS (
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
    FROM VariableValues vv
    )
    INSERT INTO @outputTable (
        FolderID
        ,EnvironmentID
        ,VariableID
        ,FolderName
        ,EnvironmentName
        ,VariableName
        ,Value
        ,StringValue
        ,VariableDescription
        ,VariableType
        ,BaseDataType
        ,IsSensitive
    )
    SELECT
         FolderID
        ,EnvironmentID
        ,VariableID
        ,FolderName
        ,EnvironmentName
        ,VariableName
        ,Value
        ,StringValue
        ,VariableDescription
        ,VariableType
        ,BaseDataType
        ,IsSensitive
    FROM VariableValuesString
    WHERE
        ((@value IS NULL OR @value = N'%') AND @exactValue IS NULL) OR (@exactValue IS NOT NULL AND StringValue = @exactValue)
        OR
        EXISTS (
            SELECT
                StringValue
            FROM @values v
            WHERE
                @exactValue IS NULL
                AND
                LEFT(v.Value, 1) <> '-'
                AND
                StringValue LIKE v.Value
            EXCEPT
            SELECT
                StringValue
            FROM @values v
            WHERE
                @exactValue IS NULL
                AND
                LEFT(v.Value, 1) = '-'
                AND
                StringValue LIKE RIGHT(v.Value, LEN(v.Value) - 1)
        )
    
    --Print global part of the generated script
    RAISERROR(N'', 0, 0) WITH NOWAIT;
    RAISERROR(N'--Global definitions:', 0, 0) WITH NOWAIT;
    RAISERROR(N'---------------------', 0, 0) WITH NOWAIT;
    RAISERROR(N'DECLARE @destinationFolder                  nvarchar(128) = N''%s''   -- Specify destination folder name/wildcard', 0, 0, @destinationFolder) WITH NOWAIT;
    RAISERROR(N'DECLARE @destinationEnvironment             nvarchar(max) = N''%s''   -- Specify destination Environment name/wildcard', 0, 0, @destinationEnvironment) WITH NOWAIT;
    IF @destinationFolderReplacements IS NULL
        RAISERROR(N'DECLARE @destinationFolderReplacements      nvarchar(max) = NULL      -- Specify destination folder replacements.', 0, 0, @destinationFolderReplacements) WITH NOWAIT;
    ELSE
        RAISERROR(N'DECLARE @destinationFolderReplacements      nvarchar(max) = N''%s''   -- Specify destination folder replacements.', 0, 0, @destinationFolderReplacements) WITH NOWAIT;
    IF @destinationEnvironmentReplacements IS NULL
        RAISERROR(N'DECLARE @destinationEnvironmentReplacements nvarchar(max) = NULL      -- Specify destination environment replacements.', 0, 0, @destinationEnvironmentReplacements) WITH NOWAIT;
    ELSE
        RAISERROR(N'DECLARE @destinationEnvironmentReplacements nvarchar(max) = N''%s''   -- Specify destination environment replacements.', 0, 0, @destinationEnvironmentReplacements) WITH NOWAIT;
    RAISERROR(N'DECLARE @autoCreate                         bit           = %d        -- Specify whether folder and environments should be auto-created', 0, 0, @autoCreateInt) WITH NOWAIT;
    RAISERROR(N'DECLARE @overwrite                          bit           = %d        -- Specify whether value of existing variables should be overwritten', 0, 0, @overwriteInt) WITH NOWAIT;
    RAISERROR(N'', 0, 0) WITH NOWAIT;
    RAISERROR(N'', 0, 0) WITH NOWAIT;
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
)

SET NOCOUNT ON;    
', 0, 0) WITH NOWAIT;
    
    --Cursor for looping environment variables
    DECLARE cr CURSOR FAST_FORWARD FOR
    SELECT
         FolderID
        ,EnvironmentID
        ,VariableID
        ,FolderName
        ,EnvironmentName
        ,VariableName
        ,Value
        ,StringValue
        ,VariableDescription
        ,VariableType
        ,BaseDataType
        ,IsSensitive
        ,FolderDescription
        ,EnvironmentDescription
    FROM @outputTable
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
            --RAISERROR(N'SET @destEnv = REPLACE(@destinationEnvironment, ''%%'', %s)', 0, 0, @envQuoted) WITH NOWAIT;
            RAISERROR(N'SET @destEnv = %s', 0, 0, @envQuoted) WITH NOWAIT;
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

    --Print Runtime part for the script
    RAISERROR(N'', 0, 0) WITH NOWAIT;
    RAISERROR(N'-- =================================================================================', 0, 0) WITH NOWAIT;
    RAISERROR(N'--                                     RUNTIME', 0, 0) WITH NOWAIT;
    RAISERROR(N'-- =================================================================================', 0, 0) WITH NOWAIT;

    RAISERROR(N'DECLARE
    @lastFolderName         nvarchar(128)
    ,@lastEnvironmentName   nvarchar(128)
    ,@fld                   nvarchar(128)
    ,@env                   nvarchar(128)
    ,@dstEnv                nvarchar(128)
    ,@destEnvCount          int
    ,@processFld            bit
    ,@processEnv            bit
    ,@xml                   xml
    ,@msg                   nvarchar(max)
    ,@oldVal                nvarchar(128)
    ,@newVal                nvarchar(128)
    ,@error                 bit             = 0

--Table for holding multiple target environments
DECLARE @environments TABLE (
    Ord             INT           NOT NULL PRIMARY KEY CLUSTERED
    ,Environment    nvarchar(128) NOT NULL
)

--Table for holding folder replacements
DECLARE @folderReplacements TABLE (
    SortOrder       int             NOT NULL    PRIMARY KEY CLUSTERED
    ,OldValue       nvarchar(128)
    ,NewValue       nvarchar(128)
    ,Replacement    nvarchar(4000)
)

--Table for holding environment replacements
DECLARE @environmentReplacements TABLE (
    SortOrder       int             NOT NULL    PRIMARY KEY CLUSTERED
    ,OldValue       nvarchar(128)
    ,NewValue       nvarchar(128)
    ,Replacement    nvarchar(4000)
)
', 0, 0) WITH NOWAIT;

RAISERROR(N'
--Environments
SET @xml = N''<i>'' + REPLACE(@destinationEnvironment, '','', ''</i><i>'') + N''</i>'';
WITH Environments AS (
    SELECT DISTINCT
        LTRIM(RTRIM(F.value(''.'', ''nvarchar(128)''))) AS Environment
        ,ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS Ord
    FROM @xml.nodes(N''/i'') T(F)
)
INSERT INTO @environments(Ord, Environment)
SELECT
    Ord
    ,Environment
FROM Environments

SET @destEnvCount = ISNULL((SELECT COUNT(1) FROM @environments), 0);
', 0, 0) WITH NOWAIT;

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

RAISERROR(N'
IF @error = 0
BEGIN
DECLARE ecr CURSOR FAST_FORWARD FOR
SELECT
    Environment
FROM @environments
ORDER BY Ord

OPEN ecr;

FETCH NEXT FROM ecr INTO @dstEnv

WHILE @@FETCH_STATUS = 0
BEGIN
    IF @destEnvCount > 1
    BEGIN
        RAISERROR(N''Processing Destination Environment [%%s]'', 0, 0, @dstEnv) WITH NOWAIT;
        SET @msg = N''*************************************'' + REPLICATE(''*'', LEN(@dstEnv))
        RAISERROR(@msg, 0, 0) WITH NOWAIT;
    END
', 0, 0) WITH NOWAIT;

RAISERROR(N'
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
    SET @env = REPLACE(@dstEnv, ''%%'', @env)
    IF @lastFolderName IS NULL OR @lastFolderName <> @fld
    BEGIN
        SET @processFld = 1
        SET @lastEnvironmentName = NULL;
        IF @lastFolderName IS NOT NULL
            RAISERROR(N''==================================================================='', 0, 0) WITH NOWAIT;

        SET @destFld = @fld
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
                SET @destFld = REPLACE(@destFld, @oldVal, @newVal)
                FETCH NEXT FROM rc INTO @oldVal, @newVal
            END

            CLOSE rc;
            DEALLOCATE rc;
        END
', 0, 0) WITH NOWAIT;
RAISERROR('
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
', 0, 0) WITH NOWAIT;
RAISERROR(N'
        IF EXISTS(SELECT 1 FROM @environmentReplacements)
        BEGIN
            DECLARE rc CURSOR FAST_FORWARD FOR
            SELECT
                OldValue
                ,NewValue
            FROM @environmentReplacements
            ORDER BY SortOrder

            OPEN rc;
            
            FETCH NEXT FROM rc INTO @oldVal, @newVal

            WHILE @@FETCH_STATUS = 0
            BEGIN
                SET @destEnv = REPLACE(@destEnv, @oldVal, @newVal)
                FETCH NEXT FROM rc INTO @oldVal, @newVal
            END

            CLOSE rc;
            DEALLOCATE rc;
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

    RAISERROR(N'
    SELECT
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
            RAISERROR(N''Creating variable [%%s]\[%%s]\[%%s]'', 0, 0, @destFld, @destEnv, @varName) WITH NOWAIT;
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
DEALLOCATE cr;

FETCH NEXT FROM ecr INTO @dstEnv
END

CLOSE ecr;
DEALLOCATE ecr;

END', 0, 0) WITH NOWAIT;

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
GRANT EXECUTE ON [dbo].[sp_SSISCloneEnvironment] TO [ssis_admin]
GO
