/* *****************************************************************************************
                                      AZURE SQL DB Notice

   Comment-out the unsupported USE [master] when running in Azure SQL DB/Synapse Analytics
   or ignore error caused by unsupported USE statement
******************************************************************************************** */

USE [master]
GO
IF NOT EXISTS (SELECT 1 FROM sys.all_objects WHERE object_id = OBJECT_ID('[dbo].[sp_tblCleanupRetentionWindow]') AND TYPE = 'P')
    EXECUTE ('CREATE PROCEDURE [dbo].[sp_tblCleanupRetentionWindow] AS BEGIN PRINT ''Container for [dbo].[sp_tblCleanupRetentionWindow] (C) Pavel Pawlowski'' END')
GO

/* *******************************************************
sp_CleanupRetentionWindow v 0.10 (2021-05-07)

Feedback: mailto:pavel.pawlowski@hotmail.cz

MIT License

Copyright (c) 2017 - 2021 Pavel Pawlowski

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
    Drops all partitions prior a reretion window


Parameters:
     @pfName            nvarchar(128)   = NULL  --Name of the partition function
    ,@retentionWindow   sql_variant     = NULL  --RetentionWindow Value. All partitons prior partition containing @retentionWindow will be cleared and merged.
    ,@infoOnly          bit             = 1     --When 1, prints only information about affected tables and affected partitions

********************************************************************************* */

ALTER PROCEDURE [dbo].[sp_tblCleanupRetentionWindow]
    @pfName             nvarchar(128)   = NULL --Name of the partition function
    ,@retentionWindow   sql_variant     = NULL --RetentionWindow Value. All partitons prior partition containing @retentionWindow will be cleared and merged.
    ,@infoOnly          bit             = 1    --When 1, prints only information about affected tables and affected partitions
