USE [SSISDB]
GO
IF NOT EXISTS(SELECT * FROM sys.procedures WHERE object_id = OBJECT_ID('[dbo].[usp_cleanup_key_certificates]'))
    EXEC (N'CREATE PROCEDURE [dbo].[usp_cleanup_key_certificates] AS PRINT ''Placeholder for [dbo].[usp_cleanup_key_certificates]''')
GO
/* ****************************************************
usp_cleanup_key_certificates v 1.01 (2019-08-19)
Feedback: mailto:pavel.pawlowski@hotmail.cz

MIT License

Copyright (c) 2019 Pavel Pawlowski

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
    Cleanups SSISDB catalog from left over certificates and symmetric keys.

    The regular SSISDB cleanup job is dropping operations behind the retention window in batches. During the deletion it stores
    the deleted operation_ids in temporary table and and then deletes keys and certificates for such deleted operation_ids.
    In case the delete operation fails for whatever reason, then it happens that there are left over keys and certificates which
    will be never deleted.

    This procedure compares the existing execution IDs with the certificates and drops such left over certificates
    and symmetric keys.

    This procedure should be added as last step to the SSIS Server Maintenance Job
    
Paramters:
    @do_cleanup bit = NULL --Specifies whether information about left over certificates will be printed instead of actual cleanup
 ******************************************************* */
ALTER PROCEDURE [dbo].[usp_cleanup_key_certificates]
    @do_cleanup bit = NULL --Specifies whether information about left over certificates will be printed instead of actual cleanup
--WITH EXECUTE AS 'AllSchemaOwner'
WITH EXECUTE AS OWNER
AS
    SET NOCOUNT ON;

    RAISERROR(N'usp_cleanup_key_certificates v1.01 (2019-08-19) (c) 2019 Pavel Pawlowski', 0, 0) WITH NOWAIT;
    RAISERROR(N'========================================================================', 0, 0) WITH NOWAIT;
    RAISERROR(N'usp_cleanup_key_certificates cleanups SSISDB for left over certificates.', 0, 0) WITH NOWAIT;
    RAISERROR(N'and symmetric key caused by regular cleanup job failures', 0, 0) WITH NOWAIT;
    RAISERROR(N'https://github.com/PavelPawlowski/SQL-Scripts', 0, 0) WITH NOWAIT;

    RAISERROR(N'', 0, 0) WITH NOWAIT;

    IF @do_cleanup IS NULL
    BEGIN
        RAISERROR(N'
Usage: 
    [dbo].[usp_cleanup_key_certificates] [params]

Parameters:
    @do_cleanup bit = NULL --Specifies whetehr actual cleanup should be done or only information about the cleanup should be printed.
                           --0 = print only the left-over certificates and keys.
                           --1 = delete left-over certificates and keys
', 0, 0) WITH NOWAIT;


        RETURN;
    END
    ELSE IF @do_cleanup = 0
    BEGIN
        RAISERROR(N'<<-- NO DELETE MODE - information is printed only -->>', 0, 0);
    END
    
    RAISERROR(N'', 0, 0) WITH NOWAIT;
    RAISERROR(N'Retrieving information about left-over certificates and symmetric keys....', 0, 0) WITH NOWAIT;


    DECLARE 
        @name_to_delete nvarchar(128)
        ,@is_cert       bit
        ,@msg           nvarchar(max)
        ,@sql           nvarchar(max)
        ,@cntCerts      int
        ,@cntKeys       int


    CREATE TABLE #certkeys (
         operation_id   bigint NOT NULL
        ,is_cert        bit NOT NULL 
        ,name           nvarchar(128)
        ,PRIMARY KEY CLUSTERED(operation_id, is_cert)
    )

    --Get redundant certificates
    INSERT INTO #certkeys(operation_id, is_cert, name)
    SELECT
        CONVERT(bigint, RIGHT(name, LEN(name) - LEN('MS_Cert_Exec_'))) AS operation_id
        ,CONVERT(bit, 1) AS is_cert
        ,name
    FROM sys.certificates
    WHERE
        name LIKE 'MS_Cert_Exec_%'

    INSERT INTO #certkeys(operation_id, is_cert, name)
    SELECT
        CONVERT(bigint, RIGHT(name, LEN(name) - LEN('MS_Enckey_Exec_'))) AS operation_id
        ,CONVERT(bit, 0) as is_cert
        ,name
    FROM sys.symmetric_keys
    WHERE name LIKE 'MS_Enckey_Exec_%'
    

    SELECT
        @cntCerts = ISNULL(SUM(CASE WHEN is_cert = 1 THEN 1 ELSE 0 END), 0)
        ,@cntKeys = ISNULL(SUM(CASE WHEN is_cert = 1 THEN 0 ELSE 1 END), 0)
    FROM #certkeys c
    LEFT JOIN internal.operations o ON c.operation_id = o.operation_id
    WHERE 
        o.operation_id IS NULL

    RAISERROR(N'Number of Certificates to Cleanup: %d', 0, 0, @cntCerts) WITH NOWAIT;
    RAISERROR(N'Number of symmetric keys to Cleanup: %d', 0, 0, @cntKeys) WITH NOWAIT;
    RAISERROR(N'------------------------------------------------------------------', 0, 0) WITH NOWAIT;
    WAITFOR DELAY '00:00:00.5';

    DECLARE rk CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        c.name
        ,c.is_cert
    FROM #certkeys c
    LEFT JOIN internal.operations o ON c.operation_id = o.operation_id
    WHERE 
        o.operation_id IS NULL
    ORDER BY c.operation_id

    OPEN rk;

    FETCH NEXT FROM rk INTO @name_to_delete, @is_cert

    WHILE @@FETCH_STATUS = 0
    BEGIN
        if @is_cert = 1
        BEGIN
            SET @msg = 'Deleting left-over certificate: ' + @name_to_delete;
            SET @sql = 'DROP CERTIFICATE ' + QUOTENAME(@name_to_delete);
        END
        ELSE
        BEGIN
            SET @msg = 'Deleting left-over symmetric key: ' + @name_to_delete;
            SET @sql = 'DROP SYMMETRIC KEY ' + QUOTENAME(@name_to_delete);
        END


        IF @do_cleanup = 1
        BEGIN
            RAISERROR(@msg, 0, 0) WITH NOWAIT;
            EXECUTE sp_executesql @sql;
        END
        ELSE
        BEGIN
            SET @msg = N'NOT ' + @msg + N'   (' + @sql + N')'
            RAISERROR(@msg, 0, 0) WITH NOWAIT;
        END

        FETCH NEXT FROM rk INTO @name_to_delete, @is_cert
    END

    CLOSE rk;
    DEALLOCATE rk;

GO

GRANT EXECUTE ON [dbo].[usp_cleanup_key_certificates] TO [##MS_SSISServerCleanupJobUser##]
GO
