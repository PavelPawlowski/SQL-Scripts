USE [SSISDB]
GO
IF NOT EXISTS(SELECT * FROM sys.procedures WHERE object_id = OBJECT_ID('[dbo].[usp_CheckConstraints]'))
    EXEC (N'CREATE PROCEDURE [dbo].[usp_CheckConstraints] AS PRINT ''Placeholder for [dbo].[usp_CheckConstraints]''')
GO
IF NOT EXISTS (SELECT  1 FROM sys.database_principals WHERE name = 'AllSchemaMaintenance')
BEGIN
    CREATE USER [AllSchemaMaintenance] WITHOUT LOGIN WITH DEFAULT_SCHEMA=[dbo]
    GRANT ALTER, DELETE, INSERT, SELECT, UPDATE ON SCHEMA::[internal] TO [AllSchemaMaintenance]
END
GO
/* ****************************************************
usp_CheckConstraints v 1.0 (2019-10-01)
Feedback: mailto:pavel.pawlowski@hotmail.cz

MIT License

Copyright (c) 2019 Pavel Pawlowski

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

Description:
    Enables or disables check constraints betwen among the log tables to allow fast cleanup of log records.    
Paramters:
    @enable     bit = 1 --Specifies whether the constraints should be enabled or disabled
 ******************************************************* */
ALTER PROCEDURE [dbo].[usp_CheckConstraints]
    @enable    bit = 1  --Specifies whether the constraints should be enabled or disabled
WITH EXECUTE AS 'AllSchemaMaintenance'
AS
BEGIN 
    SET NOCOUNT ON

    RAISERROR(N'[dbo].[usp_CheckConstraints]', 0, 0) WITH NOWAIT;
    RAISERROR(N'=============================', 0, 0) WITH NOWAIT;

    IF @enable = 0
    BEGIN
        RAISERROR(N'Disabling [SSISDB] Constraints to [internal].[operations]', 0, 0) WITH NOWAIT;
        ALTER TABLE [internal].[event_message_context]
            NOCHECK CONSTRAINT [FK_EventMessagecontext_Operations]

        ALTER TABLE [internal].[event_messages]
            NOCHECK CONSTRAINT [FK_EventMessage_Operations]

        ALTER TABLE [internal].[operation_messages]
	        NOCHECK CONSTRAINT [FK_OperationMessages_OperationId_Operations]

        ALTER TABLE [internal].[executions]
            NOCHECK CONSTRAINT [FK_Executions_ExecutionId_Operations]


        ALTER TABLE [internal].[validations]
            NOCHECK CONSTRAINT [FK_Validations_ValidationId_Operations]


        ALTER TABLE [internal].[operation_permissions]
            NOCHECK CONSTRAINT [FK_OperationPermissions_ObjectId_Operations]

        ALTER TABLE [internal].[extended_operation_info]
            NOCHECK CONSTRAINT [FK_OperationInfo_Operations]

        ALTER TABLE [internal].[operation_os_sys_info]
            NOCHECK CONSTRAINT [FK_OssysInfo_Operations]
    END
    ELSE
    BEGIN
        RAISERROR(N'Enabling [SSISDB] Constraints to [internal].[operations]', 0, 0) WITH NOWAIT;

        DELETE FROM [internal].[event_messages]
            WHERE operation_id NOT IN (SELECT operation_id FROM [internal].[operations])

        ALTER TABLE [internal].[event_message_context]
            NOCHECK CONSTRAINT [FK_EventMessagecontext_Operations]
        
        ALTER TABLE [internal].[event_messages]
            CHECK CONSTRAINT [FK_EventMessage_Operations]

        --=============================
        DELETE FROM [internal].[operation_messages]
            WHERE operation_id NOT IN (SELECT operation_id FROM [internal].[operations])

        ALTER TABLE [internal].[operation_messages]
	        CHECK CONSTRAINT [FK_OperationMessages_OperationId_Operations]

        --=============================
        DELETE FROM [internal].[executions]
            WHERE execution_id NOT IN (SELECT operation_id FROM [internal].[operations])
        
        ALTER TABLE [internal].[executions]
            CHECK CONSTRAINT [FK_Executions_ExecutionId_Operations]


        --=============================
        DELETE FROM [internal].[validations]
            WHERE validation_id NOT IN (SELECT operation_id FROM [internal].[operations])

        ALTER TABLE [internal].[validations]
            CHECK CONSTRAINT [FK_Validations_ValidationId_Operations]


        --=============================
        DELETE FROM [internal].[operation_permissions]
            WHERE [object_id] NOT IN (SELECT operation_id FROM [internal].[operations])
        
        ALTER TABLE [internal].[operation_permissions]
            CHECK CONSTRAINT [FK_OperationPermissions_ObjectId_Operations]

        --=============================
        DELETE FROM [internal].[extended_operation_info]
            WHERE operation_id NOT IN (SELECT operation_id FROM [internal].[operations])

        ALTER TABLE [internal].[extended_operation_info]
            CHECK CONSTRAINT [FK_OperationInfo_Operations]

        --=============================
        DELETE FROM [internal].[operation_os_sys_info]
            WHERE operation_id NOT IN (SELECT operation_id FROM [internal].[operations])

        ALTER TABLE [internal].[operation_os_sys_info]
            CHECK CONSTRAINT [FK_OssysInfo_Operations]
    END
END
GO

GRANT EXECUTE ON [dbo].[usp_CheckConstraints] TO [##MS_SSISServerCleanupJobUser##]
GO