AS
BEGIN
    RAISERROR(N'
sp_tblCleanupRetentionWindow v0.10 (2021-05-07) (C) 2017-2021 Pavel Pawlowski
=============================================================================
Cleans retention window for all tables associated with partition function

Feedback mail to: pavel.pawlowski@hotmail.cz
Repository:       https://github.com/PavelPawlowski/SQL-Scripts
-----------------------------------------------------------------------------', 0, 0) WITH NOWAIT;


    DECLARE 
        @function_id                    int
        ,@range_type                    char(1)
        ,@range_data_type               nvarchar(128)
        ,@range_precision               nvarchar(10)
        ,@range_scale                   nvarchar(10)
        ,@retentionWindow_data_type     nvarchar(128)
        ,@retentionWindow_precision     nvarchar(10)
        ,@retentionWindow_scale         nvarchar(10)
        ,@retention_window_partition    int
        ,@data_type_full                nvarchar(150)
        ,@retention_window_str          nvarchar(256)
        ,@stamp                         nvarchar(50)
        ,@cleanup_partition_sql         nvarchar(max)
        ,@truncate_partition_sql        nvarchar(max)
        ,@merge_partition_sql           nvarchar(max)
        ,@boundary_id                   int
        ,@boundary_value_left           sql_variant
        ,@boundary_value_right          sql_variant
        ,@boundary_value_left_str       nvarchar(256)
        ,@boundary_value_right_str      nvarchar(256)
        ,@left_operator                 char(2)
        ,@right_operator                char(2)
        ,@ps_name                       nvarchar(130)
        ,@ps_last_name                  nvarchar(130)   = N''
        ,@schema_name                   nvarchar(130)
        ,@table_name                    nvarchar(130)
        ,@object_id                     int
        ,@rows                          bigint
        ,@print_help                    bit             = 0
        ,@product_version               nvarchar(128)   = CONVERT(nvarchar(128), SERVERPROPERTY ('productversion'));


    IF SERVERPROPERTY('EngineEdition') IN (1, 2, 3, 4, 8) AND CONVERT(int, LEFT(@product_version, CHARINDEX('.', @product_version) - 1)) < 13
    BEGIN
        RAISERROR(N'Unsupported Engine version. Only SQL Server 2016 and above, Azure SQL Database, Azure SQL Instance and Azure Synapse is supported', 15, 0);;
        SET @pfName = NULL;
    END

    IF @pfName IS NULL
    BEGIN
        RAISERROR(N'', 0, 0) WITH NOWAIT;
        RAISERROR(N'Supports only SQL Server 2016 and above, Azure SQL Database, Azure SQL Instance and Azure Synapse', 0, 0) WITH NOWAIT;
        RAISERROR(N'', 0, 0) WITH NOWAIT;
        RAISERROR(N'[sp_tblCleanupRetentionWindow] cleanups all tables associated with the provided partition function up to the specified retention window', 0, 0) WITH NOWAIT; 
        RAISERROR(N'', 0, 0) WITH NOWAIT;
        RAISERROR(N'Usage:', 0, 0) WITH NOWAIT;
        RAISERROR(N'[sp_tblCleanupRetentionWindow] @pfName = ''partition_function_name'', @retentionWindow = ''retention_window_value'', @infoOnly = 0/1', 0, 0) WITH NOWAIT;

        RAISERROR(N'
Parameters:
-----------
     @pfName            nvarchar(128)   = NULL  - Name of the partition function
                                                  All associated parition schemes and tables will be cleaned according specified @retentionWindow
    ,@retentionWindow   sql_variant     = NULL  - Specifies retention window.
                                                  All partitions prior the partition containing the @retentioneWindow value will be cleared.
                                                  If partitions contain data, partitions are first TRUNCATED
                                                  Then all partitions prior the @retentionWindow partitions will be merged to the first (leftmost) partition
                                                  [sp_tblCleanupRetentionWindow] keeps first (leftmost) partition empty.
                                                  [sp_tblCleanupRetentionWindow] does not invoke any cleanup, if the @retentionWindow is part of the first (leftmost) partition.
                                                  @retentioneWindow must be of the data type of the partition function. 
    ,@infoOnly          bit             = 1     - When 1, then prints only information about affected partitions, partition schemes and tables.
                                                  No Cleanup is performed if @infoOnly = 1            
        ', 0, 0) WITH NOWAIT;
        RAISERROR(N'
Sample:
--------

--Cleanup all tables associated with the [pf_PartitionByDate] partition function.
--Cleanup and merge all partitions prior partition containing value of @retentionWindow = ''2021-05-01''
--[pf_PartitionByDate] is using [date] data type.

DECLARE @retentionWindow date = ''20201-05-01''

EXEC [sp_tblCleanupRetentionWindow]
    @pfName               = ''pf_PartitionByDate''
    ,@retentionWindow     = @retentionWindow
    ,@infoOnly            = 0

        ', 0, 0) WITH NOWAIT;

        RETURN;
    END

    /*************************************
               CHECKS section
    *********************************** */
    --Get partition fuction
    SELECT
        @function_id    = function_id
        ,@range_type    = type
    FROM sys.partition_functions pf
    WHERE pf.name = @pfName

    --Check if partition function exists
    IF @function_id IS NULL
    BEGIN
        RAISERROR(N'Could not find partition function [%s]', 15, 0, @pfName);
        RETURN;
    END

    --check @retentionWindow
    IF @retentionWindow IS NULL
    BEGIN
        RAISERROR(N'@retentionWindow cannot be NULL', 15, 0)
        RETURN;
    END

    --Get data type of the partition range values
    SELECT TOP (1)
        @range_data_type    = lower(CONVERT(nvarchar(128), SQL_VARIANT_PROPERTY([value],'BaseType')))
        ,@range_precision   = CONVERT(nvarchar(10), SQL_VARIANT_PROPERTY([value],'Precision'))
        ,@range_scale       = CONVERT(nvarchar(10), SQL_VARIANT_PROPERTY([value],'Scale'))
    FROM sys.partition_range_values prv
    WHERE
        prv.function_id = @function_id

    --Get data type of the provided retention window value
    SELECT
        @retentionWindow_data_type  = lower(CONVERT(nvarchar(128), SQL_VARIANT_PROPERTY(@retentionWindow,'BaseType')))
        ,@retentionWindow_precision = CONVERT(nvarchar(10), SQL_VARIANT_PROPERTY(@retentionWindow,'Precision'))
        ,@retentionWindow_scale     = CONVERT(nvarchar(10), SQL_VARIANT_PROPERTY(@retentionWindow,'Scale'))

    --format the supported data type
    SET @data_type_full = QUOTENAME(@retentionWindow_data_type) + 
                            CASE 
                                WHEN @retentionWindow_data_type IN (N'datetime2', N'datetimeoffset') THEN N'(' + @retentionWindow_scale + N')' 
                                WHEN @retentionWindow_data_type IN (N'decimal', N'numeric') THEN N'(' + @retentionWindow_precision + N', ' + @retentionWindow_scale + N')' 
                                WHEN @retentionWindow_data_type IN (N'char', N'varchar') THEN N'(8000)' 
                                WHEN @retentionWindow_data_type IN (N'nchar', N'nvarchar') THEN N'(4000)' 
                                ELSE N'' 
                            END;

    --Check if the data type of the window match the data type of the pf range
    IF (@retentionWindow_data_type <> @range_data_type)
    BEGIN
        RAISERROR(N'Data type of provided retention window [%s] does not match data type of the partition window range [%s]', 15, 2, @retentionWindow_data_type, @range_data_type);
        RETURN;
    END

    --Check if the scale of the retention window data type matches the scale of the range data type
    IF (@retentionWindow_precision <> @range_precision OR  @retentionWindow_scale <> @range_scale)
    BEGIN
        RAISERROR(N'Precision or Scale of the retetntion data type of [%s] does not match the scale of the range data type of [%s]', 15, 3, @retentionWindow_scale, @range_scale);
        RETURN;
    END

    --Build SQL statement to get retention window partition number
    SET @cleanup_partition_sql = N'SELECT @retention_window_partition = $PARTITION.' + QUOTENAME(@pfName) + N'(CONVERT(' + @data_type_full + N', @retentionWindow))'

    --Get actual retention window partition
    EXEC sp_executesql @cleanup_partition_sql, N'@retentionWindow sql_variant, @retention_window_partition int OUTPUT', @retentionWindow=@retentionWindow, @retention_window_partition=@retention_window_partition OUTPUT

    --if retention window is part of the first partition, no cleanup 
    IF @retention_window_partition = 1
    BEGIN
        SET @retention_window_str = CONVERT(nvarchar(256), @retentionWindow);
        RAISERROR(N'Retention window [%s] is part of the first partition of the [%s]. NO CLEANUP.', 0, 0, @retention_window_str, @pfName) WITH NOWAIT;
        RETURN;
    END


    /*************************************
               INFO section
    *********************************** */

    RAISERROR(N'Cleaning retention window for partition function [%s]', 0, 0, @pfName) WITH NOWAIT;


    DECLARE bv CURSOR FAST_FORWARD FOR
    SELECT
        boundary_id
        ,LAG([value], 1) OVER(ORDER BY boundary_id)
        ,[value]
    FROM sys.partition_range_values prv
    WHERE
        prv.function_id = @function_id
        AND
        prv.boundary_id < @retention_window_partition

    RAISERROR(N'', 0, 0) WITH NOWAIT;
    RAISERROR(N'Partitions to Cleanup:', 0, 0) WITH NOWAIT;
    RAISERROR(N'----------------------', 0, 0) WITH NOWAIT;

    OPEN bv;
    FETCH NEXT FROM bv INTO @boundary_id, @boundary_value_left, @boundary_value_right
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT
            @boundary_value_left_str    = CASE
                                            WHEN @range_data_type IN ('date') THEN CONVERT(nvarchar(256), @boundary_value_left, 23)
                                            WHEN @range_data_type IN ('datetime', 'datetime2') THEN CONVERT(nvarchar(256), @boundary_value_left, 121)
                                            WHEN @range_data_type IN ('datetimeoffset') THEN CONVERT(nvarchar(256), @boundary_value_left, 127)
                                            ELSE CONVERT(nvarchar(256), @boundary_value_left)
                                          END
            ,@boundary_value_right_str  = CASE
                                            WHEN @range_data_type IN ('date') THEN CONVERT(nvarchar(256), @boundary_value_right, 23)
                                            WHEN @range_data_type IN ('datetime', 'datetime2') THEN CONVERT(nvarchar(256), @boundary_value_right, 121)
                                            WHEN @range_data_type IN ('datetimeoffset') THEN CONVERT(nvarchar(256), @boundary_value_right, 127)
                                            ELSE CONVERT(nvarchar(256), @boundary_value_right)
                                          END
            ,@left_operator             = CASE WHEN @boundary_id = 1 THEN N'' WHEN @range_type = 'R' THEN '<=' ELSE '<' END
            ,@right_operator            = CASE WHEN @range_type = 'R' THEN '<' ELSE '<=' END

        IF @boundary_value_left_str IS NULL
            SET @boundary_value_left_str = REPLICATE(N' ', LEN(@boundary_value_right_str));

        RAISERROR(N'[%s] %s [x] %s [%s]', 0, 0, @boundary_value_left_str, @left_operator, @right_operator, @boundary_value_right_str) WITH NOWAIT;
    

        FETCH NEXT FROM bv INTO @boundary_id, @boundary_value_left, @boundary_value_right
    END

    CLOSE bv;


    DECLARE tbls CURSOR READ_ONLY FOR 
    SELECT
         QUOTENAME(ps.[name])                   AS [ps_name]
        ,QUOTENAME(SCHEMA_NAME(o.[schema_id]))  AS [schema_name]
        ,QUOTENAME(o.[name])                    AS [table_name]
        ,o.[object_id]                          AS [object_id]
    FROM sys.indexes i
    INNER JOIN sys.data_spaces ds on i.data_space_id = ds.data_space_id
    INNER JOIN sys.partition_schemes ps ON ds.data_space_id = ps.data_space_id
    INNER JOIN sys.objects o ON o.object_id = i.object_id

    WHERE
        i.index_id <= 1
        AND
        ds.type = 'PS'
        AND
        ps.function_id = @function_id


    RAISERROR(N'', 0, 0) WITH NOWAIT;
    RAISERROR(N'Affected Partition Schemes And Tables:', 0, 0) WITH NOWAIT;
    RAISERROR(N'--------------------------------------', 0, 0) WITH NOWAIT;

    OPEN tbls;

    FETCH NEXT FROM tbls INTO @ps_name, @schema_name, @table_name, @object_id

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @ps_last_name <> @ps_name
            RAISERROR(N'%s', 0, 0, @ps_name) WITH NOWAIT;
        RAISERROR(N'  - %s.%s', 0, 0, @schema_name, @table_name) WITH NOWAIT;

        SET @ps_last_name = @ps_name
        FETCH NEXT FROM tbls INTO @ps_name, @schema_name, @table_name, @object_id
    END

    CLOSE tbls;

    /*************************************
               CLEANUP section
    *********************************** */
    IF @infoOnly = 0
    BEGIN
        RAISERROR(N'', 0, 0) WITH NOWAIT;
        RAISERROR(N'CLEANUP PROCESS', 0, 0) WITH NOWAIT;
        RAISERROR(N'---------------------------------------------------------------', 0, 0) WITH NOWAIT;
        SET @stamp = CONVERT(nvarchar(50), SYSDATETIMEOFFSET());
        RAISERROR(N'%s - Starting CLEANUP Process', 0, 0, @stamp) WITH NOWAIT;

        --Loop through first partitions to check if they are empty, if not, TRUNCATE THEM
        OPEN tbls;
        FETCH NEXT FROM tbls INTO @ps_name, @schema_name, @table_name, @object_id

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SELECT
                @rows = p.rows
            FROM sys.partitions p
            WHERE
                p.object_id = @object_id
                AND
                p.index_id <= 1
                AND
                p.partition_number = 1

            --if there are rows in the partition 1, TRUNCATE the table partition
            IF @rows > 0
            BEGIN
                SET @truncate_partition_sql = N'TRUNCATE TABLE ' + @schema_name + N'.' + @table_name + N'WITH(PARTITIONS(1))'

                SET @stamp = CONVERT(nvarchar(50), SYSDATETIMEOFFSET());
                RAISERROR(N'%s - %s.%s PARTITION 1 not empty. Starting TRUNCATE', 0, 0, @stamp, @schema_name, @table_name) WITH NOWAIT;

                --Truncate PARTITION 2 of table
                EXEC sp_executesql @truncate_partition_sql

                SET @stamp = CONVERT(nvarchar(50), SYSDATETIMEOFFSET());
                RAISERROR(N'%s - %s.%s PARTITION 1 TRUNCATE completed', 0, 0, @stamp, @schema_name, @table_name) WITH NOWAIT;
            END
            FETCH NEXT FROM tbls INTO @ps_name, @schema_name, @table_name, @object_id
        END

        CLOSE tbls

        --While the @retention_window_partition  > 2, then DROP PARTITION 2
        --Partition 1 is the leftmost partition which will contain no data
        --After dropping the @retention_window_partition 2 it's range will be part of the Partition 1 and partitions will be renumbered
        --So we drop partition 2 in the circle up to the point where the date we want to keep will be part of partition 2
        WHILE @retention_window_partition > 2
        BEGIN
            --Get boundary values for partition 2
            SELECT
                @boundary_value_left        = prv.[value]
                ,@boundary_value_left_str   = CASE
                                                WHEN @range_data_type IN ('date') THEN CONVERT(nvarchar(256), prv.[value], 23)
                                                WHEN @range_data_type IN ('datetime', 'datetime2') THEN CONVERT(nvarchar(256), prv.[value], 121)
                                                WHEN @range_data_type IN ('datetimeoffset') THEN CONVERT(nvarchar(256), prv.[value], 127)
                                                ELSE CONVERT(nvarchar(256), prv.[value])
                                              END
            FROM sys.partition_range_values  prv
            INNER JOIN sys.partition_functions pf ON pf.function_id = prv.function_id
            WHERE
                pf.function_id = @function_id
                AND
                boundary_id = 1

            SELECT
                @boundary_value_right        = prv.[value]
                ,@boundary_value_right_str   = CASE
                                                WHEN @range_data_type IN ('date') THEN CONVERT(nvarchar(256), prv.[value], 23)
                                                WHEN @range_data_type IN ('datetime', 'datetime2') THEN CONVERT(nvarchar(256), prv.[value], 121)
                                                WHEN @range_data_type IN ('datetimeoffset') THEN CONVERT(nvarchar(256), prv.[value], 127)
                                                ELSE CONVERT(nvarchar(256), prv.[value])
                                              END
            FROM sys.partition_range_values  prv
            INNER JOIN sys.partition_functions pf ON pf.function_id = prv.function_id
            WHERE
                pf.function_id = @function_id
                AND
                boundary_id = 2

            SELECT
                 @left_operator     = CASE WHEN @range_type = 'R' THEN '<=' ELSE '<' END
                ,@right_operator    = CASE WHEN @range_type = 'R' THEN '<' ELSE '<=' END


            --Loop through all tables and check PARTITION 2 if it is empty, if not truncate it
            OPEN tbls;
            FETCH NEXT FROM tbls INTO @ps_name, @schema_name, @table_name, @object_id

            WHILE @@FETCH_STATUS = 0
            BEGIN
                SELECT
                    @rows = p.rows
                FROM sys.partitions p
                WHERE
                    p.object_id = @object_id
                    AND
                    p.index_id <= 1
                    AND
                    p.partition_number = 2

                --if there are rows in the partition 2, TRUNCATE the table partition
                IF @rows > 0
                BEGIN
                    SET @truncate_partition_sql = N'TRUNCATE TABLE ' + @schema_name + N'.' + @table_name + N'WITH(PARTITIONS(2))'

                    SET @stamp = CONVERT(nvarchar(50), SYSDATETIMEOFFSET());
                    RAISERROR(N'%s - %s.%s PARTITION for range [%s] %s [x] %s [%s] not empty. Starting TRUNCATE', 0, 0, @stamp, @schema_name, @table_name, @boundary_value_left_str, @left_operator, @right_operator, @boundary_value_right_str) WITH NOWAIT;

                    --Truncate PARTITION 2 of table
                    EXEC sp_executesql @truncate_partition_sql

                    SET @stamp = CONVERT(nvarchar(50), SYSDATETIMEOFFSET());
                    RAISERROR(N'%s - %s.%s PARTITION for range [%s] %s [x] %s [%s] TRUNCATE completed', 0, 0, @stamp, @schema_name, @table_name, @boundary_value_left_str, @left_operator, @right_operator, @boundary_value_right_str) WITH NOWAIT;
                END
                FETCH NEXT FROM tbls INTO @ps_name, @schema_name, @table_name, @object_id
            END

            CLOSE tbls

            --Build MERGE PARTITION statement
            SET @merge_partition_sql = N'ALTER PARTITION FUNCTION ' + QUOTENAME(@pfName) + N'() MERGE RANGE (CONVERT(' + @data_type_full + N', @boundary_value_left))'

            SET @stamp = CONVERT(nvarchar(50), SYSDATETIMEOFFSET());
            RAISERROR(N'%s - [%s] range [%s] %s [x] %s [%s] : Start MERGE into PARTITION 1', 0, 0, @stamp, @pfName, @boundary_value_left_str, @left_operator, @right_operator, @boundary_value_right_str) WITH NOWAIT;
        
            --Merge Partition 2 INTO Partition 1
            EXEC sp_executesql @merge_partition_sql, N'@boundary_value_left sql_variant', @boundary_value_left = @boundary_value_left

            SET @stamp = CONVERT(nvarchar(50), SYSDATETIMEOFFSET());
            RAISERROR(N'%s - [%s] range [%s] %s [x] %s [%s] : MERGE into PARTITION 1 completed. New range of PARTITION 1: [x] %s [%s]', 0, 0, @stamp, @pfName, @boundary_value_left_str, @left_operator, @right_operator, @boundary_value_right_str, @right_operator, @boundary_value_right_str) WITH NOWAIT;


            EXEC sp_executesql @cleanup_partition_sql, N'@retentionWindow sql_variant, @retention_window_partition int OUTPUT', @retentionWindow=@retentionWindow, @retention_window_partition=@retention_window_partition OUTPUT
        END

        SET @stamp = CONVERT(nvarchar(50), SYSDATETIMEOFFSET());
        RAISERROR(N'%s - CLEANUP Process COMPLETED', 0, 0, @stamp) WITH NOWAIT;


    END --IF @infoOnly = 0

    DEALLOCATE tbls;
    DEALLOCATE bv;
END
GO
--Mark Stored Procedure as system object, so it executes in the context of current database.
IF SERVERPROPERTY('EngineEdition') IN (1, 2, 3, 4, 8)
    EXEC(N'EXECUTE sp_ms_marksystemobject ''dbo.sp_tblCleanupRetentionWindow''');
GO
