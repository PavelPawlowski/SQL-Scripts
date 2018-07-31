USE [master]
GO
IF NOT EXISTS (SELECT 1 FROM sys.all_objects WHERE object_id = OBJECT_ID('[dbo].[sp_tblScriptIndexes]') AND TYPE = 'P')
	EXECUTE ('CREATE PROCEDURE [dbo].[sp_tblScriptIndexes] AS BEGIN PRINT ''Container'' END')
GO
/* ****************************************************
sp_tblScriptIndexes v  0.65 (2018-07-30)

Feedback: mailto:pavel.pawlowski@hotmail.cz

MIT License

Copyright (c) 2014 - 2018 Pavel Pawlowski

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
    written consent.

Description: 
	Scripts indexes for specifed table


Parameters:

	@tableName                      nvarchar(261)   = NULL                  --Table which indexes should be scripted
	,@newTableName                  nvarchar(261)   = NULL                  --New table Name. If NULL then Indexes are scripted for original table
	,@partitionID                   int             = 0                     --Specifies how the ON [FileGroup] is being scripted
	,@scriptPrimaryKey              bit             = 1		                --Specifies whether Primary key should be scripted
	,@scriptUniqueConstraints       bit             = 1		                --Specifies whether Unique Constraints should be scripted
	,@scriptIndexes                 bit             = 1		                --Specifies wheteher Indexes should be scripted
	,@scriptDisabledIndexes         bit             = 0		                --Specifies whether to script disabled indexes
	,@scriptAlterIndexDisable       bit             = 1		                --For Disabled indexes scripts the ALTER INDEX DISABLE
    ,@scriptDropExisting            bit             = 1                     --Scripts DROP_EXISTING = ON or DROP_EXISTING = OFF
	,@scriptIndexTypes              nvarchar(100)   = N'1,2,3,5,6'          --Bitmask of Index types to Script Currently 1,2,5,6
    ,@indexNames                    nvarchar(max)   = '%'                   --Comma Separated List of Index Names to Script. Supports LIKE wildcards
    ,@noInfoMsg                     bit             = 0                     --Disbles printing of header and informational messages
    ,@outputScript                  nvarchar(max)   = NULL          OUTPUT  --Outputs script to the @outputScript parameters. Allows utilization of the script in other stored procedures
    ,@outputScriptOnly              bit             = 0                     --When true, then script is only returned in @outputScript OUTPUT variable and not as result set
    ,@noXml                         bit             = 0                     --Specifies whether the script in the result set is returned as nvarchar(max) or as XML processing instruction
    ,@onFileGroup                   nvarchar(256)   = NULL                  --When specified then the clause is used as the ON [@onFileGroupClause]. Overrides the @partitionID parameter.
    ,@dataCompression               nvarchar(5)     = NULL                  --When specified the overrides the current index data compression
    ,@columnstoreDataCompression    nvarchar(50)    = NULL                  --When specified then overrides the current columnstore data compression type
    

Index types and corresponding bit positions
	1 = Clustered
	2 = Nonclustered
	3 = XML
	4 = Spatial
	5 = Clustered columnstore index - Applies to: SQL Server 2014 and above
	6 = Nonclustered columnstore index - Applies to: SQL Server 2012 and above
	7 = Nonclustered hash index - Applies to: SQL Server 2014 and above
 
* ***************************************************** */ 
ALTER PROCEDURE [dbo].[sp_tblScriptIndexes]
	@tableName                      nvarchar(261)   = NULL                  --Table which indexes should be scripted
	,@newTableName                  nvarchar(261)   = NULL                  --New table Name. If NULL then Indexes are scripted for original table
	,@partitionID                   int             = 0                     --Specifies how the ON [FileGroup] is being scripted
	,@scriptPrimaryKey              bit             = 1		                --Specifies whether Primary key should be scripted
	,@scriptUniqueConstraints       bit             = 1		                --Specifies whether Unique Constraints should be scripted
	,@scriptIndexes                 bit             = 1		                --Specifies wheteher Indexes should be scripted
	,@scriptDisabledIndexes         bit             = 0		                --Specifies whether to script disabled indexes
	,@scriptAlterIndexDisable       bit             = 1		                --For Disabled indexes scripts the ALTER INDEX DISABLE
    ,@scriptDropExisting            bit             = 1                     --Scripts DROP_EXISTING = ON or DROP_EXISTING = OFF
	,@scriptIndexTypes              nvarchar(100)   = N'1,2,3,5,6'          --Bitmask of Index types to Script Currently 1,2,5,6
    ,@indexNames                    nvarchar(max)   = '%'                   --Comma Separated List of Index Names to Script. Supports LIKE wildcards
    ,@noInfoMsg                     bit             = 0                     --Disbles printing of header and informational messages
    ,@outputScript                  nvarchar(max)   = NULL          OUTPUT  --Outputs script to the @outputScript parameters. Allows utilization of the script in other stored procedures
    ,@outputScriptOnly              bit             = 0                     --When true, then script is only returned in @outputScript OUTPUT variable and not as result set
    ,@noXml                         bit             = 0                     --Specifies whether the script in the result set is returned as nvarchar(max) or as XML processing instruction
    ,@onFileGroup                   nvarchar(256)   = NULL                  --When specified then the clause is used as the ON [@onFileGroupClause]
    ,@dataCompression               nvarchar(5)     = NULL                  --When specified the overrides the current index data compression
    ,@columnstoreDataCompression    nvarchar(50)    = NULL                  --When specified then overrides the current columnstore data compression type
