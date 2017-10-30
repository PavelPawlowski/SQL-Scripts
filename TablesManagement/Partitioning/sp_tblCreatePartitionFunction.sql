USE [master]
GO
IF NOT EXISTS(SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('[dbo].[sp_tblCreatePartitionFunction]') AND type = 'P')
	EXEC (N'CREATE PROCEDURE [dbo].[sp_tblCreatePartitionFunction] AS PRINT ''Container''')
GO
/* ****************************************************
sp_tblCreatePartitionFunction v 0.32 (2016-10-30)
(C) 2014 - 2016 Pavel Pawlowski

Feedback: mailto:pavel.pawlowski@hotmail.cz

License: 
	sp_tblCreatePartitionFunction is free to download and use for personal, educational, and internal 
	corporate purposes, provided that this header is preserved. Redistribution or sale 
	of sp_tblCreatePartitionFunction, in whole or in part, is prohibited without the author's express 
	written consent.

Description: Generates Partition function for specified range of dates in specified format

Usage:
    sp_tblCreatePartitionFunction [parameters]

Parameters:
     @pfName            nvarchar(128)   = NULL      --Partition function name
    ,@rangeStart        sql_variant     = NULL      --Start of the Range. you should pass proper data type or string in proper format
    ,@rangeEnd          sql_variant     = NULL      --End of the Range. You should pass proper data type or string in proper format
    ,@boundaryType      nvarchar(5)     = ''RIGHT''   --Range Boundary Type (RIGHT or LEFT)
    ,@incrementValue    int             = 1         --Specifies how many increment units should be incremented in each step
    ,@incrementUnit     nvarchar(10)    = ''MONTH''   --Range Increment Type eg. YEAR, MONTH, WEEK, ISO_WEEK, DAY. 
                                                    --Used only for date ranges
    ,@useIntegerDates   bit             = 1         --Specifies whether dates should be interpreted as integers or as original range date data type in case of Dates
    ,@integerFormatType tinyint         = 2         --Specifies how the int data type is being formatted. 1 or 2. 
                                                    --1 = format is yyyymmdd and 
                                                    --2 = format using yyyxx(x) where xx(x) represents month, week or day
    ,@printScriptOnly   bit             = 1         --Specifies whether script should be printed or the function should be automatically created. 
                                                    --Default is print script
Range parameters specification:
@rangeStart and @rangeEnd can be passed also as strings to avoid declaration fo explicit variables for date parameters or for easy specification of integer data types

If string value passed as @rageStart or @Range end is convertible into a datetime data type, the datetime data type will be used for the partition function.

In addition a Format specifier can be used as first character of the string:
(D = date, T = datetime, B = bigint, I = int, S = smallint)

''2016-01-01''      - converted to:     datetime    2016-01-01
''20160101''        - converted to:     datetime    2016-01-01
''D2016-01-01''     - converted to:     date        2016-01-01
''T2016-01-01''     - converted to:     datetime    2016-01-01
''B100''            - converted to:     bigint      100
''I100''            - converted to:     int         100
''S100''            - converted to:     smallint    100

Modifications: 
* ***************************************************** */ 
ALTER PROCEDURE [dbo].[sp_tblCreatePartitionFunction]
     @pfName            nvarchar(128)   = NULL      --Partition function name
    ,@rangeStart        sql_variant     = NULL      --Start of the Range. you should pass proper data type or string in proper formant
    ,@rangeEnd          sql_variant     = NULL      --End of the Range. You should pass proper data type or string in proper format
    ,@boundaryType      nvarchar(5)     = 'RIGHT'   --Range Boundary Type (RIGHT or LEFT)
    ,@incrementValue    int             = 1         --Specifies how many increment units should be incremented
    ,@incrementUnit     nvarchar(10)    = 'MONTH'   --Range Increment Type eg. YEAR, MONTH, WEEK, ISO_WEEK, DAY. Used only for date ranges
    ,@useIntegerDates   bit             = 1         --Specifies whether dates should be interpreted as integers or as original range date data type
    ,@integerFormatType tinyint         = 2         --Specifies how the int data type is being formatted. 1 or 2. 1 = format is yyyymmdd and 2 = format using yyyxx(x) where xx(x) represents month, week or day
    ,@printScriptOnly   bit             = 1         --Specifies whether script should be printed or the function should be automatically created. Default is print script
