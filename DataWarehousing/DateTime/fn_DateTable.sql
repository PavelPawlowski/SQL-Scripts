IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID('[dbo].[fn_DateTable]') AND TYPE = 'IF')
    EXECUTE ('CREATE FUNCTION [dbo].[fn_DateTable]() RETURNS TABLE AS RETURN(SELECT ''Container for fn_DateTable() (C) Pavel Pawlowski'' AS DateTable)');
GO
/* ****************************************************
fn_DateTable v 1.2 (C) 2018 - 2020 Pavel Pawlowski

Feedback: mailto:pavel.pawlowski@hotmail.cz

MIT License

Copyright (c) 2018 - 2020 Pavel Pawlowski

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
    First Supported date is 1900-01-01. For dates prior 1900-01-01 it might generate non-sense data
    For Fiscal Weeks calculation the function assumes the first day of week is Monday.
    Calendar weeks calculation is based on @firstDayofWeek parameter

Parameters:
     @startDate                                 date                                    -- Start date of the sequence to Generate
    ,@endDate                                   date                                    -- End date of the sequence to Generate

    ,@culture                                   nvarchar(10)    = N'en-US'              -- Culture to be used for names generation

    ,@firstDayOfWeek                            tinyint         = 1                     -- First Day Of Week. 1 = Monday - 7 = Sunday
    ,@calendarFirstWeek                         tinyint         = 2                     -- 1 = Starts on 1. January, 2 = First 4 days week, 3 = First Full Week.
    ,@fiscalQuarterWeekType                     smallint        = 445                   -- Type of Fiscal Quarter Week Types. Supported 445, 454, 544 (Specifies how the 13 weeks quarters are distributed among weeks)
    ,@lastDayOfFiscalYear                       tinyint         = 7                     -- Last Day of Fiscal Year. 1 = Monday - 7 = Sunday
    ,@lastDayOfFiscalYearType                   tinyint         = 1                     -- Specifies how the last day of fiscal yer is determined. 1 = Last @lastDayOfFiscalYear in the fiscal year end month. 2 = @lastDayOfFiscalYear closes to the fiscal year end month
    ,@fiscalYearStartMonth                      tinyint         = 9                     -- Specifies the Month at which the Fiscal year Starts

    ,@dateNameFormatString                      nvarchar(30)    = N'd'                  -- Format String for date name generation
    
    ,@yearNameFormatString                      varchar(30)     = N'yyyy'               -- Format String for the name of year 
    ,@fiscalYearNameFormatString                varchar(30)     = N'\F\Y yyyy'          -- Format String for the name of fiscal year 


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

    ,@workingDays                               char(7)         = '1111100'             -- Bitmask of working days where left most is Monday and RightMost is Sunday: MTWTFSS. Working Days are considered Week Days, Non Working days are considered Weekend
    ,@workingDayTypeName                        nvarchar(30)    = 'Working day'         -- Name for the working days
    ,@nonWorkingDayTypeName                     nvarchar(30)    = 'Non-working day'     -- Name for the non-working days
    ,@holidayDayTypeName                        nvarchar(30)    = 'Holiday'             -- Name for the Holiday day type
    ,@holidays                                  varchar(max)    = ''                    -- Comma Separated list of holidays. Holidays can be specified in the MMdd or yyyyMMdd.

For details on Format Strings, review MSDN - FORMAT(Transact-SQL): https://msdn.microsoft.com/en-us/library/hh213505.aspx
For details on cultures see MDSDN - National Language Support (NLS) API Reference: https://msdn.microsoft.com/en-us/goglobal/bb896001.aspx
For details on ISO weeks look at: https://en.wikipedia.org/wiki/ISO_week_date

Output Columns as @dateTable table variable
-------------------------------------------
DECLARE @dateTable TABLE (
     [DateKey]                          int             -- Unique date key in format yyyyMMdd
    ,[Date]                             date            -- Date
    ,[DateSequenceNumber]               int             -- Number of days since 1900-01-01
    ,[DateName]                         nvarchar(30)    -- Date as string
    ,[DayOfWeek]                        tinyint         -- Week day number
    ,[DayOfWeekName]                    nvarchar(30)    -- Name of the week day
    ,[DayOccurenceInMonth]              tinyint         -- Occurence of a week day in Month
    ,[CalendarYear]                     int             -- Calendar year
    ,[CalendarYearName]                 nvarchar(30)    -- Calendar year as string
    ,[StartOfCalendarYear]              date            -- Date representing start of calendar year
    ,[EndOfCalendarYear]                date            -- Date representing end of calendary year
    ,[FirstDayOfYear]                   tinyint         -- First day of calendary year 1 = Monday - 7 = Sunday
    ,[FirstDayOfYearName]               nvarchar(30)    -- Name of the first day of calendar year
    ,[DayOfYear]                        smallint        -- Day number in year
    ,[FiscalYear]                       int             -- Fiscal year
    ,[FiscalYearName]                   nvarchar(30)    -- Fiscal year as string
    ,[DayOfFiscalYear]                  smallint        -- Day number in fiscal year
    ,[StartOfFiscalYear]                date            -- Date representing start of fiscal year
    ,[EndOfFiscalYear]                  date            -- Date representing end of fiscal year
    ,[Month]                            int             -- Unique identification of year in format yyyyMM
    ,[MonthName]                        nvarchar(30)    -- Unique month name
    ,[MonthOfYear]                      tinyint         -- Month number within year
    ,[MonthOfYearName]                  nvarchar(30)    -- Month name
    ,[StartOfMonth]                     date            -- Date representing start of month
    ,[EndOfMonth]                       date            -- Date representing end of month
    ,[MonthSequenceNumber]              int             -- Number of months since 1900-01-01
    ,[MonthOfQuarter]                   tinyint         -- Month number within quarter
    ,[MonthOfTrimester]                 tinyint         -- Month number within trimestar
    ,[MonthOfSemester]                  tinyint         -- Month number within semester
    ,[DayOfMonth]                       tinyint         -- Day of month
    ,[DayOfMonthName]                   nvarchar(30)    -- Name of the day of month
    ,[MonthDay]                         smallint        -- Unique identification of day within calendar months in format MMdd.
    ,[CalendarQuarter]                  int             -- Unique identification of calendar quarter in format yyyyQ
    ,[CalendarQuarterName]              nvarchar(30)    -- Calendar quarter as unique string
    ,[StartOfCalendarQuarter]           date            -- Date representing start of calendar quarter
    ,[EndOfCalendarQuarter]             date            -- Date representing end of calendar quarter
    ,[CalendarquarterSequenceNumber]    int             -- Number of calendar quarters since 1900-01-01
    ,[QuarterOfCalendarYear]            tinyint         -- Quarter number within calendar year
    ,[QuarterOfCalendarYearName]        nvarchar(30)    -- Quarter withing calendar year as string
    ,[CalendarTrimester]                int             -- Unique identification of calendar trimester in format yyyyT
    ,[CalendarTrimesterName]            nvarchar(30)    -- Calendar trimester as unique string
    ,[CalendarTrimesterSequenceNumber]  int             -- Number of calendar trimesters since 1900-01-01
    ,[TrimesterOfCalendarYear]          tinyint         -- Trimester number within calendar year
    ,[TrimesterOfCalendarYearName]      nvarchar(30)    -- Trimestar withing calendar year as string
    ,[CalendarSemester]                 int             -- Unique identification of calendar semester in format yyyyS
    ,[CalendarSemesterName]             nvarchar(30)    -- Calendar Semester as unique string
    ,[StartOfCalendarSemester]          date            -- Date representing start of calendar semester
    ,[EndOfCalendarSemester]            date            -- Date representing end of calendar semester
    ,[CalendarSemesterSequenceNumber]   int             -- Number of calendar semesters since 1900-01-01
    ,[SemesterOfCalendarYear]           tinyint         -- Number of semester within calendar year
    ,[SemesterOfCalendarYearName]       nvarchar(30)    -- Semester within calendar year as string
    ,[StartOfFirstCalendarWeek]         date            -- Date of the First Day of the First Calendar Week
    ,[EndOfLastCalendarWeek]            date            -- Date of the Last Day of the Last Calendar Week
    ,[CalendarWeek]                     int             -- Unique identifrication of calendar week in format yyyyww
    ,[CalendarWeekName]                 nvarchar(30)    -- Calendar week as unique string
    ,[StartOfWeek]                      date            -- Start of calendar week
    ,[EndOfWeek]                        date            -- End of calendar week
    ,[CalendarWeekSequenceNumber]       int             -- Number of weeks since 1900-01-01
    ,[WeekOfCalendarYear]               tinyint         -- Week number within calendar year
    ,[WeekOfCalendarYearName]           nvarchar(30)    -- Week within calendar year as string
    ,[ISOWeek]                          int             -- Unique identification of ISO Week
    ,[ISOWeekName]                      nvarchar(30)    -- ISO Week as unique string
    ,[ISOWeekSequenceNumber]            int             -- Number of ISO weeks since 1900-01-01
    ,[ISOWeekOfCalendarYear]            tinyint         -- Number of ISO week within calendar year
    ,[ISOWeekOfCalendarYearName]        nvarchar(30)    -- ISO week within calendar year as string
    ,[YearOfISOWeek]                    int             -- Year of ISO Week (For first week it can be previous year and for last week it can be next year)
    ,[StartOfYearOfISOWeek]             date            -- Date representing start of ISO year (First day of first ISO Week)
    ,[EndOfYearOfISOWeek]               date            -- Date representing end of ISO year (Last day of last ISO Week)
    ,[FiscalWeek]                       int             -- Unique idntification of fiscal week in format yyyyww
    ,[FiscalWeekName]                   nvarchar(30)    -- Week of Fiscal year as unique string
    ,[StartOfFiscalWeek]                date            -- Date representing start of fiscal week
    ,[EndOfFiscalWeek]                  date            -- Date representing end of fiscal week
    ,[WeekOfFiscalYear]                 int             -- Number of week within fiscal year
    ,[WeekOfFiscalYearName]             nvarchar(30)    -- Week within fiscal year as string
    ,[WeekOfFiscalSemester]             tinyint         -- Week number within fiscal semester
    ,[WeekOfFiscalQuarter]              tinyint         -- Week number within within fiscal quarter
    ,[FiscalMonth]                      int             -- Unique identification of fiscal month in format yyyyMM
    ,[FiscalMonthName]                  nvarchar(30)    -- Fiscal month as unique string
    ,[StartOfFiscalMonth]               date            -- Date representing start of fiscal month
    ,[EndOfFiscalMonth]                 date            -- Date representing end of fiscal month
    ,[MonthOfFiscalYear]                tinyint         -- Month number within fiscal year
    ,[MonthOfFiscalYearName]            nvarchar(30)    -- Month within fiscal year as string
    ,[MonthOfFiscalSemester]            tinyint         -- Month number withinfiscal semester
    ,[MonthOfFiscalQuarter]             tinyint         -- Month number within fiscal quarter
    ,[FiscalQuarter]                    int             -- Unique identification of fiscal quarter in format yyyyQ
    ,[FiscalQuarterName]                nvarchar(30)    -- Fiscal quarter as unique string
    ,[StartOfFiscalQuarter]             date            -- Date representing start of fiscal quarter
    ,[EndOfFiscalQuarter]               date            -- Date representing end of fiscal quarter
    ,[QuarterOfFiscalYear]              tinyint         -- Quarter number within fiscal year
    ,[QuarterOfFiscalYearName]          nvarchar(30)    -- Quarter within fiscal year as string
    ,[QuarterOfFiscalSemester]          tinyint         -- Quarter number within fiscal semester
    ,[FiscalSemester]                   int             -- Unique identification of fiscal semester in format yyyyS
    ,[FiscalSemesterName]               nvarchar(30)    -- Fiscal semester as unique string
    ,[StartOfFiscalSemester]            date            -- Date representing start of fiscal semester
    ,[EndOfFiscalSemester]              date            -- Date representing end of fiscal semester
    ,[SemesterOfFiscalYear]             tinyint         -- Semester number within fiscal year
    ,[SemesterOfFiscalYearName]         nvarchar(30)    -- Semester within fiscal year as string
    ,[IsLastOccurenceOfDayInMonth]      bit             -- Identifies whether the current day is last occurence of a week day in Month
    ,[IsWeekDay]                        bit             -- Identifies whether the day is a week day
    ,[IsWeekend]                        bit             -- Identifies whether the day is weekend
    ,[IsHoliday]                        bit             -- Identifies whether the day is holiday
    ,[HolidayName]                      nvarchar(50)    -- Name of the holiday
    ,[IsWorkingDay]                     bit             -- Identifies whether the day is Working day = IsWeekDay and is not Holiday
    ,[DayTypeName]                      nvarchar(30)    -- Working/Non Working day as string
    ,[HolidayDayTypeName]               nvarchar(30)    -- Working/Non Working/Holiday as string
    ,[DaysInCalendarYear]               smallint        -- Number of days in calendar year
    ,[ISOWeeksInCalendarYear]           tinyint         -- Number of ISO weeks in calendar year
    ,[DaysInMonth]                      tinyint         -- Number of days in month
    ,[DaysInCalendarQuarter]            tinyint         -- Number of days in calendar quarter
    ,[DaysInCalendarTrimester]          tinyint         -- Number of days in calendar trimester
    ,[DaysInCalendarSemester]           tinyint         -- Number of days in calendar semester
    ,[DaysInFiscalYear]                 smallint        -- Number of days in fiscal year
    ,[WeeksInFiscalYear]                tinyint         -- Number of weeks in fiscal year
    ,[DaysInFiscalMonth]                tinyint         -- Number of days in fiscal month
    ,[WeeksInFiscalMonth]               tinyint         -- Number of weeks in fiscal month
    ,[DaysInFiscalQuarter]              tinyint         -- Number of days in fiscal quarter
    ,[WeeksInFiscalQuarter]             tinyint         -- Number of week sin fiscal quarter
    ,[DaysInFiscalSemester]             tinyint         -- Number of days in fiscal semester
    ,[WeeksInFiscalSemester]            tinyint         -- Number of weeks in fiscal semester
    ,[IsLeapYear]                       bit             -- Identifies whether the year of current day is leap year
    ,[IsFirstDayOfWeek]                 bit             -- Identifies whether current day is first day of week
    ,[IsLastDayOfWeek]                  bit             -- Identifies whether current day is last day of week
    ,[IsFirstDayOfCalendarMonth]        bit             -- Identifies whether current day is first day of calendar month
    ,[IsLastDayOfCalendarMonth]         bit             -- Identifies whether current day is last day of calendar month
    ,[IsFirstDayOfCalendarQuarter]      bit             -- Identifies whether current day is first day of calendar quarter
    ,[IsLastDayOfCalendarQuarter]       bit             -- Identifies whether current day is last day of calendar quarter
    ,[IsFirstDayOfCalendarTrimester]    bit             -- Identifies whether current day is first day of calendar trimester
    ,[IsLastDayOfCalendarTrimester]     bit             -- Identifies whether current day is last day of calendar trimester
    ,[IsFirstDayOfCalendarSemester]     bit             -- Identifies whether current day is first day of calendar semester
    ,[IsLastDayOfCalendarSemester]      bit             -- Identifies whether current day is last day of calendar semester
    ,[IsFirstDayOfCalendarYear]         bit             -- Identifies whether current day is first  day of calendar year
    ,[IsLastDayOfCalendarYear]          bit             -- Identifies whether current day is last day of calendar year
    ,[IsFirstDayOfFiscalMonth]          bit             -- Identifies whether current day is first day of fiscal month
    ,[IsLastDayOfFiscalMonth]           bit             -- Identifies whether current day is last day of fiscal month
    ,[IsFirstDayOfFiscalQuarter]        bit             -- Identifies whether current day is fist day of fiscal quarter
    ,[IsLastDayOfFiscalQuarter]         bit             -- Identifies whether current day is last day of fiscal quarter
    ,[IsFirstDayOfFiscalSemester]       bit             -- Identifies whether current day is first day of fiscal semester
    ,[IsLastDayOfFiscalSemester]        bit             -- Identifies whether current day is last day of fiscal semester
    ,[IsFirstDayOfFiscalYear]           bit             -- Identifies whether current day is first day of fiscal year
    ,[IsFirstDayOfFiscalYear]           bit             -- Identifies whether current day is last day of fiscal year
    ,PRIMARY KEY CLUSTERED ([DateKey])
)

Usage:
------

SELECT
     [DateKey]                          -- Unique date key in format yyyyMMdd                      
    ,[Date]                             -- Date
    ,[DateSequenceNumber]               -- Number of days since 1900-01-01
    ,[DateName]                         -- Date as string
    ,[DayOfWeek]                        -- Week day number
    ,[DayOfWeekName]                    -- Name of the week day
    ,[DayOccurenceInMonth]              -- Occurence of a week day in Month
    ,[CalendarYear]                     -- Calendar year
    ,[CalendarYearName]                 -- Calendar year as string
    ,[StartOfCalendarYear]              -- Date representing start of calendar year
    ,[EndOfCalendarYear]                -- Date representing end of calendary year
    ,[FirstDayOfYear]                   -- First day of calendary year 1 = Monday - 7 = Sunday
    ,[FirstDayOfYearName]               -- Name of the first day of calendar year
    ,[DayOfYear]                        -- Day number in year
    ,[FiscalYear]                       -- Fiscal year
    ,[FiscalYearName]                   -- Fiscal year as string
    ,[DayOfFiscalYear]                  -- Day number in fiscal year
    ,[StartOfFiscalYear]                -- Date representing start of fiscal year
    ,[EndOfFiscalYear]                  -- Date representing end of fiscal year
    ,[Month]                            -- Unique identification of year in format yyyyMM
    ,[MonthName]                        -- Unique month name
    ,[MonthOfYear]                      -- Month number within year
    ,[MonthOfYearName]                  -- Month name
    ,[StartOfMonth]                     -- Date representing start of month
    ,[EndOfMonth]                       -- Date representing end of month
    ,[MonthSequenceNumber]              -- Number of months since 1900-01-01
    ,[MonthOfQuarter]                   -- Month number within quarter
    ,[MonthOfTrimester]                 -- Month number within trimestar
    ,[MonthOfSemester]                  -- Month number within semester
    ,[DayOfMonth]                       -- Day of month
    ,[DayOfMonthName]                   -- Name of the day of month
    ,[MonthDay]                         -- Unique identification of day within calendar months in format MMdd.
    ,[CalendarQuarter]                  -- Unique identification of calendar quarter in format yyyyQ
    ,[CalendarQuarterName]              -- Calendar quarter as unique string
    ,[StartOfCalendarQuarter]           -- Date representing start of calendar quarter
    ,[EndOfCalendarQuarter]             -- Date representing end of calendar quarter
    ,[CalendarquarterSequenceNumber]    -- Number of calendar quarters since 1900-01-01
    ,[QuarterOfCalendarYear]            -- Quarter number within calendar year
    ,[QuarterOfCalendarYearName]        -- Quarter withing calendar year as string
    ,[CalendarTrimester]                -- Unique identification of calendar trimester in format yyyyT
    ,[CalendarTrimesterName]            -- Calendar trimester as unique string
    ,[CalendarTrimesterSequenceNumber]  -- Number of calendar trimesters since 1900-01-01 
    ,[TrimesterOfCalendarYear]          -- Trimester number within calendar year
    ,[TrimesterOfCalendarYearName]      -- Trimestar withing calendar year as string
    ,[CalendarSemester]                 -- Unique identification of calendar semester in format yyyyS
    ,[CalendarSemesterName]             -- Calendar Semester as unique string
    ,[StartOfCalendarSemester]          -- Date representing start of calendar semester
    ,[EndOfCalendarSemester]            -- Date representing end of calendar semester
    ,[CalendarSemesterSequenceNumber]   -- Number of calendar semesters since 1900-01-01
    ,[SemesterOfCalendarYear]           -- Number of semester within calendar year
    ,[SemesterOfCalendarYearName]       -- Semester within calendar year as string
    ,[StartOfFirstCalendarWeek]         -- Date of the First Day of the First Calendar Week
    ,[EndOfLastCalendarWeek]            -- Date of the Last Day of the Last Calendar Week
    ,[CalendarWeek]                     -- Unique identifrication of calendar week in format yyyyww
    ,[CalendarWeekName]                 -- Calendar week as unique string
    ,[StartOfWeek]                      -- Start of calendar week
    ,[EndOfWeek]                        -- End of calendar week
    ,[CalendarWeekSequenceNumber]       -- Number of weeks since 1900-01-01
    ,[WeekOfCalendarYear]               -- Week number within calendar year
    ,[WeekOfCalendarYearName]           -- Week within calendar year as string
    ,[ISOWeek]                          -- Unique identification of ISO Week
    ,[ISOWeekName]                      -- ISO Week as unique string
    ,[ISOWeekSequenceNumber]            -- Number of ISO weeks since 1900-01-01
    ,[ISOWeekOfCalendarYear]            -- Number of ISO week within calendar year
    ,[ISOWeekOfCalendarYearName]        -- ISO week within calendar year as string
    ,[YearOfISOWeek]                    -- Year of ISO Week (For first week it can be previous year and for last week it can be next year)
    ,[StartOfYearOfISOWeek]             -- Date representing start of ISO year (First day of first ISO Week)
    ,[EndOfYearOfISOWeek]               -- Date representing end of ISO year (Last day of last ISO Week)
    ,[FiscalWeek]                       -- Unique idntification of fiscal week in format yyyyww
    ,[FiscalWeekName]                   -- Week of Fiscal year as unique string
    ,[StartOfFiscalWeek]                -- Date representing start of fiscal week
    ,[EndOfFiscalWeek]                  -- Date representing end of fiscal week
    ,[WeekOfFiscalYear]                 -- Number of week within fiscal year
    ,[WeekOfFiscalYearName]             -- Week within fiscal year as string
    ,[WeekOfFiscalSemester]             -- Week number within fiscal semester
    ,[WeekOfFiscalQuarter]              -- Week number within within fiscal quarter
    ,[FiscalMonth]                      -- Unique identification of fiscal month in format yyyyMM
    ,[FiscalMonthName]                  -- Fiscal month as unique string
    ,[StartOfFiscalMonth]               -- Date representing start of fiscal month
    ,[EndOfFiscalMonth]                 -- Date representing end of fiscal month
    ,[MonthOfFiscalYear]                -- Month number within fiscal year
    ,[MonthOfFiscalYearName]            -- Month within fiscal year as string
    ,[MonthOfFiscalSemester]            -- Month number withinfiscal semester
    ,[MonthOfFiscalQuarter]             -- Month number within fiscal quarter
    ,[FiscalQuarter]                    -- Unique identification of fiscal quarter in format yyyyQ
    ,[FiscalQuarterName]                -- Fiscal quarter as unique string
    ,[StartOfFiscalQuarter]             -- Date representing start of fiscal quarter
    ,[EndOfFiscalQuarter]               -- Date representing end of fiscal quarter
    ,[QuarterOfFiscalYear]              -- Quarter number within fiscal year
    ,[QuarterOfFiscalYearName]          -- Quarter within fiscal year as string
    ,[QuarterOfFiscalSemester]          -- Quarter number within fiscal semester
    ,[FiscalSemester]                   -- Unique identification of fiscal semester in format yyyyS
    ,[FiscalSemesterName]               -- Fiscal semester as unique string
    ,[StartOfFiscalSemester]            -- Date representing start of fiscal semester
    ,[EndOfFiscalSemester]              -- Date representing end of fiscal semester
    ,[SemesterOfFiscalYear]             -- Semester number within fiscal year
    ,[SemesterOfFiscalYearName]         -- Semester within fiscal year as string
    ,[IsLastOccurenceOfDayInMonth]      -- Identifies whether the current day is last occurence of a week day in Month
    ,[IsWeekDay]                        -- Identifies whether the day is a week day
    ,[IsWeekend]                        -- Identifies whether the day is weekend
    ,[IsHoliday]                        -- Identifies whether the day is holiday
    ,[HolidayName]                      -- Name of the holiday
    ,[IsWorkingDay]                     -- Identifies whether the day is Working day = IsWeekDay and is not Holiday
    ,[DayTypeName]                      -- Working/Non Working day as string
    ,[HolidayDayTypeName]               -- Working/Non Working/Holiday as string
    ,[DaysInCalendarYear]               -- Number of days in calendar year
    ,[ISOWeeksInCalendarYear]           -- Number of ISO weeks in calendar year
    ,[DaysInMonth]                      -- Number of days in month
    ,[DaysInCalendarQuarter]            -- Number of days in calendar quarter
    ,[DaysInCalendarTrimester]          -- Number of days in calendar trimester
    ,[DaysInCalendarSemester]           -- Number of days in calendar semester
    ,[DaysInFiscalYear]                 -- Number of days in fiscal year
    ,[WeeksInFiscalYear]                -- Number of weeks in fiscal year
    ,[DaysInFiscalMonth]                -- Number of days in fiscal month
    ,[WeeksInFiscalMonth]               -- Number of weeks in fiscal month
    ,[DaysInFiscalQuarter]              -- Number of days in fiscal quarter
    ,[WeeksInFiscalQuarter]             -- Number of week sin fiscal quarter
    ,[DaysInFiscalSemester]             -- Number of days in fiscal semester
    ,[WeeksInFiscalSemester]            -- Number of weeks in fiscal semester
    ,[IsLeapYear]                       -- Identifies whether the year of current day is leap year
    ,[IsFirstDayOfWeek]                -- Identifies whether current day is first day of week
    ,[IsLastDayOfWeek]                 -- Identifies whether current day is last day of week
    ,[IsFirstDayOfCalendarMonth]       -- Identifies whether current day is first day of calendar month
    ,[IsLastDayOfCalendarMonth]        -- Identifies whether current day is last day of calendar month
    ,[IsFirstDayOfCalendarQuarter]     -- Identifies whether current day is first day of calendar quarter
    ,[IsLastDayOfCalendarQuarter]      -- Identifies whether current day is last day of calendar quarter
    ,[IsFirstDayOfCalendarTrimester]   -- Identifies whether current day is first day of calendar trimester
    ,[IsLastDayOfCalendarTrimester]    -- Identifies whether current day is last day of calendar trimester
    ,[IsFirstDayOfCalendarSemester]    -- Identifies whether current day is first day of calendar semester
    ,[IsLastDayOfCalendarSemester]     -- Identifies whether current day is last day of calendar semester
    ,[IsFirstDayOfCalendarYear]        -- Identifies whether current day is first  day of calendar year
    ,[IsLastDayOfCalendarYear]         -- Identifies whether current day is last day of calendar year
    ,[IsFirstDayOfFiscalMonth]         -- Identifies whether current day is first day of fiscal month
    ,[IsLastDayOfFiscalMonth]          -- Identifies whether current day is last day of fiscal month
    ,[IsFirstDayOfFiscalQuarter]       -- Identifies whether current day is fist day of fiscal quarter
    ,[IsLastDayOfFiscalQuarter]        -- Identifies whether current day is last day of fiscal quarter
    ,[IsFirstDayOfFiscalSemester]      -- Identifies whether current day is first day of fiscal semester
    ,[IsLastDayOfFiscalSemester]       -- Identifies whether current day is last day of fiscal semester
    ,[IsFirstDayOfFiscalYear]          -- Identifies whether current day is first day of fiscal year
FROM dbo.fn_DateTable(
     /*                           @startDate*/ '20120101'
    ,/*                             @endDate*/ '20151231'
    ,/*                             @culture*/ 'en-US'
    ,/*                      @firstDayOfWeek*/ DEFAULT
    ,/*                   @calendarFirstWeek*/ DEFAULT
    ,/*               @fiscalQuarterWeekType*/ DEFAULT
    ,/*                 @lastDayOfFiscalYear*/ DEFAULT
    ,/*             @lastDayOfFiscalYearType*/ DEFAULT
    ,/*                @fiscalYearStartMonth*/ DEFAULT
    ,/*                @dateNameFormatString*/ DEFAULT
    ,/*                @yearNameFormatString*/ DEFAULT
    ,/*          @fiscalYearNameFormatString*/ DEFAULT
    ,/*               @monthNameFormatString*/ DEFAULT
    ,/*         @monthOfYearNameFormatString*/ DEFAULT
    ,/*            @monthDayNameFormatString*/ DEFAULT
    ,/*          @weekNamePrefixFormatString*/ DEFAULT
    ,/*                @weekNameFormatString*/ DEFAULT
    ,/*          @weekNameSuffixFormatString*/ DEFAULT
    ,/*       @quarterNamePrefixFormatString*/ DEFAULT
    ,/*             @quarterNameFormatString*/ DEFAULT
    ,/*       @quarterNameSuffixFormatString*/ DEFAULT
    ,/*      @semesterNamePrefixFormatString*/ DEFAULT
    ,/*            @semesterNameFormatString*/ DEFAULT
    ,/*      @semesterNameSuffixFormatString*/ DEFAULT
    ,/*     @trimesterNamePrefixFormatString*/ DEFAULT
    ,/*           @trimesterNameFormatString*/ DEFAULT
    ,/*     @trimesterNameSuffixFormatString*/ DEFAULT
    ,/*    @fiscalWeekNamePrefixFormatString*/ DEFAULT
    ,/*          @fiscalWeekNameFormatString*/ DEFAULT
    ,/*    @fiscalWeekNameSuffixFormatString*/ DEFAULT
    ,/*   @fiscalMonthNamePrefixFormatString*/ DEFAULT
    ,/*         @fiscalMonthNameFormatString*/ DEFAULT
    ,/*   @fiscalMonthNameSuffixFormatString*/ DEFAULT
    ,/* @fiscalQuarterNamePrefixFormatString*/ DEFAULT
    ,/*       @fiscalQuarterNameFormatString*/ DEFAULT
    ,/* @fiscalQuarterNameSuffixFormatString*/ DEFAULT
    ,/*@fiscalSemesterNamePrefixFormatString*/ DEFAULT
    ,/*      @fiscalSemesterNameFormatString*/ DEFAULT
    ,/*@fiscalSemesterNameSuffixFormatString*/ DEFAULT
    ,/*            @dayOfWeeknameFormatSring*/ DEFAULT
    ,/*                         @workingDays*/ DEFAULT
    ,/*                  @workingDayTypeName*/ DEFAULT
    ,/*               @nonWorkingDayTypeName*/ DEFAULT
    ,/*                  @holidayDayTypeName*/ DEFAULT
    ,/*                            @holidays*/ DEFAULT
)



