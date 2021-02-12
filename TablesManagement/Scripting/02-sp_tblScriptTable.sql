/* *****************************************************************************************
                                      AZURE SQL DB Notice

   Comment-out the unsupported USE [master] when running in Azure SQL DB/Synapse Analytics
   or ignore error caused by unsupported USE statement
******************************************************************************************** */

USE [master]
GO
--Detection of correct sp_tblScriptIndexes
DECLARE
     @minVersion        nvarchar(5)      = N'0.60'   --Defines minimum required version of sp_tblScriptIndexes
    ,@definition        nvarchar(max)
    ,@versionPos        int
    ,@foundVersion      int
    ,@minVersionInt     int
    ,@version           nvarchar(5)
    ,@msg               nvarchar(max) = NULL

SELECT
    @definition = m.definition
FROM sys.procedures p
INNER JOIN sys.sql_modules m ON m.object_id = p.object_id
WHERE name = 'sp_tblScriptIndexes'

SELECT 
    @versionPos = PATINDEX('%sp_tblScriptIndexes v __.__ (%', @definition)

IF @versionPos IS NOT NULL
BEGIN
    BEGIN TRY
    SET @minVersionInt = CONVERT(int, REPLACE(@minVersion, N'.', N''));
    SET @version = SUBSTRING(@definition, @versionPos + 22, 5);
    SET @foundVersion = CONVERT(int, REPLACE(@version, N'.', N''));
    END TRY
    BEGIN CATCH
    END CATCH
END

IF @definition IS NULL
BEGIN
    SET @msg = N'Could not locate [sp_tblScriptIndexes] which is required for [sp_tblScriptTable].';
END
ELSE IF @versionPos = 0 OR @foundVersion IS NULL
BEGIN
    SET @msg = N'Could not determine version of [sp_tblScriptIndexes] which is required for [sp_tblScriptTable].';
END
ELSE IF @foundVersion < @minVersionInt
BEGIN
    SET @msg = N'Minimum required version of [sp_tblScriptIndexes]: %s 
Detected version %s'
END

IF @msg IS NOT NULL
BEGIN
    SET @msg = @msg + N' Please run [sp_tblScriptIndexes] script first.
To get latest version visit: https://github.com/PavelPawlowski/SQL-Scripts/tree/master/TablesManagement/Partitioning'
    RAISERROR(@msg, 16, 0, @minVersion, @version) WITH NOWAIT;
    RETURN;
END
ELSE
BEGIN
    RAISERROR(N'Detected version of [sp_tblScriptIndexes]: %s', 0, 0, @version) WITH NOWAIT;
END

RAISERROR(N'Creating [sp_tblScriptTable]', 0, 0) WITH NOWAIT;


IF NOT EXISTS (SELECT 1 FROM sys.all_objects WHERE object_id = OBJECT_ID('[dbo].[sp_tblScriptTable]') AND TYPE = 'P')
    EXECUTE ('CREATE PROCEDURE [dbo].[sp_tblScriptTable] AS BEGIN PRINT ''Container'' END')
GO

