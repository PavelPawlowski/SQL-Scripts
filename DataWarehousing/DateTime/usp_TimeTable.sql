IF NOT EXISTS (SELECT 1 FROM sys.all_objects WHERE object_id = OBJECT_ID('[dbo].[usp_TimeTable]') AND TYPE = 'P')
    EXECUTE ('CREATE PROCEDURE [dbo].[usp_TimeTable] AS BEGIN PRINT ''Container for usp_TimeTable (C) Pavel Pawlowski'' END');
GO
/* ****************************************************
usp_TimeTable v 1.0
(C) 2015 Pavel Pawlowski

Feedback: mailto:pavel.pawlowski@hotmail.cz

License: 
    usp_TimeTable is free to download and use for personal, educational, and internal 
    corporate purposes, provided that this header is preserved. Redistribution or sale 
    of usp_TimeTable, in whole or in part, is prohibited without the author's express 
    written consent.

Description:
    Generates a TimeTable for Kimball's based Time Dimensions. Works on SQL Server 2012 and above.
    Encapsulates call to fn_TimeTable.

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

**************************************************** */
ALTER PROCEDURE [dbo].[usp_TimeTable]
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
AS
BEGIN
    SELECT
         [TimeKey]
        ,[Time]
        ,[TimeName]
        ,[TimeName12]
        ,[Hour]
        ,[HourName]
        ,[Hour12]
        ,[Hour12Name]
        ,[Minute]
        ,[MinuteName]
        ,[Second]
        ,[SecondName]
        ,[HourOfDay]
        ,[HourOfDayName]
        ,[HourMinute]
        ,[HourMinuteName]
        ,[MinuteOfDay]
        ,[MinuteOfDayName]
        ,[MinuteOfHour]
        ,[MinuteOfHourName]
        ,[MinuteSecond]
        ,[MinuteSecondName]
        ,[SecondOfDay]
        ,[SecondOfDayName]
        ,[SecondOfHour]
        ,[SecondOfHourName]
        ,[SecondOfMinute]
        ,[SecondOfMinuteName]
        ,[AmPmName]        
    FROM dbo.fn_TimeTable(
         @culture
        ,@timeNameFormatString
        ,@timeName12FormatString
        ,@hourNameFormatString
        ,@hour12NameFormatString
        ,@hourMinuteNameFormatString
        ,@minuteNameFormatString
        ,@minuteSecondNameFormatString
        ,@secondNameFormatString
        ,@hourOfNameFormatString
        ,@minuteOfNameFormatString
        ,@secondOfNameFormatString
        ,@amPmIndicatorFormatString
    )
END