To provide multiple translations of the names, you can INNER JOIN two calls with different cultures as in example below.

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
    ,DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) EN
INNER JOIN dbo.fn_DateTable(
      '20120101'
     ,'20151231'
     ,'es-ES'   --Spanish (Spain)
  ,DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT
  ,DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT
  ,DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT
  ,DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT) CN ON CN.DateKey = EN.DateKey

**************************************************** */
ALTER FUNCTION [dbo].[fn_DateTable] (
     @startDate                                 date                                    -- Start date of the sequence to Generate
	,@endDate                                   date                                    -- End date of the sequence to Generate

    ,@culture                                   nvarchar(10)    = N'en-US'              -- Culture to be used for names generation

    ,@firstDayOfWeek                            tinyint         = 1                     -- First Day Of Week. 1 = Monday - 7 = Sunday
    ,@calendarFirstWeek                         tinyint         = 2                     -- 1 = Starts on 1. January, 2 = First 4 days week, 3 = First Full Week.
    ,@fiscalQuarterWeekType                     smallint        = 445                   -- Type of Fiscal Quarter Week Types. Supported 445, 454, 544 (Specifies how the 13 weeks quarters are distributed among weeks)
    ,@lastDayOfFiscalYear                       tinyint         = 7                     -- Last Day of Fiscal Year. 1 = Monday - 7 = Sunday
    ,@lastDayOfFiscalYearType                   tinyint         = 1                     -- Specifies how the last day of fiscal yer is determined. 1 = Last @lastDayOfFiscalYear in the fiscal year end month. 2 = @lastDayOfFiscalYear closes to the fiscal year end month
    ,@fiscalYearStartMonth                      tinyint         = 9                     -- Specifies the Month at which the Fiscal year Starts


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

    ,@workingDays                               char(7)         = '1111100'             -- "Bitmask of working days where left most is Monday and RightMost is Sunday: MTWTFSS. Working Days are considered Week Days, Non Working days are considered Weekend
    ,@workingDayTypeName                        nvarchar(30)    = 'Working day'         -- Name for the working days - String representing working days
    ,@nonWorkingDayTypeName                     nvarchar(30)    = 'Non-working day'     -- Name for the non-working days - String representing non-working days
    ,@holidayDayTypeName                        nvarchar(30)    = 'Holiday'             -- Name for the Holiday day type - String representing holidays
    ,@holidays                                  varchar(max)    = ''                    -- Comma Separated list of holidays. Holidays can be specified in the MMdd or yyyyMMdd. '0101:New Year,0704,20200413' 
                                                                                        -- Holiday without yyyy part is repeating every year. Optional Holiday name can be specified after colon as in example above the "New Year"
)
RETURNS TABLE
AS
RETURN (
   WITH NumTable AS (  --Numbers Table
	    SELECT N FROM(VALUES (1), (1), (1), (1), (1), (1), (1), (1), (1), (1)) T(N)
    ),
    HolidaysBase AS (   --Convert the holidays comma separated list to XML for further CSV split
        SELECT 
            NULLIF(HT.H.value(N'./i[1]', N'int'), 0)            AS H
            ,NULLIF(HT.H.value(N'./i[2]', N'nvarchar(50)'), '')  AS HName
        FROM (SELECT CONVERT(xml, '<holiday><i>'+ REPLACE(REPLACE(@holidays, ',', '</i></holiday><holiday><i>'), ':', '</i><i>') + '</i></holiday>') HB) T(HB)
        CROSS APPLY HB.nodes(N'holiday') HT(H)
    ), 
    YearsTable AS (
        SELECT TOP(YEAR(@endDate) - YEAR(@startDate) + 1)
            YEAR(@startDate) +  ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 1 AS [Year]
        FROM 
            NumTable N10
           ,NumTable N100
           ,NumTable N1000
           ,NumTable N10000
    )
    , HolidaysTable AS (
        SELECT
            CONVERT(date, CONVERT(char(10), YT.[Year] * 10000 + HB.H % 10000), 112) AS [HolidayDate]
            ,CONVERT(bit, 1)                                                        AS [IsHoliday]
            ,HB.HName                                                               AS [HolidayName]
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
	    SELECT TOP (DATEDIFF(DAY, @startDate, @endDate) + 1)  --Take only TOP values which equeals to the difference between end and starting date
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
        YEAR(@startDate) +  CONVERT(int, ROW_NUMBER() OVER(ORDER BY (SELECT NULL))) - 1 AS FiscalYear
        ,DATEADD(DAY, @lastDayOfFiscalYear - 1, DATEADD(WEEK, DATEDIFF(WEEK, 0, DATEADD(MONTH, @fiscalYearStartMonth - 1, DATEADD(YEAR, DATEDIFF(YEAR, 0, @startDate) + ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 1 , 0))) - 1, 0)) FiscalYearEndCore
        ,DATEADD(DAY, @lastDayOfFiscalYear - 1, DATEADD(WEEK, DATEDIFF(WEEK, 0, DATEADD(MONTH, @fiscalYearStartMonth - 1, DATEADD(YEAR, DATEDIFF(YEAR, 0, @startDate) + ROW_NUMBER() OVER(ORDER BY (SELECT NULL)) - 2 , 0))) - 1, 0)) PrevFiscalYearEndCore
    FROM 
        NumTable N10
       ,NumTable N100
       ,NumTable N1000
       ,NumTable N10000
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
            YEAR([Date]) * 10000 + MONTH([Date]) * 100 + DAY([Date])                                                                AS [DateKey]
            ,[Date]													                                                                AS [Date]
            
            ,YEAR([Date])                                                                                                           AS [CalendarYear]
            ,YEAR([Date]) - 1                                                                                                       AS [PreviousCalendarYear]
            ,CONVERT(date, DATEADD(YEAR, DATEDIFF(YEAR, 0, [Date]), 0))                                                             AS [StartOfCalendarYear]
            ,CONVERT(date, DATEADD(YEAR, DATEDIFF(YEAR, 0, [Date]) + 1, 0))                                                         AS [StartOfNextCalendarYear]
            ,CONVERT(date, DATEADD(YEAR, DATEDIFF(YEAR, 0, [Date]) - 1, 0))                                                         AS [StartOfPreviousCalendarYear]
            ,CONVERT(bit,ABS(MONTH(DATEADD(DAY, 59, CONVERT(date, DATEADD(YEAR, DATEDIFF(YEAR, 0, [Date]), 0)))) - 3))              AS [IsLeapYear]
            ,CONVERT(date, DATEADD(DAY, -1, DATEADD(YEAR, DATEDIFF(YEAR, 0, [Date]) + 1, 0)))                                       AS [EndOfCalendarYear]

            ,YEAR(DATEADD(day, 26 - DATEPART(ISO_WEEK, [Date]), [Date]))                                                            AS [YearOfISOWeek]
            ,CONVERT(date, DATEADD(YEAR, YEAR(DATEADD(day, 26 - DATEPART(ISO_WEEK, [Date]), [Date])) - 1900, 0))                    AS [YearOfISOWeekDate]

            ,FY.[FiscalYear]                                                                                                        AS [FiscalYear]
            ,FY.[StartOfFiscalYear]                                                                                                 AS [StartOfFiscalYear]
            ,FY.[EndOfFiscalYear]                                                                                                   AS [EndOfFiscalYear]


            ,CONVERT(tinyint, DAY([Date]))                                                                                          AS [DayOfMonth]
            ,CONVERT(tinyint, (DAY([Date]) - 1) / 7 + 1)                                                                            AS [DayOccurenceInMonth]
            ,CONVERT(bit, CASE WHEN MONTH(DATEADD(DAY, 7, [Date])) <> MONTH([Date]) THEN 1 ELSE 0 END)                              AS [IsLastOccurenceOfDayInMonth]
            ,CONVERT(smallint, DATEPART(DAYOFYEAR, [date]))                                                                         AS [DayOfYear]

            ,YEAR([Date]) * 100 + MONTH([Date])                                                                                     AS [Month]
            ,CONVERT(tinyint, MONTH([Date]))                                                                                        AS [MonthOfYear]
            ,DATEDIFF(MONTH, 0, [Date]) + 1                                                                                         AS [MonthSequenceNumber]

            ,CONVERT(smallint, MONTH([Date]) * 100 + DAY([Date]))                                                                   AS [MonthDay]
            
            ,CONVERT(date, DATEADD(WEEK, DATEDIFF(DAY, @firstDayOfWeek - 8, [Date]) / 7, @firstDayOfWeek - 8))                      AS [StartOfWeek]
            ,CONVERT(date, DATEADD(WEEK, DATEDIFF(DAY, @firstDayOfWeek - 8, [Date]) / 7 + 1, @firstDayOfWeek - 9))                  AS [EndOfWeek]

            ,CONVERT(date, DATEADD(MONTH, DATEDIFF(MONTH, 0, [Date]), 0))                                                           AS [StartOfMonth]
            ,CONVERT(date, DATEADD(DAY, -1, DATEADD(MONTH, DATEDIFF(MONTH, 0, [Date]) + 1, 0)))                                     AS [EndOfMonth]

            ,YEAR([Date]) * 10 + DATEPART(QUARTER, [Date])                                                                          AS [CalendarQuarter]
            ,CONVERT(tinyint, DATEPART(QUARTER, [Date]))                                                                            AS [QuarterOfCalendarYear]
            ,DATEDIFF(QUARTER, 0, [Date]) + 1                                                                                       AS [CalendarquarterSequenceNumber]

            ,YEAR([Date]) * 10 + CONVERT(tinyint, (MONTH([Date]) - 1) / 4 + 1)                                                      AS [CalendarTrimester]
            ,CONVERT(tinyint, (MONTH([Date]) - 1) / 4 + 1)                                                                          AS [TrimesterOfCalendarYear]

            ,YEAR([Date]) * 10 + CONVERT(tinyint, (MONTH([Date]) - 1) / 6 + 1)                                                      AS [CalendarSemester]
            ,CONVERT(tinyint, (MONTH([Date]) - 1) / 6 + 1)                                                                          AS [SemesterOfCalendarYear]

            ,YEAR(DATEADD(day, 26 - DATEPART(ISO_WEEK, [Date]), [Date])) * 100 + DATEPART(ISO_WEEK, [Date])                         AS [ISOWeek]
            ,CONVERT(tinyint, DATEPART(ISO_WEEK, [Date]))                                                                           AS [ISOWeekOfCalendarYear]
            ,DATEDIFF(DAY, 0, [Date]) / 7 + 1                                                                                       AS [ISOWeekSequenceNumber]

            ,CONVERT(tinyint, DATEDIFF(DAY, @firstDayOfWeek - 8, [Date]) % 7 + 1)                                                   AS [DayOfWeek]
            ,CONVERT(tinyint, DATEDIFF(DAY, 0, [Date]) % 7 + 1)                                                                     AS [DayOfWeekFixedMonday]
            
            ,CONVERT(tinyint, DATEDIFF(DAY, 0, DATEADD(YEAR, DATEDIFF(YEAR, 0, [Date]), 0)) % 7 + 1)                                AS [FirstDayOfYear]
            ,CONVERT(tinyint, DATEDIFF(DAY, 0, DATEADD(YEAR, DATEDIFF(YEAR, 0, [Date]) + 1, 0)) % 7 + 1)                            AS [FirstDayOfNextYear]

            ,ISNULL(HT.IsHoliday, 0)                                                                                                AS [IsHoliday]
            ,HT.[HolidayName]                                                                                                       AS [HolidayName]
            ,CASE WHEN @fiscalQuarterWeekType IN (445,454,544) THEN @fiscalQuarterWeekType ELSE 1/0 END                             AS [FiscalQuarterWeekType]

        FROM [Dates] D
        INNER JOIN [FiscalYears] FY ON D.[Date] BETWEEN FY.[StartOfFiscalYear] AND FY.[EndOfFiscalYear]
        LEFT JOIN HolidaysTable HT ON D.[Date] = HT.[HolidayDate]
    ),
    CalendarDateTableBase2 AS (
        SELECT
            D.*
            ,CONVERT(date, DATEADD(WEEK, DATEDIFF(DAY, @firstDayOfWeek - 1 + 7 * SIGN(1 - @firstDayOfWeek), 
                CONVERT(date, D.StartOfCalendarYear )) / 7, 
                @firstDayOfWeek - 1 + 7 * SIGN(1 - @firstDayOfWeek)))                                                                   AS [StartOfFirstCalendarWeek]

            ,CONVERT(date, DATEADD(DAY, -1, DATEADD(WEEK, DATEDIFF(DAY, @firstDayOfWeek - 1 + 7 * SIGN(1 - @firstDayOfWeek), 
                CONVERT(date, D.EndOfCalendarYear )) / 7 + 1, 
                @firstDayOfWeek - 1 + 7 * SIGN(1 - @firstDayOfWeek))))                                                                  AS [EndOfLastCalendarWeek]


            ,DATEDIFF(DAY, @firstDayOfWeek - 1 + 7 * SIGN(1 - @firstDayOfWeek), [Date]) / 7 + 1                                         AS [CalendarWeekSequenceNumber]
            ,CONVERT(tinyint, (D.[MonthOfYear] - 1) % 3 + 1)                                                                            AS [MonthOfQuarter]
            ,CONVERT(tinyint, (D.[MonthOfYear] - 1) % 4 + 1)                                                                            AS [MonthOfTrimester]
            ,CONVERT(tinyint, (D.[MonthOfYear]- 1) % 6 + 1)                                                                             AS [MonthOfSemester]
            ,DATEADD(MONTH, ([QuarterOfCalendarYear] - 1) * 3, D.[StartOfCalendarYear])                                                 AS [StartOfCalendarQuarter]
            ,DATEADD(DAY, -1, DATEADD(MONTH, ([QuarterOfCalendarYear]) * 3, D.[StartOfCalendarYear]))                                   AS [EndOfCalendarQuarter]
            ,DATEADD(MONTH, ([TrimesterOfCalendarYear] - 1) * 4, D.[StartOfCalendarYear])                                               AS [StartOfCalendarTrimester]
            ,DATEADD(DAY, -1, DATEADD(MONTH, ([TrimesterOfCalendarYear]) * 4, D.[StartOfCalendarYear]))                                 AS [EndOfCalendarTrimester]
            ,(D.[MonthSequenceNumber] - 1) / 4 + 1                                                                                      AS [CalendarTrimesterSequenceNumber]
            ,DATEADD(MONTH, ([SemesterOfCalendarYear] - 1) * 6, D.[StartOfCalendarYear])                                                AS [StartOfCalendarSemester]
            ,DATEADD(DAY, -1, DATEADD(MONTH, ([SemesterOfCalendarYear]) * 6, D.[StartOfCalendarYear]))                                  AS [EndOfCalendarSemester]
        
            ,(D.[MonthSequenceNumber] - 1) / 6 + 1                                                                                      AS [CalendarSemesterSequenceNumber]

            ,CONVERT(date, 
                DATEADD(WEEK, DATEDIFF(WEEK, 0, D.[StartOfCalendarYear]) + CASE WHEN D.FirstDayOfYear <= 4 THEN 0 ELSE 1 END, 0))       AS [StartOfYearOfISOWeek]

            ,CONVERT(date, 
                DATEADD(DAY, -1, DATEADD(WEEK, 
                    DATEDIFF(WEEK, 0, D.[StartOfNextCalendarYear]) + CASE WHEN D.[FirstDayOfNextYear] <= 4 THEN 0 ELSE 1 END, 0)
                )
            )                                                                                                                           AS [EndOfYearOfISOWeek]

        FROM CalendarDateTableBase1 D
    ), 
    CalendarDateTableBase3 AS(        
        SELECT
            D.*
            ,DATEDIFF(DAY, [StartOfFirstCalendarWeek], D.[Date]) / 7 + 1                                                                AS [WeekOfCalendarYear]
        FROM CalendarDateTableBase2 D
    ),
    [CalendarDateTable] AS (
        SELECT
            D.*
            ,D.[CalendarYear] * 100 + [WeekOfCalendarYear]                                                                              AS [CalendarWeek]
            ,DATEDIFF(DAY, [StartOfCalendarYear], [EndOfCalendarYear]) + 1                                                              AS [DaysInCalendarYear]
            ,CONVERT(tinyint, DATEDIFF(DAY, D.StartOfMonth, D.EndOfMonth) + 1)                                                          AS [DaysInMonth]
            ,CONVERT(tinyint, DATEDIFF(DAY, D.StartOfCalendarQuarter, D.EndOfCalendarQuarter) + 1)                                      AS [DaysInCalendarQuarter]
            ,CONVERT(tinyint, DATEDIFF(DAY, D.StartOfCalendarTrimester, D.EndOfCalendarTrimester) + 1)                                  AS [DaysInCalendarTrimester]
            ,CONVERT(tinyint, DATEDIFF(DAY, D.StartOfCalendarSemester, D.EndOfCalendarSemester)  + 1)                                   AS [DaysInCalendarSemester]
            ,CONVERT(tinyint, DATEPART(ISO_WEEK, DATEADD(DAY, -3, [EndOfCalendarYear]))) /*December 28 is always in last ISO week*/     AS [ISOWeeksInCalendarYear]
                    

            ,CONVERT(bit, CASE WHEN D.[Date] = D.StartOfWeek THEN 1 ELSE 0 END)                                                         AS [IsFirstDayOfWeek]
            ,CONVERT(bit, CASE WHEN D.[Date] = D.EndOfWeek THEN 1 ELSE 0 END)                                                           AS [IsLastDayOfWeek]
            ,CONVERT(bit, CASE WHEN D.[Date] = D.StartOfMonth THEN 1 ELSE 0 END)                                                        AS [IsFirstDayOfCalendarMonth]
            ,CONVERT(bit, CASE WHEN D.[Date] = D.EndOfMonth THEN 1 ELSE 0 END)                                                          AS [IsLastDayOfCalendarMonth]
            ,CONVERT(bit, CASE WHEN D.[Date] = D.StartOfCalendarQuarter THEN 1 ELSE 0 END)                                              AS [IsFirstDayOfCalendarQuarter]
            ,CONVERT(bit, CASE WHEN D.[Date] = D.EndOfCalendarQuarter THEN 1 ELSE 0 END)                                                AS [IsLastDayOfCalendarQuarter]
            ,CONVERT(bit, CASE WHEN D.[Date] = D.StartOfCalendarTrimester THEN 1 ELSE 0 END)                                            AS [IsFirstDayOfCalendarTrimester]
            ,CONVERT(bit, CASE WHEN D.[Date] = D.EndOfCalendarTrimester THEN 1 ELSE 0 END)                                              AS [IsLastDayOfCalendarTrimester]
            ,CONVERT(bit, CASE WHEN D.[Date] = D.StartOfCalendarSemester THEN 1 ELSE 0 END)                                             AS [IsFirstDayOfCalendarSemester]
            ,CONVERT(bit, CASE WHEN D.[Date] = D.EndOfCalendarSemester THEN 1 ELSE 0 END)                                               AS [IsLastDayOfCalendarSemester]
            ,CONVERT(bit, CASE WHEN D.[Date] = D.StartOfCalendarYear THEN 1 ELSE 0 END)                                                 AS [IsFirstDayOfCalendarYear]
            ,CONVERT(bit, CASE WHEN D.[Date] = D.EndOfCalendarYear THEN 1 ELSE 0 END)                                                   AS [IsLastDayOfCalendarYear]
            ,CONVERT(bit, CASE WHEN D.[Date] = D.[StartOfYearOfISOWeek] THEN 1 ELSE 0 END)                                              AS [IsStartOfYearOfISOWeek]
            ,CONVERT(bit, CASE WHEN D.[Date] = D.[EndOfYearOfISOWeek] THEN 1 ELSE 0 END)                                                AS [IsEndOfYearOfISOWeek]            
        FROM [CalendarDateTableBase3] D
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
            ,CONVERT(tinyint, 
                CASE WHEN D.[WeekOfFiscalYear] > 52 THEN 4 ELSE  D.[WeekOfFiscalYear] / 13 + SIGN(D.[WeekOfFiscalYear] % 13) END)       AS [QuarterOfFiscalYear]

        FROM [FiscalBase1] D
    ),
    [FiscalCalendarBase1] AS (
        SELECT
            D.*
            ,CONVERT(bit, D.[IsWeekDay] ^ 1)                                                                                            AS [IsWeekend]
            ,CONVERT(tinyint, 
                CASE WHEN D.[WeekOfFiscalYear] > 52 THEN 14 ELSE D.[WeekOfFiscalYear] - 13 * (D.[QuarterOfFiscalYear]  - 1) END)        AS [WeekOfFiscalQuarter]
            ,CONVERT(tinyint, (D.[QuarterOfFiscalYear] - 1) / 2 + 1)                                                                    AS [SemesterOfFiscalYear]
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
            ,CONVERT(tinyint, ([QuarterOfFiscalYear] - 1) % 2 + 1)                                                                      AS [QuarterOfFiscalSemester]

            ,DATEADD(WEEK, ([SemesterOfFiscalYear] - 1) * 26, [StartOfFiscalYear])                                                      AS [StartOfFiscalSemester]
            ,CASE
                WHEN D.[SemesterOfFiscalYear] = 2 AND  D.[WeeksInFiscalYear] > 52 THEN [EndOfFiscalYear] 
                ELSE DATEADD(DAY, -1, DATEADD(WEEK, ([SemesterOfFiscalYear]) * 26, [StartOfFiscalYear])) 
             END                                                                                                                        AS [EndOfFiscalSemester]
            ,D.[FiscalYear] * 10 + D.[SemesterOfFiscalYear]                                                                             AS [FiscalSemester]
            ,CONVERT(tinyint, 
                CASE WHEN D.[WeekOfFiscalYear] > 52 THEN 27 ELSE D.[WeekOfFiscalYear] - 26 * (D.[SemesterOfFiscalYear]  - 1) END)       AS [WeekOfFiscalSemester]

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
            ,CONVERT(tinyint, (D.[MonthOfFiscalYear] - 1) % 6 + 1)                                                                      AS [MonthOfFiscalSemester]
            ,CONVERT(tinyint, (D.[MonthOfFiscalYear] - 1) % 3 + 1)                                                                      AS [MonthOfFiscalQuarter]

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

            ,CONVERT(bit, CASE WHEN D.[Date] = D.StartOfFiscalMonth THEN 1 ELSE 0 END)                                                  AS [IsFirstDayOfFiscalMonth]
            ,CONVERT(bit, CASE WHEN D.[Date] = D.EndOfFiscalMonth THEN 1 ELSE 0 END)                                                    AS [IsLastDayOfFiscalMonth]
            ,CONVERT(bit, CASE WHEN D.[Date] = D.StartOfFiscalQuarter THEN 1 ELSE 0 END)                                                AS [IsFirstDayOfFiscalQuarter]
            ,CONVERT(bit, CASE WHEN D.[Date] = D.EndOfFiscalQuarter THEN 1 ELSE 0 END)                                                  AS [IsLastDayOfFiscalQuarter]
            ,CONVERT(bit, CASE WHEN D.[Date] = D.StartOfFiscalSemester THEN 1 ELSE 0 END)                                               AS [IsFirstDayOfFiscalSemester]
            ,CONVERT(bit, CASE WHEN D.[Date] = D.EndOfFiscalSemester THEN 1 ELSE 0 END)                                                 AS [IsLastDayOfFiscalSemester]
            ,CONVERT(bit, CASE WHEN D.[Date] = D.StartOfFiscalYear THEN 1 ELSE 0 END)                                                   AS [IsFirstDayOfFiscalYear]
            ,CONVERT(bit, CASE WHEN D.[Date] = D.EndOfFiscalYear THEN 1 ELSE 0 END)                                                     AS [IsLastDayOfFiscalYear]
        FROM [FiscalCalendarBase3] D
    )
    SELECT                                                                                       
         D.[DateKey]                                                                                                                    AS [DateKey]
        ,D.[Date]                                                                                                                       AS [Date]

        ,DATEDIFF(DAY, 0, [Date]) + 1                                                                                                   AS [DateSequenceNumber] --Number of Days since 1900-01-01
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT([Date], @dateNameFormatString, @culture))))                                           AS [DateName]

        ,D.[DayOfWeek]                                                                                                                  AS [DayOfWeek]
        ,CONVERT(nvarchar(30), FORMAT([Date], @dayOfWeeknameFormatSring, @culture))                                                     AS [DayOfWeekName]
        ,D.[DayOccurenceInMonth]                                                                                                        AS [DayOccurenceInMonth]

        ,D.[CalendarYear]                                                                                                               AS [CalendarYear]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT([Date], @yearNameFormatString, @culture))))                                           AS [CalendarYearName]
        ,D.[StartOfCalendarYear]                                                                                                        AS [StartOfCalendarYear]
        ,D.[EndOfCalendarYear]                                                                                                          AS [EndOfCalendarYear]
        ,D.[FirstDayOfYear]                                                                                                             AS [FirstDayOfYear]
        ,CONVERT(nvarchar(30), FORMAT(DATEADD(YEAR, DATEDIFF(YEAR, 0, D.[Date]), 0), @dayOfWeeknameFormatSring, @culture))              AS [FirstDayOfYearName]
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
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT(D.[Date], @monthDayNameFormatString, @culture))))                                     AS [DayOfMonthName]
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


        ,[StartOfFirstCalendarWeek]
        ,[EndOfLastCalendarWeek]

        ,D.[CalendarWeek]                                                                                                               AS [CalendarWeek]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), 
          ISNULL(FORMAT(D.StartOfCalendarYear, ISNULL(NULLIF(@weekNamePrefixFormatString, N''), N' '), @culture), N'')
         +ISNULL(FORMAT([WeekOfCalendarYear], @weekNameFormatString, @culture), N'')
         +ISNULL(FORMAT(StartOfCalendarYear, ISNULL(NULLIF(@weekNameSuffixFormatString, N''), N' '), @culture), N''))))                 AS [CalendarWeekName]
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
        ,D.[ISOWeekSequenceNumber]                                                                                                      AS [ISOWeekSequenceNumber]
        ,D.[ISOWeekOfCalendarYear]                                                                                                      AS [ISOWeekOfCalendarYear]
        ,LTRIM(RTRIM(CONVERT(nvarchar(30), FORMAT([ISOWeekOfCalendarYear], @weekNameFormatString, @culture))))                          AS [ISOWeekOfCalendarYearName]

        ,D.[YearOfISOWeek]                                                                                                              AS [YearOfISOWeek]
        ,D.[StartOfYearOfISOWeek]                                                                                                       AS [StartOfYearOfISOWeek]
        ,D.[EndOfYearOfISOWeek]                                                                                                         AS [EndOfYearOfISOWeek]

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

        ,D.[IsLastOccurenceOfDayInMonth]                                                                                                AS [IsLastOccurenceOfDayInMonth]
        ,D.IsWeekDay                                                                                                                    AS [IsWeekDay]
        ,D.[IsWeekend]                                                                                                                  AS [IsWeekend]
        ,D.[IsHoliday]                                                                                                                  AS [IsHoliday]
        ,D.[HolidayName]                                                                                                                AS [HolidayName]
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
        ,[ISOWeeksInCalendarYear]                                                                                                       AS [ISOWeeksInCalendarYear]
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

        ,[IsLeapYear]                                                                                                                   AS [IsLeapYear]
        ,[IsFirstDayOfWeek]                                                                                                             AS [IsFirstDayOfWeek]
        ,[IsLastDayOfWeek]                                                                                                              AS [IsLastDayOfWeek]
        ,[IsFirstDayOfCalendarMonth]                                                                                                    AS [IsFirstDayOfCalendarMonth]
        ,[IsLastDayOfCalendarMonth]                                                                                                     AS [IsLastDayOfCalendarMonth]
        ,[IsFirstDayOfCalendarQuarter]                                                                                                  AS [IsFirstDayOfCalendarQuarter]
        ,[IsLastDayOfCalendarQuarter]                                                                                                   AS [IsLastDayOfCalendarQuarter]
        ,[IsFirstDayOfCalendarTrimester]                                                                                                AS [IsFirstDayOfCalendarTrimester]
        ,[IsLastDayOfCalendarTrimester]                                                                                                 AS [IsLastDayOfCalendarTrimester]
        ,[IsFirstDayOfCalendarSemester]                                                                                                 AS [IsFirstDayOfCalendarSemester]
        ,[IsLastDayOfCalendarSemester]                                                                                                  AS [IsLastDayOfCalendarSemester]
        ,[IsFirstDayOfCalendarYear]                                                                                                     AS [IsFirstDayOfCalendarYear]
        ,[IsLastDayOfCalendarYear]                                                                                                      AS [IsLastDayOfCalendarYear]

        ,[IsFirstDayOfFiscalMonth]                                                                                                      AS [IsFirstDayOfFiscalMonth]
        ,[IsLastDayOfFiscalMonth]                                                                                                       AS [IsLastDayOfFiscalMonth]
        ,[IsFirstDayOfFiscalQuarter]                                                                                                    AS [IsFirstDayOfFiscalQuarter]
        ,[IsLastDayOfFiscalQuarter]                                                                                                     AS [IsLastDayOfFiscalQuarter]
        ,[IsFirstDayOfFiscalSemester]                                                                                                   AS [IsFirstDayOfFiscalSemester]
        ,[IsLastDayOfFiscalSemester]                                                                                                    AS [IsLastDayOfFiscalSemester]
        ,[IsFirstDayOfFiscalYear]                                                                                                       AS [IsFirstDayOfFiscalYear]
        ,[IsLastDayOfFiscalYear]                                                                                                        AS [IsLastDayOfFiscalYear]
        ,[IsStartOfYearOfISOWeek]                                                                                                       AS [IsStartOfYearOfISOWeek]
        ,[IsEndOfYearOfISOWeek]                                                                                                         AS [IsEndOfYearOfISOWeek]   



    FROM [FiscalCalendar] D
)
