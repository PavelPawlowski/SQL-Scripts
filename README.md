# SQL-Scripts

This project contain scripts for SQL Server in different Areas.

## Searching

Scripts for simplifying searching of objects on SQL Server.

### sp_find

Powerful stored procedure for searching objects on SQL Server. Searching by name or by object definition. Allows Searching Database scope objects, Server Scoped objects as well as searching SSIS packages stored in both SSISDB and msdb.

## Rights Management

Righs management folder contains script usable for managing user rights.

### sp_CloneRights

Stored procedure for scripting database objects rights granted to a database principal or to clone the database objects rights among principals.

### sp_HelpRights

Stored procedure provides overview about rights assignments in database.

## SSISDB

SSISDB folder contains scripts related to SSIS.

### sp_ssisdb

Stored procedure provides information about operations in ssisdb.
It tool for easy (and advanced) analysis of what is going on on SSIS Server.
Use `sp_ssisdb '?'` for detailed help.

### sp_SSISCloneEnvironment

Stored procedure for cloning SSIS server variables from one environment to another. It supports generation of easily reusable scripts for replication of the SSIS Server variables among environments.

### sp_SSISCloneConfiguration

Stored procedure cones SSIS project configuration from one project to another.
Allows simple scripting of existing configuration for easy transfer among environments or backup purposes.

### sp_SSISClonePermissions

Stored procedure clones permissions on objects in SSISDB catalog.
Allows easy scripting of existing granular permissions on Folders, Project and Environments.

### sp_SSISCloneProject

Stored procedure for cloning SSIS project(s) among folders and servers.
Allows simple deployment of projects among servers through linked servers.

### sp_SSISMapEnvironment

Stored procedure maps Project/Object configuration parameters to corresponding Environment variables.
Mapping is done on parameter and variable name as well as data type.

### sp_SSISListEnvironment

Stored procedure allows easy listing of environment variables and their values.
Allows decryption of encrypted variable values.

### sp_SSISResetConfiguration

Stored procedure allows easy reset of Project/Object/Parameter configuration values.

### usp_cleanup_server_retention_window

Cleanups SSISDB catalog from all kind of log mesasges belonging to operations past specified data or retention window

### usp_cleanup_key_certificates

Cleanups SSISDB catalog from left over certificates and symmetric keys

## msdb

Stored procedures for stuff related to msdb.

### sp_jobStatus
Stored procedure allows easy generation of scripts for setting status of agent jobs. 
Useful during maintenance breaks to generate script for disabling all active jobs and their easy re-enabling by simple parameter change.

## Tables Management

Contains stored procedures for managing tables.

### Partitioning
 
Contains stored procedure for managing partitioned tables.

#### sp_tblCreatePartitionFunction

Generates Partition function for specified range of dates in specified format.

#### sp_HelpPartitionFunction

Provides information about the partition function including partitions it will generate and their boundary values.
Procedure also lists depended partition schemes and tables/indexed views/indexes using that partition function.

#### sp_HelpPartitionScheme

Provides information about the partition scheme including the partition function it is based on and partition boundary values.
Procedure also lists depended tables and indexes using the partition scheme.

