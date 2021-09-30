USE [SSISDB]
GO

/*
                        EXECUTION SPEAD-UP

    This Index speeds up the SSIS Packages execution extremely. 
    It speedups lookups of every executed executable in the SSIS package . 
    In case large number of packages or large number of executables inside a package being executed the time reduction is extreme.
*/
IF NOT EXISTS(
    SELECT
        ic.index_id
        ,COUNT(index_id)
    FROM (
    SELECT
        ic.object_id
        ,ic.index_id
        ,c.name
        ,ic.index_column_id
        ,ic.key_ordinal
        ,is_included_column
    FROM sys.index_columns ic
    INNER JOIN sys.columns c ON c.column_id = ic.column_id AND c.object_id = ic.object_id
    WHERE
        ic.object_id = OBJECT_ID('[internal].[executables]')
        AND
        (
            (c.name = 'project_id' AND ic.key_ordinal = 1)
            OR
            (c.name = 'project_version_lsn' AND ic.key_ordinal = 2)
            OR
            (c.name = 'package_name' AND ic.key_ordinal = 3)

        )
    ) ic
    GROUP BY
        ic.index_id
    HAVING COUNT(index_id) = 3
)
BEGIN
    CREATE NONCLUSTERED INDEX [IX_PP_Executables_project_id_project_version_lsn_package_name] ON [internal].[executables]
    (
	    [project_id] ASC,
	    [project_version_lsn] ASC,
	    [package_name] ASC
    )
END
GO



IF NOT EXISTS(
    SELECT
        ic.index_id
        ,COUNT(index_id)
    FROM (
    SELECT
        ic.object_id
        ,ic.index_id
        ,c.name
        ,ic.index_column_id
        ,ic.key_ordinal
        ,is_included_column
    FROM sys.index_columns ic
    INNER JOIN sys.columns c ON c.column_id = ic.column_id AND c.object_id = ic.object_id
    WHERE
        ic.object_id = OBJECT_ID('[internal].[executables]')
        AND
        (
            (c.name = 'package_name' AND ic.key_ordinal = 1)
            OR
            (c.name = 'project_version_lsn' AND ic.key_ordinal = 2)
            OR
            (c.name = 'executable_name' AND (ic.key_ordinal > 2 OR ic.is_included_column = 1))
            OR
            (c.name = 'package_path' AND (ic.key_ordinal > 2 OR ic.is_included_column = 1))

        )
    ) ic
    GROUP BY
        ic.index_id
    HAVING COUNT(index_id) = 4
)
BEGIN
    CREATE NONCLUSTERED INDEX [IX_PP_executable_project_package_name_project_version_lsn_Filtered] ON [internal].[executables]
    (
	    [package_name] ASC,
	    [project_version_lsn] ASC
    )
    INCLUDE([executable_name],[package_path]) 
    WHERE ([package_path]='\Package')
END

/*
            DEPLOYMENT ISSUES RESOLVING

When deploying a large project with lots of packages, after some time deployment timeout will start occurring.  
This is caused by call to below stored procedure which will start executing longer than 30 seconds and causing large amounts of reads.

exec [internal].[sync_parameter_versions] @project_id=xxx,@object_version_lsn=xxx

To resolve the issue, the below indexes needs to be created in the SSISDB.
*/

IF NOT EXISTS(
    SELECT
        ic.index_id
        ,COUNT(index_id)
    FROM (
    SELECT
        ic.object_id
        ,ic.index_id
        ,c.name
        ,ic.index_column_id
        ,ic.key_ordinal
        ,is_included_column
    FROM sys.index_columns ic
    INNER JOIN sys.columns c ON c.column_id = ic.column_id AND c.object_id = ic.object_id
    WHERE
        ic.object_id = OBJECT_ID('[internal].[object_parameters]')
        AND
        (
            (c.name = 'project_id' AND ic.key_ordinal = 1)
            OR
            (c.name = 'project_version_lsn' AND ic.key_ordinal = 2)

        )
    ) ic
    GROUP BY
        ic.index_id
    HAVING COUNT(index_id) = 2
)
BEGIN
    CREATE NONCLUSTERED INDEX [IX_PP_object_parameters_DeployIssue]
    ON [internal].[object_parameters] (
        [project_id],
        [project_version_lsn]
    )
    INCLUDE (
        [parameter_id],[object_type],[object_name],[parameter_name],[parameter_data_type],[required],[sensitive]
    )
