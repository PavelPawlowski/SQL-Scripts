/* *****************************************************************************************
                                      AZURE SQL DB Notice

   Comment-out the unsupported USE [master] when running in Azure SQL DB/Synapse Analytics
   or ignore error caused by unsupported USE statement
******************************************************************************************** */

USE [master]
GO
IF NOT EXISTS (SELECT 1 FROM sys.all_objects WHERE object_id = OBJECT_ID('[dbo].[sp_tblCheckAndCreatePartitions]') AND TYPE = 'P')
    EXECUTE ('CREATE PROCEDURE [dbo].[sp_tblCheckAndCreatePartitions] AS BEGIN PRINT ''Container procedure for sp_tblCheckAndCreatePartitions'' END')
GO
/* ****************************************************
sp_tblCheckAndCreatePartitions v 0.5 (2018-03-14)
(C) 2014 - 2018 Pavel Pawlowski

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

    written consent.

Description: 
    Checks Partition Scheme and Partition function whether it covers input @pValue. If not additional partitions are crated to cover the input date
    It ensures that only one partition scheme is mapped to one partition function.

Parameters:
     @pValue                sql_variant        = NULL      --value to check
    ,@psName                nvarchar(130)   = NULL      --Partition Scheme Name
    ,@tableName             nvarchar(261)   = NULL      --Table Name. It is possible to specify table name instead of Partition Scheme Name
    ,@incrementType         nvarchar(10)    = 'MONTH'   --Range Increment Type eg. YAER, MONTH, WEEK, DAY
    ,@increment             int             = 1         --Default increment size
    ,@destinationFileGroups nvarchar(max)   = NULL      --Comma Separated List of Destination File Groups. If NULL the last from the Partition Scheme will be used
    ,@printScriptOnly       bit             = 0         --Specifies whether the scritp should be printed instead of executed

* ***************************************************** */ 
ALTER PROCEDURE [dbo].[sp_tblCheckAndCreatePartitions]
     @pValue                sql_variant        = NULL      --value to check
    ,@psName                nvarchar(130)   = NULL      --Partition Scheme Name
    ,@tableName             nvarchar(261)   = NULL      --Table Name. It is possible to specify table name instead of Partition Scheme Name
    ,@incrementType         nvarchar(10)    = 'MONTH'   --Range Increment Type eg. YAER, MONTH, WEEK, DAY
    ,@increment             int             = 1         --Default increment size
    ,@destinationFileGroups nvarchar(max)   = NULL      --Comma Separated List of Destination File Groups. If NULL the last from the Partition Scheme will be used
    ,@printScriptOnly       bit             = 0         --Specifieswhether the scrip should be printed instead of executed
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
         @pfName                sysname             --Partition Funciton Name
        ,@dataType              sysname             --Data Type of the Partition Function
        ,@partValue             sql_variant         --Conveerted @pValue input parameter to a range based on the @incrementType
        ,@maxPartValue          sql_variant         --Range Value of the last partition
        ,@maxPartDate           datetime            --Range Value of the last partition converted to Date
        ,@maxPartID             int                 --maximum partition ID
        ,@boundaryValueOnRight  bit                 --stores information whether boundary value is on right
        ,@valuePartID           int                 --partition ID for the provided value
        ,@maxFG                 nvarchar(128)       --FileGeroup of the last Destination Data Space
        ,@integerFormatType     tinyint             --Integer Format Type used in the Partition Function 1 or 2 (1 = yyyymmdd; 2 = yyyyxx(x)
        ,@maxPartYear           date                --Year of the last partition in case of the @integerFormat = 2 yyyy
        ,@maxPartPart           int                 --part number of the last partition in thes fo the @integerFormat = 2 xx(x)
        ,@currentPartitionValue nvarchar(20)        --Value for the partition currently being created
        ,@currentFG             nvarchar(128)       --FileGroup to be used for the currently being created partition
        ,@currentFGID           int                 --ID of the current File Group taken from the @fileGroups table
        ,@tsql                  nvarchar(max)       --T-SQL Statement for the ALTER PARTITION FUNCTION or calling the $PARTITION function
        ,@params                nvarchar(max)       --parameters for the T-SQL Statement to run $PARTITION function
        ,@msg                   nvarchar(max)
        ,@msg1                  nvarchar(max)
        ,@printHelp             bit             = 0 --Specifies whether to print help
        ,@xml                   xml                                

    DECLARE @fileGroups TABLE (
        FGID int IDENTITY(1,1) PRIMARY KEY CLUSTERED,
        Name nvarchar(128)
    );

    RAISERROR(N'sp_tblCheckAndCreatePartitions v 0.5 (2018-03-14) (C) 2014 - 2018 Pavel Pawlowski', 0, 0) WITH NOWAIT;
    RAISERROR(N'=================================================================================', 0, 0) WITH NOWAIT;
    RAISERROR(N'Checks Partition Scheme and Partition function whether it covers input value. If not it creates attidional partitions to cover it', 0, 0) WITH NOWAIT;
    RAISERROR(N'', 0, 0) WITH NOWAIT;

    --Check if help should be printed
    IF @pValue IS NULL OR (@psName IS NULL AND @tableName IS NULL)
        SET @printHelp = 1;

    --Check if only one of the parameter is specified
    IF @psName IS NOT NULL AND @tableName IS NOT NULL
    BEGIN
        RAISERROR(N'Only @psName or @tableName can be specified', 15, 0);
        SET @printHelp = 1;
    END

    --If table name is provided, get the partition scheme name from the table's data spaces
    IF @tableName IS NOT NULL
    BEGIN
        SELECT
            @psName = ds.name
        FROM sys.tables t
        INNER JOIN sys.indexes i ON i.object_id = t.object_id AND i.index_id <= 1
        INNER JOIN sys.data_spaces ds on ds.data_space_id = i.data_space_id
        WHERE
            t.object_id = OBJECT_ID(@tableName)
            AND
            ds.type = N'PS';

        IF (@psName IS NULL)
        BEGIN
            RAISERROR ('Table "%s" does not exists in current context or is not partitioned table', 15, 1, @tableName);
            SET @printHelp = 1;
        END
    END    


    --Check if partition scheme exists
    IF NOT EXISTS(SELECT 1 FROM sys.partition_schemes WHERE name = @psName) AND @printHelp = 0
    BEGIN
        RAISERROR('Partition scheme "%s" does not exists in current context', 15, 2, @psName);
        SET @printHelp = 1;
    END


    --Check supported ranges
    IF @incrementType NOT IN (N'YEAR', N'MONTH', N'DAY', N'WEEK', N'ISO_WEEK', N'INT', N'BIGINT')
    BEGIN
        RAISERROR(N'@incrementType has to be one of following: YEAR, MONTH, DATE, WEEK, ISO_WEEK, INT, BIGINT', 15, 3);
        SET @printHelp = 1;
    END

    --Store new filegroups to be used to extend paritions if those are provided
    IF ISNULL(RTRIM(LTRIM(@destinationFileGroups)), N'') <> N''
    BEGIN
        SET @xml = CONVERT(xml, N'<fg>'+ REPLACE(@destinationFileGroups, N',', N'</fg><fg>') + N'</fg>')
        INSERT INTO @fileGroups(Name)
        SELECT
            n.value(N'.', N'nvarchar(128)') AS [Name]
        FROM @xml.nodes(N'fg') AS T(n);
    END


    --Get Partition Function Name, data type and range value of the last partition
    SELECT TOP (1)
         @pfName                = pf.name
        ,@dataType              = t.name    
        ,@maxPartValue          = prv.value
        ,@maxPartID             = prv.boundary_id + 1    --We have maximum boundary_id + 1 partitions
        ,@boundaryValueOnRight  = pf.boundary_value_on_right
    FROM sys.partition_schemes ps
    INNER JOIN sys.partition_functions pf ON ps.function_id = pf.function_id
    INNER JOIN sys.partition_parameters pp ON pf.function_id = pp.function_id AND pp.parameter_id = 1
    INNER JOIN sys.types t ON pp.user_type_id = t.user_type_id
    INNER JOIN sys.partition_range_values prv ON ps.function_id = prv.function_id
    WHERE 
        ps.name = @psName
    ORDER BY 
        prv.boundary_id DESC;

    --Check if input value data type match the data type of partition function
    IF @dataType <> SQL_VARIANT_PROPERTY(@pValue,'BaseType')
    BEGIN
        RAISERROR(N'@pValue data type does not match the partition function [%s] data type [%s]', 15, 4, @pfName, @dataType);
        SET @printHelp = 1;
    END

    --Get file group name of the last partition
    SELECT TOP (1) 
        @maxFG = fg.name
    FROM sys.partition_schemes ps
    INNER JOIN sys.destination_data_spaces dds ON ps.data_space_id = dds.partition_scheme_id
    INNER JOIN sys.filegroups fg on dds.data_space_id = fg.data_space_id
    WHERE 
        ps.name = @psName
    ORDER
        BY destination_id DESC


    IF @printHelp = 1
    BEGIN
        RAISERROR(N'Usage:', 0, 0);
        RAISERROR(N'[sp_tblCheckAndCreatePartitions] 
    @pValue = value_to_check', 0, 0);

        RAISERROR(N'', 0, 0);
        RAISERROR(N'Parameters:', 0, 0);
        RAISERROR(N'     @pValue                sql_variant        = NULL      --value to check
    ,@psName                nvarchar(130)   = NULL      --Partition Scheme Name
    ,@tableName             nvarchar(261)   = NULL      --Table Name. It is possible to specify table name instead of Partition Scheme Name
    ,@incrementType         nvarchar(10)    = ''MONTH''   --Range Increment Type eg. YAER, MONTH, WEEK, DAY
    ,@increment             int             = 1         --Default increment size
    ,@destinationFileGroups nvarchar(max)   = NULL      --Comma Separated List of Destination File Groups. If NULL the last from the Partition Scheme will be used
    ,@printScriptOnly       bit             = 0         --Specifieswhether the scrip should be printed instead of executed', 0, 0);

        RETURN
    END

    SET @msg = CONVERT(nvarchar(max), @pValue);
    RAISERROR(N'Checking value [%s] against partition scheme [%s]', 0, 0, @msg, @psName) WITH NOWAIT;
    RAISERROR(N'', 0, 0) WITH NOWAIT;


    --Get PartitionID for the provided value
    CREATE TABLE #valPartition(PartID int);
    SET @tsql = N'DECLARE @partVal ' + @dataType + N'; SET @partVal = CONVERT(' + @dataType + N', @val); INSERT INTO #valPartition(PartID) SELECT $PARTITION.' + QUOTENAME(@pfName) + N'(@partVal)';
    SET @params = N'@val sql_variant'
    EXECUTE sp_executesql @tsql, @params, @val = @pValue
    
    SELECT 
        @valuePartID = PartID 
    FROM #valPartition
    DROP TABLE #valPartition;

    --Value falls 
    IF (@valuePartID < @maxPartID)
    BEGIN
        RAISERROR(N'All partitions exists. Nothing to do.', 0, 0);
        RETURN;
    END

    --Value fallss to last partition. We have to create additional paritions
    IF @dataType = 'int'
        SET @integerFormatType = IIF( TRY_CONVERT(date, CONVERT(varchar(10), @maxPartValue), 112) IS NULL, 2, 1)

    --if partition function param no in int or bigint or @incrementType specified is not INT or BIGINT then convert the max partition value to appropriate date
    IF @datatype NOT IN (N'int', N'bigint') OR @incrementType NOT IN (N'INT', N'BIGINT')
    BEGIN
        IF @dataType NOT IN (N'int', N'bigint')
            SET @maxPartDate = CONVERT(datetime, @maxPartValue)
        ELSE IF @integerFormatType = 1
            SET @maxPartDate = CONVERT(datetime, convert(varchar(10), @maxPartValue), 112)
        ELSE
        BEGIN
            SET @maxPartYear = DATEADD(YEAR, CONVERT(int, LEFT(CONVERT(varchar(10), @maxPartValue), 4)) - 1900, 0)
            SET @maxPartPart = SUBSTRING(CONVERT(varchar(10), @maxPartValue), 5, 3)

            SET @maxPartDate =  CASE @incrementType
                                    WHEN N'YEAR'        THEN @maxPartYear
                                    WHEN N'MONTH'       THEN DATEADD(MONTH, @maxPartPart - 1, @maxPartYear)
                                    WHEN N'DAY'         THEN DATEADD(DAY, @maxPartPart - 1, @maxPartYear)
                                    WHEN N'WEEK'        THEN DATEADD(WEEK, @maxPartPart -1, DATEADD(WEEK, DATEDIFF(WEEK, 0, @maxPartYear), 0))
                                    WHEN N'ISO_WEEK'    THEN CASE
                                                                WHEN DATEPART(WEEK, DATEADD(WEEK, @maxPartPart -1 , DATEADD(WEEK, DATEDIFF(WEEK, 0, @maxPartYear), 0))) 
                                                                        < DATEPART(ISO_WEEK, DATEADD(WEEK, @maxPartPart -1 , DATEADD(WEEK, DATEDIFF(WEEK, 0, @maxPartYear), 0)))
                                                                    THEN DATEADD(WEEK, @maxPartPart, DATEADD(WEEK, DATEDIFF(WEEK, 0, @maxPartYear), 0))
                                                                ELSE
                                                                    DATEADD(WEEK, @maxPartPart -1, DATEADD(WEEK, DATEDIFF(WEEK, 0, @maxPartYear), 0))                                                            
                                                                END
                                END
        END
    END

    SET @currentFG = @maxFG --Set @currentFG to @maxFG in case there are no @fileGroups specified

    --create missing partitions
    WHILE (@maxPartValue < @pValue)  OR (@maxPartValue = @pValue AND @boundaryValueOnRight = 1)
    BEGIN
        --if partition function param no in int or bigint or @incrementType specified is not INT or BIGINT then process the value as date
        IF @datatype NOT IN (N'int', N'bigint') OR @incrementType NOT IN (N'INT', N'BIGINT')
        BEGIN            
            SET @maxPartDate = 
                CASE @incrementType
                    WHEN N'YEAR'        THEN DATEADD(YEAR, @increment , @maxPartDate)
                    WHEN N'MONTH'       THEN DATEADD(MONTH, @increment , @maxPartDate)
                    WHEN N'DAY'         THEN DATEADD(DAY, @increment , @maxPartDate)
                    WHEN N'WEEK'        THEN DATEADD(WEEK, @increment , @maxPartDate)
                    WHEN N'ISO_WEEK'    THEN DATEADD(WEEK, @increment , @maxPartDate)
                END

            IF @integerFormatType = 1 OR @dataType NOT IN (N'int', N'bigint')
                SET @currentPartitionValue = CONVERT(nvarchar(8), @maxPartDate, 112)
            ELSE
                SET @currentPartitionValue = 
                    CASE @incrementType
                        WHEN N'YEAR'    THEN YEAR(@maxPartDate)
                        WHEN N'MONTH'   THEN CONVERT(nvarchar(6), @maxPartDate, 112)
                        WHEN N'DAY'     THEN CONVERT(nvarchar(8), YEAR(@maxPartDate) * 1000 + DATEPART(DAYOFYEAR, @maxPartDate))
                        WHEN N'WEEK'    THEN 
                            CONVERT(nvarchar(8), YEAR(@maxPartDate) * 100 + 
                            CASE 
                                WHEN DATEPART(WEEK, @maxPartDate) > 50 AND MONTH(@maxPartDate) = 1 THEN 1
                                ELSE DATEPART(WEEK, @maxPartDate)
                            END)
                        WHEN N'ISO_WEEK' THEN 
                            CONVERT(nvarchar(8), (YEAR(@maxPartDate) + 
                                CASE 
                                    WHEN MONTH(@maxPartDate) = 12 AND DATEPART(ISO_WEEK, @maxPartDate) = 1 THEN 1
                                    WHEN MONTH(@maxPartDate) = 1 AND DATEPART(ISO_WEEK, @maxPartDate) > 50 THEN -1
                                    ELSE 0
                                END   
                                ) * 100 
                                + DATEPART(ISO_WEEK, @maxPartDate))
                    END
        END --IF @incrementType NOT IN (N'INT', N'BIGINT')
        ELSE
        BEGIN
            SET @currentPartitionValue = CONVERT(nvarchar(20), CONVERT(bigint, @maxPartValue) + @increment);
        END

        SET @tsql = N'SET @partVal = CONVERT(' + @dataType + N', @val)';
        SET @params = N'@partVal sql_variant OUT, @val ' + @dataType;

        EXEC sp_executesql @tsql, @params, @partVal=@maxPartValue OUT, @val=@currentPartitionValue;


        IF @dataType NOT IN (N'int', N'bigint')
            SET @currentPartitionValue = QUOTENAME(@currentPartitionValue, '''')

        --Set filegroup ro the new partition being created (if filegroups were provided user first available
        IF EXISTS(SELECT 1 FROM @fileGroups)
        BEGIN
            SELECT TOP (1)
                @currentFGID = FGID
                ,@currentFG = Name
            FROM @fileGroups
            ORDER BY 
                FGID ASC;

            DELETE FROM @fileGroups WHERE FGID = @currentFGID
        END

        --Set the T-SQL to alter the partition scheme next userd filegroup and ALTER PARTITION FUNCTION SPLIT
        SET @tsql = N'ALTER PARTITION SCHEME ' + QUOTENAME(@psName) + N' NEXT USED ' + QUOTENAME(@currentFG) + 
                    N'; ALTER PARTITION FUNCTION ' + QUOTENAME(@pfName) + N'() SPLIT RANGE (' + @currentPartitionValue + N')'

        IF @printScriptOnly = 1
            RAISERROR(@tsql, 0, 0)
        ELSE
        BEGIN
            SET @msg = N'Setting next used file group for ' + QUOTENAME(@psName) + N' to ' + QUOTENAME(@currentFG) + N' and splitting partition function ' + QUOTENAME(@pfName) + N' on boundary value ' + @currentPartitionValue
            RAISERROR(@msg, 0, 0)

            EXEC (@tsql)
        END 
    END --WHILE @maxPartDate < @partValue
END
GO

--Mark Stored Procedure as system object, so it executes in the context of current database.
IF SERVERPROPERTY('EngineEdition') IN (1, 2, 3, 4, 8)
    EXEC(N'EXECUTE sp_ms_marksystemobject ''dbo.sp_tblCheckAndCreatePartitions''');
GO
