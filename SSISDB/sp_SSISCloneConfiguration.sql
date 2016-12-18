USE [SSISDB]
GO
IF NOT EXISTS(SELECT * FROM sys.procedures WHERE object_id = OBJECT_ID('[dbo].[sp_SSISCloneConfiguration]'))
    EXEC (N'CREATE PROCEDURE [dbo].[sp_SSISCloneConfiguration] AS PRINT ''Placeholder for [dbo].[sp_SSISCloneConfiguration]''')
GO
/* ****************************************************
sp_SSISCloneConfiguration v 0.10 (2016-12-18)
(C) 2016 Pavel Pawlowski

Feedback: mailto:pavel.pawlowski@hotmail.cz

License: 
    sp_SSISCloneConfiguration is free to download and use for personal, educational, and internal 
    corporate purposes, provided that this header is preserved. Redistribution or sale 
    of sp_SSISCloneConfiguration, in whole or in part, is prohibited without the author's express 
    written consent.

Description:
    Clones SSIS Project Configurations from one project to another.
    Allows scripting of the configurations for easy transfer among environments.

Parameters:
     @sourceFolder              nvarchar(128)   =       --Name of the Source Folder from which the project configuraiont should be cloned
    ,@sourceProject             nvarchar(128)   =       --Name of the Source Project to clone configurations
	,@sourceObject              nvarchar(260)	= NULL  --Name of the Source Object to clone configurations

    ,@destinationFolder         nvarchar(128)   = NULL  --Name of the destination folder to which the project configuration
    ,@destinationProject		nvarchar(128)   = NULL  --Name of the desntination project to which the source project configuraiont should be cloned.

    ,@printScript               bit             = 0     --Specifies whether script for the variables should be generated
    ,@decryptSensitiveInScript  bit             = 1     --Specifies whether sensitive data shuld be descrypted in script. Otherwise it extracts NULLs for the sensitive data in Script
 ******************************************************* */
ALTER PROCEDURE [dbo].[sp_SSISCloneConfiguration]
     @sourceFolder              nvarchar(128)   = NULL  --Name of the Source Folder from which the project configuraiont should be cloned
    ,@sourceProject             nvarchar(128)   = NULL  --Name of the Source Project to clone configurations
	,@sourceObject              nvarchar(260)	= NULL	--Name of the Source Object to clone configurations

    ,@destinationFolder         nvarchar(128)   = NULL  --Name of the destination folder to which the project configuration
    ,@destinationProject		nvarchar(128)   = NULL  --Name of the desntination project to which the source project configuraiont should be cloned.

    ,@printScript               bit             = 0     --Specifies whether script for the variables should be generated
    ,@decryptSensitiveInScript  bit             = 0     --Specifies whether sensitive data shuld be descrypted in script. Otherwise it extracts NULLs for the sensitive data in Script