AS
BEGIN	
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE 
         @newTable          nvarchar(261)
        ,@newTableSchema    nvarchar(128)
        ,@newTbName         nvarchar(128)
        ,@defaultFilegroup  nvarchar(128)
        ,@script            nvarchar(max)
        ,@printHelp         bit             = 0
        ,@xml               xml
        ,@msg               nvarchar(max)

    DECLARE @names TABLE (
        indexName   nvarchar(128)
    )
    
    IF OBJECT_ID(N'tempdb..#indexNames') IS NOT NULL
        DROP TABLE #indexNames;

    CREATE TABLE #indexNames (
        IndexName nvarchar(120) COLLATE DATABASE_DEFAULT NOT NULL  PRIMARY KEY CLUSTERED
    )

    IF @noInfoMsg = 0
    BEGIN
        RAISERROR(N'sp_tblScriptIndexes v 0.65 (2018-07-30) (C) 2014 - 2018 Pavel Pawlowski', 0, 0) WITH NOWAIT;
        RAISERROR(N'=======================================================================', 0, 0) WITH NOWAIT;
        RAISERROR(N'Generates indexes script for table', 0, 0) WITH NOWAIT;
    END

    IF @tableName IS NULL
        SET @printHelp = 1

    IF NULLIF(@tableName, N'') IS NULL
        SET @printHelp = 1;


    DECLARE @indexes TABLE (
        IndexType tinyint
    )

    IF @printHelp = 0 AND NOT EXISTS(SELECT * FROM sys.tables WHERE object_id = OBJECT_ID(@tableName))
    BEGIN
        SET @printHelp = 1;
        RAISERROR(N'Provided table "%s" does not exists.', 15, 0, @tableName);
    END

    IF @printHelp = 0
    BEGIN
        SET @xml = CONVERT(xml, N'<idx>'+ REPLACE(@scriptIndexTypes, N',', N'</idx><idx>') + N'</idx>')
        INSERT INTO @indexes(IndexType)
        SELECT
            n.value(N'.', N'tinyint') AS IndexType
        FROM @xml.nodes(N'idx') AS T(n);

        SET @msg = STUFF((SELECT N',' + CONVERT(nvarchar(10), IndexType) FROM @indexes WHERE IndexType NOT IN (1, 2, 3, 5, 6) FOR XML PATH('')), 1, 1, N'');

        IF @msg <> N''
        BEGIN
            RAISERROR(N'Index types [%s] are not supported index types', 15, 0, @msg) WITH NOWAIT;
            SET @printHelp = 1
        END

        SET @xml = N'<i>' + REPLACE(ISNULL(@indexNames, N'%'), N',', N'</i><i>') + N'</i>'
        INSERT INTO @names(indexName)
        SELECT DISTINCT
            LTRIM(RTRIM(N.value('.', N'nvarchar(128)')))
        FROM @xml.nodes(N'/i') T(N)

        --get index names to script
        INSERT INTO #indexNames(IndexName)
        SELECT DISTINCT
            i.name
        FROM sys.indexes i
        INNER JOIN @names n ON i.object_id = OBJECT_ID(@tableName) AND i.name LIKE n.indexName AND LEFT(n.indexName, 1) <> N'-'
        
        EXCEPT
            
        SELECT
            i.name
        FROM sys.indexes i
        INNER JOIN @names n ON i.object_id = OBJECT_ID(@tableName) AND i.name LIKE RIGHT(n.indexName, LEN(n.indexName) -1) AND LEFT(n.indexName, 1) = N'-'

        --Get Default FileGroup
        SELECT 
            @defaultFilegroup = fg.name 
        FROM sys.filegroups fg
        WHERE 
            fg.is_default = 1 AND fg.type = 'FG'
    END


    IF @printHelp = 1
    BEGIN
        RAISERROR(N'', 0, 0) WITH NOWAIT;
        RAISERROR(N'Udage:
sp_tblScriptIndexes <parameters>', 0,0) WITH NOWAIT;
		RAISERROR(N'', 0, 0);
        RAISERROR(N'Script is returned as XML processing-instruction to allow easy complete script retrieval.', 0, 0) WITH NOWAIT;
        RAISERROR(N'If not a complete script is returned, check "Maximum Characters Retrieved" for XML in the Query Options of SSMS', 0, 0) WITH NOWAIT;
        RAISERROR(N'', 0, 0) WITH NOWAIT;

        RAISERROR(N'Parameters:

    @tableName                      nvarchar(261)   = NULL                  --Table which indexes should be scripted
    ,@newTableName                  nvarchar(261)   = NULL                  --New table Name. If NULL then Indexes are scripted for original table
    ,@partitionID                   int             = 0                     --For Partitioned Indexes:
                                                                              -3 - Do not Script ON [FileGgroupName]
                                                                              -2 - Script ON [DEFAULT]
                                                                              -1 - Script ON [DefaultFileGroupName]
                                                                               0 - For partitioned indexes script ON [PartitionScheme]([fieldName]) 
                                                                                   For Non-Partitioned indexes script ON [FileGroupName]
                                                                              >0 - For Partitioned Indexes script ON [FileGroupOfPartitionID]
                                                                                   For Non-Partitioned indexes is the same as 0
    ,@scriptPrimaryKey              bit             = 1		                --Specifies whether Primary key should be scripted
    ,@scriptUniqueConstraints       bit             = 1		                --Specifies whether Unique Constraints should be scripted
    ,@scriptIndexes                 bit             = 1		                --Specifies wheteher Indexes should be scripted',0, 0) WITH NOWAIT;
RAISERROR(N'    ,@scriptDisabledIndexes         bit             = 0		                --Specifies whether to script disabled indexes
    ,@scriptAlterIndexDisable       bit             = 1		                --For Disabled indexes scripts the ALTER INDEX DISABLE
    ,@scriptDropExisting            bit             = 1                     --Scripts DROP_EXISTING = ON or DROP_EXISTING = OFF
    ,@scriptIndexTypes              nvarchar(100)   = N''1,2,3,5,6''          --Bitmask of Index types to Script Currently 1,2,5,6
    ,@indexNames                    nvarchar(max)   = ''%%''                   --Comma Separated List of Index Names to Script. Supports LIKE wildcards
    ,@noInfoMsg                     bit             = 0                     --Disbles printing of header and informational messages
    ,@outputScript                  xml             = NULL          OUTPUT  --Outputs script to the @outputScript parameters.
                                                                              Allows utilization of the script in other stored procedures
    ,@outputScriptOnly              bit             = 0                     --When true, then script is only returned in @outputScript OUTPUT variable 
                                                                              and not as result set', 0, 0) WITH NOWAIT;
RAISERROR(N'    ,@noXml                         bit             = 0                     --Specifies whether the script in the result set is returned as nvarchar(max) or as XML processing instruction
    ,@onFileGroup                   nvarchar(256)   = NULL                  --When specified then the clause is used as the ON [@onFileGroupClause]
                                                                              Overrides the @partitionID parameter behavior.
                                                                              Useful for converting non-partitioned indexes to partitioned indexes
    ,@dataCompression               nvarchar(5)     = NULL                  --When specified the overrides the current index data compression
    ,@columnstoreDataCompression    nvarchar(50)    = NULL                  --When specified then overrides the current columnstore data compression type
', 0, 0) WITH NOWAIT;
        RAISERROR(N'', 0, 0) WITH NOWAIT;
        RAISERROR(N'Supported Index Types:
	1 = Clustered
	2 = Nonclustered
	3 = XML
	4 = Spatial
	5 = Clustered columnstore index - Applies to: SQL Server 2014 and above
	6 = Nonclustered columnstore index - Applies to: SQL Server 2012 and above
	7 = Nonclustered hash index - Applies to: SQL Server 2014 and above', 0, 0) WITH NOWAIT;
        
        RETURN
    END

	--Split @newTableName into Schema and Table
	SELECT
		@newTbName          = PARSENAME(@newTableName, 1)
		,@newTableSchema    = PARSENAME(@newTableName,2)

    SELECT
        @newTable = QUOTENAME(ISNULL(@newTableSchema, SCHEMA_NAME(t.schema_id))) + N'.' + QUOTENAME(ISNULL(@newTbName, t.name))
    FROM sys.tables t
    WHERE object_id = OBJECT_ID(@tableName)

    DECLARE @scripts TABLE (
        RowID       INT             NOT NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED,
        IndexScript nvarchar(max)
    );

    INSERT INTO @scripts(IndexScript)
    SELECT
        CASE	--Script CREATE INDES or APPROPRIATE ALTER TABLE for CONSTRAINTS
            WHEN i.is_primary_key = 1 THEN N'ALTER TABLE ' + @newTable + N' ADD CONSTRAINT ' + QUOTENAME(ISNULL(@newTbName + '_', '') + i.name) + N' PRIMARY KEY ' + CASE WHEN i.[type] = 1 THEN N'CLUSTERED' ELSE N'NONCLUSTERED' END
            WHEN i.is_unique_constraint = 1 THEN N'ALTER TABLE ' + @newTable + N' ADD CONSTRAINT ' + QUOTENAME(ISNULL(@newTbName + '_', '') + i.name) + N' UNIQUE ' + CASE WHEN i.[type] = 1 THEN N'CLUSTERED' ELSE N'NONCLUSTERED' END
            ELSE N'CREATE ' + CASE WHEN i.is_unique = 1 THEN N'UNIQUE ' ELSE N'' END 
                + CASE 
                    WHEN i.type = 1 THEN N'CLUSTERED' 
                    WHEN i.type = 5 THEN N'CLUSTERED COLUMNSTORE'
                    WHEN i.type = 6 THEN N'NONCLUSTERED COLUMNSTORE' 
                    WHEN i.type = 3 AND xi.xml_index_type = 0 THEN N'PRIMARY XML'
                    WHEN i.type = 3 THEN N'XML'
                    ELSE N'NONCLUSTERED' 
            END + ' INDEX ' + QUOTENAME(ISNULL(@newTbName + '_', '') + i.name) + N' ON ' + @newTable
        END + CASE WHEN i.type <> 5 THEN N' ('  + NCHAR(13) + NCHAR(10) ELSE N'' END
        +
        ISNULL(	--Script Key columns for INDEX or CONSTRAINT
            STUFF((
                    SELECT
                        (	
                            SELECT 
                                N'    ,' + QUOTENAME(c.name) + CASE WHEN ic.is_descending_key = 1 THEN N' DESC' ELSE '' END  + NCHAR(13)-- + NCHAR(10)
                            FROM sys.index_columns ic 
                            INNER JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
                            WHERE 
                                ic.object_id = i.object_id 
                                AND 
                                ic.index_id = i.index_id
                                AND
                                (ic.key_ordinal <> 0 OR i.type = 3) --iognore key_ordinal for XML indexes
                            ORDER BY ic.key_ordinal
                            FOR XML PATH(''), TYPE
                        ).value('.', 'nvarchar(max)'))
            , 1, 5, '     ')
            + N')'
            ,N''
        )
        + CASE
            WHEN i.type = 3AND xi.using_xml_index_id IS NOT NULL THEN
                 N' USING XML INDEX ' + QUOTENAME((SELECT pxi.name FROM sys.indexes pxi WHERE pxi.object_id = i.object_id AND pxi.index_id = xi.using_xml_index_id))
                 + N' FOR ' + CASE xi.secondary_type WHEN 'P' THEN N'PATH' WHEN 'V' THEN N'VALUE' WHEN 'R' THEN N'PROPERTY' END
            ELSE N''
          END
        + ISNULL(	--Script Included columns for INDEXES
            CASE WHEN i.type NOT IN (3, 5, 6) THEN N' INCLUDE (' + NCHAR(13) ELSE N'' END + 
            STUFF((
                SELECT
                    (
                        SELECT 
                            N'    ,' + c.name + NCHAR(13)
                        FROM sys.index_columns ic 
                        INNER JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
                        WHERE 
                            ic.object_id = i.object_id 
                            AND 
                            ic.index_id = i.index_id
                            AND
                            ((@partitionID > 0 AND ic.key_ordinal = 0) OR ic.is_included_column = 1)
                            AND
                            i.type <> 5
                        ORDER BY ic.is_included_column DESC, ic.partition_ordinal, ic.index_column_id
                        FOR XML PATH(''), TYPE
                    ).value(N'.', N'nvarchar(max)')
                )
                , 1, 5, '     ')
            + N')'
            ,N''
        ) + NCHAR(13) + NCHAR(10)
        + ISNULL(N'WHERE ' + i.filter_definition + NCHAR(13) + NCHAR(10), '')	--Script filter ondition for INDEX
        + N'WITH ('		--Script Options for INDEXES AND CONSTRAINTS
        + CASE 
            WHEN i.[type] IN (5, 6) THEN N'DROP_EXISTING = OFF'
            ELSE		
                N'PAD_INDEX = ' + CASE WHEN i.is_padded = 1 THEN N'ON' ELSE N'OFF' END
                + N', SORT_IN_TEMPDB = OFF' 
                + CASE WHEN i.is_primary_key = 1 OR i.is_unique_constraint = 1 THEN N'' ELSE CASE WHEN @scriptDropExisting = 1 THEN N', DROP_EXISTING = ON' ELSE  N', DROP_EXISTING = OFF' END END
                + N', ONLINE = OFF'
                + N', ALLOW_ROW_LOCKS = ' + CASE WHEN i.allow_row_locks = 1 THEN N'ON' ELSE N'OFF' END
                + N', ALLOW_PAGE_LOCKS = ' + CASE WHEN i.allow_page_locks = 1 THEN N'ON' ELSE N'OFF' END
                + CASE WHEN  i.type <> 3 THEN N', IGNORE_DUP_KEY = ' + CASE WHEN i.ignore_dup_key = 1 THEN N'ON' ELSE N'OFF' END ELSE N'' END
                + N', STATISTICS_NORECOMPUTE = ' + CASE WHEN s.no_recompute = 1 THEN N'ON' ELSE N'OFF' END
                + CASE WHEN i.fill_factor <> 0 THEN N'FILLFACTOR = ' + CONVERT(nvarchar(10), i.fill_factor) ELSE N'' END
                + ISNULL(
                    N', DATA_COMPRESSION = ' 
                    +   CASE 
                            WHEN i.[type] IN (1, 2) AND @dataCompression IS NOT NULL THEN @dataCompression
                            WHEN i.[type] IN (5,6) AND @columnstoreDataCompression IS NOT NULL THEN @columnstoreDataCompression
                            WHEN p.data_compression = 1 THEN N'ROW'
                            WHEN p.data_compression = 2 THEN N'PAGE'
                            WHEN p.data_compression = 3 THEN N'COLUMNSTORE'
                            WHEN p.data_compression = 4 THEN N'COLUMNSTORE_ARCHIVE '
                            ELSE NULL
                        END
                    ,N''
                    )
            END + N')'
        + CASE 
            WHEN i.type = 3 OR @partitionID <= -3 THEN N'' --Do not script ON [FileGroup] for XML INDEXES or if @partitionID <= -3
            ELSE
                ISNULL(
                    N' ON ' --Script destination FILEGROUP
                      +  CASE 
                            WHEN @onFileGroup IS NOT NULL THEN @onFileGroup
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
        + N';'
        + CASE
            WHEN i.is_disabled = 1 AND @scriptAlterIndexDisable = 1 
                THEN NCHAR(13) + NCHAR(10) + N'ALTER INDEX '  + QUOTENAME(ISNULL(@newTbName + '_', '') + i.name) + N' ON ' + @newTable + N' DISABLE'				
            ELSE N''
          END AS IndexScript
    FROM sys.indexes i
    INNER JOIN #indexNames ixn ON i.name = ixn.IndexName
    LEFT JOIN sys.xml_indexes xi ON xi.object_id = i.object_id and xi.index_id = i.index_id
    LEFT JOIN sys.stats s ON s.object_id = i.object_id AND s.stats_id = i.index_id	--Statistics to get the NO RECOMPUTE information
    INNER JOIN sys.data_spaces ds ON i.data_space_id = ds.data_space_id	AND ds.type <> 'FX'	--dsta_spaces to find out the FileGroup/partition scheme informaiton (exclude MEMORY OPTIMIZED data Spaces
    LEFT JOIN sys.partition_schemes ps ON i.data_space_id = ps.data_space_id		--details of partition scheme
    LEFT JOIN sys.destination_data_spaces dds ON dds.partition_scheme_id = i.data_space_id AND ds.[type] = N'PS' AND dds.destination_id = @partitionID --Partitions and destinations
    LEFT JOIN sys.filegroups dfg ON dfg.data_space_id = dds.data_space_id			--Destination file groups for partitioned index
    LEFT JOIN sys.partitions p ON p.object_id = i.object_id AND p.index_id = i.index_id AND (p.partition_number = @partitionID OR (ds.[type] = N'FG' AND p.partition_number = 1)) --To determine compression
    WHERE
        i.object_id = OBJECT_ID(@tableName)
        AND
        (i.is_disabled = 0 OR @scriptDisabledIndexes = 1)  --Script Disabled Indexes if Specified
        AND 
        i.is_hypothetical = 0
        AND 
        i.type IN (SELECT IndexType FROM @indexes) --Script only supported indexes
        AND
        (@scriptPrimaryKey = 1 OR i.is_primary_key = 0)	--Script Primary Key
        AND
        (@scriptUniqueConstraints = 1 OR i.is_unique_constraint = 0)	--Script Unique Constraints
        AND
        (@scriptIndexes = 1 OR i.is_primary_key = 1 OR i.is_unique_constraint = 1)	--Script Indexes

        SET @xml = (
            SELECT
                (
                    SELECT (
                        SELECT
                            IndexScript + NCHAR(13) + NCHAR(10) + NCHAR(13) + NCHAR(10)
                        FROM @scripts
                        ORDER BY RowID
                        FOR XML PATH(N''), TYPE
                    ) 
                ).value(N'.', N'nvarchar(max)') 'processing-instruction(index-script)'
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
EXECUTE sp_ms_marksystemobject 'dbo.sp_tblScriptIndexes'
GO
