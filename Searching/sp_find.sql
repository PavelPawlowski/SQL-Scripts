USE [master]
GO
IF NOT EXISTS (SELECT 1 FROM sys.all_objects WHERE object_id = OBJECT_ID('[dbo].[sp_find]') AND TYPE = 'P')
    EXECUTE ('CREATE PROCEDURE [dbo].[sp_find] AS BEGIN PRINT ''Container for sp_find (C) Pavel Pawlowski'' END');
GO
/* ****************************************************
sp_find v 0.91 (2017-10-13)
(C) 2014 - 2017 Pavel Pawlowski

Feedback: mailto:pavel.pawlowski@hotmail.cz

License: 
    sp_find is free to download and use for personal, educational, and internal 
    corporate purposes, provided that this header is preserved. Redistribution or sale 
    of sp_find, in whole or in part, is prohibited without the author's express 
    written consent.

Description:
    Searches databases and server objects for specified string

Parameters:
     @searchString              nvarchar(max)   = NULL          -- String to search for To serch for substring include wildcards like '%searchString%'
    ,@objectTypes               nvarchar(max)   = N'DATABASE'   -- Comma separated list of Object Types to search
    ,@databaseName              nvarchar(max)   = NULL          -- Comma separated list of databases to search. NULL means current database. Supports wildcards and ''%%'' means all databases
    ,@searchInDefinition        bit             = 1             -- Specifies whether to search in object definitions
    ,@caseSensitive             bit             = 0             -- Specifies whether a Case Sensitive search should be done
 
 Results table Schema:
 --------------------
 CREATE TABLE #Results(
     [DatabaseName]          nvarchar(128)   NULL       -- Database name of the match. In case of server scoped objects NULL
    ,[MatchIn]               varchar(10)     NOT NULL   -- Specifies whethe match was in NAME or in definition
    ,[ObjectType]            nvarchar(66)    NOT NULL   -- Type of object found
    ,[ObjectID]              varchar(36)     NOT NULL   -- ID of the object found
    ,[ObjectSchema]          nvarchar(128)   NULL       -- Object schema. NULL for not schema bound objects
    ,[ObjectName]            nvarchar(128)   NULL       -- Object name
    ,[ParentObjectType]      nvarchar(60)    NULL       -- Parent object type
    ,[ParentObjectID]        varchar(36)     NULL       -- Parent object ID
    ,[ParentObjectSchema]    nvarchar(128)   NULL       -- Parent object schema. NULL for not schema bound objects
    ,[ParentObjectName]      nvarchar(128)   NULL       -- Parent Object Name
    ,[ObjectCreationDate]    datetime        NULL       -- Object creation date if available
    ,[ObjectModifyDate]      datetime        NULL       -- Object modification date if available
    ,[ObjectPath]            nvarchar(max)   NULL       -- Path to the Object in SSMS Object Explorer
    ,[ObjectDetails]         xml             NULL       -- Objects details including definition for SQL modules
)

Revisions: 
* ***************************************************** */ 
ALTER PROCEDURE [dbo].[sp_find]
     @searchString              nvarchar(max)   = NULL          -- String to search for To serch for substring include wildcards like '%searchString%'
    ,@objectTypes               nvarchar(max)   = N'DATABASE'   -- Comma separated list of Object Types to search
    ,@databaseName              nvarchar(max)   = NULL          -- Comma separated list of databases to search. NULL means current database. Supports wildcards and ''%%'' means all databases
    ,@searchInDefinition        bit             = 1             -- Specifies whether to search in object definitions
    ,@caseSensitive             bit             = 0             -- Specifies whether a Case Sensitive search should be done
AS
BEGIN
SET NOCOUNT ON;

DECLARE
    @wrongTypes nvarchar(max)                           -- Will store wrong object types not matchind the correct one
    --,@searchStr nvarchar(max) = N'%' + @searchString + N'%'	-- Updated Search string with all wildcards  ##Currently do not add wildcards to allow search for exact match
    ,@searchStr nvarchar(max) = @searchString           -- Updated Search string with all wildcards
    ,@dbName nvarchar(128)                              -- database name of currently processed database
    ,@dbCollation nvarchar(128)                         -- colaltion to be used for currently processed database
    ,@searchBaseSQL nvarchar(max)                       -- Base search SQL 
    ,@searchSQL nvarchar(max)                           -- Search SQL updated for current database and collation
    ,@searchDescription nvarchar(255)                   -- Description of the current search being executed
    ,@sql nvarchar(max)                                 -- variable ro general dynamic SQL manipulations
    ,@msg nvarchar(max)                                 -- for storing mesaages being printed
    ,@paramDefinition nvarchar(max)                     -- Parameters Definition for help printing
    ,@caption nvarchar(max)                             -- sp_Find caption
    ,@start datetime2                                   -- Start timestap scope search
    ,@searchStart datetime2                             -- Start timestamp of current search
    ,@dbSearchStart datetime2                           -- Start timestamp of current database search
    ,@end datetime2                                     -- End fimenstap of current search
    ,@searchEnd datetime2                               -- End timestamp scope search
    ,@dbSearchEnd datetime2                             -- End timestamp of current database search
    ,@now nvarchar(24)                                  -- Current time converted to string for printing
    ,@duration nvarchar(10)                             -- Duration of current search converted to string for printing
    ,@currentScope tinyint                              -- Stores scope of current search
    ,@startMessage nvarchar(256)                        -- Start message of current scope
    ,@endMessage nvarchar(256)                          -- End message of current scope
    ,@dbStartMessage nvarchar(256)                      -- Start message of current DB
    ,@dbEndMessage nvarchar(256)                        -- End message of current DB
    ,@printHelp bit = 0                                 -- Specifies whether to print HELP
    ,@version varchar(20)                               -- Store Server version
    ,@versionNumber bigint                              -- Store the version as bigint number
    ,@xml xml                                           -- For XML Storing purposes
    ,@matchInName nvarchar(10) = N'NAME'                -- Specifies string to return when there is a match in name
    ,@matchInDefinition nvarchar(10) = N'DEFINITION'    -- Specifies string to return when there is match in definition
    ,@basePath nvarchar(max) = N''                      -- Base ObjectPath - for database object searches it contains path to the Database
    ,@atGroup tinyint                                   -- Allowed Types group for help printing purposes
    ,@lastAtGroup tinyint = 0                           -- Last Allowed Types group for helpprinting purposes

--Set and print the procedure output caption
SET @caption =  N'sp_find v0.91 (2017-10-13) (C) 2014-2017 Pavel Pawlowski' + NCHAR(13) + NCHAR(10) + 
                N'========================================================' + NCHAR(13) + NCHAR(10);
RAISERROR(@caption, 0, 0) WITH NOWAIT;

--Temp table to hold list of search types --we need temp table to be available inside dynamic search SQL
CREATE TABLE #objTypes (
     ObjectType nvarchar(128) COLLATE Latin1_General_CI_AS NOT NULL PRIMARY KEY CLUSTERED
    ,[Type] char(2) COLLATE Latin1_General_CI_AS
);

--Temp table to hold mappings between object types and covering parent types
CREATE TABLE #typesMapping(
    ObjectType          nvarchar(128) COLLATE Latin1_General_CI_AS NOT NULL 
    ,ParentObjectType   nvarchar(128) COLLATE Latin1_General_CI_AS NOT NULL 
    ,PRIMARY KEY CLUSTERED(ObjectType,ParentObjectType)
)

--Table varaible to hold input object types
DECLARE @inputTypes TABLE (
    ObjectType nvarchar(128) COLLATE Latin1_General_CI_AS NOT NULL PRIMARY KEY CLUSTERED
)


--Table variable to hold Search results
DECLARE @Results TABLE(
     [DatabaseName]          nvarchar(128)  NULL
    ,[MatchIn]               varchar(10)    NOT NULL
    ,[ObjectType]            nvarchar(66)   NOT NULL
    ,[ObjectID]              varchar(36)    NOT NULL
    ,[ObjectSchema]          nvarchar(128)  NULL
    ,[ObjectName]            nvarchar(128)  NULL
    ,[ParentObjectType]      nvarchar(60)   NULL
    ,[ParentObjectID]        varchar(36)    NULL
    ,[ParentObjectSchema]    nvarchar(128)  NULL
    ,[ParentObjectName]      nvarchar(128)  NULL
    ,[ObjectCreationDate]    datetime       NULL
    ,[ObjectModifyDate]      datetime       NULL
    ,[ObjectPath]            nvarchar(max)  NULL
    ,[ObjectDetails]         xml            NULL
);

--Table variable for storing list of databases to search in
DECLARE @databases TABLE(
    DatabaseName nvarchar(128)
)

--Table variable for storing allowed object types
DECLARE @allowedTypes TABLE ( 
     RowID                  int NOT NULL IDENTITY(1,1)                                          --RowID of the Allowed Types
    ,[Group]                tinyint                                                             --Group fo allowed types for sorting purposes during help printing
    ,ObjectType             nvarchar(128)   COLLATE Latin1_General_CI_AS PRIMARY KEY CLUSTERED  --Object Type
    ,[Type]                 char(2)                                                             --Type corresponding to insternal sytem type codes
    ,SearchScope            char(1)                                                             --Scope of the search name/definition
    ,ObjectDescription      varchar(256)    COLLATE Latin1_General_CI_AS                        --Desciprion of the object type
    ,DefinitionSearchScope  varchar(256)    COLLATE Latin1_General_CI_AS                        --Description of the Definition search scope
);

--For purpose of version numbers storage
DECLARE @versionNumbers TABLE(
    ID              int NOT NULL IDENTITY(1, 1) PRIMARY KEY CLUSTERED
    ,versionNumber   int
);

--Table variable to hold Searches to be executed
DECLARE @searches TABLE (
     ID                  int             NOT NULL IDENTITY(1, 1) PRIMARY KEY CLUSTERED
    ,SearchScope         tinyint         NOT NULL DEFAULT(0)
    ,SearchDescription   nvarchar(255)   NULL
    ,SearchSQL           nvarchar(MAX)   NOT NULL
)

--Insrt allwed object types into @allowedTypes table variable
INSERT INTO @allowedTypes([Group], ObjectType, [Type], SearchScope, ObjectDescription, DefinitionSearchScope)
VALUES
         (0,    N'DATABASE'                          ,''     ,'D'    ,'Any database scoped object'                                       ,'Depends on concrete object type')          --Custom Group Type
        ,(0,    N'SERVER'                            ,''     ,'D'    ,'Any Server Scoped object'                                         ,'Depends on concrete object type')          --Custom Group Type
        ,(0,    N'SSIS'                              ,''     ,'D'    ,'Any SSIS related object (SSISDB or legacy in msdb)'               ,'Depends on concrete object type')          --Custom Group Type
                                               
        ,(1,    N'OBJECT'                            ,''     ,'D'    ,'Any schema scoped database object'                                ,'Depends on concrete object type')          --Custom Group Type
        ,(1,    N'SYSTEM_OBJECT'                     ,''     ,'D'    ,'Any system objects (EXPLICIT)'                                    ,'Depends on concrete object type')          --Custom Group TYpe
        ,(1,    N'AGGREGATE_FUNCTION'                ,'AF'   ,'D'    ,'Aggregate funciton (CLR)'                                         ,'assembly_class & assembly_method names')
        ,(1,    N'CHECK_CONSTRAINT'                  ,'C'    ,'D'    ,'CHECK constraint'                                                 ,'T-SQL definition of the constraint')
        ,(1,    N'CLR_SCALAR_FUNCTION'               ,'FS'   ,'D'    ,'Scalar function (CLR)'                                            ,'assembly_class & assembly_method names')
        ,(1,    N'FUNCTION'                          ,''     ,'D'    ,'Any fucntion (SQL or CLR'                                         ,'Depends on concrete function type')        --Custom Group Type
        ,(1,    N'SQL_FUNCTION'                      ,''     ,'D'    ,'Any SQL function (scalar, inline table-valued, table valued'      ,'Whole T-SQL Definition')                   --Custom Type
        ,(1,    N'CLR_FUNCTION'                      ,''     ,'D'    ,'Any CLR function (scalar, table-valued'                           ,'assembly_class & assembly_method names')   --Custom Group Type
        ,(1,    N'PROCEDURE'                         ,''     ,'D'    ,'Any stored procedure (SQL, CLR or Extended)'                      ,'Depends on concrete procedure type')       --Custom Group Type
        ,(1,    N'CLR_STORED_PROCEDURE'              ,'PC'   ,'D'    ,'Stored Procedure (CLR)'                                           ,'assembly_class & assembly_method names')
        ,(1,    N'CLR_TABLE_VALUED_FUNCTION'         ,'FT'   ,'D'    ,'Table Valued Function (CLR)'                                      ,'assembly_class & assembly_method names')
        ,(1,    N'TRIGGER'                           ,''     ,'D'    ,'Any (CLR, SQL) DML, DDL (database or server) Trigger'             ,'depends on concrete object type')          --Custom Group Type
        ,(1,    N'DATABASE_TRIGGER'                  ,''     ,'D'    ,'Any (CLR, SQL) DDL (database) Trigger'                            ,'depends on concrete object type')	        --Custom Group Type
        ,(1,    N'SERVER_TRIGGER'                    ,''     ,'D'    ,'Any (CLR, SQL) DDL (server) Trigger'                              ,'depends on concrete object type')	        --Custom Group Type
        ,(1,    N'CLR_TRIGGER'                       ,'TA'   ,'D'    ,'Assembly (CLR) DML or DDL (database or server) Trigger'           ,'assembly_class & assembly_method names')
        ,(1,    N'CLR_DATABASE_TRIGGER'              ,'TA'   ,'D'    ,'Assembly (CLR) DML or DDL database Trigger'                       ,'assembly_class & assembly_method names')
        ,(1,    N'CLR_SERVER_TRIGGER'                ,'TA'   ,'D'    ,'Assembly (CLR) DML or DDL server Trigger'                         ,'assembly_class & assembly_method names')
        ,(1,    N'SQL_DATABASE_TRIGGER'              ,'TR'   ,'D'    ,'Assembly (CLR) DML or DDL database Trigger'                       ,'assembly_class & assembly_method names')
        ,(1,    N'SQL_SERVER_TRIGGER'                ,'TR'   ,'D'    ,'Assembly (CLR) DML or DDL server Trigger'                         ,'assembly_class & assembly_method names')
        ,(1,    N'DEFAULT_CONSTRAINT'                ,'D'    ,'D'    ,'DEFAULT constraint'                                               ,'T-SQL definition of the constraint')
        ,(1,    N'EXTENDED_STORED_PROCEDURE'         ,'X'    ,'N'    ,'Extended stored procedure'                                        ,'')
        ,(1,    N'FOREIGN_KEY_CONSTRAINT'            ,'F'    ,'N'    ,'FOREIGN KEY constraint'                                           ,'')
        ,(1,    N'INTERNAL_TABLE'                    ,'IT'   ,'N'    ,'Internal Table (EXPLICIT)'                                        ,'')
        ,(1,    N'PLAN_GUIDE'                        ,''     ,'N'    ,'Plan Guide'                                                       ,'')
        ,(1,    N'PRIMARY_KEY_CONSTRAINT'            ,'PK'   ,'N'    ,'PRIMARY KEY constraint'                                           ,'')
        ,(1,    N'REPLICATION_FILTER_PROCEDURE'      ,'RF'   ,'D'    ,'Replication filter procedure'                                     ,'Whole T-SQL Definition')
        ,(1,    N'RULE'                              ,'R'    ,'N'    ,'Rule'                                                             ,'')
        ,(1,    N'SEQUENCE_OBJECT'                   ,'SO'   ,'N'    ,'Sequence Object (SQL Server 212 and above'                        ,'')
        ,(1,    N'SERVICE_QUEUE'                     ,'SQ'   ,'N'    ,'Service Queue'                                                    ,'')
        ,(1,    N'SQL_INLINE_TABLE_VALUED_FUNCTION'  ,'IF'   ,'D'    ,'SQL inline table valued function'                                 ,'Whole T-SQL Definition')
        ,(1,    N'SQL_SCALAR_FUNCTION'               ,'FN'   ,'D'    ,'SQL scalar function'                                              ,'Whole T-SQL Definition')
        ,(1,    N'SQL_STORED_PROCEDURE'              ,'P'    ,'D'    ,'SQL stored prcedure'                                              ,'Whole T-SQL Definition')
        ,(1,    N'SQL_TABLE_VALUED_FUNCTION'         ,'TF'   ,'D'    ,'SQL table valued function'                                        ,'Whole T-SQL Definition')
        ,(1,    N'SQL_TRIGGER'                       ,''     ,'D'    ,'SQL DML or DDL (database or server) Trigger'                      ,'Whole T-SQL Definition')
        ,(1,    N'SYNONYM'                           ,'SN'   ,'N'    ,'Synonym'                                                          ,'')
        ,(1,    N'SYSTEM_TABLE'                      ,'S'    ,'N'    ,'System table (EXPLICIT)'                                          ,'')
        ,(1,    N'TABLE_TYPE'                        ,'TT'   ,'N'    ,'Table type'                                                       ,'')
        ,(1,    N'UNIQUE_CONSTRAINT'                 ,'UQ'   ,'N'    ,'UNIQUE constraint'                                                ,'')
        ,(1,    N'USER_TABLE'                        ,'U'    ,'N'    ,'Table (user-defined)'                                             ,'')
        ,(1,    N'VIEW'                              ,'V'    ,'D'    ,'View'                                                             ,'Whole T-SQL Definition')
        ,(1,    N'INDEX'                             ,''     ,'D'    ,'Any index type'                                                   ,'index column names')	--Custom Group Type
        ,(1,    N'INDEX_CLUSTERED'                   ,'1'    ,'D'    ,'CLUSTERED index'                                                  ,'index column names')
        ,(1,    N'INDEX_NONCLUSTERED'                ,'2'    ,'D'    ,'NONCLUSTERED index'                                               ,'index column names')
        ,(1,    N'INDEX_XML'                         ,'3'    ,'D'    ,'XML index'                                                        ,'index column names')
        ,(1,    N'INDEX_SPATIAL'                     ,'4'    ,'D'    ,'SPATIAL index'                                                    ,'index column names')
        ,(1,    N'INDEX_CLUSTERED COLUMNSTORE'       ,'5'    ,'D'    ,'CLUSTERED COLUMNSTORE index'                                      ,'index column names')
        ,(1,    N'INDEX_NONCLUSTERED COLUMNSTORE'    ,'6'    ,'D'    ,'NONCLUSTERED COLUMNSTORE index'                                   ,'index column names')
        ,(1,    N'INDEX_NONCLUSTERED HASH'           ,'7'    ,'D'    ,'HASH Index (SQL Server 2014 and above)'                           ,'index column names')
        ,(1,    N'COLUMN'                            ,''     ,'D'    ,'Column'                                                           ,'T-SQL definition of computed columns')
        ,(1,    N'SYSTEM_COLUMN'                     ,''     ,'D'    ,'Column of system and internal tables'                             ,'T-SQL definition of computed columns')    --Custom Type
        ,(1,    N'SCHEMA'                            ,''     ,'N'    ,'Schema'                                                           ,'')	--Custom Type
        ,(1,    N'DATABASE_PRINCIPAL'                ,''     ,'N'    ,'Any datbabase principal'                                          ,'')	--Custom Group Type
        ,(1,    N'SQL_USER'                          ,'S'    ,'N'    ,'SQL user'                                                         ,'')
        ,(1,    N'WINDOWS_USER'                      ,'U'    ,'N'    ,'Windows user'                                                     ,'')
        ,(1,    N'WINDOWS_GROUP'                     ,'G'    ,'N'    ,'Windows group user or login'                                      ,'')
        ,(1,    N'APPLICATION_ROLE'                  ,'A'    ,'N'    ,'Application role'                                                 ,'')
        ,(1,    N'DATABASE_ROLE'                     ,'R'    ,'N'    ,'Database role'                                                    ,'')
        ,(1,    N'CERTIFICATE_MAPPED_USER'           ,'C'    ,'N'    ,'Certificate mapped user'                                          ,'')
        ,(1,    N'ASYMMETRIC_KEY_MAPPED_USER'        ,'K'    ,'N'    ,'Asymmetric key mapped user'                                       ,'')
        ,(1,    N'EXTERNAL_USER'                     ,'E'    ,'N'    ,'External user from Azure Active Directory'                        ,'')
        ,(1,    N'EXTERNAL_GROUP'                    ,'X'    ,'N'    ,'External group from Azure Active Directory group or applications' ,'')
        ,(1,    N'TYPE'                              ,''     ,'N'    ,'Type'                                                             ,'')	--Custom Type
        ,(1,    N'ASSEMBLY'                          ,''     ,'N'    ,'Assembly'                                                         ,'assembly_class, assembly_method_names, assembly file_names')	--Custom Type
        ,(1,    N'XML_SCHEMA_COLLECTION'             ,''     ,'N'    ,'XML schema collection'                                            ,'')    --Custom Type
        ,(1,    N'SERVICE_MESSAGE_TYPE'              ,''     ,'N'    ,'Service message type'                                             ,'')    --Custom Type
        ,(1,    N'SERVICE_CONTRACT'                  ,''     ,'N'    ,'Service contract'                                                 ,'')    --Custom Type
        ,(1,    N'SERVICE'                           ,''     ,'N'    ,'Service'                                                          ,'')    --Custom Type
        ,(1,    N'REMOTE_SERVICE_BINDING'            ,''     ,'N'    ,'Remote service binding'                                           ,'')    --Custom Type
        ,(1,    N'ROUTE'                             ,''     ,'N'    ,'Route'                                                            ,'')    --Custom Type
        ,(1,    N'FULLTEXT_CATALOG'                  ,''     ,'N'    ,'Fulltext catalog'                                                 ,'')    --Custom Type
        ,(1,    N'SYMMETRIC_KEY'                     ,''     ,'N'    ,'Symmetric key'                                                    ,'')    --Custom Type
        ,(1,    N'CERTIFICATE'                       ,''     ,'N'    ,'Certificate'                                                      ,'')    --Custom Type
        ,(1,    N'ASYMMETRIC_KEY'                    ,''     ,'N'    ,'Asymmetric key'                                                   ,'')    --Custom Type
        ,(1,    N'PARTITION_SCHEME'                  ,''     ,'N'    ,'Partition scheme'                                                 ,'')    --Custom Type
        ,(1,    N'PARTITION_FUNCTION'                ,''     ,'D'    ,'partition function'                                               ,'Partition range values')  --Custom Type
        ,(1,    N'SERVER_PRINCIPAL'                  ,''     ,'N'    ,'Any server principal'                                             ,'')    --Custom Group Type
        ,(1,    N'SQL_LOGIN'                         ,'S'    ,'N'    ,'SQL login'                                                        ,'')
        ,(1,    N'WINDOWS_LOGIN'                     ,'U'    ,'N'    ,'Windows login'                                                    ,'')
        ,(1,    N'SERVER_ROLE'                       ,'R'    ,'N'    ,'Server role'                                                      ,'')
        ,(1,    N'CERTIFICATE_MAPPED_LOGIN'          ,'C'    ,'N'    ,'Certificate mapped login'                                         ,'')
        ,(1,    N'ASYMMETRIC_KEY_MAPPED_LOGIN'       ,'K'    ,'N'    ,'Asymmetric key mapped login'                                      ,'')
        ,(1,    N'CREDENTIAL'                        ,''     ,'N'    ,'Credential'                                                       ,'')    --Custom Type
        ,(1,    N'LINKED_SERVER'                     ,''     ,'D'    ,'LinkedServer'                                                     ,'Provider string')	--Custom Type
        ,(1,    N'SSISDB'                            ,''     ,'D'    ,'Any SSIS related object in SSISDB'                                ,'Depends on concrete object type')     --Custom Type
        ,(1,    N'SSIS_FOLDER'                       ,''     ,'N'    ,'SSIS Folder in SSISDB'                                            ,'')    --Custom Type
        ,(1,    N'SSIS_ENVIRONMENT'                  ,''     ,'N'    ,'SSIS Environment'                                                 ,'')    --Custom Type
        ,(1,    N'SSIS_VARIABLE'                     ,''     ,'D'    ,'SSIS Environment Variable'                                        ,'Description, Non sensitive values')   --Custom Type
        ,(1,    N'SSIS_PROJECT'                      ,''     ,'D'    ,'SSIS Project'                                                     ,'Description')     --Custom Type
        ,(1,    N'SSIS_PACKAGE'                      ,''     ,'D'    ,'SSIS Package'                                                     ,'Description')     --Custom Type
		,(1,    N'SSIS_PACKAGE_VERSION'              ,''     ,'D'    ,'SSIS Package iv all project versions (EXPLICIT)'                  ,'Description')     --Custom Type
        ,(1,    N'SSIS_MSDB'                         ,''     ,'D'    ,'Any Legacy SSIS related object in msdb'                           ,'Depends on concrete object type')     --Custom Type
        ,(1,    N'SSIS_MSDB_FOLDER'                  ,''     ,'N'    ,'SSIS Folder in msdb'                                              ,'')    --Custom Type
        ,(1,    N'SSIS_MSDB_PACKAGE'                 ,''     ,'D'    ,'SSIS Legacy Package in msdb'                                      ,'Description, content of SSIS Package')     --Custom Type
        
