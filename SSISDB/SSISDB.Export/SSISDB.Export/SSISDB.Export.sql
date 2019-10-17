USE [master]
GO
/*
Create Asymmetric Key from the CLR to enable Unsafe assmebly execution
Further we create login based on that asymmetric key to enable creation of unsafe assembly
*/
IF NOT EXISTS(SELECT 1 FROM sys.asymmetric_keys WHERE name = 'SSISDB.Export.dll')
BEGIN
	RAISERROR( N'+ Creating [SSISDB.Export.dll] asymmetric key form SSISDB.Export.dll', 0, 0) WITH NOWAIT;
	CREATE ASYMMETRIC KEY [SSISDB.Export.dll] FROM EXECUTABLE FILE = N'C:\SQLCLR\SSISDB.Export.dll';
END
GO

/*
Create login from the Assembly asymmetric key. Futher we grant unsafe assembly to that login to enable unsafe assembly creation
*/
IF NOT EXISTS(SELECT 1 FROM sys.server_principals WHERE name = 'SSISDB.Export.dll' AND type = 'K')
BEGIN
	RAISERROR( N'+ Creating Login [SSISDB.Export.dll] from asymmetric key [SSISDB.Export.dll]', 0, 0) WITH NOWAIT;
	CREATE LOGIN [SSISDB.Export.dll] FROM ASYMMETRIC KEY [SSISDB.Export.dll];
END
GO

/*
Grant unsafe aseembly to the [SSISDB.Export.dll] login based on the assembly asymmetric key.
This ensures, that we can create an ussafe asembly in the SSISDB database even without setting
database as trustworthy.
*/
RAISERROR( N'+ Granting UNSAFE ASSEMBLY TO [SSISDB.Export.dll]', 0, 0) WITH NOWAIT;
GO
GRANT UNSAFE ASSEMBLY TO [SSISDB.Export.dll];
GO



USE [SSISDB]
GO

IF EXISTS(SELECT 1 FROM sys.assemblies WHERE name = 'SSISDB.Export')
BEGIN
    RAISERROR(N'+Updating [SSISDB.Export] Assembly... 

If the assmebly does not differs form existing one in SSISDB, an exception will follow. 

', 0, 0) WITH NOWAIT;
    ALTER ASSEMBLY [SSISDB.Export]
        DROP FILE ALL

    ALTER ASSEMBLY [SSISDB.Export]
        FROM 'C:\SQLCLR\SSISDB.Export.dll'

    ALTER ASSEMBLY [SSISDB.Export]
        ADD FILE FROM 'C:\SQLCLR\SSISDB.Export.dll'
END
ELSE
BEGIN
    RAISERROR(N'+Creating [SSISDB.Export] Assembly', 0,0) WITH NOWAIT;
    CREATE ASSEMBLY [SSISDB.Export]
    AUTHORIZATION [dbo]
    FROM 'C:\SQLCLR\SSISDB.Export.dll'
    WITH PERMISSION_SET = UNSAFE
END