END
GO

IF NOT EXISTS(
    SELECT
        ic.index_id
        ,COUNT(index_id)
    FROM (
    SELECT
        ic.object_id
        ,ic.index_id
        ,c.name
        ,ic.index_column_id
        ,ic.key_ordinal
        ,is_included_column
    FROM sys.index_columns ic
    INNER JOIN sys.columns c ON c.column_id = ic.column_id AND c.object_id = ic.object_id
    WHERE
        ic.object_id = OBJECT_ID('[internal].[object_parameters]')
        AND
        (
            (c.name = 'project_id' AND ic.key_ordinal = 1)
            OR
            (c.name = 'project_version_lsn' AND ic.key_ordinal = 2)
            OR
            (c.name = 'object_type' AND ic.key_ordinal = 3)
            OR
            (c.name = 'object_name' AND ic.key_ordinal = 4)
            OR
            (c.name = 'parameter_data_type' AND ic.key_ordinal = 5)
            OR
            (c.name = 'required' AND ic.key_ordinal = 6)
            OR
            (c.name = 'sensitive' AND ic.key_ordinal = 7)

        )
    ) ic
    GROUP BY
        ic.index_id
    HAVING COUNT(index_id) = 7
)
BEGIN
    CREATE NONCLUSTERED INDEX [IX_PP_object_parameters_DeployIssue2]
    ON [internal].[object_parameters] (
        [project_id],
        [project_version_lsn],
        [object_type],
        [object_name],
        [parameter_data_type],
        [required],
        [sensitive]
    )
    INCLUDE ([parameter_name],[default_value],[sensitive_default_value],[value_type],[value_set],[referenced_variable_name])
END
GO



--Additional Supporting indexes
IF NOT EXISTS(
    SELECT
        ic.object_id
        ,ic.index_id
        ,c.name
        ,ic.index_column_id
        ,ic.key_ordinal
        ,is_included_column
    FROM sys.index_columns ic
    INNER JOIN sys.columns c ON c.column_id = ic.column_id AND c.object_id = ic.object_id
    WHERE
        ic.object_id = OBJECT_ID('[internal].[event_messages]')
        AND
        c.name = 'operation_id'
        AND
        ic.key_ordinal = 1
)
BEGIN
    CREATE NONCLUSTERED INDEX [IX_PP_event_messages_operation_id] ON [internal].[event_messages]
    (
	    [operation_id] ASC
    )
END;



IF NOT EXISTS (
    SELECT
        ic.index_id
        ,COUNT(index_id)
    FROM (
    SELECT
        ic.object_id
        ,ic.index_id
        ,c.name
        ,ic.index_column_id
        ,ic.key_ordinal
        ,is_included_column
    FROM sys.index_columns ic
    INNER JOIN sys.columns c ON c.column_id = ic.column_id AND c.object_id = ic.object_id
    WHERE
        ic.object_id = OBJECT_ID('[internal].[executable_statistics]')
        AND
        (
            (c.name = 'execution_id' AND ic.key_ordinal = 1)
            OR
            (c.name = 'statistics_id' AND (ic.key_ordinal > 1 OR ic.is_included_column = 1))

        )
    ) ic
    GROUP BY
        ic.index_id
    HAVING COUNT(index_id) = 2
)
BEGIN
    CREATE NONCLUSTERED INDEX [IX_PP_executable_statistics_execution_id] ON [internal].[executable_statistics]
    (
	    [execution_id] ASC
    )
    INCLUDE([statistics_id])
END
GO


