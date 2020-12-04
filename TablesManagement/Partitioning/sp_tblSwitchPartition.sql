/* *****************************************************************************************
                                      AZURE SQL DB Notice

   Comment-out the unsupported USE [master] when running in Azure SQL DB/Synapse Analytics
   or ignore error caused by unsupported USE statement
******************************************************************************************** */
USE [master]
GO

--Detection of correct sp_tblScriptTable
DECLARE
     @minVersion        nvarchar(5)      = N'0.55'   --Defines minimum required version of sp_tblScriptIndexes
    ,@definition        nvarchar(max)
    ,@versionPos        int
    ,@foundVersion      int
    ,@minVersionInt     int
    ,@version           nvarchar(5)
    ,@msg               nvarchar(max) = NULL

SELECT
    @definition = m.definition
FROM master.sys.procedures p
INNER JOIN master.sys.sql_modules m ON m.object_id = p.object_id
WHERE name = 'sp_tblScriptTable'

SELECT 
    @versionPos = PATINDEX('%sp_tblScriptTable v __.__ (%', @definition)

IF @versionPos IS NOT NULL
BEGIN
    BEGIN TRY
    SET @minVersionInt = CONVERT(int, REPLACE(@minVersion, N'.', N''));
    SET @version = SUBSTRING(@definition, @versionPos + 20, 5);
    SET @foundVersion = CONVERT(int, REPLACE(@version, N'.', N''));
    END TRY
    BEGIN CATCH
    END CATCH
END

IF @definition IS NULL
BEGIN
    SET @msg = N'Could not locate [sp_tblScriptTable] which is required for [sp_tblSwitchPartition].';
END
ELSE IF @versionPos = 0 OR @foundVersion IS NULL
BEGIN
    SET @msg = N'Could not determine version of [sp_tblScriptTable] which is required for [sp_tblSwitchPartition].';
END
ELSE IF @foundVersion < @minVersionInt
BEGIN
    SET @msg = N'Minimum required version of [sp_tblScriptTable]: %s 
Detected version %s'
END

IF @msg IS NOT NULL
BEGIN
    SET @msg = @msg + N' Please run [sp_tblScriptTable] script first.
To get latest version visit: https://github.com/PavelPawlowski/SQL-Scripts/tree/master/TablesManagement/Partitioning'
    RAISERROR(@msg, 16, 0, @minVersion, @version) WITH NOWAIT;
    RETURN;
END
ELSE
BEGIN
    RAISERROR(N'Detected version of [sp_tblScriptTable]: %s', 0, 0, @version) WITH NOWAIT;
END

RAISERROR(N'Creating [sp_tblSwitchPartition]', 0, 0) WITH NOWAIT;


IF NOT EXISTS (SELECT 1 FROM sys.all_objects WHERE object_id = OBJECT_ID('[dbo].[sp_tblSwitchPartition]') AND TYPE = 'P')
    EXECUTE ('CREATE PROCEDURE [dbo].[sp_tblSwitchPartition] AS BEGIN PRINT ''Container'' END')
