USE [SSISDB]
GO
/****** Object:  StoredProcedure [dbo].[usp_cleanup_server_retention_window]    Script Date: 03.10.2019 8:25:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/* ****************************************************
usp_cleanup_server_retention_window v 1.50 (2019-10-03)
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
    Cleanups SSISDB catalog from all kind of log mesasges belonging to operations past specified data or retention window
    
    This stored procedrue should be called in the SSIS cleanup job prior the internal version: [iternal].[cleanup_server_retention_window].
    It does not remove the operations itself. The proper cleanup steps should be called after this stored proc.

    The internal procedure clears the ssis db in batches, but batches on the internal.operations table. However due to the constraints on the SSISDB catalog
    all the eventual additional log records belonging to the deleted operations in a batch are deleted as single transaction.
    As there can be millions of rows per operation, this causes large transaction log growth during the operations cleanup on large SSISDBs
    as well as heavy contention.

    This stored procedure deletes the log information in smaller batches and many smaller tnrasactions thuss not flooding the transaction log and
    allowing the normal opertaion of the SSISDB

Paramters:
     @max_date          datetime    = NULL          --Specifies maximum date to cleanup. If Not provided, retention window is being used
    ,@batch_size        int         = 50000         --batch_size to use during cleanup
    ,@sleep_time        time        = '00:00:00.01' --Sleep duration between each deletion batch of operations
    ,@check_only        bit         = 0             --If Check Only is specified then only the number of log records are returned'
    ,@no_infomsg        bit         = 0             --Specifies whether intermediate info messages should be printed
    ,@ops_batch_size    smallint    = 50            --Specifies size of the operations batch to be deleted in one step
    ,@cleanup_start_date    datetime    = NULL          --Specifies the starting data for the retention window. If null then current timestamp is used
 ******************************************************* */
ALTER PROCEDURE [dbo].[usp_cleanup_server_retention_window]
     @max_date              datetime    = NULL          --Specifies maximum date to cleanup. If Not provided, retention window is being used
    ,@batch_size            int         = 50000         --batch_size to use during cleanup
    ,@sleep_time            time        = '00:00:00.01' --Sleep duration between each deletion batch of operations
    ,@check_only            bit         = 0             --If Check Only is specified then only the number of log records are returned
    ,@no_infomsg            bit         = 0             --Specifies whether intermediate info messages should be printed
    ,@ops_batch_size        smallint    = 50            --Specifies size of the operations batch to be deleted in one step
    ,@cleanup_start_date    datetime    = NULL          --Specifies the starting data for the retention window. If null then current timestamp is used
