USE [SSISDB]
GO
IF NOT EXISTS(SELECT * FROM sys.procedures WHERE object_id = OBJECT_ID('[dbo].[sp_SSISListEnvironment]'))
    EXEC (N'CREATE PROCEDURE [dbo].[sp_SSISListEnvironment] AS PRINT ''Placeholder for [dbo].[sp_SSISListEnvironment]''')
GO
/* ****************************************************
sp_SSISListEnvironment v 0.31 (2017-10-11)
(C) 2017 Pavel Pawlowski

Feedback: mailto:pavel.pawlowski@hotmail.cz

License: 
    sp_SSISListEnvironment is free to download and use for personal, educational, and internal 
    corporate purposes, provided that this header is preserved. Redistribution or sale 
    of sp_SSISListEnvironment, in whole or in part, is prohibited without the author's express 
    written consent.

Description:
    List Environmetn variables and their values for environments specified by paramters.
    Allows decryption of encrypted variable values

Parameters:
     @folder                nvarchar(max)    = NULL --comma separated list of environment folder. supports wildcards
    ,@environment           nvarchar(max)    = NULL --comma separated lists of environments.  support wildcards
    ,@variables             nvarchar(max)    = NULL --Comma separated lists of environment varaibles to list. Supports wildcards
    ,@value                 nvarchar(max)    = NULL --Comma separated list of envirnment variable values. Supports wildcards
    ,@exactValue            nvarchar(max)    = NULL --Exact value of variables to be matched. Have priority above value
    ,@decryptSensitive      bit              = 0    --Specifies whether sensitive data shuld be descrypted.
 ******************************************************* */
ALTER PROCEDURE [dbo].[sp_SSISListEnvironment]
     @folder                nvarchar(max)    = NULL --comma separated list of environment folder. supports wildcards
    ,@environment           nvarchar(max)    = NULL --comma separated lists of environments.  support wildcards
    ,@variables             nvarchar(max)    = NULL --Comma separated lists of environment varaibles to list. Supports wildcards
    ,@value                 nvarchar(max)    = NULL --Comma separated list of envirnment variable values. Supports wildcards
    ,@exactValue            nvarchar(max)    = NULL --Exact value of variables to be matched. Have priority above value
    ,@decryptSensitive      bit              = 0    --Specifies whether sensitive data shuld be descrypted.
WITH EXECUTE AS 'AllSchemaOwner'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @src_folder_id                  bigint                  --ID of the source folder
        ,@src_Environment_id            bigint                  --ID of thesource Environment
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


    DECLARE @folders TABLE (
        folder_id       bigint
        ,folder_name    nvarchar(128)
    )

    DECLARE @variableNames TABLE (
        name    nvarchar(128)
    )

    DECLARE @values TABLE (
        Value   nvarchar(4000)
    )

    DECLARE @environments TABLE (
        FolderID            bigint
        ,EnvironmentID      bigint
        ,FolderName         nvarchar(128)
        ,EnvironmentName    nvarchar(128)
    )

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
        ,IsSensitive            bit
    )


    --If the needed input parameters are null, print help
    IF @folder IS NULL OR @environment IS NULL
        SET @printHelp = 1

	RAISERROR(N'sp_SSISListEnvironment v0.31 (2017-10-11) (C) 2017 Pavel Pawlowski', 0, 0) WITH NOWAIT;
	RAISERROR(N'==================================================================' , 0, 0) WITH NOWAIT;

    IF @value IS NOT NULL AND @exactValue IS NOT NULL
    BEGIN
        RAISERROR(N'Only @value or @exactValue can be specified at a time', 11, 0) WITH NOWAIT;
        SET @printHelp = 1
    END



    --PRINT HELP
    IF @printHelp = 1
    BEGIN
        RAISERROR(N'', 0, 0) WITH NOWAIT; 
        RAISERROR(N'Lists SSIS environment variables and allows seeing encrypted invormation', 0, 0) WITH NOWAIT; 
        RAISERROR(N'', 0, 0) WITH NOWAIT; 
        RAISERROR(N'Usage:', 0, 0) WITH NOWAIT; 
        RAISERROR(N'[sp_SSISListEnvironment] parameters', 0, 0) WITH NOWAIT; 
        RAISERROR(N'', 0, 0) WITH NOWAIT; 
        SET @msg = N'Parameters:
     @folder                nvarchar(max)    = NULL - Comma separated list of environment folders. Supports wildcards.
                                                      Only variables from environment beloging to matched folder are listed
    ,@environment           nvarchar(max)    = NULL - Comma separated lists of environments.  Support wildcards.
                                                      Only variables from environments matching provided list are returned.
    ,@variables             nvarchar(max)    = NULL - Comma separated lists of environment varaibles to list. Supports wildcards.
                                                      Only variables matching provided pattern are returned
    ,@value                 nvarchar(max)    = NULL - Comma separated list of envirnment variable values. Supports wildcards.
                                                      Only variables wich value in string representaion matches provided pattern are listed.
                                                      Ideal when need to find all environments and variables using particular value.
                                                      Eg. Updating to new password.
    ,@exactValue            nvarchar(max)    = NULL - Exact value of variables to be matched. Only one of @exactvalue and @value can be specified at a time
    ,@decryptSensitive      bit              = 0    - Specifies whether sensitive data shuld be descrypted.'
