-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                     Copyright (C) 2010, AdaCore                   --
--                                                                   --
-- GPS is free  software;  you can redistribute it and/or modify  it --
-- under the terms of the GNU General Public License as published by --
-- the Free Software Foundation; either version 2 of the License, or --
-- (at your option) any later version.                               --
--                                                                   --
-- This program is  distributed in the hope that it will be  useful, --
-- but  WITHOUT ANY WARRANTY;  without even the  implied warranty of --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details. You should have received --
-- a copy of the GNU General Public License along with this library; --
-- if not,  write to the  Free Software Foundation, Inc.,  59 Temple --
-- Place - Suite 330, Boston, MA 02111-1307, USA.                    --
-----------------------------------------------------------------------

--  This package handles the on-the-fly creation of an environment to
--  compile a file from the currently loaded project tree without actually
--  modifying it, by creating an Extending project.

with GNATCOLL.VFS; use GNATCOLL.VFS;
with Remote;       use Remote;

with GPS.Kernel;   use GPS.Kernel;

package Extending_Environments is

   type Extending_Environment is private;

   function Get_File (Env : Extending_Environment) return Virtual_File;
   --  Return the source file in Env

   function Get_Project (Env : Extending_Environment) return Virtual_File;
   --  Return the project file in Env

   function Create_Extending_Environment
     (Kernel : Kernel_Handle;
      Source : Virtual_File;
      Server : Server_Type) return Extending_Environment;
   --  Create an extending environment needed to build Source.
   --  The current Source is copied as-is from the current buffer into the
   --  extending environment.
   --  This environment should be Destroyed when no longer needed.

   procedure Destroy (Env : Extending_Environment);
   --  Remove files created for Env

private

   type Extending_Environment is record
      File          : Virtual_File := No_File;
      Project_File  : Virtual_File := No_File;
      Temporary_Dir : Virtual_File := No_File;
   end record;

end Extending_Environments;
