-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                 Copyright (C) 2001-2008, AdaCore                  --
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
-- a copy of the GNU General Public License along with this program; --
-- if not,  write to the  Free Software Foundation, Inc.,  59 Temple --
-- Place - Suite 330, Boston, MA 02111-1307, USA.                    --
-----------------------------------------------------------------------

with Ada.Unchecked_Deallocation; use Ada;

with GNAT.Case_Util;             use GNAT.Case_Util;
with GNAT.Directory_Operations;  use GNAT.Directory_Operations;
with GNAT.OS_Lib;                use GNAT.OS_Lib;
with GNAT.Strings;
with GNATCOLL.Filesystem;        use GNATCOLL.Filesystem;
with GNATCOLL.VFS;               use GNATCOLL.VFS;

with Glib;                       use Glib;
with Glib.Convert;               use Glib.Convert;
with Glib.Object;                use Glib.Object;
with Glib.Values;                use Glib.Values;
with Glib.Xml_Int;               use Glib.Xml_Int;
with Gdk.Dnd;                    use Gdk.Dnd;
with Gdk.Event;                  use Gdk.Event;
with Gtk.Check_Menu_Item;        use Gtk.Check_Menu_Item;
with Gtk.Dnd;                    use Gtk.Dnd;
with Gtk.Handlers;               use Gtk.Handlers;
with Gtk.Main;                   use Gtk.Main;
with Gtk.Object;                 use Gtk.Object;
with Gtk.Tree_View;              use Gtk.Tree_View;
with Gtk.Tree_Selection;         use Gtk.Tree_Selection;
with Gtk.Tree_Store;             use Gtk.Tree_Store;
with Gtk.Cell_Renderer_Text;     use Gtk.Cell_Renderer_Text;
with Gtk.Cell_Renderer_Pixbuf;   use Gtk.Cell_Renderer_Pixbuf;
with Gtk.Enums;                  use Gtk.Enums;
with Gtk.Menu;                   use Gtk.Menu;
with Gtk.Scrolled_Window;        use Gtk.Scrolled_Window;
with Gtk.Tree_View_Column;       use Gtk.Tree_View_Column;
with Gtk.Tree_Model;             use Gtk.Tree_Model;
with Gtk.Widget;                 use Gtk.Widget;
with Gtkada.MDI;                 use Gtkada.MDI;
with Gtkada.Handlers;            use Gtkada.Handlers;

with GPS.Kernel.Contexts;        use GPS.Kernel.Contexts;
with GPS.Kernel.Hooks;           use GPS.Kernel.Hooks;
with GPS.Kernel.MDI;             use GPS.Kernel.MDI;
with GPS.Kernel.Modules;         use GPS.Kernel.Modules;
with GPS.Kernel.Project;         use GPS.Kernel.Project;
with GPS.Kernel.Standard_Hooks;  use GPS.Kernel.Standard_Hooks;
with GPS.Kernel;                 use GPS.Kernel;
with GPS.Intl;                   use GPS.Intl;
with Projects;                   use Projects;
with Projects.Registry;          use Projects.Registry;
with Remote;                     use Remote;
with String_List_Utils;          use String_List_Utils;
with File_Utils;                 use File_Utils;
with GUI_Utils;                  use GUI_Utils;
with OS_Utils;                   use OS_Utils;
with Traces;                     use Traces;
with Histories;                  use Histories;
with Project_Explorers_Common;   use Project_Explorers_Common;

with Namet;                      use Namet;