IF NOT EXISTS (
    SELECT
        ic.index_id
        ,COUNT(index_id)
    FROM (
    SELECT
        ic.object_id
        ,ic.index_id
        ,c.name
        ,ic.index_column_id
        ,ic.key_ordinal
        ,is_included_column
    FROM sys.index_columns ic
    INNER JOIN sys.columns c ON c.column_id = ic.column_id AND c.object_id = ic.object_id
    WHERE
        ic.object_id = OBJECT_ID('[internal].[execution_component_phases]')
        AND
        (
            (c.name = 'execution_id' AND ic.key_ordinal = 1)
            OR
            (c.name = 'sequence_id' AND ic.key_ordinal = 2)

        )
    ) ic
    GROUP BY
        ic.index_id
    HAVING COUNT(index_id) = 2
)
BEGIN
    CREATE NONCLUSTERED INDEX [IX_PP_execution_component_phases_execution_id_sequence_id] ON [internal].[execution_component_phases]
    (
	    [execution_id] ASC,
	    [sequence_id] ASC
    )
END
GO


IF NOT EXISTS (
    SELECT
        ic.index_id
        ,COUNT(index_id)
    FROM (
    SELECT
        ic.object_id
        ,ic.index_id
        ,c.name
        ,ic.index_column_id
        ,ic.key_ordinal
        ,is_included_column
    FROM sys.index_columns ic
    INNER JOIN sys.columns c ON c.column_id = ic.column_id AND c.object_id = ic.object_id
    WHERE
        ic.object_id = OBJECT_ID('[internal].[operation_messages]')
        AND
        (
            (c.name = 'operation_id' AND ic.key_ordinal = 1)
            OR
            (c.name = 'operation_message_id' AND (ic.key_ordinal > 1 OR ic.is_included_column = 1))

        )
    ) ic
    GROUP BY
        ic.index_id
    HAVING COUNT(index_id) = 2
)
BEGIN
    CREATE NONCLUSTERED INDEX [IX_PP_operation_messages_operation_id] ON [internal].[operation_messages]
    (
	    [operation_id] ASC
    )
    INCLUDE([operation_message_id])
END
GO

IF NOT EXISTS (
    SELECT
        ic.index_id
        ,COUNT(index_id)
    FROM (
    SELECT
        ic.object_id
        ,ic.index_id
        ,c.name
        ,ic.index_column_id
        ,ic.key_ordinal
        ,is_included_column
    FROM sys.index_columns ic
    INNER JOIN sys.columns c ON c.column_id = ic.column_id AND c.object_id = ic.object_id
    WHERE
        ic.object_id = OBJECT_ID('[internal].[event_message_context]')
        AND
        (
            (c.name = 'operation_id' AND ic.key_ordinal = 1)
            OR
            (c.name = 'event_message_id' AND ic.key_ordinal = 2)
            OR
            (c.name = 'context_id' AND (ic.key_ordinal > 2 OR ic.is_included_column = 1))

        )
    ) ic
    GROUP BY
        ic.index_id
    HAVING COUNT(index_id) = 3
)
BEGIN
    CREATE NONCLUSTERED INDEX [IX_PP_event_message_context_operation_id_event_message_id] ON [internal].[event_message_context]
    (
	    [operation_id] ASC,
	    [event_message_id] ASC
    )
    INCLUDE([context_id])
END



IF NOT EXISTS (
    SELECT
        ic.index_id
        ,COUNT(index_id)
    FROM (
    SELECT
        ic.object_id
        ,ic.index_id
        ,c.name
        ,ic.index_column_id
        ,ic.key_ordinal
        ,is_included_column
    FROM sys.index_columns ic
    INNER JOIN sys.columns c ON c.column_id = ic.column_id AND c.object_id = ic.object_id
    WHERE
        ic.object_id = OBJECT_ID('[internal].[event_message_context]')
        AND
        (
            (c.name = 'event_message_id' AND ic.key_ordinal = 1)
        )
    ) ic
    GROUP BY
        ic.index_id
    HAVING COUNT(index_id) = 1
)
BEGIN
    CREATE NONCLUSTERED INDEX [IX_PP_event_message_context_event_message_id] ON [internal].[event_message_context]
    (
	    [event_message_id] ASC
    )
END