;
--Define mappings between types and their parent types
INSERT INTO #typesMapping(ObjectType, ParentObjectType)
VALUES 
     (N'DATABASE'                               ,N'')
    ,(N'SERVER'                                 ,N'')
    ,(N'SSIS'                                   ,N'')
    ,(N'SYSTEM_OBJECT'                          ,N'')
    ,(N'TRIGGER'                                ,N'')
    ,(N'CLR_TRIGGER'                            ,N'')
    ,(N'SQL_TRIGGER'                            ,N'')
    ,(N'OBJECT'                                 ,N'DATABASE')
    ,(N'INDEX'                                  ,N'DATABASE')
    ,(N'DATABASE_TRIGGER'                       ,N'DATABASE')
    ,(N'DATABASE_PRINCIPAL'                     ,N'DATABASE')
    ,(N'SERVER_TRIGGER'                         ,N'SERVER')
    ,(N'SERVER_PRINCIPAL'                       ,N'SERVER')
    ,(N'DATABASE_TRIGGER'                       ,N'TRIGGER')
    ,(N'SERVER_TRIGGER'                         ,N'TRIGGER')
    ,(N'CLR_DATABASE_TRIGGER'                   ,N'CLR_TRIGGER')
    ,(N'CLR_SERVER_TRIGGER'                     ,N'CLR_TRIGGER')
    ,(N'SQL_DATABASE_TRIGGER'                   ,N'SQL_TRIGGER')
    ,(N'SQL_SERVER_TRIGGER'                     ,N'SQL_TRIGGER')
    ,(N'FUNCTION'                               ,N'OBJECT')
    ,(N'SQL_FUNCTION'                           ,N'OBJECT')
    ,(N'CLR_FUNCTION'                           ,N'OBJECT')
    ,(N'PROCEDURE'                              ,N'OBJECT')
    ,(N'AGGREGATE_FUNCTION'                     ,N'OBJECT')
    ,(N'CHECK_CONSTRAINT'                       ,N'OBJECT')
    ,(N'CLR_SCALAR_FUNCTION'                    ,N'OBJECT')
    ,(N'CLR_STORED_PROCEDURE'                   ,N'OBJECT')
    ,(N'CLR_TABLE_VALUED_FUNCTION'              ,N'OBJECT')
    ,(N'CLR_DATABASE_TRIGGER'                   ,N'OBJECT')
    ,(N'DEFAULT_CONSTRAINT'                     ,N'OBJECT')
    ,(N'EXTENDED_STORED_PROCEDURE'              ,N'SYSTEM_OBJECT')
    ,(N'FOREIGN_KEY_CONSTRAINT'                 ,N'OBJECT')
    ,(N'PLAN_GUIDE'                             ,N'OBJECT')
    ,(N'PRIMARY_KEY_CONSTRAINT'                 ,N'OBJECT')
    ,(N'RULE'                                   ,N'OBJECT')
    ,(N'SEQUENCE_OBJECT'                        ,N'OBJECT')
    ,(N'SERVICE_QUEUE'                          ,N'OBJECT')
    ,(N'SQL_TABLE_VALUED_FUNCTION'              ,N'OBJECT')
    ,(N'SQL_DATABASE_TRIGGER'                   ,N'OBJECT')
    ,(N'SYNONYM'                                ,N'OBJECT')
    ,(N'TABLE_TYPE'                             ,N'OBJECT')
    ,(N'UNIQUE_CONSTRAINT'                      ,N'OBJECT')
    ,(N'USER_TABLE'                             ,N'OBJECT')
    ,(N'VIEW'                                   ,N'OBJECT')
    ,(N'INTERNAL_TABLE'                         ,N'SYSTEM_OBJECT')
    ,(N'SYSTEM_TABLE'                           ,N'SYSTEM_OBJECT')
    ,(N'SYSTEM_COLUMN'                          ,N'SYSTEM_OBJECT')
    ,(N'INDEX_CLUSTERED'                        ,N'INDEX')
    ,(N'INDEX_NONCLUSTERED'                     ,N'INDEX')
    ,(N'INDEX_XML'                              ,N'INDEX')
    ,(N'INDEX_SPATIAL'                          ,N'INDEX')
    ,(N'INDEX_CLUSTERED COLUMNSTORE'            ,N'INDEX')
    ,(N'INDEX_NONCLUSTERED COLUMNSTORE'         ,N'INDEX')
    ,(N'INDEX_NONCLUSTERED HASH'                ,N'INDEX')
    ,(N'CLR_SCALAR_FUNCTION'                    ,N'FUNCTION')
    ,(N'CLR_TABLE_VALUED_FUNCTION'              ,N'FUNCTION')
    ,(N'SQL_INLINE_TABLE_VALUED_FUNCTION'       ,N'FUNCTION')
    ,(N'SQL_SCALAR_FUNCTION'                    ,N'FUNCTION')
    ,(N'SQL_TABLE_VALUED_FUNCTION'              ,N'FUNCTION')
    ,(N'CLR_SCALAR_FUNCTION'                    ,N'CLR_FUNCTION')
    ,(N'CLR_TABLE_VALUED_FUNCTION'              ,N'CLR_FUNCTION')
    ,(N'SQL_INLINE_TABLE_VALUED_FUNCTION'       ,N'SQL_FUNCTION')
    ,(N'SQL_SCALAR_FUNCTION'                    ,N'SQL_FUNCTION')
    ,(N'SQL_TABLE_VALUED_FUNCTION'              ,N'SQL_FUNCTION')
    ,(N'CLR_STORED_PROCEDURE'                   ,N'PROCEDURE')
    ,(N'SQL_STORED_PROCEDURE'                   ,N'PROCEDURE')
    ,(N'REPLICATION_FILTER_PROCEDURE'           ,N'PROCEDURE')
    ,(N'CLR_DATABASE_TRIGGER'                   ,N'DATABASE_TRIGGER')
    ,(N'SQL_DATABASE_TRIGGER'                   ,N'DATABASE_TRIGGER')
    ,(N'CLR_SERVER_TRIGGER'                     ,N'SERVER_TRIGGER')
    ,(N'SQL_SERVER_TRIGGER'                     ,N'SERVER_TRIGGER')
    ,(N'SQL_USER'                               ,N'DATABASE_PRINCIPAL')
    ,(N'WINDOWS_USER'                           ,N'DATABASE_PRINCIPAL')
    ,(N'WINDOWS_GROUP'                          ,N'DATABASE_PRINCIPAL')
    ,(N'APPLICATION_ROLE'                       ,N'DATABASE_PRINCIPAL')
    ,(N'DATABASE_ROLE'                          ,N'DATABASE_PRINCIPAL')
    ,(N'CERTIFICATE_MAPPED_USER'                ,N'DATABASE_PRINCIPAL')
    ,(N'ASYMMETRIC_KEY_MAPPED_USER'             ,N'DATABASE_PRINCIPAL')
    ,(N'EXTERNAL_USER'                          ,N'DATABASE_PRINCIPAL')
    ,(N'EXTERNAL_GROUP'                         ,N'DATABASE_PRINCIPAL')
    ,(N'WINDOWS_GROUP'                          ,N'SERVER_PRINCIPAL')
    ,(N'SQL_LOGIN'                              ,N'SERVER_PRINCIPAL')
    ,(N'WINDOWS_LOGIN'                          ,N'SERVER_PRINCIPAL')
    ,(N'SERVER_ROLE'                            ,N'SERVER_PRINCIPAL')
    ,(N'CERTIFICATE_MAPPED_LOGIN'               ,N'SERVER_PRINCIPAL')
    ,(N'ASYMMETRIC_KEY_MAPPED_LOGIN'            ,N'SERVER_PRINCIPAL')
    ,(N'SSISDB'                                 ,N'SSIS')
    ,(N'SSIS_FOLDER'                            ,N'SSISDB')
    ,(N'SSIS_ENVIRONMENT'                       ,N'SSISDB')
    ,(N'SSIS_VARIABLE'                          ,N'SSISDB')
    ,(N'SSIS_PROJECT'                           ,N'SSISDB')
    ,(N'SSIS_PACKAGE'                           ,N'SSISDB')
    ,(N'SSIS_PACKAGE_VERSION'                   ,N'')
    ,(N'COLUMN'                                 ,N'DATABASE')
    ,(N'SCHEMA'                                 ,N'DATABASE')
    ,(N'TYPE'                                   ,N'DATABASE')
    ,(N'ASSEMBLY'                               ,N'DATABASE')
    ,(N'XML_SCHEMA_COLLECTION'                  ,N'DATABASE')
    ,(N'SERVICE_MESSAGE_TYPE'                   ,N'DATABASE')
    ,(N'SERVICE_CONTRACT'                       ,N'DATABASE')
    ,(N'SERVICE'                                ,N'DATABASE')
    ,(N'REMOTE_SERVICE_BINDING'                 ,N'DATABASE')
    ,(N'ROUTE'                                  ,N'DATABASE')
    ,(N'FULLTEXT_CATALOG'                       ,N'DATABASE')
    ,(N'SYMMETRIC_KEY'                          ,N'DATABASE')
    ,(N'CERTIFICATE'                            ,N'DATABASE')
    ,(N'ASYMMETRIC_KEY'                         ,N'DATABASE')
    ,(N'PARTITION_SCHEME'                       ,N'DATABASE')
    ,(N'PARTITION_FUNCTION'                     ,N'DATABASE')
    ,(N'CREDENTIAL'                             ,N'SERVER')
    ,(N'LINKED_SERVER'                          ,N'SERVER')
    ,(N'SSIS_MSDB'                              ,N'SSIS')
    ,(N'SSIS_MSDB_FOLDER'                       ,N'SSIS_MSDB')

--Split provided ObjectTypes and store them
IF ISNULL(RTRIM(LTRIM(@objectTypes)), N'') = N''
BEGIN
    SET @printHelp = 1;
    RAISERROR(N'You have to prvide list of @objectTypes to search. The list cannot be NULL, empty and must contain only supported types.', 15, 0);
END
ELSE
BEGIN
    SET @xml = CONVERT(xml, N'<type>'+ REPLACE(@objectTypes, N',', N'</type><type>') + N'</type>')

    INSERT INTO @inputTypes(
        ObjectType
    )
    SELECT DISTINCT
        LTRIM(RTRIM(n.value(N'.', N'nvarchar(128)'))) AS ObjectType
    FROM @xml.nodes(N'type') AS T(n)

    --Detect object types not in @allowedTypes
    SET @wrongTypes =   ISNULL(
                            STUFF((
                                    SELECT
                                        N',' + t.ObjectTYpe
                                    FROM @inputTypes t
                                    LEFT JOIN @allowedTypes at ON at.ObjectType = t.ObjectType
                                    WHERE at.ObjectType IS NULL
                                    FOR XML PATH(N''))
                              , 1, 1, N'')
                        , N'');

    --Check if correct object types were provided. If not, raise error and list all possible object types
    IF ISNULL(@wrongTypes, N'') <> N'' OR NULLIF(@objectTypes, '') IS NULL
    BEGIN	
        SET @printHelp = 1;
        RAISERROR(N'ObjectType(s) "%s" is/are not from within allowed types', 15, 1, @wrongTypes);
    END
END


--Check if search string is empty
IF RTRIM(LTRIM(@searchString)) = N''
BEGIN
    SET @printHelp = 1;
    RAISERROR(N'You have to prvide @searchString which is not NULL, empty and does not contains only spaces.', 15, 0);
END


--Print help when the @searchString is NULL or in case of error in input parameters
IF @searchString IS NULL OR @printHelp = 1
BEGIN
    RAISERROR(N'Searches databases and server objects for specified string', 0, 0);
    RAISERROR(N'', 0, 0);
    RAISERROR(N'Usage:', 0, 0);
    RAISERROR(N'[sp_find] parameters', 0, 0)
    RAISERROR(N'', 0, 0)
    SET @msg = N'Parameters:
     @searchString              nvarchar(max)   = NULL          -- String to search for To serch for substring include wildcards like ''%%searchString%%''
    ,@objectTypes               nvarchar(max)   = N''DATABASE''   -- Comma separated list of Object Types to search
    ,@databaseName              nvarchar(max)   = NULL          -- Comma separated list of databases to search. NULL means current database. Supports wildcards and ''%%'' means all databases
    ,@searchInDefinition        bit             = 1             -- Specifies whether to search in object definitions
    ,@caseSensitive             bit             = 0             -- Specifies whether a Case Sensitive search should be done'
    RAISERROR(@msg, 0, 0);
    RAISERROR(N'', 0, 0);
    
    RAISERROR(N'To search through system objects, the system object types has to be explicitly specified in the @objectTypes parameter', 0, 0);
    
    RAISERROR(N'', 0, 0);
    RAISERROR(N'Allowed Object Type                Search Scope          Desccription                                                 Definition search scope', 0, 0)
    RAISERROR(N'--------------------------------   -------------------   -----------------------------------------------------------  -----------------------------------------------------------', 0, 0);
    											                     
    DECLARE tc CURSOR FAST_FORWARD FOR
    	SELECT 
              [Group]
    		, LEFT(ObjectType + SPACE(35), 35) 
    		    + LEFT(CASE SearchScope WHEN N'N' THEN N'Name' ELSE N'Name + Definition' END + SPACE(22), 22)
    		    + LEFT(ObjectDescription + Space(61), 61)
    		    + DefinitionSearchScope
    	FROM @allowedTypes 
    	ORDER BY [Group], ObjectType;
    OPEN tc;
    
    FETCH NEXT FROM tc INTO @atGroup, @msg;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @atGroup <> @lastAtGroup
        BEGIN
            SET @lastAtGroup = @atGroup;
            RAISERROR(N'', 0, 0);
        END
    	RAISERROR(@msg, 0, 0);
    	FETCH NEXT FROM tc INTO @atGroup, @msg;
    END
    CLOSE tc;
    DEALLOCATE tc;
    
    RAISERROR(N'', 0, 0);
    RAISERROR(N'Table schema to hold results', 0, 0);
    RAISERROR(N'----------------------------', 0, 0);
    SET @msg = N'CREATE TABLE #Results(
     [DatabaseName]          nvarchar(128)   NULL       -- Database name of the match. In case of server scoped objects NULL
    ,[MatchIn]               varchar(10)     NOT NULL   -- Specifies whethe match was in NAME or in definition
    ,[ObjectType]            nvarchar(66)    NOT NULL   -- Type of object found
    ,[ObjectID]              varchar(36)     NOT NULL   -- ID of the object found
    ,[ObjectSchema]          nvarchar(128)   NULL       -- Object schema. NULL for not schema bound objects
    ,[ObjectName]            nvarchar(128)   NULL       -- Object name
    ,[ParentObjectType]      nvarchar(60)    NULL       -- Parent object type
    ,[ParentObjectID]        varchar(36)     NULL       -- Parent object ID
    ,[ParentObjectSchema]    nvarchar(128)   NULL       -- Parent object schema. NULL for not schema bound objects
    ,[ParentObjectName]      nvarchar(128)   NULL       -- Parent Object Name
    ,[ObjectCreationDate]    datetime        NULL       -- Object creation date if available
    ,[ObjectModifyDate]      datetime        NULL       -- Object modification date if available
    ,[ObjectPath]            nvarchar(max)   NULL       -- Path to the Object in SSMS Object Explorer
    ,[ObjectDetails]         xml             NULL       -- Objects details including definition for SQL modules
)';
	RAISERROR(@msg, 0, 0);

	RETURN;