WITH EXECUTE AS 'AllSchemaOwner'
AS
    SET NOCOUNT ON;

    DECLARE 
         @enable_clean_operation    bit
        ,@retention_window_length   int
        ,@temp_date                 datetime
        ,@msg                       nvarchar(max)
        ,@rowCnt                    int
        ,@start                     datetime
        ,@totalOperations           int             = 0
        ,@currentOperation          int             = 0
        ,@total_rows                bigint          = 0


    DECLARE @delay datetime = CONVERT(datetime, @sleep_time);

    IF OBJECT_ID('tempdb..#operationsToCleanup') IS NOT NULL
        DROP TABLE #operationsToCleanup;

    CREATE TABLE #operationsToCleanup (
        operation_id bigint PRIMARY KEY CLUSTERED
    )

    IF OBJECT_ID('tempdb..#deleteOps') IS NOT NULL
        DROP TABLE #deleteOps;

    CREATE TABLE #deleteOps (
        operation_id bigint PRIMARY KEY CLUSTERED
    )

    RAISERROR(N'usp_cleanup_server_retention_window v1.50 (2019-10-03) (c) 2017 - 2019 Pavel Pawlowski', 0, 0) WITH NOWAIT;
    RAISERROR(N'======================================================================================', 0, 0) WITH NOWAIT;
    RAISERROR(N'usp_cleanup_server_retention_window cleanups SSISDB.', 0, 0) WITH NOWAIT;
    RAISERROR(N'Logs for operations out of retention window are cleared.', 0, 0) WITH NOWAIT;
    RAISERROR(N'', 0, 0) WITH NOWAIT;


    SELECT @enable_clean_operation = CONVERT(bit, property_value) 
        FROM [catalog].[catalog_properties]
        WHERE property_name = 'OPERATION_CLEANUP_ENABLED'
        
    IF NOT (@enable_clean_operation = 1)
    BEGIN
        RAISERROR('CLEANUP OPERATION NOT ENABLED ON SSISDB Catalog', 15, 1);
        RETURN;
    END

    IF @max_date IS NULL
    BEGIN
        SELECT @retention_window_length = CONVERT(int,property_value)  
            FROM [catalog].[catalog_properties]
            WHERE property_name = 'RETENTION_WINDOW'


        IF @retention_window_length <= 0 
        BEGIN
            RAISERROR(27163    ,16,1,'RETENTION_WINDOW')
            RETURN;
        END

        SET @temp_date = ISNULL(@cleanup_start_date, GETDATE()) - @retention_window_length;
    END
    ELSE
    BEGIN
        SET @temp_date = @max_date;
    END

    IF @check_only = 1
    BEGIN
        RAISERROR(N'<<---- CHECK ONLY MODE ---->>', 0, 0) WITH NOWAIT;
        RAISERROR(N'No deletion will occur', 0, 0) WITH NOWAIT;
        RAISERROR(N'', 0, 0) WITH NOWAIT;
    END



    SET @msg = CONVERT(nvarchar(36), SYSDATETIMEOFFSET()) + N' - Cleaning Catalog for retention window of ' + CONVERT(nvarchar(10), @retention_window_length) + N' days'
    RAISERROR(@msg, 0, 0) WITH NOWAIT;
    SET @msg = CONVERT(nvarchar(36), SYSDATETIMEOFFSET()) + N' - Cleaning Catalog for records older than ' + CONVERT(nvarchar(36), TODATETIMEOFFSET(@temp_date, DATEPART(TZ, SYSDATETIMEOFFSET())) )
    RAISERROR(@msg, 0, 0) WITH NOWAIT;
    
    --Get Operations to cleanup
    INSERT INTO #operationsToCleanup
    SELECT
        operation_id
    FROM internal.operations 
    WHERE 
        ( 
            [end_time] <= @temp_date                    
            OR 
            ([end_time] IS NULL AND [status] = 1 AND [created_time] <= @temp_date )
        )

    SET @totalOperations = (SELECT COUNT(1) FROM #operationsToCleanup)
    SET @msg = CONVERT(nvarchar(36), SYSDATETIMEOFFSET()) + N' - Cleaning Catalog for records - Operations to clenup: ' + CONVERT(nvarchar(10), @totalOperations);
    RAISERROR(@msg, 0, 0) WITH NOWAIT;


    WHILE (SELECT COUNT(1) FROM #operationsToCleanup) > 0
    BEGIN
        IF @delay IS NOT NULL WAITFOR DELAY @delay

        TRUNCATE TABLE #deleteOps;

        DELETE TOP (@ops_batch_size) op
        OUTPUT deleted.operation_id
        INTO #deleteOps
        FROM #operationsToCleanup op


        IF @no_infomsg = 1
        BEGIN
            SET @msg = CONVERT(nvarchar(36), SYSDATETIMEOFFSET()) + N' - ------------------------------------------------------------------------------------'
            RAISERROR(@msg, 0, 0) WITH NOWAIT;
        END

        SET @currentOperation = @currentOperation + @ops_batch_size;

        IF @currentOperation > @totalOperations
            SET @currentOperation = @totalOperations;

        IF @no_infomsg = 0
        BEGIN
            SET @msg = CONVERT(nvarchar(36), SYSDATETIMEOFFSET()) + N' - ------------------------------------------------------------------------------------'
            RAISERROR(@msg, 0, 0) WITH NOWAIT;
        END
        

        SET @msg = CONVERT(nvarchar(36), SYSDATETIMEOFFSET()) + N' - Cleaning Operations (' + CONVERT(nvarchar(10), @currentOperation) + N' of ' + CONVERT(nvarchar(10), @totalOperations) + N')'  
            + ' [' + STUFF((SELECT ', ' + CONVERT(nvarchar(20), operation_id) FROM #deleteOps FOR XML PATH('')), 1, 2, '') + N']'
        RAISERROR(@msg, 0, 0) WITH NOWAIT;
        
        --Extended operation info
        SET @msg = CONVERT(nvarchar(36), SYSDATETIMEOFFSET()) + N'   - Extended operation info ...'
        IF @no_infomsg = 0
            RAISERROR(@msg, 0, 0) WITH NOWAIT;
        IF @check_only = 0
        BEGIN
            SET @rowCnt = @batch_size ;
            WHILE @rowCnt >= @batch_size
            BEGIN
                SET @start = GETDATE();
                DELETE TOP (@batch_size)
                FROM internal.extended_operation_info 
                WHERE operation_id IN (SELECT operation_id FROM  #deleteOps)
                SET @rowCnt = @@ROWCOUNT
                SET @total_rows = @total_rows + @rowCnt;
                SET @msg = CONVERT(nvarchar(36), SYSDATETIMEOFFSET()) + N'     - Cleared rows: ' + CONVERT(nvarchar(10), @rowCnt) + N', Duration: ' + CONVERT(nvarchar(20), CONVERT(time, GETDATE() - @start))
                IF @no_infomsg = 0
                    RAISERROR(@msg, 0, 0) WITH NOWAIT;
            END
        END
        ELSE
        BEGIN
            SET @rowCnt = ISNULL((SELECT COUNT(1) FROM internal.extended_operation_info WITH(NOLOCK) WHERE operation_id IN (SELECT operation_id FROM  #deleteOps)), 0);
            SET @msg = CONVERT(nvarchar(36), SYSDATETIMEOFFSET()) + N'     - Rows to cleanup: ' + CONVERT(nvarchar(10), @rowCnt);
            SET @total_rows = @total_rows + @rowCnt;
            IF @no_infomsg = 0
                RAISERROR(@msg, 0, 0) WITH NOWAIT;
        END

        SET @msg = CONVERT(nvarchar(36), SYSDATETIMEOFFSET()) + N'   - Cleaning Event message contexts...'
        IF @no_infomsg = 0
            RAISERROR(@msg, 0, 0) WITH NOWAIT;
        IF @check_only = 0
        BEGIN
            SET @rowCnt = @batch_size;
            WHILE @rowCnt >= @batch_size
            BEGIN
                --IF @delay IS NOT NULL WAITFOR DELAY @delay
                SET @start = GETDATE();
                DELETE TOP (@batch_size) mc
                FROM internal.event_message_context mc
                INNER JOIN internal.event_messages em ON mc.event_message_id = em.event_message_id
                WHERE em.operation_id IN (SELECT operation_id FROM  #deleteOps)
                SET @rowCnt = @@ROWCOUNT
                SET @total_rows = @total_rows + @rowCnt;
                SET @msg = CONVERT(nvarchar(36), SYSDATETIMEOFFSET()) + N'     - Cleared rows: ' + CONVERT(nvarchar(10), @rowCnt) + N', Duration: ' + CONVERT(nvarchar(20), CONVERT(time, GETDATE() - @start))
                IF @no_infomsg = 0
                    RAISERROR(@msg, 0, 0) WITH NOWAIT;
            END
        END
        ELSE
        BEGIN
            SET @rowCnt = ISNULL((SELECT COUNT(1) 
                FROM internal.event_message_context mc WITH(NOLOCK)
                INNER JOIN internal.event_messages em ON mc.event_message_id = em.event_message_id
                WHERE em.operation_id IN (SELECT operation_id FROM  #deleteOps)), 0);
            SET @msg = CONVERT(nvarchar(36), SYSDATETIMEOFFSET()) + N'     - Rows to cleanup: ' + CONVERT(nvarchar(10), @rowCnt);
            SET @total_rows = @total_rows + @rowCnt;
            IF @no_infomsg = 0
                RAISERROR(@msg, 0, 0) WITH NOWAIT;
        END

        SET @msg = CONVERT(nvarchar(36), SYSDATETIMEOFFSET()) + N'   - Cleaning Event messages...'
        IF @no_infomsg = 0
            RAISERROR(@msg, 0, 0) WITH NOWAIT;
        IF @check_only = 0
        BEGIN
            SET @rowCnt = @batch_size
            WHILE @rowCnt >= @batch_size
            BEGIN
                --IF @delay IS NOT NULL WAITFOR DELAY @delay
                SET @start = GETDATE();
                DELETE TOP (@batch_size)
                FROM internal.event_messages 
                WHERE operation_id IN (SELECT operation_id FROM  #deleteOps)
                SET @rowCnt = @@ROWCOUNT
                SET @total_rows = @total_rows + @rowCnt;
                SET @msg = CONVERT(nvarchar(36), SYSDATETIMEOFFSET()) + N'     - Cleared rows: ' + CONVERT(nvarchar(10), @rowCnt) + N', Duration: ' + CONVERT(nvarchar(20), CONVERT(time, GETDATE() - @start))
                IF @no_infomsg = 0
                    RAISERROR(@msg, 0, 0) WITH NOWAIT;
            END
        END
        ELSE
        BEGIN
            SET @rowCnt = ISNULL((SELECT COUNT(1) FROM internal.event_messages WITH(NOLOCK) WHERE operation_id IN (SELECT operation_id FROM  #deleteOps)), 0);
            SET @msg = CONVERT(nvarchar(36), SYSDATETIMEOFFSET()) + N'     - Rows to cleanup: ' + CONVERT(nvarchar(10), @rowCnt);
            SET @total_rows = @total_rows + @rowCnt;
            IF @no_infomsg = 0
                RAISERROR(@msg, 0, 0) WITH NOWAIT;
        END

        SET @msg = CONVERT(nvarchar(36), SYSDATETIMEOFFSET()) + N'   - Cleaning Operation messages...'
        IF @no_infomsg = 0
            RAISERROR(@msg, 0, 0) WITH NOWAIT;
        IF @check_only = 0
        BEGIN
            SET @rowCnt = @batch_size;
            WHILE @rowCnt >= @batch_size
            BEGIN
                --IF @delay IS NOT NULL WAITFOR DELAY @delay
                SET @start = GETDATE();
                DELETE TOP (@batch_size)
                FROM internal.operation_messages 
                WHERE operation_id IN (SELECT operation_id FROM  #deleteOps)
                SET @rowCnt = @@ROWCOUNT
                SET @total_rows = @total_rows + @rowCnt;
                SET @msg = CONVERT(nvarchar(36), SYSDATETIMEOFFSET()) + N'     - Cleared rows: ' + CONVERT(nvarchar(10), @rowCnt) + N', Duration: ' + CONVERT(nvarchar(20), CONVERT(time, GETDATE() - @start))
                IF @no_infomsg = 0
                    RAISERROR(@msg, 0, 0) WITH NOWAIT;
            END
        END
        ELSE
        BEGIN
            SET @rowCnt = ISNULL((SELECT COUNT(1) FROM internal.operation_messages WITH(NOLOCK) WHERE operation_id IN (SELECT operation_id FROM  #deleteOps)), 0);
            SET @msg = CONVERT(nvarchar(36), SYSDATETIMEOFFSET()) + N'     - Rows to cleanup: ' + CONVERT(nvarchar(10), @rowCnt);
            SET @total_rows = @total_rows + @rowCnt;
            IF @no_infomsg = 0
                RAISERROR(@msg, 0, 0) WITH NOWAIT;
        END


        SET @msg = CONVERT(nvarchar(36), SYSDATETIMEOFFSET()) + N'   - Cleaning Executable Statistics...'
        IF @no_infomsg = 0
            RAISERROR(@msg, 0, 0) WITH NOWAIT;
        IF @check_only = 0
        BEGIN
            SET @rowCnt = @batch_size
            WHILE @rowCnt >= @batch_size
            BEGIN
                --IF @delay IS NOT NULL WAITFOR DELAY @delay
                SET @start = GETDATE();
                DELETE TOP (@batch_size)
                FROM internal.executable_statistics 
                WHERE execution_id IN (SELECT operation_id FROM  #deleteOps)
                SET @rowCnt = @@ROWCOUNT
                SET @total_rows = @total_rows + @rowCnt;
                SET @msg = CONVERT(nvarchar(36), SYSDATETIMEOFFSET()) + N'     - Cleared rows: ' + CONVERT(nvarchar(10), @rowCnt) + N', Duration: ' + CONVERT(nvarchar(20), CONVERT(time, GETDATE() - @start))
                IF @no_infomsg = 0
                    RAISERROR(@msg, 0, 0) WITH NOWAIT;
            END
        END
        ELSE
        BEGIN
            SET @rowCnt = ISNULL((SELECT COUNT(1) FROM internal.executable_statistics WITH(NOLOCK) WHERE execution_id IN (SELECT operation_id FROM  #deleteOps)), 0);
            SET @msg = CONVERT(nvarchar(36), SYSDATETIMEOFFSET()) + N'     - Rows to cleanup: ' + CONVERT(nvarchar(10), @rowCnt);
            SET @total_rows = @total_rows + @rowCnt;
            IF @no_infomsg = 0
                RAISERROR(@msg, 0, 0) WITH NOWAIT;
        END

        SET @msg = CONVERT(nvarchar(36), SYSDATETIMEOFFSET()) + N'   - Cleaning Execution data statistics...'
        IF @no_infomsg = 0
            RAISERROR(@msg, 0, 0) WITH NOWAIT;
        IF @check_only = 0
        BEGIN
            SET @rowCnt = @batch_size
            WHILE @rowCnt >= @batch_size
            BEGIN
                --IF @delay IS NOT NULL WAITFOR DELAY @delay
                SET @start = GETDATE();
                DELETE TOP (@batch_size)
                FROM internal.execution_data_statistics 
                WHERE execution_id IN (SELECT operation_id FROM  #deleteOps)
                SET @rowCnt = @@ROWCOUNT
                SET @total_rows = @total_rows + @rowCnt;
                SET @msg = CONVERT(nvarchar(36), SYSDATETIMEOFFSET()) + N'     - Cleared rows: ' + CONVERT(nvarchar(10), @rowCnt) + N', Duration: ' + CONVERT(nvarchar(20), CONVERT(time, GETDATE() - @start))
                IF @no_infomsg = 0
                    RAISERROR(@msg, 0, 0) WITH NOWAIT;
            END
        END
        ELSE
        BEGIN
            SET @rowCnt = ISNULL((SELECT COUNT(1) FROM internal.execution_data_statistics WITH(NOLOCK) WHERE execution_id IN (SELECT operation_id FROM  #deleteOps)), 0);
            SET @msg = CONVERT(nvarchar(36), SYSDATETIMEOFFSET()) + N'     - Rows to cleanup: ' + CONVERT(nvarchar(10), @rowCnt);
            SET @total_rows = @total_rows + @rowCnt;
            IF @no_infomsg = 0
                RAISERROR(@msg, 0, 0) WITH NOWAIT;
        END

        SET @msg = CONVERT(nvarchar(36), SYSDATETIMEOFFSET()) + N'   - Cleaning Execution component phases...'
        IF @no_infomsg = 0
            RAISERROR(@msg, 0, 0) WITH NOWAIT;
        IF @check_only = 0
        BEGIN
            SET @rowCnt = @batch_size
            WHILE @rowCnt >= @batch_size
            BEGIN
                --IF @delay IS NOT NULL WAITFOR DELAY @delay
                SET @start = GETDATE();
                DELETE TOP (@batch_size)
                FROM internal.execution_component_phases 
                WHERE execution_id IN (SELECT operation_id FROM  #deleteOps)
                SET @rowCnt = @@ROWCOUNT
                SET @total_rows = @total_rows + @rowCnt;
                SET @msg = CONVERT(nvarchar(36), SYSDATETIMEOFFSET()) + N'     - Cleared rows: ' + CONVERT(nvarchar(10), @rowCnt) + N', Duration: ' + CONVERT(nvarchar(20), CONVERT(time, GETDATE() - @start))
                IF @no_infomsg = 0
                    RAISERROR(@msg, 0, 0) WITH NOWAIT;
            END
        END
        ELSE
        BEGIN
            SET @rowCnt = ISNULL((SELECT COUNT(1) FROM internal.execution_component_phases WITH(NOLOCK) WHERE execution_id IN (SELECT operation_id FROM  #deleteOps)), 0);
            SET @msg = CONVERT(nvarchar(36), SYSDATETIMEOFFSET()) + N'     - Rows to cleanup: ' + CONVERT(nvarchar(10), @rowCnt);
            SET @total_rows = @total_rows + @rowCnt;
            IF @no_infomsg = 0
                RAISERROR(@msg, 0, 0) WITH NOWAIT;
        END

        SET @msg = CONVERT(nvarchar(36), SYSDATETIMEOFFSET()) + N'   - Cleaning data taps...'
        IF @no_infomsg = 0
            RAISERROR(@msg, 0, 0) WITH NOWAIT;
        IF @check_only = 0
        BEGIN
            SET @rowCnt = @batch_size
            WHILE @rowCnt >= @batch_size
            BEGIN
                --IF @delay IS NOT NULL WAITFOR DELAY @delay
                SET @start = GETDATE();
                DELETE TOP (@batch_size)
                FROM internal.execution_data_taps 
                WHERE execution_id IN (SELECT operation_id FROM  #deleteOps)
                SET @rowCnt = @@ROWCOUNT
                SET @total_rows = @total_rows + @rowCnt;
                SET @msg = CONVERT(nvarchar(36), SYSDATETIMEOFFSET()) + N'     - Cleared rows: ' + CONVERT(nvarchar(10), @rowCnt) + N', Duration: ' + CONVERT(nvarchar(20), CONVERT(time, GETDATE() - @start))
                IF @no_infomsg = 0
                    RAISERROR(@msg, 0, 0) WITH NOWAIT;
            END
        END
        ELSE
        BEGIN
            SET @rowCnt = ISNULL((SELECT COUNT(1) FROM internal.execution_data_taps WITH(NOLOCK) WHERE execution_id IN (SELECT operation_id FROM  #deleteOps)), 0);
            SET @msg = CONVERT(nvarchar(36), SYSDATETIMEOFFSET()) + N'     - Rows to cleanup: ' + CONVERT(nvarchar(10), @rowCnt);
            SET @total_rows = @total_rows + @rowCnt;
            IF @no_infomsg = 0
                RAISERROR(@msg, 0, 0) WITH NOWAIT;
        END            
    END

    RAISERROR( N'============================================================', 0, 0) WITH NOWAIT;
    IF @check_only = 1
        SET @msg = N'Total Rows to Cleanup: ' + CONVERT(nvarchar(20), @total_rows);
    ELSE
        SET @msg = N'Total Rows cleared: ' + CONVERT(nvarchar(20), @total_rows);

    RAISERROR(@msg, 0, 0) WITH NOWAIT;

    RETURN 0
GO
GRANT EXECUTE ON [dbo].[usp_cleanup_server_retention_window] TO [##MS_SSISServerCleanupJobUser##]
GO