GO
/* ****************************************************
sp_tblSwitchPartition v  0.52 (2020-12-04)

Feedback: mailto:pavel.pawlowski@hotmail.cz

MIT License

Copyright (c) 2014 - 2020 Pavel Pawlowski

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
    Switches partition OUT to staging table or IN from staging table

 Parameters:
    @tableName          nvarchar(261)                   --Partitioned table name for partition switching
    ,@partitionID       int             = NULL  OUTPUT  --Partition to be Switched
    ,@partitionValue    sql_variant     = NULL          --Value to be used to determine PartitionID. Can be used instead of @partitionID
    ,@switchOperation   CHAR(3)         = 'OUT'         --Direction of the partition switching. IN or OUT
    ,@stagingTableName  nvarchar(261)   = NULL  OUTPUT    --Staging Table Name. If NULL, Staging table name is generated based on the partition number
    ,@outputScript              xml     = NULL  OUTPUT  --allows utilization of the script in other stored procedures
    ,@outputScriptOnly          bit     = 0             --0=partition switching is done executed;1=script is returned in outputscript parameter only;NULL output script is produced as a result set also
    ,@noInfoMsg         bit             = 0             --Disbles printing of header and informationals messages

* ***************************************************** */ 
ALTER PROCEDURE [dbo].[sp_tblSwitchPartition]
    @tableName          nvarchar(261)                   --Partitioned table name for partition switching
    ,@partitionID       int             = NULL  OUTPUT  --Partition to be Switched. If Value is provided instead of @partitionID, then it returns as an OUTPUT corresponding PartitionID for the provided Value
    ,@partitionValue    sql_variant     = NULL          --Value to be used to determine PartitionID. Can be used instead of @partitionID
    ,@switchOperation   CHAR(3)         = 'OUT'         --Direction of the partition switching. IN or OUT
    ,@stagingTableName  nvarchar(261)   = NULL  OUTPUT    --Staging Table Name. If NULL, Staging table name is generated based on the partition number. Outputs the used staging table name. Usefull when input value is NULL and staging table is generated
    ,@outputScript              xml     = NULL  OUTPUT  --allows utilization of the script in other stored procedures
    ,@outputScriptOnly          bit     = 0             --0=partition switching is done executed;1=script is returned in outputscript parameter only;NULL output script is produced as a result set also
    ,@noInfoMsg         bit             = 0             --Disbles printing of header and informationals messages
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE 
         @stagingTableFullName      nvarchar(261)
        ,@tblName                   nvarchar(128)
        ,@tblSchema                 nvarchar(128)
        ,@newStagingTableName       nvarchar(128)
        ,@newStagingTableSchema     nvarchar(128)
        ,@psName                    nvarchar(128)
        ,@parameterDataType         nvarchar(128)
        ,@tsql                      nvarchar(max)
        ,@boundaryType              nvarchar(5)
        ,@leftBoundary              sql_variant
        ,@rightBoundary             sql_variant
        ,@tableScriptXml            xml
        ,@tableScript               nvarchar(max);

    --Table To hold partitions information
    DECLARE @psInfo TABLE(
        [PartitionSchemeName]       sysname         NOT NULL   --Partition scheme name
        ,[PartitionFunctionName]    sysname         NOT NULL   --Associated partition function name
        ,[PartitionFunctionID]      int             NOT NULL   --Associated partition function ID
        ,[ParameterDataType]        sysname         NOT NULL   --PF parameter data type
        ,[BoundaryType]             nvarchar(5)     NOT NULL   --Partition function boundary type
        ,[PartitionID]              int             NOT NULL   --ID of the partition defined by partition function
        ,[DestinationFileGroup]     sysname         NOT NULL   --Destination file group of the partition
        ,[LeftBoundaryIncluded]     char(1)         NULL       --Specifies whether left boundary value is included in the partition
        ,[RightBoundaryIncluded]    char(1)         NULL       --Specifies whether right boundary value is included in the partition
        ,[LeftBoundary]             sql_variant     NULL       --Left boundary value
        ,[RightBoundary]            sql_variant     NULL       --Right boundary value
        ,[PartitionRange]           nvarchar(4000)  NULL       --Partition range in human readable form [NEXT_USED] for next file group used during partition function split
    )

    --Table to hold staging table creation script
    DECLARE @switchScript TABLE (
        ID int NOT NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED,
        TableScript nvarchar(max)
    )

    IF @noInfoMsg = 0
    BEGIN
        RAISERROR(N'sp_tblSwitchPartition v 0.52 (2020-12-04) (C) 2014 - 2020 Pavel Pawlowski', 0, 0) WITH NOWAIT;
        RAISERROR(N'=========================================================================', 0, 0) WITH NOWAIT;
        RAISERROR(N'Switches partition IN to or OUT of partitioned table', 0, 0) WITH NOWAIT;
    END

    
    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID(@tableName) AND type = 'U')
    BEGIN
        RAISERROR(N'The user table %s does not exists', 16, 0, @tableName)
        RETURN
    END

    IF (@partitionID IS NULL AND @partitionValue IS NULL)
    BEGIN
        RAISERROR(N'Either @partitionID or @partitionValue has to be specified', 16, 1)
        RETURN
    END

    IF (@partitionID IS NOT NULL AND @partitionValue IS NOT NULL)
    BEGIN
        RAISERROR(N'Only one from @partitionID or @partitionValue can be specified', 16, 2)
        RETURN
    END


    IF UPPER(@switchOperation) NOT IN (N'IN', N'OUT')
    BEGIN
        RAISERROR(N'The @switchOperation has to be ''IN'' or ''OUT''', 16, 3)
        RETURN
    END

    SELECT    --Get Partition Scheme of the table
        @psName = ds.name
    FROM sys.tables t
    INNER JOIN sys.indexes i ON i.object_id = t.object_id AND i.index_id <= 1
    INNER JOIN sys.data_spaces ds ON i.data_space_id = ds.data_space_id                
    WHERE
        t.object_id = OBJECT_ID(@tableName)
        AND
        ds.type = 'PS'

    IF @psName IS NULL --Check whether table is partitioned
    BEGIN
        RAISERROR(N'Table %s is not partitioned table. Partition switching is only possible on partitioned tables', 16, 2, @tableName) 
        RETURN
    END

    --Get scheme paritions and boundaries
    INSERT INTO @psInfo
    EXEC sp_HelpPartitionScheme
        @psName         = @psName
        ,@noInfoMsg     = 1

    IF @partitionValue IS NOT NULL
    BEGIN
        SELECT
            @partitionID = psi.PartitionID            
        FROM @psInfo psi
        WHERE
            (psi.BoundaryType = N'RIGHT' AND (psi.LeftBoundary IS NULL OR psi.LeftBoundary <= @partitionValue) AND (psi.RightBoundary IS NULL OR psi.RightBoundary > @partitionValue))
            OR
            (psi.BoundaryType = N'LEFT' AND (psi.LeftBoundary IS NULL OR psi.LeftBoundary < @partitionValue) AND (psi.RightBoundary IS NULL OR psi.RightBoundary >= @partitionValue))
    END
    
    SELECT
        @parameterDataType = psi.ParameterDataType
    FROM @psInfo psi
    WHERE
        PartitionID = @partitionID

    IF @parameterDataType IS NULL
    BEGIN
        RAISERROR(N'Could not determine @partitionID or provided @partitionID does not exists', 16, 3);
        RETURN;
    END

    --Split @stagingTableName into Schem and Table Name
    SELECT
        @tblName = PARSENAME(@stagingTableName, 1)
        ,@tblSchema = PARSENAME(@stagingTableName, 2)


    --Build new table names
    SELECT
        --@stagingTableFullName = QUOTENAME(ISNULL(@tblSchema, SCHEMA_NAME(t.schema_id))) + N'.' + QUOTENAME(ISNULL(@tblName, N'staging_' + t.name + N'_P' + RIGHT(N'00000' + CONVERT(nvarchar(10), @partitionID), 5)))
        @newStagingTableName = ISNULL(@tblName, N'staging_' + t.name + N'_P' + RIGHT(N'00000' + CONVERT(nvarchar(10), @partitionID), 5)) 
        ,@newStagingTableSchema = ISNULL(@tblSchema, SCHEMA_NAME(t.schema_id))
    FROM sys.tables t
    WHERE object_id = OBJECT_ID(@tableName)

    SELECT
        @stagingTableFullName = QUOTENAME(@newStagingTableSchema) + N'.' + QUOTENAME(@newStagingTableName)


    IF NOT EXISTS(    --Check whether parition exists in the partitioned table
        SELECT
        *
        FROM sys.tables t
        INNER JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id <= 1
        WHERE
            t.object_id = OBJECT_ID(@tableName)
            AND
            p.partition_number = @partitionID
        )
    BEGIN
        RAISERROR(N'The partition [%d] does not exists in the table %s', 16, 4, @partitionID, @tableName)
        RETURN
    END

    IF UPPER(@switchOperation) = 'IN' --   =====================   SWITCH IN   =================
    BEGIN        --Checks for SWITCH IN
        IF @outputScriptOnly = 0 AND EXISTS(    --Check whether destination partition is empty
                SELECT
                1
                FROM sys.tables t
                INNER JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id <= 1
                WHERE 
                    t.object_id = OBJECT_ID(@tableName)
                AND
                    p.partition_number = @partitionID
                GROUP BY t.object_id
                HAVING
                    SUM(p.rows) > 0
            )
        BEGIN
            RAISERROR(N'Destination partition [%d] of table %s is not empty. Cannot proceed with SWITCH IN', 16, 5, @partitionID, @tableName)
            RETURN
        END

        IF NOT EXISTS(SELECT 1 FROM sys.tables t WHERE t.object_id = OBJECT_ID(@stagingTableFullName) AND t.type = 'U')
        BEGIN
            RAISERROR(N'Staging table "%s" does not exists', 16, 7, @stagingTableFullName);
            RETURN;
        END

        IF EXISTS(    --Check whether source table is partitioned
                SELECT
                    1
                from sys.tables t
                INNER JOIN sys.indexes i ON i.object_id = t.object_id AND i.index_id <= 1
                INNER JOIN sys.data_spaces ds on ds.data_space_id = i.data_space_id
                WHERE 
                    t.object_id = OBJECT_ID(@stagingTableFullName)
                    AND
                    ds.type = N'PS'
            )
        BEGIN
            RAISERROR(N'Source staging table %s is partitioned. Cannot SWITCH IN from partitioned table', 16, 6, @stagingTableFullName)
            RETURN
        END

        IF @outputScriptOnly = 0
            RAISERROR(N'Switching from %s to %s IN partition [%d]', 0, 0, @stagingTableFullName, @tableName, @partitionID) WITH NOWAIT
        ELSE
            INSERT INTO @switchScript(TableScript)
            SELECT N'RAISERROR(N''Switching from  ' + @stagingTableFullName + N' to ' + @tableName + N'INT partition [' +  CONVERT(nvarchar(10), @partitionID) + N']'', 0, 0) WITH NOWAIT;'

        INSERT INTO @switchScript
        SELECT N'ALTER TABLE ' + @stagingTableFullName + N' SWITCH TO ' + @tableName + N' PARTITION ' + CONVERT(nvarchar(10), @partitionID)
    END
    ELSE IF UPPER(@switchOperation) = 'OUT' --   =====================   SWITCH OUT   =================
    BEGIN
        IF @outputScriptOnly = 0 AND EXISTS( --Check whether staging table is empty
                SELECT
                    1
                FROM sys.tables t
                INNER JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id <= 1
                WHERE
                    t.object_id = OBJECT_ID(@stagingTableFullName)
                GROUP BY t.object_id
                HAVING
                    SUM(p.rows) > 0
            )
        BEGIN
            RAISERROR(N'Destination staging table %s is not empty. Cannot proceed with SWITCH OUT', 16, 7, @stagingTableFullName)
            RETURN
        END


        INSERT INTO @switchScript(TableScript)
            SELECT N'BEGIN TRANSACTION;'
            UNION ALL
            SELECT 'SET XACT_ABORT ON;'

        IF EXISTS( --If the staging table exists, drop the table
                SELECT
                    *
                FROM sys.tables t
                WHERE t.object_id = OBJECT_ID(@stagingTableFullName) AND t.type = N'U'
            )
        BEGIN
            INSERT INTO @switchScript(TableScript)
            SELECT
                N'DROP TABLE ' + @stagingTableFullName + N';'
        END    
    
        --Staging Table Script --Do not script primary key, constraints and indexes to avoid nested INSERT INTO
        --INSERT INTO @switchScript(TableScript)
        EXEC sp_tblScriptTable
            @tableName                      = @tableName                --Name of the table which should be scripted
            ,@newTableName                  = @stagingTableFullName     --New table Name. If not Null than that name will be used in the table script
            ,@forceScriptCollation          = 1                         --Forces scription collation even it equals to the database collation
            ,@scriptDefaultConstraints      = 1                         --Specifies whether to script DEFAULT CONSTRAINTS
            ,@scriptCheckConstraints        = 1                         --Specifies whether to script CHECK CONSTRAINTS
            ,@scriptForeignKeys             = 1                         --Specifies whethr to script FOREIGN KEYS
            ,@scriptIdentity                = 0                         --Do not script identity for staging table
            ,@partitionID                   = @partitionID              --For Partitioned Indexes: >0 Script filegroup of selected partition. 0 script PartitionScheme, -1 = script default filegorup; 
            ,@scriptPrimaryKey              = 1                         --Specifies whether PRIMARY KEY should be scripted
            ,@scriptUniqueConstraints       = 1                         --Specifies whether UNIQUE CONSTRAINT should be scripted
            ,@scriptIndexes                 = 1                         --Specifies wheteher INDEXES should be scripted
            ,@scriptDisabledIndexes         = 0                         --Specifies whether to script disabled indexes
            ,@scriptAlterIndexDisable       = 1                         --For Disabled indexes scripts the ALTER INDEX DISABLE
            ,@noInfoMsg                     = 1
            ,@outputScript                  = @tableScriptXml   OUTPUT
            ,@outputScriptOnly              = 1
        
        --Insert table script into staging script
        INSERT INTO @switchScript(TableScript)
        SELECT @tableScriptXml.value('./processing-instruction()[1]', 'nvarchar(max)');

        SELECT
            @boundaryTYpe = BoundaryType
            ,@leftBoundary = LeftBoundary
            ,@rightBoundary = RightBoundary
        FROM @psInfo i
        WHERE
            i.PartitionSchemeName = @psName
            AND
            i.PartitionID = @partitionID

        --Add constraint for Selected partition boundaries
        INSERT INTO @switchScript(TableScript)
        SELECT
            N'ALTER TABLE ' + @stagingTableFullName + N' WITH CHECK ADD CONSTRAINT ' + QUOTENAME(N'chk_' + @newStagingTableName + N'_Partition_' + CONVERT(nvarchar(10), @partitionID))
            + N' CHECK (' 
            + CASE --Left boundary condition
                WHEN @leftBoundary IS NOT NULL THEN QUOTENAME(c.name) + CASE @boundaryType WHEN N'RIGHT' THEN N'>=' ELSE N'>' END + N'''' 
                    + CASE @parameterDataType
                        WHEN N'date' THEN CONVERT(nvarchar(30), @leftBoundary, 112) 
                        WHEN N'datetime' THEN CONVERT(nvarchar(30), @leftBoundary, 126) 
                        WHEN N'datetime2' THEN CONVERT(nvarchar(30), @leftBoundary, 126) 
                        WHEN N'datetimeoffset' THEN CONVERT(nvarchar(30), @leftBoundary, 127)
                        ELSE CONVERT(nvarchar(30), @leftBoundary) 
                      END
                    + N''''
                ELSE N''
              END
            + CASE WHEN @leftBoundary IS NOT NULL AND @rightBoundary IS NOT NULL THEN N' AND ' ELSE N'' END
            + CASE --Right boundary condition
                WHEN @rightBoundary IS NOT NULL THEN QUOTENAME(c.name) + CASE @boundaryType WHEN N'RIGHT' THEN N'<' ELSE N'<=' END + N'''' 
                    + CASE @parameterDataType
                        WHEN N'date' THEN CONVERT(nvarchar(30), @rightBoundary, 112) 
                        WHEN N'datetime' THEN CONVERT(nvarchar(30), @rightBoundary, 126) 
                        WHEN N'datetime2' THEN CONVERT(nvarchar(30), @rightBoundary, 126) 
                        WHEN N'datetimeoffset' THEN CONVERT(nvarchar(30), @rightBoundary, 127)
                        ELSE CONVERT(nvarchar(30), @rightBoundary) 
                      END
                + N''''
                ELSE N''
              END
            + N');' + NCHAR(13) + NCHAR(10)
            + N'ALTER TABLE ' + @stagingTableFullName + N' CHECK CONSTRAINT ' + QUOTENAME(N'chk_' + @newStagingTableName + N'_Partition_' + CONVERT(nvarchar(10), @partitionID)) + N';'
        FROM sys.tables t
        INNER JOIN sys.indexes i ON i.object_id = t.object_id AND i.index_id <= 1 --get clustered index or heap
        INNER JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.partition_ordinal = 1 --get partition ordinal column for the constraint
        INNER JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id   --get column details
        WHERE
            t.object_id = OBJECT_ID(@tableName)


        IF @outputScriptOnly = 0
            RAISERROR(N'Switching OUT partition [%d] from %s to %s', 0, 0, @partitionID, @tableName, @stagingTableFullName) WITH NOWAIT
        ELSE
            INSERT INTO @switchScript(TableScript)
            SELECT N'RAISERROR(N''Switching OUT partition ' + CONVERT(nvarchar(10), @partitionID) + N' from ' + @tableName + N' to ' + @stagingTableFullName + N''', 0, 0) WITH NOWAIT;'

        --Add Partition Switch Command
        INSERT INTO @switchScript(TableScript)
        SELECT N'ALTER TABLE ' + @tableName + N' SWITCH PARTITION ' + CONVERT(nvarchar(10), @partitionID) + N' TO ' + @stagingTableFullName + N';'
        
        INSERT INTO @switchScript(TableScript)
            SELECT N'COMMIT TRANSACTION;'
    END

    SET @tsql = N''

    SELECT
        @tsql += TableScript + NCHAR(13) + NCHAR(10)
    FROM @switchScript

    SET @outputScript = (SELECT @tsql 'processing-instruction(partition-switch)' FOR XML PATH(N''), TYPE)

    SET @stagingTableName = @stagingTableFullName

    --PRINT @tsql
    IF @outputScriptOnly = 0
        EXEC (@tsql)
    ELSE IF @outputScriptOnly IS NULL
        SELECT @outputScript AS PartitioniSwitchScript

END
GO

--Mark Stored Procedure as system object, so it executes in the context of current database.
IF SERVERPROPERTY('EngineEdition') IN (1, 2, 3, 4, 8)
    EXEC(N'EXECUTE sp_ms_marksystemobject ''dbo.sp_tblSwitchPartition''');
GO
