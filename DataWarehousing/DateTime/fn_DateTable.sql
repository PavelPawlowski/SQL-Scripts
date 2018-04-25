IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('[dbo].[fn_DateTable]') AND TYPE = 'IF')
    EXECUTE ('CREATE FUNCTION [dbo].[fn_DateTable]() RETURNS TABLE AS RETURN(SELECT ''Container for fn_DateTable() (C) Pavel Pawlowski'' AS DateTable)');
GO
/* ****************************************************
fn_DateTable v 1.0 (C) 2018 Pavel Pawlowski

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
    Generates a DateTable for Kimball's based Date Dimensions. Works on SQL Server 2012 and above.

Parameters:
     @startDate                                 date                                    -- Start date of the sequence to Generate
	,@endDate                                   date                                    -- End date of the sequence to Generate

    ,@culture                                   nvarchar(10)    = N'en-US'              -- Culture to be used for names generation

    ,@dateNameFormatString                      nvarchar(30)    = N'd'                  -- Format String for date name generation
    
    ,@yearNameFormatString                      varchar(30)     = N'yyyy'               -- Format String for the Year 
    ,@fiscalYearNameFormatString                varchar(30)     = N'\F\Y yyyy'          -- Format String for the Year 


    ,@monthNameFormatString                     nvarchar(30)    = N'Y'                  -- Format string for month name generation
    ,@monthOfYearNameFormatString               nvarchar(30)    = N'MMMM'               -- Format string for month of year name generation
    ,@monthDayNameFormatString                  nvarchar(30)    = N'M'                  -- Format string for month day name

    ,@weekNamePrefixFormatString                nvarchar(30)    = N''                   -- Format string for week prefix. Used to place Year as prefix to the week name
    ,@weekNameFormatString                      nvarchar(30)    = N'\W#'                -- Format string for week name
    ,@weekNameSuffixFormatString                nvarchar(30)    = N' yyyy'              -- Format string for week suffix. Used to place Year as suffix to the week name

    ,@quarterNamePrefixFormatString             nvarchar(30)    = N''                   -- Format string for quarter prefix. Used to place Year as prefix to the quartername
    ,@quarterNameFormatString                   nvarchar(30)    = N'\Q#'                -- Format string for quarter name
    ,@quarterNameSuffixFormatString             nvarchar(30)    = N' yyyy'              -- Format string for quarter suffix. Used to place Year as suffix to the quarter name

    ,@semesterNamePrefixFormatString            nvarchar(30)    = N''                   -- Format string for semester prefix. Used to place Year as prefix to the semester name
    ,@semesterNameFormatString                  nvarchar(30)    = N'\S#'                -- Format string for semester name
    ,@semesterNameSuffixFormatString            nvarchar(30)    = N' yyyy'              -- Format string for semester suffix. Used to place Year as suffix to the semester name

    ,@trimesterNamePrefixFormatString           nvarchar(30)    = N''                   -- Format string for trimester prefix. Used to place Year as prefix to the trimester name
    ,@trimesterNameFormatString                 nvarchar(30)    = N'\T#'                -- Format string for trimester name
    ,@trimesterNameSuffixFormatString           nvarchar(30)    = N' yyyy'              -- Format string for trimester suffix. Used to place Year as suffix to the trimester name

    ,@fiscalWeekNamePrefixFormatString          nvarchar(30)    = N''                   -- Format string for week prefix. Used to place Year as prefix to the week name
    ,@fiscalWeekNameFormatString                nvarchar(30)    = N'\F\W#'              -- Format string for week name
    ,@fiscalWeekNameSuffixFormatString          nvarchar(30)    = N' yyyy'              -- Format string for week suffix. Used to place Year as suffix to the week name

    ,@fiscalMonthNamePrefixFormatString         nvarchar(30)    = N''                   -- Format string for quarter prefix. Used to place Year as prefix to the quartername
    ,@fiscalMonthNameFormatString               nvarchar(30)    = N'\F\M#'              -- Format string for quarter name
    ,@fiscalMonthNameSuffixFormatString         nvarchar(30)    = N' yyyy'              -- Format string for quarter suffix. Used to place Year as suffix to the quarter name

    ,@fiscalQuarterNamePrefixFormatString       nvarchar(30)    = N''                   -- Format string for quarter prefix. Used to place Year as prefix to the quartername
    ,@fiscalQuarterNameFormatString             nvarchar(30)    = N'\F\Q#'              -- Format string for quarter name
    ,@fiscalQuarterNameSuffixFormatString       nvarchar(30)    = N' yyyy'              -- Format string for quarter suffix. Used to place Year as suffix to the quarter name

    ,@fiscalSemesterNamePrefixFormatString      nvarchar(30)    = N''                   -- Format string for semester prefix. Used to place Year as prefix to the semester name
    ,@fiscalSemesterNameFormatString            nvarchar(30)    = N'\F\S#'              -- Format string for semester name
    ,@fiscalSemesterNameSuffixFormatString      nvarchar(30)    = N' yyyy'              -- Format string for semester suffix. Used to place Year as suffix to the semester name

    ,@dayOfWeeknameFormatSring                  nvarchar(30)    = N'dddd'               -- Format string for the Day of Week name

    ,@firstDayOfWeek                            tinyint         = 1                     -- First Day Of Week. 1 = Monday - 7 = Sunday
    ,@FiscalQuarterWeekType                     smallint        = 445                   -- Type of Fiscal Quarter Week Types. Supported 445, 454, 544 (Specifies how the 13 weeks quarters are distributed among weeks)
    ,@lastDayOfFiscalYear                       tinyint         = 7                     -- Last Day of Fiscal Year. 1 = Monday - 7 = Sunday
    ,@lastDayOfFiscalYearType                   tinyint         = 1                     -- Specifies how the last day of fiscal yer is determined. 1 = Last @lastDayOfFiscalYear in the fiscal year end month. 2 = @lastDayOfFiscalYear closes to the fiscal year end month
    ,@fiscalYearStartMonth                      tinyint         = 9                     -- Specifies the Month at which the Fiscal year Starts

    ,@workingDays                               char(7)         = '1111100'             -- "Bitmask of working days where left most is Monday and RightMost is Sunday: MTWTFSS. Working Days are considered Week Days, Non Working days are considered Weekend
    ,@holidays                                  varchar(max)    = ''                    -- Comma Separated list of holidays. Holidays can be specified in the MMdd or yyyyMMdd.
    ,@workingDayTypeName                        nvarchar(30)    = 'Working day'         -- Name for the working days
    ,@nonWorkingDayTypeName                     nvarchar(30)    = 'Non-working day'     -- Name for the non-working days
    ,@holidayDayTypeName                        nvarchar(30)    = 'Holiday'             -- Name for the Holiday day type

For details on Format Strings, review MSDN - FORMAT(Transact-SQL): https://msdn.microsoft.com/en-us/library/hh213505.aspx
For details on cultures see MDSDN - National Language Support (NLS) API Reference: https://msdn.microsoft.com/en-us/goglobal/bb896001.aspx

Usage:
    To provide multiple translations of the names, you can INNER JOIN twoc alls with different culture as in example below.

SELECT
     EN.DateKey
    ,EN.[Date]
    ,EN.[DateName]
    ,EN.[MonthName] AS [MonthName_EN]   --Month Name in English
    ,CN.[MonthName] AS [MonthName_CN]   --Month Name in Simplified Chinese
FROM dbo.fn_DateTable(
      '20120101'
     ,'20151231'
     ,'en-US'   --US English
    ,DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT
    ,DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT
    ,DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT
    ,DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) EN
INNER JOIN dbo.fn_DateTable(
      '20120101'
     ,'20151231'
     ,'zh-cn'   --Chinese (Simplified PRC)
  ,DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT
  ,DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT
  ,DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT
  ,DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) CN ON CN.DateKey = EN.DateKey

**************************************************** */
ALTER FUNCTION [dbo].[fn_DateTable] (
     @startDate                                 date                                    -- Start date of the sequence to Generate
	,@endDate                                   date                                    -- End date of the sequence to Generate

    ,@culture                                   nvarchar(10)    = N'en-US'              -- Culture to be used for names generation

    ,@dateNameFormatString                      nvarchar(30)    = N'd'                  -- Format String for date name generation
    
    ,@yearNameFormatString                      varchar(30)     = N'yyyy'               -- Format String for the Year 
    ,@fiscalYearNameFormatString                varchar(30)     = N'\F\Y yyyy'          -- Format String for the Year 


    ,@monthNameFormatString                     nvarchar(30)    = N'Y'                  -- Format string for month name generation
    ,@monthOfYearNameFormatString               nvarchar(30)    = N'MMMM'               -- Format string for month of year name generation
    ,@monthDayNameFormatString                  nvarchar(30)    = N'M'                  -- Format string for month day name

    ,@weekNamePrefixFormatString                nvarchar(30)    = N''                   -- Format string for week prefix. Used to place Year as prefix to the week name
    ,@weekNameFormatString                      nvarchar(30)    = N'\W#'                -- Format string for week name
    ,@weekNameSuffixFormatString                nvarchar(30)    = N' yyyy'              -- Format string for week suffix. Used to place Year as suffix to the week name

    ,@quarterNamePrefixFormatString             nvarchar(30)    = N''                   -- Format string for quarter prefix. Used to place Year as prefix to the quartername
    ,@quarterNameFormatString                   nvarchar(30)    = N'\Q#'                -- Format string for quarter name
    ,@quarterNameSuffixFormatString             nvarchar(30)    = N' yyyy'              -- Format string for quarter suffix. Used to place Year as suffix to the quarter name

    ,@semesterNamePrefixFormatString            nvarchar(30)    = N''                   -- Format string for semester prefix. Used to place Year as prefix to the semester name
    ,@semesterNameFormatString                  nvarchar(30)    = N'\S#'                -- Format string for semester name
    ,@semesterNameSuffixFormatString            nvarchar(30)    = N' yyyy'              -- Format string for semester suffix. Used to place Year as suffix to the semester name

    ,@trimesterNamePrefixFormatString           nvarchar(30)    = N''                   -- Format string for trimester prefix. Used to place Year as prefix to the trimester name
    ,@trimesterNameFormatString                 nvarchar(30)    = N'\T#'                -- Format string for trimester name
    ,@trimesterNameSuffixFormatString           nvarchar(30)    = N' yyyy'              -- Format string for trimester suffix. Used to place Year as suffix to the trimester name

    ,@fiscalWeekNamePrefixFormatString          nvarchar(30)    = N''                   -- Format string for week prefix. Used to place Year as prefix to the week name
    ,@fiscalWeekNameFormatString                nvarchar(30)    = N'\F\W#'              -- Format string for week name
    ,@fiscalWeekNameSuffixFormatString          nvarchar(30)    = N' yyyy'              -- Format string for week suffix. Used to place Year as suffix to the week name

    ,@fiscalMonthNamePrefixFormatString         nvarchar(30)    = N''                   -- Format string for quarter prefix. Used to place Year as prefix to the quartername
    ,@fiscalMonthNameFormatString               nvarchar(30)    = N'\F\M#'              -- Format string for quarter name
    ,@fiscalMonthNameSuffixFormatString         nvarchar(30)    = N' yyyy'              -- Format string for quarter suffix. Used to place Year as suffix to the quarter name

    ,@fiscalQuarterNamePrefixFormatString       nvarchar(30)    = N''                   -- Format string for quarter prefix. Used to place Year as prefix to the quartername
    ,@fiscalQuarterNameFormatString             nvarchar(30)    = N'\F\Q#'              -- Format string for quarter name
    ,@fiscalQuarterNameSuffixFormatString       nvarchar(30)    = N' yyyy'              -- Format string for quarter suffix. Used to place Year as suffix to the quarter name

    ,@fiscalSemesterNamePrefixFormatString      nvarchar(30)    = N''                   -- Format string for semester prefix. Used to place Year as prefix to the semester name
    ,@fiscalSemesterNameFormatString            nvarchar(30)    = N'\F\S#'              -- Format string for semester name
    ,@fiscalSemesterNameSuffixFormatString      nvarchar(30)    = N' yyyy'              -- Format string for semester suffix. Used to place Year as suffix to the semester name

    ,@dayOfWeeknameFormatSring                  nvarchar(30)    = N'dddd'               -- Format string for the Day of Week name

    ,@firstDayOfWeek                            tinyint         = 1                     -- First Day Of Week. 1 = Monday - 7 = Sunday
    ,@FiscalQuarterWeekType                     smallint        = 445                   -- Type of Fiscal Quarter Week Types. Supported 445, 454, 544 (Specifies how the 13 weeks quarters are distributed among weeks)
    ,@lastDayOfFiscalYear                       tinyint         = 7                     -- Last Day of Fiscal Year. 1 = Monday - 7 = Sunday
    ,@lastDayOfFiscalYearType                   tinyint         = 1                     -- Specifies how the last day of fiscal yer is determined. 1 = Last @lastDayOfFiscalYear in the fiscal year end month. 2 = @lastDayOfFiscalYear closes to the fiscal year end month
    ,@fiscalYearStartMonth                      tinyint         = 9                     -- Specifies the Month at which the Fiscal year Starts

    ,@workingDays                               char(7)         = '1111100'             -- "Bitmask of working days where left most is Monday and RightMost is Sunday: MTWTFSS. Working Days are considered Week Days, Non Working days are considered Weekend
    ,@holidays                                  varchar(max)    = ''                    -- Comma Separated list of holidays. Holidays can be specified in the MMdd or yyyyMMdd.
    ,@workingDayTypeName                        nvarchar(30)    = 'Working day'         -- Name for the working days
    ,@nonWorkingDayTypeName                     nvarchar(30)    = 'Non-working day'     -- Name for the non-working days
    ,@holidayDayTypeName                        nvarchar(30)    = 'Holiday'             -- Name for the Holiday day type
)
RETURNS TABLE
AS
RETURN (
   WITH NumTable AS (  --Numbers Table
	    SELECT N FROM(VALUES (1), (1), (1), (1), (1), (1), (1), (1), (1), (1)) T(N)
    ),
    HolidaysBase AS (   --Convert the holidays comma separated list to XML for further CSV split
        SELECT 
            NULLIF(HT.H.value(N'.', N'int'), 0) H
        FROM (SELECT CONVERT(xml, '<holiday>'+ REPLACE(@holidays, ',', '</holiday><holiday>') + '</holiday>') HB) T(HB)
        CROSS APPLY HB.nodes(N'holiday') HT(H)
    ), 
    YearsTable AS (
        SELECT TOP(YEAR(@endDate) - YEAR(@startDate) + 1)
            YEAR(@startDate) +  ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 1 AS [Year]
        FROM 
            NumTable N10
           ,NumTable N100
           ,NumTable N1000
    )
    , HolidaysTable AS (
        SELECT
            CONVERT(date, CONVERT(char(10), YT.[Year] * 10000 + HB.H % 10000), 112) AS [HolidayDate]
            ,CONVERT(bit, 1)                                                        AS [IsHoliday]
        FROM 
            YearsTable YT
            ,HolidaysBase HB
        WHERE
            HB.H IS NOT NULL
            AND
            (
                HB.H / 10000 = 0
                OR
                HB.H / 10000 = [Year]
            )
    ),
    Dates AS (  --Generate Dates
	    SELECT TOP (DATEDIFF(DAY, @startDate, @endDate) + 1)  --Take only TOP values which equeals todifference between end and starting date
		    DATEADD(DAY, ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 1, @startDate) AS [Date]
	    FROM 
		     NumTable N10
		    ,NumTable N100
		    ,NumTable N1000
		    ,NumTable N10000
		    ,NumTable N100000
		    ,NumTable N1000000
            ,NumTable N10000000
    ),
    FiscalYearsBase AS (
    SELECT TOP(YEAR(@endDate) + 1 - (YEAR(@startDate) - 1))
        YEAR(@startDate) +  ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 1 AS FiscalYear
        ,DATEADD(DAY, @lastDayOfFiscalYear - 1, DATEADD(WEEK, DATEDIFF(WEEK, 0, DATEADD(MONTH, @fiscalYearStartMonth - 1, DATEADD(YEAR, DATEDIFF(YEAR, 0, @startDate) + ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 1 , 0))) - 1, 0)) FiscalYearEndCore
        ,DATEADD(DAY, @lastDayOfFiscalYear - 1, DATEADD(WEEK, DATEDIFF(WEEK, 0, DATEADD(MONTH, @fiscalYearStartMonth - 1, DATEADD(YEAR, DATEDIFF(YEAR, 0, @startDate) + ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 2 , 0))) - 1, 0)) PrevFiscalYearEndCore
    FROM 
        NumTable N10
       ,NumTable N100
       ,NumTable N1000
    ),
    FiscalYears AS (
        SELECT
            FiscalYear
            ,CONVERT(date, DATEADD(DAY, 1, CASE
                WHEN @lastDayOfFiscalYearType = 1 THEN DATEADD(DAY, 7 * CASE WHEN DAY(PrevFiscalYearEndCore) < 8 THEN -1 WHEN DAY(PrevFiscalYearEndCore) < 25 THEN 1 ELSE 0 END, PrevFiscalYearEndCore)
                ELSE
                    DATEADD(DAY, 7 * CASE WHEN DAY(PrevFiscalYearEndCore) < 4 OR DAY(PrevFiscalYearEndCore) > 27 THEN 0 ELSE 1 END, PrevFiscalYearEndCore)
            END)) AS [StartOfFiscalYear]
            ,CONVERT(date, CASE
                WHEN @lastDayOfFiscalYearType = 1 THEN DATEADD(DAY, 7 * CASE WHEN DAY(FiscalYearEndCore) < 8 THEN -1 WHEN DAY(FiscalYearEndCore) < 25 THEN 1 ELSE 0 END, FiscalYearEndCore)
                ELSE
                    DATEADD(DAY, 7 * CASE WHEN DAY(FiscalYearEndCore) < 4 OR DAY(FiscalYearEndCore) > 27 THEN 0 ELSE 1 END, FiscalYearEndCore)
            END) AS [EndOfFiscalYear]
        FROM FiscalYearsBase
    ),
    CalendarDateTableBase1 AS (   --Generate Calendar Date table
        SELECT
            YEAR([Date]) * 10000 + MONTH([Date]) * 100 + DAY([Date])                                                AS [DateKey]
            ,[Date]													                                                AS [Date]
            
            ,YEAR([Date])                                                                                           AS [CalendarYear]
            ,CONVERT(date, DATEADD(YEAR, DATEDIFF(YEAR, 0, [Date]), 0))                                             AS [StartOfCalendarYear]
            ,CONVERT(date, DATEADD(DAY, -1, DATEADD(YEAR, DATEDIFF(YEAR, 0, [Date]) + 1, 0)))                       AS [EndOfCalendarYear]

            ,YEAR(DATEADD(day, 26 - DATEPART(ISO_WEEK, [Date]), [Date]))                                            AS [YearOfISOWeek]
            ,CONVERT(date, DATEADD(YEAR, YEAR(DATEADD(day, 26 - DATEPART(ISO_WEEK, [Date]), [Date])) - 1900, 0))    AS [YearOfISOWeekDate]
            ,FY.[FiscalYear]                                                                                        AS [FiscalYear]
            ,FY.[StartOfFiscalYear]                                                                                 AS [StartOfFiscalYear]
            ,FY.[EndOfFiscalYear]                                                                                   AS [EndOfFiscalYear]


            ,CONVERT(tinyint, DAY([Date]))                                                                          AS [DayOfMonth]
            ,CONVERT(smallint, DATEPART(DAYOFYEAR, [date]))                                                         AS [DayOfYear]

            ,YEAR([Date]) * 100 + MONTH([Date])                                                                     AS [Month]
            ,CONVERT(tinyint, MONTH([Date]))                                                                        AS [MonthOfYear]
            ,DATEDIFF(MONTH, 0, [Date]) + 1                                                                         AS [MonthSequenceNumber]

            ,CONVERT(smallint, MONTH([Date]) * 100 + DAY([Date]))                                                   AS [MonthDay]
            
            ,CONVERT(date, DATEADD(WEEK, DATEDIFF(WEEK, 0, [Date]), 0))                                             AS [StartOfWeek]
            ,CONVERT(date, DATEADD(DAY, -1, DATEADD(WEEK, DATEDIFF(WEEK, 0, [Date]) + 1, 0)))                       AS [EndOfWeek]
            ,DATEDIFF(WEEK, 0, [Date]) + 1                                                                          AS [CalendarWeekSequenceNumber]

            ,CONVERT(date, DATEADD(MONTH, DATEDIFF(MONTH, 0, [Date]), 0))                                           AS [StartOfMonth]
            ,CONVERT(date, DATEADD(DAY, -1, DATEADD(MONTH, DATEDIFF(MONTH, 0, [Date]) + 1, 0)))                     AS [EndOfMonth]

            ,YEAR([Date]) * 10 + DATEPART(QUARTER, [Date])                                                          AS [CalendarQuarter]
            ,CONVERT(tinyint, DATEPART(QUARTER, [Date]))                                                            AS [QuarterOfCalendarYear]
            ,DATEDIFF(QUARTER, 0, [Date]) + 1                                                                       AS [CalendarquarterSequenceNumber]

            ,YEAR([Date]) * 10 + CONVERT(tinyint, (MONTH([Date]) - 1) / 4 + 1)                                      AS [CalendarTrimester]
            ,CONVERT(tinyint, (MONTH([Date]) - 1) / 4 + 1)                                                          AS [TrimesterOfCalendarYear]

            ,YEAR([Date]) * 10 + CONVERT(tinyint, (MONTH([Date]) - 1) / 6 + 1)                                      AS [CalendarSemester]
            ,CONVERT(tinyint, (MONTH([Date]) - 1) / 6 + 1)                                                          AS [SemesterOfCalendarYear]

            ,YEAR([Date]) * 100 + DATEPART(WEEK, [DATE])                                                            AS [CalendarWeek]
            ,CONVERT(tinyint, DATEPART(WEEK, [Date]))                                                               AS [WeekOfCalendarYear]

            ,YEAR(DATEADD(day, 26 - DATEPART(ISO_WEEK, [Date]), [Date])) * 100 + DATEPART(ISO_WEEK, [Date])         AS [ISOWeek]
            ,CONVERT(tinyint, DATEPART(ISO_WEEK, [Date]))                                                           AS [ISOWeekOfCalendarYear]

            ,CONVERT(tinyint, DATEDIFF(DAY, @firstDayOfWeek - 1, [Date]) % 7 + 1)                                   AS [DayOfWeek]
            ,CONVERT(tinyint, DATEDIFF(DAY, 0, [Date]) % 7 + 1)                                                     AS [DayOfWeekFixedMonday]

            ,ISNULL(HT.IsHoliday, 0)                                                                                AS [IsHoliday]

            ,CASE WHEN @FiscalQuarterWeekType IN (445,454,544) THEN @FiscalQuarterWeekType ELSE 1/0 END             AS [FiscalQuarterWeekType]
        FROM [Dates] D
        INNER JOIN [FiscalYears] FY ON D.[Date] BETWEEN FY.[StartOfFiscalYear] AND FY.[EndOfFiscalYear]
        LEFT JOIN HolidaysTable HT ON D.[Date] = HT.[HolidayDate]
    ),
    CalendarDateTableBase2 AS (
        SELECT
            D.*
            ,(D.[MonthOfYear] - 1) % 3 + 1                                                                                              AS [MonthOfQuarter]
            ,(D.[MonthOfYear] - 1) % 4 + 1                                                                                              AS [MonthOfTrimester]
            ,(D.[MonthOfYear]- 1) % 6 + 1                                                                                               AS [MonthOfSemester]
            ,DATEADD(MONTH, ([QuarterOfCalendarYear] - 1) * 3, D.[StartOfCalendarYear])                                                 AS [StartOfCalendarQuarter]
            ,DATEADD(DAY, -1, DATEADD(MONTH, ([QuarterOfCalendarYear]) * 3, D.[StartOfCalendarYear]))                                   AS [EndOfCalendarQuarter]
            ,DATEADD(MONTH, ([TrimesterOfCalendarYear] - 1) * 4, D.[StartOfCalendarYear])                                               AS [StartOfCalendarTrimester]
            ,DATEADD(DAY, -1, DATEADD(MONTH, ([TrimesterOfCalendarYear]) * 4, D.[StartOfCalendarYear]))                                 AS [EndOfCalendarTrimester]
            ,(D.[MonthSequenceNumber] - 1) / 4 + 1                                                                                      AS [CalendarTrimesterSequenceNumber]
            ,DATEADD(MONTH, ([SemesterOfCalendarYear] - 1) * 6, D.[StartOfCalendarYear])                                                AS [StartOfCalendarSemester]
            ,DATEADD(DAY, -1, DATEADD(MONTH, ([SemesterOfCalendarYear]) * 6, D.[StartOfCalendarYear]))                                  AS [EndOfCalendarSemester]
        
            ,(D.[MonthSequenceNumber] - 1) / 6 + 1                                                                                      AS [CalendarSemesterSequenceNumber]
        FROM CalendarDateTableBase1 D
    ),
    [CalendarDateTable] AS (
        SELECT
            D.*
            ,DATEDIFF(DAY, [StartOfCalendarYear], [EndOfCalendarYear]) + 1                                                              AS [DaysInCalendarYear]
            ,DATEDIFF(DAY, D.StartOfMonth, D.EndOfMonth) + 1                                                                            AS [DaysInMonth]
            ,DATEDIFF(DAY, D.StartOfCalendarQuarter, D.EndOfCalendarQuarter) + 1                                                        AS [DaysInCalendarQuarter]
            ,DATEDIFF(DAY, D.StartOfCalendarTrimester, D.EndOfCalendarTrimester) + 1                                                    AS [DaysInCalendarTrimester]
            ,DATEDIFF(DAY, D.StartOfCalendarSemester, D.EndOfCalendarSemester)  + 1                                                     AS [DaysInCalendarSemester]
        FROM [CalendarDateTableBase2] D
    ),
    [FiscalBase1] AS (
        SELECt
             D.*
            ,CONVERT(smallint, DATEDIFF(DAY, D.[StartOfFiscalYear], D.[Date]) + 1)                                                      AS [DayOfFiscalYear]
            ,CONVERT(smallint, DATEDIFF(DAY, D.[StartOfFiscalYear], D.[Date]) ) / 7 + 1                                                 AS [WeekOfFiscalYear]
            ,DATEDIFF(DAY, [StartOfFiscalYear], [EndOfFiscalYear]) + 1                                                                  AS [DaysInFiscalYear]
            ,(DATEDIFF(DAY, [StartOfFiscalYear], [EndOfFiscalYear]) + 1) / 7                                                            AS [WeeksInFiscalYear]
            ,[FiscalQuarterWeekType] / 100                                                                                              AS [WeeksInMonth1]
            ,([FiscalQuarterWeekType] % 100) / 10                                                                                       AS [WeeksInMonth2]
            ,[FiscalQuarterWeekType] % 10                                                                                               AS [WeeksInMonth3]
        FROM [CalendarDateTable] D
    ),
    [FiscalBase2] AS (
        SELECT
            D.*
            ,CONVERT(bit, SUBSTRING(@workingDays, [DayOfWeekFixedMonday], 1))                                                           AS [IsWeekDay]
            ,CASE WHEN D.[WeekOfFiscalYear] > 52 THEN 4 ELSE  D.[WeekOfFiscalYear] / 13 + SIGN(D.[WeekOfFiscalYear] % 13) END           AS [QuarterOfFiscalYear]

        FROM [FiscalBase1] D
    ),
    [FiscalCalendarBase1] AS (
        SELECT
            D.*
            ,CONVERT(bit, D.[IsWeekDay] ^ 1)                                                                                            AS [IsWeekend]
            ,CASE WHEN D.[WeekOfFiscalYear] > 52 THEN 14 ELSE D.[WeekOfFiscalYear] - 13 * (D.[QuarterOfFiscalYear]  - 1) END            AS [WeekOfFiscalQuarter]
            ,(D.[QuarterOfFiscalYear] - 1) / 2 + 1                                                                                      AS [SemesterOfFiscalYear]
        FROM [FiscalBase2] D
    ),
    [FiscalCalendarBase2] AS (
        SELECT
            D.*
            ,CONVERT(bit, (D.[IsWeekend] | D.[IsHoliday]) ^ 1)                                                                          AS [IsWorkingDay]
            ,CONVERT(tinyint, ([QuarterOfFiscalYear] - 1) * 3 + 
                CASE
                    WHEN [WeekOfFiscalQuarter] <= [WeeksInMonth1] THEN 1 
                    WHEN [WeekOfFiscalQuarter] <= [WeeksInMonth1] + [WeeksInMonth2] THEN 2 
                    ELSE 3 
                END)                                                                                                                    AS [MonthOfFiscalYear]

            ,CONVERT(date, DATEADD(WEEK, [WeekOfFiscalYear] -1, [StartOfFiscalYear]))                                                   AS [StartOfFiscalWeek]
            ,CONVERT(date, DATEADD(DAY, -1, DATEADD(WEEK, [WeekOfFiscalYear], [StartOfFiscalYear])))                                    AS [EndOfFiscalWeek]
            ,D.[FiscalYear] * 100 + D.[WeekOfFiscalYear]                                                                                AS [FiscalWeek]

            ,DATEADD(WEEK, ([QuarterOfFiscalYear] - 1) * 13, [StartOfFiscalYear])                                                       AS [StartOfFiscalQuarter]
            ,CASE
                WHEN [QuarterOfFiscalYear] = 4 AND D.[WeeksInFiscalYear] > 52 THEN [EndOfFiscalYear] 
                ELSE DATEADD(DAY, -1, DATEADD(WEEK, ([QuarterOfFiscalYear]) * 13, [StartOfFiscalYear])) 
             END                                                                                                                        AS [EndOfFiscalQuarter]
            ,D.[FiscalYear] * 10 + D.[QuarterOfFiscalYear]                                                                              AS [FiscalQuarter]
            ,([QuarterOfFiscalYear] - 1) % 2 + 1                                                                                        AS [QuarterOfFiscalSemester]

            ,DATEADD(WEEK, ([SemesterOfFiscalYear] - 1) * 26, [StartOfFiscalYear])                                                      AS [StartOfFiscalSemester]
            ,CASE
                WHEN D.[SemesterOfFiscalYear] = 2 AND  D.[WeeksInFiscalYear] > 52 THEN [EndOfFiscalYear] 
                ELSE DATEADD(DAY, -1, DATEADD(WEEK, ([SemesterOfFiscalYear]) * 26, [StartOfFiscalYear])) 
             END                                                                                                                        AS [EndOfFiscalSemester]
            ,D.[FiscalYear] * 10 + D.[SemesterOfFiscalYear]                                                                             AS [FiscalSemester]
            ,CASE WHEN D.[WeekOfFiscalYear] > 52 THEN 27 ELSE D.[WeekOfFiscalYear] - 26 * (D.[SemesterOfFiscalYear]  - 1) END           AS [WeekOfFiscalSemester]

        FROM [FiscalCalendarBase1] D
    ),
    [FiscalCalendarBase3] AS (
        SELECT
            D.*
            ,DATEADD(WEEK, (QuarterOfFiscalYear - 1) * 13 + 
                CASE (D.[MonthOfFiscalYear] - 1) % 3 + 1
                    WHEN 1 THEN  0
                    WHEN 2 THEN [WeeksInMonth1] 
                    ELSE [WeeksInMonth1] + [WeeksInMonth2] 
                END, [StartOfFiscalYear])                                                                                               AS [StartOfFiscalMonth]

            ,CASE 
                WHEN [MonthOfFiscalYear] = 12 AND [WeeksInFiscalYear] > 52 THEN [EndOfFiscalYear]
                ELSE
                DATEADD(DAY, -1, DATEADD(WEEK, (QuarterOfFiscalYear - 1) * 13 + 
                    CASE (D.[MonthOfFiscalYear] - 1) % 3 + 1
                        WHEN 1 THEN  [WeeksInMonth1]
                        WHEN 2 THEN [WeeksInMonth1] + [WeeksInMonth2] 
                        ELSE [WeeksInMonth1] + [WeeksInMonth2] + [WeeksInMonth3]
                    END, [StartOfFiscalYear]))
             END                                                                                                                        AS [EndOfFiscalMonth]
            ,(D.[MonthOfFiscalYear] - 1) % 6 + 1                                                                                        AS [MonthOfFiscalSemester]
            ,(D.[MonthOfFiscalYear] - 1) % 3 + 1                                                                                        AS [MonthOfFiscalQuarter]

        FROM [FiscalCalendarBase2] D
    ),
    [FiscalCalendar] AS (
        SELECT
            D.*
            ,DATEDIFF(DAY, D.StartOfFiscalMonth, D.EndOfFiscalMonth) + 1                                                                AS [DaysInFiscalMonth]
            ,CASE 
                WHEN D.MonthOfFiscalQuarter = 1 THEN D.WeeksInMonth1
                WHEN D.MonthOfFiscalQuarter = 2 THEN D.WeeksInMonth2
                WHEN D.MonthOfFiscalQuarter = 3 AND D.QuarterOfFiscalYear = 4 AND WeeksInFiscalYear > 52 THEN WeeksInMonth3 + 1
                ELSE D.WeeksInMonth3
            END                                                                                                                         AS [WeeksInFiscalMonth]
            ,DATEDIFF(DAY, D.StartOfFiscalQuarter, D.EndOfFiscalQuarter) + 1                                                            AS [DaysInFiscalQuarter]
            ,CASE WHEN D.QuarterOfFiscalYear = 4 AND [WeeksInFiscalYear] > 52 THEN 14 ELSE 13 END                                       AS [WeeksInFiscalQuarter]
            ,DATEDIFF(DAY, D.StartOfFiscalSemester, D.EndOfFiscalSemester)  + 1                                                         AS [DaysInFiscalSemester]
            ,CASE WHEN  D.SemesterOfFiscalYear = 2 AND [WeeksInFiscalYear] > 52 THEN 27 ELSE 26 END                                     AS [WeeksInFiscalSemester]

        FROM [FiscalCalendarBase3] D
    )
    SELECT                                                                                       
         D.[DateKey]                                                                                                                    AS [DateKey]
        ,D.[Date]                                                                                                                       AS [Date]

        ,DATEDIFF(DAY, 0, [Date]) + 1                                                                                                   AS [DateSequenceNumber] --Number of Days since 1900-01-01
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT([Date], @dateNameFormatString, @culture))))                                           AS [DateName]

        ,D.[DayOfWeek]                                                                                                                  AS [DayOfWeek]
        ,CONVERT(nvarchar(30), FORMAT([Date], @dayOfWeeknameFormatSring, @culture))                                                     AS [DayOfWeekName]
        
        ,D.[CalendarYear]                                                                                                               AS [CalendarYear]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT([Date], @yearNameFormatString, @culture))))                                           AS [CalendarYearName]
        ,D.[StartOfCalendarYear]                                                                                                        AS [StartOfCalendarYear]
        ,D.[EndOfCalendarYear]                                                                                                          AS [EndOfCalendarYear]
        ,D.[DayOfYear]                                                                                                                  AS [DayOfYear]
   
        ,D.[FiscalYear]                                                                                                                 AS [FiscalYear]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT(D.[EndOfFiscalYear], @fiscalYearNameFormatString, @culture))))                        AS [FiscalYearName]
        ,D.[DayOfFiscalYear]                                                                                                            AS [DayOfFiscalYear]
        ,D.[StartOfFiscalYear]                                                                                                          AS [StartOfFiscalYear]
        ,D.[EndOfFiscalYear]                                                                                                            AS [EndOfFiscalYear]

        ,D.[Month]                                                                                                                      AS [Month]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT([Date], @monthNameFormatString, @culture))))                                          AS [MonthName]
        ,D.[MonthOfYear]                                                                                                                AS [MonthOfYear]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT([Date], @monthOfYearNameFormatString, @culture))))                                    AS [MonthOfYearName]
        ,D.[StartOfMonth]                                                                                                               AS [StartOfMonth]
        ,D.[EndOfMonth]                                                                                                                 AS [EndOfMonth]
        ,D.[MonthSequenceNumber]                                                                                                        AS [MonthSequenceNumber]
        ,[MonthOfQuarter]                                                                                                               AS [MonthOfQuarter]
        ,[MonthOfTrimester]                                                                                                             AS [MonthOfTrimester]
        ,[MonthOfSemester]                                                                                                              AS [MonthOfSemester]
        ,D.[DayOfMonth]                                                                                                                 AS [DayOfMonth]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT(D.[Date], @monthDayNameFormatString))))                                               AS [DayOfMonthName]
        ,D.[MonthDay]                                                                                                                   AS [MonthDay]

        ,D.[CalendarQuarter]                                                                                                            AS [CalendarQuarter]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), 
          ISNULL(FORMAT([Date], ISNULL(NULLIF(@quarterNamePrefixFormatString, N''), N' '), @culture), N'')
         +ISNULL(FORMAT([QuarterOfCalendarYear], @quarterNameFormatString, @culture), N'')
         +ISNULL(FORMAT([Date], ISNULL(NULLIF(@quarterNameSuffixFormatString, N''), N' '), @culture), N''))))                           AS [CalendarQuarterName]
        ,[StartOfCalendarQuarter]                                                                                                       AS [StartOfCalendarQuarter]
        ,[EndOfCalendarQuarter]                                                                                                         AS [EndOfCalendarQuarter]
        ,D.[CalendarquarterSequenceNumber]                                                                                              AS [CalendarquarterSequenceNumber]
        ,D.[QuarterOfCalendarYear]                                                                                                      AS [QuarterOfCalendarYear]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT([QuarterOfCalendarYear], @quarterNameFormatString, @culture))))                       AS [QuarterOfCalendarYearName]


        ,D.[CalendarTrimester]                                                                                                          AS [CalendarTrimester]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), 
          ISNULL(FORMAT([Date], ISNULL(NULLIF(@trimesterNamePrefixFormatString, N''), N' '), @culture), N'')
         +ISNULL(FORMAT([TrimesterOfCalendarYear], @trimesterNameFormatString, @culture), N'')
         +ISNULL(FORMAT([Date], ISNULL(NULLIF(@trimesterNameSuffixFormatString, N''), N' '), @culture), N''))))                         AS [CalendarTrimesterName]
        ,[CalendarTrimesterSequenceNumber]                                                                                              AS [CalendarTrimesterSequenceNumber]
        ,D.[TrimesterOfCalendarYear]                                                                                                    AS [TrimesterOfCalendarYear]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT([TrimesterOfCalendarYear], @trimesterNameFormatString, @culture))))                   AS [TrimesterOfCalendarYearName]


        ,D.[CalendarSemester]                                                                                                           AS [CalendarSemester]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), 
          ISNULL(FORMAT([Date], ISNULL(NULLIF(@semesterNamePrefixFormatString, N''), N' '), @culture), N'')
         +ISNULL(FORMAT([SemesterOfCalendarYear], @semesterNameFormatString, @culture), N'')
         +ISNULL(FORMAT([Date], ISNULL(NULLIF(@semesterNameSuffixFormatString, N''), N' '), @culture), N''))))                          AS [CalendarSemesterName]
         ,[StartOfCalendarTrimester]                                                                                                    AS [StartOfCalendarSemester]
         ,[EndOfCalendarTrimester]                                                                                                      AS [EndOfCalendarSemester]
         ,[CalendarSemesterSequenceNumber]                                                                                              AS [CalendarSemesterSequenceNumber]
        ,D.[SemesterOfCalendarYear]                                                                                                     AS [SemesterOfCalendarYear]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT([SemesterOfCalendarYear], @semesterNameFormatString, @culture))))                     AS [SemesterOfCalendarYearName]


        ,D.[CalendarWeek]                                                                                                               AS [CalendarWeek]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), 
          ISNULL(FORMAT([Date], ISNULL(NULLIF(@weekNamePrefixFormatString, N''), N' '), @culture), N'')
         +ISNULL(FORMAT([WeekOfCalendarYear], @weekNameFormatString, @culture), N'')
         +ISNULL(FORMAT([Date], ISNULL(NULLIF(@weekNameSuffixFormatString, N''), N' '), @culture), N''))))                              AS [CalendarWeekName]
        ,D.[StartOfWeek]                                                                                                                AS [StartOfWeek]
        ,D.[EndOfWeek]                                                                                                                  AS [EndOfWeek]
        ,D.[CalendarWeekSequenceNumber]                                                                                                 AS [CalendarWeekSequenceNumber]
        ,D.[WeekOfCalendarYear]                                                                                                         AS [WeekOfCalendarYear]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT([WeekOfCalendarYear], @weekNameFormatString, @culture))))                             AS [WeekOfCalendarYearName]

        ,D.[ISOWeek]                                                                                                                    AS [ISOWeek]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), 
          ISNULL(FORMAT([YearOfISOWeekDate], ISNULL(NULLIF(@weekNamePrefixFormatString, N''), N' '), @culture), N'')
         +ISNULL(FORMAT([ISOWeekOfCalendarYear], @weekNameFormatString, @culture), N'')
         +ISNULL(FORMAT([YearOfISOWeekDate], ISNULL(NULLIF(@weekNameSuffixFormatString, N''), N' '), @culture), N''))))                 AS [ISOWeekName]
        ,D.[ISOWeekOfCalendarYear]                                                                                                      AS [ISOWeekOfCalendarYear]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT([ISOWeekOfCalendarYear], @weekNameFormatString, @culture))))                          AS [ISOWeekOfCalendarYearName]

        ,D.[YearOfISOWeek]                                                                                                              AS [YearOfISOWeek]
        ,DATEADD(DAY, -DATEDIFF(DAY, @firstDayOfWeek - 1, D.[YearOfISOWeekDate]) % 7, D.[YearOfISOWeekDate])                            AS [StartOfYearOfISOWeek]
        ,DATEADD(
            DAY
            ,-DATEDIFF(DAY, @firstDayOfWeek - 1, DATEADD(YEAR, 1, D.[YearOfISOWeekDate])) % 7- 1
            , DATEADD(YEAR, 1, D.[YearOfISOWeekDate])
         )                                                                                                                              AS [EndtOfYearOfISOWeek]

        ,D.[FiscalWeek]                                                                                                                 AS [FiscalWeek]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), 
          ISNULL(FORMAT([EndOfFiscalYear], ISNULL(NULLIF(@fiscalWeekNamePrefixFormatString, N''), N' '), @culture), N'')
         +ISNULL(FORMAT([WeekOfFiscalYear], @fiscalWeekNameFormatString, @culture), N'')
         +ISNULL(FORMAT([EndOfFiscalYear], ISNULL(NULLIF(@fiscalWeekNameSuffixFormatString, N''), N' '), @culture), N''))))             AS [FiscalWeekName]
        ,D.[StartOfFiscalWeek]                                                                                                          AS [StartOfFiscalWeek]
        ,D.[EndOfFiscalWeek]                                                                                                            AS [EndOfFiscalWeek]
        ,D.[WeekOfFiscalYear]                                                                                                           AS [WeekOfFiscalYear]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT([WeekOfFiscalYear], @fiscalWeekNameFormatString, @culture))))                         AS [WeekOfFiscalYearName]
        ,D.[WeekOfFiscalSemester]                                                                                                       AS [WeekOfFiscalSemester]
        ,D.[WeekOfFiscalQuarter]                                                                                                        AS [WeekOfFiscalQuarter]

        ,D.[FiscalYear] * 100 + D.[MonthOfFiscalYear]                                                                                   AS [FiscalMonth]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), 
          ISNULL(FORMAT([EndOfFiscalYear], ISNULL(NULLIF(@fiscalMonthNamePrefixFormatString, N''), N' '), @culture), N'')
         +ISNULL(FORMAT([QuarterOfFiscalYear], @fiscalMonthNameFormatString, @culture), N'')
         +ISNULL(FORMAT([EndOfFiscalYear], ISNULL(NULLIF(@fiscalMonthNameSuffixFormatString, N''), N' '), @culture), N''))))            AS [FiscalMonthName]
        ,D.[StartOfFiscalMonth]                                                                                                         AS [StartOfFiscalMonth]
        ,D.[EndOfFiscalMonth]                                                                                                           AS [EndOfFiscalMonth]
        ,D.[MonthOfFiscalYear]                                                                                                          AS [MonthOfFiscalYear]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT([QuarterOfFiscalYear], @fiscalMonthNameFormatString, @culture))))                     AS [MonthOfFiscalYearName]
        ,[MonthOfFiscalSemester]                                                                                                        AS [MonthOfFiscalSemester]
        ,[MonthOfFiscalQuarter]                                                                                                         AS [MonthOfFiscalQuarter]

        ,[FiscalQuarter]                                                                                                                AS [FiscalQuarter]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), 
          ISNULL(FORMAT([EndOfFiscalYear], ISNULL(NULLIF(@fiscalQuarterNamePrefixFormatString, N''), N' '), @culture), N'')
         +ISNULL(FORMAT([QuarterOfFiscalYear], @fiscalQuarterNameFormatString, @culture), N'')
         +ISNULL(FORMAT([EndOfFiscalYear], ISNULL(NULLIF(@fiscalQuarterNameSuffixFormatString, N''), N' '), @culture), N''))))          AS [FiscalQuarterName]
        ,D.[StartOfFiscalQuarter]                                                                                                       AS [StartOfFiscalQuarter]
        ,D.[EndOfFiscalQuarter]                                                                                                         AS [EndOfFiscalQuarter]
        ,D.[QuarterOfFiscalYear]                                                                                                        AS [QuarterOfFiscalYear]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT([QuarterOfFiscalYear], @fiscalQuarterNameFormatString, @culture))))                   AS [QuarterOfFiscalYearName]
        ,D.[QuarterOfFiscalSemester]                                                                                                    AS [QuarterOfFiscalSemester]

        ,D.[FiscalSemester]                                                                                                             AS [FiscalSemester]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), 
          ISNULL(FORMAT([EndOfFiscalYear], ISNULL(NULLIF(@fiscalSemesterNamePrefixFormatString, N''), N' '), @culture), N'')
         +ISNULL(FORMAT([SemesterOfFiscalYear], @fiscalSemesterNameFormatString, @culture), N'')
         +ISNULL(FORMAT([EndOfFiscalYear], ISNULL(NULLIF(@fiscalSemesterNameSuffixFormatString, N''), N' '), @culture), N''))))         AS [FiscalSemesterName]
        ,D.[StartOfFiscalSemester]                                                                                                      AS [StartOfFiscalSemester]
        ,D.[EndOfFiscalSemester]                                                                                                        AS [EndOfFiscalSemester]
        ,[SemesterOfFiscalYear]                                                                                                         AS [SemesterOfFiscalYear]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT([SemesterOfFiscalYear], @fiscalSemesterNameFormatString, @culture))))                 AS [SemesterOfFiscalYearName]

        ,D.IsWeekDay                                                                                                                    AS [IsWeekDay]
        ,D.[IsWeekend]                                                                                                                  AS [IsWeekend]
        ,D.[IsHoliday]                                                                                                                  AS [IsHoliday]
        ,D.[IsWorkingDay]                                                                                                               AS [IsWorkingDay]
        ,CASE WHEN D.[IsWOrkingDay] = 1 THEN @workingDayTypeName ELSE @nonWorkingDayTypeName END                                        AS [DayTypeName]
        ,CASE
            WHEN D.[IsHoliday] = 1 THEN @holidayDayTypeName 
            WHEN D.[IsWOrkingDay] = 1 
            THEN @workingDayTypeName 
            ELSE @nonWorkingDayTypeName 
         END                                                                                                                            AS [HolidayDayTypeName]

        ,[DaysInCalendarYear]                                                                                                           AS [DaysInCalendarYear]
        ,[DaysInMonth]                                                                                                                  AS [DaysInMonth]
        ,[DaysInCalendarQuarter]                                                                                                        AS [DaysInCalendarQuarter]
        ,[DaysInCalendarTrimester]                                                                                                      AS [DaysInCalendarTrimester]
        ,[DaysInCalendarSemester]                                                                                                       AS [DaysInCalendarSemester]

        ,[DaysInFiscalYear]                                                                                                             AS [DaysInFiscalYear]
        ,[WeeksInFiscalYear]                                                                                                            AS [WeeksInFiscalYear]
        ,[DaysInFiscalMonth]                                                                                                            AS [DaysInFiscalMonth]
        ,[WeeksInFiscalMonth]                                                                                                           AS [WeeksInFiscalMonth]
        ,[DaysInFiscalQuarter]                                                                                                          AS [DaysInFiscalQuarter]
        ,[WeeksInFiscalQuarter]                                                                                                         AS [WeeksInFiscalQuarter]
        ,[DaysInFiscalSemester]                                                                                                         AS [DaysInFiscalSemester]
        ,[WeeksInFiscalSemester]                                                                                                        AS [WeeksInFiscalSemester]

    FROM [FiscalCalendar] D
)
