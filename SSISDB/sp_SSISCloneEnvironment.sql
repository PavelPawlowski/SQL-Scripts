USE [SSISDB]
GO
IF NOT EXISTS(SELECT * FROM sys.procedures WHERE object_id = OBJECT_ID('[dbo].[sp_SSISCloneEnvironment]'))
    EXEC (N'CREATE PROCEDURE [dbo].[sp_SSISCloneEnvironment] AS PRINT ''Placeholder for [dbo].[sp_SSISCloneEnvironment]''')
GO
/* ****************************************************
usp_SSISCloneEnvironment v 0.10 (2016-10-10)
(C) 2016 Pavel Pawlowski

Feedback: mailto:pavel.pawlowski@hotmail.cz

License: 
    sp_SSISCloneEnvironment is free to download and use for personal, educational, and internal 
    corporate purposes, provided that this header is preserved. Redistribution or sale 
    of sp_SSISCloneEnvironment, in whole or in part, is prohibited without the author's express 
    written consent.

Description:
    Clones SSIS environment variables from one environment to another.
    Allows scripting of the environments to allow easy transfer among environments.

Parameters:
     @sourceFolder              nvarchar(128)           --Name of the Source Folder from which the environment should be cloned
    ,@sourceEnvironment         nvarchar(128)           --Name of the Source Environemnt to be cloned
    ,@destinationFolder         nvarchar(128)           --Name of the destination folder to which the Environment should be cloned
    ,@destinationEnvironment    nvarchar(128)   = NULL  --Name of the desntination Environment to which the source environment should be cloned. 
                                                        --When NULL @sourceEnvironment is being used
    ,@autoCreate                bit             = 1     --Specifies whether the destination Folder/Environment should be auto-created if not exists
    ,@printScript               bit             = 0     --Specifies whether script for the variables should be generated
    ,@decryptSensitiveInScript  bit             = 0     --Specifies whether sensitive data shuld be descrypted in script. Otherwise it extracts NULLs for the sensitive data in Script
 ******************************************************* */
ALTER PROCEDURE [dbo].[sp_SSISCloneEnvironment]
     @sourceFolder              nvarchar(128)   = NULL  --Name of the Source Folder from which the environment should be cloned
    ,@sourceEnvironment         nvarchar(128)   = NULL  --Name of the Source Environemnt to be cloned
    ,@destinationFolder         nvarchar(128)   = NULL  --Name of the destination folder to which the Environment should be cloned
    ,@destinationEnvironment    nvarchar(128)   = NULL  --Name of the desntination Environment to which the source environment should be cloned. When NULL @sourceEnvironment is being used
    ,@autoCreate                bit             = 1     --Specifies whether the destination Folder/Environment should be auto-created if not exists
    ,@printScript               bit             = 0     --Specifies whether script for the variables should be generated
    ,@decryptSensitiveInScript  bit             = 0     --Specifies whether sensitive data shuld be descrypted in script. Otherwise it extracts NULLs for the sensitive data in Script
