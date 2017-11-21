USE [SSISDB]
GO
RAISERROR('Creating procedure [dbo].[sp_SSISListEnvironment]', 0, 0) WITH NOWAIT;
IF NOT EXISTS(SELECT * FROM sys.procedures WHERE object_id = OBJECT_ID('[dbo].[sp_SSISListEnvironment]'))
    EXEC (N'CREATE PROCEDURE [dbo].[sp_SSISListEnvironment] AS PRINT ''Placeholder for [dbo].[sp_SSISListEnvironment]''')
GO
/* ****************************************************
sp_SSISListEnvironment v 0.40 (2017-10-31)

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
    List Environment variables and their values for environments specified by parameters.
    Allows decryption of encrypted variable values

Parameters:
     @folder                nvarchar(max)    = NULL --comma separated list of environment folder. Supports wildcards.
    ,@environment           nvarchar(max)    = '%'  --comma separated lists of environments.  Supports wildcards.
    ,@variables             nvarchar(max)    = NULL --Comma separated lists of environment variables to list. Supports wildcards.
    ,@value                 nvarchar(max)    = NULL --Comma separated list of environment variable values. Supports wildcards.
    ,@exactValue            nvarchar(max)    = NULL --Exact value of variables to be matched. Have priority above value.
    ,@decryptSensitive      bit              = 0    --Specifies whether sensitive data should be decrypted.
 ******************************************************* */
