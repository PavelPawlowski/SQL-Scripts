/* ****************************************************
SQL Server Samples

(C) 2008 - 2021 Pavel Pawlowski

Feedback: mailto:pavel.pawlowski@hotmail.cz

Description:

Samples of Day of week calculations

**************************************************** */


/* Selecting First Day of a Week based on date */

DECLARE @date datetime = GETDATE()

SELECT                   
     DATEADD(WEEK, DATEDIFF(WEEK, 0, GETDATE()), 0) AS [FirstDayOfWeekMonday]  /*Difference in weeks between date and 0 = (1900-01-01 was Monday) for weeks starting Monday*/
    ,DATEADD(WEEK, DATEDIFF(WEEK, -1, GETDATE()), 0) AS [FirstDayOfWeekSunday] /*Difference in weeks between date and -1 = (1899-12-31 was Sunday) for weeks starting Sunday*/
GO



/* 
    Getting Number of a day might be tricky, because it depends on the SET DATEFIRST 

    https://docs.microsoft.com/en-us/sql/t-sql/functions/datepart-transact-sql?view=sql-server-ver15

    If we want to have the week of day independed on the system setting, we can calculate it easily

                 
    DATEDIFF(DAY, @firstDayOfWeek - 8, [WeekDay]) % 7 + 1  AS [WeekDay Independed on DATEFIRST]

    1. We know that 1900-01-01 was Monday
    2. @firsrDayOfWeek we use as starting day. 0 = 1900-01-01. But we are setting it in range 1 - 7 this meens between 1900-01-02 - 1900-01-08
    3. Then we substract 8 from that date. This ensures that for 1 Monday we receive 1899-12-25 (Monday) and for 7 Sunday we receive 1899-12-31 Sunday 
    4. Then we caculate the difference between such caclulated starting day and current date in days: DATEDIFF(DAY, @firstDayOfWeek - 8, [WeekDay])
    5. Then we divide the number by 7 and take the residual (% operator). Residual will be between 0 (monday) - 6 (Sunday): DATEDIFF(DAY, @firstDayOfWeek - 8, [WeekDay]) % 7
    6. We add 1 to that residual to have range from 1 Monday to 7 Sunday: DATEDIFF(DAY, @firstDayOfWeek - 8, [WeekDay]) % 7 + 1

*/


DECLARE
    @firstDayOfWeek tinyint = 1 --Defines the first day of week we want to have  1 = Monday - 7 = Sunday



SET DATEFIRST 7

/*Get dates for current week*/
;WITH CurrentWeek AS (
    SELECT                    
        DATEADD(WEEK, DATEDIFF(WEEK, 0, GETDATE()) + N, 0) AS [WeekDay] /* Utilizes the first example First Day of Week */
    FROM (VALUES (0),(1),(2),(3),(4), (5),(6)) T (N)
)
SELECT
    cw.[WeekDay]
    ,DATEPART(WEEKDAY, cw.[WeekDay])                        AS [WeekDay Depended On DATEFIRST=7] --DATEPART is depended on DATEFIRST
    ,DATEDIFF(DAY, @firstDayOfWeek - 8, [WeekDay]) % 7 + 1  AS [WeekDay Independed on DATEFIRST]
FROM CurrentWeek cw


SET DATEFIRST 1

/*Get dates for current week*/
;WITH CurrentWeek AS (
    SELECT                    
        DATEADD(WEEK, DATEDIFF(WEEK, 0, GETDATE()) + N, 0) AS [WeekDay] /* Utilizes the first example First Day of Week */
    FROM (VALUES (0),(1),(2),(3),(4), (5),(6)) T (N)
)
SELECT
    cw.[WeekDay]
    ,DATEPART(WEEKDAY, cw.[WeekDay])                        AS [WeekDay Depended On DATEFIRST=1]
    ,DATEDIFF(DAY, @firstDayOfWeek - 8, [WeekDay]) % 7 + 1  AS [WeekDay Independed on DATEFIRST]
FROM CurrentWeek cw