using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace TestApp
{
    class Program
    {
        static void Main(string[] args)
        {

            SSISDBExport.ExportProjectTest("L00SRV2122,5001", "TestProject", 145, 2398, @"FC:\temp\test.ispac", true);
        }


    }
}
