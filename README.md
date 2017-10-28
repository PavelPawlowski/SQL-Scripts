# SQL-Scripts
This project contain scripts for SQL Server in different Areas

## Searching
Scripts for simplifying searching of objects on SQL Server

### sp_find
Powerfull stored procedure for searching objects on SQL Server. Searching by name or by object definition. ALlows Searching Database scope objects, Server Scoped objects as well as searching SSIS packages stored in both SSISDB and msdb.

## Rights Management
Righs management folder contains script usable for managing user rigts

### sp_CloneRights
Stored procedure for scripting database objects rights granted to a database principal or to clone the database objects rights among principals

### sp_HelpRights
Stored procedure provides overview about rights assignments in database.

## SSISDB
SSISDB folder contains scripts related to SSIS

### sp_ssisdb
Stored procedure provides information about operations in ssisdb.
It tool for easy (and advanced) analysis of what is going on on SSIS Server.
Use `sp_ssisdb '?'` for detailed help

### sp_SSISCloneEnvironment
Stored procedure for clonning SSIS server variables from one environment to another. It supports generation of easily reusable scripts for replication of the SSIS Server variables amont environments.

### sp_SSISCloneConfiguration
Stored procedure cones SSIS project configuration from one project to another.
Allows simple scripting of exsting configuration for easy transfer among environments or backup purposes

### sp_SSISCloneProject
Stored procedure for clonning SSIS project(s) among folders and servers.
Allows simple deployment of projects among servers through linked servers.

### sp_SSISMapEnvironment
Stored procedure maps Project/Object configuraiton parameters to corresponding Environment variables
Mapping is done on parameter and variable name as well as data type.

### sp_SSISListEnvironment
Stored procedure allows easy listing of environment variables and their values.
Allows decryption of encrypted variable values.

### sp_SSISResetConfiguration
Stored procedure allows easy reset of Project/Object/Parameter configuration values.

# msdb
Stored procedures for stuff related to msdb

## sp_jobStatus
Stored procedure allows easy generation of scripts for setting status of agent jobs. 
Usefull during maintenance breaks to generate script for disbling all active jobs and their easy re-enabling by simple parameter change.