ALTER PROCEDURE [dbo].[sp_SSISListEnvironment]
     @folder                nvarchar(max)    = NULL --comma separated list of environment folder. Supports wildcards.
    ,@environment           nvarchar(max)    = '%'  --comma separated lists of environments.  Supports wildcards.
    ,@variables             nvarchar(max)    = NULL --Comma separated lists of environment variables to list. Supports wildcards.
    ,@value                 nvarchar(max)    = NULL --Comma separated list of environment variable values. Supports wildcards.
    ,@exactValue            nvarchar(max)    = NULL --Exact value of variables to be matched. Have priority above value.
    ,@decryptSensitive      bit              = 0    --Specifies whether sensitive data should be decrypted.
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
        ,@xml                           xml                     --Xml variable for parsing input parameters
        ,@src_environment_name          nvarchar(128)
        ,@src_folder_name               nvarchar(128)
        ,@variable_id                   bigint
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
        FolderID            bigint
        ,EnvironmentID      bigint
        ,FolderName         nvarchar(128)
        ,EnvironmentName    nvarchar(128)
    )

    --If the needed input parameters are null, print help
    IF @folder IS NULL OR @environment IS NULL
        SET @printHelp = 1

	RAISERROR(N'sp_SSISListEnvironment v0.40 (2017-10-31) (C) 2017 Pavel Pawlowski', 0, 0) WITH NOWAIT;
	RAISERROR(N'==================================================================' , 0, 0) WITH NOWAIT;

    --Check @value and @exactValue
    IF @value IS NOT NULL AND @exactValue IS NOT NULL
    BEGIN
        RAISERROR(N'Only @value or @exactValue can be specified at a time', 11, 0) WITH NOWAIT;
        SET @printHelp = 1
    END

    --PRINT HELP
    IF @printHelp = 1
    BEGIN
        RAISERROR(N'', 0, 0) WITH NOWAIT; 
        RAISERROR(N'Lists SSIS environment variables and allows seeing encrypted information', 0, 0) WITH NOWAIT; 
        RAISERROR(N'', 0, 0) WITH NOWAIT; 
        RAISERROR(N'Usage:', 0, 0) WITH NOWAIT; 
        RAISERROR(N'[sp_SSISListEnvironment] parameters', 0, 0) WITH NOWAIT; 
        RAISERROR(N'', 0, 0) WITH NOWAIT; 
        RAISERROR(N'Parameters:
     @folder                nvarchar(max)    = NULL - Comma separated list of environment folders. Supports wildcards.
                                                      Only variables from environment belonging to matched folder are listed
    ,@environment           nvarchar(max)    = ''%%''  - Comma separated lists of environments.  Support wildcards.
                                                      Only variables from environments matching provided list are returned.
    ,@variables             nvarchar(max)    = NULL - Comma separated lists of environment variables to list. Supports wildcards.
                                                      Only variables matching provided pattern are returned
    ,@value                 nvarchar(max)    = NULL - Comma separated list of environment variable values. Supports wildcards.
                                                      Only variables which value in string representation matches provided pattern are listed.
                                                      Ideal when need to find all environments and variables using particular value.
                                                      Eg. Updating to new password.
    ,@exactValue            nvarchar(max)    = NULL - Exact value of variables to be matched. Only one of @exactValue and @value can be specified at a time
    ,@decryptSensitive      bit              = 0    - Specifies whether sensitive data should be decrypted.
                                                      Caller must be member of [db_owner] or [ssis_sensitive_access] database role or member of [sysadmin] server role
                                                      to be able to decrypt sensitive information
    ', 0, 0) WITH NOWAIT;
RAISERROR(N'
Wildcards:
    Wildcards are standard wildcards for the LIKE statement
    Entries prefixed with [-] (minus) symbol are excluded form results and have priority over the non excluding

    Samples:
    sp_SSISListEnvironment @folder = N''TEST%%,DEV%%,-%%Backup'' = List all environment variables from folders starting with ''TEST'' or ''DEV'' but exclude all folder names ending with ''Backup''

    List varibles from all folders and environments starting with OLEDB_ and ending with _Password and containing value "AAA" or "BBB"
    sp_SSISListEnvironment
        @folder         = ''%%''
        ,@environment   = ''%%''
        ,@variables     = ''OLEDB_%%_Password''
        ,@value         = ''AAA,BBB''
    ', 0, 0) WITH NOWAIT;

RAISERROR(N'
Table for output resultset:
---------------------------
CREATE TABLE #outputTable (
        [FolderID]             bigint
    ,[EnvironmentID]        bigint
    ,[VariableID]           bigint
    ,[FolderName]           nvarchar(128)
    ,[EnvironmentName]      nvarchar(128)
    ,[VariableName]         nvarchar(128)
    ,[Value]                sql_variant
    ,[VariableDescription]  nvarchar(1024)
    ,[VariableType]         nvarchar(128)
    ,[BaseDataType]         nvarchar(128)
    ,[IsSensitive]          bit
)
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
    )
    SELECT DISTINCT
        E.folder_id
        ,E.environment_id
        ,F.folder_name
        ,E.environment_name
    FROM internal.environments E
    INNER JOIN @folders F ON E.folder_id = F.folder_id
    INNER JOIN EnvironmentNames EN ON E.environment_name LIKE EN.EnvName AND LEFT(EN.EnvName, 1) <> '-'
    EXCEPT
    SELECT
        E.folder_id
        ,E.environment_id
        ,F.folder_name
        ,E.environment_name
    FROM internal.environments E
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

    --Get variable names list
    SET @xml = N'<i>' + REPLACE(ISNULL(@variables, N'%'), ',', '</i><i>') + N'</i>';
    INSERT INTO @variableNames (
        Name
    )
    SELECT DISTINCT
        LTRIM(RTRIM(V.value(N'.', N'nvarchar(128)'))) AS VariableName
    FROM @xml.nodes(N'/i') T(V);

    --Output the result
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
                WHEN ev.[sensitive] = 0                                                     THEN [value]
                WHEN ev.[sensitive] = 1 AND @decryptSensitive = 1 AND @sensitiveAccess = 1  THEN [internal].[get_value_by_data_type](DECRYPTBYKEYAUTOCERT(CERT_ID(N'MS_Cert_Env_' + CONVERT(nvarchar(20), ev.environment_id)), NULL, ev.[sensitive_value]), ev.[type])
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
    SELECT
        FolderID
        ,EnvironmentID
        ,VariableID
        ,FolderName
        ,EnvironmentName
        ,VariableName
        ,Value
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
    ORDER BY FolderName, EnvironmentName, VariableName
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
GRANT EXECUTE ON [dbo].[sp_SSISListEnvironment] TO [ssis_admin]
GO
