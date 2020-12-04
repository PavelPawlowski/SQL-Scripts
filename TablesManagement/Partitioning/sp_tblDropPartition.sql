/* *****************************************************************************************
                                      AZURE SQL DB Notice

   Comment-out the unsupported USE [master] when running in Azure SQL DB/Synapse Analytics
   or ignore error caused by unsupported USE statement
******************************************************************************************** */
USE [master]
GO

--Detection of correct sp_tblSwitchPartition
DECLARE
     @minVersion        nvarchar(5)      = N'0.52'   --Defines minimum required version of sp_tblScriptIndexes
    ,@definition        nvarchar(max)
    ,@versionPos        int
    ,@foundVersion      int
    ,@minVersionInt     int
    ,@productVersion    nvarchar(128) = CONVERT(nvarchar(128), SERVERPROPERTY ('productversion'))
    ,@version           nvarchar(5)
    ,@msg               nvarchar(max) = NULL

SELECT
    @definition = m.definition
FROM master.sys.procedures p
INNER JOIN master.sys.sql_modules m ON m.object_id = p.object_id
WHERE name = 'sp_tblSwitchPartition'

SELECT 
    @versionPos = PATINDEX('%sp_tblSwitchPartition v __.__ (%', @definition)

IF @versionPos IS NOT NULL
BEGIN
    BEGIN TRY
    SET @minVersionInt = CONVERT(int, REPLACE(@minVersion, N'.', N''));
    SET @version = SUBSTRING(@definition, @versionPos + 24, 5);
    SET @foundVersion = CONVERT(int, REPLACE(@version, N'.', N''));
    END TRY
    BEGIN CATCH
    END CATCH
END


IF @definition IS NULL
BEGIN
    SET @msg = N'Could not locate [sp_tblSwitchPartition] which is required for [sp_tblDropPartition].';
END
ELSE IF @versionPos = 0 OR @foundVersion IS NULL
BEGIN
    SET @msg = N'Could not determine version of [sp_tblSwitchPartition] which is required for [sp_tblDropPartition].';
END
ELSE IF @foundVersion < @minVersionInt
BEGIN
    SET @msg = N'Minimum required version of [sp_tblSwitchPartition]: %s 
Detected version %s'
END

IF @msg IS NOT NULL
BEGIN
    IF CONVERT(int, LEFT(@productVersion, CHARINDEX('.', @productVersion) - 1)) < 13
    BEGIN
        SET @msg = @msg + N' Please run [sp_tblSwitchPartition] script first.
To get latest version visit: https://github.com/PavelPawlowski/SQL-Scripts/tree/master/TablesManagement/Partitioning'
        RAISERROR(@msg, 16, 0, @minVersion, @version) WITH NOWAIT;
        RETURN
    END
    ELSE
    BEGIN
        SET @msg = @msg + N'
Without [sp_tblSwitchPartition] it will not be possible to use partition switching only default and preffered TRUNCATE. Please run [sp_tblSwitchPartition] script first.
To get latest version visit: https://github.com/PavelPawlowski/SQL-Scripts/tree/master/TablesManagement/Partitioning';
        RAISERROR(@msg, 10, 0, @minVersion, @version) WITH NOWAIT;
    END
END
ELSE
BEGIN
    RAISERROR(N'Detected version of [sp_tblSwitchPartition]: %s', 0, 0, @version) WITH NOWAIT;
END

RAISERROR(N'Creating [sp_tblDropPartition]', 0, 0) WITH NOWAIT;


IF NOT EXISTS (SELECT 1 FROM sys.all_objects WHERE object_id = OBJECT_ID('[dbo].[sp_tblDropPartition]') AND TYPE = 'P')
    EXECUTE ('CREATE PROCEDURE [dbo].[sp_tblDropPartition] AS BEGIN PRINT ''Container'' END')
