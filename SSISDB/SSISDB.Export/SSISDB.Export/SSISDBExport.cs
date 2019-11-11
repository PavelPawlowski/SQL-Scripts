using SSISDB.Export.Properties;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.IO;
using System.Linq;
using System.Text;

public class SSISDBExport
{
    /// <summary>
    /// Context connection string
    /// </summary>
    public const string ContextConnectionString = "context connection=true";

    /// <summary>
    /// Exports a version of SSISDB projet to .ispac file
    /// </summary>
    /// <param name="project_name">Name of the project to export</param>
    /// <param name="project_id">project_id of project to export</param>
    /// <param name="project_version">object_version_lsn of the project to export</param>
    /// <param name="destination_file">path to destination .ispac file</param>
    /// <param name="connectionString">connection string to the SSISDB</param>
    private static void ExportProjectInternal(string project_name, long project_id, long project_version, string destination_file, string connectionString, bool createPath)
    {
        byte[] buffer = new byte[65536];
        long bytesRead = 0;
        long dataIndex = 0;

        using (SqlConnection con = new SqlConnection(connectionString))
        {
            //Command to execute the [internal].[get_project_internal] to get the decrypted data stream with project content
            SqlCommand cmd = new SqlCommand(Resources.ExportProject, con);
            cmd.Parameters.AddWithValue("@project_version_lsn", project_version);
            cmd.Parameters.AddWithValue("@project_id", project_id);
            cmd.Parameters.AddWithValue("@project_name", project_name);

            con.Open();

            //get the decrypted project data stream 
            using (var reader = cmd.ExecuteReader(System.Data.CommandBehavior.SingleRow | System.Data.CommandBehavior.SequentialAccess))
            {
                if (reader.Read())
                {
                    if (createPath)
                    {
                        var path = Path.GetDirectoryName(destination_file);
                        Directory.CreateDirectory(path);
                    }

                    //Create the ouptu .ispac file
                    using (FileStream fs = File.Open(destination_file, FileMode.Create))
                    {
                        //Read the project data in 64kB chunks and write to the output .ispac file
                        do
                        {
                            bytesRead = reader.GetBytes(0, dataIndex, buffer, 0, buffer.Length);
                            dataIndex += bytesRead;

                            fs.Write(buffer, 0, (int)bytesRead);

                        } while (bytesRead == buffer.LongLength);

                        fs.Close();
                    }

                }
            }

            con.Close();
        }
    }

    /// <summary>
    /// Procedure to test exports
    /// </summary>
    /// <param name="dataSource">data source (instance) to connect</param>
    /// <param name="project_name">Name of the project to export</param>
    /// <param name="project_id">project_id of project to export</param>
    /// <param name="project_version">object_version_lsn of the project to export</param>
    /// <param name="destination_file">path to destination .ispac file</param>
    public static void ExportProjectTest(string dataSource, string project_name, long project_id, long project_version, string destination_file, bool createPath)
    {

        SqlConnectionStringBuilder builder = new SqlConnectionStringBuilder();
        builder.InitialCatalog = "SSISDB";
        builder.IntegratedSecurity = true;
        builder.DataSource = dataSource;

        ExportProjectInternal(project_name, project_id, project_version, destination_file, builder.ToString(), createPath);
    }

    /// <summary>
    /// SQL Stored procedure to export SSISDB proejct version to .ispac file
    /// </summary>
    /// <param name="project_name">Name of the project to export</param>
    /// <param name="project_id">project_id of project to export</param>
    /// <param name="project_version">object_version_lsn of the project to export</param>
    /// <param name="destination_file">path to destination .ispac file</param>
    [Microsoft.SqlServer.Server.SqlProcedure]
    public static void ExportProject(string project_name, long project_id, long project_version, string destination_file, bool createPath)
    {

        ExportProjectInternal(project_name, project_id, project_version, destination_file, ContextConnectionString, createPath);

    }
}