WITH EXECUTE AS 'AllSchemaOwner'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @src_folder_id                  bigint                  --ID of the source folder
        ,@src_Environment_id            bigint                  --ID of thesource Environment
        ,@dst_folder_id                 bigint                  --ID of the destination folder
        ,@dst_Environment_id            bigint                  --ID of the destination environment
        ,@captionBegin                  nvarchar(50)    = N''   --Beginning of the caption for the purpose of the catpion printing
        ,@captionEnd                    nvarchar(50)    = N''   --End of the caption linef or the purpose of the caption printing
        ,@caption                       nvarchar(max)           --sp_SSISCloneEnvironment caption
        ,@msg                           nvarchar(max)           --General purpose message variable (used for printing output)
        ,@printHelp                     bit             = 0     --Identifies whether Help should be printed (in case of no parameters provided or error)
        ,@name                          sysname                 --Name of the variable
        ,@description                   nvarchar(1024)          --Description of the variable
        ,@type                          nvarchar(128)           --DataType of the variable
        ,@sensitive                     bit                     --Identifies sensitive variable
        ,@value                         sql_variant             --Non sensitive value of the variable
        ,@sensitive_value               varbinary(max)          --Sensitive value of the variable
        ,@base_data_type                nvarchar(128)           --Base data type of the variable
        ,@sql                           nvarchar(max)           --Variable for storing dynamic SQL statements
        ,@src_keyName                   nvarchar(256)           --Name of the symmetric key for decryption of the source sensitive values from the source environment
        ,@src_certificateName           nvarchar(256)           --Name of the certificate for decryption of the source symmetric key
        ,@dst_keyName                   nvarchar(256)           --Name of the symmetric key for encryption of the sensitive values in destination environment
        ,@dst_certificateName           nvarchar(256)           --Name of the certificate fo descryption of the destination symmetric key
        ,@decrypted_value               varbinary(max)          --Variable to store decrypted sensitive value

    --If the needed input parameters are null, print help
    IF @sourceFolder IS NULL OR @sourceEnvironment IS NULL OR  @destinationFolder IS NULL
        SET @printHelp = 1

	--Set and print the procedure output caption
    IF (@printScript = 1 AND @printHelp = 0)
    BEGIN
        SET @captionBegin = N'RAISERROR(N''';
        SET @captionEnd = N''', 0, 0) WITH NOWAIT;';
    END

	SET @caption =  @captionBegin + N'sp_SSISCloneEnvironment v0.10 (2016-10-10) (C) 2016 Pavel Pawlowski' + @captionEnd + NCHAR(13) + NCHAR(10) + 
					@captionBegin + N'===================================================================' + @captionEnd + NCHAR(13) + NCHAR(10);
	RAISERROR(@caption, 0, 0) WITH NOWAIT;
    RAISERROR(N'', 0, 0) WITH NOWAIT;

    --Set Destination ENvironment Name in case of NULL       
    SET @destinationEnvironment = ISNULL(@destinationEnvironment, @sourceEnvironment)

    IF @printHelp = 0
    BEGIN 
        --get source folder_id
        SELECT
            @src_folder_id = folder_id
        FROM internal.folders f
        WHERE f.name = @sourceFolder;

        --check source folder
        IF @src_folder_id IS NULL
        BEGIN
            RAISERROR(N'Source Folder [%s] does not exists', 15, 1, @sourceFolder) WITH NOWAIT;
            RETURN;
        END
    END

    IF @printHelp = 0
    BEGIN 
        --get source environment_id
        SELECT
            @src_Environment_id = environment_id
        FROM [catalog].environments e
        WHERE
            e.folder_id = @src_folder_id
            AND
            e.name = @sourceEnvironment;

        --chek source environment
        IF @src_Environment_id IS NULL
        BEGIN
            RAISERROR(N'Source Environment [%s]\[%s] does not exists', 15, 2, @sourceFolder, @sourceEnvironment) WITH NOWAIT;
            RETURN;
        END
    END

    IF @printHelp = 0
    BEGIN 

        IF @printScript = 0 --if not priting the script, get the folder ID check that the folder exists and eventually craete it
        BEGIN
            --get destination folder_id
            SELECT
                @dst_folder_id = folder_id
            FROM internal.folders f
            WHERE f.name = @destinationFolder;

            --check destination folder
            IF @dst_folder_id IS NULL
            BEGIN
                IF NOT (@autoCreate = 1)
                BEGIN
                    RAISERROR(N'Destination Folder [%s] soes not exists @autoCreate <> 1', 15, 3, @destinationFolder) WITH NOWAIT;
                    RETURN;
                END
                ELSE
                BEGIN        
                    RAISERROR(N'Creating missing Folder [%s]', 0, 0, @destinationFolder) WITH NOWAIT;
                    EXECUTE AS CALLER;  --Change the execution context to the caller of the stored proc to allow creation of the folder
                    EXEC [catalog].[create_folder] @folder_name=@destinationFolder, @folder_id=@dst_folder_id OUTPUT
                    REVERT; --Revert the execution context
                END
            END
        END
        ELSE
        BEGIN
            RAISERROR(N'DECLARE @destinationFolder nvarchar(128) = N''%s'' --Specify Destination Folder Name', 0, 0, @destinationFolder) WITH NOWAIT;
            RAISERROR(N'DECLARE @destinationEnvironment nvarchar(128) = N''%s'' --Specify Destination Environment Name', 0, 0, @destinationEnvironment) WITH NOWAIT;
            RAISERROR(N'', 0, 0) WITH NOWAIT;

            IF @autoCreate = 1 --If printing script and @autoCrate = 1, generate check and eventual creation of the folder
            BEGIN
                RAISERROR(N'IF NOT EXISTS(SELECT 1 FROM [SSISDB].[catalog].[folders] WHERE [name] = @destinationFolder)', 0, 0) WITH NOWAIT;
                RAISERROR(N'BEGIN', 0, 0 ) WITH NOWAIT;
                RAISERROR(N'    RAISERROR(N''Creating missing Folder [%%s]'', 0, 0, @destinationFolder) WITH NOWAIT;', 0, 0) WITH NOWAIT;                
                RAISERROR(N'    EXEC [SSISDB].[catalog].[create_folder] @folder_name = @destinationFolder', 0, 0) WITH NOWAIT;
                RAISERROR(N'END', 0, 0 ) WITH NOWAIT;
            END
        END
    END

    IF @printHelp = 0
    BEGIN 
        IF @printScript = 0 --if not priting the script, get the environment ID check that the environment exists and eventually craete it
        BEGIN
            --Get the destination environment_id
            SELECT
                @dst_Environment_id = environment_id
            FROM [catalog].environments e
            WHERE
                e.folder_id = @dst_folder_id
                AND
                e.name = @destinationEnvironment

            --Check Destiantion environment
            IF @dst_Environment_id IS NULL
            BEGIN
                IF NOT (@autoCreate = 1)
                BEGIN
                    RAISERROR('Destination environment [%s]\[%s] does not exists and @autoCreate <> 1', 15, 4, @destinationFolder, @destinationEnvironment) WITH NOWAIT;
                    RETURN;
                END
                ELSE
                BEGIN
                    RAISERROR(N'Creating missing Environment [%s]\[%s]', 0, 0, @destinationFolder, @destinationEnvironment) WITH NOWAIT;
                    EXECUTE AS CALLER;  --Change the execution context to the caller of the stored procedure to allow creation of the environment
                    EXEC [catalog].[create_environment] @environment_name=@destinationEnvironment, @environment_description=N'', @folder_name=@destinationFolder
                    REVERT; --Revert the execution context

                    SELECT
                        @dst_Environment_id = environment_id
                    FROM [catalog].environments e
                    WHERE
                        e.folder_id = @dst_folder_id
                        AND
                        e.name = @destinationEnvironment
                END
            END
        END
        ELSE 
        BEGIN
            IF @autoCreate = 1 --If printing script and @autoCrate = 1, generate check and eventual creation of the environment
            BEGIN
                RAISERROR(N'IF NOT EXISTS(', 0, 0) WITH NOWAIT;
                RAISERROR(N'    SELECT 1', 0, 0) WITH NOWAIT;
                RAISERROR(N'    FROM [SSISDB].[catalog].[environments] e', 0, 0) WITH NOWAIT;
                RAISERROR(N'    INNER JOIN [SSISDB].[catalog].[folders] f ON f.folder_id = e.folder_id', 0, 0) WITH NOWAIT;
                RAISERROR(N'    WHERE f.[name] = @destinationFolder AND e.[name] = @destinationEnvironment', 0, 0) WITH NOWAIT;
                RAISERROR(N')', 0, 0) WITH NOWAIT;
                RAISERROR(N'BEGIN', 0, 0) WITH NOWAIT;
                RAISERROR(N'    RAISERROR(N''Creating missing Environment [%%s]\[%%s]'', 0, 0, @destinationFolder, @destinationEnvironment) WITH NOWAIT', 0, 0) WITH NOWAIT;
                RAISERROR(N'    EXEC [SSISDB].[catalog].[create_environment] @folder_name = @destinationFolder, @environment_name = @destinationEnvironment, @environment_description = N''''', 0, 0) WITH NOWAIT;
                RAISERROR(N'END', 0, 0) WITH NOWAIT;
            END
            ELSE
            BEGIN
                RAISERROR(N'IF NOT EXISTS(', 0, 0) WITH NOWAIT;
                RAISERROR(N'    SELECT 1', 0, 0) WITH NOWAIT;
                RAISERROR(N'    FROM [SSISDB].[catalog].[environments] e', 0, 0) WITH NOWAIT;
                RAISERROR(N'    INNER JOIN [SSISDB].[catalog].[folders] f ON f.folder_id = e.folder_id', 0, 0) WITH NOWAIT;
                RAISERROR(N'    WHERE f.[name] = @destinationFolder AND e.[name] = @destinationEnvironment', 0, 0) WITH NOWAIT;
                RAISERROR(N')', 0, 0) WITH NOWAIT;
                RAISERROR(N'BEGIN', 0, 0) WITH NOWAIT;
                RAISERROR(N'    RAISERROR(N''Destination environment [%%s]\[%%s] does not exist.'', 15, 0, @destinationFolder, @destinationEnvironment) WITH NOWAIT', 0, 0) WITH NOWAIT;
                RAISERROR(N'    RETURN', 0, 0) WITH NOWAIT;
                RAISERROR(N'END', 0, 0) WITH NOWAIT;
            END
        END
    END

    --PRINT HELP
    IF @printHelp = 1
    BEGIN
        RAISERROR(N'', 0, 0) WITH NOWAIT; 
        RAISERROR(N'Clones SSIS environment variables from one environment to another', 0, 0) WITH NOWAIT; 
        RAISERROR(N'Allows scripting of the environments to allow easy transfer among environments.', 0, 0) WITH NOWAIT;
        RAISERROR(N'', 0, 0) WITH NOWAIT; 
        RAISERROR(N'Usage:', 0, 0) WITH NOWAIT; 
        RAISERROR(N'[sp_SSISCloneEnvironment] parameters', 0, 0) WITH NOWAIT; 
        RAISERROR(N'', 0, 0) WITH NOWAIT; 
        SET @msg = N'Parameters:
     @sourceFolder              nvarchar(128)   =       --Name of the Source Folder from which the environment should be cloned
                                                          Source folder is required and must exist
    ,@sourceEnvironment         nvarchar(128)   =       --Name of the Source Environemnt to be cloned
                                                          Source environment is required and must exist
    ,@destinationFolder         nvarchar(128)   =       --Name of the destination folder to which the Environment should be cloned
                                                          Destination folder is required, but may not exists if @autoCreate = 1
    ,@destinationEnvironment    nvarchar(128)   = NULL  --Name of the desntination Environment to which the source environment should be cloned. 
                                                          Destiantion Environment is not required and Source Environment name is used when not provided.
                                                          If Destination Environment does not exists and @autoCreate = 1 then the environment is automatically created
    ,@autoCreate                bit             = 1     --Specifies whether the destination Folder/Environment should be auto-created if not exists
    ,@printScript               bit             = 0     --Specifies whether script for the variables should be generated
    ,@decryptSensitiveInScript  bit             = 0     --Specifies whether sensitive data shuld be descrypted in script.
                                                          Otherwise it extracts NULLs for the sensitive data in Script and data needs to be provided manually
    '
        RAISERROR(@msg, 0, 0) WITH NOWAIT;

        RAISERROR(N'',0, 0) WITH NOWAIT; 

        RETURN;
    END

    --Check that desctination environment is empty
    IF @printScript = 0
    BEGIN
        IF EXISTS(SELECT 1 FROM internal.environment_variables ev WHERE ev.environment_id = @dst_Environment_id)
        BEGIN
            RAISERROR('Destination environment [%s]\[%s] is not empty. Clear all variables prior clonning environment.', 15, 5, @destinationFolder, @destinationEnvironment) WITH NOWAIT;
            RETURN;
        END
    END
    ELSE
    BEGIN
        RAISERROR(N'IF EXISTS (', 0, 0) WITH NOWAIT;
        RAISERROR(N'    SELECT 1', 0, 0) WITH NOWAIT;
        RAISERROR(N'    FROM [SSISDB].[catalog].[environment_variables] ev', 0, 0) WITH NOWAIT;
        RAISERROR(N'    INNER JOIN [SSISDB].[catalog].[environments] e ON e.environment_id = ev.environment_id', 0, 0) WITH NOWAIT;
        RAISERROR(N'    INNER JOIN [SSISDB].[catalog].[folders] f ON f.folder_id = e.folder_id', 0, 0) WITH NOWAIT;
        RAISERROR(N'    WHERE', 0, 0) WITH NOWAIT;
        RAISERROR(N'        f.name = @destinationFolder AND e.name = @destinationEnvironment', 0, 0) WITH NOWAIT;
        RAISERROR(N')', 0, 0) WITH NOWAIT;
        RAISERROR(N'BEGIN', 0, 0) WITH NOWAIT;
        RAISERROR(N'    RAISERROR(N''Destination Environment [%%s]\[%%s] is not empty. Clear all variables prior clonning environment.'', 15, 1, @destinationFolder, @destinationEnvironment) WITH NOWAIT;', 0, 0) WITH NOWAIT;        
        RAISERROR(N'    RETURN;', 0, 0) WITH NOWAIT;
        RAISERROR(N'END', 0, 0) WITH NOWAIT;

    END

    --Set Source and Destiantion Environment keys and Certificates        
    SET @src_keyName = 'MS_Enckey_Env_' + CONVERT(varchar, @src_Environment_id);
    SET @src_certificateName = 'MS_Cert_Env_' + CONVERT(varchar,@src_Environment_id)
    SET @dst_keyName = 'MS_Enckey_Env_' + CONVERT(varchar, @dst_Environment_id);
    SET @dst_certificateName = 'MS_Cert_Env_' + CONVERT(varchar,@dst_Environment_id)

    --Open the Symmetic Keys for Descryption/Encryption
    SET @sql = 'OPEN SYMMETRIC KEY ' + @src_keyName + ' DECRYPTION BY CERTIFICATE ' + @src_certificateName
    EXECUTE sp_executesql @sql
    SET @sql = 'OPEN SYMMETRIC KEY ' + @dst_keyName + ' DECRYPTION BY CERTIFICATE ' + @dst_certificateName
    EXECUTE sp_executesql @sql


    IF @printScript = 0
    BEGIN
        RAISERROR(N'Clonning varaibles from Environment [%s]\[%s] to Environment [%s]\[%s]', 0, 0, @sourceFolder, @sourceEnvironment, @destinationFolder, @destinationEnvironment) WITH NOWAIT;        
    END
    ELSE
    BEGIN
        RAISERROR(N'', 0, 0) WITH NOWAIT;
        RAISERROR(N'DECLARE @var sql_variant', 0, 0) WITH NOWAIT;
    END

    --Declare cursor for iteration over the environment variables
    DECLARE cr CURSOR FAST_FORWARD FOR
        SELECT
            [name]
            ,[description]
            ,[type]
            ,[sensitive]
            ,[value]
            ,[sensitive_value]
            ,[base_data_type]
        FROM [internal].[environment_variables] ev
        WHERE
            ev.environment_id = @src_Environment_id

    OPEN cr;

    --Iterate over the environment variables
    FETCH NEXT FROM cr into @name, @description, @type, @sensitive, @value, @sensitive_value, @base_data_type
    WHILE @@FETCH_STATUS = 0
    BEGIN
        --Decrypt the sensitive_value for the purpose of re-encrypting on printing into the script
        SET @decrypted_value = DECRYPTBYKEY(@sensitive_value)

        IF @printScript = 1 --SCRIPT is being printed - Generate Script
        BEGIN
            RAISERROR(N'RAISERROR(N''Creating variable [SSISDB]\[%%s]\[%%s]\[%s]'', 0, 0, @destinationFolder, @destinationEnvironment) WITH NOWAIT;', 0, 0, @name) WITH NOWAIT;
            
            --Print the variable for storing the value
            SET @msg = 'SET @var = CONVERT(' +
                CASE @base_data_type
                    WHEN 'decimal' THEN 'decimal(28, 18)'
                    WHEN 'nvarchar' THEN 'sql_variant'
                    ELSE @base_data_type
                END + N', '
            
            IF @sensitive = 0  --Print Non-Sensitive value
            BEGIN
                SET @msg = @msg + N'N''' + 
                    CASE 
                        WHEN @type = 'datetime' THEN CONVERT(nvarchar(max), @value, 126)
                        ELSE CONVERT(nvarchar(max), @value) 
                    END + N''');';
            END
            ELSE
            BEGIN
                IF @decryptSensitiveInScript = 0 --If Sensitive value and @descryptSensitiveInScript = 0 then print NULL and information about sensitive removal
                BEGIN
                    SET @msg = @msg + N'NULL); --SENSITIVE REMOVED';
                END
                ELSE
                BEGIN   --Print decrypted sensitive value
                    SET @msg = @msg + N'N''' + 
                        CASE 
                            WHEN @type = 'datetime' THEN CONVERT(nvarchar(max), [internal].[get_value_by_data_type](@decrypted_value, @type), 126)
                            ELSE CONVERT(nvarchar(max), [internal].[get_value_by_data_type](@decrypted_value, @type))
                        END + N'''); --SENSITIVE';
                END
            END

            RAISERROR(@msg, 0, 0) WITH NOWAIT;

            --Generate the 'crate_environment_variable statement
            SET @msg = N'EXEC [SSISDB].[catalog].[create_environment_variable] ' +
                  N'@variable_name=N''' + @name +N'''' +
                N', @data_type=N''' + @type + N'''' +
                N', @sensitive=' + CASE WHEN @sensitive = 1 THEN N'True' ELSE N'False' END + 
                N', @folder_name=@destinationFolder' +
                N', @environment_name=@destinationEnvironment' +
                N', @value=@var' +
                N', @description=N''' + @description + N'''';
        
            RAISERROR(@msg, 0, 0) WITH NOWAIT;

        END
        ELSE --SCRIPT IS NOT BEING PRINTED - Clone the variables
        BEGIN
            RAISERROR(N'Clonning variable [%s]', 0, 0, @name) WITH NOWAIT; 

            --Reencrypt the decrypted value by new key
            SET @sensitive_value = 
                CASE 
                    WHEN @type = 'datetime' THEN EncryptByKey(KEY_GUID(@dst_keyName),CONVERT(varbinary(4000),CONVERT(datetime2,@value)))
                    WHEN @type = 'single' OR @type = 'double' OR @type = 'decimal' THEN EncryptByKey(KEY_GUID(@dst_keyName),CONVERT(varbinary(4000),CONVERT(decimal(38,18),@value)))
                    ELSE EncryptByKey(KEY_GUID(@dst_keyName),CONVERT(varbinary(MAX),@value))   
                END

            --Insert new variable into destination Environment (Do not use the stored procedure so the sensitive data are not revealed in eventual traces
            INSERT INTO [internal].[environment_variables] (
                [environment_id]
                ,[name]
                ,[description]
                ,[type]
                ,[sensitive]
                ,[value]
                ,[sensitive_value]
                ,[base_data_type]
            )
            VALUES (
                @dst_Environment_id
                ,@name
                ,@description
                ,@type
                ,@sensitive
                ,@value
                ,@sensitive_value
                ,@base_data_type
            )
                      
        END

        FETCH NEXT FROM cr into @name, @description, @type, @sensitive, @value, @sensitive_value, @base_data_type
    END
    CLOSE cr;
    DEALLOCATE cr;

    --Close symmetric keys being used during the process
    SET @sql = 'CLOSE SYMMETRIC KEY '+ @src_keyName
    EXECUTE sp_executesql @sql
    SET @sql = 'CLOSE SYMMETRIC KEY '+ @dst_keyName
    EXECUTE sp_executesql @sql
END
GO
--GRANT EXECUTE permission on the stored procedure to [ssis_admin] role
GRANT EXECUTE ON [dbo].[sp_SSISCloneEnvironment] TO [ssis_admin]
GO