/* ****************************************************
sp_tblScriptTable v  0.56 (2021-02-12)

Feedback: mailto:pavel.pawlowski@hotmail.cz

MIT License

Copyright (c) 2014-2021 Pavel Pawlowski

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
    Generates CREATE script for a table

Parameters
    @tableName                      nvarchar(261)                    --Name of the table which should be scripted
    ,@newTableName                  nvarchar(261)   = NULL          --New table Name. If not Null than that name will be used in the table script
    ,@forceScriptCollation          bit             = 0                --Forces scripting of collation even it equals to the database collation
    ,@scriptDefaultConstraints      bit             = 1                --Specifies whether to script DEFAULT CONSTRAINTS
    ,@scriptCheckConstraints        bit             = 1                --Specifies whether to script CHECK CONSTRAINTS
    ,@scriptForeignKeys             bit             = 1                --Specifies whethr to script FOREIGN KEYS
    ,@scriptIdentity                bit             = 1                --Specifies whether identity specification should be sciprited
    ,@partitionID                   int             = 0             --Specifies how the ON [FileGroup] is being scripted    
    ,@scriptPrimaryKey              bit             = 1                --Specifies whether PRIMARY KEY should be scripted
    ,@scriptUniqueConstraints       bit             = 1                --Specifies whether UNIQUE CONSTRAINT should be scripted
    ,@scriptIndexes                 bit             = 1                --Specifies wheteher INDEXES should be scripted
    ,@scriptDisabledIndexes         bit             = 0                --Specifies whether to script disabled indexes
    ,@scriptAlterIndexDisable       bit             = 1                --For Disabled indexes scripts the ALTER INDEX DISABLE
    ,@noInfoMsg                     bit             = 0             --Disbles printing of header and informational messages
    ,@outputScript                  nvarchar(max)   = NULL  OUTPUT  --Outputs script to the @outputScript parameters. Allows utilization of the script in other stored procedures
    ,@outputScriptOnly              bit             = 0             --When true, then script is only returned in @outputScript OUTPUT variable and not as result set
    ,@noXml                         bit             = 0             --Specifies whether the script in the result set is returned as nvarchar(max) or as XML processing instruction

Index types and corresponding bit positions
    1 = Clustered
    2 = Nonclustered
    3 = XML
    4 = Spatial
    5 = Clustered columnstore index - Applies to: SQL Server 2014 through SQL Server 2014.
    6 = Nonclustered columnstore index - Applies to: SQL Server 2012 through SQL Server 2014.
    7 = Nonclustered hash index - Applies to: SQL Server 2014 through SQL Server 2014.
 
Modifications: 
* ***************************************************** */ 
ALTER PROCEDURE [dbo].[sp_tblScriptTable]
    @tableName                      nvarchar(261)    = NULL            --Name of the table which should be scripted
    ,@newTableName                  nvarchar(261)   = NULL          --New table Name. If not Null than that name will be used in the table script
    ,@forceScriptCollation          bit             = 0                --Forces scripting of collation even it equals to the database collation
    ,@scriptDefaultConstraints      bit             = 1                --Specifies whether to script DEFAULT CONSTRAINTS
    ,@scriptCheckConstraints        bit             = 1                --Specifies whether to script CHECK CONSTRAINTS
    ,@scriptForeignKeys             bit             = 1                --Specifies whethr to script FOREIGN KEYS
    ,@scriptIdentity                bit             = 1                --Specifies whether identity specification should be sciprited
    ,@partitionID                   int             = 0             --Specifies how the ON [FileGroup] is being scripted
    ,@scriptPrimaryKey              bit             = 1                --Specifies whether PRIMARY KEY should be scripted
    ,@scriptUniqueConstraints       bit             = 1                --Specifies whether UNIQUE CONSTRAINT should be scripted
    ,@scriptIndexes                 bit             = 1                --Specifies wheteher INDEXES should be scripted
    ,@scriptDisabledIndexes         bit             = 0                --Specifies whether to script disabled indexes
    ,@scriptAlterIndexDisable       bit             = 1                --For Disabled indexes scripts the ALTER INDEX DISABLE
    ,@noInfoMsg                     bit             = 0             --Disbles printing of header and informational messages
    ,@outputScript                  nvarchar(max)   = NULL  OUTPUT  --Outputs script to the @outputScript parameters. Allows utilization of the script in other stored procedures
    ,@outputScriptOnly              bit             = 0             --When true, then script is only returned in @outputScript OUTPUT variable and not as result set
    ,@noXml                     bit             = 0                     --Specifies whether the script in the result set is returned as nvarchar(max) or as XML processing instruction
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE 
        @newTable               nvarchar(261)
        ,@dbCollation           nvarchar(128)
        ,@defaultFilegroup      nvarchar(128)
        ,@maxCheckConstraints   int
        ,@maxForeignKeys        int
        ,@newTableSchema        nvarchar(128)
        ,@newTbName             nvarchar(128)
        ,@printHelp             bit             = 0
        ,@indexScript           nvarchar(max)   = NULL
        ,@xml                   xml

    DECLARE @script TABLE(
        RowID INT NOT NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED
        --,TableScript nvarchar(max)
        ,TableScript xml
    )

    IF @noInfoMsg = 0
    BEGIN
        RAISERROR(N'sp_tblScriptTable v 0.56 (2021-02-12) (C) 2014 - 2021 Pavel Pawlowski', 0, 0) WITH NOWAIT;
        RAISERROR(N'=====================================================================', 0, 0) WITH NOWAIT;
        RAISERROR(N'Generates a create script for a table', 0, 0) WITH NOWAIT;
    END

    IF @tableName IS NULL
        SET @printHelp = 1

    --Split @newTableName into Schema and Table
    SELECT
        @newTbName          = PARSENAME(@newTableName, 1)
        ,@newTableSchema    = PARSENAME(@newTableName, 2)


    SELECT
        @newTable = QUOTENAME(ISNULL(@newTableSchema, SCHEMA_NAME(t.schema_id))) + N'.' + QUOTENAME(ISNULL(@newTbName, t.name))
    FROM sys.tables t
    WHERE object_id = OBJECT_ID(@tableName)

    IF @newTable IS NULL AND @printHelp = 0
    BEGIN
        RAISERROR(N'Provided table name "%s" does not exits', 15, 0, @tableName);
        RETURN;
    END

    IF @printHelp = 1
    BEGIN
        RAISERROR(N'', 0, 0) WITH NOWAIT;
        RAISERROR(N'Usage:', 0, 0);
        RAISERROR(N'[sp_tblScriptTable] <<parameters>>', 0, 0);
        RAISERROR(N'', 0, 0);
        RAISERROR(N'Script is returned as XML processing-instruction to allow easy complete script retrieval.', 0, 0) WITH NOWAIT;
        RAISERROR(N'If not a complete script is returned, check "Maximum Characters Retrieved" for XML in the Query Options of SSMS', 0, 0) WITH NOWAIT;
        RAISERROR(N'', 0, 0);
        RAISERROR(N'Parameters:
    @tableName                      nvarchar(261)   = NULL          --Name of the table which should be scripted
    ,@newTableName                  nvarchar(261)   = NULL          --New table Name. If not Null than that name will be used in the table script
    ,@forceScriptCollation          bit             = 0             --Forces scripting of collation even it equals to the database collation
    ,@scriptDefaultConstraints      bit             = 1             --Specifies whether to script DEFAULT CONSTRAINTS
    ,@scriptCheckConstraints        bit             = 1             --Specifies whether to script CHECK CONSTRAINTS
    ,@scriptForeignKeys             bit             = 1             --Specifies whethr to script FOREIGN KEYS
    ,@scriptIdentity                bit             = 1             --Specifies whether identity specification should be sciprited', 0, 0) WITH NOWAIT;
RAISERROR(N'    ,@partitionID                   int             = 0                 --For Partitioned Indexes:
                                                                          -3 - Do not Script ON [FileGgroupName]
                                                                          -2 - Script ON [DEFAULT]
                                                                          -1 - Script ON [DefaultFileGroupName]
                                                                           0 - For partitioned indexes script ON [PartitionScheme]([fieldName]) 
                                                                               For Non-Partitioned indexes script ON [FileGroupName]
                                                                          >0 - For Partitioned Indexes script ON [FileGroupOfPartitionID]
                                                                               For Non-Partitioned indexes is the same as 0', 0, 0) WITH NOWAIT;
RAISERROR(N'    ,@scriptPrimaryKey              bit             = 1             --Specifies whether PRIMARY KEY should be scripted
    ,@scriptUniqueConstraints       bit             = 1             --Specifies whether UNIQUE CONSTRAINT should be scripted
    ,@scriptIndexes                 bit             = 1             --Specifies wheteher INDEXES should be scripted
    ,@scriptDisabledIndexes         bit             = 0             --Specifies whether to script disabled indexes
    ,@scriptAlterIndexDisable       bit             = 1             --For Disabled indexes scripts the ALTER INDEX DISABLE
    ,@noInfoMsg                     bit             = 0             --Disbles printing of header and informational messages
    ,@outputScript                  nvarchar(max)   = NULL  OUTPUT  --Outputs script to the @outputScript parameters. Allows utilization of the script in other stored procedures
    ,@outputScriptOnly              bit             = 0             --When true, then script is only returned in @outputScript OUTPUT variable and not as result set
    ,@noXml                         bit             = 0             --Specifies whether the script in the result set is returned as nvarchar(max) or as XML processing instruction
    ', 0, 0) WITH NOWAIT;

        RETURN;
    END

    --Get database collation
    SELECT
        @dbCollation=collation_name
    FROM sys.databases
    WHERE database_id = DB_ID()

    --Get Default FileGroup
    SELECT 
        @defaultFilegroup = fg.name 
    FROM sys.filegroups fg
    WHERE 
        fg.is_default = 1 AND fg.type = 'FG'


    SELECT
        @maxCheckConstraints = CASE WHEN @scriptCheckConstraints = 1 THEN 2147483647 ELSE 0 END
        ,@maxForeignKeys = CASE WHEN @scriptForeignKeys = 1 THEN 2147483647 ELSE 0 END


    IF (@scriptPrimaryKey = 1 OR @scriptUniqueConstraints = 1 OR @scriptIndexes = 1)
    BEGIN
        --Add Primary Key and Indexes into the Script
        EXEC sp_tblScriptIndexes
            @tableName                  = @tableName
            ,@newTableName              = @newTable
            ,@partitionID               = @partitionID
            ,@scriptPrimaryKey          = @scriptPrimaryKey
            ,@scriptUniqueConstraints   = @scriptUniqueConstraints
            ,@scriptIndexes             = @scriptIndexes
            ,@scriptDisabledIndexes     = @scriptDisabledIndexes
            ,@scriptAlterIndexDisable   = @scriptAlterIndexDisable
            ,@noInfoMsg                 = 1
            ,@outputScript              = @indexScript OUTPUT
            ,@outputScriptOnly          = 1
    END;


    --INSERT INTO @script (TableScript)
    WITH TableScript(TableScript) AS (
        --Ansi Nulls and Quoted Identifiers
        SELECT
            N'SET ANSI_NULLS ON;' + NCHAR(13) + NCHAR(10)
          + N'SET QUOTED_IDENTIFIER ON;'
             AS TableScript

        UNION ALL
        --Create Table Script
        SELECT
            CONVERT(nvarchar(max),
            N'CREATE TABLE ' + @newTable + ' (' + NCHAR(13) + NCHAR(10) +

            --Table COlumns
            STUFF((
                SELECT
                    N'   ,' + QUOTENAME(c.name) + N' '    --Column Name
                    + CASE c.is_computed
                        WHEN 1 THEN N' AS ' + cc.definition        --Computed Column Defition
                        WHEN 0 THEN        --NON Computed Columns
                                  CASE WHEN t.is_user_defined = 1 THEN QUOTENAME(SCHEMA_NAME(t.schema_id)) + N'.' ELSE N'' END + QUOTENAME(t.name) --Data Type
                                + CASE 
                                    WHEN t.name IN (N'char', N'varchar') THEN N'(' + CASE WHEN c.max_length = -1 THEN N'MAX' ELSE CONVERT(nvarchar(4), c.max_length) END + N')'
                                    WHEN t.name IN (N'nchar', N'nvarchar') THEN N'(' + CASE WHEN c.max_length = -1 THEN N'MAX' ELSE CONVERT(nvarchar(4), c.max_length / 2) END + N')'
                                    WHEN t.name IN (N'datetime2', N'datetimeoffset') THEN N'(' + CONVERT(varchar(4), c.scale) + N')'
                                    WHEN t.name IN (N'decimal', N'numeric') THEN N'(' + CONVERT(nvarchar(4), c.precision) + N', ' + CONVERT(nvarchar(4), c.scale) + N')'
                                    ELSE N''
                                  END --Lenth and precision specification

                                + CASE WHEN c.is_rowguidcol = 1 THEN N' ROWGUIDCOL' ELSE N'' END    --Rowguidcol
                                + CASE WHEN c.collation_name IS NOT NULL AND (@forceScriptCollation = 1 OR c.collation_name <> @dbCollation) THEN N' COLLATE ' + c.collation_name ELSE N'' END --Collation
                                + CASE WHEN c.is_nullable = 1 THEN N' NULL' ELSE N' NOT NULL' END    --Nullability
                                + CASE WHEN c.is_identity = 1 AND @scriptIdentity = 1 THEN N' IDENTITY(' + CONVERT(nvarchar(10), ic.seed_value) + N', ' + CONVERT(nvarchar(10), ic.increment_value) + N')' ELSE N'' END --Identity column
                      END
                    + CASE WHEN @scriptDefaultConstraints = 1 THEN ISNULL(N' CONSTRAINT ' + QUOTENAME(ISNULL(@newTbName + N'_', N'') + dc.name) + N' DEFAULT ' + dc.definition, N'') ELSE N'' END   --DEFAULT Constraint
                    + NCHAR(13)
                FROM sys.columns c 
                LEFT JOIN sys.default_constraints dc ON c.default_object_id = dc.object_id --To get column Default Constraint
                LEFT JOIN sys.computed_columns cc ON cc.object_id = c.object_id AND cc.column_id = c.column_id  --To get computed columns defitions
                LEFT JOIN sys.identity_columns ic ON ic.object_id = c.object_id AND ic.column_id = c.column_id  --To get identity specification
                INNER JOIN sys.types t ON c.user_type_id = t.user_type_id
                WHERE 
                    c.object_id = tbls.object_id
                ORDER BY c.column_id
                FOR XML PATH(N''), TYPE
                ).value(N'.', N'nvarchar(max)'), 1, 4, N'    '
            )
            + N')' --end of Table Columns

            + CASE
            WHEN @partitionID <= -3 THEN N'' --Do not script ON [FileGroup] for XML INDEXES or if @partitionID <= -3
            ELSE
                ISNULL(
                    N' ON ' --Script destination FILEGROUP
                      +  CASE 
                            WHEN @partitionID <= -2 THEN N'[DEFAULT]'
                            WHEN @partitionID = -1 THEN QUOTENAME(@defaultFilegroup) --Script ON [DefaultFileGroupName]
                            WHEN ds.[type] = N'FG' THEN QUOTENAME(ds.name)  --For Non Partitioned, script ON [FileGroupName]
                            WHEN ds.[type] = N'PS' AND @partitionID > 0 THEN QUOTENAME(dfg.name)    --For partitioned script ON [FileGroupOfPartitionID]
                            WHEN ds.[type] = N'PS' AND @partitionID = 0 THEN QUOTENAME(ds.name) + N'(' +    --For partitioned script ON [PartitionScheme]
                                    (
                                        SELECT 
                                            c.name
                                        FROM sys.index_columns ic 
                                        INNER JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
                                        WHERE 
                                            ic.object_id = i.object_id 
                                            AND 
                                            ic.index_id = i.index_id
                                            AND
                                            ic.partition_ordinal = 1
                                    ) + N')'
                            ELSE NULL
                        END
                    ,N''
                )
            END
         + N';') AS TableScript
        FROM sys.tables tbls
        INNER JOIN sys.indexes i ON i.object_id = tbls.object_id AND i.index_id <= 1    --get Heap or ClusteredIndex to retrieve data spaces
        INNER JOIN sys.data_spaces ds ON i.data_space_id = ds.data_space_id                --data_spaces to find out the FileGroup/partition scheme informaiton
        LEFT JOIN sys.partition_schemes ps ON i.data_space_id = ps.data_space_id        --details of partition scheme
        LEFT JOIN sys.destination_data_spaces dds ON dds.partition_scheme_id = i.data_space_id AND ds.[type] = N'PS' AND dds.destination_id = @partitionID --Partitions and destinations
        LEFT JOIN sys.filegroups dfg ON dfg.data_space_id = dds.data_space_id            --Destination file groups for partitioned table
        LEFT JOIN sys.partitions p ON tbls.object_id = p.object_id AND p.index_id <= 1 AND (p.partition_number = @partitionID OR (ds.[type] = N'FG' AND p.partition_number = 1)) --To determine compression
        WHERE 
            tbls.object_id = OBJECT_ID(@tableName)
            AND
            tbls.is_filetable = 0
            --AND t.is_memory_optimized = 0 --FOR SQL 2014

        UNION ALL

        --Check Constraint
        SELECT TOP (@maxCheckConstraints)
            CONVERT(nvarchar(max),
              N'ALTER TABLE ' + @newTable + N' WITH ' + CASE WHEN cc.is_disabled = 1 THEN N'NOCHECK' ELSE  N'CHECK' END + N' ADD CONSTRAINT ' + QUOTENAME(ISNULL(@newTbName + N'_', N'') + cc.name) 
              + N' CHECK ' + CASE WHEN cc.is_not_for_replication = 1 THEN N'NOT FOR REPLICATION ' ELSE N'' END + cc.[definition] + N';' + NCHAR(13) + NCHAR(10)
            + N'ALTER TABLE ' + @newTable + CASE WHEN cc.is_disabled = 1 THEN N' NOCHECK' ELSE N' CHECK' END  + N' CONSTRAINT ' + QUOTENAME(ISNULL(@newTbName + N'_', N'') + cc.name) + N';'

            ) AS TableScript
        FROM sys.tables tbls
        INNER JOIN sys.check_constraints cc ON cc.parent_object_id = tbls.object_id
        WHERE 
            tbls.object_id = OBJECT_ID(@tableName)
            AND
            tbls.is_filetable = 0
            --AND t.is_memory_optimized = 0 --FOR SQL 2014

        UNION ALL

        --Foreign keys
        SELECT TOP (@maxForeignKeys)
            CONVERT(nvarchar(max),
            N'ALTER TABLE ' + @newTable + CASE WHEN fk.is_disabled = 1 THEN N' WITH NOCHECK' ELSE N' WITH CHECK' END + N' ADD CONSTRAINT '
            + QUOTENAME(ISNULL(@newTbName + N'_', N'') + fk.name) + N' FOREIGN KEY(' 
            + STUFF((    --Parent Columns
                SELECT
                    N', ' + QUOTENAME(c.name)
                FROM sys.foreign_key_columns fkc 
                INNER JOIN sys.columns c ON c.object_id = fkc.parent_object_id AND c.column_id = fkc.parent_column_id
                WHERE fkc.constraint_object_id = fk.object_id        
                ORDER BY fkc.constraint_column_id
                FOR XML PATH(N'')
                ), 1, 2, N''
            ) + N')' + NCHAR(13) + NCHAR(10)
            + N'  REFERENCES ' + QUOTENAME(s.name) + N'.' + QUOTENAME(rt.name) + N' ('
            + STUFF(( --Referenced Columns
                SELECT
                    N', ' + QUOTENAME(c.name)
                FROM sys.foreign_key_columns fkc 
                INNER JOIN sys.columns c ON c.object_id = fkc.referenced_object_id AND c.column_id = fkc.referenced_column_id
                WHERE fkc.constraint_object_id = fk.object_id        
                ORDER BY fkc.constraint_column_id
                FOR XML PATH(N'')
                ), 1, 2, N''
            ) + N');' + NCHAR(13) + NCHAR(10)

            + N'ALTER TABLE ' + @newTable + CASE WHEN fk.is_disabled = 1 THEN N' NOCHECK' ELSE N' CHECK' END + N' CONSTRAINT ' + QUOTENAME(fk.name) + N';'
            ) AS TableScript
        FROM sys.tables tbls
        INNER JOIN sys.foreign_keys fk ON fk.parent_object_id = tbls.object_id    --Foreign key information
        INNER JOIN sys.tables rt ON rt.object_id = fk.referenced_object_id    --Referenced table
        INNER JOIN sys.schemas s ON s.schema_id = rt.schema_id    --Referenced schema
        WHERE 
            tbls.object_id = OBJECT_ID(@tableName)
            AND
            tbls.is_filetable = 0
            --AND t.is_memory_optimized = 0 --FOR SQL 2014

        UNION ALL

        SELECT
            @indexScript
        WHERE
            @indexScript IS NOT NULL
    )
    SELECT
        @xml = (
            SELECT
                (
                    SELECT
                        ts.TableScript + NCHAR(13) + NCHAR(10) + NCHAR(13) + NCHAR(10)
                    FROM TableScript ts
                    FOR XML PATH(N''), TYPE
                ).value(N'.', N'nvarchar(max)') 'processing-instruction(table-script)'
            FOR XML PATH(N''), TYPE
        )

    SET @outputScript = @xml.value(N'./processing-instruction()[1]', N'nvarchar(max)');

    IF @outputScriptOnly = 0
    BEGIN
        IF @noXml = 1
            SELECT @outputScript AS IndexScript            
        ELSE
            SELECT @xml AS IndexScript
    END
END
GO

--Mark Stored Procedure as system object, so it executes in the context of current database.
IF SERVERPROPERTY('EngineEdition') IN (1, 2, 3, 4, 8)
    EXEC(N'EXECUTE sp_ms_marksystemobject ''dbo.sp_tblScriptTable''');
GO