AS
BEGIN
	DECLARE
		@tsql                   nvarchar(max) = N'CREATE PARTITION FUNCTION '
        ,@currentDate           datetime        = '19000101'                    --current date range value
        ,@maxDate               datetime        = '99991231'                    --max date range value
        ,@currentValue          bigint          = 0                             --current numeric range value
        ,@maxValue              bigint          = 1                             --max value for numeric range
		,@currentPartitionValue nvarchar(24)                                    --variable for storing current partition value for script building purposes
		,@dataType              nvarchar(15)    
		,@loopNumber            int             = 0
		,@caption               nvarchar(max)                                   --Procedure caption
		,@msg                   nvarchar(max)                                   --message
		,@printHelp             bit             = 0		                        --Specifies whether to print help
        ,@isDateRange           bit             = 0                             --indicates whether we are operating with date ranges
        ,@rangeBaseType         nvarchar(10)                                    --stores the data type fo the input @rangeStart
        ,@typeConvert           char(1)                                         --Type of conversion in input Range in case string is passed
        ,@strRangeStart         nvarchar(50)
        ,@strRangeEnd           nvarchar(50)

	SET @caption = N'--sp_tblCreatePartitionFunction v 0.3 (2016-10-15) (C) 2014 - 2016 Pavel Pawlowski' + NCHAR(13) + NCHAR(10) + 
				   N'--================================================================================' + NCHAR(13) + NCHAR(10);
	RAISERROR(@caption, 0, 0) WITH NOWAIT;


	IF ISNULL(@pfName, '') = '' OR @rangeStart IS NULL OR @rangeEnd IS NULL
	BEGIN
		SET @printHelp = 1;
	END

    --get the @rangeStart data type
    SET @rangeBaseType = CONVERT(nvarchar(10), SQL_VARIANT_PROPERTY(@rangeStart, 'BaseType'));

    --Convert the ranges in case conversion characters are found in input string
    IF @rangeBaseType IN (N'char', N'varchar', N'nchar', N'nvarchar')
    BEGIN
        SET @typeConvert = LEFT(CONVERT(varchar(50), @rangeStart), 1)
        SET @strRangeStart = CONVERT(nvarchar(50), @rangeStart)
        SET @strRangeEnd = CONVERT(nvarchar(50), @rangeEnd)

        IF @typeConvert IN ('D', 'T', 'I', 'B', 'S') OR (ISDATE( @strRangeStart) = 1 AND ISDATE(@strRangeEnd) = 1)
        BEGIN
            IF @typeConvert IN ('D', 'T', 'I', 'B', 'S')
            BEGIN
                SET @strRangeStart = SUBSTRING(CONVERT(nvarchar(50), @rangeStart), 2, 49)
                SET @strRangeEnd = SUBSTRING(CONVERT(nvarchar(50), @rangeEnd), 2, 49)
            END
            ELSE
                SET @typeConvert = 'T'
                             
            --if dates or numbers are passed, try handle conversion
            IF (ISDATE(@strRangeStart) = 1 AND ISDATE(@strRangeEnd) = 1) OR (ISNUMERIC(CONVERT(nvarchar(50), @strRangeStart)) = 1 AND ISNUMERIC(@strRangeEnd) = 1)
            BEGIN
                BEGIN TRY
                    IF @typeConvert = 'D'
                    BEGIN
                        SET @rangeStart = CONVERT(date, @strRangeStart);                    
                        SET @rangeEnd = CONVERT(date, @strRangeEnd);
                    END                    
                    ELSE IF @typeConvert = 'T'
                    BEGIN
                        SET @rangeStart = CONVERT(datetime, @strRangeStart);                    
                        SET @rangeEnd = CONVERT(datetime, @strRangeEnd);
                    END                    
                    ELSE IF @typeConvert = 'B'
                    BEGIN
                        SET @rangeStart = CONVERT(bigint, @strRangeStart);                    
                        SET @rangeEnd = CONVERT(bigint, @strRangeEnd);
                    END                    
                    ELSE IF @typeConvert = 'I'
                    BEGIN
                        SET @rangeStart = CONVERT(int, @strRangeStart);                    
                        SET @rangeEnd = CONVERT(int, @strRangeEnd);
                    END                    
                    ELSE IF @typeConvert = 'S'
                    BEGIN
                        SET @rangeStart = CONVERT(smallint, @strRangeStart);                    
                        SET @rangeEnd = CONVERT(smallint, @strRangeEnd);
                    END                    

                    --update the range base type
                    SET @rangeBaseType = CONVERT(nvarchar(10), SQL_VARIANT_PROPERTY(@rangeStart, 'BaseType'));
                END TRY
                BEGIN CATCH
                END CATCH        
            END
        END
    END


    IF (
        @rangeBaseType NOT IN (N'smallint', N'int', N'bigint', N'date', N'datetime', N'datetime2')
        OR
        @rangeBaseType NOT IN (N'smallint', N'int', N'bigint', N'date', N'datetime', N'datetime2')
    )
    BEGIN
		RAISERROR(N'@rangeStart and rangeEnd has to be one of following data types: smallint, int, bigint, date, datetime, datetime2(x)', 16, 1);
		SET @printHelp = 1;
    END

    IF SQL_VARIANT_PROPERTY(@rangeStart, 'BaseType') <> SQL_VARIANT_PROPERTY(@rangeEnd, 'BaseType')
    BEGIN
		RAISERROR(N'@rangeStart and rangeStart has to be of the same data type', 16, 2);
		SET @printHelp = 1;
    END

	IF @boundaryType NOT IN (N'RIGHT', N'LEFT')
	BEGIN
		RAISERROR(N'@boundaryType has to be RIGHT or LEFT only', 16,3);
		SET @printHelp = 1;
	END

	IF @incrementUnit NOT IN (N'YEAR', N'MONTH', N'DAY', N'WEEK', N'ISO_WEEK')
	BEGIN
		RAISERROR(N'@incrementUnit has to be one of following: YEAR, MONTH, DATE, WEEK, ISO_WEEK', 16, 5);
		SET @printHelp = 1;
	END
	IF @integerFormatType NOT IN (1,2)
	BEGIN
		RAISERROR(N'@integerFormatType has to be either 1 or 2 where 1 = (yyyyxx(x)) where xx(x) represents month, week or day) and 2 = date format in yyyymmdd', 16, 6);
		SET @printHelp = 1;
	END


    IF @printHelp = 1
    BEGIN
	    RAISERROR(N'Generates Partition function for specified range of dates in specified format', 0, 0) WITH NOWAIT;
        RAISERROR(N'
Usage:
    sp_tblCreatePartitionFunction [parameters]

Parameters:
     @pfName            nvarchar(128)   = NULL      --Partition function name
    ,@rangeStart        sql_variant     = NULL      --Start of the Range. you should pass proper data type or string in proper formant
    ,@rangeEnd          sql_variant     = NULL      --End of the Range. You should pass proper data type or string in proper format
    ,@boundaryType      nvarchar(5)     = ''RIGHT''   --Range Boundary Type (RIGHT or LEFT)
    ,@incrementValue    int             = 1         --Specifies how many increment units should be incremented in each step
    ,@incrementUnit     nvarchar(10)    = ''MONTH''   --Range Increment Type eg. YEAR, MONTH, WEEK, ISO_WEEK, DAY. 
                                                    --Used only for date ranges
    ,@useIntegerDates   bit             = 1         --Specifies whether dates should be interpreted as integers or as original range date data type in case of Dates
    ,@integerFormatType tinyint         = 2         --Specifies how the int data type is being formatted. 1 or 2. 
                                                    --1 = format is yyyymmdd and 
                                                    --2 = format using yyyxx(x) where xx(x) represents month, week or day
    ,@printScriptOnly   bit             = 1         --Specifies whether script should be printed or the function should be automatically created. 
                                                    --Default is print script
', 0, 0) WITH NOWAIT;

RAISERROR(N'
Range parameters specification:
@rangeStart and @rangeEnd can be passed also as strings to avoid declaration fo explicit variables for date parameters or for easy specification of integer data types

If string value passed as @rageStart or @Range end is convertible into a datetime data type, the datetime data type will be used for the partition function.

In addition a Format specifier can be used as first character of the string:
(D = date, T = datetime, B = bigint, I = int, S = smallint)

''2016-01-01''      - converted to:     datetime    2016-01-01
''20160101''        - converted to:     datetime    2016-01-01
''D2016-01-01''     - converted to:     date        2016-01-01
''T2016-01-01''     - converted to:     datetime    2016-01-01
''B100''            - converted to:     bigint      100
''I100''            - converted to:     int         100
''S100''            - converted to:     smallint    100
', 0, 0) WITH NOWAIT;

        RETURN;
    END

    --Detect if we are working with date ranges (or numeric)
    IF LEFT(@rangeBaseType, 4) = 'date'
    BEGIN
        SET @isDateRange    =   1
        SET @currentDate    =   CASE @incrementUnit                                 
									WHEN 'YEAR' THEN DATEADD(YEAR, DATEDIFF(YEAR, 0, CONVERT(datetime, @rangeStart)), 0)
									WHEN N'MONTH' THEN DATEADD(MONTH, DATEDIFF(MONTH, 0, CONVERT(datetime, @rangeStart)), 0)
									WHEN N'DAY' THEN DATEADD(DAY, DATEDIFF(DAY, 0, CONVERT(datetime, @rangeStart)), 0)
									WHEN N'WEEK' THEN DATEADD(WEEK, DATEDIFF(WEEK, 0, CONVERT(datetime, @rangeStart)), 0)
									WHEN N'ISO_WEEK' THEN DATEADD(WEEK, DATEDIFF(WEEK, 0, CONVERT(datetime, @rangeStart)), 0)
							    END;
        SET @maxDate        = CONVERT(datetime, @rangeEnd);
    END
    ELSE
    BEGIN
        SET @isDateRange    =   0
        SET @currentValue   =   CONVERT(bigint, @rangeStart);
        SET @maxValue       =   CONVERT(bigint, @rangeEnd);
    END

    --Get the data type to be used for the partition function
	SET @dataType = CASE 
                        WHEN @isDateRange = 1 AND @useIntegerDates = 1 THEN 'int'
                        WHEN @rangeBaseType = 'datetime2' THEN 'datetime2(' + CONVERT(nvarchar(10), SQL_VARIANT_PROPERTY(@rangeStart, 'Scale')) + N')'
                        ELSE @rangeBaseType
                    END;

	SET @tsql += QUOTENAME(@pfName) + N'(' + @dataType + N') AS RANGE ' + @boundaryType + N' FOR VALUES (';

	IF @printScriptOnly = 1
    BEGIN
    	RAISERROR(N'', 0, 0) WITH NOWAIT;
		RAISERROR(@tsql, 0, 0) WITH NOWAIT;
    END

	SET @tsql += NCHAR(13) + NCHAR(10);

	WHILE (@isDateRange = 1 AND @currentDate <= @maxDate) OR (@isDateRange = 0 AND @currentValue <= @maxValue)
	BEGIN
		IF @isDateRange = 0  --If we are operating on numeric ranges do not use any special formatting
            SET @currentPartitionValue = CONVERT(nvarchar(20), @currentValue)
        ELSE IF @useIntegerDates = 0 OR @integerFormatType = 1 --If using date as ranges, script the dates in the 112 format = yyymmdd
			SET @currentPartitionValue = CONVERT(nvarchar(8), @currentDate, 112);
		ELSE    --In case of integer dates format
        BEGIN
			SET @currentPartitionValue = CASE @incrementUnit
											WHEN N'YEAR' THEN CONVERT(nvarchar(20), YEAR(@currentDate))
											WHEN N'MONTH' THEN CONVERT(nvarchar(20), @currentDate, 112)
											WHEN N'DAY' THEN CONVERT(nvarchar(20), YEAR(@currentDate) * 1000 + DATEPART(DAYOFYEAR, @currentDate))
											WHEN N'WEEK' THEN CONVERT(nvarchar(20), YEAR(@currentDate) * 100 + DATEPART(WEEK, @currentDate))
											WHEN N'ISO_WEEK' THEN CONVERT(nvarchar(20), (YEAR(@currentDate) + 
																							CASE 
																								WHEN MONTH(@currentDate) = 12 AND DATEPART(ISO_WEEK, @currentDate) = 1 THEN 1
																								WHEN MONTH(@currentDate) = 1 AND DATEPART(ISO_WEEK, @currentDate) > 50 THEN -1
																								ELSE 0
																							END   
																						) * 100 

											+ DATEPART(ISO_WEEK, @currentDate))
										END;
        END
	
		IF @isDateRange = 1 AND @useIntegerDates = 0
			SET @currentPartitionValue = QUOTENAME(@currentPartitionValue, N'''');

		if @loopNumber > 0 
			SET @currentPartitionValue = '   ,' + @currentPartitionValue;
		ELSE 
			SET @currentPartitionValue = '    ' + @currentPartitionValue;


		SET @tsql += @currentPartitionValue + NCHAR(13) + NCHAR(10);

		IF @printScriptOnly = 1
			PRINT @currentPartitionvalue;

        IF @isDateRange = 1
        BEGIN
		    SET @currentDate =  CASE @incrementUnit
									WHEN N'YEAR' THEN DATEADD(YEAR, @incrementValue, CONVERT(datetime, @currentDate))
									WHEN N'MONTH' THEN DATEADD(MONTH, @incrementValue, CONVERT(datetime, @currentDate))
									WHEN N'DAY' THEN DATEADD(DAY, @incrementValue, CONVERT(datetime, @currentDate))
									WHEN N'WEEK' THEN DATEADD(WEEK, @incrementValue, CONVERT(datetime, @currentDate))
									WHEN N'ISO_WEEK' THEN DATEADD(WEEK, @incrementValue, CONVERT(datetime, @currentDate))
								END;
        END
        ELSE
        BEGIN
            SET @currentValue = @currentValue + @incrementValue;
        END
		SET @loopNumber += 1;
	END

	SET @tsql += N')'


	IF @printScriptOnly = 1
		RAISERROR(N')', 0, 0)
	ELSE
		EXECUTE (@tsql);
END
GO

EXECUTE sp_ms_marksystemobject 'dbo.sp_tblCreatePartitionFunction';
GO