GO
/* ****************************************************
sp_tblDropPartition v  0.4 (2020-12-04)

Feedback: mailto:pavel.pawlowski@hotmail.cz

MIT License

Copyright (c) 2014-2020 Pavel Pawlowski

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
    Drops specified partition by clearting it and merging into adjacent one.

Parameters:
    @tableName                  nvarchar(261)   = NULL      --Partitioned table name for partition switching
    ,@partitionID               int             = NULL      --Partition to be Switched
    ,@partitionValue            sql_variant     = NULL      --Value to be used to determine PartitionID. Can be used instead of @partitionID
    ,@stagingTableName          nvarchar(261)   = NULL      --Staging Table Name. If NULL, Staging table name is generated based on the partition number.
                                                            --Used for partition switchout. Not needed for SQL Server 2016 and above
    ,@useTruncateWhenPossible   bit             = 1         --Specifies whether on SQL Server 2016 and above to use TRUNCATE WITH PARTITION instead of partition switching
    ,@dropStagingTable          bit             = 1         --Specifies whether drop staging table after partition switching.
* ***************************************************** */ 
ALTER PROCEDURE [dbo].[sp_tblDropPartition]
     @tableName                  nvarchar(261)  = NULL      --Partitioned table name for partition switching
    ,@partitionID               int             = NULL      --Partition to be Switched
    ,@partitionValue            sql_variant     = NULL      --Value to be used to determine PartitionID. Can be used instead of @partitionID
    ,@stagingTableName          nvarchar(261)   = NULL      --Staging Table Name. If NULL, Staging table name is generated based on the partition number.
                                                            --Used for partition switchout. Not needed for SQL Server 2016 and above
    ,@useTruncateWhenPossible   bit             = 1         --Specifies whether on SQL Server 2016 and above to use TRUNCATE WITH PARTITION instead of partition switching
    ,@dropStagingTable          bit             = 1         --Specifies whether drop staging table after partition switching.
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    RAISERROR(N'sp_tblDropPartition v 0.4 (2020-12-04) (C) 2014 - 2020 Pavel Pawlowski', 0, 0) WITH NOWAIT;
    RAISERROR(N'=======================================================================', 0, 0) WITH NOWAIT;
    RAISERROR(N'Deletes a parttion from partitioned table by truncating/switching out partition and merging.', 0, 0) WITH NOWAIT;
    RAISERROR(N'', 0, 0) WITH NOWAIT;

    DECLARE 
        @psName                         nvarchar(128)
        ,@productVersion                nvarchar(128) = CONVERT(nvarchar(128), SERVERPROPERTY ('productversion'))
        ,@tblName                       nvarchar(261)
        ,@boundaryType                  nvarchar(5)
        ,@boundaryValue                 sql_variant
        ,@pfName                        nvarchar(128)
        ,@dataType                      nvarchar(128)
        ,@sql                           nvarchar(max)        
        ,@sourcePartitionRange          nvarchar(4000)
        ,@destinationPartitionRange     nvarchar(4000)
        ,@destinationPartitionID        int
        ,@destinationBoundaryValue      sql_variant
        ,@newPartitionRange             nvarchar(4000)
        ,@newPartitionID                int
        ,@printHelp                     bit             = 0

    
    --Table To hold partitions information
    DECLARE @psInfo TABLE(
         [TableName]             nvarchar(261)   NULL       --Name of partitioned table in case table name was provided
        ,[TableID]               int             NULL       --ID of the partitioned table in case table name was provided
        ,[PartitionColumn]       nvarchar(max)   NULL       --List of partition columns used
        ,[PartitionSchemeName]   sysname         NOT NULL   --Partition scheme name
        ,[PartitionSchemeID]     int             NOT NULL   --Partition scheme ID
        ,[PartitionFunctionName] sysname         NOT NULL   --Associated partition function name
        ,[PartitionFunctionID]   int             NOT NULL   --Associated partition function ID
        ,[ParameterDataType]     sysname         NOT NULL   --PF parameter data type
        ,[BoundaryType]          nvarchar(5)     NOT NULL   --Partition function boundary type
        ,[PartitionID]           int             NOT NULL   --ID of the partition defined by partition function
        ,[DestinationFileGroup]  sysname         NOT NULL   --Destination file group of the partition
        ,[LeftBoundaryIncluded]  char(1)         NULL       --Specifies whether left boundary value is included in the partition
        ,[RightBoundaryIncluded] char(1)         NULL       --Specifies whether right boundary value is included in the partition
        ,[LeftBoundary]          sql_variant     NULL       --Left boundary value
        ,[RightBoundary]         sql_variant     NULL       --Right boundary value
        ,[PartitionRange]        nvarchar(4000)  NULL       --Partition range in human readable form [NEXT_USED] for next file group used during partition function split
    )

    DECLARE @switchedTable TABLE (
        TableName               nvarchar(261)
        ,StagingTableName       nvarchar(261)
        ,PartitionID            int
        ,SwithOperation         char(3)
    )

    IF @tableName IS NULL
    BEGIN
        SET @printHelp = 1
    END
    ELSE IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(@tableName) AND type = 'U')
    BEGIN
        RAISERROR(N'The user table %s does not exists', 16, 0, @tableName)
        SET @printHelp = 1
    END

    IF @printHelp = 0 AND (@partitionID IS NULL AND @partitionValue IS NULL)
    BEGIN
        RAISERROR(N'Either @partitionID or @partitionValue has to be specified', 16, 1)
        SET @printHelp = 1
    END

    IF @printHelp = 0 AND (@partitionID IS NOT NULL AND @partitionValue IS NOT NULL)
    BEGIN
        RAISERROR(N'Only one from @partitionID or @partitionValue can be specified', 16, 2)
        SET @printHelp = 1
    END

    IF @printHelp = 1
    BEGIN
        RAISERROR(N'Usage:', 0, 0);
        RAISERROR(N'[sp_tblDropPartition] <<parameters>>
        ', 0, 0) WITH NOWAIT;

        RAISERROR(N'!!! WARNING !!!    !!! WARNING !!!    !!! WARNING !!!    !!! WARNING !!!    !!! WARNING !!!', 0, 0) WITH NOWAIT;
        RAISERROR(N'Even the procedure is using @tableName for partition dropping, it merges partitions in Partition Function,', 0, 0) WITH NOWAIT;
        RAISERROR(N'thuss affecting all parition schemes and table usin corresponding partition function', 0, 0) WITH NOWAIT;
        RAISERROR(N'If partition function is used specified table is used by multiple tables, all tables are affected but', 0, 0) WITH NOWAIT;
        RAISERROR(N'partition truncation or switching is done only on the table specified thus on other tables it is very costly operation', 0, 0) WITH NOWAIT;
        RAISERROR(N'', 0, 0) WITH NOWAIT;
        RAISERROR(N'It is recomended that the partition function is used by single table.', 0, 0) WITH NOWAIT;


        RAISERROR(N'', 0, 0) WITH NOWAIT;
        RAISERROR(N'Parameters:
     @tableName                 nvarchar(261)               --Partitioned table name for partition dropping
     @partitionID               int             = NULL      --Partition to be dropped
     @partitionValue            sql_variant     = NULL      --Value to be used to determine PartitionID. Can be used instead of @partitionID
     @stagingTableName          nvarchar(261)   = NULL      --Staging Table Name. If NULL, Staging table name is generated based on the partition number.
                                                            --Used for partition switchout. Not needed for SQL Server 2016 and above
     @useTruncateWhenPossible   bit             = 1         --Specifies whether on SQL Server 2016 and above to use TRUNCATE WITH PARTITION instead of partition switching
     @dropStagingTable          bit             = 1         --Specifies whether drop staging table after partition switching.
     ', 0, 0) WITH NOWAIT;

        RETURN
    END

    SELECT    --Get Partition Scheme of the table
        @psName             = ds.name
        ,@tblName           = QUOTENAME(SCHEMA_NAME(t.schema_id)) + N'.' + QUOTENAME(t.name)
    FROM sys.tables t
    INNER JOIN sys.indexes i ON i.object_id = t.object_id AND i.index_id <= 1
    INNER JOIN sys.data_spaces ds ON i.data_space_id = ds.data_space_id                
    WHERE
        t.object_id = OBJECT_ID(@tableName)
        AND
        ds.type = 'PS'

    IF @psName IS NULL --Check whether table is partitioned
    BEGIN
        RAISERROR(N'Table %s is not partitioned table. Dropping partitions is only possible on partitioned tables', 16, 4, @tableName) 
        RETURN
    END    

    --Get scheme paritions and boundaries
    INSERT INTO @psInfo
    EXEC sp_HelpPartitionScheme
        @psName         = @psName
        ,@noInfoMsg     = 1

    IF @partitionID IS NULL
    BEGIN
        SELECT
            @partitionID    = psi.PartitionID                        
        FROM @psInfo psi
        WHERE
            (psi.BoundaryType = N'RIGHT' AND (psi.LeftBoundary IS NULL OR psi.LeftBoundary <= @partitionValue) AND (psi.RightBoundary IS NULL OR psi.RightBoundary > @partitionValue))
            OR
            (psi.BoundaryType = N'LEFT' AND (psi.LeftBoundary IS NULL OR psi.LeftBoundary < @partitionValue) AND (psi.RightBoundary IS NULL OR psi.RightBoundary >= @partitionValue))

        IF @partitionID IS NULL
        BEGIN
            RAISERROR(N'Could not determine PartitionID based on @partitionValue', 16, 5);
            RETURN;
        END
    END

    --Get Partition Function name and Boundary information
    SELECT
        @pfName                 = p.PartitionFunctionName
        ,@boundaryValue         = CASE WHEN p.BoundaryType = 'RIGHT' THEN p.LeftBoundary ELSE  p.RightBoundary END
        ,@dataType              = p.ParameterDataType
        ,@sourcePartitionRange  = LTRIM(RTRIM(p.PartitionRange))
        ,@boundaryType          = BoundaryType
    FROM @psInfo p
    WHERE
        p.PartitionID = @partitionID

    IF @boundaryValue IS NULL
    BEGIN
        IF @boundaryType = 'RIGHT'
            RAISERROR(N'Partition boundary type is RIGHT and left most partition was selected. Could not merge partition', 16, 6);
        ELSE
            RAISERROR(N'Partition boundary type is LEFT and right most partition was selected. Could not merge partition', 16, 6);
        RETURN;
    END
    
    SET @destinationPartitionID = @partitionID + CASE WHEN @boundaryType = 'RIGHT' THEN -1 ELSE 1 END;

    SELECT
        @destinationBoundaryValue       = CASE WHEN p.BoundaryType = 'RIGHT' THEN p.LeftBoundary ELSE  p.RightBoundary END
        ,@destinationPartitionRange     = LTRIM(RTRIM(p.PartitionRange))
    FROM @psInfo p
    WHERE 
        PartitionID = @destinationPartitionID


    --If Partition truncation should be used, use it on SQL Sever 2016 and above
    IF CONVERT(int, LEFT(@productVersion, CHARINDEX('.', @productVersion) - 1)) >= 13 AND @useTruncateWhenPossible = 1
    BEGIN
        RAISERROR(N'Truncating partition (%d) in table %s', 0, 0, @partitionID, @tblName) WITH NOWAIT;
        SET @sql = 'TRUNCATE TABLE ' + @tblName + N'WITH (PARTITIONS (' + CONVERT(nvarchar(10), @partitionID) + N'))';
        EXEC (@sql)
    END
    ELSE    --Utilize partition switching to empty partition
    BEGIN
        EXEC [sp_tblSwitchPartition]
            @tableName          = @tblName
            ,@partitionID       = @partitionID
            ,@switchOperation   = 'OUT'
            ,@stagingTableName  = @stagingTableName OUTPUT
            ,@outputScriptOnly  = 0
            ,@noInfoMsg         = 1

        --Drop staging table if we should drop it
        IF @dropStagingTable = 1
        BEGIN
            RAISERROR(N'Dropping staging table %s', 0, 0, @stagingTableName) WITH NOWAIT;
            SET @sql = N'DROP TABLE ' + @stagingTableName;
            EXEC (@sql)
        END
    END

    RAISERROR(N'Merging partition [%d] with range (%s) into partition [%d] with original range (%s)', 0, 0, @partitionID, @sourcePartitionRange, @destinationPartitionID, @destinationPartitionRange) WITH NOWAIT;

    SET @sql = N'DECLARE @rangeTyped ' + QUOTENAME(@dataType) + N' = CONVERT(' + QUOTENAME(@dataType) + N', @range);  ALTER PARTITION FUNCTION ' + QUOTENAME(@pfName) + N' () MERGE RANGE (@rangeTyped)';
    
    --PRINT @sql;
    EXEC sp_executesql @sql, N'@range sql_variant', @range = @boundaryValue

    DELETE FROM @psInfo;

    INSERT INTO @psInfo
    EXEC sp_HelpPartitionScheme
        @psName         = @psName
        ,@noInfoMsg     = 1

    SET @newPartitionID = @partitionID + CASE WHEN @boundaryType = 'RIGHT' THEN -1 ELSE 0 END;

    SELECT
        @newPartitionRange = LTRIM(RTRIM(PartitionRange))
    FROM @psInfo
    WHERE
        PartitionID = @newPartitionID

    RAISERROR(N'Partition [%d] successfully merged into partition [%d]. New PartitionID = [%d] with new Range: (%s)', 0, 0, @partitionID, @destinationPartitionID, @newPartitionID, @newPartitionRange) WITH NOWAIT;
    
END
GO

--Mark Stored Procedure as system object, so it executes in the context of current database.
IF SERVERPROPERTY('EngineEdition') IN (1, 2, 3, 4, 8)
    EXEC(N'EXECUTE sp_ms_marksystemobject ''dbo.sp_tblDropPartition''');
GO
