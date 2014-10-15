------------------------------------------------------------------------------
--                                  G P S                                   --
--                                                                          --
--                       Copyright (C) 2014, AdaCore                        --
--                                                                          --
-- This is free software;  you can redistribute it  and/or modify it  under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  This software is distributed in the hope  that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.  You should have  received  a copy of the GNU --
-- General  Public  License  distributed  with  this  software;   see  file --
-- COPYING3.  If not, go to http://www.gnu.org/licenses for a complete copy --
-- of the license.                                                          --
------------------------------------------------------------------------------

with Ada.Containers.Hashed_Maps;
with Ada.Containers; use Ada.Containers;
with GNATCOLL.VFS; use GNATCOLL.VFS;
with GNATCOLL.Projects; use GNATCOLL.Projects;
with GNATCOLL.Utils; use GNATCOLL.Utils;
with Language.Libclang.Utils; use Language.Libclang.Utils;
with Ada.Strings.Hash;
with Ada.Unchecked_Deallocation;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package body Language.Libclang is

   Diagnostics : constant Trace_Handle :=
     GNATCOLL.Traces.Create ("COMPLETION_LIBCLANG.DIAGNOSTICS", Off);

   function Hash (Project : Project_Type) return Hash_Type is
     (Ada.Strings.Hash (Project.Name));

   package TU_Maps is new Ada.Containers.Hashed_Maps
     (Virtual_File, Clang_Translation_Unit, Full_Name_Hash, "=");
   type Tu_Map_Access is access all TU_Maps.Map;

   type Clang_Context is record
      TU_Cache : Tu_Map_Access;
      Clang_Indexer : Clang_Index;
   end record;

   procedure Free
   is new Ada.Unchecked_Deallocation (TU_Maps.Map, Tu_Map_Access);
   pragma Unreferenced (Free);

   package Clang_Cache_Maps is new Ada.Containers.Hashed_Maps
     (Project_Type, Clang_Context, Hash, "=");

   Global_Cache : Clang_Cache_Maps.Map;
   --  Global state of libclang, should probably be put into the kernel

   procedure Initialize (Context : in out Clang_Context);

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize (Context : in out Clang_Context) is
   begin
      Context.Clang_Indexer := Create_Index (True, Active (Diagnostics));
      Context.TU_Cache := new TU_Maps.Map;
   end Initialize;

   ----------------------
   -- Translation_Unit --
   ----------------------

   function Translation_Unit
     (Kernel : Core_Kernel;
      File : GNATCOLL.VFS.Virtual_File;
      Unsaved_Files : Unsaved_File_Array := No_Unsaved_Files)
      return Clang_Translation_Unit
   is
   begin
      declare
         --  ??? We should fill other unsaved_files! ??? Or should we ? I think
         --  that filling the current file as unsaved is enough. We can, at
         --  least in the first iteration of libclang, ask the user to save
         --  the other files if he expects to get completion. RA

         Lang             : constant String :=
           Kernel.Lang_Handler.Get_Language_From_File (File);
         C_Switches       : GNAT.Strings.String_List_Access;
         Ignored          : Boolean;

         F_Info : constant File_Info'Class :=
           File_Info'Class
             (Kernel.Registry.Tree.Info_Set
                (File).First_Element);

         Context : Clang_Context;
      begin
         if not Global_Cache.Contains (F_Info.Project) then
            Initialize (Context);
            Global_Cache.Insert (F_Info.Project, Context);
         else
            Context := Global_Cache.Element (F_Info.Project);
         end if;

         if Unsaved_Files = No_Unsaved_Files
           and then Context.TU_Cache.Contains (File)
         then
            return Context.TU_Cache.Element (File);
         end if;

         --  Retrieve the switches for this file
         Switches (F_Info.Project,
                   "compiler", File, Lang, C_Switches, Ignored);

         declare
            The_Switches     : Unbounded_String_Array (C_Switches'Range);
            TU : Clang_Translation_Unit;
            Dummy : Boolean;
         begin
            for J in C_Switches'Range loop
               The_Switches (J) := To_Unbounded_String (C_Switches (J).all);
            end loop;

            if Context.TU_Cache.Contains (File) then
               --  If the key is in the cache, we know that File_Content is not
               --  null, so we want to reparse

               TU := Context.TU_Cache.Element (File);
               Dummy := Reparse_Translation_Unit (TU, Unsaved_Files);
            else
               --  In the other case, this is the first time we're parsing this
               --  file

               TU := Parse_Translation_Unit
                 (Index             => Context.Clang_Indexer,
                  Source_Filename   => String (File.Full_Name.all),
                  Command_Line_Args =>

                  --  We pass to libclang a list of switches made of:
                  --  ... the C/C++ switches specified in this project
                  The_Switches

                  --  ... a -I<dir> for each directory in the subprojects
                  --  of this project
                  & Get_Project_Source_Dirs
                    (Kernel, F_Info.Project, Lang)

                  --  ... a -I<dir> for each dir in the compiler search path
                  & Get_Compiler_Search_Paths
                    (Kernel, F_Info.Project, Lang),

                  Unsaved_Files     => Unsaved_Files,
                  Options           => No_Translation_Unit_Flags);
            end if;

            GNAT.Strings.Free (C_Switches);
            return TU;
         end;
      end;
   end Translation_Unit;

end Language.Libclang;