RAISERROR(N'
Wildcards:
    Wildcards are standard wildcards for the LIKE statement
    Entries prefixed with [-] (minus) symbol are excluded form results.

    Samples:
    sp_SSISListEnvironment @folder = N''TEST%%,DEV%%,-%%Backup'' = List all environment varaibles from folders starting with ''TEST'' or ''DEV'' but exclude all folder names ending with ''Backup''

    List varaibles from all folders and evironments starting with OLEDB_ and ending with _Password and containing value "AAA" or "BBB"
    sp_SSISListEnvironment
        @folder         = ''%%''
        ,@environment   = ''%%''
        ,@variables     = ''OLEDB_%%_Password''
        ,@value         = ''AAA,BBB''
    ', 0, 0) WITH NOWAIT;
        RAISERROR(@msg, 0, 0) WITH NOWAIT;

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


    --Get variable values list
    SET @xml = N'<i>' + REPLACE(@value, ',', '</i><i>') + N'</i>';

    INSERT INTO @values (Value)
    SELECT DISTINCT
        LTRIM(RTRIM(V.value(N'.', N'nvarchar(4000)'))) AS Value
    FROM @xml.nodes(N'/i') T(V)


    IF NOT EXISTS(SELECT 1 FROM @environments)
    BEGIN
        RAISERROR(N'No Environments matching [%s] exists in folders matching [%s]', 15, 2, @environment, @folder) WITH NOWAIT;
        RETURN;
    END

    IF @variables IS NULL
    BEGIN
        INSERT INTO @variableNames(name) VALUES(N'%')
    END
    ELSE
    BEGIN
        SET @xml = N'<i>' + REPLACE(@variables, ',', '</i><i>') + N'</i>';
        INSERT INTO @variableNames (
            Name
        )
        SELECT DISTINCT
            LTRIM(RTRIM(V.value(N'.', N'nvarchar(128)'))) AS VariableName
        FROM @xml.nodes(N'/i') T(V)    
    END

    DECLARE ec CURSOR FAST_FORWARD FOR
    SELECT
        EnvironmentID
        ,FolderID
        ,FolderName
        ,EnvironmentName
    FROM @environments

    OPEN ec;

    FETCH NEXT FROM ec INTO @src_environment_id, @src_folder_id, @src_folder_name, @src_environment_name

    WHILE @@FETCH_STATUS = 0
    BEGIN
        --Set Source and Destiantion Environment keys and Certificates        
        SET @src_keyName = 'MS_Enckey_Env_' + CONVERT(varchar, @src_Environment_id);
        SET @src_certificateName = 'MS_Cert_Env_' + CONVERT(varchar,@src_Environment_id)

        --Open the Symmetic Keys for Descryption/Encryption
        SET @sql = 'OPEN SYMMETRIC KEY ' + @src_keyName + ' DECRYPTION BY CERTIFICATE ' + @src_certificateName
        EXECUTE sp_executesql @sql


        --Declare cursor for iteration over the environment variables
        DECLARE cr CURSOR FAST_FORWARD FOR
            SELECT DISTINCT
                 ev.variable_id
                ,ev.[name]
                ,ev.[description]
                ,ev.[type]
                ,ev.[sensitive]
                ,ev.[value]
                ,ev.[sensitive_value]
                ,ev.[base_data_type]
            FROM [internal].[environment_variables] ev
            INNER JOIN @variableNames vn ON ev.name LIKE vn.name AND LEFT(vn.name, 1) <> '-'
            WHERE
                ev.environment_id = @src_Environment_id
            EXCEPT
            SELECT 
                 ev.variable_id
                ,ev.[name]
                ,ev.[description]
                ,ev.[type]
                ,ev.[sensitive]
                ,ev.[value]
                ,ev.[sensitive_value]
                ,ev.[base_data_type]
            FROM [internal].[environment_variables] ev
            INNER JOIN @variableNames vn ON ev.name LIKE RIGHT(vn.name, LEN(vn.name) -1) AND LEFT(vn.name, 1) = '-'
            WHERE
                ev.environment_id = @src_Environment_id


        OPEN cr;

        --Iterate over the environment variables
        FETCH NEXT FROM cr into @variable_id, @name, @description, @type, @sensitive, @valueInternal, @sensitive_value, @base_data_type
        WHILE @@FETCH_STATUS = 0
        BEGIN
            --Decrypt the sensitive_value for the purpose of re-encrypting on printing into the script
            SET @decrypted_value = DECRYPTBYKEY(@sensitive_value)

            SELECT
                @valueInternal =CASE 
                                    WHEN @sensitive = 0                             THEN @valueInternal
                                    WHEN @sensitive = 1 AND @decryptSensitive = 1   THEN [internal].[get_value_by_data_type](@decrypted_value, @type)
                                    ELSE NULL
                                END

            SELECT
                @stringval = CASE
                                WHEN @type = 'datetime' THEN CONVERT(nvarchar(50), @valueInternal, 126)
                                ELSE CONVERT(nvarchar(4000), @valueInternal)
                            END            

            IF ((@value IS NULL OR @value = N'%') AND @exactValue IS NULL) OR (@exactValue IS NOT NULL AND @stringval = @exactValue)  OR EXISTS (
                SELECT
                    Value
                FROM @values v
                WHERE
                    @exactValue IS NULL
                    AND
                    LEFT(v.Value, 1) <> '-'
                    AND
                    @stringval LIKE v.Value
                EXCEPT
                SELECT
                    Value
                FROM @values v
                WHERE
                    LEFT(v.Value, 1) = '-'
                    AND
                    @stringval LIKE RIGHT(v.Value, LEN(v.Value) - 1)
            )
            BEGIN            
                INSERT INTO @outputTable (
                    FolderID
                    ,FolderName
                    ,EnvironmentID
                    ,EnvironmentName
                    ,VariableID
                    ,VariableName
                    ,VariableDescription
                    ,VariableType
                    ,BaseDataType
                    ,Value
                    ,IsSensitive
                )
                VALUES (
                     @src_folder_id
                    ,@src_folder_name
                    ,@src_Environment_id
                    ,@src_environment_name
                    ,@variable_id
                    ,@name
                    ,@description
                    ,@type
                    ,@base_data_type
                    ,@valueInternal
                    ,@sensitive
                )
            END
            FETCH NEXT FROM cr into @variable_id, @name, @description, @type, @sensitive, @valueInternal, @sensitive_value, @base_data_type
        END
        CLOSE cr;
        DEALLOCATE cr;

        --Close symmetric keys being used during the process
        SET @sql = 'CLOSE SYMMETRIC KEY '+ @src_keyName
        EXECUTE sp_executesql @sql

        FETCH NEXT FROM ec INTO @src_environment_id, @src_folder_id, @src_folder_name, @src_environment_name
    END

    CLOSE ec;
    DEALLOCATE ec;

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
    FROM @outputTable
    ORDER BY FolderName, EnvironmentName, VariableName
END

GO
--GRANT EXECUTE permission on the stored procedure to [ssis_admin] role
GRANT EXECUTE ON [dbo].[sp_SSISListEnvironment] TO [ssis_admin]
GO
