IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('[dbo].[fn_TimeTable]') AND TYPE = 'IF')
    EXECUTE ('CREATE FUNCTION [dbo].[fn_TimeTable]() RETURNS TABLE AS RETURN(SELECT ''Container for fn_TimeTable() (C) Pavel Pawlowski'' AS DateTable)');
GO
/* ****************************************************
fn_TimeTable v 1.0 (C) 2015 - 2018 Pavel Pawlowski

Feedback: mailto:pavel.pawlowski@hotmail.cz

MIT License

Copyright (c) 2018 Pavel Pawlowski

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

Description:
    Generates a TimeTable for Kimball's based Time Dimensions. Works on SQL Server 2012 and above.

Parameters:
     @culture                           nvarchar(10)    = N'en-US'          -- Culture to be used for names generation
    ,@timeNameFormatString              nvarchar(30)    = N'T'              -- Format string for time name
    ,@timeName12FormatString            nvarchar(30)    = N'hh:mm:ss tt'    -- Format string for 12h time name
    ,@hourNameFormatString              nvarchar(30)    = N'H '             -- Format string for nour name
    ,@hour12NameFormatString            nvarchar(30)    = N'h tt'           -- Format string for 12h hour name
    ,@hourMinuteNameFormatString        nvarchar(30)    = N't'              -- Format string for hour minute name
    ,@minuteNameFormatString            nvarchar(30)    = N'MM'             -- Format string for minute name
    ,@minuteSecondNameFormatString      nvarchar(30)    = N'mm:ss'          -- Format string for minute second name
    ,@secondNameFormatString            nvarchar(30)    = N'ss'             -- Format string for second name
    ,@hourOfNameFormatString            nvarchar(30)    = N'# ##0\. h'      -- Format string for hour of ... name
    ,@minuteOfNameFormatString          nvarchar(30)    = N'# ##0\. min'    -- Format string for minute of ... name
    ,@secondOfNameFormatString          nvarchar(30)    = N'# ##0\. sec'    -- Format string for second of ... name
    ,@amPmIndicatorFormatString         nvarchar(30)    = N'tt'             -- Format string for AM/PM indicator

For details on Format Strings, review MSDN - FORMAT(Transact-SQL): https://msdn.microsoft.com/en-us/library/hh213505.aspx
For details on cultures see MDSDN - National Language Support (NLS) API Reference: https://msdn.microsoft.com/en-us/goglobal/bb896001.aspx
Usage:
    To provide multiple translations of the names, you can INNER JOIN two calls to the function

**************************************************** */
ALTER FUNCTION [dbo].[fn_TimeTable] (
     @culture                           nvarchar(10)    = N'en-US'          -- Culture to be used for names generation
    ,@timeNameFormatString              nvarchar(30)    = N'T'              -- Format string for time name
    ,@timeName12FormatString            nvarchar(30)    = N'hh:mm:ss tt'    -- Format string for 12h time name
    ,@hourNameFormatString              nvarchar(30)    = N'H '             -- Format string for nour name
    ,@hour12NameFormatString            nvarchar(30)    = N'h tt'           -- Format string for 12h hour name
    ,@hourMinuteNameFormatString        nvarchar(30)    = N't'              -- Format string for hour minute name
    ,@minuteNameFormatString            nvarchar(30)    = N'MM'             -- Format string for minute name
    ,@minuteSecondNameFormatString      nvarchar(30)    = N'mm:ss'          -- Format string for minute second name
    ,@secondNameFormatString            nvarchar(30)    = N'ss'             -- Format string for second name
    ,@hourOfNameFormatString            nvarchar(30)    = N'# ##0\. h'      -- Format string for hour of ... name
    ,@minuteOfNameFormatString          nvarchar(30)    = N'# ##0\. min'    -- Format string for minute of ... name
    ,@secondOfNameFormatString          nvarchar(30)    = N'# ##0\. sec'    -- Format string for second of ... name
    ,@amPmIndicatorFormatString         nvarchar(30)    = N'tt'             -- Format string for AM/PM indicator
)
RETURNS TABLE
AS
RETURN (
    WITH NumTable AS (  --Numbers Table
	    SELECT N FROM(VALUES (1), (1), (1), (1), (1), (1), (1), (1), (1), (1)) T(N)
    ),
    Times AS (  --Generate Times as time of 1900-01-01
	    SELECT TOP (86400)  --Take only TOP 86400 rows, which represents number of seconds in a day
		    CONVERT(datetime2(0), DATEADD(SECOND, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 1, 0)) AS [DateTime]
	    FROM 
		     NumTable N10
		    ,NumTable N100
		    ,NumTable N1000
		    ,NumTable N10000
		    ,NumTable N100000
    ),
    TimeTable AS ( --Generate a TimeTable
        SELECT
             T.[DateTime]                                                                                                   AS [DateTime]
            ,DATEPART(HOUR, T.[DateTime]) * 10000 + DATEPART(MINUTE, T.[DateTime]) * 100 + DATEPART(SECOND, T.[DateTime])   AS [TimeKey]
            ,CONVERT(time(0), T.[DateTime])                                                                                 AS [Time]
            ,CONVERT(tinyint, DATEPART(HOUR, T.[DateTime]))                                                                 AS [Hour]
            ,CONVERT(tinyint, FORMAT(T.[DateTime], N'hh', N'en-US'))                                                        AS [Hour12]
            ,CONVERT(tinyint, DATEPART(MINUTE, T.[DateTime]))                                                               AS [Minute]
            ,CONVERT(tinyint, DATEPART(SECOND, T.[DateTime]))                                                               AS [Second]
            ,CONVERT(tinyint, DATEPART(HOUR, T.[DateTime]) + 1)                                                             AS [HourOfDay]
            ,CONVERT(smallint, DATEPART(HOUR, T.[DateTime]) * 100 + DATEPART(MINUTE, T.[DateTime]))                         AS [HourMinute]
            ,CONVERT(smallint, DATEDIFF(MINUTE, 0, T.[DateTime]) + 1)                                                       AS [MinuteOfDay]
            ,CONVERT(tinyint, DATEPART(MINUTE, T.[DateTime]) + 1 )                                                          AS [MinuteOfHour]
            ,CONVERT(smallint, DATEPART(MINUTE, T.[DateTime]) * 100 + DATEPART(SECOND, T.[DateTime]))                       AS [MinuteSecond]
            ,CONVERT(int, DATEDIFF(SECOND, 0, T.[DateTime]) + 1)                                                            AS [SecondOfDay]
            ,CONVERT(smallint, DATEPART(MINUTE, T.[DateTime]) * 60 + DATEPART(SECOND, T.[DateTime]) + 1)                    AS [SecondOfHour]
            ,CONVERT(tinyint, DATEPART(SECOND, T.[DateTime]) + 1)                                                           AS [SecondOfMinute]
        FROM [Times] T
    )
    SELECT
         [TimeKey]                                                                                              AS [TimeKey]
        ,[Time]                                                                                                 AS [Time]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT(T.[DateTime], @timeNameFormatString, @culture))))             AS [TimeName]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT(T.[DateTime], @timeName12FormatString, @culture))))           AS [TimeName12]

        ,[Hour]                                                                                                 AS [Hour]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT(T.[DateTime], @hourNameFormatString, @culture))))             AS [HourName]
        ,[Hour12]                                                                                               AS [Hour12]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT(T.[DateTime], @hour12NameFormatString, @culture))))           AS [Hour12Name]
        ,[Minute]                                                                                               AS [Minute]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT(T.[DateTime], @minuteNameFormatString, @culture))))           AS [MinuteName]
        ,[Second]                                                                                               AS [Second]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT(T.[DateTime], @secondNameFormatString, @culture))))           AS [SecondName]

        ,[HourOfDay]                                                                                            AS [HourOfDay]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT([HourOfDay], @hourOfNameFormatString, @culture))))            AS [HourOfDayName]

        ,[HourMinute]                                                                                           AS [HourMinute]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT(T.[DateTime], @hourMinuteNameFormatString, @culture))))       AS [HourMinuteName]
        ,[MinuteOfDay]                                                                                          AS [MinuteOfDay]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT([MinuteOfDay], @minuteOfNameFormatString, @culture))))        AS [MinuteOfDayName]
        ,[MinuteOfHour]                                                                                         AS [MinuteOfHour]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT([MinuteOfHour], @minuteOfNameFormatString, @culture))))       AS [MinuteOfHourName]

        ,[MinuteSecond]                                                                                         AS [MinuteSecond]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT(T.[DateTime], @minuteSecondNameFormatString, @culture))))     AS [MinuteSecondName]
        ,[SecondOfDay]                                                                                          AS [SecondOfDay]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT([SecondOfDay], @secondOfNameFormatString, @culture))))        AS [SecondOfDayName]
        ,[SecondOfHour]                                                                                         AS [SecondOfHour]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT([SecondOfHour], @secondOfNameFormatString, @culture))))       AS [SecondOfHourName]
        ,[SecondOfMinute]                                                                                       AS [SecondOfMinute]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT([SecondOfMinute], @secondOfNameFormatString, @culture))))     AS [SecondOfMinuteName]

        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT(T.[DateTime], @amPmIndicatorFormatString, @culture))))        AS [AmPmName]
    FROM TimeTable T
)