package body Project_Explorers_Files is

   Explorer_Files_Module_Id     : Module_ID;

   File_View_Shows_Only_Project : constant History_Key :=
     "explorers-file-show-project-only";

   type Explorer_Module_Record is new Module_ID_Record with null record;
   overriding procedure Default_Context_Factory
     (Module  : access Explorer_Module_Record;
      Context : in out Selection_Context;
      Child   : Gtk.Widget.Gtk_Widget);
   --  See inherited documentation

   type Append_Directory_Idle_Data is record
      Explorer      : Project_Explorer_Files;
      Norm_Dest     : GNAT.Strings.String_Access;
      Norm_Dir      : GNAT.Strings.String_Access;
      D             : GNAT.Directory_Operations.Dir_Type;
      Depth         : Integer := 0;
      Base          : Gtk_Tree_Iter;
      Dirs          : String_List_Utils.String_List.List;
      Files         : String_List_Utils.String_List.List;
      Idle          : Boolean := False;
      Physical_Read : Boolean := True;
   end record;

   procedure Free is
     new Unchecked_Deallocation (Append_Directory_Idle_Data,
                                 Append_Directory_Idle_Data_Access);

   procedure Set_Column_Types (Tree : Gtk_Tree_View);
   --  Sets the types of columns to be displayed in the tree_view

   function Parse_Path
     (Path : String) return String_List_Utils.String_List.List;
   --  Parse a path string and return a list of all directories in it

   procedure File_Append_Directory
     (Explorer      : access Project_Explorer_Files_Record'Class;
      Dir           : String;
      Base          : Gtk_Tree_Iter;
      Depth         : Integer := 0;
      Append_To_Dir : String  := "";
      Idle          : Boolean := False;
      Physical_Read : Boolean := True);
   --  Add to the file view the directory Dir, at node given by Iter.
   --  If Append_To_Dir is not "", and is a sub-directory of Dir, then
   --  the path is expanded recursively all the way to Append_To_Dir.

   procedure File_Tree_Expand_Row_Cb
     (Explorer : access Gtk.Widget.Gtk_Widget_Record'Class;
      Values   : GValues);
   --  Called every time a node is expanded in the file view.
   --  It is responsible for automatically adding the children of the current
   --  node if they are not there already.

   function Expose_Event_Cb
     (Explorer : access Glib.Object.GObject_Record'Class;
      Values   : GValues) return Boolean;
   --  Scroll the explorer to the current directory

   procedure File_Tree_Collapse_Row_Cb
     (Explorer : access Gtk.Widget.Gtk_Widget_Record'Class;
      Values   : GValues);
   --  Called every time a node is collapsed in the file view

   procedure On_File_Destroy
     (Explorer : access Gtk.Widget.Gtk_Widget_Record'Class;
      Params : Glib.Values.GValues);
   --  Callback for the "destroy" event on the file view

   procedure File_Remove_Idle_Calls
     (Explorer : access Project_Explorer_Files_Record'Class);
   --  Remove the idle calls for filling the file view

   function File_Button_Press
     (Explorer : access Gtk_Widget_Record'Class;
      Event    : Gdk_Event) return Boolean;
   --  Callback for the "button_press" event on the file view

   function File_Key_Press
     (Explorer : access Gtk_Widget_Record'Class;
      Event    : Gdk_Event) return Boolean;
   --  Callback for the "key_press" event on the file view

   procedure File_Selection_Changed
     (Explorer : access Gtk_Widget_Record'Class);
   --  Callback for the "button_press" event on the file view

   procedure Free_Children
     (T    : Project_Explorer_Files;
      Iter : Gtk_Tree_Iter);
   --  Free all the children of iter Iter in the file view

   function Read_Directory
     (D : Append_Directory_Idle_Data_Access) return Boolean;
   --  ???
   --  Called by File_Append_Directory.

   procedure Explorer_Context_Factory
     (Context      : in out Selection_Context;
      Kernel       : access Kernel_Handle_Record'Class;
      Event_Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Object       : access Glib.Object.GObject_Record'Class;
      Event        : Gdk.Event.Gdk_Event;
      Menu         : Gtk_Menu);
   --  ??? Unused for now while the files explorer is not a separate module.
   --  Return the context to use for the contextual menu.
   --  It is also used to return the context for
   --  GPS.Kernel.Get_Current_Context, and thus can be called with a null
   --  event or a null menu.

   function Greatest_Common_Path
     (L : String_List_Utils.String_List.List) return String;
   --  Return the greatest common path to a list of directories

   procedure Refresh (Files : access Gtk.Widget.Gtk_Widget_Record'Class);
   --  Refresh the contents of the explorer

   function Load_Desktop
     (MDI  : MDI_Window;
      Node : Node_Ptr;
      User : Kernel_Handle) return MDI_Child;
   --  Restore the status of the explorer from a saved XML tree

   function Save_Desktop
     (Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      User   : Kernel_Handle)
      return Node_Ptr;
   --  Save the status of the project explorer to an XML tree

   procedure On_Open_Explorer
     (Widget : access GObject_Record'Class;
      Kernel : Kernel_Handle);
   --  Raise the existing explorer, or open a new one

   type File_View_Filter_Record is new Action_Filter_Record
      with null record;
   overriding function Filter_Matches_Primitive
     (Context : access File_View_Filter_Record;
      Ctxt    : GPS.Kernel.Selection_Context) return Boolean;

   -----------
   -- Hooks --
   -----------

   type Internal_Hook_Record is abstract new Function_With_Args with record
      View : Project_Explorer_Files;
   end record;

   type File_Deleted_Hook_Record is new Internal_Hook_Record with null record;
   type File_Deleted_Hook is access File_Deleted_Hook_Record'Class;

   type File_Saved_Hook_Record is new Internal_Hook_Record with null record;
   type File_Saved_Hook is access File_Saved_Hook_Record'Class;

   type File_Renamed_Hook_Record is new Internal_Hook_Record with null record;
   type File_Renamed_Hook is access File_Renamed_Hook_Record'Class;

   overriding procedure Execute
     (Hook   : File_Deleted_Hook_Record;
      Kernel : access Kernel_Handle_Record'Class;
      Data   : access Hooks_Data'Class);
   --  Callback for the "file_deleted" hook

   overriding procedure Execute
     (Hook   : File_Saved_Hook_Record;
      Kernel : access Kernel_Handle_Record'Class;
      Data   : access Hooks_Data'Class);
   --  Callback for the "file_saved" hook

   overriding procedure Execute
     (Hook   : File_Renamed_Hook_Record;
      Kernel : access Kernel_Handle_Record'Class;
      Data   : access Hooks_Data'Class);
   --  Callback for the "file_renamed" hook

   procedure Remove_File
     (View : Project_Explorer_Files;
      File : GNATCOLL.VFS.Virtual_File);
   --  Remove a file or directory node from the tree

   procedure Add_File
     (View : Project_Explorer_Files;
      File : GNATCOLL.VFS.Virtual_File);
   --  Add a file or directory node in the tree

   ------------------------------
   -- Filter_Matches_Primitive --
   ------------------------------

   overriding function Filter_Matches_Primitive
     (Context : access File_View_Filter_Record;
      Ctxt    : GPS.Kernel.Selection_Context) return Boolean
   is
      pragma Unreferenced (Context);
   begin
      return Module_ID (Get_Creator (Ctxt)) = Explorer_Files_Module_Id;
   end Filter_Matches_Primitive;

   -----------------------------
   -- Default_Context_Factory --
   -----------------------------

   overriding procedure Default_Context_Factory
     (Module  : access Explorer_Module_Record;
      Context : in out Selection_Context;
      Child   : Gtk.Widget.Gtk_Widget) is
   begin
      Explorer_Context_Factory
        (Context, Get_Kernel (Module.all), Child, Child, null, null);
   end Default_Context_Factory;

   --------------------
   -- Read_Directory --
   --------------------

   function Read_Directory
     (D : Append_Directory_Idle_Data_Access) return Boolean
   is
      File       : String (1 .. 1024);
      Last       : Natural;
      Path_Found : Boolean := False;
      Iter       : Gtk_Tree_Iter;
      New_D      : Append_Directory_Idle_Data_Access;

      use String_List_Utils.String_List;

   begin
      --  If we are appending at the base, create a node indicating the
      --  absolute path to the directory.

      if D.Base = Null_Iter then
         Append (D.Explorer.File_Model, Iter, D.Base);

         Set (D.Explorer.File_Model, Iter, Absolute_Name_Column,
              Locale_To_UTF8 (D.Norm_Dir.all));
         Set (D.Explorer.File_Model, Iter, Base_Name_Column,
              Locale_To_UTF8 (D.Norm_Dir.all));
         Set (D.Explorer.File_Model, Iter, Node_Type_Column,
              Gint (Node_Types'Pos (Directory_Node)));

         if D.Physical_Read then
            Set (D.Explorer.File_Model, Iter, Icon_Column,
                 C_Proxy (Open_Pixbufs (Directory_Node)));
            D.Base := Iter;

            return Read_Directory (D);

         else
            Append_Dummy_Iter (D.Explorer.File_Model, Iter);
            Set (D.Explorer.File_Model, Iter, Icon_Column,
                 C_Proxy (Close_Pixbufs (Directory_Node)));
            Pop_State (D.Explorer.Kernel);
            New_D := D;
            Free (New_D);

            return False;
         end if;
      end if;

      Read (D.D, File, Last);

      if D.Depth >= 0 and then Last /= 0 then
         if not (Last = 1 and then File (1) = '.')
           and then not (Last = 2 and then File (1 .. 2) = "..")
         then
            declare
               Name : constant String := File (File'First .. Last);
               P    : Project_Type;
            begin
               if Get_History
                 (Get_History (D.Explorer.Kernel).all,
                  File_View_Shows_Only_Project)
               then
                  if Is_Directory (D.Norm_Dir.all & Name) then
                     if Directory_Belongs_To_Project
                       (Get_Registry (D.Explorer.Kernel).all,
                        D.Norm_Dir.all & Name,
                        Direct_Only => False)
                     then
                        Append (D.Dirs, Locale_To_UTF8 (Name));
                     end if;

                  --  If the file belongs to the project hierarchy, we also
                  --  need to check that it is the one that really belongs to
                  --  the project, not a homonym in some other directory
                  else
                     P := Get_Project_From_File
                       (Get_Registry (D.Explorer.Kernel).all,
                        Name, Root_If_Not_Found => False);
                     Get_Full_Path_From_File
                       (Registry => Get_Registry (D.Explorer.Kernel).all,
                        Filename => Name,
                        Use_Source_Path => True,
                        Use_Object_Path => True,
                        Project => P);

                     if P /= No_Project
                       and then File_Equal
                         (Dir_Name (Name_Buffer (1 .. Name_Len)),
                          D.Norm_Dir.all, Build_Server)
                     then
                        Append (D.Files, Name);
                     end if;
                  end if;

               elsif Is_Directory (D.Norm_Dir.all & Name) then
                  Append (D.Dirs, Locale_To_UTF8 (Name));
               else
                  Append (D.Files, Locale_To_UTF8 (Name));
               end if;
            end;

            if D.Depth = 0 then
               D.Depth := -1;
            end if;
         end if;

         return True;
      end if;

      Close (D.D);

      if D.Idle then
         Pop_State (D.Explorer.Kernel);
         Push_State (D.Explorer.Kernel, Busy);
      end if;

      if Is_Case_Sensitive (Build_Server) then
         Sort (D.Dirs);
         Sort (D.Files);
      else
         Sort_Case_Insensitive (D.Dirs);
         Sort_Case_Insensitive (D.Files);
      end if;

      if Is_Empty (D.Dirs) and then Is_Empty (D.Files) then
         Set (D.Explorer.File_Model, D.Base, Icon_Column,
              C_Proxy (Close_Pixbufs (Directory_Node)));
      end if;

      while not Is_Empty (D.Dirs) loop
         declare
            Dir : constant String := Head (D.Dirs);
         begin
            Append (D.Explorer.File_Model, Iter, D.Base);
            Set (D.Explorer.File_Model, Iter, Absolute_Name_Column,
                 Locale_To_UTF8
                 (D.Norm_Dir.all & Dir & Directory_Separator));
            Set (D.Explorer.File_Model, Iter, Base_Name_Column,
                 Locale_To_UTF8 (Dir));
            Set (D.Explorer.File_Model, Iter, Node_Type_Column,
                 Gint (Node_Types'Pos (Directory_Node)));

            if D.Depth = 0 then
               exit;
            end if;

            --  Are we on the path to the target directory ?

            if not Path_Found
              and then D.Norm_Dir'Length + Dir'Length <= D.Norm_Dest'Length
              and then File_Equal
                (D.Norm_Dest
                   (D.Norm_Dest'First ..
                       D.Norm_Dest'First + D.Norm_Dir'Length + Dir'Length - 1),
                 D.Norm_Dir.all & Dir, Build_Server)
            then
               Path_Found := True;

               declare
                  Success   : Boolean;
                  pragma Unreferenced (Success);

                  Path      : Gtk_Tree_Path;
                  Expanding : constant Boolean := D.Explorer.Expanding;
               begin
                  Path := Get_Path (D.Explorer.File_Model, D.Base);

                  D.Explorer.Expanding := True;
                  Success := Expand_Row (D.Explorer.File_Tree, Path, False);
                  D.Explorer.Expanding := Expanding;

                  Set (D.Explorer.File_Model, D.Base, Icon_Column,
                       C_Proxy (Open_Pixbufs (Directory_Node)));

                  Path_Free (Path);
               end;

               --  Are we on the target directory ?

               if File_Equal
                 (D.Norm_Dest.all, D.Norm_Dir.all & Dir & Directory_Separator,
                  Build_Server)
               then
                  declare
                     Success   : Boolean;
                     pragma Unreferenced (Success);

                     Expanding : constant Boolean := D.Explorer.Expanding;
                  begin
                     D.Explorer.Path := Get_Path (D.Explorer.File_Model, Iter);

                     File_Append_Directory
                       (D.Explorer, D.Norm_Dir.all & Dir & Directory_Separator,
                        Iter, D.Depth, D.Norm_Dest.all, False);

                     D.Explorer.Expanding := True;
                     Success := Expand_Row
                       (D.Explorer.File_Tree,
                        D.Explorer.Path, False);
                     D.Explorer.Expanding := Expanding;

                     Select_Path
                       (Get_Selection (D.Explorer.File_Tree),
                        D.Explorer.Path);

                     Set (D.Explorer.File_Model, Iter, Icon_Column,
                          C_Proxy (Open_Pixbufs (Directory_Node)));
                     D.Explorer.Scroll_To_Directory := True;
                     D.Explorer.Realize_Cb_Id :=
                       Gtkada.Handlers.Object_Return_Callback.Object_Connect
                         (D.Explorer.File_Tree, Signal_Expose_Event,
                          Expose_Event_Cb'Access, D.Explorer, True);
                  end;

               else
                  File_Append_Directory
                    (D.Explorer, D.Norm_Dir.all & Dir & Directory_Separator,
                     Iter, D.Depth, D.Norm_Dest.all, D.Idle);
               end if;

            else
               Append_Dummy_Iter (D.Explorer.File_Model, Iter);

               Set (D.Explorer.File_Model, Iter, Icon_Column,
                    C_Proxy (Close_Pixbufs (Directory_Node)));
            end if;

            Next (D.Dirs);
         end;
      end loop;

      while not Is_Empty (D.Files) loop
         Append_File
           (D.Explorer.Kernel,
            D.Explorer.File_Model,
            D.Base,
            Create (Full_Filename => D.Norm_Dir.all & Head (D.Files)));
         Next (D.Files);
      end loop;

      Free (D.Norm_Dir);
      Free (D.Norm_Dest);

      Pop_State (D.Explorer.Kernel);

      New_D := D;
      Free (New_D);

      return False;

   exception
      when Directory_Error =>
         --  The directory couldn't be open, probably because of permissions

         New_D := D;
         Free (New_D);
         return False;

      when E : others =>
         Trace (Exception_Handle, E);
         return False;
   end Read_Directory;

   ---------------------------
   -- File_Append_Directory --
   ---------------------------

   procedure File_Append_Directory
     (Explorer      : access Project_Explorer_Files_Record'Class;
      Dir           : String;
      Base          : Gtk_Tree_Iter;
      Depth         : Integer := 0;
      Append_To_Dir : String  := "";
      Idle          : Boolean := False;
      Physical_Read : Boolean := True)
   is
      D : Append_Directory_Idle_Data_Access := new Append_Directory_Idle_Data;
      --  D is freed when Read_Directory ends (i.e. returns False)

      Timeout_Id : Timeout_Handler_Id;

   begin
      if Physical_Read then
         begin
            Open (D.D, Dir);
         exception
            when Directory_Error =>
               Free (D);
               return;
         end;

         --  Force a final directory separator, since otherwise on Windows
         --  "C:\" is converted to "C:" and only file names relative to the
         --  current directory will be returned
         D.Norm_Dir := new String'
           (Name_As_Directory (Normalize_Pathname (Dir)));
      else
         D.Norm_Dir := new String'
           (Name_As_Directory ((Normalize_Pathname (Dir))));
      end if;

      D.Norm_Dest     := new String'
        (Name_As_Directory (Normalize_Pathname (Append_To_Dir)));
      D.Depth         := Depth;
      D.Base          := Base;
      D.Explorer      := Project_Explorer_Files (Explorer);
      D.Idle          := Idle;
      D.Physical_Read := Physical_Read;

      if Idle then
         Push_State (Explorer.Kernel, Processing);
      else
         Push_State (Explorer.Kernel, Busy);
      end if;

      if Idle then
         --  Do not append the first item in an idle loop.
         --  Necessary for preserving order in drive names.

         if Read_Directory (D) then
            Timeout_Id :=
              File_Append_Directory_Timeout.Add (1, Read_Directory'Access, D);
            Timeout_Id_List.Append (Explorer.Fill_Timeout_Ids, Timeout_Id);
         end if;
      else
         loop
            exit when not Read_Directory (D);
         end loop;
      end if;
   end File_Append_Directory;

   ----------------------
   -- Set_Column_Types --
   ----------------------

   procedure Set_Column_Types (Tree : Gtk_Tree_View) is
      Col         : Gtk_Tree_View_Column;
      Text_Rend   : Gtk_Cell_Renderer_Text;
      Pixbuf_Rend : Gtk_Cell_Renderer_Pixbuf;
      Dummy       : Gint;
      pragma Unreferenced (Dummy);

   begin
      Gtk_New (Text_Rend);
      Gtk_New (Pixbuf_Rend);

      Set_Rules_Hint (Tree, False);

      Gtk_New (Col);
      Pack_Start (Col, Pixbuf_Rend, False);
      Pack_Start (Col, Text_Rend, True);
      Add_Attribute (Col, Pixbuf_Rend, "pixbuf", Icon_Column);
      Add_Attribute (Col, Text_Rend, "text", Base_Name_Column);
      Dummy := Append_Column (Tree, Col);
   end Set_Column_Types;

   -------------
   -- Gtk_New --
   -------------

   procedure Gtk_New
     (Explorer : out Project_Explorer_Files;
      Kernel   : access GPS.Kernel.Kernel_Handle_Record'Class) is
   begin
      Explorer := new Project_Explorer_Files_Record;
      Initialize (Explorer, Kernel);
   end Gtk_New;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (Explorer : access Project_Explorer_Files_Record'Class;
      Kernel   : access GPS.Kernel.Kernel_Handle_Record'Class)
   is
      Deleted_Hook : File_Deleted_Hook;
      Saved_Hook   : File_Saved_Hook;
      Renamed_Hook : File_Renamed_Hook;
   begin
      Gtk.Scrolled_Window.Initialize (Explorer);
      Set_Policy (Explorer, Policy_Automatic, Policy_Automatic);

      Gtk_New (Explorer.File_Model, Columns_Types);
      Gtk_New (Explorer.File_Tree, Explorer.File_Model);
      Set_Name (Explorer.File_Tree, "File Explorer Tree");

      --  The model should be destroyed as soon as the tree view is destroyed
      Unref (Explorer.File_Model);

      Explorer.Kernel := Kernel_Handle (Kernel);

      Add (Explorer, Explorer.File_Tree);

      Set_Headers_Visible (Explorer.File_Tree, False);

      Gtkada.Handlers.Return_Callback.Object_Connect
        (Explorer.File_Tree,
         Signal_Button_Press_Event,
         Gtkada.Handlers.Return_Callback.To_Marshaller
           (File_Button_Press'Access),
         Slot_Object => Explorer,
         After       => False);
      Gtkada.Handlers.Return_Callback.Object_Connect
        (Explorer.File_Tree,
         Signal_Button_Release_Event,
         Gtkada.Handlers.Return_Callback.To_Marshaller
           (File_Button_Press'Access),
         Slot_Object => Explorer,
         After       => False);

      Gtkada.Handlers.Return_Callback.Object_Connect
        (Explorer.File_Tree,
         Signal_Key_Press_Event,
         Gtkada.Handlers.Return_Callback.To_Marshaller (File_Key_Press'Access),
         Slot_Object => Explorer,
         After       => False);

      Widget_Callback.Object_Connect
        (Get_Selection (Explorer.File_Tree),
         Signal_Changed,
         File_Selection_Changed'Access,
         Slot_Object => Explorer,
         After       => True);

      Set_Column_Types (Explorer.File_Tree);

      Register_Contextual_Menu
        (Kernel          => Kernel,
         Event_On_Widget => Explorer.File_Tree,
         Object          => Explorer,
         ID              => Explorer_Files_Module_Id,
         Context_Func    => Explorer_Context_Factory'Access);

      Init_Graphics (Gtk_Widget (Explorer));

      Refresh (Explorer);

      Widget_Callback.Object_Connect
        (Explorer.File_Tree, Signal_Row_Expanded,
         File_Tree_Expand_Row_Cb'Access, Explorer, False);

      Widget_Callback.Object_Connect
        (Explorer.File_Tree, Signal_Row_Collapsed,
         File_Tree_Collapse_Row_Cb'Access, Explorer, False);

      Widget_Callback.Object_Connect
        (Explorer.File_Tree, Signal_Destroy,
         On_File_Destroy'Access, Explorer, False);

      Gtk.Dnd.Dest_Set
        (Explorer.File_Tree, Dest_Default_All, Target_Table_Url, Action_Any);
      Kernel_Callback.Connect
        (Explorer.File_Tree, Signal_Drag_Data_Received,
         Drag_Data_Received'Access, Kernel_Handle (Kernel));

      Deleted_Hook := new File_Deleted_Hook_Record;
      Deleted_Hook.View := Project_Explorer_Files (Explorer);
      Add_Hook (Kernel, GPS.Kernel.File_Deleted_Hook,
                Deleted_Hook,
                Name  => "project_explorers_files.file_deleted",
                Watch => GObject (Explorer));
      Saved_Hook := new File_Saved_Hook_Record;
      Saved_Hook.View := Project_Explorer_Files (Explorer);
      Add_Hook (Kernel, GPS.Kernel.File_Saved_Hook,
                Saved_Hook,
                Name  => "project_explorers_files.file_saved",
                Watch => GObject (Explorer));
      Renamed_Hook := new File_Renamed_Hook_Record;
      Renamed_Hook.View := Project_Explorer_Files (Explorer);
      Add_Hook (Kernel, GPS.Kernel.File_Renamed_Hook,
                Renamed_Hook,
                Name  => "project_explorers_files.file_renamed",
                Watch => GObject (Explorer));
   end Initialize;

   ------------------------------
   -- Explorer_Context_Factory --
   ------------------------------

   procedure Explorer_Context_Factory
     (Context      : in out Selection_Context;
      Kernel       : access Kernel_Handle_Record'Class;
      Event_Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      Object       : access Glib.Object.GObject_Record'Class;
      Event        : Gdk.Event.Gdk_Event;
      Menu         : Gtk_Menu)
   is
      pragma Unreferenced (Event_Widget);

      T         : constant Project_Explorer_Files :=
                    Project_Explorer_Files (Object);
      Iter      : constant Gtk_Tree_Iter :=
                    Find_Iter_For_Event (T.File_Tree, T.File_Model, Event);
      Path      : Gtk_Tree_Path;
      File      : Virtual_File;
      Node_Type : Node_Types;
      Check     : Gtk_Check_Menu_Item;
   begin
      if Iter /= Null_Iter then
         Path := Get_Path (T.File_Model, Iter);
         Set_Cursor (T.File_Tree, Path, null, False);
         Path_Free (Path);

         Node_Type := Node_Types'Val
           (Integer (Get_Int (T.File_Model, Iter, Node_Type_Column)));

         case Node_Type is
            when Directory_Node | File_Node =>
               File := Create
                 (Full_Filename =>
                    (Get_String (T.File_Model, Iter, Absolute_Name_Column)));
               Set_File_Information (Context, (1 => File));

            when Entity_Node =>
               --  ??? No entity information was set before, but isn't this
               --  strange ?
               null;

            when others =>
               null;

         end case;
      end if;

      if Menu /= null then
         Gtk_New (Check, Label => -"Show files from project only");
         Associate
           (Get_History (Kernel).all, File_View_Shows_Only_Project, Check);
         Append (Menu, Check);
         Widget_Callback.Object_Connect
           (Check, Signal_Toggled, Refresh'Access, T);
      end if;
   end Explorer_Context_Factory;

   ----------------------------
   -- File_Remove_Idle_Calls --
   ----------------------------

   procedure File_Remove_Idle_Calls
     (Explorer : access Project_Explorer_Files_Record'Class) is
   begin
      while not Timeout_Id_List.Is_Empty (Explorer.Fill_Timeout_Ids) loop
         Pop_State (Explorer.Kernel);
         Timeout_Remove (Timeout_Id_List.Head (Explorer.Fill_Timeout_Ids));
         Timeout_Id_List.Next (Explorer.Fill_Timeout_Ids);
      end loop;
   end File_Remove_Idle_Calls;

   ---------------------
   -- On_File_Destroy --
   ---------------------

   procedure On_File_Destroy
     (Explorer : access Gtk.Widget.Gtk_Widget_Record'Class;
      Params   : Glib.Values.GValues)
   is
      pragma Unreferenced (Params);
      E : constant Project_Explorer_Files :=
            Project_Explorer_Files (Explorer);
   begin
      File_Remove_Idle_Calls (E);
   end On_File_Destroy;

   -------------------------------
   -- File_Tree_Collapse_Row_Cb --
   -------------------------------

   procedure File_Tree_Collapse_Row_Cb
     (Explorer : access Gtk.Widget.Gtk_Widget_Record'Class;
      Values   : GValues)
   is
      T    : constant Project_Explorer_Files :=
               Project_Explorer_Files (Explorer);
      Path : constant Gtk_Tree_Path :=
               Gtk_Tree_Path (Get_Proxy (Nth (Values, 2)));
      Iter : Gtk_Tree_Iter;

   begin
      Iter := Get_Iter (T.File_Model, Path);

      if Iter /= Null_Iter then
         declare
            Iter_Name : constant String :=
              Get_String (T.File_Model, Iter, Absolute_Name_Column);

         begin
            if Is_Directory (Iter_Name) then
               Set (T.File_Model, Iter, Icon_Column,
                    C_Proxy (Close_Pixbufs (Directory_Node)));
            end if;
         end;
      end if;

   exception
      when E : others => Trace (Exception_Handle, E);
   end File_Tree_Collapse_Row_Cb;

   ---------------------
   -- Expose_Event_Cb --
   ---------------------

   function Expose_Event_Cb
     (Explorer : access Glib.Object.GObject_Record'Class;
      Values   : GValues) return Boolean
   is
      pragma Unreferenced (Values);
      T : constant Project_Explorer_Files := Project_Explorer_Files (Explorer);

   begin
      if T.Scroll_To_Directory then
         Scroll_To_Cell
           (T.File_Tree,
            T.Path, null, True,
            0.1, 0.1);
         Disconnect (T.File_Tree, T.Realize_Cb_Id);
         T.Scroll_To_Directory := False;
      end if;

      return True;
   exception
      when E : others =>
         Trace (Exception_Handle, E);
         return True;
   end Expose_Event_Cb;

   -----------------------------
   -- File_Tree_Expand_Row_Cb --
   -----------------------------

   procedure File_Tree_Expand_Row_Cb
     (Explorer : access Gtk.Widget.Gtk_Widget_Record'Class;
      Values   : GValues)
   is
      T       : constant Project_Explorer_Files :=
                  Project_Explorer_Files (Explorer);
      Path    : constant Gtk_Tree_Path :=
                  Gtk_Tree_Path (Get_Proxy (Nth (Values, 2)));
      Iter    : Gtk_Tree_Iter;
      Success : Boolean;
      pragma Unreferenced (Success);

   begin
      if T.Expanding then
         return;
      end if;

      Iter := Get_Iter (T.File_Model, Path);

      if Iter /= Null_Iter then
         T.Expanding := True;

         declare
            Iter_Name : constant String :=
                         Get_String (T.File_Model, Iter, Absolute_Name_Column);
            N_Type : constant Node_Types := Node_Types'Val
              (Integer (Get_Int (T.File_Model, Iter, Node_Type_Column)));

         begin
            case N_Type is
               when Directory_Node =>
                  Free_Children (T, Iter);
                  Set (T.File_Model, Iter, Icon_Column,
                       C_Proxy (Open_Pixbufs (Directory_Node)));
                  File_Append_Directory (T, Iter_Name, Iter, 1);

               when File_Node =>
                  Free_Children (T, Iter);
                  Append_File_Info
                    (T.Kernel, T.File_Model, Iter,
                     Create (Full_Filename => Iter_Name));

               when Project_Node | Extends_Project_Node =>
                  null;

               when Category_Node | Entity_Node =>
                  null;

               when Obj_Directory_Node | Exec_Directory_Node =>
                  null;

               when Modified_Project_Node =>
                  null;
            end case;
         end;

         Success := Expand_Row (T.File_Tree, Path, False);
         Scroll_To_Cell (T.File_Tree, Path, null, True, 0.1, 0.1);

         T.Expanding := False;
      end if;

   exception
      when E : others => Trace (Exception_Handle, E);
   end File_Tree_Expand_Row_Cb;

   ----------------------------
   -- File_Selection_Changed --
   ----------------------------

   procedure File_Selection_Changed
     (Explorer : access Gtk_Widget_Record'Class)
   is
      T : constant Project_Explorer_Files := Project_Explorer_Files (Explorer);
   begin
      Context_Changed (T.Kernel);
   exception
      when E : others => Trace (Exception_Handle, E);
   end File_Selection_Changed;

   -----------------------
   -- File_Button_Press --
   -----------------------

   function File_Button_Press
     (Explorer : access Gtk_Widget_Record'Class;
      Event    : Gdk_Event) return Boolean
   is
      T : constant Project_Explorer_Files := Project_Explorer_Files (Explorer);
   begin
      return On_Button_Press
        (T.Kernel,
         MDI_Explorer_Child (Find_MDI_Child (Get_MDI (T.Kernel), T)),
         T.File_Tree, T.File_Model, Event, True);

   exception
      when E : others =>
         Trace (Exception_Handle, E);
         return False;
   end File_Button_Press;

   --------------------
   -- File_Key_Press --
   --------------------

   function File_Key_Press
     (Explorer : access Gtk_Widget_Record'Class;
      Event    : Gdk_Event) return Boolean
   is
      T : constant Project_Explorer_Files := Project_Explorer_Files (Explorer);
   begin
      return On_Key_Press (T.Kernel, T.File_Tree, Event);

   exception
      when E : others =>
         Trace (Exception_Handle, E);
         return False;
   end File_Key_Press;

   ----------
   -- Free --
   ----------

   procedure Free (D : in out Gtk.Main.Timeout_Handler_Id) is
      pragma Unreferenced (D);
   begin
      null;
   end Free;

   -------------
   -- Refresh --
   -------------

   procedure Refresh (Files : access Gtk.Widget.Gtk_Widget_Record'Class) is
      Explorer     : constant Project_Explorer_Files :=
                       Project_Explorer_Files (Files);
      Buffer       : aliased String (1 .. 1024);
      Last, Len    : Integer;
      Cur_Dir      : constant String := Get_Current_Dir;
      Dir_Inserted : Boolean := False;

   begin
      Clear (Explorer.File_Model);
      File_Remove_Idle_Calls (Explorer);

      if Get_History
        (Get_History (Explorer.Kernel).all, File_View_Shows_Only_Project)
      then
         declare
            Inc : String_List_Utils.String_List.List;
            Obj : String_List_Utils.String_List.List;
         begin
            Inc := Parse_Path
              (Include_Path (Get_Project (Explorer.Kernel), True));
            Obj := Parse_Path
              (Object_Path (Get_Project (Explorer.Kernel), True));
            String_List_Utils.String_List.Concat (Inc, Obj);

            File_Append_Directory
              (Explorer,
               Greatest_Common_Path (Inc),
               Null_Iter, 1, Get_Current_Dir, True);
            String_List_Utils.String_List.Free (Inc);
         end;
      else
         Get_Local_Filesystem.Get_Logical_Drives (Buffer, Len);

         if Len = 0 then
            File_Append_Directory
              (Explorer, (1 => Directory_Separator),
               Null_Iter, 1, Cur_Dir, True);

         else
            Last := 1;

            for J in 1 .. Len loop
               if Buffer (J) = ASCII.NUL then
                  if File_Equal
                    (Buffer (Last .. J - 1),
                     Cur_Dir (Cur_Dir'First ..
                         Cur_Dir'First + J - Last - 1),
                     Build_Server)
                  then
                     File_Append_Directory
                       (Explorer, Buffer (Last .. J - 1),
                        Null_Iter, 1, Cur_Dir, True);
                     Dir_Inserted := True;

                  else
                     File_Append_Directory
                       (Explorer, Buffer (Last .. J - 1),
                        Null_Iter, 0, "", False, False);
                  end if;

                  Last := J + 1;
               end if;
            end loop;

            if not Dir_Inserted then
               declare
                  J : Natural := Cur_Dir'First;
               begin
                  while J < Cur_Dir'Last
                    and then not Is_Directory_Separator (Cur_Dir (J))
                  loop
                     J := J + 1;
                  end loop;

                  File_Append_Directory
                    (Explorer, Cur_Dir (Cur_Dir'First .. J),
                     Null_Iter, 1, Cur_Dir, True);
               end;
            end if;
         end if;
      end if;

   exception
      when E : others => Trace (Exception_Handle, E);
   end Refresh;

   ----------------
   -- Parse_Path --
   ----------------

   function Parse_Path
     (Path : String) return String_List_Utils.String_List.List
   is
      First : Integer;
      Index : Integer;

      use String_List_Utils.String_List;
      Result : String_List_Utils.String_List.List;

   begin
      First := Path'First;
      Index := First + 1;

      while Index <= Path'Last loop
         if Path (Index) = Path_Separator then
            Append (Result, Path (First .. Index - 1));
            Index := Index + 1;
            First := Index;
         end if;

         Index := Index + 1;
      end loop;

      if First /= Path'Last then
         Append (Result, Path (First .. Path'Last));
      end if;

      return Result;
   end Parse_Path;

   --------------------------
   -- Greatest_Common_Path --
   --------------------------

   function Greatest_Common_Path
     (L : String_List_Utils.String_List.List) return String
   is
      use String_List_Utils.String_List;

      N : List_Node;
   begin
      if Is_Empty (L) then
         return "";
      end if;

      N := First (L);

      declare
         Greatest_Prefix        : constant String  := Data (N);
         Greatest_Prefix_Length : Natural := Greatest_Prefix'Length;
      begin
         N := Next (N);

         while N /= Null_Node loop
            declare
               Challenger : constant String  := Data (N);
               First      : constant Natural := Challenger'First;
               Index      : Natural := 0;
               Length     : constant Natural := Challenger'Length;
            begin
               while Index < Greatest_Prefix_Length
                 and then Index < Length
                 and then
                   ((Is_Case_Sensitive (Build_Server)
                     and then Challenger (First + Index)
                       = Greatest_Prefix (Greatest_Prefix'First + Index))
                    or else
                      (not Is_Case_Sensitive (Build_Server)
                       and then To_Lower (Challenger (First + Index))
                         = To_Lower (Greatest_Prefix
                                       (Greatest_Prefix'First + Index))))
               loop
                  Index := Index + 1;
               end loop;

               Greatest_Prefix_Length := Index;
            end;

            if Greatest_Prefix_Length <= 1 then
               exit;
            end if;

            N := Next (N);
         end loop;

         if Greatest_Prefix_Length = 0 then
            return (1 => Directory_Separator);
         end if;

         return Greatest_Prefix
           (Greatest_Prefix'First
            .. Greatest_Prefix'First + Greatest_Prefix_Length - 1);
      end;
   end Greatest_Common_Path;

   -------------------
   -- Free_Children --
   -------------------

   procedure Free_Children
     (T    : Project_Explorer_Files;
      Iter : Gtk_Tree_Iter)
   is
      Current : Gtk_Tree_Iter := Children (T.File_Model, Iter);
   begin
      if Has_Child (T.File_Model, Iter) then
         while Current /= Null_Iter loop
            Remove (T.File_Model, Current);
            Current := Children (T.File_Model, Iter);
         end loop;
      end if;
   end Free_Children;

   -----------------
   -- Remove_File --
   -----------------

   procedure Remove_File
     (View : Project_Explorer_Files;
      File : GNATCOLL.VFS.Virtual_File)
   is
      Iter      : Gtk.Tree_Model.Gtk_Tree_Iter;
      Next_Iter : Gtk.Tree_Model.Gtk_Tree_Iter;
      Path      : Gtk_Tree_Path;
   begin
      Iter := Get_Iter_First (View.File_Model);

      while Iter /= Null_Iter loop
         if File_Equal
           (Get_String (View.File_Model, Iter, Absolute_Name_Column),
            File.Full_Name.all)
         then
            --  First select the parent and set the 'scroll to dir' state
            Path := Get_Path (View.File_Model,
                              Parent (View.File_Model, Iter));
            Set_Cursor (View.File_Tree, Path, null, False);
            View.Scroll_To_Directory := True;

            --  Now remove the node, this will invoke the expose event, that
            --  will scroll to the parent directory.
            Remove (View.File_Model, Iter);
            exit;
         end if;

         --  We look through the tree: first dir node, then children,
         --  then parent's next item.
         if Has_Child (View.File_Model, Iter) then
            Iter := Children (View.File_Model, Iter);
         else
            loop
               Next_Iter := Iter;
               Next (View.File_Model, Next_Iter);

               if Next_Iter = Null_Iter then
                  Iter := Parent (View.File_Model, Iter);
                  exit when Iter = Null_Iter;
               else
                  Iter := Next_Iter;
                  exit;
               end if;
            end loop;
         end if;
      end loop;
   end Remove_File;

   --------------
   -- Add_File --
   --------------

   procedure Add_File
     (View : Project_Explorer_Files;
      File : GNATCOLL.VFS.Virtual_File)
   is
      Iter      : Gtk.Tree_Model.Gtk_Tree_Iter;
      Next_Iter : Gtk.Tree_Model.Gtk_Tree_Iter;
      Iter2     : Gtk.Tree_Model.Gtk_Tree_Iter := Null_Iter;
      Dir       : GNATCOLL.VFS.Virtual_File := GNATCOLL.VFS.Dir (File);
      Path      : Gtk_Tree_Path;
      Dead      : Boolean;
      Done      : Boolean;
      pragma Unreferenced (Dead);

   begin
      Iter := Get_Iter_First (View.File_Model);

      if Is_Directory (File) then
         Dir := GNATCOLL.VFS.Get_Parent (File);
      end if;

      while Iter /= Null_Iter loop
         if File_Equal
           (Get_String (View.File_Model, Iter, Absolute_Name_Column),
            Dir.Full_Name.all)
         then
            --  We found the file's directory

            Path := Get_Path (View.File_Model, Iter);
            if not Row_Expanded (View.File_Tree, Path)
              and then Children (View.File_Model, Iter) /= Null_Iter then
               --  File's directory is not expanded. Return now

               --  Note that we need to test if dir node has children: in the
               --  normal case, a non expanded dir always has a dummy child.
               --  When we rename a directory, we might have deleted the only
               --  dir's child, then this dir won't have children at all. We
               --  don't want to fall back in this case here.
               return;
            end if;

            --  file's directory is expanded. Let's look at the children
            Next_Iter := Children (View.File_Model, Iter);

            while Next_Iter /= Null_Iter loop
               if File_Equal
                 (Get_String
                    (View.File_Model, Next_Iter, Absolute_Name_Column),
                  File.Full_Name.all)
               then
                  --  File already present. Do nothing
                  return;
               end if;

               Next (View.File_Model, Next_Iter);
            end loop;

            --  If we are here, then this means that the saved file is not
            --  present in the view. Let's insert it.

            if Is_Directory (File) then
               Next_Iter := Children (View.File_Model, Iter);
               Done := False;

               while Next_Iter /= Null_Iter loop

                  if Get_Node_Type (View.File_Model, Next_Iter) =
                    Directory_Node
                  then
                     declare
                        Name : constant String :=
                                 Get_Base_Name (View.File_Model, Next_Iter);
                     begin
                        if Name > File.Base_Dir_Name then
                           Insert_Before
                             (View.File_Model, Iter2, Iter, Next_Iter);
                           Done := True;

                           exit;
                        end if;
                     end;
                  elsif Get_Node_Type (View.File_Model, Next_Iter) =
                    File_Node
                  then
                     Insert_Before
                       (View.File_Model, Iter2, Iter, Next_Iter);
                     Done := True;

                     exit;
                  end if;

                  Next (View.File_Model, Next_Iter);
               end loop;

               if not Done then
                  Append (View.File_Model, Iter2, Iter);
               end if;

               Set (View.File_Model, Iter2, Absolute_Name_Column,
                    File.Full_Name.all);
               Set (View.File_Model, Iter2, Base_Name_Column,
                    File.Base_Dir_Name);
               Set_Node_Type (View.File_Model, Iter2, Directory_Node, False);
               File_Append_Directory (View, File.Full_Name.all, Iter2);
            else
               Append_File
                 (View.Kernel,
                  View.File_Model,
                  Iter,
                  File,
                  Sorted => True);
            end if;

            Dead := Expand_Row (View.File_Tree, Path, False);

            return;
         end if;

         --  We look through the tree: first dir node, then children,
         --  then parent's next item.
         if Has_Child (View.File_Model, Iter) then
            Iter := Children (View.File_Model, Iter);
         else
            loop
               Next_Iter := Iter;
               Next (View.File_Model, Next_Iter);

               if Next_Iter = Null_Iter then
                  Iter := Parent (View.File_Model, Iter);
                  exit when Iter = Null_Iter;
               else
                  Iter := Next_Iter;
                  exit;
               end if;
            end loop;
         end if;
      end loop;
   end Add_File;

   -------------
   -- Execute --
   -------------

   overriding procedure Execute
     (Hook   : File_Deleted_Hook_Record;
      Kernel : access Kernel_Handle_Record'Class;
      Data   : access Hooks_Data'Class)
   is
      pragma Unreferenced (Kernel);
   begin
      Remove_File (Hook.View, File_Hooks_Args (Data.all).File);
   end Execute;

   -------------
   -- Execute --
   -------------

   overriding procedure Execute
     (Hook   : File_Saved_Hook_Record;
      Kernel : access Kernel_Handle_Record'Class;
      Data   : access Hooks_Data'Class)
   is
      pragma Unreferenced (Kernel);
   begin
      Add_File (Hook.View, File_Hooks_Args (Data.all).File);
   end Execute;

   -------------
   -- Execute --
   -------------

   overriding procedure Execute
     (Hook   : File_Renamed_Hook_Record;
      Kernel : access Kernel_Handle_Record'Class;
      Data   : access Hooks_Data'Class)
   is
      pragma Unreferenced (Kernel);
   begin
      Remove_File (Hook.View, Files_2_Hooks_Args (Data.all).File);
      Add_File (Hook.View, Files_2_Hooks_Args (Data.all).Renamed);
   end Execute;

   ----------------------
   -- On_Open_Explorer --
   ----------------------

   procedure On_Open_Explorer
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);
      Files        : Project_Explorer_Files;
      Child        : MDI_Child;
      C2           : MDI_Explorer_Child;
   begin
      --  Start with the files view, so that if both are needed, the project
      --  view ends up on top of the files view
      Child := Find_MDI_Child_By_Tag
        (Get_MDI (Kernel), Project_Explorer_Files_Record'Tag);

      if Child = null then
         Gtk_New (Files, Kernel);
         C2 := new MDI_Explorer_Child_Record;
         Initialize (C2, Files,
                     Default_Width  => 215,
                     Default_Height => 600,
                     Group          => Group_View,
                     Module         => Explorer_Files_Module_Id);
         Set_Title (C2, -"File View",  -"File View");
         Put (Get_MDI (Kernel), C2, Initial_Position => Position_Left);
         Child := MDI_Child (C2);
      end if;

      Raise_Child (Child);
      Set_Focus_Child (Get_MDI (Kernel), Child);

   exception
      when E : others => Trace (Exception_Handle, E);
   end On_Open_Explorer;

   ------------------
   -- Load_Desktop --
   ------------------

   function Load_Desktop
     (MDI  : MDI_Window;
      Node : Node_Ptr;
      User : Kernel_Handle) return MDI_Child is
   begin
      if Node.Tag.all = "Project_Explorer_Files" then
         On_Open_Explorer (MDI, User);
         return Find_MDI_Child_By_Tag
           (Get_MDI (User), Project_Explorer_Files_Record'Tag);
      end if;

      return null;
   end Load_Desktop;

   ------------------
   -- Save_Desktop --
   ------------------

   function Save_Desktop
     (Widget : access Gtk.Widget.Gtk_Widget_Record'Class;
      User   : Kernel_Handle)
     return Node_Ptr
   is
      pragma Unreferenced (User);
      N : Node_Ptr;
   begin
      if Widget.all in Project_Explorer_Files_Record'Class then
         N := new Node;
         N.Tag := new String'("Project_Explorer_Files");
         return N;
      end if;

      return null;
   end Save_Desktop;

   ---------------------
   -- Register_Module --
   ---------------------

   procedure Register_Module
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class)
   is
      Tools : constant String := '/' & (-"Tools") & '/' & (-"Views");
      File_View_Filter : constant Action_Filter :=
                           new File_View_Filter_Record;
   begin
      Explorer_Files_Module_Id := new Explorer_Module_Record;
      Register_Module
        (Module      => Explorer_Files_Module_Id,
         Kernel      => Kernel,
         Module_Name => "Files_View",
         Priority    => GPS.Kernel.Modules.Default_Priority);
      GPS.Kernel.Kernel_Desktop.Register_Desktop_Functions
        (Save_Desktop'Access, Load_Desktop'Access);
      Register_Menu
        (Kernel, Tools, -"_Files", "", On_Open_Explorer'Access,
         Ref_Item => -"Remote");
      Register_Filter
        (Kernel,
         Filter => File_View_Filter,
         Name   => "File_View");
   end Register_Module;

end Project_Explorers_Files;