WITH EXECUTE AS 'AllSchemaOwner'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
         @src_folder_id                 bigint                  --ID of the source folder
		,@src_project_id                bigint					--ID of the source project
		,@src_project_lsn               bigint					--current source project lsn

        ,@dst_folder_id                 bigint                  --ID of the destination folder
        ,@dst_project_id                bigint					--ID of the destination project

        ,@captionBegin                  nvarchar(50)    = N''   --Beginning of the caption for the purpose of the catpion printing
        ,@captionEnd                    nvarchar(50)    = N''   --End of the caption linef or the purpose of the caption printing
        ,@caption                       nvarchar(max)           --sp_SSISCloneEnvironment caption
        ,@msg                           nvarchar(max)           --General purpose message variable (used for printing output)
        ,@msg2                          nvarchar(max)           --General purpose message variable (used for printing output)
        ,@printHelp                     bit             = 0     --Identifies whether Help should be printed (in case of no parameters provided or error)


        ,@object_type                   smallint				--Object type from object configuration
        ,@object_name                   nvarchar(260)			--Object name in the objects configurations
        ,@parameter_name                nvarchar(128)			--Parameter name in the objects configurations
        ,@parameter_data_type           nvarchar(128)			--Tada type of the parameter
        ,@sensitive                     bit                     --Identifies sensitive parameter
        ,@default_value                 sql_variant             --Non sensitive value of the parameter
        ,@sensitive_default_value       varbinary(max)          --Sensitive value of the parameterr
        ,@base_data_type                nvarchar(128)           --Base data type of the parameter
        ,@value_type                    char(1)					--Specifies the value type of the parameter (V - direct value or R - reference
        ,@referenced_variable_name      nvarchar(128)

        ,@sql                           nvarchar(max)           --Variable for storing dynamic SQL statements
        ,@src_keyName                   nvarchar(256)           --Name of the symmetric key for decryption of the source sensitive values from the source project configuration
        ,@src_certificateName           nvarchar(256)           --Name of the certificate for decryption of the source symmetric key
        ,@decrypted_value               varbinary(max)          --Variable to store decrypted sensitive value
        ,@references_count              int             = 0     --Count of configurations using References

    --If the needed input parameters are null, print help
    IF @sourceFolder IS NULL OR @sourceProject IS NULL 
        SET @printHelp = 1

    --Set Destination Folder and Environment Name in case of NULL       
    SELECT
         @destinationFolder     = ISNULL(@destinationFolder, @sourceFolder)
        ,@destinationProject    = ISNULL(@destinationProject, @sourceProject)
        
    --force @printScript = 1 in case source = destination
    IF @sourceFolder = @destinationFolder AND @sourceProject = @destinationProject
        SET @printScript = 1


	--Set and print the procedure output caption
    IF (@printScript = 1 AND @printHelp = 0)
    BEGIN
        SET @captionBegin = N'RAISERROR(N''';
        SET @captionEnd = N''', 0, 0) WITH NOWAIT;';
    END

	SET @caption =  @captionBegin + N'sp_SSISCloneConfiguration v0.10 (2016-12-18) (C) 2016 Pavel Pawlowski' + @captionEnd + NCHAR(13) + NCHAR(10) + 
					@captionBegin + N'=====================================================================' + @captionEnd + NCHAR(13) + NCHAR(10);
	RAISERROR(@caption, 0, 0) WITH NOWAIT;
    RAISERROR(N'', 0, 0) WITH NOWAIT;

    --PRINT HELP
    IF @printHelp = 1
    BEGIN
        RAISERROR(N'Clones SSIS Project configuration from one project to another', 0, 0) WITH NOWAIT; 
        RAISERROR(N'Allows scripting of the configurations for easy transfer among environments.', 0, 0) WITH NOWAIT;
        RAISERROR(N'', 0, 0) WITH NOWAIT; 
        RAISERROR(N'Usage:', 0, 0) WITH NOWAIT; 
        RAISERROR(N'[sp_SSISCloneConfiguration] parameters', 0, 0) WITH NOWAIT; 
        RAISERROR(N'', 0, 0) WITH NOWAIT; 
        SET @msg = N'Parameters:
     @sourceFolder              nvarchar(128)   =       --Name of the Source Folder from which the project configuration should be cloned.
                                                          Source folder is required and must exist.
    ,@sourceEnvironment         nvarchar(128)   =       --Name of the Source project which configurations should be clonned.
                                                          Source project is required and must exist.
	,@sourceObject              nvarchar(260)	= NULL  --Name of the Source Object to clone configurations.
                                                          It can point to Project name or concrete package name.
                                                          When provided, then only configurations for that particular object are being clonned.
    ,@destinationFolder         nvarchar(128)   = NULL  --Name of the destination folder to which the project configuration should be cloned.
                                                          Destination folder is optional and if not provided @sourceFolder is being used.
    ,@destinationProject        nvarchar(128)   = NULL  --Name of the destination project to which the source project configuraions should be cloned. 
                                                          Destiantion Project is not required and Source Project name is used when not provided.
                                                          When both @destinationFolder and @destinationProject are NULL or are matching the source
                                                          @printScript = 1 is enforced.
    ,@printScript               bit             = 0     --Specifies whether script for clonning should be generated or configuration should be clonned immediatelly.
    ,@decryptSensitiveInScript  bit             = 0     --Specifies whether sensitive data shuld be descrypted in script.
                                                          Otherwise it extracts NULLs for the sensitive data in Script and data needs to be provided manually
    '
        RAISERROR(@msg, 0, 0) WITH NOWAIT;

        RAISERROR(N'',0, 0) WITH NOWAIT; 

        RETURN;
    END

    --get source folder_id
    SELECT
        @src_folder_id = folder_id
    FROM internal.folders f
    WHERE f.name = @sourceFolder;

    --check source folder
    IF @src_folder_id IS NULL
    BEGIN
        RAISERROR(N'Source Folder [%s] does not exists.', 15, 1, @sourceFolder) WITH NOWAIT;
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
        p.name = @sourceProject;


    --chek source project
    IF @src_project_id IS NULL
    BEGIN
        RAISERROR(N'Source Project [%s]\[%s] does not exists.', 15, 2, @sourceFolder, @sourceProject) WITH NOWAIT;
        RETURN;
    END

    --check Source Object in case is does not equals to project
    if @sourceObject IS NOT NULL AND @sourceObject <> @sourceProject
    BEGIN
        IF NOT EXISTS(
            SELECT
            1
            FROM [internal].[object_parameters] op
            WHERE 
                op.project_id = @src_project_id
                AND
                op.project_version_lsn = @src_project_lsn
                AND
                op.object_name = @sourceObject
        )
        BEGIN
            RAISERROR(N'Source Object [%s]\[%s]\[%s] does not exists in configurations.', 15, 3, @sourceFolder, @sourceProject, @sourceObject) WITH NOWAIT;
            RETURN;
        END            
    END


    IF @printScript = 0 --if not priting the script, check that the destination folder and project exists
    BEGIN
        --get destination folder_id
        SELECT
            @dst_folder_id = folder_id
        FROM internal.folders f
        WHERE f.name = @destinationFolder;

        --check destination folder
        IF @dst_folder_id IS NULL
        BEGIN
            RAISERROR(N'Destination Folder [%s] does not exists.', 15, 4, @destinationFolder) WITH NOWAIT;
            RETURN;
        END

        SELECT
             @dst_project_id    = p.project_id
        FROM [catalog].projects p
        WHERE
            p.folder_id = @dst_folder_id
            AND
            p.name = @destinationProject;
       
        IF @dst_project_id IS NULL
        BEGIN
            RAISERROR(N'Destination project [%s]\[%s] does not exists.', 15, 5, @destinationFolder, @destinationProject) WITH NOWAIT;
        END
    END
    ELSE --We are printing script. Generate check script
    BEGIN
        RAISERROR(N'DECLARE @destinationFolder nvarchar(128) = N''%s'' --Specify Destination Folder Name', 0, 0, @destinationFolder) WITH NOWAIT;
        RAISERROR(N'DECLARE @destinationProject nvarchar(128) = N''%s'' --Specify Destination Project Name', 0, 0, @destinationProject) WITH NOWAIT;
        RAISERROR(N'', 0, 0) WITH NOWAIT;

        RAISERROR(N'--Checking for destination folder existence', 0, 0) WITH NOWAIT;
        RAISERROR(N'IF NOT EXISTS(SELECT 1 FROM [SSISDB].[catalog].[folders] WHERE [name] = @destinationFolder)', 0, 0) WITH NOWAIT;
        RAISERROR(N'BEGIN', 0, 0 ) WITH NOWAIT;
        RAISERROR(N'    RAISERROR(N''Destination folder [%%s] does not exists.'', 15, 0, @destinationFolder) WITH NOWAIT;', 0, 0) WITH NOWAIT;                
        RAISERROR(N'    RETURN;', 0, 0) WITH NOWAIT;
        RAISERROR(N'END', 0, 0) WITH NOWAIT;

        RAISERROR(N'--Checking for destination project existence', 0, 0) WITH NOWAIT;
        RAISERROR(N'IF NOT EXISTS(SELECT 1', 0, 0) WITH NOWAIT;
        RAISERROR(N'    FROM [SSISDB].[catalog].[projects] p', 0, 0) WITH NOWAIT;
        RAISERROR(N'    INNER JOIN [SSISDB].[catalog].[folders] f ON f.folder_id = p.folder_id', 0, 0) WITH NOWAIT;
        RAISERROR(N'    WHERE f.name = @destinationFolder AND p.name = @destinationProject)', 0, 0) WITH NOWAIT;
        RAISERROR(N'BEGIN', 0, 0 ) WITH NOWAIT;
        RAISERROR(N'    RAISERROR(N''Destination project [%%s]\[%%s] does not exists.'', 15, 1, @destinationFolder, @destinationProject) WITH NOWAIT;', 0, 0) WITH NOWAIT;                
        RAISERROR(N'    RETURN;', 0, 0) WITH NOWAIT;
        RAISERROR(N'END', 0, 0) WITH NOWAIT;
    END

    --Set Source and Destiantion Environment keys and Certificates        
    SET @src_keyName = 'MS_Enckey_Proj_' + CONVERT(varchar, @src_project_id);
    SET @src_certificateName = 'MS_Cert_Proj_' + CONVERT(varchar, @src_project_id)

    --Open the Symmetic Keys for Descryption/Encryption
    SET @sql = 'OPEN SYMMETRIC KEY ' + @src_keyName + ' DECRYPTION BY CERTIFICATE ' + @src_certificateName
    EXECUTE sp_executesql @sql


    IF @printScript = 0
    BEGIN
        RAISERROR(N'Clonning project configuration from project [%s]\[%s] to project [%s]\[%s]', 0, 0, @sourceFolder, @sourceProject, @destinationFolder, @destinationProject) WITH NOWAIT;        
    END
    ELSE
    BEGIN
        RAISERROR(N'', 0, 0) WITH NOWAIT;
        RAISERROR(N'--Project parameters configuration', 0, 0) WITH NOWAIT;
        RAISERROR(N'DECLARE @var sql_variant', 0, 0) WITH NOWAIT;
    END

    --Declare cursor for iteration over the environment variables
    DECLARE cr CURSOR FAST_FORWARD FOR
    SELECT
        object_type
        ,object_name
        ,parameter_name
        ,parameter_data_type
        ,sensitive
        ,default_value
        ,sensitive_default_value
        ,value_type
        ,referenced_variable_name
    FROM [internal].[object_parameters] op
    WHERE
        op.project_id = @src_project_id
        AND
        op.project_version_lsn = @src_project_lsn
        AND
        (op.object_name = @sourceObject OR @sourceObject IS NULL)
        AND
        op.value_set = 1

    OPEN cr;

    EXECUTE AS CALLER;

    --Iterate over the environment variables
    FETCH NEXT FROM cr into @object_type, @object_name, @parameter_name, @parameter_data_type, @sensitive, @default_value, @sensitive_default_value, @value_type, @referenced_variable_name
    WHILE @@FETCH_STATUS = 0
    BEGIN
        --Decrypt the sensitive_value for the purpose of re-encrypting on printing into the script
        SET @decrypted_value = DECRYPTBYKEY(@sensitive_default_value)

        SET @object_name = CASE WHEN @object_name = @sourceProject THEN @destinationProject ELSE @object_name END

        
        IF @printScript = 1 --SCRIPT is being printed - Generate Script
        BEGIN
            RAISERROR(N'', 0, 0) WITH NOWAIT;
            --TODO: Update the Object Name in case of project
            RAISERROR(N'RAISERROR(N''Creating Configuration [SSISDB]\[%%s]\[%%s]\[%s]\[%s]'', 0, 0, @destinationFolder, @destinationProject) WITH NOWAIT;', 0, 0, @object_name, @parameter_name) WITH NOWAIT;
        END
        ELSE
        BEGIN
            RAISERROR(N'Creating Configuration [SSISDB]\[%s]\[%s]\[%s]\[%s]', 0, 0, @destinationFolder, @destinationProject, @object_name, @parameter_name) WITH NOWAIT;
        END

        SET @msg = '';

        --Get the value in case of value reference
        IF @value_type = 'V'
        BEGIN
            --if sensitive, replace the default_value with decrypted sensitive one
            IF @sensitive = 1
                SET @default_value = [internal].[get_value_by_data_type](@decrypted_value, @parameter_data_type)

            SET @base_data_type = CONVERT(nvarchar(128), SQL_VARIANT_PROPERTY (@default_value, 'BaseType') )

            SET @msg = CASE WHEN @printScript = 1 THEN N'SET @var' ELSE N'DECLARE @var sql_variant' END;

            --Print the variable for storing the value
            SET @msg = @msg +' = CONVERT(' +
                CASE @base_data_type
                    WHEN 'decimal' THEN 'decimal(28, 18)'
                    WHEN 'nvarchar' THEN 'sql_variant'
                    ELSE @base_data_type
                END + N', '
                
            IF @printScript = 1 AND @sensitive = 1 AND @decryptSensitiveInScript = 0
            BEGIN
                SET @msg = @msg + N'NULL); --SENSITIVE REMOVED';
            END
            ELSE
            BEGIN
                SET @msg = @msg + N'N''' + 
                    CASE 
                        WHEN @base_data_type = 'datetime' THEN CONVERT(nvarchar(max), @default_value, 126)
                        ELSE CONVERT(nvarchar(max), @default_value) 
                    END + N''');' + CASE WHEN @sensitive = 1 THEN N' --SENSITIVE' ELSE N'' END;
            END

            SET @msg = @msg + NCHAR(13) + NCHAR(10)
        END
        ELSE
            SET @references_count = @references_count + 1

        SET @msg = @msg + N'EXEC [SSISDB].[catalog].[set_object_parameter_value] ' +
            N'@object_type=' + CONVERT(nvarchar(10), @object_type) +
            N', @parameter_name = N''' + @parameter_name + N'''' +
            N', @object_name = ' + CASE WHEN @object_name = @sourceProject THEN N'@destinationProject' ELSE  N'N''' + @object_name + N'''' END +
            N', @folder_name = ' + CASE WHEN @printScript = 0 THEN N'N''' + @destinationFolder + N'''' ELSE  N'@destinationFolder' END +
            N', @project_name = ' + CASE WHEN @printScript = 0 THEN N'N''' + @destinationProject + N'''' ELSE  N'@destinationProject' END +
            N', @value_type = ' + CASE WHEN @value_type = 'V' THEN N'''V''' ELSE N'''R''' END +
            N', @parameter_value = ' + CASE WHEN @value_type = 'V' THEN N'@var' ELSE  N'N''' + @referenced_variable_name + N'''' END;

		--Print of Execute the script
        IF @printScript = 1
            RAISERROR(@msg, 0, 0) WITH NOWAIT;
        ELSE
            EXEC(@msg); --Execute Script in case of non Printing

        FETCH NEXT FROM cr into @object_type, @object_name, @parameter_name, @parameter_data_type, @sensitive, @default_value, @sensitive_default_value, @value_type, @referenced_variable_name
    END

    REVERT;

    IF @references_count > 0
    BEGIN        
        SET @msg = @captionBegin + N'--------------------------------------------------------------' + REPLICATE(N'-', LEN(@destinationFolder) + LEN(@destinationProject)) + @captionEnd;
        SET @msg2 = @captionBegin + N'There are configurations using Environment varaibles references.' + @captionEnd;

        RAISERROR( @msg, 0, 0) WITH NOWAIT;
        RAISERROR( @msg2, 0, 0) WITH NOWAIT;
        IF @printScript = 1
            SET @msg2 = N'RAISERROR(N''DON''''T FORGET TO SET ENVIRONMENT REFERENCES for project [%%s]\[%%s].'', 0, 0, @destinationFolder, @destinationProject) WITH NOWAIT';
        ELSE
            SET @msg2 = N'DON''T FORGET TO SET ENVIRONMENT REFERENCES for project [%s]\[%s].'

        RAISERROR( @msg2, 0, 0, @destinationFolder, @destinationProject) WITH NOWAIT;
        RAISERROR( @msg, 0, 0) WITH NOWAIT;
    END

    CLOSE cr;
    DEALLOCATE cr;

    --Close symmetric keys being used during the process
    SET @sql = 'CLOSE SYMMETRIC KEY '+ @src_keyName
    EXECUTE sp_executesql @sql
END
GO
--GRANT EXECUTE permission on the stored procedure to [ssis_admin] role
GRANT EXECUTE ON [dbo].[sp_SSISCloneConfiguration] TO [ssis_admin]
GO
