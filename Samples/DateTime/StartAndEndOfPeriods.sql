/* ****************************************************
SQL Server Samples

(C) 2008 - 2021 Pavel Pawlowski

Feedback: mailto:pavel.pawlowski@hotmail.cz

Description:

Samples calculations of beginning and end of DateTime Periods

**************************************************** */



/* The easiest way to calculate the beginning and/or end of particular period 
   is by using the DATEADD and DATEDIFF function and do the calculations 
   from some known point in time in past

*/


DECLARE
    @date datetime = GETDATE()


SELECT
    @date                                                                   AS [Selected Date]
    ,DATEADD(YEAR, DATEDIFF(YEAR, 0, @date), 0)                             AS [Beginning of Year]              --We count number of years from 0 = 1900-01-01 and add them back to the 0.
                                                                                                                --we receive beginning of the year of selected date
    ,DATEADD(DAY, -1, DATEADD(YEAR, DATEDIFF(YEAR, 0, @date) + 1, 0))       AS [End of Year]                    --We count the beginning of the year, but add 1 additional year and subtract 1 day.
    ,DATEADD(MONTH, DATEDIFF(MONTH, 0, @date), 0)                           AS [Beginning of Month]             --We count the number of months from 0 = 1900-01-010 and add them back to the 0.
                                                                                                                --we receive beginning of the month of selected date
    ,DATEADD(DAY, -1, DATEADD(MONTH, DATEDIFF(MONTH, 0, @date) + 1, 0))     AS [End of Month]                   --We count the beginning of the month but add 1 additional month and subtract 1 day
    ,DATEADD(WEEK, DATEDIFF(WEEK, 0, @date), 0)                             AS [Beginning of Week - Monday]     --We count the number of weeks from 0 = 1900-01-01 and add them back to the 0
                                                                                                                --We receive Monday as beginning of the year as we know 1900-01-01 was Monday
    ,DATEADD(WEEK, DATEDIFF(WEEK, -1, @date), -1)                           AS [Beginning of Week - Sunday]     --We count the number of weeks from -1 = 1899-12-31 and add them back to the -1
                                                                                                                --We receive Sunday as beginning of the year as we know 1-01-01 was Monday
    ,DATEADD(DAY, -1, DATEADD(WEEK, DATEDIFF(WEEK, 0, @date) + 1, 0))       AS [End of Week - Sunday]           --We count the beginning of the week, but add 1 additional week and subtract 1 day.
    ,DATEADD(DAY, -1, DATEADD(WEEK, DATEDIFF(WEEK, -1, @date) + 1, -1))     AS [End of Week - Saturday]         --We count the beginning of the week, but add 1 additional week and subtract 1 day.

SELECT
    @date                                                                   AS [Selected Date]
    ,DATEADD(HOUR, DATEDIFF(HOUR, 0, @date), 0)                             AS [Start of Hour]                  --We count the number of hours from 0 = 1900-01-01 midnight and add them back to 0.
    ,DATEADD(MINUTE, DATEDIFF(MINUTE, 0, @date), 0)                         AS [Start of Minute]                --We count the number of minutes from 0 = 1900-01-01 midnight and add them back to 0.
    ,CONVERT(datetime, CONVERT(datetime2(0), @date))                        AS [Start of Second]                --For seconds the easies is to convert the to datetime2(0) which has zero precison
                                                                                                                --so time is truncated to whole seconds and conver back to original data type. 
                                                                                                                --DATEADD and DATEDIFF would be possible to utilize as well
                                                                                                                --but we we would need to choose a closer starting date (not 0 as it would result in overflow 
                                                                                                                --too much seconds from 1900-01-01)
    ,CONVERT(datetime, CONVERT(datetime2(1), @date))                        AS [Start of Millisecond]           --For seconds the easies is to convert the to datetime2(1) which has millisecond precison and convert back to original data type