END



;WITH TypesMapping AS (
    SELECT
         ObjectType
        ,ParentObjectType
    FROM #typesMapping
    WHERE ParentObjectType IN (SELECT ObjectType FROM @inputTypes)

    UNION ALL

    SELECT
         tm.ObjectType
        ,tm.ParentObjectType
    FROM #typesMapping tm
    INNER JOIN TypesMapping pt ON tm.ParentObjectType = pt.ObjectType
)
INSERT INTO #objTypes (
     ObjectType
    ,[Type]
)
SELECT DISTINCT
     TM.ObjectType
    ,AT.[Type]
FROM TypesMapping TM
INNER JOIN @allowedTypes AT ON TM.ObjectType = AT.ObjectType
UNION
SELECT
     IT.ObjectType
    ,AT.[Type]
FROM @inputTypes IT
INNER JOIN @allowedTypes AT ON IT.ObjectType = AT.ObjectType

--Get databases
IF (@databaseName IS NULL)
    SET @databaseName = DB_NAME();
SET @xml = CONVERT(xml, N'<db>' + REPLACE(@databaseName, N',', N'</db><db>') + N'</db>');

INSERT INTO @databases(DatabaseName)
SELECT
	LTRIM(RTRIM(n.value(N'.', N'nvarchar(128)')))
FROM @xml.nodes(N'db') AS T(n)

--Get Product Version in format major.minor.build.revision - We need version to enable additional features on newer editions
SET @version = CONVERT(nvarchar(128), SERVERPROPERTY('productversion'));

--Convert the version number into a bigint value - simplifies enabling features based on version and build numbers
SET @xml = CONVERT(xml, N'<version>'+ REPLACE(@version, N'.', N'</version><version>') + N'</version>')
SET @version = '';
SELECT
    @version = @version + RIGHT(N'00000' + n.value(N'.', N'varchar(10)'), 5)
FROM @xml.nodes(N'version') AS T(n);

SET @versionNumber = CONVERT(bigint, @version);


/**************************************************
   Define Searches for Database scoped objects
***************************************************/
DECLARE
     @fieldsSql nvarchar(max)
    ,@noPoFieldsSql nvarchar(max);

SET @fieldsSql = N'SELECT --Schema Bound Objects
        DB_NAME() COLLATE database_default                                  AS [DatabaseName]
        ,CASE WHEN o.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
        ,o.type_desc COLLATE database_default                               AS [ObjectType]
        ,o.object_id                                                        AS [ObjectID]
        ,SCHEMA_NAME(o.schema_id)                                           AS [ObjectSchema]
        ,o.name COLLATE database_default                                    AS [ObjectName]
        ,po.type_desc COLLATE database_default                              AS [ParentObjectType]
        ,po.object_id                                                       AS [ParentObjectID]
        ,SCHEMA_NAME(po.schema_id) COLLATE database_default                 AS [ParentObjectSchema]
        ,po.name COLLATE database_default                                   AS [ParentObjectName]
        ,o.create_date                                                      AS [ObjectCreationDate]
        ,o.modify_date                                                      AS [ObjectModifyDate]
        ';

SET @noPoFieldsSql = N'SELECT --Schema Bound Objects
        DB_NAME() COLLATE database_default                                  AS [DatabaseName]
        ,CASE WHEN o.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
        ,o.type_desc COLLATE database_default                               AS [ObjectType]
        ,o.object_id                                                        AS [ObjectID]
        ,SCHEMA_NAME(o.schema_id)                                           AS [ObjectSchema]
        ,o.name COLLATE database_default                                    AS [ObjectName]
        ,''SCHEMA'' COLLATE database_default                                AS [ParentObjectType]
        ,o.schema_id                                                        AS [ParentObjectID]
        ,'''' COLLATE database_default                                      AS [ParentObjectSchema]
        ,SCHEMA_NAME(o.schema_id) COLLATE database_default                  AS [ParentObjectName]
        ,o.create_date                                                      AS [ObjectCreationDate]
        ,o.modify_date                                                      AS [ObjectModifyDate]
        ';

--User Tables
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType = N'USER_TABLE')
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'User Tables', @noPoFieldsSql +
N'
        ,@basePath +N''\Tables\'' + QUOTENAME(SCHEMA_NAME(o.schema_id)) + N''.'' AS [ObjectPath]
        ,(
            SELECT 
                [object].*
                ,[table].*
                ,CONVERT(xml, 
                    (SELECT 
                        [column].* 
                        ,CONVERT(xml, STUFF(
                        (SELECT 
                            N'' '' + x.value(N''local-name(.)'', N''nvarchar(max)'') + N''="'' + x.value(N''.'', N''nvarchar(max)'') + N''"''
                        FROM
                        (SELECT (SELECT * from sys.computed_columns [computedColumn] WHERE object_id = [object].object_id AND column_id = [column].column_id FOR XML AUTO, TYPE) AS XmlData) M
                        CROSS APPLY XmlData.nodes(N''/*/@*'') a(x)
                        WHERE x.value(N''local-name(.)'', N''nvarchar(max)'') <> N''definition''
                        FOR XML PATH(N'''')), 1, 1, N''<computedColumn '') + N''/>'') 

                        ,CONVERT(xml, N''<?definition --'' + REPLACE(REPLACE(definition, N''<?'', N''''), N''?>'', N'''') + N''--?>'') -- computed column definition

                        FROM sys.columns [column] 
                        LEFT JOIN sys.computed_columns cc ON cc.object_id = [column].object_id AND cc.column_id = [column].column_id
                        WHERE [column].object_id = [object].[object_id] ORDER BY column_id FOR XML AUTO, ROOT(N''columns''))
                    )
            FROM sys.objects [object]
            INNER JOIN sys.tables [table] ON [table].object_id = [object].object_id
            WHERE [object].object_id = o.object_id 
            FOR XML AUTO, TYPE
            )               AS [ObjectDetails]
    FROM sys.objects o
    WHERE
        o.type COLLATE Latin1_General_CI_AS = N''U'' COLLATE Latin1_General_CI_AS
        AND 
        (
            (o.name COLLATE database_default LIKE @searchStr COLLATE database_default)
        )
');

--Views
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType = N'VIEW')
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'Views', @noPoFieldsSql +
N'
        ,@basePath + N''\Views\'' + QUOTENAME(SCHEMA_NAME(o.schema_id)) + N''.'' AS [ObjectPath]
        ,(
            SELECT
                [object].*
                ,[view].*
                ,(SELECT * FROM sys.columns [column] WHERE [column].object_id = [object].[object_id] ORDER BY column_id FOR XML AUTO, ROOT(N''columns''), TYPE)
                ,CONVERT(xml, STUFF(
                (SELECT 
                    N'' '' + x.value(N''local-name(.)'', N''nvarchar(max)'') + N''="'' + x.value(N''.'', N''nvarchar(max)'') + N''"''
                FROM
                (SELECT CONVERT(xml, (SELECT * from sys.sql_modules [module] WHERE object_id = [object].object_id FOR XML AUTO)) AS XmlData) M
                CROSS APPLY XmlData.nodes(N''/*/@*'') a(x)
                WHERE x.value(N''local-name(.)'', N''nvarchar(max)'') <> N''definition''
                FOR XML PATH(N'''')), 1, 1, N''<module '') + N''/>'')
                ,CONVERT(xml, N''<?definition --'' + NCHAR(13) + NCHAR(10) + REPLACE(REPLACE(definition, N''<?'', N''''), N''?>'', N'''') + NCHAR(13) + NCHAR(10) + N''--?>'')
            FROM sys.objects [object]
            INNER JOIN sys.views [view] ON [view].object_id = [object].object_id
            INNER JOIN sys.sql_modules  [module] ON [module].object_id = [object].object_id
            WHERE [object].object_id = o.object_id
            FOR XML AUTO, TYPE
            )               AS [ObjectDetails]
    FROM sys.objects o
    LEFT JOIN sys.sql_modules m ON m.object_id = o.object_id
    WHERE
        o.type COLLATE Latin1_General_CI_AS = N''V'' COLLATE Latin1_General_CI_AS
        AND 
        (
            (o.name COLLATE database_default LIKE @searchStr COLLATE database_default)
            OR
            (
                @searchInDefinition =1
                AND
                (
                    m.definition COLLATE database_default LIKE @searchStr COLLATE database_default
                )
            )
        )
');

--Check Constraints
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType = N'CHECK_CONSTRAINT')
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'Check Constraints', @fieldsSql +
N'
        ,@basePath + N''\Tables\'' + QUOTENAME(SCHEMA_NAME(po.schema_id)) + N''.'' + QUOTENAME(po.name) + N''\Constraints'' AS [ObjectPath]
        ,(
                    SELECT
                        [object].*
                        ,CONVERT(xml, STUFF(
                        (SELECT 
                            N'' '' + x.value(N''local-name(.)'', N''nvarchar(max)'') + N''="'' + x.value(N''.'', N''nvarchar(max)'') + N''"''
                        FROM
                        (SELECT CONVERT(xml, (SELECT * from sys.check_constraints [constraint] WHERE object_id = [object].object_id FOR XML AUTO)) AS XmlData) M
                        CROSS APPLY XmlData.nodes(N''/*/@*'') a(x)
                        WHERE x.value(N''local-name(.)'', N''nvarchar(max)'') <> N''definition''
                        FOR XML PATH(N'''')), 1, 1, N''<checkConstraint '') + N''/>'')
                        ,CONVERT(xml, N''<?definition --'' + NCHAR(13) + NCHAR(10) + REPLACE(REPLACE(definition, N''<?'', N''''), N''?>'', N'''') + NCHAR(13) + NCHAR(10) + N''--?>'')
                    FROM sys.objects [object]
                    INNER JOIN sys.check_constraints  [constraint] ON [constraint].object_id = [object].object_id
                    WHERE [object].object_id = o.object_id
                    FOR XML AUTO, TYPE
			)                   AS [ObjectDetails]
    FROM sys.objects o
    INNER JOIN sys.objects po ON po.object_id = o.parent_object_id
    WHERE
        o.type COLLATE Latin1_General_CI_AS = N''C'' COLLATE Latin1_General_CI_AS
        AND 
        (
            (o.name COLLATE database_default LIKE @searchStr COLLATE database_default)
        )
');

--Default Constraints
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType = N'DEFAULT_CONSTRAINT')
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'Default Constraints', @fieldsSql +
N'
        ,@basePath + N''\Tables\'' + QUOTENAME(SCHEMA_NAME(po.schema_id)) + N''.'' + QUOTENAME(po.name) + N''\Constraints'' AS [ObjectPath]
        ,(
            SELECT
                [object].*
                ,CONVERT(xml, STUFF(
                (SELECT 
                    N'' '' + x.value(N''local-name(.)'', N''nvarchar(max)'') + N''="'' + x.value(N''.'', N''nvarchar(max)'') + N''"''
                FROM
                (SELECT CONVERT(xml, (SELECT * from sys.default_constraints [constraint] WHERE object_id = [object].object_id FOR XML AUTO)) AS XmlData) M
                CROSS APPLY XmlData.nodes(N''/*/@*'') a(x)
                WHERE x.value(N''local-name(.)'', N''nvarchar(max)'') <> N''definition''
                FOR XML PATH(N'''')), 1, 1, N''<defaultConstraint '') + N''/>'')
                ,CONVERT(xml, N''<?definition --'' + NCHAR(13) + NCHAR(10) + REPLACE(REPLACE(definition, N''<?'', N''''), N''?>'', N'''') + NCHAR(13) + NCHAR(10) + N''--?>'')
            FROM sys.objects [object]
            INNER JOIN sys.default_constraints  [constraint] ON [constraint].object_id = [object].object_id
            WHERE [object].object_id = o.object_id
            FOR XML AUTO, TYPE
            )               AS [ObjectDetails]
    FROM sys.objects o
    INNER JOIN sys.objects po ON po.object_id = o.parent_object_id
    WHERE
        o.type COLLATE Latin1_General_CI_AS = N''D'' COLLATE Latin1_General_CI_AS
        AND 
        (
            (o.name COLLATE database_default LIKE @searchStr COLLATE database_default)
        )
');

--Foreign Keys Constraints
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType = N'FOREIGN_KEY_CONSTRAINT')
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'Foreign Key Constraints', @fieldsSql +
N'
        ,@basePath + N''\Tables\'' + QUOTENAME(SCHEMA_NAME(po.schema_id)) + N''.'' + QUOTENAME(po.name) + N''\Keys'' AS [ObjectPath]
        ,(
            SELECT
                [object].*
                ,[foreignKey].*
                ,CONVERT(xml, (
                    SELECT 
                        [column].*
                        ,[parentTable].*
                        ,[parentColumn].*
                        ,[preferencedTable].*
                        ,[referencedColumn].*
                    FROM sys.foreign_key_columns [column]
                    INNER JOIN sys.tables [parentTable] ON [parentTable].object_id = [column].parent_object_id
                    INNER JOIN sys.columns [parentColumn] ON [parentColumn].object_id = [column].parent_object_id AND [parentColumn].column_id = [column].parent_column_id
                    INNER JOIN sys.tables [preferencedTable] ON [preferencedTable].object_id = [column].referenced_object_id
                    INNER JOIN sys.columns [referencedColumn] ON [referencedColumn].object_id = [column].referenced_object_id AND [referencedColumn].column_id = [column].referenced_column_id
                    WHERE [column].constraint_object_id = [object].[object_id] 
                    ORDER BY constraint_column_id 
                    FOR XML AUTO, ROOT(''foreignKeyColumns''))
                )
            FROM sys.objects [object]
            INNER JOIN sys.foreign_keys [foreignKey] ON [foreignKey].object_id = [object].object_id
            WHERE [object].object_id = o.object_id
            FOR XML AUTO, TYPE
            )               AS [ObjectDetails]
    FROM sys.objects o
    INNER JOIN sys.objects po ON po.object_id = o.parent_object_id
    WHERE
        o.type COLLATE Latin1_General_CI_AS = N''F'' COLLATE Latin1_General_CI_AS
        AND 
        (
            (o.name COLLATE database_default LIKE @searchStr COLLATE database_default)
        )
');

--SQL Table Functions
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType IN (N'SQL_INLINE_TABLE_VALUED_FUNCTION', N'SQL_TABLE_VALUED_FUNCTION'))
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'SQL Inline And Table Valued Functions', @noPoFieldsSql +
N'
        ,@basePath + N''\Programmability\Functions\Table-valued Functions\'' + QUOTENAME(SCHEMA_NAME(o.schema_id)) + N''.'' AS [ObjectPath]
        ,(
            SELECT
                [object].*
                ,(SELECT * FROM sys.parameters [parameter] WHERE [parameter].object_id = [object].[object_id] ORDER BY parameter_id FOR XML AUTO, ROOT(N''parameters''), TYPE)
                ,(SELECT * FROM sys.columns [column] WHERE [column].object_id = [object].[object_id] ORDER BY column_id FOR XML AUTO, ROOT(N''columns''), TYPE)
                ,CONVERT(xml, STUFF(
                (SELECT 
                    N'' '' + x.value(N''local-name(.)'', N''nvarchar(max)'') + N''="'' + x.value(N''.'', N''nvarchar(max)'') + N''"''
                FROM
                (SELECT CONVERT(xml, (SELECT * from sys.sql_modules [module] WHERE object_id = [object].object_id FOR XML AUTO)) AS XmlData) M
                CROSS APPLY XmlData.nodes(N''/*/@*'') a(x)
                WHERE x.value(N''local-name(.)'', N''nvarchar(max)'') <> N''definition''
                FOR XML PATH(N'''')), 1, 1, N''<module '') + N''/>'')
                ,CONVERT(xml, N''<?definition --'' + NCHAR(13) + NCHAR(10) + REPLACE(REPLACE(definition, N''<?'', N''''), N''?>'', N'''') + NCHAR(13) + NCHAR(10) + N''--?>'')
            FROM sys.objects [object]
            INNER JOIN sys.sql_modules  [module] ON [module].object_id = [object].object_id
            WHERE [object].object_id = o.object_id
            FOR XML AUTO, TYPE							
            )               AS [ObjectDetails]
    FROM sys.objects o
    LEFT JOIN sys.sql_modules m ON m.object_id = o.object_id
    WHERE
        o.[type] COLLATE Latin1_General_CI_AS IN (SELECT [Type] FROM #objTypes WHERE ObjectType IN (N''SQL_INLINE_TABLE_VALUED_FUNCTION'', N''SQL_TABLE_VALUED_FUNCTION''))
        AND 
        (
            (o.name COLLATE database_default LIKE @searchStr COLLATE database_default)
            OR
            (
                @searchInDefinition =1
                AND
                (
                    m.definition COLLATE database_default LIKE @searchStr COLLATE database_default
                )
            )
        )
');

--Scalar Functions
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType IN (N'SQL_SCALAR_FUNCTION'))
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'SQL Scalar Functions', @noPoFieldsSql +
N'
        ,@basePath + N''\Programmability\Functions\Scalar-valued Functions\'' + QUOTENAME(SCHEMA_NAME(o.schema_id)) + N''.'' AS [ObjectPath]
        ,(
            SELECT
                [object].*
                ,(SELECT * FROM sys.parameters [parameter] WHERE [parameter].object_id = [object].[object_id] ORDER BY parameter_id FOR XML AUTO, ROOT(N''parameters''), TYPE)
                ,CONVERT(xml, STUFF(
                (SELECT 
                    N'' '' + x.value(N''local-name(.)'', N''nvarchar(max)'') + N''="'' + x.value(N''.'', N''nvarchar(max)'') + N''"''
                FROM
                (SELECT CONVERT(xml, (SELECT * from sys.sql_modules [module] WHERE object_id = [object].object_id FOR XML AUTO)) AS XmlData) M
                CROSS APPLY XmlData.nodes(N''/*/@*'') a(x)
                WHERE x.value(N''local-name(.)'', N''nvarchar(max)'') <> N''definition''
                FOR XML PATH(N'''')), 1, 1, N''<module '') + N''/>'')
                ,CONVERT(xml, N''<?definition --'' + NCHAR(13) + NCHAR(10) + REPLACE(REPLACE(definition, N''<?'', N''''), N''?>'', N'''') + NCHAR(13) + NCHAR(10) + N''--?>'')
            FROM sys.objects [object]
            INNER JOIN sys.sql_modules  [module] ON [module].object_id = [object].object_id
            WHERE [object].object_id = o.object_id
            FOR XML AUTO, TYPE							
            )               AS [ObjectDetails]
    FROM sys.objects o
    LEFT JOIN sys.sql_modules m ON m.object_id = o.object_id
    WHERE
        o.[type] COLLATE Latin1_General_CI_AS = N''FN'' COLLATE Latin1_General_CI_AS
        AND 
        (
            (o.name COLLATE database_default LIKE @searchStr COLLATE database_default)
            OR
            (
                @searchInDefinition =1
                AND
                (
                    m.definition COLLATE database_default LIKE @searchStr COLLATE database_default
                )
            )
        )
');

--CLR Scalar Functions and aggregates
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType IN (N'AGGREGATE_FUNCTION', N'CLR_SCALAR_FUNCTION'))
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'CLR Scalar and Aggregate Functions', @noPoFieldsSql +
N'
        ,@basePath
            + N''\Programmability\Functions\'' + CASE WHEN o.[type] = N''AF'' THEN N''Aggregate Functions\'' ELSE N''Scalar-valued Functions\'' END
            + QUOTENAME(SCHEMA_NAME(o.schema_id)) + N''.'' AS [ObjectPath]
        ,(
            SELECT
                [object].*
                ,[assemblyModule].*
                ,CONVERT(xml, (SELECT * FROM sys.parameters [parameter] WHERE [parameter].object_id = [object].[object_id] ORDER BY parameter_id FOR XML AUTO, ROOT(N''parameters'')))
            FROM sys.objects [object]
            INNER JOIN sys.assembly_modules  [assemblyModule] ON [assemblyModule].object_id = [object].object_id
            WHERE [object].object_id = o.object_id
            FOR XML AUTO, TYPE							
            )               AS [ObjectDetails]
    FROM sys.objects o
    LEFT JOIN sys.assembly_modules am ON am.object_id = o.object_id
    WHERE
        o.[type] COLLATE Latin1_General_CI_AS IN (SELECT [Type] FROM #objTypes WHERE ObjectType IN (N''AGGREGATE_FUNCTION'', N''CLR_SCALAR_FUNCTION''))
        AND 
        (
            (o.name COLLATE database_default LIKE @searchStr COLLATE database_default)
            OR
            (
                @searchInDefinition =1
                AND
                (
                    am.assembly_class COLLATE database_default LIKE @searchStr COLLATE database_default
                    OR
                    am.assembly_method COLLATE database_default LIKE @searchStr COLLATE database_default
                )
            )
        )
');

--CLR Table Functions
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType IN (N'CLR_TABLE_VALUED_FUNCTION'))
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'CLR Table Valued Functions', @noPoFieldsSql +
N'
        ,@basePath
            + N''\Programmability\Functions\Table-valued Functions\'' 
            + QUOTENAME(SCHEMA_NAME(o.schema_id)) + N''.'' AS [ObjectPath]
        ,(
            SELECT
                [object].*
                ,[assemblyModule].*
                ,(SELECT * FROM sys.parameters [parameter] WHERE [parameter].object_id = [object].[object_id] ORDER BY parameter_id FOR XML AUTO, ROOT(N''parameters''), TYPE)
                ,(SELECT * FROM sys.columns [column] WHERE [column].object_id = [object].[object_id] ORDER BY column_id FOR XML AUTO, ROOT(N''columns''), TYPE)
            FROM sys.objects [object]
            INNER JOIN sys.assembly_modules  [assemblyModule] ON [assemblyModule].object_id = [object].object_id
            WHERE [object].object_id = o.object_id
            FOR XML AUTO, TYPE
            )               AS [ObjectDetails]
    FROM sys.objects o
    LEFT JOIN sys.assembly_modules am ON am.object_id = o.object_id
    WHERE
        o.type COLLATE Latin1_General_CI_AS = N''FS'' COLLATE Latin1_General_CI_AS
        AND 
        (
            (o.name COLLATE database_default LIKE @searchStr COLLATE database_default)
            OR
            (
                @searchInDefinition =1
                AND
                (
                    am.assembly_class COLLATE database_default LIKE @searchStr COLLATE database_default
                    OR
                    am.assembly_method COLLATE database_default LIKE @searchStr COLLATE database_default
                )
            )
        )
');

--CLR Stored Procedures
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType IN (N'CLR_STORED_PROCEDURE'))
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'CLR Stored Procedures', @noPoFieldsSql +
N'
        ,@basePath
            + N''\Programmability\Stored Procedures\'' + CASE WHEN o.is_ms_shipped = 1 THEN N''\System Stored Procedures\'' ELSE N'''' END
            + QUOTENAME(SCHEMA_NAME(o.schema_id)) + N''.'' AS [ObjectPath]
        ,(
            SELECT
                [object].*
                ,[procedure].*
                ,[assemblyModule].*
                ,(SELECT * FROM sys.parameters [parameter] WHERE [parameter].object_id = [object].[object_id] ORDER BY parameter_id FOR XML AUTO, ROOT(N''parameters''), TYPE)
            FROM sys.objects [object]
            LEFT JOIN sys.procedures [procedure] ON [procedure].object_id = [object].object_id
            INNER JOIN sys.assembly_modules  [assemblyModule] ON [assemblyModule].object_id = [object].object_id
            WHERE [object].object_id = o.object_id
            FOR XML AUTO, TYPE							
            )               AS [ObjectDetails]
    FROM sys.objects o
    LEFT JOIN sys.assembly_modules am ON am.object_id = o.object_id
    WHERE
        o.[type] COLLATE Latin1_General_CI_AS = N''PC'' COLLATE Latin1_General_CI_AS
        AND 
        (
            (o.name COLLATE database_default LIKE @searchStr COLLATE database_default)
            OR
            (
                @searchInDefinition =1
                AND
                (
                    am.assembly_class COLLATE database_default LIKE @searchStr COLLATE database_default
                    OR
                    am.assembly_method COLLATE database_default LIKE @searchStr COLLATE database_default
                )
            )
        )
');

--CLR Database Triggers
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType IN (N'CLR_DATABASE_TRIGGER'))
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'CLR Triggers', @fieldsSql +
N'
        ,@basePath
            + CASE 
                WHEN po.type IN (''S'', ''IT'') OR (o.type = ''U'' AND o.is_ms_shipped = 1) THEN N''\Tables\System Tables\''
                WHEN po.type = ''U'' THEN N''\Tables\''
                WHEN po.type = ''V'' AND o.is_ms_shipped = 1 THEN N''\Views\System Views\'' 
                WHEN po.type = ''V'' THEN N''\Views\'' 
               END + QUOTENAME(SCHEMA_NAME(po.schema_id)) + N''.'' + QUOTENAME(po.name) +  N''\Triggers''         
            AS [ObjectPath]
        ,(
            SELECT
                [object].*
                ,[trigger].*
                ,[assemblyModule].*
            FROM sys.objects [object]
            LEFT JOIN sys.triggers [trigger] ON [trigger].object_id = [object].object_id
            INNER JOIN sys.assembly_modules  [assemblyModule] ON [assemblyModule].object_id = [object].object_id
            WHERE [object].object_id = o.object_id
            FOR XML AUTO, TYPE							
            )               AS [ObjectDetails]
    FROM sys.objects o
    INNER JOIN sys.objects po ON po.object_id = o.parent_object_id
    LEFT JOIN sys.assembly_modules am ON am.object_id = o.object_id
    WHERE
        o.type COLLATE Latin1_General_CI_AS = N''TA'' COLLATE Latin1_General_CI_AS
        AND 
        (
            (o.name COLLATE database_default LIKE @searchStr COLLATE database_default)
            OR
            (
                @searchInDefinition =1
                AND
                (
                    am.assembly_class COLLATE database_default LIKE @searchStr COLLATE database_default
                    OR
                    am.assembly_method COLLATE database_default LIKE @searchStr COLLATE database_default
                )
            )
        )
');

--SQL Stored Procedures
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType IN (N'SQL_STORED_PROCEDURE', N'REPLICATION_FILTER_PROCEDURE'))
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'SQL Stored Procedures', @noPoFieldsSql +
N'
    ,@basePath
        + N''\Programmability\Stored Procedures\'' + CASE WHEN o.is_ms_shipped = 1 THEN N''\System Stored Procedures\'' ELSE N'''' END
        + QUOTENAME(SCHEMA_NAME(o.schema_id)) + N''.'' AS [ObjectPath]
    ,(
            SELECT
                [object].*
                ,[procedure].*
                ,(SELECT * FROM sys.parameters [parameter] WHERE [parameter].object_id = [object].[object_id] ORDER BY parameter_id FOR XML AUTO, ROOT(N''parameters''), TYPE)
                ,CONVERT(xml, STUFF(
                (SELECT 
                    N'' '' + x.value(N''local-name(.)'', N''nvarchar(max)'') + N''="'' + x.value(N''.'', N''nvarchar(max)'') + N''"''
                FROM
                (SELECT CONVERT(xml, (SELECT * from sys.sql_modules [module] WHERE object_id = [object].object_id FOR XML AUTO)) AS XmlData) M
                CROSS APPLY XmlData.nodes(N''/*/@*'') a(x)
                WHERE x.value(''local-name(.)'', ''nvarchar(max)'') <> N''definition''
                FOR XML PATH(N'''')), 1, 1, N''<module '') + N''/>'')
                ,CONVERT(xml, N''<?definition --'' + NCHAR(13) + NCHAR(10) + REPLACE(REPLACE(definition, N''<?'', N''''), N''?>'', N'''') + NCHAR(13) + NCHAR(10) + N''--?>'')
            FROM sys.objects [object]
            INNER JOIN sys.procedures [procedure] ON [procedure].object_id = [object].object_id
            INNER JOIN sys.sql_modules  [module] ON [module].object_id = [object].object_id
            WHERE [object].object_id = o.object_id
            FOR XML AUTO, TYPE							
            )               AS [ObjectDetails]
    FROM sys.objects o
    LEFT JOIN sys.sql_modules m ON m.object_id = o.object_id
    WHERE
        o.[type] COLLATE Latin1_General_CI_AS IN (SELECT [Type] FROM #objTypes WHERE ObjectType IN (N''SQL_STORED_PROCEDURE'', N''REPLICATION_FILTER_PROCEDURE''))
        AND 
        (
            (o.name COLLATE database_default LIKE @searchStr COLLATE database_default)
            OR
            (
                @searchInDefinition =1
                AND
                (
                    m.definition COLLATE database_default LIKE @searchStr COLLATE database_default
                )
            )
        )
');

--Primary Key and Unique Constraints
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType IN (N'PRIMARY_KEY_CONSTRAINT', N'UNIQUE_CONSTRAINT'))
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'Primary and Unique Key Constraints', 
N'SELECT --Schema Bound Objects
        DB_NAME() COLLATE database_default                                  AS [DatabaseName]
        ,CASE WHEN o.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
        ,o.type_desc COLLATE database_default                               AS [ObjectType]
        ,o.object_id                                                        AS [ObjectID]
        ,SCHEMA_NAME(o.schema_id)                                           AS [ObjectSchema]
        ,o.name COLLATE database_default                                    AS [ObjectName]
        ,po.type_desc COLLATE database_default                              AS [ParentObjectType]
        ,po.object_id                                                       AS [ParentObjectID]
        ,SCHEMA_NAME(po.schema_id) COLLATE database_default                 AS [ParentObjectSchema]
        ,po.name COLLATE database_default                                   AS [ParentObjectName]
        ,o.create_date                                                      AS [ObjectCreationDate]
        ,o.modify_date                                                      AS [ObjectModifyDate]
        ,@basePath + N''\Tables\'' + QUOTENAME(SCHEMA_NAME(po.schema_id)) + N''.'' + QUOTENAME(po.name) + N''\Keys'' AS [ObjectPath]
        ,(
            SELECT
                [object].*
                ,[keyConstraint].*
                ,[index].*
                , 
                    (SELECT 
                        *
                    FROM sys.index_columns [indexColumn] 
                    INNER JOIN sys.columns [column] ON [column].object_id = [indexColumn].object_id AND [column].column_id = [indexColumn].column_id
                    WHERE [indexColumn].object_id = [index].[object_id] AND [indexColumn].index_id = [index].index_id
                    ORDER BY [indexColumn].index_column_id 
                    FOR XML AUTO, ROOT(''indexColumns''), TYPE)
            FROM sys.objects [object]
            INNER JOIN sys.key_constraints [keyConstraint] ON [keyConstraint].object_id = [object].object_id
            INNER JOIN sys.indexes [index] ON [index].object_id = [object].parent_object_id AND [index].index_id = [keyConstraint].unique_index_id
            WHERE [object].object_id = o.object_id
            FOR XML AUTO, TYPE							
            )               AS [ObjectDetails]
    FROM sys.objects o
    INNER JOIN sys.objects po ON po.object_id = o.parent_object_id
    WHERE
        o.[type] COLLATE Latin1_General_CI_AS IN (SELECT [Type] FROM #objTypes WHERE ObjectType IN (N''PRIMARY_KEY_CONSTRAINT'', N''UNIQUE_CONSTRAINT''))
        AND 
        (
            (o.name COLLATE database_default LIKE @searchStr COLLATE database_default)
        )
');

--Rules
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType = N'RULE')
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'Rules', @noPoFieldsSql +
N'
    ,@basePath + N''\Programmability\Rules\'' + QUOTENAME(SCHEMA_NAME(o.schema_id)) + N''.'' AS [ObjectPath]
    ,(
            SELECT
                [object].*
            FROM sys.objects [object]
            WHERE [object].object_id = o.object_id
            FOR XML AUTO, TYPE
            )               AS [ObjectDetails]
    FROM sys.objects o
    WHERE
        o.[type] COLLATE Latin1_General_CI_AS = ''R'' COLLATE Latin1_General_CI_AS
        AND 
        o.name COLLATE database_default LIKE @searchStr COLLATE database_default
');

--Synonyms
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType = N'SYNONYM')
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'Synonyms', @noPoFieldsSql +
N'
    ,@basePath + N''\Synonyms\'' + QUOTENAME(SCHEMA_NAME(o.schema_id)) + N''.'' AS [ObjectPath]
    ,(
            SELECT
                [object].*
                ,[synonym].*
            FROM sys.objects [object]
            INNER JOIN sys.synonyms [synonym] ON [synonym].object_id = [object].object_id
            WHERE [object].object_id = o.object_id
            FOR XML AUTO, TYPE
            )               AS [ObjectDetails]
    FROM sys.objects o
    WHERE
        o.[type] COLLATE Latin1_General_CI_AS = ''SN'' COLLATE Latin1_General_CI_AS
        AND 
        o.name COLLATE database_default LIKE @searchStr COLLATE database_default
');

--Table Types
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType = N'TABLE_TYPE')
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'Table Types',
N'SELECT --Table Type
    DB_NAME() COLLATE database_default                      AS [DatabaseName]
    ,CASE WHEN t.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
    ,N''TYPE''                                                AS [ObjectType]
    ,t.user_type_id                                         AS [ObjectID]
    ,SCHEMA_NAME(t.schema_id)	COLLATE database_default    AS [ObjectSchema]
    ,t.name COLLATE database_default                        AS [ObjectName]
    ,N''SCHEMA''                                              AS [ParentObjectType]
    ,t.schema_id                                            AS [ParentObjectID]
    ,NULL                                                   AS [ParentObjectSchema]
    ,SCHEMA_NAME(t.schema_id)                               AS [ParentObjectName]
    ,NULL                                                   AS [ObjectCreationDate]
    ,NULL                                                   AS [ObjectModifyDate]	
    ,@basePath + N''\Programmability\Types\User-Defined Table Types\'' + QUOTENAME(SCHEMA_NAME(t.schema_id))  AS [ObjectPath]
        ,(
            SELECT 
                 [type].*
                ,[tableType].*
                ,[object].*
                , 
                    (SELECT 
                        [column].* 
                        ,CONVERT(xml, STUFF(
                        (SELECT 
                            N'' '' + x.value(N''local-name(.)'', N''nvarchar(max)'') + N''="'' + x.value(N''.'', N''nvarchar(max)'') + N''"''
                        FROM
                        (SELECT CONVERT(xml, (SELECT * from sys.computed_columns [computedColumn] WHERE object_id = [object].object_id AND column_id = [column].column_id FOR XML AUTO)) AS XmlData) M
                        CROSS APPLY XmlData.nodes(N''/*/@*'') a(x)
                        WHERE x.value(N''local-name(.)'', N''nvarchar(max)'') <> N''definition''
                        FOR XML PATH(N'''')), 1, 1, N''<computedColumn '') + N''/>'') 

                        ,CONVERT(xml, N''<?definition --'' + REPLACE(REPLACE(definition, N''<?'', N''''), N''?>'', N'''') + N''--?>'') -- computed column definition

                        FROM sys.columns [column] 
                        LEFT JOIN sys.computed_columns cc ON cc.object_id = [column].object_id AND cc.column_id = [column].column_id
                        WHERE [column].object_id = [object].[object_id] ORDER BY column_id FOR XML AUTO, ROOT(N''columns''), TYPE
                    )
            FROM sys.objects [object]
            INNER JOIN sys.table_types [tableType] ON [tableType].type_table_object_id = [object].object_id
            INNER JOIN sys.types [type] ON [type].user_type_id = [tableType].user_type_id
            WHERE [object].object_id = tt.type_table_object_id
            FOR XML AUTO, TYPE
            )                                               AS [ObjectDetails]

FROM sys.types t
INNER JOIN sys.table_types tt ON t.user_type_id = tt.user_type_id
WHERE
    t.name COLLATE database_default LIKE @searchStr COLLATE database_default
    AND
    t.is_user_defined = 1
    and
    t.is_table_type = 1
');

--Extended Stored Procedures
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType = N'EXTENDED_STORED_PROCEDURE')
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'Extended Stored Procedures', @noPoFieldsSql +
N'
    ,@basePath + N''\Programmability\Stored Procedures\System Stored Procedures\'' + QUOTENAME(SCHEMA_NAME(o.schema_id)) + N''.'' AS [ObjectPath]
    ,(
            SELECT
                [object].*
            FROM sys.all_objects [object]
            WHERE [object].object_id = o.object_id
            FOR XML AUTO, TYPE
            )               AS [ObjectDetails]
    FROM sys.all_objects o
    WHERE
        DB_NAME() = ''master''
        AND
        o.[type] COLLATE Latin1_General_CI_AS = ''X'' COLLATE Latin1_General_CI_AS
        AND 
        o.name COLLATE database_default LIKE @searchStr COLLATE database_default
');

--Service Queues
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType = N'SERVICE_QUEUE')
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'Service Queues', @noPoFieldsSql +
N'
    ,@basePath + N''\Service Broker\Queues'' + CASE WHEN o.is_ms_shipped = 1 THEN N''\System Queues'' ELSE N'''' END AS [ObjectPath]
    ,(
            SELECT
                [object].*
                ,[serviceQueue].*
            FROM sys.objects [object]
            INNER JOIN sys.service_queues [serviceQueue] ON [serviceQueue].object_id = [object].object_id
            WHERE [object].object_id = o.object_id
            FOR XML AUTO, TYPE
            )               AS [ObjectDetails]
    FROM sys.objects o
    WHERE
        o.[type] COLLATE Latin1_General_CI_AS = ''SQ'' COLLATE Latin1_General_CI_AS
        AND 
        o.name COLLATE database_default LIKE @searchStr COLLATE database_default
');

--Sequences
IF @versionNumber >= 11000000000000000 AND EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType = N'SEQUENCE_OBJECT')
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'Sequences', @noPoFieldsSql +
N'
    ,@basePath + N''\Programmability\Sequences\'' + QUOTENAME(SCHEMA_NAME(o.schema_id)) + N''.'' AS [ObjectPath]
    ,(
            SELECT
                [object].*
                ,[sequence].*
            FROM sys.objects [object]
            INNER JOIN sys.sequences [sequence] ON [sequence].object_id = [object].object_id
            WHERE [object].object_id = o.object_id
            FOR XML AUTO, TYPE
            )               AS [ObjectDetails]
    FROM sys.objects o
    WHERE
        o.[type] COLLATE Latin1_General_CI_AS = ''SO'' COLLATE Latin1_General_CI_AS
        AND 
        o.name COLLATE database_default LIKE @searchStr COLLATE database_default
');


--Internal Tables
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType = N'INTERNAL_TABLE')
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'Internal Tables', @fieldsSql +
N'
        ,N''''                                                              AS [ObjectPath]
        ,(
            SELECT 
                [object].*
                ,[iternalTable].*
                ,
                    (SELECT 
                        [column].* 
                        ,CONVERT(xml, STUFF(
                        (SELECT 
                            N'' '' + x.value(N''local-name(.)'', N''nvarchar(max)'') + N''="'' + x.value(N''.'', N''nvarchar(max)'') + N''"''
                    FROM
                    (SELECT (SELECT * from sys.computed_columns [computedColumn] WHERE object_id = [object].object_id AND column_id = [column].column_id FOR XML AUTO, TYPE) AS XmlData) M
                    CROSS APPLY XmlData.nodes(N''/*/@*'') a(x)
                    WHERE x.value(N''local-name(.)'', N''nvarchar(max)'') <> N''definition''
                    FOR XML PATH(N'''')), 1, 1, N''<computedColumn '') + N''/>'') 

                    ,CONVERT(xml, N''<?definition --'' + REPLACE(REPLACE(definition, N''<?'', N''''), N''?>'', N'''') + N''--?>'')
                    FROM sys.columns [column] 
                    LEFT JOIN sys.computed_columns cc ON cc.object_id = [column].object_id AND cc.column_id = [column].column_id
                    WHERE [column].object_id = [object].[object_id] ORDER BY column_id FOR XML AUTO, ROOT(''columns''), TYPE)
            FROM sys.objects [object]
            INNER JOIN sys.internal_tables [iternalTable] ON [iternalTable].object_id = [object].object_id
            WHERE [object].object_id = o.object_id 
            FOR XML AUTO, TYPE
            )               AS [ObjectDetails]
    FROM sys.all_objects o
    LEFT JOIN sys.all_objects po on po.object_id = o.parent_object_id
    WHERE
        o.type COLLATE Latin1_General_CI_AS = ''IT'' COLLATE Latin1_General_CI_AS
        AND 
        o.name COLLATE database_default LIKE @searchStr COLLATE database_default
');


--System Tables
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType = N'SYSTEM_TABLE')
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'System Tables', @noPoFieldsSql +
N'
    ,@basePath + N''\Tables\System Tables\'' + QUOTENAME(SCHEMA_NAME(o.schema_id)) + N''.'' AS [ObjectPath]
    ,(
            SELECT 
                [object].*
                ,
                    (SELECT 
                        [column].* 
                        ,CONVERT(xml, STUFF(
                        (SELECT 
                            N'' '' + x.value(N''local-name(.)'', N''nvarchar(max)'') + N''="'' + x.value(N''.'', N''nvarchar(max)'') + N''"''
                        FROM
                        (SELECT (SELECT * from sys.computed_columns [computedColumn] WHERE object_id = [object].object_id AND column_id = [column].column_id FOR XML AUTO, TYPE) AS XmlData) M
                        CROSS APPLY XmlData.nodes(N''/*/@*'') a(x)
                        WHERE x.value(N''local-name(.)'', N''nvarchar(max)'') <> N''definition''
                        FOR XML PATH(N'''')), 1, 1, N''<computedColumn '') + N''/>'') 
                        ,CONVERT(xml, N''<?definition --'' + REPLACE(REPLACE(definition, N''<?'', N''''), N''?>'', N'''') + N''--?>'') -- computed column definition
                        FROM sys.all_columns [column] 
                        LEFT JOIN sys.computed_columns cc ON cc.object_id = [column].object_id AND cc.column_id = [column].column_id
                        WHERE [column].object_id = [object].[object_id] ORDER BY column_id FOR XML AUTO, ROOT(N''columns''), TYPE)
            FROM sys.objects [object]
            WHERE [object].object_id = o.object_id 
            FOR XML AUTO, TYPE
            )               AS [ObjectDetails]
    FROM sys.all_objects o
    WHERE
        o.[type] COLLATE Latin1_General_CI_AS = ''S'' COLLATE Latin1_General_CI_AS
        AND 
        o.name COLLATE database_default LIKE @searchStr COLLATE database_default
');

--SQL Database Triggers
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType IN (N'SQL_DATABASE_TRIGGER'))
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'SQL Triggers',
N'SELECT --Schema Bound Objects
        DB_NAME() COLLATE database_default                                  AS [DatabaseName]
        ,CASE WHEN o.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
        ,o.type_desc COLLATE database_default                               AS [ObjectType]
        ,o.object_id                                                        AS [ObjectID]
        ,SCHEMA_NAME(o.schema_id)                                           AS [ObjectSchema]
        ,o.name COLLATE database_default                                    AS [ObjectName]
        ,ISNULL(po.type_desc, ''SCHEMA'') COLLATE database_default          AS [ParentObjectType]
        ,po.object_id                                                       AS [ParentObjectID]
        ,SCHEMA_NAME(po.schema_id) COLLATE database_default                 AS [ParentObjectSchema]
        ,po.name COLLATE database_default                                   AS [ParentObjectName]
        ,o.create_date                                                      AS [ObjectCreationDate]
        ,o.modify_date                                                      AS [ObjectModifyDate]
    ,@basePath
        + CASE 
            WHEN po.type IN (''S'', ''IT'') OR (o.type = ''U'' AND o.is_ms_shipped = 1) THEN N''\Tables\System Tables\''
            WHEN po.type = ''U'' THEN N''\Tables\''
            WHEN po.type = ''V'' AND o.is_ms_shipped = 1 THEN N''\Views\System Views\'' 
            WHEN po.type = ''V'' THEN N''\Views\'' 
           END + QUOTENAME(SCHEMA_NAME(po.schema_id)) + N''.'' + QUOTENAME(po.name) +  N''\Triggers''         
        AS [ObjectPath]
    ,(
            SELECT
                [object].*
                ,[trigger].*
                ,CONVERT(xml, STUFF(
                (SELECT 
                    N'' '' + x.value(N''local-name(.)'', N''nvarchar(max)'') + N''="'' + x.value(N''.'', N''nvarchar(max)'') + N''"''
                FROM
                (SELECT CONVERT(xml, (SELECT * from sys.sql_modules [module] WHERE object_id = [object].object_id FOR XML AUTO)) AS XmlData) M
                CROSS APPLY XmlData.nodes(N''/*/@*'') a(x)
                WHERE x.value(N''local-name(.)'', N''nvarchar(max)'') <> N''definition''
                FOR XML PATH(N'''')), 1, 1, N''<module '') + N''/>'')
                ,CONVERT(xml, N''<?definition --'' + NCHAR(13) + NCHAR(10) + REPLACE(REPLACE(definition, N''<?'', N''''), N''?>'', N'''') + NCHAR(13) + NCHAR(10) + N''--?>'')
            FROM sys.objects [object]
            INNER JOIN sys.triggers [trigger] ON [trigger].object_id = [object].object_id
            INNER JOIN sys.sql_modules  [module] ON [module].object_id = [object].object_id
            WHERE [object].object_id = o.object_id
            FOR XML AUTO, TYPE
            )               AS [ObjectDetails]
    FROM sys.objects o
    INNER JOIN sys.objects po ON po.object_id = o.parent_object_id
    LEFT JOIN sys.sql_modules m ON m.object_id = o.object_id
    WHERE
        o.[type] COLLATE Latin1_General_CI_AS = N''TR'' COLLATE Latin1_General_CI_AS
        AND 
        (
            (o.name COLLATE database_default LIKE @searchStr COLLATE database_default)
            OR
            (
                @searchInDefinition =1
                AND
                (
                    m.definition COLLATE database_default LIKE @searchStr COLLATE database_default
                )
            )
        )
');

--Columns
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType IN (N'COLUMN', N'SYSTEM_COLUMN', N'SYSTEM_OBJECT'))
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'Columns',
N'SELECT --Columns
    DB_NAME() COLLATE database_default                  AS [DatabaseName]
    ,CASE WHEN c.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
    ,N''COLUMN'' /*+ o.type_desc*/                      AS [ObjectType]
    ,c.column_id                                        AS [ObjectID]
    ,NULL                                               AS [ObjectSchema]
    ,c.name COLLATE database_default                    AS [ObjectName]
    ,o.type_desc                                        AS [ParentObjectType]
    ,o.object_id                                        AS [ParentObjectID]
    ,SCHEMA_NAME(o.schema_id) COLLATE database_default  AS [ParentObjectSchema]
    ,o.name COLLATE database_default                    AS [ParentObjectName]
    ,o.create_date                                      AS [ObjectCreationDate]
    ,o.modify_date                                      AS [ObjectModifyDate]
    ,@basePath
        + CASE 
            WHEN o.type IN (''S'', ''IT'') OR (o.type = ''U'' AND o.is_ms_shipped = 1) THEN N''\Tables\System Tables\''
            WHEN o.type = ''U'' THEN N''\Tables\''
            WHEN o.type = ''V'' AND o.is_ms_shipped = 1 THEN N''\Views\System Views\'' 
            WHEN o.type = ''V'' THEN N''\Views\'' 
            WHEN o.type IN (''IF'', ''TF'', ''FT'') THEN N''\Programmability\Functions\Table-valued Functions\''
           END + QUOTENAME(SCHEMA_NAME(o.schema_id)) + N''.'' + QUOTENAME(o.name) +  N''\Columns''         
        AS [ObjectPath]
    ,(SELECT 
        [column].* 
        ,CONVERT(xml, STUFF(
        (SELECT 
            N'' '' + x.value(N''local-name(.)'', N''nvarchar(max)'') + N''="'' + x.value(N''.'', N''nvarchar(max)'') + N''"''
        FROM
        (SELECT (SELECT * from sys.computed_columns [computedColumn] WHERE object_id = [column].object_id AND column_id = [column].column_id FOR XML AUTO, TYPE) AS XmlData) M
        CROSS APPLY XmlData.nodes(N''/*/@*'') a(x)
        WHERE x.value(N''local-name(.)'', N''nvarchar(max)'') <> N''definition''
        FOR XML PATH(N'''')), 1, 1, N''<computedColumn '') + N''/>'') 
        ,CONVERT(xml, N''<?definition --'' + REPLACE(REPLACE(definition, N''<?'', N''''), N''?>'', N'''') +  N''--?>'') -- computed column definition
        FROM sys.columns [column] 
        LEFT JOIN sys.computed_columns cc ON cc.object_id = [column].object_id AND cc.column_id = [column].column_id
        WHERE [column].object_id = c.[object_id] AND [column].column_id = c.column_id ORDER BY column_id 
        FOR XML AUTO, TYPE)
                                        AS [ObjectDetails]
FROM sys.all_columns c
INNER JOIN sys.all_objects o ON o.object_id = c.object_id
LEFT JOIN sys.computed_columns cc ON cc.object_id = c.object_id AND cc.column_id = c.column_id
WHERE
    ((o.type NOT IN (''S'', ''IT'') AND o.is_ms_shipped = 0) OR EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType IN (N''SYSTEM_COLUMN'', N''SYSTEM_OBJECT'')))
    AND 
    (
        (c.name COLLATE database_default LIKE @searchStr COLLATE database_default)
        OR
        (
            @searchInDefinition =1
            AND
            cc.definition COLLATE database_default LIKE @searchStr COLLATE database_default
        )
    )	
');

--Indexes
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType IN (SELECT ObjectType FROM #typesMapping WHERE ParentObjectType = N'INDEX'))
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'Indexes',
N'SELECT --Indexes
    DB_NAME() COLLATE database_default                  AS [DatabaseName]
    ,CASE WHEN i.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
    ,N''INDEX_'' + i.type_desc COLLATE database_default AS [ObjectType]
    ,i.index_id                                         AS [ObjectID]
    ,NULL                                               AS [ObjectSchema]
    ,i.name COLLATE database_default                    AS [ObjectName]
    ,o.type_desc COLLATE database_default               AS [ParentObjectType]
    ,i.object_id                                        AS [ParentObjectID]
    ,SCHEMA_NAME(o.schema_id) COLLATE database_default  AS [ParentObjectSchema]
    ,o.name COLLATE database_default                    AS [ParentObjectName]
    ,NULL                                               AS [ObjectCreationDate]
    ,NULL                                               AS [ObjectModifyDate]
    ,@basePath + CASE WHEN o.type = ''V'' THEN N''\Views\'' ELSE N''\Tables\'' END + QUOTENAME(SCHEMA_NAME(o.schema_id)) + N''.'' + QUOTENAME(o.name) +  N''\Indexes'' AS [ObjectPath]
    ,(
        SELECT
            [index].*
            ,
                (SELECT 
                    *
                FROM sys.index_columns [indexColumn] 
                INNER JOIN sys.columns [column] ON [column].object_id = [indexColumn].object_id AND [column].column_id = [indexColumn].column_id
                WHERE [indexColumn].object_id = [index].[object_id] AND [indexColumn].index_id = [index].index_id
                ORDER BY [indexColumn].index_column_id 
                FOR XML AUTO, ROOT(''indexColumns''), TYPE)
        FROM sys.indexes [index]
        WHERE [index].object_id = i.object_id AND [index].index_id = i.index_id
        FOR XML AUTO, TYPE)
                                       AS [ObjectDetails]
FROM sys.indexes i
LEFT JOIN sys.objects o ON o.object_id = i.object_id
WHERE
    o.type NOT IN (N''S'', N''IT'')
    AND i.index_id > 0	--Do not include HEAP
    AND i.type IN (SELECT CONVERT(smallint, [Type]) FROM #objTypes WHERE ObjectType LIKE ''INDEX_%'')
    AND 
    (
        (i.name COLLATE database_default LIKE @searchStr COLLATE database_default)
        OR
        (
            @searchInDefinition = 1
            AND
            EXISTS(
                SELECT 1
                FROM sys.index_columns ic
                LEFT JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
                WHERE ic.object_id = i.object_id and ic.index_id = i.index_id AND c.name COLLATE database_default LIKE @searchStr COLLATE database_default
            )
        )
    )');

--Schemas
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType = N'SCHEMA')
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'Schemas',
N'SELECT --Schemas
    DB_NAME() COLLATE database_default  AS [DatabaseName]
    ,CASE WHEN s.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
    ,N''SCHEMA''                        AS [ObjectType]
    ,s.schema_id                        AS [ObjectID]
    ,NULL                               AS [ObjectSchema]
    ,s.name COLLATE database_default    AS [ObjectName]
    ,N''DATABASE''                      AS [ParentObjectType]
    ,DB_ID()                            AS [ParentObjectID]
    ,NULL                               AS [ParentObjectSchema]
    ,DB_NAME() COLLATE database_default AS [ParentObjectName]
    ,NULL                               AS [ObjectCreationDate]
    ,NULL                               AS [ObjectModifyDate]
    ,@basePath + N''\Security\Schemas'' AS [ObjectPath]
    ,(SELECT * FROM sys.schemas [schema] WHERE schema_id = s.schema_id FOR XML AUTO, TYPE)
                                        AS [ObjectDetails]
FROM sys.schemas s
WHERE
    s.name COLLATE database_default LIKE @searchStr COLLATE database_default
');

--database_principals
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType IN (SELECT ObjectType FROM #typesMapping WHERE ParentObjectType = N'DATABASE_PRINCIPAL'))
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'database_principals',
N'SELECT --database_principals
    DB_NAME() COLLATE database_default  AS [DatabaseName]
    ,CASE WHEN dp.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
    ,dp.type_desc                       AS [ObjectType]
    ,dp.principal_id                    AS [ObjectID]
    ,NULL                               AS [ObjectSchema]
    ,dp.name COLLATE database_default   AS [ObjectName]
    ,N''DATABASE''                      AS [ParentObjectType]
    ,DB_ID()                            AS [ParentObjectID]
    ,NULL                               AS [ParentObjectSchema]
    ,DB_NAME() COLLATE database_default AS [ParentObjectName]
    ,dp.create_date                     AS [ObjectCreationDate]
    ,dp.modify_date                     AS [ObjectModifyDate]
    ,@basePath + N''\Security\'' + CASE dp.type WHEN ''R'' THEN N''Roles\Database Roles'' WHEN ''A'' THEN N''Roles\Application Roles'' ELSE N''Users'' END AS [ObjectPath]
    ,
        (SELECT 
            [databasePrincipal].* 
            ,(
                SELECT 
                    *
                FROM sys.database_role_members [roleMember] 
                INNER JOIN sys.database_principals [memberPrincipal] ON [memberPrincipal].principal_id = [roleMember].member_principal_id
                WHERE [roleMember].role_principal_id = [databasePrincipal].[principal_id]
                FOR XML AUTO, ROOT(''roleMembers''), BINARY BASE64, TYPE
            )
        FROM sys.database_principals [databasePrincipal] 
    WHERE [databasePrincipal].principal_id = dp.principal_id
    FOR XML AUTO, BINARY BASE64, TYPE
    )
                    AS [ObjectDetails]
FROM sys.database_principals dp
WHERE
    dp.type COLLATE Latin1_General_CI_AS IN (SELECT [Type] COLLATE Latin1_General_CI_AS FROM #objTypes WHERE ObjectType IN (SELECT ObjectType FROM #typesMapping WHERE ParentObjectType = N''DATABASE_PRINCIPAL''))
    AND 
    dp.name COLLATE database_default LIKE @searchStr COLLATE database_default
');

--Types
IF @objectTypes COLLATE database_default IS NULL OR EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType = N'TYPE')
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'Types',
N'SELECT --Types
    DB_NAME() COLLATE database_default                  AS [DatabaseName]
    ,CASE WHEN t.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
    ,N''TYPE''                                          AS [ObjectType]
    ,t.user_type_id                                     AS [ObjectID]
    ,SCHEMA_NAME(t.schema_id)	COLLATE database_default  AS [ObjectSchema]
    ,t.name COLLATE database_default                    AS [ObjectName]
    ,CASE WHEN st.user_type_id IS NULL THEN N''SCHEMA'' ELSE N''TYPE'' END                                    AS [ParentObjectType]
    ,CASE WHEN st.user_type_id IS NULL THEN t.schema_id ELSE t.system_type_id END                             AS [ParentObjectID]
    ,CASE WHEN st.user_type_id IS NULL THEN NULL ELSE SCHEMA_NAME(st.schema_id) COLLATE database_default END  AS [ParentObjectSchema]
    ,CASE WHEN st.user_type_id IS NULL THEN SCHEMA_NAME(t.schema_id) ELSE st.name END                         AS [ParentObjectName]
    ,NULL                                               AS [ObjectCreationDate]
    ,NULL                                               AS [ObjectModifyDate]	
    ,@basePath + N''\Programmability\Types\'' + CASE WHEN t.is_assembly_type = 1 THEN N''User-Defined Types\'' ELSE N''User-Defined Data Types\'' END + QUOTENAME(SCHEMA_NAME(t.schema_id)) AS [ObjectPath]
    ,(SELECT * FROM sys.types [type] WHERE user_type_id = t.user_type_id FOR XML AUTO, BINARY BASE64, TYPE)
                                                        AS [ObjectDetails]
FROM sys.types t
LEFT JOIN sys.types st ON st.user_type_id = t.system_type_id
WHERE
    t.name COLLATE database_default LIKE @searchStr COLLATE database_default
    AND
    t.is_user_defined = 1
    and
    t.is_table_type = 0
');

--Assemblies
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType = N'ASSEMBLY')
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'Assemblies',
N'SELECT --Assemblies
    DB_NAME() COLLATE database_default              AS [DatabaseName]
    ,CASE WHEN a.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
    ,N''ASSEMBLY''                                  AS [ObjectType]
    ,a.assembly_id                                  AS [ObjectID]
    ,NULL                                           AS [ObjectSchema]
    ,a.name COLLATE database_default                AS [ObjectName]
    ,N''DATABASE''                                  AS [ParentObjectType]
    ,DB_ID()                                        AS [ParentObjectID]
    ,NULL                                           AS [ParentObjectSchema]
    ,DB_NAME() COLLATE database_default             AS [ParentObjectName]
    ,a.create_date                                  AS [ObjectCreationDate]
    ,a.modify_date                                  AS [ObjectModifyDate]
    ,@basePath + N''\Programmability\Assemblies''   AS [ObjectPath]
    ,(
    SELECT
        [assembly].*
        ,(SELECT assembly_id, name, file_id FROM sys.assembly_files [file] WHERE [file].assembly_id = [assembly].assembly_id FOR XML AUTO, ROOT(N''aseemblyFiles''), TYPE)
        ,(SELECT * FROM sys.assembly_modules [module] WHERE [module].assembly_id = [assembly].assembly_id FOR XML AUTO, ROOT(N''assemblyModules''), TYPE)
    FROM sys.assemblies [assembly] 
    WHERE assembly_id = a.assembly_id 
    FOR XML AUTO, TYPE
    )                           AS [ObjectDetails]
FROM sys.assemblies a
WHERE
    (
        (a.name COLLATE database_default LIKE @searchStr COLLATE database_default)
        OR
        (
            @searchInDefinition =1
            AND
            (
                EXISTS (
                    SELECT 1
                    FROM sys.assembly_modules m
                    WHERE 
                        m.assembly_id = a.assembly_id
                        AND
                        (
                            m.assembly_class COLLATE database_default LIKE @searchStr COLLATE database_default
                            OR
                            m.assembly_method COLLATE database_default LIKE @searchStr COLLATE database_default
                        )
                )
                OR
                EXISTS (
                    SELECT 1
                    FROM sys.assembly_files f
                    WHERE
                        f.assembly_id = a.assembly_id
                        AND
                        f.name COLLATE database_default LIKE @searchStr COLLATE database_default
                )
            )
        )
    )	
');

--xml_schema_collections
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType = N'XML_SCHEMA_COLLECTION')
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'xml_schema_collections',
N'SELECT --sys.xml_schema_collections
    DB_NAME() COLLATE database_default                              AS [DatabaseName]
    ,CASE WHEN x.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
    ,N''XML_SCHEMA_COLLECTION''                                     AS [ObjectType]
    ,x.xml_collection_id                                            AS [ObjectID]
    ,SCHEMA_NAME(x.schema_id) COLLATE database_default              AS [ObjectSchema]
    ,x.name COLLATE database_default                                AS [ObjectName]
    ,N''SCHEMA''                                                    AS [ParentObjectType]
    ,x.schema_id                                                    AS [ParentObjectID]
    ,NULL                                                           AS [ParentObjectSchema]
    ,SCHEMA_NAME(x.schema_id) COLLATE database_default              AS [ParentObjectName]
    ,x.create_date                                                  AS [ObjectCreationDate]
    ,x.modify_date                                                  AS [ObjectModifyDate]
    ,@basePath + N''\Programmability\Types\XML Schema Collections'' AS [ObjectPath]
    ,(
    SELECT
        [xmlSchemaCollection].*
        ,(SELECT * FROM sys.xml_schema_namespaces [namespace] WHERE [namespace].xml_collection_id = [xmlSchemaCollection].xml_collection_id FOR XML AUTO, ROOT(N''namespaces''), TYPE)
        ,(SELECT * FROM sys.xml_schema_attributes [attribute] WHERE [attribute].xml_collection_id = [xmlSchemaCollection].xml_collection_id FOR XML AUTO, ROOT(N''attributes''), TYPE)
    FROM sys.xml_schema_collections [xmlSchemaCollection] 
    WHERE xml_collection_id = 1
    FOR XML AUTO, TYPE)                           AS [ObjectDetails]
FROM sys.xml_schema_collections x
WHERE
    x.name COLLATE database_default LIKE @searchStr COLLATE database_default
');

--service_message_types
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType = N'SERVICE_MESSAGE_TYPE')
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'service_message_types',
N'SELECT --sys.service_message_types
    DB_NAME() COLLATE database_default  AS [DatabaseName]
    ,CASE WHEN sm.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
    ,N''SERVICE_MESSAGE_TYPE''          AS [ObjectType]
    ,sm.message_type_id                 AS [ObjectID]
    ,NULL                               AS [ObjectSchema]
    ,sm.name COLLATE database_default   AS [ObjectName]
    ,N''DATABASE''                      AS [ParentObjectType]
    ,DB_ID()                            AS [ParentObjectID]
    ,NULL                               AS [ParentObjectSchema]
    ,DB_NAME() COLLATE database_default AS [ParentObjectName]
    ,NULL                               AS [ObjectCreationDate]
    ,NULL                               AS [ObjectModifyDate]
    ,@basePath + N''\Service Broker\Message Types'' 
        + CASE WHEN sm.message_type_id  <= 65535 THEN N''\System Message Types'' ELSE N'''' END AS [ObjectPath]
    ,(SELECT * FROM sys.service_message_types [serviceMessageType] WHERE [serviceMessageType].message_type_id = sm.message_type_id FOR XML AUTO, BINARY BASE64, TYPE)
                                        AS [ObjectDetails]
FROM sys.service_message_types sm
WHERE
    sm.name COLLATE database_default LIKE @searchStr COLLATE database_default
');

--service_contracts
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType = N'SERVICE_CONTRACT')
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'service_contracts',
N'SELECT --sys.service_contracts
    DB_NAME() COLLATE database_default  AS [DatabaseName]
    ,CASE WHEN sc.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
    ,N''SERVICE_CONTRACT''              AS [ObjectType]
    ,sc.service_contract_id             AS [ObjectID]
    ,NULL                               AS [ObjectSchema]
    ,sc.name COLLATE database_default   AS [ObjectName]
    ,N''DATABASE''                      AS [ParentObjectType]
    ,DB_ID()                            AS [ParentObjectID]
    ,NULL                               AS [ParentObjectSchema]
    ,DB_NAME() COLLATE database_default AS [ParentObjectName]
    ,NULL                               AS [ObjectCreationDate]
    ,NULL                               AS [ObjectModifyDate]
    ,@basePath + N''\Service Broker\Contracts'' 
        + CASE WHEN sc.service_contract_id <= 65535 THEN N''\System Contracts'' ELSE '''' END AS [ObjectPath]
    ,(SELECT * FROM sys.service_contracts [serviceContract] WHERE [serviceContract].service_contract_id = sc.service_contract_id FOR XML AUTO, BINARY BASE64, TYPE)
                                        AS [ObjectDetails]
FROM sys.service_contracts sc
WHERE
    sc.name COLLATE database_default LIKE @searchStr COLLATE database_default
');

--services
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType = N'SERVICE')
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'services',
N'SELECT --sys.services
    DB_NAME() COLLATE database_default  AS [DatabaseName]
    ,CASE WHEN s.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
    ,N''SERVICE''                       AS [ObjectType]
    ,s.service_id                       AS [ObjectID]
    ,NULL                               AS [ObjectSchema]
    ,s.name COLLATE database_default    AS [ObjectName]
    ,N''DATABASE''                      AS [ParentObjectType]
    ,DB_ID()                            AS [ParentObjectID]
    ,NULL                               AS [ParentObjectSchema]
    ,DB_NAME() COLLATE database_default AS [ParentObjectName]
    ,NULL                               AS [ObjectCreationDate]
    ,NULL                               AS [ObjectModifyDate]
    ,@basePath + N''\Service Broker\Services'' 
        + CASE WHEN s.service_id <= 65535 THEN N''\System Services'' ELSE '''' END AS [ObjectPath]
    ,(SELECT * FROM sys.services [service] WHERE [service].service_id = s.service_id FOR XML AUTO, BINARY BASE64, TYPE)
                                        AS [ObjectDetails]
FROM sys.services s
WHERE
    s.name COLLATE database_default LIKE @searchStr COLLATE database_default
');

--remote_service_bindings
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType = N'REMOTE_SERVICE_BINDING')
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'remote_service_bindings',
N'SELECT --sys.remote_service_bindings
    DB_NAME() COLLATE database_default  AS [DatabaseName]
    ,CASE WHEN rsb.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
    ,N''REMOTE_SERVICE_BINDING''        AS [ObjectType]
    ,rsb.remote_service_binding_id      AS [ObjectID]
    ,NULL                               AS [ObjectSchema]
    ,rsb.name COLLATE database_default  AS [ObjectName]
    ,N''DATABASE''                      AS [ParentObjectType]
    ,DB_ID()                            AS [ParentObjectID]
    ,NULL                               AS [ParentObjectSchema]
    ,DB_NAME() COLLATE database_default AS [ParentObjectName]
    ,NULL                               AS [ObjectCreationDate]
    ,NULL                               AS [ObjectModifyDate]
    ,@basePath + N''\Service Broker\Remote Service Binding'' AS [ObjectPath]
    ,(SELECT * FROM sys.remote_service_bindings [remoteServiceBinding] WHERE [remoteServiceBinding].remote_service_binding_id = rsb.remote_service_binding_id FOR XML AUTO, BINARY BASE64, TYPE)
                                        AS [ObjectDetails]
FROM sys.remote_service_bindings rsb
WHERE
    rsb.name COLLATE database_default LIKE @searchStr COLLATE database_default
');

--routes
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType = N'ROUTE')
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'routes',
N'SELECT --sys.routes
    DB_NAME()	COLLATE database_default        AS [DatabaseName]
    ,CASE WHEN r.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
    ,N''ROUTE''                                 AS [ObjectType]
    ,r.route_id                                 AS [ObjectID]
    ,NULL                                       AS [ObjectSchema]
    ,r.name COLLATE database_default            AS [ObjectName]
    ,N''DATABASE''                              AS [ParentObjectType]
    ,DB_ID()                                    AS [ParentObjectID]
    ,NULL                                       AS [ParentObjectSchema]
    ,DB_NAME() COLLATE database_default         AS [ParentObjectName]
    ,NULL                                       AS [ObjectCreationDate]
    ,NULL                                       AS [ObjectModifyDate]
    ,@basePath + N''\Service Broker\Routes''    AS [ObjectPath]
    ,(SELECT * FROM sys.routes [route] WHERE [route].route_id = r.route_id FOR XML AUTO, BINARY BASE64, TYPE)
                                                AS [ObjectDetails]
FROM sys.routes r
WHERE
    r.name COLLATE database_default LIKE @searchStr COLLATE database_default
');

--fulltext_catalogs
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType = N'FULLTEXT_CATALOG')
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'fulltext_catalogs',
N'SELECT --sys.fulltext_catalogs
    DB_NAME() COLLATE database_default              AS [DatabaseName]
    ,CASE WHEN fc.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
    ,N''FULLTEXT_CATALOG''                          AS [ObjectType]
    ,fc.fulltext_catalog_id                         AS [ObjectID]
    ,NULL                                           AS [ObjectSchema]
    ,fc.name COLLATE database_default               AS [ObjectName]
    ,N''DATABASE''                                  AS [ParentObjectType]
    ,DB_ID()                                        AS [ParentObjectID]
    ,NULL                                           AS [ParentObjectSchema]
    ,DB_NAME() COLLATE database_default             AS [ParentObjectName]
    ,NULL                                           AS [ObjectCreationDate]
    ,NULL                                           AS [ObjectModifyDate]
    ,@basePath + N''\Storage\Full Text Catalogs''   AS [ObjectPath]
    ,(SELECT * FROM sys.fulltext_catalogs [fulltextCatalog] WHERE [fulltextCatalog].fulltext_catalog_id = fc.fulltext_catalog_id FOR XML AUTO, BINARY BASE64, TYPE)
                                                    AS [ObjectDetails]
FROM sys.fulltext_catalogs fc
WHERE
    fc.name COLLATE database_default LIKE @searchStr COLLATE database_default
');

--symmetric_keys
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType = N'SYMMETRIC_KEY')
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'symmetric_keys',
N'SELECT --sys.symmetric_keys
    DB_NAME() COLLATE database_default          AS [DatabaseName]
    ,CASE WHEN sc.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
    ,N''SYMMETRIC_KEY''                         AS [ObjectType]
    ,sc.symmetric_key_id                        AS [ObjectID]
    ,NULL                                       AS [ObjectSchema]
    ,sc.name COLLATE database_default           AS [ObjectName]
    ,N''DATABASE''                              AS [ParentObjectType]
    ,DB_ID()                                    AS [ParentObjectID]
    ,NULL                                       AS [ParentObjectSchema]
    ,DB_NAME() COLLATE database_default         AS [ParentObjectName]
    ,sc.create_date                             AS [ObjectCreationDate]
    ,sc.modify_date                             AS [ObjectModifyDate]
    ,@basePath + N''\Security\Symmetric Keys''  AS [ObjectPath]
    ,(SELECT * FROM sys.symmetric_keys [symmetricKey] WHERE [symmetricKey].symmetric_key_id = sc.symmetric_key_id FOR XML AUTO, BINARY BASE64, TYPE)
                                                AS [ObjectDetails]
FROM sys.symmetric_keys sc
WHERE
    sc.name COLLATE database_default LIKE @searchStr COLLATE database_default
');

--asymmetric_keys
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType = N'ASYMMETRIC_KEY')
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'asymmetric_keys',
N'SELECT --sys.asymmetric_keys
    DB_NAME() COLLATE database_default          AS [DatabaseName]
    ,CASE WHEN ac.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
    ,N''ASYMMETRIC_KEY''                        AS [ObjectType]
    ,ac.asymmetric_key_id                       AS [ObjectID]
    ,NULL                                       AS [ObjectSchema]
    ,ac.name COLLATE database_default           AS [ObjectName]
    ,N''DATABASE''                              AS [ParentObjectType]
    ,DB_ID()                                    AS [ParentObjectID]
    ,NULL                                       AS [ParentObjectSchema]
    ,DB_NAME() COLLATE database_default         AS [ParentObjectName]
    ,NULL                                       AS [ObjectCreationDate]
    ,NULL                                       AS [ObjectModifyDate]
    ,@basePath + N''\Security\Asymmetric Keys'' AS [ObjectPath]
    ,(SELECT * FROM sys.asymmetric_keys [asymmetricKey] WHERE [asymmetricKey].asymmetric_key_id = ac.asymmetric_key_id FOR XML AUTO, BINARY BASE64, TYPE)
                                                AS [ObjectDetails]
FROM sys.asymmetric_keys ac
WHERE
    ac.name COLLATE database_default LIKE @searchStr COLLATE database_default
');

--certificates
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType = N'CERTIFICATE')
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'certificates',
N'SELECT --sys.certificates 
    DB_NAME() COLLATE database_default          AS [DatabaseName]
    ,CASE WHEN c.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
    ,N''CERTIFICATE''                           AS [ObjectType]
    ,c.certificate_id                           AS [ObjectID]
    ,NULL                                       AS [ObjectSchema]
    ,c.name COLLATE database_default            AS [ObjectName]
    ,N''DATABASE''                              AS [ParentObjectType]
    ,DB_ID()                                    AS [ParentObjectID]
    ,NULL                                       AS [ParentObjectSchema]
    ,DB_NAME() COLLATE database_default         AS [ParentObjectName]
    ,NULL                                       AS [ObjectCreationDate]
    ,NULL                                       AS [ObjectModifyDate]
    ,@basePath + N''\Security\Certificates''    AS [ObjectPath]
    ,(SELECT * FROM sys.certificates [certificate] WHERE [certificate].certificate_id = c.certificate_id FOR XML AUTO, BINARY BASE64, TYPE)
                                                AS [ObjectDetails]
FROM sys.certificates c
WHERE
    c.name COLLATE database_default LIKE @searchStr COLLATE database_default
');

--partition_schemes
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType = N'PARTITION_SCHEME')
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'partition_schemes',
N'SELECT --sys.partition_schemes
    DB_NAME() COLLATE database_default              AS [DatabaseName]
    ,CASE WHEN ps.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
    ,N''PARTITION_SCHEME''                          AS [ObjectType]
    ,ps.data_space_id                               AS [ObjectID]
    ,NULL                                           AS [ObjectSchema]
    ,ps.name COLLATE database_default               AS [ObjectName]
    ,N''DATABASE''                                  AS [ParentObjectType]
    ,DB_ID()                                        AS [ParentObjectID]
    ,NULL                                           AS [ParentObjectSchema]
    ,DB_NAME() COLLATE database_default             AS [ParentObjectName]
    ,NULL                                           AS [ObjectCreationDate]
    ,NULL                                           AS [ObjectModifyDate]
    ,@basePath + N''\Storage\Partition Schemes''    AS [ObjectPath]
    ,(SELECT
        [partitionScheme].*
        ,(
            SELECT
                [destinationDataSpace].*
                ,[fileGroup].*
            FROM sys.destination_data_spaces [destinationDataSpace]
            INNER JOIN sys.filegroups [fileGroup] ON [fileGroup].data_space_id = [destinationDataSpace].data_space_id
            WHERE [destinationDataSpace].partition_scheme_id = [partitionScheme].data_space_id 
            ORDER BY destination_id
            FOR XML AUTO, ROOT(''destinationDataSpaces''), TYPE
        )	
    FROM sys.partition_schemes [partitionScheme] WHERE data_space_id = ps.data_space_id
    FOR XML AUTO, TYPE
    )               AS [ObjectDetails]
FROM sys.partition_schemes ps
WHERE
    ps.name COLLATE database_default LIKE @searchStr COLLATE database_default
');

--partition_functions
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType = N'PARTITION_FUNCTION')
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'partition_functions',
N'SELECT --sys.partition_functions
    DB_NAME() COLLATE database_default              AS [DatabaseName]
    ,CASE WHEN pf.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
    ,N''PARTITION_FUNCTION''                        AS [ObjectType]
    ,pf.function_id                                 AS [ObjectID]
    ,NULL                                           AS [ObjectSchema]
    ,pf.name COLLATE database_default               AS [ObjectName]
    ,N''DATABASE''                                  AS [ParentObjectType]
    ,DB_ID()                                        AS [ParentObjectID]
    ,NULL                                           AS [ParentObjectSchema]
    ,DB_NAME() COLLATE database_default             AS [ParentObjectName]
    ,NULL                                           AS [ObjectCreationDate]
    ,NULL                                           AS [ObjectModifyDate]
    ,@basePath + N''\Storage\Partition Functions''  AS [ObjectPath]
    ,
        (SELECT
	       [partitionFunction].*
	       ,(
		      SELECT
				    [rangeValue].*
		      FROM sys.partition_range_values [rangeValue]
		      WHERE [rangeValue].function_id = [partitionFunction].function_id 
		      ORDER BY boundary_id
		      FOR XML AUTO, ROOT(''boundaryValues''), TYPE
	       )	
        FROM sys.partition_functions [partitionFunction] WHERE function_id = pf.function_id
        FOR XML AUTO, TYPE
        )                   AS [ObjectDetails]
FROM sys.partition_functions pf
WHERE
    (
        (pf.name COLLATE database_default LIKE @searchStr COLLATE database_default)
        OR
        (
            @searchInDefinition =1
            AND
            EXISTS (
                SELECT 1
                FROM sys.partition_range_values prv
                WHERE
                    prv.function_id = pf.function_id
                    AND
                    CONVERT(nvarchar(max), prv.value, 121) COLLATE database_default LIKE @searchStr COLLATE database_default
            )
        )
    )	
');

--database_triggers
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType IN (SELECT ObjectType FROM #typesMapping WHERE ParentObjectType = N'DATABASE_TRIGGER'))
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (0, 'database_triggers',
N'SELECT --sys.triggers
    DB_NAME() COLLATE database_default                  AS [DatabaseName]
    ,CASE WHEN tr.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
    ,tr.type_desc                                           AS [ObjectType]
    ,tr.object_id                                           AS [ObjectID]
    ,NULL                                                   AS [ObjectSchema]
    ,tr.name COLLATE database_default                       AS [ObjectName]
    ,N''DATABASE''                                          AS [ParentObjectType]
    ,DB_ID()                                                AS [ParentObjectID]
    ,NULL                                                   AS [ParentObjectSchema]
    ,DB_NAME() COLLATE database_default                     AS [ParentObjectName]
    ,NULL                                                   AS [ObjectCreationDate]
    ,NULL                                                   AS [ObjectModifyDate]
    ,@basePath + N''\Programmability\Database Triggers''    AS [ObjectPath]
    ,
        (SELECT
            [trigger].*
            ,CONVERT(xml, STUFF(
            (SELECT 
                N'' '' + x.value(N''local-name(.)'', N''nvarchar(max)'') + N''="'' + x.value(N''.'', N''nvarchar(max)'') + N''"''
            FROM
            (SELECT CONVERT(xml, (SELECT * from sys.sql_modules [module] WHERE object_id = [trigger].object_id FOR XML AUTO)) AS XmlData) M
            CROSS APPLY XmlData.nodes(N''/*/@*'') a(x)
            WHERE x.value(N''local-name(.)'', N''nvarchar(max)'') <> N''definition''
            FOR XML PATH(N'''')), 1, 1, N''<module '') + N''/>'')
            ,CONVERT(xml, N''<?definition --'' + NCHAR(13) + NCHAR(10) + REPLACE(REPLACE(definition, N''<?'', N''''), N''?>'', N'''') + NCHAR(13) + NCHAR(10) + N''--?>'')
        FROM sys.triggers [trigger] 
        INNER JOIN sys.sql_modules  [module] ON [module].object_id = [trigger].object_id
        WHERE [trigger].object_id = tr.object_id
        FOR XML AUTO, TYPE
    )							AS [ObjectDetails]
FROM sys.triggers tr
LEFT JOIN sys.sql_modules m ON m.object_id = tr.object_id
LEFT JOIN sys.assembly_modules am ON am.object_id = tr.object_id
WHERE
    tr.parent_class = 0
    AND 
        tr.[type] COLLATE Latin1_General_CI_AS IN (SELECT [Type] FROM #objTypes WHERE ObjectType IN (SELECT ObjectType FROM #typesMapping WHERE ParentObjectType = N''DATABASE_TRIGGER''))
    AND 
    (
        (tr.name COLLATE database_default LIKE @searchStr COLLATE database_default)
        OR
        (
            @searchInDefinition =1
            AND
            (
                m.definition LIKE @searchStr COLLATE database_default
                OR
                am.assembly_class COLLATE database_default LIKE @searchStr COLLATE database_default
                OR
                am.assembly_method COLLATE database_default LIKE @searchStr COLLATE database_default
            )
        )
    )
');

/**********************************************
    Define Searches for Server scoped objects
***********************************************/
--server_triggers
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType IN (SELECT ObjectType FROM #typesMapping WHERE ParentObjectType = N'SERVER_TRIGGER'))
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (1, 'server_triggers',
N'SELECT --sys.seerver_triggers
    DB_NAME() COLLATE database_default      AS [DatabaseName]
    ,CASE WHEN tr.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
    ,tr.type_desc                           AS [ObjectType]
    ,tr.object_id                           AS [ObjectID]
    ,NULL                                   AS [ObjectSchema]
    ,tr.name COLLATE database_default       AS [ObjectName]
    ,N''SERVER''                            AS [ParentObjectType]
    ,0                                      AS [ParentObjectID]
    ,NULL                                   AS [ParentObjectSchema]
    ,@@SERVERNAME COLLATE database_default  AS [ParentObjectName]
    ,NULL                                   AS [ObjectCreationDate]
    ,NULL                                   AS [ObjectModifyDate]
    ,N''Server Objects\Triggers''           AS [ObjectPath]
    ,
        (SELECT
            [trigger].*
            ,CONVERT(xml, STUFF(
            (SELECT 
                N'' '' + x.value(N''local-name(.)'', N''nvarchar(max)'') + N''="'' + x.value(N''.'', N''nvarchar(max)'') + N''"''
            FROM
            (SELECT (SELECT * from sys.server_sql_modules [module] WHERE object_id = [trigger].object_id FOR XML AUTO, TYPE) AS XmlData) M
            CROSS APPLY XmlData.nodes(''/*/@*'') a(x)
            WHERE x.value(N''local-name(.)'', N''nvarchar(max)'') <> N''definition''
            FOR XML PATH(N'''')), 1, 1, N''<module '') + N''/>'')
            ,CONVERT(xml, N''<?definition --'' + NCHAR(13) + NCHAR(10) + REPLACE(REPLACE(definition, N''<?'', N''''), N''?>'', N'''') + NCHAR(13) + NCHAR(10) + N''--?>'')
            ,[assemblyModule].*
        FROM sys.server_triggers [trigger] 
        LEFT JOIN sys.server_sql_modules  [module] ON [module].object_id = [trigger].object_id
        LEFT JOIN sys.server_assembly_modules [assemblyModule] ON [assemblyModule].object_id = [trigger].object_id
        LEFT JOIN master.sys.assemblies [assembly] ON [assembly].assembly_id = [assemblyModule].assembly_id
        WHERE [trigger].object_id = tr.object_id
        FOR XML AUTO, TYPE
    )                                   AS [ObjectDetails]
FROM sys.server_triggers tr
LEFT JOIN sys.server_sql_modules m ON m.object_id = tr.object_id
LEFT JOIN sys.server_assembly_modules am ON am.object_id = tr.object_id
WHERE
    tr.parent_class = 100
    AND tr.[type] COLLATE Latin1_General_CI_AS IN (SELECT [Type] FROM #objTypes WHERE ObjectType IN (SELECT ObjectType FROM #typesMapping WHERE ParentObjectType = N''SERVER_TRIGGER''))
    AND 
    (
        (tr.name COLLATE database_default LIKE @searchStr COLLATE database_default)
        OR
        (
            @searchInDefinition =1
            AND
            (
                m.definition LIKE @searchStr COLLATE database_default
                OR
                am.assembly_class COLLATE database_default LIKE @searchStr COLLATE database_default
                OR
                am.assembly_method COLLATE database_default LIKE @searchStr COLLATE database_default
            )
        )
    )
');

--server_principals
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType IN (SELECT ObjectType FROM #typesMapping WHERE ParentObjectType = N'SERVER_PRINCIPAL'))
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (1, 'server_principals',
N'SELECT --server_principals
    NULL                                    AS [DatabaseName]
    ,CASE WHEN sp.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
    ,sp.type_desc                           AS [ObjectType]
    ,sp.principal_id                        AS [ObjectID]
    ,NULL                                   AS [ObjectSchema]
    ,sp.name COLLATE database_default       AS [ObjectName]
    ,N''SERVER''                            AS [ParentObjectType]
    ,0                                      AS [ParentObjectID]
    ,NULL                                   AS [ParentObjectSchema]
    ,@@SERVERNAME COLLATE database_default  AS [ParentObjectName]
    ,sp.create_date                         AS [ObjectCreationDate]
    ,sp.modify_date                         AS [ObjectModifyDate]
    ,N''Security\'' + CASE WHEN sp.type_desc = N''SERVER_ROLE'' THEN N''Server Roles'' ELSE N''Logins'' END  AS [ObjectPath]
    ,
        (SELECT 
            [serverPrincipal].* 
            ,(
                SELECT 
                    *
                FROM sys.server_principal_credentials [principalCredential] 
                INNER JOIN sys.credentials [credential] ON [credential].credential_id = [principalCredential].credential_id
                WHERE [principalCredential].principal_id = [serverPrincipal].[principal_id]
                FOR XML AUTO, ROOT(N''principalCredentials''), BINARY BASE64, TYPE)
            ,(
                SELECT 
                    *
                FROM sys.server_role_members [roleMember] 
                INNER JOIN sys.server_principals [memberPrincipal] ON [memberPrincipal].principal_id = [roleMember].member_principal_id
                WHERE [roleMember].role_principal_id = [serverPrincipal].[principal_id]
                FOR XML AUTO, ROOT(N''roleMembers''), BINARY BASE64, TYPE)
        FROM sys.server_principals [serverPrincipal] 
    WHERE principal_id = sp.principal_id
    FOR XML AUTO, BINARY BASE64, TYPE
    )
                                        AS [ObjectDetails]
FROM sys.server_principals sp
WHERE
    sp.[type] COLLATE Latin1_General_CI_AS IN (SELECT [Type] FROM #objTypes WHERE ObjectType IN (SELECT ObjectType FROM #typesMapping WHERE ParentObjectType = N''SERVER_PRINCIPAL''))
    AND 
    sp.name COLLATE database_default LIKE @searchStr COLLATE database_default
');

--credentials
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType = N'CREDENTIAL')
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (1, 'credentials',
N'SELECT --sys.credentials
    NULL                                    AS [DatabaseName]
    ,CASE WHEN cr.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
    ,N''CREDENTIAL''                        AS [ObjectType]
    ,cr.credential_id                       AS [ObjectID]
    ,NULL                                   AS [ObjectSchema]
    ,cr.name COLLATE database_default       AS [ObjectName]
    ,N''SERVER''                            AS [ParentObjectType]
    ,0                                      AS [ParentObjectID]
    ,NULL                                   AS [ParentObjectSchema]
    ,@@SERVERNAME COLLATE database_default  AS [ParentObjectName]
    ,cr.create_date                         AS [ObjectCreationDate]
    ,cr.modify_date                         AS [ObjectModifyDate]
    ,N''Security\Credentials''              AS [ObjectPath]
    ,
        (SELECT 
        [credential].* 
        ,(
            SELECT 
                *
            FROM sys.server_principal_credentials [credentialPrincipal] 
            INNER JOIN sys.server_principals [serverPrincipal] ON [serverPrincipal].principal_id = [credentialPrincipal].principal_id
            WHERE [credentialPrincipal].credential_id = [credential].credential_id
            FOR XML AUTO, ROOT(N''credentialPrincipals''), BINARY BASE64, TYPE
        )
        FROM sys.credentials [credential] 
    WHERE [credential].credential_id = cr.credential_id
    FOR XML AUTO, BINARY BASE64, TYPE
    )
                                AS [ObjectDetails]
FROM sys.credentials cr
WHERE
    cr.name COLLATE database_default LIKE @searchStr COLLATE database_default
');

--linked_servers
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType = N'LINKED_SERVER')
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (1, 'linked_servers',
N'SELECT --sys.servers
    NULL                                    AS [DatabaseName]
    ,CASE WHEN s.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
    ,N''LINKED_SERVER''                     AS [ObjectType]
    ,s.server_id                            AS [ObjectID]
    ,NULL                                   AS [ObjectSchema]
    ,s.name COLLATE database_default        AS [ObjectName]
    ,N''SERVER''                            AS [ParentObjectType]
    ,0                                      AS [ParentObjectID]
    ,NULL                                   AS [ParentObjectSchema]
    ,@@SERVERNAME COLLATE database_default  AS [ParentObjectName]
    ,NULL                                   AS [ObjectCreationDate]
    ,s.modify_date                          AS [ObjectModifyDate]
    ,N''ServerObjects\Linked Servers''      AS [ObjectPath]
    ,
        (SELECT 
            [server].* 
            ,(
                SELECT 
                    [linkedLogin].*
                    ,[serverPrincipal].*
                FROM sys.linked_logins [linkedLogin]
                LEFT JOIN sys.server_principals [serverPrincipal] ON [serverPrincipal].principal_id = [linkedLogin].local_principal_id
                WHERE [linkedLogin].server_id = [server].server_id
                FOR XML AUTO, ROOT(N''linkedLogins''), BINARY BASE64, TYPE
            )
        FROM sys.servers [server] 
    WHERE [server].server_id = s.server_id
    FOR XML AUTO, BINARY BASE64, TYPE
    )
                                        AS [ObjectDetails]
FROM sys.servers s
WHERE
    (
        (s.name COLLATE database_default LIKE @searchStr COLLATE database_default)
        OR
        (
            @searchInDefinition = 1
            AND
            s.provider_string COLLATE database_default LIKE @searchStr COLLATE database_default
        )
    )
');

/**********************************************
    Define Searches for SSIS Objects
***********************************************/
IF EXISTS(SELECT database_id FROM sys.databases d WHERE d.name = 'SSISDB')
BEGIN

--ssis_environments
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType IN (N'SSIS_ENVIRONMENT', N'SSISDB', N'SSIS'))
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (2, 'ssis_environments',
N'SELECT
    DB_NAME()                                                   As [DatabaseName]
    ,CASE WHEN e.environment_name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
    ,N''SSIS_ENVIRONMENT'' COLLATE database_default             AS [ObjectType]
    ,e.environment_id                                           AS [ObjectID]
    ,NULL                                                       AS [ObjectSchema]
    ,e.environment_name COLLATE database_default                AS [ObjectName]
    ,N''SSIS_FOLDER''                                           AS [ParentObjectType]
    ,e.folder_id                                                AS [ParentObjectID]
    ,NULL                                                       AS [ParentObjectSchema]
    ,f.name COLLATE database_default                            AS [ParentObjectName]
    ,e.created_time                                             AS [ObjectCreationDate]
    ,NULL                                                       AS [ObjectModifyDate]
    ,N''[SSISDB]\'' + QUOTENAME(F.name) + N''\Environments''    AS [ObjectPath]
    ,
        (SELECT 
            [environment].* 
            ,folder.*
        FROM internal.environments [environment] 
        INNER JOIN internal.folders folder ON folder.folder_id = environment.environment_id
    WHERE [environment].environment_id = e.environment_id
    FOR XML AUTO, BINARY BASE64, TYPE
    )
                                                                AS [ObjectDetails]
FROM internal.environments e
INNER JOIN internal.folders f ON f.folder_id = e.folder_id
WHERE 
    e.environment_name COLLATE database_default LIKE @searchStr COLLATE database_default
');

--ssis_folder
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType IN (N'SSIS_FOLDER', N'SSISDB', N'SSIS'))
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (2, 'ssis_folders',
N'SELECT
    DB_NAME()                                       As [DatabaseName]
    ,CASE WHEN f.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
    ,N''SSIS_FOLDER'' COLLATE database_default      AS [ObjectType]
    ,f.folder_id                                    AS [ObjectID]
    ,NULL                                           AS [ObjectSchema]
    ,f.name COLLATE database_default                AS [ObjectName]
    ,N''SSISDB''                                    AS [ParentObjectType]
    ,0                                              AS [ParentObjectID]
    ,NULL                                           AS [ParentObjectSchema]
    ,N''SSISDB'' COLLATE database_default           AS [ParentObjectName]
    ,f.created_time                                 AS [ObjectCreationDate]
    ,NULL                                           AS [ObjectModifyDate]
    ,N''[SSISDB]''                                  AS [ObjectPath]
    ,
        (SELECT 
            folder.* 
        FROM internal.folders folder 
    WHERE folder.folder_id = f.folder_id
    FOR XML AUTO, BINARY BASE64, TYPE
    )
                                                    AS [ObjectDetails]
FROM internal.folders f
WHERE 
    f.name COLLATE database_default LIKE @searchStr COLLATE database_default
');

--ssis_variable
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType IN (N'SSIS_VARIABLE', N'SSISDB', N'SSIS'))
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (2, 'ssis_variables',
N'SELECT
    DB_NAME()                                       As [DatabaseName]
    ,CASE WHEN v.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
    ,N''SSIS_VARIABLE'' COLLATE database_default    AS [ObjectType]
    ,v.variable_id                                  AS [ObjectID]
    ,NULL                                           AS [ObjectSchema]
    ,v.name COLLATE database_default                AS [ObjectName]
    ,N''SSIS_ENVIRONMENT'' COLLATE database_default AS [ParentObjectType]
    ,0                                              AS [ParentObjectID]
    ,NULL                                           AS [ParentObjectSchema]
    ,e.environment_name COLLATE database_default    AS [ParentObjectName]
    ,NULL                                           AS [ObjectCreationDate]
    ,NULL                                           AS [ObjectModifyDate]
    ,N''[SSISDB]\'' + QUOTENAME(F.name) + N''\Environments\'' + QUOTENAME(e.environment_name)        AS [ObjectPath]
    ,
        (SELECT 
            variable.*
            ,environment.*
            ,folder.*
        FROM internal.environment_variables variable 
        INNER JOIN internal.environments environment on environment.environment_id = variable.environment_id
        INNER JOIN internal.folders folder ON folder.folder_id = environment.environment_id
    WHERE variable.variable_id = v.variable_id    
    FOR XML AUTO, BINARY BASE64, TYPE
    )
                                                    AS [ObjectDetails]
FROM internal.environment_variables v
INNER JOIN internal.environments e ON e.environment_id = v.environment_id
INNER JOIN internal.folders f ON f.folder_id = e.folder_id
WHERE 
    v.name COLLATE database_default LIKE @searchStr COLLATE database_default
    OR
    (
        @searchInDefinition = 1
        AND
        (
            v.[description] COLLATE database_default LIKE @searchStr COLLATE database_default
            OR
            (v.sensitive = 0 AND CONVERT(nvarchar(max), v.value) COLLATE database_default LIKE @searchStr COLLATE database_default)
        )
    )
');

--ssis_project
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType IN (N'SSIS_PROJECT', N'SSISDB', N'SSIS'))
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (2, 'ssis_projects',
N'SELECT
    DB_NAME()                                       As [DatabaseName]
    ,CASE WHEN p.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
    ,N''SSIS_PROJECT'' COLLATE database_default     AS [ObjectType]
    ,p.project_id                                   AS [ObjectID]
    ,NULL                                           AS [ObjectSchema]
    ,p.name COLLATE database_default                AS [ObjectName]
    ,N''SSIS_FOLDER'' COLLATE database_default      AS [ParentObjectType]
    ,0                                              AS [ParentObjectID]
    ,NULL                                           AS [ParentObjectSchema]
    ,f.name COLLATE database_default                AS [ParentObjectName]
    ,p.created_time                                 AS [ObjectCreationDate]
    ,p.last_deployed_time                           AS [ObjectModifyDate]
    ,N''[SSISDB]\'' + QUOTENAME(F.name) + N''\Projects''             AS [ObjectPath]
    ,
        (SELECT 
            project.*
            ,folder.*
        FROM internal.projects project
        INNER JOIN internal.folders folder ON folder.folder_id = project.folder_id
    WHERE project.project_id = p.project_id
    FOR XML AUTO, BINARY BASE64, TYPE
    )
                                                    AS [ObjectDetails]
FROM internal.projects p
INNER JOIN internal.folders f ON f.folder_id = p.folder_id
WHERE 
    p.name COLLATE database_default LIKE @searchStr COLLATE database_default
    OR
    (
        @searchInDefinition = 1
        AND
        (
            p.[description] COLLATE database_default LIKE @searchStr COLLATE database_default
        )
    )
');

--ssis_packages
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType IN (N'SSIS_PACKAGE', N'SSIS_PACKAGE_VERSION', N'SSISDB', N'SSIS'))
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (2, 'ssis_packages',
N'SELECT
    DB_NAME()                                       As [DatabaseName]
    ,CASE WHEN p.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
    ,N''SSIS_PACKAGE'' COLLATE database_default     AS [ObjectType]
    ,p.package_id                                   AS [ObjectID]
    ,NULL                                           AS [ObjectSchema]
    ,p.name + CASE WHEN p.project_version_lsn <> pr.object_version_lsn THEN '' <<LSN:'' + CONVERT(varchar(10), p.project_version_lsn) + N''>>'' ELSE N'''' END  COLLATE database_default    AS [ObjectName]
    ,N''SSIS_PROJECT'' COLLATE database_default     AS [ParentObjectType]
    ,0                                              AS [ParentObjectID]
    ,NULL                                           AS [ParentObjectSchema]
    ,pr.name COLLATE database_default               AS [ParentObjectName]
    ,NULL                                           AS [ObjectCreationDate]
    ,NULL                                           AS [ObjectModifyDate]
    ,N''[SSISDB]\'' + QUOTENAME(F.name) + N''\Projects\'' + QUOTENAME(pr.name) + N''\Packages''  AS [ObjectPath]
    ,
        (SELECT 
             package.*
            ,project.*
            ,folder.*
        FROM internal.packages package
        INNER JOIN internal.projects project ON project.project_id = package.project_id
        INNER JOIN internal.folders folder ON folder.folder_id = project.folder_id
    WHERE package.package_id = p.package_id
    FOR XML AUTO, BINARY BASE64, TYPE
    )
                                                    AS [ObjectDetails]
FROM internal.packages p
INNER JOIN internal.projects pr ON pr.project_id = p.project_id AND (pr.object_version_lsn = p.project_version_lsn OR EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType = N''SSIS_PACKAGE_VERSION''))
INNER JOIN internal.folders f ON f.folder_id = pr.folder_id
WHERE 
    p.name COLLATE database_default LIKE @searchStr COLLATE database_default
    OR
    (
        @searchInDefinition = 1
        AND
        (
            p.[description] COLLATE database_default LIKE @searchStr COLLATE database_default
        )
    )
');

END  --IF EXISTS(SELECT database_id FROM sys.databases d WHERE d.name = 'SSISDB')


--ssis_msdb_folders
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType IN (N'SSIS_MSDB_FOLDER', N'SSIS_MSDB', N'SSIS'))
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (3, 'ssis_msdb_folders',
N'WITH [Folders] AS (
    SELECT
         folderid                           AS FolderID
        ,foldername                         AS FolderName
        ,CONVERT(nvarchar(128), ''[MSDB]'') AS ParentFolderName
        ,CONVERT(nvarchar(max), ''[MSDB]'') AS FolderPath
    FROM [dbo].[sysssispackagefolders] F
    WHERE
        parentfolderid = ''00000000-0000-0000-0000-000000000000''

    UNION ALL
    
    SELECT
         F.folderid                     AS FolderID
        ,F.foldername                   AS FolderName
        ,PF.FolderName                  AS ParentFolderName
        ,PF.FolderPath + CASE WHEN PF.FolderPath = '''' THEN '''' ELSE ''\'' END + QUOTENAME(PF.FolderName) AS FolderPath
    FROM [dbo].[sysssispackagefolders] F
    INNER JOIN [Folders] PF ON PF.FolderID = F.parentfolderid
)
SELECT
    DB_NAME()                                           As [DatabaseName]
    ,@matchInName                                       AS [MatchIn]
    ,N''SSIS_MSDB_FOLDER'' COLLATE database_default     AS [ObjectType]
    ,f.FolderID                                         AS [ObjectID]
    ,NULL                                               AS [ObjectSchema]
    ,f.FolderName COLLATE database_default              AS [ObjectName]
    ,N''SSIS_MSDB''                                     AS [ParentObjectType]
    ,0                                                  AS [ParentObjectID]
    ,NULL                                               AS [ParentObjectSchema]
    ,N''msdb'' COLLATE database_default                 AS [ParentObjectName]
    ,NULL                                               AS [ObjectCreationDate]
    ,NULL                                               AS [ObjectModifyDate]
    ,F.FolderPath COLLATE database_default              AS [ObjectPath]
    ,
        (SELECT 
            folder.* 
        FROM [Folders] folder 
    WHERE folder.FolderID = f.FolderID
    FOR XML AUTO, BINARY BASE64, TYPE
    )
                                                        AS [ObjectDetails]
FROM [Folders] f
WHERE 
    f.FolderName COLLATE database_default LIKE @searchStr COLLATE database_default
')

--ssis_msdb_packages
IF EXISTS(SELECT ObjectType FROM #objTypes WHERE ObjectType IN (N'SSIS_MSDB_PACKAGE', N'SSIS_MSDB', N'SSIS'))
INSERT INTO @searches(SearchScope, SearchDescription, SearchSQL)
VALUES (3, 'ssis_msdb_packages',
N'WITH [Folders] AS (
    SELECT
         folderid                           AS FolderID
        ,foldername                         AS FolderName
        ,CONVERT(nvarchar(128), ''[MSDB]'') AS ParentFolderName
        ,CONVERT(nvarchar(max), ''[MSDB]'') AS FolderPath
    FROM [dbo].[sysssispackagefolders] F
    WHERE
        parentfolderid = ''00000000-0000-0000-0000-000000000000''

    UNION ALL
    
    SELECT
         F.folderid                     AS FolderID
        ,F.foldername                   AS FolderName
        ,PF.FolderName                  AS ParentFolderName
        ,PF.FolderPath + CASE WHEN PF.FolderPath = '''' THEN '''' ELSE ''\'' END + QUOTENAME(PF.FolderName) AS FolderPath
    FROM [dbo].[sysssispackagefolders] F
    INNER JOIN [Folders] PF ON PF.FolderID = F.parentfolderid
)
SELECT
    DB_NAME()                                           As [DatabaseName]
    ,CASE WHEN p.name COLLATE database_default LIKE @searchStr COLLATE database_default THEN @matchInName ELSE @matchInDefinition END AS [MatchIn]
    ,N''SSIS_MSDB_PACKAGE'' COLLATE database_default    AS [ObjectType]
    ,P.id                                               AS [ObjectID]
    ,NULL                                               AS [ObjectSchema]
    ,p.name COLLATE database_default                    AS [ObjectName]
    ,N''SSIS_MSDB_FOLDER''                              AS [ParentObjectType]
    ,F.FolderID                                         AS [ParentObjectID]
    ,NULL                                               AS [ParentObjectSchema]
    ,F.FolderName COLLATE database_default              AS [ParentObjectName]
    ,P.createdate                                       AS [ObjectCreationDate]
    ,NULL                                               AS [ObjectModifyDate]
    ,F.FolderPath + N''\'' + QUOTENAME(F.FolderName) COLLATE database_default   AS [ObjectPath]
    ,
        (SELECT 
              package.name
            , package.id
            , package.description
            , package.createdate
            , package.folderid
            , package.ownersid
            , package.packageformat
            , package.packagetype
            , package.vermajor
            , package.verminor
            , package.verbuild
            , package.vercomments
            , package.verid
            , package.isencrypted
            , package.readrolesid
            , package.writerolesid
            ,(SELECT * FROM [Folders] [folder] WHERE [folder].FolderID = package.folderid FOR XML AUTO, TYPE)
            ,CONVERT(xml, CASE WHEN isencrypted = 0 THEN CONVERT(varbinary(max), packagedata) ELSE NULL END) AS packageData
        FROM [dbo].[sysssispackages] package
    WHERE package.id = P.id
    FOR XML AUTO, BINARY BASE64, TYPE
    )
                                                        AS [ObjectDetails]
FROM [dbo].[sysssispackages] P
INNER JOIN [Folders] F ON F.FolderID = P.folderid
WHERE 
    P.name COLLATE database_default LIKE @searchStr COLLATE database_default
    OR
    (
        @searchInDefinition = 1
        AND
        (
            (
                P.isencrypted = 0
                AND
                CONVERT(nvarchar(max), CONVERT(xml, CASE WHEN isencrypted = 0 THEN CONVERT(varbinary(max), packagedata) ELSE NULL END)) COLLATE database_default LIKE @searchStr COLLATE database_default
            )
            OR
            P.[description] COLLATE database_default LIKE @searchStr COLLATE database_default
        )
    )
')


/****************************
    MAIN SEARCH EXECUTION
*****************************/

--Search through databases
IF NULLIF(@databaseName, N'') IS NULL
    SET @databaseName = DB_NAME();

--Define parameters for dynamic SQL
SET @paramDefinition = N'
     @searchStr nvarchar(max)
    ,@objectTypes nvarchar(max)
    ,@searchInDefinition bit
    ,@caseSensitive bit
    ,@matchInName nvarchar(10)
    ,@matchInDefinition nvarchar(10)
    ,@basePath nvarchar(max)'

DECLARE scope CURSOR LOCAL FAST_FORWARD FOR
    SELECT DISTINCT
        SearchScope
    FROM @searches;

    OPEN scope;

    FETCH NEXT FROM scope INTO @currentScope;

    WHILE @@FETCH_STATUS = 0
    BEGIN

        --DECLARE Cursor for the databases loop based on the current scope
        IF @currentScope = 0
        BEGIN
            DECLARE db CURSOR LOCAL FAST_FORWARD FOR	--declare cursor to fetch databases for searching
                SELECT DISTINCT
                    name
                FROM sys.databases d
                INNER JOIN @databases dl ON d.name COLLATE SQL_Latin1_General_CP1_CI_AS LIKE dl.DatabaseName COLLATE SQL_Latin1_General_CP1_CI_AS
                ORDER BY name;

            SELECT
                @startMessage =     NULL
                ,@endMessage =      NULL
                ,@dbStartMessage =  N'%s DB_START          - Searching database [%s]'
                ,@dbEndMessage =    N'%s DB_END            - Searching database [%s] - duration: %s ms'
        END
        ELSE IF @currentScope = 1   --Server Scope
        BEGIN
            DECLARE db CURSOR LOCAL FAST_FORWARD FOR	--declare cursor to fetch databases for searching
                SELECT
                    name
                FROM sys.databases d
                WHERE d.name COLLATE SQL_Latin1_General_CP1_CI_AS = N'master' COLLATE SQL_Latin1_General_CP1_CI_AS;

            SELECT
                @startMessage =     N'%s SRV_START         - Searching server objects'
                ,@endMessage =      N'%s SRV_END           - Searching server objects - duration: %s ms'
                ,@dbStartMessage =  NULL
                ,@dbEndMessage =    NULL
        END
        ELSE IF @currentScope = 2   --SSISDB scope
        BEGIN
            DECLARE db CURSOR LOCAL FAST_FORWARD FOR	--declare cursor to fetch SSIS databases for searching
                SELECT
                    name
                FROM sys.databases d
                WHERE
                    d.name COLLATE SQL_Latin1_General_CP1_CI_AS = N'SSISDB' COLLATE SQL_Latin1_General_CP1_CI_AS

            SELECT
                @startMessage =     N'%s SSIS_START        - Searching SSIS objects'
                ,@endMessage =      N'%s SSIS_END          - Searching SSIS objects - duration: %s ms'
                ,@dbStartMessage =  NULL
                ,@dbEndMessage =    NULL
        END
        ELSE IF @currentScope = 3 --SSSIS LEGACY msdb Scope
        BEGIN
            DECLARE db CURSOR LOCAL FAST_FORWARD FOR	--declare cursor to fetch SSIS databases for searching
                SELECT
                    name
                FROM sys.databases d
                WHERE
                    d.name COLLATE SQL_Latin1_General_CP1_CI_AS = N'msdb' COLLATE SQL_Latin1_General_CP1_CI_AS

            SELECT
                @startMessage =     N'%s SSIS_MSDB_START   - Searching SSIS msdb Legacy objects'
                ,@endMessage =      N'%s SSIS_MSDB_END     - Searching SSIS msdb Legacy objects - duration: %s ms'
                ,@dbStartMessage =  NULL
                ,@dbEndMessage =    NULL
        END

        --print start timestamp
        SET @start = SYSDATETIME()
        SET @now = CONVERT(nvarchar(24), @start, 121);
        IF @startMessage IS NOT NULL
            RAISERROR(@startMessage, 0, 0, @now, @dbName) WITH NOWAIT;


        --Open databases cursor
        open db;

        FETCH NEXT FROM db INTO @dbName;

        --Loop throuch databases for current scope;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SELECT
                @basePath = CASE 
                                WHEN @currentScope = 0 THEN
                                   CASE WHEN @dbName IN (N'master', N'model', N'msdb', N'tempdb') OR EXISTS(SELECT 1 FROM sys.databases WHERE name = @dbName AND is_distributor = 1) THEN N'System ' ELSE '' END + N'Databases\' + QUOTENAME(DB_NAME())
                                ELSE N''
                            END

            --print start timestamp
            SET @dbSearchStart = SYSDATETIME()
            SET @now = CONVERT(nvarchar(24), @dbSearchStart, 121);
            IF @dbStartMessage IS NOT NULL
                RAISERROR(@dbStartMessage, 0, 0, @now, @dbName) WITH NOWAIT;
            

            --Get database collation
            SELECT
                @dbCollation = CASE 
                                    WHEN @caseSensitive = 1 THEN REPLACE(d.collation_name, N'_CI', N'_CS')
                                    ELSE REPLACE(d.collation_name, N'_CS', N'_CI')
                                END	--Collation updated to appropriate Case Sensitiviity for search
            FROM sys.databases d
            WHERE d.name = @dbName

            --Iterate Through individual Searches and launch them
            DECLARE s CURSOR LOCAL FAST_FORWARD FOR
                SELECT
                    SearchDescription
                    ,SearchSQL
                FROM @searches
                WHERE SearchScope = @currentScope
                ORDER BY ID;

            OPEN s;

            FETCH NEXT FROM s INTO @searchDescription, @searchBaseSQL; --get first databse scoped search

            --Loop through individual searches
            WHILE @@FETCH_STATUS = 0
            BEGIN
                --Get starting timestamp of current search and print information
                SET @searchStart = SYSDATETIME()
                SET @now = CONVERT(nvarchar(24), @searchStart, 121);
                RAISERROR(N'%s SEARCH_START      - Searching through [%s]', 0, 0, @now, @searchDescription) WITH NOWAIT;

                --Update the search SQL for the currently processed database and proper searching collation
                SET @searchSQL = N'
                USE [' + @dbName + N'];
                ' + REPLACE(@searchBaseSQL, N'COLLATE database_default', N'COLLATE ' + @dbCollation);

                --PRINT @searchSQL
                --execute database objectssearch with proper parameters
                INSERT INTO @Results                
                EXECUTE sp_executesql @searchSQL, @paramDefinition, @searchStr = @searchStr, @objectTypes=@objectTypes, @searchInDefinition = @searchInDefinition, 
                    @caseSensitive = @caseSensitive, @matchInName=@matchInName, @matchInDefinition = @matchInDefinition, @basePath = @basePath

                --Get ending timestamp of current search and print information
                SET @searchEnd = SYSDATETIME()
                SET @now = CONVERT(nvarchar(24), @searchEnd, 121);
                SET @duration = CONVERT(nvarchar(10), DATEDIFF(millisecond, @searchStart, @searchEnd))
                RAISERROR(N'%s SEARCH_END        - Searching through [%s] - duration: %s ms', 0, 0, @now, @searchDescription, @duration) WITH NOWAIT;

                FETCH NEXT FROM s INTO @searchDescription, @searchBaseSQL; --get first databse scoped search
            END

            CLOSE s;
            DEALLOCATE s;

            --Get ending timestamp of current db search and print dbEndMessage
            SET @dbSearchEnd = SYSDATETIME()
            SET @now = CONVERT(nvarchar(24), @dbSearchEnd, 121);
            SET @duration = CONVERT(nvarchar(10), DATEDIFF(millisecond, @dbSearchStart, @dbSearchEnd))
            IF @dbEndMessage IS NOT NULL
                RAISERROR(@dbEndMessage, 0, 0, @now, @dbName, @duration) WITH NOWAIT;

            FETCH NEXT FROM db INTO @dbName;
        END

        CLOSE db;        --Close cursor for databases
        DEALLOCATE db;   --Deallocate cursofr foor database

        --print end timestamp and duration
        SET @end = SYSDATETIME()
        SET @now = CONVERT(nvarchar(24), @end, 121);
        SET @duration = CONVERT(nvarchar(10), DATEDIFF(millisecond, @start, @end))
        IF (@endMessage IS NOT NULL)
            RAISERROR(@endMessage, 0, 0, @now, @duration) WITH NOWAIT;

        FETCH NEXT FROM scope INTO @currentScope;
    END



CLOSE scope;        --Clsoes the SearchScope Cusros
DEALLOCATE scope;   --Deallocates the SearchScope Cursor


--Return results to caller
SELECT
    *
FROM @Results
ORDER BY DatabaseName, ObjectType, ObjectName;

--DROP temprorary tables
DROP TABLE #objTypes;

END --End of Procedure
GO
EXECUTE sp_ms_marksystemobject N'dbo.sp_find'
GO
