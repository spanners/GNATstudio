-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                     Copyright (C) 2001-2003                       --
--                            ACT-Europe                             --
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

with Ada.Exceptions;            use Ada.Exceptions;
with GNAT.Directory_Operations; use GNAT.Directory_Operations;
with GNAT.OS_Lib;               use GNAT.OS_Lib;
with GNAT.Case_Util;            use GNAT.Case_Util;
with Glib.Xml_Int;              use Glib.Xml_Int;
with Gdk;                       use Gdk;
with Gdk.Color;                 use Gdk.Color;
with Gdk.Event;                 use Gdk.Event;
with Gdk.GC;                    use Gdk.GC;
with Gdk.Types;                 use Gdk.Types;
with Gdk.Types.Keysyms;         use Gdk.Types.Keysyms;
with Glib;                      use Glib;
with Glib.Object;               use Glib.Object;
with Glib.Values;               use Glib.Values;
with Glide_Intl;                use Glide_Intl;
with Glide_Kernel;              use Glide_Kernel;
with Glide_Kernel.Console;      use Glide_Kernel.Console;
with Glide_Kernel.Modules;      use Glide_Kernel.Modules;
with Glide_Kernel.Preferences;  use Glide_Kernel.Preferences;
with Glide_Kernel.Project;      use Glide_Kernel.Project;
with Glide_Kernel.Scripts;      use Glide_Kernel.Scripts;
with Glide_Kernel.Timeout;      use Glide_Kernel.Timeout;
with Language;                  use Language;
with Language_Handlers;         use Language_Handlers;
with Glide_Main_Window;         use Glide_Main_Window;
with Basic_Types;               use Basic_Types;
with GVD.Status_Bar;            use GVD.Status_Bar;
with Gtk.Box;                   use Gtk.Box;
with Gtk.Button;                use Gtk.Button;
with Gtk.Dialog;                use Gtk.Dialog;
with Gtk.Enums;                 use Gtk.Enums;
with Gtk.GEntry;                use Gtk.GEntry;
with Gtk.Handlers;              use Gtk.Handlers;
with Gtk.Label;                 use Gtk.Label;
with Gtk.Menu;                  use Gtk.Menu;
with Gtk.Menu_Item;             use Gtk.Menu_Item;
with Gtk.Main;                  use Gtk.Main;
with Gtk.Stock;                 use Gtk.Stock;
with Gtk.Toolbar;               use Gtk.Toolbar;
with Gtk.Widget;                use Gtk.Widget;
with Gtk.Text_Mark;             use Gtk.Text_Mark;
with Gtkada.Entry_Completion;   use Gtkada.Entry_Completion;
with Gtkada.Handlers;           use Gtkada.Handlers;
with Gtkada.MDI;                use Gtkada.MDI;
with Gtkada.File_Selector;      use Gtkada.File_Selector;
with Src_Editor_Box;            use Src_Editor_Box;
with Src_Editor_Buffer;         use Src_Editor_Buffer;
with Src_Editor_View;           use Src_Editor_View;
with Src_Editor_View.Commands;  use Src_Editor_View.Commands;
with String_List_Utils;         use String_List_Utils;
with String_Utils;              use String_Utils;
with Traces;                    use Traces;
with Projects.Registry;         use Projects, Projects.Registry;
with Src_Contexts;              use Src_Contexts;
with Find_Utils;                use Find_Utils;
with Histories;                 use Histories;
with Aliases_Module;            use Aliases_Module;
with Commands.Interactive;      use Commands, Commands.Interactive;
with VFS;                       use VFS;

with Gtkada.Types;              use Gtkada.Types;
with Gdk.Pixbuf;                use Gdk.Pixbuf;

with Generic_List;
with GVD.Preferences; use GVD.Preferences;

with Src_Editor_Module.Line_Highlighting;
with Src_Editor_Buffer.Buffer_Commands; use Src_Editor_Buffer.Buffer_Commands;
with Src_Editor_Buffer.Line_Information;

with Src_Editor_Buffer.Text_Handling;   use Src_Editor_Buffer.Text_Handling;

with Src_Printing;
with Pango.Font;
with Pango.Enums;

package body Src_Editor_Module is

   Me : constant Debug_Handle := Create ("Src_Editor_Module");

   Hist_Key : constant History_Key := "reopen_files";
   --  Key to use in the kernel histories to store the most recently opened
   --  files.

   Open_From_Path_History : constant History_Key := "open-from-project";
   --  Key used to store the most recently open files in the Open From Project
   --  dialog.

   editor_xpm : aliased Chars_Ptr_Array (0 .. 0);
   pragma Import (C, editor_xpm, "mini_page_xpm");
   fold_block_xpm : aliased Chars_Ptr_Array (0 .. 0);
   pragma Import (C, fold_block_xpm, "fold_block_xpm");
   unfold_block_xpm  : aliased Chars_Ptr_Array (0 .. 0);
   pragma Import (C, unfold_block_xpm, "unfold_block_xpm");
   close_block_xpm  : aliased Chars_Ptr_Array (0 .. 0);
   pragma Import (C, close_block_xpm, "close_block_xpm");

   Filename_Cst  : aliased constant String := "filename";
   Line_Cst      : aliased constant String := "line";
   Col_Cst       : aliased constant String := "column";
   Length_Cst    : aliased constant String := "length";
   Pattern_Cst   : aliased constant String := "pattern";
   Case_Cst      : aliased constant String := "case_sensitive";
   Regexp_Cst    : aliased constant String := "regexp";
   Recursive_Cst : aliased constant String := "recursive";
   Scope_Cst     : aliased constant String := "scope";

   Edit_Cmd_Parameters : constant Cst_Argument_List :=
     (1 => Filename_Cst'Access,
      2 => Line_Cst'Access,
      3 => Col_Cst'Access,
      4 => Length_Cst'Access);
   File_Search_Parameters : constant Cst_Argument_List :=
     (1 => Pattern_Cst'Access,
      2 => Case_Cst'Access,
      3 => Regexp_Cst'Access,
      4 => Scope_Cst'Access);
   Project_Search_Parameters : constant Cst_Argument_List :=
     File_Search_Parameters & (5 => Recursive_Cst'Access);

   type Editor_Child_Record is new GPS_MDI_Child_Record
      with null record;

   function Dnd_Data
     (Child : access Editor_Child_Record; Copy : Boolean) return MDI_Child;
   --  See inherited documentation

   type Clipboard_Kind is (Cut, Copy, Paste);
   type Clipboard_Command is new Interactive_Command with record
      Kernel : Kernel_Handle;
      Kind   : Clipboard_Kind;
   end record;
   function Execute
     (Command : access Clipboard_Command; Event : Gdk_Event)
      return Command_Return_Type;
   --  Perform the various actions associated with the clipboard

   procedure Generate_Body_Cb (Data : Process_Data; Status : Integer);
   --  Callback called when gnatstub has completed.

   procedure Pretty_Print_Cb (Data : Process_Data; Status : Integer);
   --  Callback called when gnatpp has completed.

   procedure Gtk_New
     (Box : out Source_Box; Editor : Source_Editor_Box);
   --  Create a new source box.

   procedure Initialize
     (Box : access Source_Box_Record'Class; Editor : Source_Editor_Box);
   --  Internal initialization function.

   function Mime_Action
     (Kernel    : access Kernel_Handle_Record'Class;
      Mime_Type : String;
      Data      : GValue_Array;
      Mode      : Mime_Mode := Read_Write) return Boolean;
   --  Process, if possible, the data sent by the kernel

   procedure Save_To_File
     (Kernel  : access Glide_Kernel.Kernel_Handle_Record'Class;
      Name    : VFS.Virtual_File := VFS.No_File;
      Success : out Boolean);
   --  Save the current editor to Name, or its associated filename if Name is
   --  null.

   function Open_File
     (Kernel     : access Kernel_Handle_Record'Class;
      File       : VFS.Virtual_File := VFS.No_File;
      Create_New : Boolean := True;
      Focus      : Boolean := True) return Source_Box;
   --  Open a file and return the handle associated with it.
   --  If Add_To_MDI is set to True, the box will be added to the MDI window.
   --  If Focus is True, the box will be raised if it is in the MDI.
   --  See Create_File_Exitor.

   function Create_File_Editor
     (Kernel     : access Kernel_Handle_Record'Class;
      File       : VFS.Virtual_File;
      Create_New : Boolean := True) return Source_Editor_Box;
   --  Create a new text editor that edits File.
   --  If File is the empty string, or the file doesn't exist and Create_New is
   --  True, then an empty editor is created.
   --  No check is done to make sure that File is not already edited
   --  elsewhere. The resulting editor is not put in the MDI window.

   function Save_Function
     (Kernel : access Kernel_Handle_Record'Class;
      Child  : Gtk.Widget.Gtk_Widget;
      Mode   : Save_Function_Mode) return Boolean;
   --  Save the text editor.
   --  If Force is False, then offer a choice to the user before doing so.

   type Location_Idle_Data is record
      Edit  : Source_Editor_Box;
      Line, Column, Column_End : Natural;
      Kernel : Kernel_Handle;
   end record;

   function Location_Callback (D : Location_Idle_Data) return Boolean;
   --  Idle callback used to scroll the source editors.

   function File_Edit_Callback (D : Location_Idle_Data) return Boolean;
   --  Emit the File_Edited signal.

   function Load_Desktop
     (MDI  : MDI_Window;
      Node : Node_Ptr;
      User : Kernel_Handle) return MDI_Child;
   function Save_Desktop
     (Widget : access Gtk.Widget.Gtk_Widget_Record'Class)
      return Node_Ptr;
   --  Support functions for the MDI

   procedure On_Open_File
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  File->Open menu

   procedure On_Open_From_Path
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  File->Open From Path menu

   procedure On_New_View
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  File->New View menu

   procedure On_New_File
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  File->New menu

   procedure On_Save
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  File->Save menu

   procedure On_Save_As
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  File->Save As... menu

   procedure On_Save_All
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  File->Save All menu

   procedure On_Print
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  File->Print menu

   procedure On_Select_All
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  Edit->Select All menu

   procedure On_Goto_Line_Current_Editor
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  Navigate->Goto Line... menu

   procedure On_Goto_Declaration
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  Navigate->Goto Declaration menu
   --  Goto the declaration of the entity under the cursor in the current
   --  editor.

   procedure On_Goto_Body
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  Navigate->Goto Body menu
   --  Goto the next body of the entity under the cursor in the current
   --  editor.

   procedure On_Generate_Body
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  Edit->Generate Body menu

   procedure On_Pretty_Print
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  Edit->Pretty Print menu

   procedure On_Comment_Lines
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  Edit->Comment Lines menu

   procedure On_Uncomment_Lines
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  Edit->Uncomment Lines menu

   procedure On_Fold_Blocks
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  Edit->Fold all blocks menu

   procedure On_Unfold_Blocks
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  Edit->Unfold all blocks menu

   procedure Comment_Uncomment
     (Kernel : Kernel_Handle; Comment : Boolean);
   --  Comment or uncomment the current selection, if any.
   --  Auxiliary procedure for On_Comment_Lines and On_Uncomment_Lines.

   procedure On_Edit_File
     (Widget : access GObject_Record'Class;
      Context : Selection_Context_Access);
   --  Edit a file (from a contextual menu)

   procedure On_Lines_Revealed
     (Widget  : access Glib.Object.GObject_Record'Class;
      Args    : GValues;
      Kernel  : Kernel_Handle);
   --  Display the line numbers.

   procedure Source_Editor_Contextual
     (Object  : access GObject_Record'Class;
      Context : access Selection_Context'Class;
      Menu    : access Gtk.Menu.Gtk_Menu_Record'Class);
   --  Generate the contextual menu entries for contextual menus in other
   --  modules than the source editor.

   function Default_Factory
     (Kernel : access Kernel_Handle_Record'Class;
      Child  : Gtk.Widget.Gtk_Widget) return Selection_Context_Access;
   --  Create the current context for Glide_Kernel.Get_Current_Context

   function Default_Factory
     (Kernel : access Kernel_Handle_Record'Class;
      Editor : access Source_Editor_Box_Record'Class)
      return Selection_Context_Access;
   --  Same as above.

   function New_View
     (Kernel  : access Kernel_Handle_Record'Class;
      Current : Source_Editor_Box) return Source_Box;
   --  Create a new view for Current and add it in the MDI.
   --  The current editor is the focus child in the MDI.
   --  If Add is True, the Box is added to the MDI.

   procedure New_View
     (Kernel : access Glide_Kernel.Kernel_Handle_Record'Class);
   --  Create a new view for the current editor and add it in the MDI.
   --  The current editor is the focus child in the MDI. If the focus child
   --  is not an editor, nothing happens.

   function Delete_Callback
     (Widget : access Gtk_Widget_Record'Class;
      Params : Glib.Values.GValues) return Boolean;
   --  Callback for the "delete_event" signal.

   procedure File_Edited_Cb
     (Widget  : access Glib.Object.GObject_Record'Class;
      Args    : GValues;
      Kernel  : Kernel_Handle);
   --  Callback for the "file_edited" signal.

   procedure File_Closed_Cb
     (Widget  : access Glib.Object.GObject_Record'Class;
      Args    : GValues;
      Kernel  : Kernel_Handle);
   --  Callback for the "file_closed" signal.

   procedure File_Changed_On_Disk_Cb
     (Widget  : access Glib.Object.GObject_Record'Class;
      Args    : GValues;
      Kernel  : Kernel_Handle);
   --  Callback for the "file_changed_on_disk" signal.

   procedure File_Saved_Cb
     (Widget  : access Glib.Object.GObject_Record'Class;
      Args    : GValues;
      Kernel  : Kernel_Handle);
   --  Callback for the "file_saved" signal.

   procedure Preferences_Changed
     (K : access GObject_Record'Class; Kernel : Kernel_Handle);
   --  Called when the preferences have changed.

   procedure Edit_Command_Handler
     (Data    : in out Callback_Data'Class; Command : String);
   --  Interactive command handler for the source editor module.

   procedure File_Search_Command_Handler
     (Data    : in out Callback_Data'Class; Command : String);
   procedure Project_Search_Command_Handler
     (Data    : in out Callback_Data'Class; Command : String);
   procedure Common_Search_Command_Handler
     (Data    : in out Callback_Data'Class;
      Files   : VFS.File_Array_Access);
   --  Interactive command handler for the source editor module (Search part)

   procedure Add_To_Recent_Menu
     (Kernel : access Kernel_Handle_Record'Class; File : String);
   --  Add an entry for File to the Recent menu, if needed.

   function Find_Mark (Identifier : String) return Mark_Identifier_Record;
   --  Find the mark corresponding to Identifier, or return an empty
   --  record.

   procedure Fill_Marks (Kernel : Kernel_Handle; File : VFS.Virtual_File);
   --  Create the marks on the buffer corresponding to File, if File has just
   --  been open.

   function Get_Filename (Child : MDI_Child) return VFS.Virtual_File;
   --  If Child is a file editor, return the corresponding filename,
   --  otherwise return an empty string.

   function Expand_Aliases_Entities
     (Kernel    : access Kernel_Handle_Record'Class;
      Expansion : String;
      Special   : Character) return String;
   --  Does the expansion of special entities in the aliases.

   type On_Recent is new Menu_Callback_Record with record
      Kernel : Kernel_Handle;
   end record;
   procedure Activate (Callback : access On_Recent; Item : String);

   procedure Map_Cb (Widget : access Gtk_Widget_Record'Class);
   --  Create the module-wide GCs.

   --------------
   -- Dnd_Data --
   --------------

   function Dnd_Data
     (Child : access Editor_Child_Record; Copy : Boolean) return MDI_Child
   is
      Editor : Source_Editor_Box;
      Kernel : Kernel_Handle;
   begin
      if Copy then
         Editor := Get_Source_Box_From_MDI (MDI_Child (Child));
         Kernel := Get_Kernel (Editor);
         return Find_MDI_Child
           (Get_MDI (Kernel), New_View (Kernel, Editor));
      else
         return MDI_Child (Child);
      end if;
   end Dnd_Data;

   ------------
   -- Map_Cb --
   ------------

   procedure Map_Cb (Widget : access Gtk_Widget_Record'Class) is
      Color   : Gdk_Color;
      Success : Boolean;
      Id      : constant Source_Editor_Module :=
        Source_Editor_Module (Src_Editor_Module_Id);
   begin
      Gdk_New (Id.Blank_Lines_GC, Get_Window (Widget));
      Gdk_New (Id.Post_It_Note_GC, Get_Window (Widget));

      --  ??? Should this be a preference ?
      Color := Parse ("#AAAAAA");
      Alloc_Color (Get_Default_Colormap, Color, False, True, Success);

      if Success then
         Set_Foreground
           (Id.Blank_Lines_GC, Color);
      else
         Set_Foreground
           (Id.Blank_Lines_GC,
            Black (Get_Default_Colormap));
      end if;

      --  ??? This should be a preference !
      Color := Parse ("#FFFF88");
      Alloc_Color (Get_Default_Colormap, Color, False, True, Success);

      if Success then
         Set_Foreground
           (Id.Post_It_Note_GC, Color);
      else
         Set_Foreground
           (Id.Post_It_Note_GC,
            Black (Get_Default_Colormap));
      end if;
   end Map_Cb;

   ------------------
   -- Get_Filename --
   ------------------

   function Get_Filename (Child : MDI_Child) return VFS.Virtual_File is
   begin
      if Child /= null
        and then Get_Widget (Child).all in Source_Box_Record'Class
      then
         return Get_Filename (Source_Box (Get_Widget (Child)).Editor);
      else
         return VFS.No_File;
      end if;
   end Get_Filename;

   ----------
   -- Free --
   ----------

   procedure Free (X : in out Mark_Identifier_Record) is
      pragma Unreferenced (X);
   begin
      null;
   end Free;

   ---------------
   -- Find_Mark --
   ---------------

   function Find_Mark (Identifier : String) return Mark_Identifier_Record is
      use type Mark_Identifier_List.List_Node;

      Id          : constant Source_Editor_Module :=
        Source_Editor_Module (Src_Editor_Module_Id);
      Mark_Node   : Mark_Identifier_List.List_Node;
      Mark_Record : Mark_Identifier_Record;
   begin
      Mark_Node := Mark_Identifier_List.First (Id.Stored_Marks);

      while Mark_Node /= Mark_Identifier_List.Null_Node loop
         Mark_Record := Mark_Identifier_List.Data (Mark_Node);

         if Image (Mark_Record.Id) = Identifier then
            return Mark_Record;
         end if;

         Mark_Node := Mark_Identifier_List.Next (Mark_Node);
      end loop;

      return Mark_Identifier_Record'
        (Id     => 0,
         Child  => null,
         File   => VFS.No_File,
         Mark   => null,
         Line   => 0,
         Column => 0,
         Length => 0);
   end Find_Mark;

   -----------------------------------
   -- Common_Search_Command_Handler --
   -----------------------------------

   procedure Common_Search_Command_Handler
     (Data    : in out Callback_Data'Class;
      Files   : File_Array_Access)
   is
      Kernel    : constant Kernel_Handle := Get_Kernel (Data);
      Context   : Files_Project_Context_Access;
      Pattern   : constant String  := Nth_Arg (Data, 2);
      Casing    : constant Boolean := Nth_Arg (Data, 3, False);
      Regexp    : constant Boolean := Nth_Arg (Data, 4, False);
      Scope     : constant String  := Nth_Arg (Data, 5, "whole");
      S         : Search_Scope;

      function Callback (Match : Match_Result) return Boolean;
      --  Store the result of the match in Data

      function Callback (Match : Match_Result) return Boolean is
      begin
         Set_Return_Value
           (Data,
            Create_File_Location
              (Get_Script (Data),
               Create_File (Get_Script (Data), Current_File (Context)),
               Match.Line,
               Match.Column));
         return True;
      end Callback;

   begin
      if Scope = "whole" then
         S := Whole;
      elsif Scope = "comments" then
         S := Comments_Only;
      elsif Scope = "strings" then
         S := Strings_Only;
      elsif Scope = "code" then
         S := All_But_Comments;
      else
         S := Whole;
      end if;

      Context := Files_From_Project_Factory
        (Scope           => S,
         All_Occurrences => True);
      Set_File_List (Context, Files);
      Set_Context
        (Context,
         Look_For => Pattern,
         Options => (Case_Sensitive => Casing,
                     Whole_Word     => False,
                     Regexp         => Regexp));

      Set_Return_Value_As_List (Data);

      while Search
        (Context  => Context,
         Handler  => Get_Language_Handler (Kernel),
         Kernel   => Kernel,
         Callback => Callback'Unrestricted_Access)
      loop
         --  No need to delay, since the search is done in same process.
         null;
      end loop;
   end Common_Search_Command_Handler;

   ---------------------------------
   -- File_Search_Command_Handler --
   ---------------------------------

   procedure File_Search_Command_Handler
     (Data    : in out Callback_Data'Class; Command : String)
   is
      pragma Unreferenced (Command);
      Kernel : constant Kernel_Handle := Get_Kernel (Data);
      Inst   : constant Class_Instance :=
        Nth_Arg (Data, 1, Get_File_Class (Kernel));
      Info   : constant File_Info := Get_Data (Inst);
   begin
      Name_Parameters (Data, File_Search_Parameters);
      Common_Search_Command_Handler
        (Data, new File_Array'(1 => Get_File (Info)));
   end File_Search_Command_Handler;

   ------------------------------------
   -- Project_Search_Command_Handler --
   ------------------------------------

   procedure Project_Search_Command_Handler
     (Data    : in out Callback_Data'Class; Command : String)
   is
      pragma Unreferenced (Command);
      Kernel    : constant Kernel_Handle := Get_Kernel (Data);
      Inst      : constant Class_Instance :=
        Nth_Arg (Data, 1, Get_Project_Class (Kernel));
      Project   : constant Project_Type := Get_Data (Inst);
      Recursive : Boolean;
   begin
      Name_Parameters (Data, File_Search_Parameters);
      Recursive := Nth_Arg (Data, 5, True);
      Common_Search_Command_Handler
        (Data, Get_Source_Files (Project, Recursive));
   end Project_Search_Command_Handler;

   --------------------------
   -- Edit_Command_Handler --
   --------------------------

   procedure Edit_Command_Handler
     (Data    : in out Callback_Data'Class; Command : String)
   is
      Kernel   : constant Kernel_Handle := Get_Kernel (Data);
      Id       : constant Source_Editor_Module :=
        Source_Editor_Module (Src_Editor_Module_Id);
      Length   : Natural := 0;
      Line     : Natural := 1;
      Column   : Natural := 1;

   begin
      if Command = "edit" or else Command = "create_mark" then
         Name_Parameters (Data, Edit_Cmd_Parameters);
         declare
            File : constant Virtual_File :=
              Create (Nth_Arg (Data, 1), Kernel, Use_Source_Path => True);
         begin
            Line   := Nth_Arg (Data, 2, Default => 1);
            Column := Nth_Arg (Data, 3, Default => 1);
            Length := Nth_Arg (Data, 4, Default => 0);

            if File /= VFS.No_File then
               if Command = "edit" then
                  if Length = 0 then
                     Open_File_Editor
                       (Kernel,
                        File,
                        Line,
                        Column,
                        Enable_Navigation => False);
                  else
                     Open_File_Editor
                       (Kernel,
                        File,
                        Line,
                        Column,
                        Column + Length,
                        Enable_Navigation => False);
                  end if;

               elsif Command = "create_mark" then
                  declare
                     Box         : Source_Box;
                     Child       : MDI_Child;
                     Mark_Record : Mark_Identifier_Record;
                  begin
                     Child := Find_Editor (Kernel, File);

                     --  Create a new mark record and insert it in the list.

                     Mark_Record.File := File;
                     Mark_Record.Id   := Id.Next_Mark_Id;
                     Mark_Record.Line := Line;
                     Id.Next_Mark_Id := Id.Next_Mark_Id + 1;

                     Mark_Record.Length := Length;

                     if Child /= null then
                        Mark_Record.Child := Child;
                        Box := Source_Box (Get_Widget (Child));
                        Mark_Record.Mark :=
                          Create_Mark
                            (Box.Editor,
                             Editable_Line_Type (Line),
                             Column);
                     else
                        Mark_Record.Line := Line;
                        Mark_Record.Column := Column;
                        Add_Unique_Sorted
                          (Id.Unopened_Files, Full_Name (File).all);
                     end if;

                     Mark_Identifier_List.Append
                       (Id.Stored_Marks, Mark_Record);

                     Set_Return_Value (Data, Image (Mark_Record.Id));
                  end;
               end if;
            end if;
         end;

      elsif Command = "close"
        or else Command = "undo"
        or else Command = "redo"
      then
         declare
            Filename : constant Virtual_File :=
              Create (Full_Filename => Nth_Arg (Data, 1));
         begin
            if Command = "close" then
               Close_File_Editors (Kernel, Filename);
            else
               declare
                  Child : MDI_Child;
                  Box   : Source_Box;
               begin
                  Child := Find_Editor (Kernel, Filename);

                  if Child = null then
                     Set_Error_Msg (Data, -"file not open");
                  else
                     Box := Source_Box (Get_Widget (Child));

                     if Command = "redo" then
                        Redo (Box.Editor);
                     elsif Command = "undo" then
                        Undo (Box.Editor);
                     end if;
                  end if;
               end;
            end if;
         end;

      elsif Command = "goto_mark" then
         declare
            Identifier  : constant String := Nth_Arg (Data, 1);
            Mark_Record : constant Mark_Identifier_Record :=
              Find_Mark (Identifier);
         begin
            if Mark_Record.Child /= null then
               Raise_Child (Mark_Record.Child);
               Set_Focus_Child (Mark_Record.Child);
               Grab_Focus (Source_Box (Get_Widget (Mark_Record.Child)).Editor);

               --  If the Length is null, we set the length to 1, otherwise
               --  the cursor is not visible.

               Scroll_To_Mark
                 (Source_Box (Get_Widget (Mark_Record.Child)).Editor,
                  Mark_Record.Mark,
                  Mark_Record.Length);

            else
               if Mark_Record.File /= VFS.No_File
                 and then Is_In_List
                 (Id.Unopened_Files, Full_Name (Mark_Record.File).all)
               then
                  Open_File_Editor (Kernel,
                                    Mark_Record.File,
                                    Mark_Record.Line,
                                    Mark_Record.Column,
                                    Mark_Record.Column + Mark_Record.Length);

                  --  At this point, Open_File_Editor should have caused the
                  --  propagation of the File_Edited signal, which provokes a
                  --  call to Fill_Marks in File_Edited_Cb.
                  --  Therefore the Mark_Record might not be valid beyond this
                  --  point.
               end if;
            end if;
         end;

      elsif Command = "delete_mark" then
         declare
            Identifier  : constant String := Nth_Arg (Data, 1);
            Mark_Record : constant Mark_Identifier_Record :=
              Find_Mark (Identifier);
            Node        : Mark_Identifier_List.List_Node;
            Prev        : Mark_Identifier_List.List_Node;

            use Mark_Identifier_List;
         begin
            if Mark_Record.Child /= null then
               Delete_Mark
                 (Get_Buffer
                    (Source_Box (Get_Widget (Mark_Record.Child)).Editor),
                  Mark_Record.Mark);

               Node := First (Id.Stored_Marks);

               if Mark_Identifier_List.Data (Node).Id = Mark_Record.Id then
                  Next (Id.Stored_Marks);
               else
                  Prev := Node;
                  Node := Next (Node);

                  while Node /= Null_Node loop
                     if Mark_Identifier_List.Data (Node).Id
                       = Mark_Record.Id
                     then
                        Remove_Nodes (Id.Stored_Marks, Prev, Node);
                        exit;
                     end if;

                     Node := Next (Node);
                  end loop;
               end if;
            end if;
         end;

      elsif Command = "get_chars" then
         declare
            File   : constant String  := Nth_Arg (Data, 1);
            Line   : constant Integer := Nth_Arg (Data, 2);
            Column : constant Integer := Nth_Arg (Data, 3);
            Before : constant Integer := Nth_Arg (Data, 4, Default => -1);
            After  : constant Integer := Nth_Arg (Data, 5, Default => -1);
            Child  : constant MDI_Child :=
              Find_Editor (Kernel, Create (File, Kernel));
         begin
            Set_Return_Value
              (Data,
               Get_Chars
                 (Get_Buffer (Source_Box (Get_Widget (Child)).Editor),
                  Editable_Line_Type (Line),
                  Natural (Column),
                  Before, After));
         end;

      elsif Command = "replace_text" then
         declare
            File   : constant String  := Nth_Arg (Data, 1);
            Line   : constant Integer := Nth_Arg (Data, 2);
            Column : constant Integer := Nth_Arg (Data, 3);
            Text   : constant String  := Nth_Arg (Data, 4);
            Before : constant Integer := Nth_Arg (Data, 5, Default => -1);
            After  : constant Integer := Nth_Arg (Data, 6, Default => -1);
            Child  : constant MDI_Child :=
              Find_Editor (Kernel, Create (File, Kernel));
            Editor : constant Source_Editor_Box :=
              Source_Box (Get_Widget (Child)).Editor;
         begin
            if Get_Writable (Editor) then
               Replace_Slice
                 (Get_Buffer (Editor),
                  Text,
                  Editable_Line_Type (Line), Natural (Column),
                  Before, After);
            else
               Set_Error_Msg
                 (Data, -("Attempting to edit a non-writable file: ") & File);
            end if;
         end;

      elsif Command = "get_line"
        or else Command = "get_column"
        or else Command = "get_file"
      then
         declare
            Identifier  : constant String := Nth_Arg (Data, 1);
            Mark_Record : constant Mark_Identifier_Record :=
              Find_Mark (Identifier);
            Buffer      : Source_Buffer;
         begin
            if Mark_Record.File = VFS.No_File then
               Set_Error_Msg (Data, -"mark not found");
            else
               if Mark_Record.Child /= null then
                  Buffer := Get_Buffer
                    (Source_Box (Get_Widget (Mark_Record.Child)).Editor);
               end if;

               if Command = "get_line" then
                  if Buffer /= null then
                     Set_Return_Value
                       (Data,
                        Integer (Src_Editor_Buffer.Line_Information.Get_Line
                                   (Buffer, Mark_Record.Mark)));
                  else
                     Set_Return_Value (Data, Mark_Record.Line);
                  end if;
               elsif Command = "get_column" then
                  if Buffer /= null then
                     Set_Return_Value
                       (Data,
                        Src_Editor_Buffer.Line_Information.Get_Column
                          (Buffer, Mark_Record.Mark));
                  else
                     Set_Return_Value (Data, Mark_Record.Column);
                  end if;
               else
                  Set_Return_Value (Data, Full_Name (Mark_Record.File).all);
               end if;
            end if;
         end;

      elsif Command = "get_last_line" then
         declare
            File  : constant Virtual_File :=
              Create (Nth_Arg (Data, 1), Kernel);
            Child : constant MDI_Child := Find_Editor (Kernel, File);
         begin
            if Child = null then
               declare
                  A : GNAT.OS_Lib.String_Access := Read_File (File);
                  N : Natural := 0;
               begin
                  if A /= null then
                     for J in A'Range loop
                        if A (J) = ASCII.LF then
                           N := N + 1;
                        end if;
                     end loop;

                     Free (A);

                     if N = 0 then
                        N := 1;
                     end if;

                     Set_Return_Value (Data, N);
                  else
                     Set_Error_Msg (Data, -"file not found or not opened");
                  end if;
               end;
            else
               Set_Return_Value
                 (Data,
                  Get_Last_Line (Source_Box (Get_Widget (Child)).Editor));
            end if;
         end;

      elsif Command = "block_get_start"
        or else Command = "block_get_end"
        or else Command = "block_get_type"
        or else Command = "block_get_level"
      then
         declare
            File   : constant Virtual_File :=
              Create (Nth_Arg (Data, 1), Kernel);
            Child  : constant MDI_Child := Find_Editor (Kernel, File);
            Line   : constant Editable_Line_Type :=
              Editable_Line_Type (Positive'(Nth_Arg (Data, 2)));
         begin
            if Child = null then
               Set_Error_Msg
                 (Data,
                    -("Attempting to get block information for non" &
                      " open file : ") & Base_Name (File));
            else
               if Command = "block_get_start" then
                  Set_Return_Value
                    (Data,
                     Get_Block_Start
                       (Source_Box (Get_Widget (Child)).Editor, Line));
               elsif Command = "block_get_end" then
                  Set_Return_Value
                    (Data,
                     Get_Block_End
                       (Source_Box (Get_Widget (Child)).Editor, Line));
               elsif Command = "block_get_type" then
                  Set_Return_Value
                    (Data,
                     Get_Block_Type
                       (Source_Box (Get_Widget (Child)).Editor, Line));
               else
                  --  Get_Level
                  Set_Return_Value
                    (Data,
                     Get_Block_Level
                       (Source_Box (Get_Widget (Child)).Editor, Line));
               end if;
            end if;
         end;

      elsif Command = "cursor_get_line"
        or else Command = "cursor_get_column"
      then
         declare
            File  : constant Virtual_File :=
              Create (Nth_Arg (Data, 1), Kernel);
            Child : constant MDI_Child := Find_Editor (Kernel, File);
         begin
            if Child = null then
               Set_Error_Msg
                 (Data,
                    -("Attempting to get cursor position for non open file : ")
                  & Base_Name (File));
            else
               declare
                  Line   : Editable_Line_Type;
                  Column : Positive;
               begin
                  Get_Cursor_Position
                    (Get_Buffer
                       (Source_Box (Get_Widget (Child)).Editor), Line, Column);

                  if Command = "cursor_get_line" then
                     Set_Return_Value (Data, Integer (Line));
                  else
                     Set_Return_Value (Data, Column);
                  end if;
               end;
            end if;
         end;

      elsif Command = "cursor_set_position" then
         declare
            File   : constant Virtual_File :=
              Create (Nth_Arg (Data, 1), Kernel);
            Child  : constant MDI_Child := Find_Editor (Kernel, File);
            Line   : constant Editable_Line_Type :=
              Editable_Line_Type (Integer'(Nth_Arg (Data, 2)));
            Column : Natural := Nth_Arg (Data, 3, Default => 0);
         begin
            if Child = null then
               Set_Error_Msg
                 (Data,
                    -("Attempting to set cursor position for non open file : ")
                  & Base_Name (File));
            else
               if Column = 0 then
                  --  Column has not been specified, set it to the first non
                  --  white space character.

                  declare
                     Chars : constant String :=
                       Get_Chars
                         (Get_Buffer (Source_Box (Get_Widget (Child)).Editor),
                          Line);
                  begin
                     --  Set the column to 1, if line is empty we want to set
                     --  the cursor on the first column.

                     Column := 1;

                     for K in Chars'Range loop
                        Column := K;
                        exit when Chars (K) /= ' '
                          and then Chars (K) /= ASCII.HT;
                     end loop;

                     if Column /= 1 then
                        --  Adjust column number.
                        Column := Column - Chars'First + 1;
                     end if;
                  end;
               end if;

               Set_Cursor_Position
                 (Get_Buffer (Source_Box (Get_Widget (Child)).Editor),
                  Line, Column);
            end if;
         end;

      elsif Command = "get_buffer" then
         declare
            File  : constant Virtual_File :=
              Create (Nth_Arg (Data, 1), Kernel);
            Child : constant MDI_Child := Find_Editor (Kernel, File);
            A     : GNAT.OS_Lib.String_Access;

         begin
            if Child /= null then
               Set_Return_Value
                 (Data, Get_Buffer (Source_Box (Get_Widget (Child)).Editor));
            else
               --  The buffer is not currently open, read directly from disk.

               A := Read_File (File);

               if A /= null then
                  Set_Return_Value (Data, A.all);
                  Free (A);
               else
                  Set_Error_Msg (Data, -"file not found");
               end if;
            end if;
         end;

      elsif Command = "save" then
         declare
            Interactive : constant Boolean :=
              Nth_Arg (Data, 1, Default => True);
            All_Save : constant Boolean := Nth_Arg (Data, 2, Default => True);
            Child    : MDI_Child;
         begin
            if All_Save then
               if not Save_MDI_Children (Kernel, Force => not Interactive) then
                  Set_Error_Msg (Data, -"cancelled");
               end if;
            else
               Child := Find_Current_Editor (Kernel);
               if Child = null then
                  Set_Error_Msg (Data, -"no file selected");
               elsif not Save_MDI_Children
                 (Kernel, Children => (1 => Child), Force => not Interactive)
               then
                  Set_Error_Msg (Data, -"cancelled");
               end if;
            end if;
         end;
      elsif Command = "add_blank_lines" then
         declare
            Filename    : constant Virtual_File :=
              Create (Nth_Arg (Data, 1), Kernel);
            Line        : constant Integer := Nth_Arg (Data, 2);
            Number      : constant Integer := Nth_Arg (Data, 3);
            Child       : MDI_Child;
            GC          : Gdk.Gdk_GC;
            Box         : Source_Box;
            Mark_Record : Mark_Identifier_Record;
         begin
            Child := Find_Editor (Kernel, Filename);

            if Number_Of_Arguments (Data) >= 4 then
               GC := Line_Highlighting.Get_GC
                 (Line_Highlighting.Lookup_Category (Nth_Arg (Data, 4)));
            end if;

            if GC = null then
               GC := Id.Blank_Lines_GC;
            end if;

            if Child /= null then
               Box := Source_Box (Get_Widget (Child));

               if Line >= 0 and then Number > 0 then
                  --  Create a new mark record and insert it in the list.
                  Mark_Record.Child := Child;
                  Mark_Record.Line := 0;
                  Mark_Record.File := Filename;
                  Mark_Record.Id := Id.Next_Mark_Id;

                  Id.Next_Mark_Id := Id.Next_Mark_Id + 1;
                  Mark_Record.Length := 0;
                  Mark_Record.Mark :=
                    Add_Blank_Lines
                      (Box.Editor, Editable_Line_Type (Line),
                       GC, "", Number);
                  Mark_Identifier_List.Append (Id.Stored_Marks, Mark_Record);
                  Set_Return_Value (Data, Image (Mark_Record.Id));
               end if;
            else
               Set_Error_Msg (Data, -"file not open");
            end if;
         end;

      elsif Command = "remove_blank_lines" then
         declare
            Identifier  : constant String := Nth_Arg (Data, 1);
            Mark_Record : constant Mark_Identifier_Record :=
              Find_Mark (Identifier);
            Child       : MDI_Child;
            Number      : Integer := 0;
            Box         : Source_Box;
         begin
            Child := Find_Editor (Kernel, Mark_Record.File);

            if Number_Of_Arguments (Data) >= 3 then
               Number := Nth_Arg (Data, 2);
            end if;

            if Child /= null then
               Box := Source_Box (Get_Widget (Child));

               Src_Editor_Buffer.Line_Information.Remove_Blank_Lines
                 (Get_Buffer (Box.Editor), Mark_Record.Mark, Number);
            else
               Set_Error_Msg (Data, -"file not found or not open");
            end if;
         end;
      end if;
   end Edit_Command_Handler;

   ----------------
   -- Fill_Marks --
   ----------------

   procedure Fill_Marks
     (Kernel : Kernel_Handle;
      File   : VFS.Virtual_File)
   is
      Id    : constant Source_Editor_Module :=
        Source_Editor_Module (Src_Editor_Module_Id);

      use Mark_Identifier_List;

      Box         : Source_Box;
      Child       : MDI_Child;
      Node        : List_Node;
      Mark_Record : Mark_Identifier_Record;
   begin
      if Is_In_List (Id.Unopened_Files, Full_Name (File).all) then
         Child := Find_Editor (Kernel, File);

         if Child = null then
            return;
         end if;

         Box := Source_Box (Get_Widget (Child));
         Remove_From_List (Id.Unopened_Files, Full_Name (File).all);

         Node := First (Id.Stored_Marks);

         while Node /= Null_Node loop
            Mark_Record := Data (Node);

            if Mark_Record.File = File then
               Set_Data
                 (Node,
                  Mark_Identifier_Record'
                    (Id => Mark_Record.Id,
                     Child => Child,
                     File => File,
                     Line => Mark_Record.Line,
                     Mark =>
                       Create_Mark
                         (Box.Editor,
                          Editable_Line_Type (Mark_Record.Line),
                          Mark_Record.Column),
                     Column => Mark_Record.Column,
                     Length => Mark_Record.Length));
            end if;

            Node := Next (Node);
         end loop;
      end if;
   end Fill_Marks;

   --------------------
   -- File_Edited_Cb --
   --------------------

   procedure File_Edited_Cb
     (Widget  : access Glib.Object.GObject_Record'Class;
      Args    : GValues;
      Kernel  : Kernel_Handle)
   is
      pragma Unreferenced (Widget);

      Id    : constant Source_Editor_Module :=
        Source_Editor_Module (Src_Editor_Module_Id);
      Infos : Line_Information_Data;
      File  : constant Virtual_File :=
        Create (Full_Filename => Get_String (Nth (Args, 1)));
   begin
      if Id.Display_Line_Numbers then
         Create_Line_Information_Column
           (Kernel,
            File,
            Src_Editor_Module_Name,
            Stick_To_Data => False,
            Every_Line    => True);

         Infos := new Line_Information_Array (1 .. 1);
         Infos (1).Text := new String'("   1");

         Add_Line_Information
           (Kernel,
            File,
            Src_Editor_Module_Name,
            Infos);

         Unchecked_Free (Infos);
      end if;

      Fill_Marks (Kernel, File);
   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end File_Edited_Cb;

   -----------------------------
   -- File_Changed_On_Disk_Cb --
   -----------------------------

   procedure File_Changed_On_Disk_Cb
     (Widget  : access Glib.Object.GObject_Record'Class;
      Args    : GValues;
      Kernel  : Kernel_Handle)
   is
      pragma Unreferenced (Widget);
      File  : constant Virtual_File :=
        Create (Get_String (Nth (Args, 1)), Kernel);
      Iter  : Child_Iterator := First_Child (Get_MDI (Kernel));
      Child : MDI_Child;
      Box   : Source_Box;
   begin
      if File = VFS.No_File then
         return;
      end if;

      loop
         Child := Get (Iter);

         exit when Child = null;

         if File = Get_Filename (Child) then
            Box := Source_Box (Get_Widget (Child));
            Check_Timestamp (Box.Editor);
         end if;

         Next (Iter);
      end loop;
   end File_Changed_On_Disk_Cb;

   --------------------
   -- File_Closed_Cb --
   --------------------

   procedure File_Closed_Cb
     (Widget  : access Glib.Object.GObject_Record'Class;
      Args    : GValues;
      Kernel  : Kernel_Handle)
   is
      pragma Unreferenced (Widget);

      use Mark_Identifier_List;

      Id    : constant Source_Editor_Module :=
        Source_Editor_Module (Src_Editor_Module_Id);
      File  : constant Virtual_File :=
        Create (Get_String (Nth (Args, 1)), Kernel);

      Node        : List_Node;
      Mark_Record : Mark_Identifier_Record;
      Added       : Boolean := False;
      Box         : Source_Box;

   begin
      --  If the file has marks, store their location.

      Node := First (Id.Stored_Marks);

      while Node /= Null_Node loop
         if Data (Node).File = File then
            Mark_Record := Data (Node);

            if Mark_Record.Child /= null
              and then Mark_Record.Mark /= null
              and then Mark_Record.Line /= 0
            then
               Box := Source_Box (Get_Widget (Mark_Record.Child));

               Mark_Record.Line :=
                 Natural (Src_Editor_Buffer.Line_Information.Get_Line
                            (Get_Buffer (Box.Editor), Mark_Record.Mark));
               Mark_Record.Column :=
                 Src_Editor_Buffer.Line_Information.Get_Column
                   (Get_Buffer (Box.Editor), Mark_Record.Mark);

               Set_Data (Node,
                         Mark_Identifier_Record'
                           (Id => Mark_Record.Id,
                            Child => null,
                            File => File,
                            Line => Mark_Record.Line,
                            Mark => null,
                            Column => Mark_Record.Column,
                            Length => Mark_Record.Length));

               if not Added then
                  Add_Unique_Sorted (Id.Unopened_Files, Full_Name (File).all);
                  Added := True;
               end if;
            end if;
         end if;

         Node := Next (Node);
      end loop;

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end File_Closed_Cb;

   -------------------
   -- File_Saved_Cb --
   -------------------

   procedure File_Saved_Cb
     (Widget  : access Glib.Object.GObject_Record'Class;
      Args    : GValues;
      Kernel  : Kernel_Handle)
   is
      pragma Unreferenced (Widget);

      File  : constant String := Get_String (Nth (Args, 1));
      Base  : constant String := Base_Name (File);
   begin
      --  Insert the saved file in the Recent menu.

      if File /= ""
        and then not (Base'Length > 2
                      and then Base (Base'First .. Base'First + 1) = ".#")
      then
         Add_To_Recent_Menu (Kernel, File);
      end if;
   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end File_Saved_Cb;

   ---------------------
   -- Delete_Callback --
   ---------------------

   function Delete_Callback
     (Widget : access Gtk_Widget_Record'Class;
      Params : Glib.Values.GValues) return Boolean
   is
      pragma Unreferenced (Params);
      Kernel : constant Kernel_Handle :=
        Get_Kernel (Source_Box (Widget).Editor);
   begin
      return Get_Ref_Count (Source_Box (Widget).Editor) = 1
        and then not Save_MDI_Children
          (Kernel,
           Children => (1 => Find_MDI_Child (Get_MDI (Kernel), Widget)),
           Force => False);

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
         return False;
   end Delete_Callback;

   ------------------------
   -- File_Edit_Callback --
   ------------------------

   function File_Edit_Callback (D : Location_Idle_Data) return Boolean is
   begin
      if Is_Valid_Location (D.Edit, D.Line) then
         Set_Screen_Location (D.Edit, D.Line, D.Column, Force_Focus => False);

         if D.Column_End /= 0
           and then Is_Valid_Location (D.Edit, D.Line, D.Column_End)
         then
            Select_Region (D.Edit, D.Line, D.Column, D.Line, D.Column_End);
         end if;
      end if;

      File_Edited (Get_Kernel (D.Edit), Get_Filename (D.Edit));

      return False;

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
         return False;
   end File_Edit_Callback;

   ------------------
   -- Load_Desktop --
   ------------------

   function Load_Desktop
     (MDI  : MDI_Window;
      Node : Node_Ptr;
      User : Kernel_Handle) return MDI_Child
   is
      Src    : Source_Box := null;
      File   : Glib.String_Ptr;
      F      : Virtual_File;
      Str    : Glib.String_Ptr;
      Id     : Idle_Handler_Id;
      Line   : Positive := 1;
      Column : Positive := 1;
      Child  : MDI_Child;
      pragma Unreferenced (Id, MDI);

      Dummy  : Boolean;
      pragma Unreferenced (Dummy);
   begin
      if Node.Tag.all = "Source_Editor" then
         File := Get_Field (Node, "File");

         if File /= null and then File.all /= "" then
            Str := Get_Field (Node, "Line");

            if Str /= null then
               Line := Positive'Value (Str.all);
            end if;

            Str := Get_Field (Node, "Column");

            if Str /= null then
               Column := Positive'Value (Str.all);
            end if;

            F := Create (Full_Filename => File.all);
            if not Is_Open (User, F) then
               Src := Open_File (User, F, False);
               Child := Find_Editor (User, F);
            else
               Child := Find_Editor (User, F);
               declare
                  Edit  : constant Source_Editor_Box :=
                    Get_Source_Box_From_MDI (Child);
               begin
                  Src := New_View (User, Edit);
               end;
            end if;

            if Src /= null then
               Dummy := File_Edit_Callback
                 ((Src.Editor, Line, Column, 0, User));

               --  Add the location in the navigations button.
               declare
                  Args : Argument_List :=
                    (new String'("edit"),
                     new String'(Full_Name (F).all),
                     new String'(Image (Line)),
                     new String'(Image (Column)));
               begin
                  Execute_GPS_Shell_Command
                    (User, "add_location_command", Args);
                  Free (Args);
               end;
            end if;
         end if;
      end if;

      return Child;

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
         return null;
   end Load_Desktop;

   -----------------------
   -- On_Lines_Revealed --
   -----------------------

   procedure On_Lines_Revealed
     (Widget  : access Glib.Object.GObject_Record'Class;
      Args    : GValues;
      Kernel  : Kernel_Handle)
   is
      pragma Unreferenced (Widget);

      Context      : constant Selection_Context_Access :=
        To_Selection_Context_Access (Get_Address (Nth (Args, 1)));
      Area_Context : File_Area_Context_Access;
      Infos        : Line_Information_Data;
      Line1, Line2 : Integer;

   begin
      if Context.all in File_Area_Context'Class then
         Area_Context := File_Area_Context_Access (Context);

         Get_Area (Area_Context, Line1, Line2);

         Infos := new Line_Information_Array (Line1 .. Line2);

         for J in Infos'Range loop
            Infos (J).Text := new String'(Image (J));
         end loop;

         if Has_File_Information (Area_Context) then
            Add_Line_Information
              (Kernel,
               File_Information (Area_Context),
               Src_Editor_Module_Name,
               Infos,
               Normalize => False);
         end if;

         Unchecked_Free (Infos);
      end if;
   end On_Lines_Revealed;

   ------------------
   -- Save_Desktop --
   ------------------

   function Save_Desktop
     (Widget : access Gtk.Widget.Gtk_Widget_Record'Class) return Node_Ptr
   is
      N, Child     : Node_Ptr;
      Line, Column : Positive;
      Editor       : Source_Editor_Box;

   begin
      if Widget.all in Source_Box_Record'Class then
         Editor := Source_Box (Widget).Editor;

         declare
            Filename : constant String :=
              Full_Name (Get_Filename (Editor)).all;
         begin
            if Filename = "" then
               return null;
            end if;

            N := new Node;
            N.Tag := new String'("Source_Editor");

            Child := new Node;
            Child.Tag := new String'("File");
            Child.Value := new String'(Filename);
            Add_Child (N, Child);

            Get_Cursor_Location (Editor, Line, Column);

            Child := new Node;
            Child.Tag := new String'("Line");
            Child.Value := new String'(Image (Line));
            Add_Child (N, Child);

            Child := new Node;
            Child.Tag := new String'("Column");
            Child.Value := new String'(Image (Column));
            Add_Child (N, Child);

            Child := new Node;
            Child.Tag := new String'("Column_End");
            Child.Value := new String'(Image (Column));
            Add_Child (N, Child);

            return N;
         end;
      end if;

      return null;
   end Save_Desktop;

   -----------------------------
   -- Get_Source_Box_From_MDI --
   -----------------------------

   function Get_Source_Box_From_MDI
     (Child : MDI_Child) return Source_Editor_Box is
   begin
      if Child = null then
         return null;
      else
         return Source_Box (Get_Widget (Child)).Editor;
      end if;
   end Get_Source_Box_From_MDI;

   -------------------------
   -- Find_Current_Editor --
   -------------------------

   function Find_Current_Editor
     (Kernel : access Kernel_Handle_Record'Class) return MDI_Child is
   begin
      return Find_MDI_Child_By_Tag (Get_MDI (Kernel), Source_Box_Record'Tag);
   end Find_Current_Editor;

   -------------
   -- Gtk_New --
   -------------

   procedure Gtk_New
     (Box    : out Source_Box;
      Editor : Source_Editor_Box) is
   begin
      Box := new Source_Box_Record;
      Initialize (Box, Editor);
   end Gtk_New;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (Box    : access Source_Box_Record'Class;
      Editor : Source_Editor_Box) is
   begin
      Gtk.Box.Initialize_Hbox (Box);
      Box.Editor := Editor;
   end Initialize;

   --------------
   -- New_View --
   --------------

   function New_View
     (Kernel  : access Kernel_Handle_Record'Class;
      Current : Source_Editor_Box) return Source_Box
   is
      Editor  : Source_Editor_Box;
      Box     : Source_Box;
      Child   : MDI_Child;

   begin
      if Current = null then
         return null;
      end if;

      declare
         Title : constant Virtual_File := Get_Filename (Current);
      begin
         Create_New_View (Editor, Kernel, Current);
         Gtk_New (Box, Editor);
         Attach (Editor, Box);

         Child := new Editor_Child_Record;
         Initialize (Child, Box, All_Buttons);
         Child := Put
           (Kernel, Child,
            Focus_Widget => Gtk_Widget (Get_View (Editor)),
            Default_Width  => Get_Pref (Kernel, Default_Widget_Width),
            Default_Height => Get_Pref (Kernel, Default_Widget_Height),
            Module => Src_Editor_Module_Id);

         Set_Icon (Child, Gdk_New_From_Xpm_Data (editor_xpm));
         Set_Focus_Child (Child);

         declare
            Im : constant String := Image (Get_Total_Ref_Count (Editor));
         begin
            Set_Title
              (Child,
               Full_Name (Title).all & " <" & Im & ">",
               Base_Name (Title) & " <" & Im & ">");
         end;

         Gtkada.Handlers.Return_Callback.Object_Connect
           (Box,
            "delete_event",
            Delete_Callback'Access,
            Gtk_Widget (Box),
            After => False);
      end;

      return Box;
   end New_View;

   procedure New_View
     (Kernel : access Kernel_Handle_Record'Class)
   is
      Current : constant Source_Editor_Box :=
        Get_Source_Box_From_MDI (Find_Current_Editor (Kernel));
      Box     : Source_Box;
      pragma Unreferenced (Box);

   begin
      if Current /= null then
         Box := New_View (Kernel, Current);
      end if;
   end New_View;

   -------------------
   -- Save_Function --
   -------------------

   function Save_Function
     (Kernel : access Kernel_Handle_Record'Class;
      Child  : Gtk.Widget.Gtk_Widget;
      Mode   : Save_Function_Mode) return Boolean
   is
      pragma Unreferenced (Kernel);
      Success        : Boolean;
      Containing_Box : constant Source_Box := Source_Box (Child);
      Box            : constant Source_Editor_Box := Containing_Box.Editor;
   begin
      case Mode is
         when Query =>
            return Needs_To_Be_Saved (Box);

         when Action =>
            if Needs_To_Be_Saved (Box) then
               Save_To_File (Box, Success => Success);
               return Success;
            else
               --  Nothing to do => success
               return True;
            end if;
      end case;
   end Save_Function;

   ------------------------
   -- Create_File_Editor --
   ------------------------

   function Create_File_Editor
     (Kernel     : access Kernel_Handle_Record'Class;
      File       : VFS.Virtual_File;
      Create_New : Boolean := True) return Source_Editor_Box
   is
      Success     : Boolean;
      Editor      : Source_Editor_Box;
      File_Exists : constant Boolean := Is_Regular_File (File);

   begin
      --  Create a new editor only if the file exists or we are asked to
      --  create a new empty one anyway.

      if File_Exists or else Create_New then
         Gtk_New (Editor, Kernel_Handle (Kernel));

         if File_Exists then
            Load_File (Editor, File,
                       Force_Focus => True,
                       Success     => Success);

            if not Success then
               Destroy (Editor);
               Editor := null;
            end if;

         else
            Load_Empty_File (Editor, File, Get_Language_Handler (Kernel));
         end if;
      end if;

      return Editor;
   end Create_File_Editor;

   ------------------------
   -- Add_To_Recent_Menu --
   ------------------------

   procedure Add_To_Recent_Menu
     (Kernel : access Kernel_Handle_Record'Class; File : String) is
   begin
      Add_To_History (Kernel, Hist_Key, File);
   end Add_To_Recent_Menu;

   ---------------
   -- Open_File --
   ---------------

   function Open_File
     (Kernel     : access Kernel_Handle_Record'Class;
      File       : VFS.Virtual_File := VFS.No_File;
      Create_New : Boolean := True;
      Focus      : Boolean := True) return Source_Box
   is
      MDI        : constant MDI_Window := Get_MDI (Kernel);
      Editor     : Source_Editor_Box;
      Box        : Source_Box;
      Child      : MDI_Child;

   begin
      if File /= VFS.No_File then
         Child := Find_Editor (Kernel, File);

         if Child /= null then
            Raise_Child (Child);

            if Focus then
               Set_Focus_Child (Child);
            end if;

            return Source_Box (Get_Widget (Child));
         end if;
      end if;

      Editor := Create_File_Editor (Kernel, File, Create_New);

      --  If we have created an editor, put it into a box, and give it
      --  to the MDI to handle

      if Editor /= null then
         Gtk_New (Box, Editor);
         Attach (Editor, Box);

         Child := new Editor_Child_Record;
         Initialize (Child, Box, All_Buttons);
         Child := Put
           (Kernel, Child, Focus_Widget => Gtk_Widget (Get_View (Editor)),
            Default_Width  => Get_Pref (Kernel, Default_Widget_Width),
            Default_Height => Get_Pref (Kernel, Default_Widget_Height),
            Module => Src_Editor_Module_Id);
         Set_Icon (Child, Gdk_New_From_Xpm_Data (editor_xpm));

         if Focus then
            Set_Focus_Child (Child);
         end if;

         Raise_Child (Child);

         if File /= VFS.No_File then
            Set_Title (Child, Full_Name (File).all, Base_Name (File));
            File_Edited (Kernel, Get_Filename (Child));

         else
            --  Determine the number of "Untitled" files open.

            declare
               Iterator    : Child_Iterator := First_Child (MDI);
               The_Child   : MDI_Child;
               Nb_Untitled : Natural := 0;
               No_Name     : constant String := -"Untitled";
               Ident       : Virtual_File;
            begin
               The_Child := Get (Iterator);

               while The_Child /= null loop
                  if The_Child /= Child
                    and then Get_Widget (The_Child).all in
                    Source_Box_Record'Class
                    and then Get_Filename (The_Child) = VFS.No_File
                  then
                     Nb_Untitled := Nb_Untitled + 1;
                  end if;

                  Next (Iterator);
                  The_Child := Get (Iterator);
               end loop;

               if Nb_Untitled = 0 then
                  Set_Title (Child, No_Name);
                  Ident := Create (Full_Filename => No_Name);
               else
                  declare
                     Identifier : constant String :=
                       No_Name & " (" & Image (Nb_Untitled + 1) & ")";
                  begin
                     Set_Title (Child, Identifier);
                     Ident := Create (Full_Filename => Identifier);
                  end;
               end if;

               Set_File_Identifier (Editor, Ident);
               Set_Filename (Editor, Get_Filename (Child));
               File_Edited (Kernel, Ident);
            end;
         end if;

         Gtkada.Handlers.Return_Callback.Object_Connect
           (Box,
            "delete_event",
            Delete_Callback'Access,
            Gtk_Widget (Box),
            After => False);

         if File /= VFS.No_File then
            Add_To_Recent_Menu (Kernel, Full_Name (File).all);
         end if;

      else
         Console.Insert
           (Kernel, (-"Cannot open file ") & "'" & Full_Name (File).all & "'",
            Add_LF => True,
            Mode   => Error);
      end if;

      return Box;
   end Open_File;

   -----------------------
   -- Location_Callback --
   -----------------------

   function Location_Callback (D : Location_Idle_Data) return Boolean is
   begin
      if D.Line /= 0 and then Is_Valid_Location (D.Edit, D.Line) then
         Set_Screen_Location
           (D.Edit, D.Line, D.Column,
            True);

         if D.Column_End /= 0
           and then Is_Valid_Location (D.Edit, D.Line, D.Column_End)
         then
            Select_Region (D.Edit, D.Line, D.Column, D.Line, D.Column_End);
         end if;
      end if;

      return False;

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
         return False;
   end Location_Callback;

   ------------------
   -- Save_To_File --
   ------------------

   procedure Save_To_File
     (Kernel  : access Kernel_Handle_Record'Class;
      Name    : VFS.Virtual_File := VFS.No_File;
      Success : out Boolean)
   is
      Child  : constant MDI_Child := Find_Current_Editor (Kernel);
      Source : Source_Editor_Box;

   begin
      if Child = null then
         Success := False;
         return;
      end if;

      Source := Source_Box (Get_Widget (Child)).Editor;

      declare
         Old_Name : constant Virtual_File := Get_Filename (Source);
      begin
         Save_To_File (Source, Name, Success);

         declare
            New_Name : constant Virtual_File := Get_Filename (Source);
         begin
            --  Update the title, in case "save as..." was used.

            if Old_Name /= New_Name then
               Set_Title
                 (Child, Full_Name (New_Name).all, Base_Name (New_Name));
               Recompute_View (Kernel);
            end if;
         end;
      end;
   end Save_To_File;

   ------------------
   -- On_Open_File --
   ------------------

   procedure On_Open_File
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);
   begin
      declare
         Filename : constant Virtual_File :=
           Select_File
             (Title             => -"Open File",
              Parent            => Get_Main_Window (Kernel),
              Use_Native_Dialog => Get_Pref (Kernel, Use_Native_Dialogs),
              Kind              => Open_File,
              History           => Get_History (Kernel));

      begin
         if Filename /= VFS.No_File then
            Open_File_Editor (Kernel, Filename);
         end if;
      end;

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Open_File;

   -----------------------
   -- On_Open_From_Path --
   -----------------------

   procedure On_Open_From_Path
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      Label  : Gtk_Label;
      Button : Gtk_Widget;
      pragma Unreferenced (Widget, Button);

      Open_File_Dialog  : Gtk_Dialog;
      Open_File_Entry   : Gtkada_Entry;
      Hist              : constant String_List_Access :=
        Get_History (Get_History (Kernel).all, Open_From_Path_History);

   begin
      Gtk_New (Open_File_Dialog,
               Title  => -"Open file from project",
               Parent => Get_Main_Window (Kernel),
               Flags  => Modal or Destroy_With_Parent);
      Set_Default_Size (Open_File_Dialog, 300, 200);
      Set_Position (Open_File_Dialog, Win_Pos_Mouse);

      Gtk_New (Label, -"Enter file name (use <tab> for completion):");
      Pack_Start (Get_Vbox (Open_File_Dialog), Label, Expand => False);

      --  Do not use a combo box, so that users can easily navigate to the list
      --  of completions through the keyboard (C423-005)
      Gtk_New (Open_File_Entry, Use_Combo => False);
      Set_Activates_Default (Get_Entry (Open_File_Entry), True);
      Pack_Start (Get_Vbox (Open_File_Dialog), Open_File_Entry,
                  Fill => True, Expand => True);

      if Hist /= null then
         Set_Text (Get_Entry (Open_File_Entry),
                   Base_Name (Hist (Hist'First).all));
         Select_Region (Get_Entry (Open_File_Entry), 0, -1);
      end if;

      Button := Add_Button (Open_File_Dialog, Stock_Ok, Gtk_Response_OK);
      Button := Add_Button
        (Open_File_Dialog, Stock_Cancel, Gtk_Response_Cancel);
      Set_Default_Response (Open_File_Dialog, Gtk_Response_OK);

      Grab_Focus (Get_Entry (Open_File_Entry));
      Show_All (Open_File_Dialog);

      declare
         List1 : File_Array_Access := Get_Source_Files
           (Project   => Get_Project (Kernel),
            Recursive => True,
            Full_Path => False);
         List2 : File_Array_Access :=
           Get_Predefined_Source_Files (Get_Registry (Kernel));
         Completions : String_Array_Access :=
           new String_Array (List1'First .. List1'Last + List2'Length);
      begin
         for L in List1'Range loop
            Completions (L) := new String'(Base_Name (List1 (L)));
         end loop;

         for L in List2'Range loop
            Completions (List1'Last + L - List2'First + 1) :=
              new String'(Base_Name (List2 (L)));
         end loop;

         Set_Completions (Open_File_Entry, Completions);
         Unchecked_Free (List1);
         Unchecked_Free (List2);
      end;

      if Run (Open_File_Dialog) = Gtk_Response_OK then

         --  Look for the file in the project. If the file cannot be found,
         --  display an error message in the console.

         declare
            Text : constant String :=
              Get_Text (Get_Entry (Open_File_Entry));
            Full : constant Virtual_File :=
              Create (Text, Kernel, Use_Object_Path => False);
         begin
            if Is_Regular_File (Full) then
               Add_To_History
                 (Get_History (Kernel).all, Open_From_Path_History,
                  Full_Name (Full).all);

               Open_File_Editor
                 (Kernel, Full,
                  Enable_Navigation => True,
                  New_File          => False);

            else
               Insert
                 (Kernel,
                    -"Could not find source file """ & Text &
                      (-""" in currently loaded project."),
                  Mode => Error);
            end if;
         end;
      end if;

      Destroy (Open_File_Dialog);

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Open_From_Path;

   --------------
   -- Activate --
   --------------

   procedure Activate (Callback : access On_Recent; Item : String) is
   begin
      Open_File_Editor (Callback.Kernel, Create (Full_Filename => Item));

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end Activate;

   -----------------
   -- On_New_File --
   -----------------

   procedure On_New_File
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      Editor : Source_Box;
      pragma Unreferenced (Widget, Editor);
   begin
      Editor := Open_File (Kernel, File => VFS.No_File);

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_New_File;

   -------------
   -- On_Save --
   -------------

   procedure On_Save
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);
      Success : Boolean;
   begin
      Save_To_File (Kernel, Success => Success);

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Save;

   ----------------
   -- On_Save_As --
   ----------------

   procedure On_Save_As
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);

      Success : Boolean;
      Source  : constant Source_Editor_Box :=
        Get_Source_Box_From_MDI (Find_Current_Editor (Kernel));

   begin
      if Source /= null then
         declare
            Old_Name : constant Virtual_File := Get_Filename (Source);
            New_Name : constant Virtual_File :=
              Select_File
                (Title             => -"Save File As",
                 Parent            => Get_Main_Window (Kernel),
                 Base_Directory    => Dir_Name (Old_Name).all,
                 Default_Name      => Base_Name (Old_Name),
                 Use_Native_Dialog => Get_Pref (Kernel, Use_Native_Dialogs),
                 Kind              => Save_File,
                 History           => Get_History (Kernel));

         begin
            if New_Name /= VFS.No_File then
               Save_To_File (Kernel, New_Name, Success);
            end if;
         end;
      end if;

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Save_As;

   -----------------
   -- On_Save_All --
   -----------------

   procedure On_Save_All
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      Ignore : Boolean;
      pragma Unreferenced (Widget, Ignore);

   begin
      Ignore := Save_MDI_Children (Kernel, Force => False);

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Save_All;

   --------------
   -- On_Print --
   --------------

   procedure On_Print
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);
      use Pango.Font, Pango.Enums;

      Success          : Boolean;
      Child            : constant MDI_Child := Find_Current_Editor (Kernel);
      Source           : constant Source_Editor_Box :=
        Get_Source_Box_From_MDI (Child);
      Print_Helper     : constant String := Get_Pref (Kernel, Print_Command);
      Source_Font      : constant Pango_Font_Description :=
        Get_Pref (Kernel, Source_Editor_Font);
      Source_Font_Name : constant String := Get_Family (Source_Font);
      Source_Font_Size : constant Gint := To_Pixels (Get_Size (Source_Font));

   begin
      if Source = null then
         return;
      end if;

      if Print_Helper = "" then
         --  Use our internal facility

         Src_Printing.Print
           (Source,
            Font_Name  => Source_Font_Name,
            Font_Size  => Integer (Source_Font_Size),
            Bold       => False,
            Italicized => False);

      else
         --  Use helper

         if Save_MDI_Children
           (Kernel,
            Children => (1 => Child),
            Force    => Get_Pref (Kernel, Auto_Save))
         then
            declare
               Cmd : Argument_List_Access := Argument_String_To_List
                 (Print_Helper & " " & Full_Name (Get_Filename (Source)).all);
            begin
               Launch_Process
                 (Kernel, Cmd (Cmd'First).all, Cmd (Cmd'First + 1 .. Cmd'Last),
                  Name => "", Success => Success);
               Free (Cmd);
            end;
         end if;
      end if;
   end On_Print;

   -------------
   -- Execute --
   -------------

   function Execute
     (Command : access Clipboard_Command; Event : Gdk_Event)
      return Command_Return_Type
   is
      pragma Unreferenced (Event);
      Source : constant Source_Editor_Box :=
        Get_Source_Box_From_MDI (Find_Current_Editor (Command.Kernel));
   begin
      if Source /= null then
         case Command.Kind is
            when Cut   => Cut_Clipboard (Source);
            when Copy  => Copy_Clipboard (Source);
            when Paste => Paste_Clipboard (Source);
         end case;
         return Commands.Success;
      else
         return Commands.Failure;
      end if;
   end Execute;

   -------------------
   -- On_Select_All --
   -------------------

   procedure On_Select_All
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);
      Source : constant Source_Editor_Box :=
        Get_Source_Box_From_MDI (Find_Current_Editor (Kernel));
   begin
      if Source /= null then
         Select_All (Source);
      end if;

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Select_All;

   -----------------
   -- On_New_View --
   -----------------

   procedure On_New_View
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);
   begin
      New_View (Kernel);

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_New_View;

   ---------------------------------
   -- On_Goto_Line_Current_Editor --
   ---------------------------------

   procedure On_Goto_Line_Current_Editor
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);
      Editor : constant Source_Editor_Box :=
        Get_Source_Box_From_MDI (Find_Current_Editor (Kernel));

   begin
      if Editor /= null then
         On_Goto_Line (Editor => GObject (Editor), Kernel => Kernel);
      end if;

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Goto_Line_Current_Editor;

   -------------------------
   -- On_Goto_Declaration --
   -------------------------

   procedure On_Goto_Declaration
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);
      Editor : constant Source_Editor_Box :=
        Get_Source_Box_From_MDI (Find_Current_Editor (Kernel));
   begin
      if Editor = null then
         return;
      end if;

      Goto_Declaration_Or_Body
        (Kernel,
         To_Body => False,
         Editor  => Editor,
         Context => Entity_Selection_Context_Access
           (Default_Factory (Kernel, Editor)));

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Goto_Declaration;

   ------------------
   -- On_Goto_Body --
   ------------------

   procedure On_Goto_Body
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);
      Editor : constant Source_Editor_Box :=
        Get_Source_Box_From_MDI (Find_Current_Editor (Kernel));
   begin
      if Editor = null then
         return;
      end if;

      Goto_Declaration_Or_Body
        (Kernel, To_Body => True,
         Editor => Editor,
         Context => Entity_Selection_Context_Access
           (Default_Factory (Kernel, Editor)));

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Goto_Body;

   ----------------------
   -- Generate_Body_Cb --
   ----------------------

   procedure Generate_Body_Cb (Data : Process_Data; Status : Integer) is
      Body_Name : constant Virtual_File := Other_File_Name
        (Data.Kernel, Create (Full_Filename => Data.Name.all));
   begin
      if Status = 0
        and then Is_Regular_File (Body_Name)
      then
         Open_File_Editor (Data.Kernel, Body_Name);
      end if;
   end Generate_Body_Cb;

   ----------------------
   -- On_Generate_Body --
   ----------------------

   procedure On_Generate_Body
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);

      Context : constant Selection_Context_Access :=
        Get_Current_Context (Kernel);

   begin
      if Context = null
        or else not (Context.all in File_Selection_Context'Class)
      then
         Console.Insert
           (Kernel, -"No file selected, cannot generate body", Mode => Error);
         return;
      end if;

      declare
         File_Context : constant File_Selection_Context_Access :=
           File_Selection_Context_Access (Context);
         File       : constant Virtual_File := File_Information (File_Context);
         Success    : Boolean;
         Args       : Argument_List (1 .. 4);
         Lang       : String := Get_Language_From_File
           (Get_Language_Handler (Kernel), File);

      begin
         if File = VFS.No_File then
            Console.Insert
              (Kernel, -"No file name, cannot generate body", Mode => Error);
            return;
         end if;

         To_Lower (Lang);

         if Lang /= "ada" then
            Console.Insert
              (Kernel, -"Body generation of non Ada file not yet supported",
               Mode => Error);
            return;
         end if;

         if not Save_MDI_Children
           (Kernel, Force => Get_Pref (Kernel, Auto_Save))
         then
            return;
         end if;

         Args (1) := new String'("stub");
         Args (2) := new String'
           ("-P" & Project_Path
            (Get_Project_From_File (Get_Registry (Kernel), File)));
         Args (3) := new String'(Full_Name (File).all);
         Args (4) := new String'(Dir_Name (File).all);

         declare
            Scenar : Argument_List_Access := Argument_String_To_List
              (Scenario_Variables_Cmd_Line (Kernel, GNAT_Syntax));
         begin
            Launch_Process
              (Kernel, "gnat", Args (1 .. 2) & Scenar.all & Args (3 .. 4),
               "", null,
               Generate_Body_Cb'Access, Full_Name (File).all, Success);
            Free (Args);
            Free (Scenar);
         end;

         --  ??? Should remove the message when gnatstub has finished
         --  executing, and automatically load the file

         if Success then
            Print_Message
              (Glide_Window (Get_Main_Window (Kernel)).Statusbar,
               Help, -"Generating body...");
         end if;
      end;

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Generate_Body;

   ---------------------
   -- Pretty_Print_Cb --
   ---------------------

   procedure Pretty_Print_Cb (Data : Process_Data; Status : Integer) is
   begin
      if Status = 0 then
         Open_File_Editor
           (Data.Kernel,
            Create (Full_Filename => Data.Name.all & ".pp"));
      end if;
   end Pretty_Print_Cb;

   -----------------------
   -- Comment_Uncomment --
   -----------------------

   procedure Comment_Uncomment
     (Kernel : Kernel_Handle; Comment : Boolean)
   is
      Context    : constant Selection_Context_Access :=
        Get_Current_Context (Kernel);

      Area         : File_Area_Context_Access;
      File_Context : File_Selection_Context_Access;
      Start_Line   : Integer;
      End_Line     : Integer;


      use String_List_Utils.String_List;
   begin
      if Context /= null
        and then Context.all in File_Selection_Context'Class
        and then Has_File_Information
          (File_Selection_Context_Access (Context))
        and then Has_Directory_Information
          (File_Selection_Context_Access (Context))
      then
         File_Context := File_Selection_Context_Access (Context);

         declare
            Lang   : Language_Access;
            File   : constant Virtual_File := File_Information (File_Context);
            Lines  : List;
            Length : Integer := 0;

         begin
            if Context.all in File_Area_Context'Class then
               Area := File_Area_Context_Access (Context);
               Get_Area (Area, Start_Line, End_Line);

            elsif Context.all in Entity_Selection_Context'Class
              and then Has_Line_Information
                (Entity_Selection_Context_Access (Context))
            then
               Start_Line := Modules.Line_Information
                 (Entity_Selection_Context_Access (Context));

               End_Line := Start_Line;
            else
               return;
            end if;

            Lang := Get_Language_From_File
              (Get_Language_Handler (Kernel), File);

            --  Create a list of lines, in order to perform the replace
            --  as a block.

            for J in Start_Line .. End_Line loop
               declare
                  Args : Argument_List :=
                    (1 => new String'(Full_Name (File).all),
                     2 => new String'(Image (J)),
                     3 => new String'("1"));
                  Line : constant String :=
                    Execute_GPS_Shell_Command (Kernel, "get_chars", Args);
               begin
                  Free (Args);
                  Length := Length + Line'Length;

                  if Line = "" then
                     Append (Lines, "");
                  else
                     if Comment then
                        Append (Lines, Comment_Line (Lang, Line));
                     else
                        Append (Lines, Uncomment_Line (Lang, Line));
                     end if;
                  end if;
               end;
            end loop;

            --  Create a String containing the modified lines.

            declare
               L : Integer := 0;
               N : List_Node := First (Lines);
            begin
               while N /= Null_Node loop
                  L := L + Data (N)'Length;
                  N := Next (N);
               end loop;

               declare
                  S    : String (1 .. L);
                  Args : Argument_List (1 .. 6);
               begin
                  N := First (Lines);
                  L := 1;

                  while N /= Null_Node loop
                     S (L .. L + Data (N)'Length - 1) := Data (N);
                     L := L + Data (N)'Length;
                     N := Next (N);
                  end loop;

                  Args := (1 => new String'(Full_Name (File).all),
                           2 => new String'(Image (Start_Line)),
                           3 => new String'("1"), --  column
                           4 => new String'(S),
                           5 => new String'("0"), --  before
                           6 => new String'(Image (Length))); --  after
                  Execute_GPS_Shell_Command (Kernel, "replace_text", Args);
                  Free (Args);
               end;
            end;
         end;
      end if;
   end Comment_Uncomment;

   ----------------------
   -- On_Comment_Lines --
   ----------------------

   procedure On_Comment_Lines
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);
   begin
      Comment_Uncomment (Kernel, Comment => True);

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Comment_Lines;

   --------------------
   -- On_Fold_Blocks --
   --------------------

   procedure On_Fold_Blocks
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);
      Current : constant Source_Editor_Box :=
        Get_Source_Box_From_MDI (Find_Current_Editor (Kernel));
   begin
      if Current /= null then
         Src_Editor_Buffer.Line_Information.Fold_All (Get_Buffer (Current));
      end if;

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Fold_Blocks;

   ----------------------
   -- On_Unfold_Blocks --
   ----------------------

   procedure On_Unfold_Blocks
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);
      Current : constant Source_Editor_Box :=
        Get_Source_Box_From_MDI (Find_Current_Editor (Kernel));
   begin
      if Current /= null then
         Src_Editor_Buffer.Line_Information.Unfold_All (Get_Buffer (Current));
      end if;

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Unfold_Blocks;

   ------------------------
   -- On_Uncomment_Lines --
   ------------------------

   procedure On_Uncomment_Lines
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);

   begin
      Comment_Uncomment (Kernel, Comment => False);

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Uncomment_Lines;

   ---------------------
   -- On_Pretty_Print --
   ---------------------

   procedure On_Pretty_Print
     (Widget : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (Widget);

      Context : constant Selection_Context_Access :=
        Get_Current_Context (Kernel);

   begin
      if Context = null
        or else not (Context.all in File_Selection_Context'Class)
      then
         Console.Insert
           (Kernel, -"No file selected, cannot pretty print",
            Mode => Error);
         return;
      end if;

      declare
         File_Context : constant File_Selection_Context_Access :=
           File_Selection_Context_Access (Context);
         File       : constant Virtual_File := File_Information (File_Context);
         Project    : constant String := Project_Name
           (Get_Project_From_File (Get_Registry (Kernel), File));
         Success    : Boolean;
         Args, Vars : Argument_List_Access;
         Lang       : String := Get_Language_From_File
           (Get_Language_Handler (Kernel), File);

      begin
         if File = VFS.No_File then
            Console.Insert
              (Kernel, -"No file name, cannot pretty print",
               Mode => Error);
            return;
         end if;

         To_Lower (Lang);

         if Lang /= "ada" then
            Console.Insert
              (Kernel, -"Pretty printing of non Ada file not yet supported",
               Mode => Error);
            return;
         end if;

         if not Save_MDI_Children
           (Kernel, Force => Get_Pref (Kernel, Auto_Save))
         then
            return;
         end if;

         if Project = "" then
            Args := new Argument_List'
              (new String'("pretty"), new String'(Full_Name (File).all));

         else
            Vars := Argument_String_To_List
              (Scenario_Variables_Cmd_Line (Kernel, GNAT_Syntax));
            Args := new Argument_List'
              ((1 => new String'("pretty"),
                2 => new String'("-P" & Project),
                3 => new String'(Full_Name (File).all)) & Vars.all);
            Unchecked_Free (Vars);
         end if;

         Launch_Process
           (Kernel, "gnat", Args.all, "", null,
            Pretty_Print_Cb'Access, Full_Name (File).all, Success);
         Free (Args);

         if Success then
            Print_Message
              (Glide_Window (Get_Main_Window (Kernel)).Statusbar,
               Help, -"Pretty printing...");
         end if;
      end;

   exception
      when E : others =>
         Pop_State (Kernel);
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Pretty_Print;

   -----------------
   -- Mime_Action --
   -----------------

   function Mime_Action
     (Kernel    : access Kernel_Handle_Record'Class;
      Mime_Type : String;
      Data      : GValue_Array;
      Mode      : Mime_Mode := Read_Write) return Boolean
   is
      pragma Unreferenced (Mode);

      Source    : Source_Box;
      Edit      : Source_Editor_Box;
      MDI       : constant MDI_Window := Get_MDI (Kernel);
      Tmp       : Boolean;
      pragma Unreferenced (Tmp);

   begin
      if Mime_Type = Mime_Source_File then
         declare
            File        : constant Virtual_File :=
              Create (Full_Filename => Get_String (Data (Data'First)));
            Line        : constant Gint    := Get_Int (Data (Data'First + 1));
            Column      : Gint             := Get_Int (Data (Data'First + 2));
            Column_End  : constant Gint    := Get_Int (Data (Data'First + 3));
            New_File    : constant Boolean :=
              Get_Boolean (Data (Data'First + 5));
            Iter        : Child_Iterator := First_Child (MDI);
            Child       : MDI_Child;
            No_Location : Boolean := False;

         begin
            if Line = -1 then
               --  Close all file editors corresponding to File.

               loop
                  Child := Get (Iter);

                  exit when Child = null;

                  if Get_Widget (Child).all in Source_Box_Record'Class
                    and then Get_Filename (Child) = File
                  then
                     Close_Child (Child);
                  end if;

                  Next (Iter);
               end loop;

               return True;

            else
               if Line = 0 and then Column = 0 then
                  No_Location := True;
               end if;

               Source := Open_File
                 (Kernel, File,
                  Create_New => New_File,
                  Focus      => not No_Location);

               if Source /= null then
                  Edit := Source.Editor;
               end if;

               if Column = 0 then
                  Column := 1;
               end if;

               if Edit /= null
                 and then not No_Location
               then
                  Trace (Me, "Setup editor to go to line,col="
                         & Line'Img & Column'Img);
                  Tmp := Location_Callback
                    ((Edit,
                      Natural (Line),
                      Natural (Column),
                      Natural (Column_End),
                      Kernel_Handle (Kernel)));
               end if;

               return Edit /= null;
            end if;
         end;

      elsif Mime_Type = Mime_File_Line_Info then
         declare
            File  : constant Virtual_File :=
              Create (Full_Filename => Get_String (Data (Data'First)));
            Id    : constant String  := Get_String (Data (Data'First + 1));
            Info  : constant Line_Information_Data :=
              To_Line_Information (Get_Address (Data (Data'First + 2)));
            Stick_To_Data : constant Boolean :=
              Get_Boolean (Data (Data'First + 3));
            Every_Line : constant Boolean :=
              Get_Boolean (Data (Data'First + 4));
            Child : MDI_Child;

            procedure Apply_Mime_On_Child (Child : MDI_Child);
            --  Apply the mime information on Child.

            procedure Apply_Mime_On_Child (Child : MDI_Child) is
            begin
               if Info'First = 0 then
                  Create_Line_Information_Column
                    (Source_Box (Get_Widget (Child)).Editor,
                     Id,
                     Stick_To_Data,
                     Every_Line);

               elsif Info'Length = 0 then
                  Remove_Line_Information_Column
                    (Source_Box (Get_Widget (Child)).Editor, Id);

               else
                  Add_File_Information
                    (Source_Box (Get_Widget (Child)).Editor,
                     Id, Info);
               end if;
            end Apply_Mime_On_Child;

         begin
            --  Look for the corresponding file editor.

            Child := Find_Editor (Kernel, File);

            if Child /= null then
               --  The editor was found.
               Apply_Mime_On_Child (Child);

               return True;
            end if;
         end;
      end if;

      return False;

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
         return False;
   end Mime_Action;

   ------------------
   -- On_Edit_File --
   ------------------

   procedure On_Edit_File
     (Widget  : access GObject_Record'Class;
      Context : Selection_Context_Access)
   is
      pragma Unreferenced (Widget);

      File     : constant File_Selection_Context_Access :=
        File_Selection_Context_Access (Context);
      Line     : Natural;

   begin
      Trace (Me, "On_Edit_File: " & Full_Name (File_Information (File)).all);

      if Has_Line_Information (File) then
         Line := Modules.Line_Information (File);
      else
         Line := 1;
      end if;

      Open_File_Editor
        (Get_Kernel (Context),
         Filename  => File_Information (File),
         Line      => Line,
         Column    => Column_Information (File));

   exception
      when E : others =>
         Trace (Me, "Unexpected exception: " & Exception_Information (E));
   end On_Edit_File;

   ------------------------------
   -- Source_Editor_Contextual --
   ------------------------------

   procedure Source_Editor_Contextual
     (Object  : access GObject_Record'Class;
      Context : access Selection_Context'Class;
      Menu    : access Gtk.Menu.Gtk_Menu_Record'Class)
   is
      pragma Unreferenced (Object);
      File  : File_Selection_Context_Access;
      Mitem : Gtk_Menu_Item;

   begin
      if Context.all in File_Selection_Context'Class then
         File := File_Selection_Context_Access (Context);

         if Has_Directory_Information (File)
           and then Has_File_Information (File)
         then
            Gtk_New (Mitem, -"Edit " &
                     Base_Name (File_Information (File)));
            Append (Menu, Mitem);
            Context_Callback.Connect
              (Mitem, "activate",
               Context_Callback.To_Marshaller (On_Edit_File'Access),
               Selection_Context_Access (Context));
         end if;
      end if;
   end Source_Editor_Contextual;

   ---------------------
   -- Default_Factory --
   ---------------------

   function Default_Factory
     (Kernel : access Kernel_Handle_Record'Class;
      Editor : access Source_Editor_Box_Record'Class)
      return Selection_Context_Access is
   begin
      return Get_Contextual_Menu (Kernel, Editor, null, null);
   end Default_Factory;

   ---------------------
   -- Default_Factory --
   ---------------------

   function Default_Factory
     (Kernel : access Kernel_Handle_Record'Class;
      Child  : Gtk.Widget.Gtk_Widget) return Selection_Context_Access
   is
      C : constant Source_Box := Source_Box (Child);
   begin
      return Default_Factory (Kernel, C.Editor);
   end Default_Factory;

   -----------------------------
   -- Expand_Aliases_Entities --
   -----------------------------

   function Expand_Aliases_Entities
     (Kernel    : access Kernel_Handle_Record'Class;
      Expansion : String;
      Special   : Character) return String
   is
      Box : Source_Editor_Box;
      W   : Gtk_Widget := Get_Current_Focus_Widget (Kernel);
      Line, Column : Positive;
   begin
      if W.all in Source_View_Record'Class then
         W := Get_Parent (W);
         while W.all not in Source_Box_Record'Class loop
            W := Get_Parent (W);
         end loop;
         Box := Source_Box (W).Editor;

         case Special is
            when 'l' =>
               Get_Cursor_Location (Box, Line, Column);
               return Expansion & Image (Line);

            when 'c' =>
               Get_Cursor_Location (Box, Line, Column);
               return Expansion & Image (Column);

            when 'f' =>
               return Expansion & Base_Name (Get_Filename (Box));

            when 'd' =>
               return Expansion & Dir_Name (Get_Filename (Box)).all;

            when 'p' =>
               return Expansion & Project_Name
                 (Get_Project_From_File
                  (Get_Registry (Kernel),
                   Get_Filename (Box),
                   Root_If_Not_Found => True));

            when 'P' =>
               return Expansion & Project_Path
                 (Get_Project_From_File
                  (Get_Registry (Kernel),
                   Get_Filename (Box),
                   Root_If_Not_Found => True));

            when others =>
               return Invalid_Expansion;
         end case;

      else
         return Invalid_Expansion;
      end if;
   end Expand_Aliases_Entities;

   ---------------------
   -- Register_Module --
   ---------------------

   procedure Register_Module
     (Kernel : access Glide_Kernel.Kernel_Handle_Record'Class)
   is
      File             : constant String := '/' & (-"File") & '/';
      Save             : constant String := File & (-"Save...") & '/';
      Edit             : constant String := '/' & (-"Edit") & '/';
      Navigate         : constant String := '/' & (-"Navigate") & '/';
      Mitem            : Gtk_Menu_Item;
      Button           : Gtk_Button;
      Toolbar          : constant Gtk_Toolbar := Get_Toolbar (Kernel);
      Undo_Redo        : Undo_Redo_Information;
      Selector         : Scope_Selector;
      Extra            : Files_Extra_Scope;
      Recent_Menu_Item : Gtk_Menu_Item;
      Command          : Interactive_Command_Access;

      Src_Action_Context  : constant Action_Context :=
        new Src_Editor_Action_Context;
      --  Memory is never freed, but this is needed for the whole life of
      --  the application

   begin
      Src_Editor_Module_Id := new Source_Editor_Module_Record;
      Source_Editor_Module (Src_Editor_Module_Id).Kernel :=
        Kernel_Handle (Kernel);

      Register_Context (Kernel, Src_Action_Context);

      Command := new Indentation_Command;
      Indentation_Command (Command.all).Kernel := Kernel_Handle (Kernel);
      Register_Action
        (Kernel, "Indent current line",
         Command, -"Auto-indent the current line or block of lines",
         Src_Action_Context);
      Bind_Default_Key
        (Handler     => Get_Key_Handler (Kernel),
         Action      => "Indent current line",
         Default_Key => "control-Tab");

      Command := new Completion_Command;
      Completion_Command (Command.all).Kernel := Kernel_Handle (Kernel);
      Register_Action
        (Kernel, "Complete identifier", Command,
         -("Completion the current identifier based on the"
           & " contents of the editor"),
         Src_Action_Context);
      Bind_Default_Key
        (Handler     => Get_Key_Handler (Kernel),
         Action      => "Complete identifier",
         Default_Key => "control-slash");

      Command := new Jump_To_Delimiter_Command;
      Jump_To_Delimiter_Command (Command.all).Kernel :=
        Kernel_Handle (Kernel);
      Register_Action
        (Kernel, "Jump to matching delimiter", Command,
         -"Jump to the matching delimiter ()[]{}",
         Src_Action_Context);
      Bind_Default_Key
        (Handler     => Get_Key_Handler (Kernel),
         Action      => "Jump to matching delimiter",
         Default_Key => "control-apostrophe");

      Command := new Move_Command;
      Move_Command (Command.all).Kernel := Kernel_Handle (Kernel);
      Move_Command (Command.all).Kind := Word;
      Move_Command (Command.all).Step := 1;
      Register_Action
        (Kernel, "Move to next word", Command,
           -"Move to the next word in the current source editor",
         Src_Action_Context);

      Command := new Move_Command;
      Move_Command (Command.all).Kernel := Kernel_Handle (Kernel);
      Move_Command (Command.all).Kind := Word;
      Move_Command (Command.all).Step := -1;
      Register_Action
        (Kernel, "Move to previous word", Command,
           -"Move to the previous word in the current source editor",
         Src_Action_Context);

      Command := new Move_Command;
      Move_Command (Command.all).Kernel := Kernel_Handle (Kernel);
      Move_Command (Command.all).Kind := Paragraph;
      Move_Command (Command.all).Step := -1;
      Register_Action
        (Kernel, "Move to previous sentence", Command,
           -"Move to the previous sentence in the current source editor",
         Src_Action_Context);

      Command := new Move_Command;
      Move_Command (Command.all).Kernel := Kernel_Handle (Kernel);
      Move_Command (Command.all).Kind := Paragraph;
      Move_Command (Command.all).Step := 1;
      Register_Action
        (Kernel, "Move to next sentence", Command,
           -"Move to the next sentence in the current source editor",
         Src_Action_Context);

      Command := new Scroll_Command;
      Scroll_Command (Command.all).Kernel := Kernel_Handle (Kernel);
      Register_Action
        (Kernel, "Center cursor on screen", Command,
           -"Scroll the current source editor so that the cursor is centerd",
         Src_Action_Context);

      Command := new Delete_Command;
      Delete_Command (Command.all).Kernel := Kernel_Handle (Kernel);
      Delete_Command (Command.all).Kind := Word;
      Delete_Command (Command.all).Count := 1;
      Register_Action
        (Kernel, "Delete word forward", Command,
           -"Delete the word following the current cursor position",
         Src_Action_Context);

      Command := new Delete_Command;
      Delete_Command (Command.all).Kernel := Kernel_Handle (Kernel);
      Delete_Command (Command.all).Kind := Word;
      Delete_Command (Command.all).Count := -1;
      Register_Action
        (Kernel, "Delete word backward", Command,
           -"Delete the word preceding the current cursor position",
         Src_Action_Context);

      Register_Module
        (Module                  => Src_Editor_Module_Id,
         Kernel                  => Kernel,
         Module_Name             => Src_Editor_Module_Name,
         Priority                => Default_Priority,
         Contextual_Menu_Handler => Source_Editor_Contextual'Access,
         Mime_Handler            => Mime_Action'Access,
         Default_Context_Factory => Default_Factory'Access,
         Save_Function           => Save_Function'Access);
      Glide_Kernel.Kernel_Desktop.Register_Desktop_Functions
        (Save_Desktop'Access, Load_Desktop'Access);

      --  Menus

      Register_Menu (Kernel, File, -"_Open...",  Stock_Open,
                     On_Open_File'Access, null,
                     GDK_F3, Ref_Item => -"Save...");
      Register_Menu (Kernel, File, -"Open _From Project...",  Stock_Open,
                     On_Open_From_Path'Access, null,
                     GDK_F3, Shift_Mask, Ref_Item => -"Save...");

      Recent_Menu_Item :=
        Register_Menu (Kernel, File, -"_Recent", "", null,
                       Ref_Item   => -"Open From Project...",
                       Add_Before => False);
      Associate (Get_History (Kernel).all,
                 Hist_Key,
                 Recent_Menu_Item,
                 new On_Recent'(Menu_Callback_Record with
                                Kernel => Kernel_Handle (Kernel)));

      Register_Menu (Kernel, File, -"_New", Stock_New, On_New_File'Access,
                     Ref_Item => -"Open...");
      Register_Menu (Kernel, File, -"New _View", "", On_New_View'Access,
                     Ref_Item => -"Open...");

      Register_Menu (Kernel, File, -"_Save", Stock_Save,
                     On_Save'Access, null,
                     GDK_S, Control_Mask, Ref_Item => -"Save...");
      Register_Menu (Kernel, File, -"Save _As...", Stock_Save_As,
                     On_Save_As'Access, Ref_Item => -"Save...");
      Register_Menu (Kernel, Save, -"_All", "",
                     On_Save_All'Access, Ref_Item => -"Desktop");

      Register_Menu (Kernel, File, -"_Print", Stock_Print, On_Print'Access,
                     Ref_Item => -"Exit");
      Gtk_New (Mitem);
      Register_Menu (Kernel, File, Mitem, Ref_Item => -"Exit");

      --  Note: callbacks for the Undo/Redo menu items will be added later
      --  by each source editor.

      Undo_Redo.Undo_Menu_Item :=
        Register_Menu (Kernel, Edit, -"_Undo", Stock_Undo,
                       null, null,
                       GDK_Z, Control_Mask, Ref_Item => -"Preferences",
                       Sensitive => False);
      Undo_Redo.Redo_Menu_Item :=
        Register_Menu (Kernel, Edit, -"_Redo", Stock_Redo,
                       null, null,
                       GDK_R, Control_Mask, Ref_Item => -"Preferences",
                       Sensitive => False);

      Gtk_New (Mitem);
      Register_Menu
        (Kernel, Edit, Mitem, Ref_Item => "Redo", Add_Before => False);

      Insert_Space (Toolbar, Position => 3);
      Undo_Redo.Undo_Button := Insert_Stock
        (Toolbar, Stock_Undo, -"Undo Previous Action", Position => 4);
      Set_Sensitive (Undo_Redo.Undo_Button, False);
      Undo_Redo.Redo_Button := Insert_Stock
        (Toolbar, Stock_Redo, -"Redo Previous Action", Position => 5);
      Set_Sensitive (Undo_Redo.Redo_Button, False);

      Append_Space (Toolbar);

      Command := new Clipboard_Command;
      Clipboard_Command (Command.all).Kernel := Kernel_Handle (Kernel);
      Clipboard_Command (Command.all).Kind   := Cut;
      Register_Action
        (Kernel, -"Cut to Clipboard", Command,
         -"Cut the current selection to the clipboard",
         Src_Action_Context);
      Register_Menu (Kernel, Edit, -"_Cut",  Stock_Cut,
                     null, Command_Access (Command),
                     GDK_Delete, Shift_Mask,
                     Ref_Item => -"Preferences");
      Register_Button
        (Kernel, Stock_Cut, Command_Access (Command), -"Cut To Clipboard");

      Command := new Clipboard_Command;
      Clipboard_Command (Command.all).Kernel := Kernel_Handle (Kernel);
      Clipboard_Command (Command.all).Kind   := Copy;
      Register_Action
        (Kernel, -"Copy to Clipboard", Command,
         -"Copy the current selection to the clipboard",
         Src_Action_Context);
      Register_Menu (Kernel, Edit, -"C_opy",  Stock_Copy,
                     null, Command_Access (Command),
                     GDK_Insert, Control_Mask,
                     Ref_Item => -"Preferences");
      Register_Button
        (Kernel, Stock_Copy, Command_Access (Command), -"Copy To Clipboard");

      Command := new Clipboard_Command;
      Clipboard_Command (Command.all).Kernel := Kernel_Handle (Kernel);
      Clipboard_Command (Command.all).Kind   := Paste;
      Register_Action
        (Kernel, -"Paste From Clipboard", Command,
         -"Paste the contents of the clipboard into the current editor",
         Src_Action_Context);
      Register_Menu (Kernel, Edit, -"P_aste",  Stock_Paste,
                     null, Command_Access (Command),
                     GDK_Insert, Shift_Mask,
                     Ref_Item => -"Preferences");
      Register_Button
        (Kernel, Stock_Paste, Command_Access (Command),
         -"Paste From Clipboard");

      --  ??? This should be bound to Ctrl-A, except this would interfer with
      --  Emacs keybindings for people who want to use them.
      Register_Menu (Kernel, Edit, -"_Select All",  "",
                     On_Select_All'Access, Ref_Item => -"Preferences");

      Gtk_New (Mitem);
      Register_Menu (Kernel, Edit, Mitem, Ref_Item => -"Preferences");

      Register_Menu (Kernel, Edit, -"Comment _Lines", "",
                     On_Comment_Lines'Access, null,
                     GDK_minus, Control_Mask, Ref_Item => -"Preferences");
      Register_Menu (Kernel, Edit, -"Uncomment L_ines", "",
                     On_Uncomment_Lines'Access, null,
                     GDK_underscore, Control_Mask, Ref_Item => -"Preferences");

      Gtk_New (Mitem);
      Register_Menu (Kernel, Edit, Mitem, Ref_Item => -"Preferences");

      Register_Menu (Kernel, Edit, -"Fold all blocks", "",
                     On_Fold_Blocks'Access, null,
                     0, 0, Ref_Item => -"Preferences");
      Register_Menu (Kernel, Edit, -"Unfold all blocks", "",
                     On_Unfold_Blocks'Access, null,
                     0, 0, Ref_Item => -"Preferences");

      Gtk_New (Mitem);
      Register_Menu (Kernel, Edit, Mitem, Ref_Item => -"Preferences");

      Register_Menu (Kernel, Edit, -"_Generate Body", "",
                     On_Generate_Body'Access, Ref_Item => -"Preferences");
      Register_Menu (Kernel, Edit, -"P_retty Print", "",
                     On_Pretty_Print'Access, Ref_Item => -"Preferences");

      Register_Menu (Kernel, Navigate, -"Goto _Line...", Stock_Jump_To,
                     On_Goto_Line_Current_Editor'Access, null,
                     GDK_G, Control_Mask,
                     Ref_Item => -"Goto File Spec<->Body");
      Register_Menu (Kernel, Navigate, -"Goto _Declaration", Stock_Home,
                     On_Goto_Declaration'Access, Ref_Item => -"Goto Line...");
      Register_Menu (Kernel, Navigate, -"Goto _Body", "",
                     On_Goto_Body'Access, Ref_Item => -"Goto Line...");

      --  Toolbar buttons

      Button := Insert_Stock
        (Toolbar, Stock_New, -"Create a New File", Position => 0);
      Kernel_Callback.Connect
        (Button, "clicked",
         Kernel_Callback.To_Marshaller (On_New_File'Access),
         Kernel_Handle (Kernel));

      Button := Insert_Stock
        (Toolbar, Stock_Open, -"Open a File", Position => 1);
      Kernel_Callback.Connect
        (Button, "clicked",
         Kernel_Callback.To_Marshaller (On_Open_File'Access),
         Kernel_Handle (Kernel));

      Button := Insert_Stock
        (Toolbar, Stock_Save, -"Save Current File", Position => 2);
      Kernel_Callback.Connect
        (Button, "clicked",
         Kernel_Callback.To_Marshaller (On_Save'Access),
         Kernel_Handle (Kernel));

      Kernel_Callback.Connect
        (Kernel, File_Saved_Signal,
         File_Saved_Cb'Access,
         Kernel_Handle (Kernel));

      Undo_Redo_Data.Set (Kernel, Undo_Redo, Undo_Redo_Id);

      Preferences_Changed (Kernel, Kernel_Handle (Kernel));

      Kernel_Callback.Connect
        (Kernel, Preferences_Changed_Signal,
         Kernel_Callback.To_Marshaller (Preferences_Changed'Access),
         User_Data   => Kernel_Handle (Kernel));

      Source_Editor_Module (Src_Editor_Module_Id).File_Closed_Id :=
        Kernel_Callback.Connect
          (Kernel,
           File_Closed_Signal,
           File_Closed_Cb'Access,
           Kernel_Handle (Kernel));

      Kernel_Callback.Connect
        (Kernel,
         File_Changed_On_Disk_Signal,
         File_Changed_On_Disk_Cb'Access,
         Kernel_Handle (Kernel));

      Source_Editor_Module (Src_Editor_Module_Id).File_Edited_Id :=
        Kernel_Callback.Connect
          (Kernel,
           File_Edited_Signal,
           File_Edited_Cb'Access,
           Kernel_Handle (Kernel));

      --  Commands

      Register_Command
        (Kernel,
         Command      => "edit",
         Params       => Parameter_Names_To_Usage (Edit_Cmd_Parameters, 3),
         Description  => -"Open a file editor for file_name." & ASCII.LF
           & (-"Length is the number of characters to select after the"
              & " cursor. If line and column are set to 0 (the default),"
              & " then the location of the cursor is not changed if the file"
              & " is already opened in an editor."),
         Minimum_Args => 1,
         Maximum_Args => 4,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "create_mark",
         Params       => Parameter_Names_To_Usage (Edit_Cmd_Parameters, 3),
         Return_Value => "identifier",
         Description  =>
           -("Create a mark for file_name, at position given by line and"
             & " column. Length corresponds to the text length to highlight"
             & " after the mark. The identifier of the mark is returned."
             & " Use the command goto_mark to jump to this mark."),
         Minimum_Args => 1,
         Maximum_Args => 4,
         Handler => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "highlight",
         Params       => "(file, category, [line=0])",
         Description  =>
           -("Marks a line as belonging to a highlighting category."
             & " If line is not specified, mark all lines in file."),

         Minimum_Args => 2,
         Maximum_Args => 3,
         Handler      => Line_Highlighting.Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "add_blank_lines",
         Params       => "(file, start_line, number_of_lines, [category])",
         Return_Value => "string",
         Description  =>
           -("Adds number_of_lines non-editable lines to the buffer editing"
             & " file, starting at line start_line."
             & " If category is specified, use it for highlighting."
             & " Create a mark at beginning of block and return its ID."),
         Minimum_Args => 3,
         Maximum_Args => 4,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "remove_blank_lines",
         Params       => "(mark, [number])",
         Return_Value => "string",
         Description  =>
           -("Remove blank lines located at mark."
             & " If number is specified, remove only the n first lines"),
         Minimum_Args => 1,
         Maximum_Args => 2,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "unhighlight",
         Params       => "(file, category, [line=0])",
         Description  =>
           -("Unmarks the line for the specified category."
             & " If line is not specified, unmark all lines in file."),
         Minimum_Args => 2,
         Maximum_Args => 3,
         Handler      => Line_Highlighting.Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "highlight_range",
         Params       =>
           "(file, category, [line, [start_column, [end_column]]])",
         Description  =>
           -("Highlights a portion of a line in a file with the given"
             & " category."),
         Minimum_Args => 2,
         Maximum_Args => 5,
         Handler      => Line_Highlighting.Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "unhighlight_range",
         Params       =>
           "(file, category, [line, [start_column, [end_column]]])",
         Description  =>
           -("Remove highlights for a portion of a line in a file."),
         Minimum_Args => 2,
         Maximum_Args => 5,
         Handler      => Line_Highlighting.Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "register_highlighting",
         Params       => "(category, color)",
         Description  =>
           -("Create a new highlighting category with the given color. The"
             & " format for color is ""#RRGGBB""."),
         Minimum_Args => 2,
         Maximum_Args => 2,
         Handler      => Line_Highlighting.Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "goto_mark",
         Params       => "(identifier)",
         Description  =>
           -"Jump to the location of the mark corresponding to identifier.",
         Minimum_Args => 1,
         Maximum_Args => 1,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "delete_mark",
         Params       => "(identifier)",
         Description  =>
           -"Delete the mark corresponding to identifier.",
         Minimum_Args => 1,
         Maximum_Args => 1,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "get_chars",
         Params       => "(file, line, column, [before=-1], [after=-1])",
         Return_Value => "string",
         Description  =>
           -("Get the characters around a certain position."
             & " Returns string between <before> characters before the mark"
             & " and <after> characters after the position. If <before> or"
             & " <after> is omitted, the bounds will be at the beginning and"
             & "/or the end of the line."),
         Minimum_Args => 3,
         Maximum_Args => 5,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "get_line",
         Params       => "(mark)",
         Return_Value => "integer",
         Description  => -"Returns the current line of mark.",
         Minimum_Args => 1,
         Maximum_Args => 1,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "get_column",
         Params       => "(mark)",
         Return_Value => "integer",
         Description  => -"Returns the current column of mark.",
         Minimum_Args => 1,
         Maximum_Args => 1,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "get_file",
         Params       => "(mark)",
         Return_Value => "string",
         Description  => -"Returns the current file of mark.",
         Minimum_Args => 1,
         Maximum_Args => 1,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "get_last_line",
         Params       => "(file)",
         Return_Value => "integer",
         Description  => -"Returns the number of the last line in file.",
         Minimum_Args => 1,
         Maximum_Args => 1,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "block_get_start",
         Params       => "(file, line)",
         Return_Value => "integer",
         Description  =>
           -"Returns starting line number for block enclosing line.",
         Minimum_Args => 2,
         Maximum_Args => 2,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "block_get_end",
         Params       => "(file, line)",
         Return_Value => "integer",
         Description  =>
           -"Returns ending line number for block enclosing line.",
         Minimum_Args => 2,
         Maximum_Args => 2,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "block_get_type",
         Params       => "(file, line)",
         Return_Value => "string",
         Description  =>
           -"Returns type for block enclosing line.",
         Minimum_Args => 2,
         Maximum_Args => 2,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "block_get_level",
         Params       => "(file, line)",
         Return_Value => "integer",
         Description  =>
           -"Returns nested level for block enclosing line.",
         Minimum_Args => 2,
         Maximum_Args => 2,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "cursor_get_line",
         Params       => "(file)",
         Return_Value => "integer",
         Description  =>
           -"Returns current cursor line number.",
         Minimum_Args => 1,
         Maximum_Args => 1,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "cursor_get_column",
         Params       => "(file)",
         Return_Value => "integer",
         Description  =>
           -"Returns current cursor column number.",
         Minimum_Args => 1,
         Maximum_Args => 1,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "cursor_set_position",
         Params       => "(file, line, [column])",
         Description  =>
           -("Set cursor to position line/column in buffer file. Default "
             & " column, if not specified, is 1."),
         Minimum_Args => 2,
         Maximum_Args => 3,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "get_buffer",
         Params       => "(file)",
         Return_Value => "string",
         Description  =>
           -"Returns the text contained in the current buffer for file.",
         Minimum_Args => 1,
         Maximum_Args => 1,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "replace_text",
         Params       => "(file, line, column, text, [before=-1], [after=-1])",
         Description  =>
           -("Replace the characters around a certain position."
             & " <before> characters before (line, column), and up to <after>"
             & " characters after are removed, and the new text is inserted"
             & " instead. If <before> or <after> is omitted, the bounds will"
             & " be at the beginning and/or the end of the line."),
         Minimum_Args => 4,
         Maximum_Args => 6,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "undo",
         Params       => "(file)",
         Description  => -"Undo the last edition command for file.",
         Minimum_Args => 1,
         Maximum_Args => 1,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "redo",
         Params       => "(file)",
         Description  => -"Redo the last edition command for file.",
         Minimum_Args => 1,
         Maximum_Args => 1,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "close",
         Params       => "(file)",
         Description  => -"Close all file editors for file_name.",
         Minimum_Args => 1,
         Maximum_Args => 1,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "save",
         Params       => "(interactive=true, all=true)",
         Description  => -("Save current or all files."
           & " If interactive is true, then prompt before each save."
           & " If all is true, then all files are saved"),
         Minimum_Args => 0,
         Maximum_Args => 2,
         Handler      => Edit_Command_Handler'Access);

      Register_Command
        (Kernel,
         Command      => "search",
         Params       =>
           Parameter_Names_To_Usage (File_Search_Parameters, 3),
         Return_Value => "list",
         Description  =>
           -("Return the list of matches for pattern in the file. Default"
             & " values are False for case_sensitive and regexp."
             & " Scope is a string, and should be any of 'whole', 'comments',"
             & " 'strings', 'code'. The latter will match only for text"
             & " outside of comments"),
         Minimum_Args => 1,
         Maximum_Args => 3,
         Class        => Get_File_Class (Kernel),
         Handler      => File_Search_Command_Handler'Access);
      Register_Command
        (Kernel,
         Command      => "search",
         Params       =>
           Parameter_Names_To_Usage (Project_Search_Parameters, 4),
         Return_Value => "list",
         Description  =>
           -("Return the list of matches for pattern in all the files"
             & " belonging to the project (and its imported projects if"
             & " recursive is true (default)."
             & " Scope is a string, and should be any of 'whole', 'comments',"
             & " 'strings', 'code'. The latter will match only for text"
             & " outside of comments"),
         Minimum_Args => 1,
         Maximum_Args => 4,
         Class        => Get_Project_Class (Kernel),
         Handler      => Project_Search_Command_Handler'Access);

      --  Register the search functions

      Gtk_New (Selector, Kernel);
      Gtk_New (Extra, Kernel);

      declare
         Name  : constant String := -"Current File";
         Name2 : constant String := -"Files From Project";
         Name3 : constant String := -"Files...";
         Name4 : constant String := -"Open Files";

      begin
         Register_Search_Function
           (Kernel => Kernel,
            Data   =>
              (Length            => Name'Length,
               Label             => Name,
               Factory           => Current_File_Factory'Access,
               Extra_Information => Gtk_Widget (Selector),
               Id                => Src_Editor_Module_Id,
               Mask              => All_Options));
         Register_Search_Function
           (Kernel => Kernel,
            Data   =>
              (Length            => Name2'Length,
               Label             => Name2,
               Factory           => Files_From_Project_Factory'Access,
               Extra_Information => Gtk_Widget (Selector),
               Id                => null,
               Mask              => All_Options and not Search_Backward));
         Register_Search_Function
           (Kernel => Kernel,
            Data   =>
              (Length            => Name3'Length,
               Label             => Name3,
               Factory           => Files_Factory'Access,
               Extra_Information => Gtk_Widget (Extra),
               Id                => null,
               Mask              => All_Options and not Search_Backward));
         Register_Search_Function
           (Kernel => Kernel,
            Data   =>
              (Length            => Name4'Length,
               Label             => Name4,
               Factory           => Open_Files_Factory'Access,
               Extra_Information => Gtk_Widget (Selector),
               Id                => null,
               Mask              => All_Options and not Search_Backward));
      end;

      --  Register the aliases special entities

      Register_Special_Alias_Entity
        (Kernel, -"Current line",   'l', Expand_Aliases_Entities'Access);
      Register_Special_Alias_Entity
        (Kernel, -"Current column", 'c', Expand_Aliases_Entities'Access);
      Register_Special_Alias_Entity
        (Kernel, -"Current file",   'f', Expand_Aliases_Entities'Access);
      Register_Special_Alias_Entity
        (Kernel, -"Project for the current file", 'p',
         Expand_Aliases_Entities'Access);
      Register_Special_Alias_Entity
        (Kernel, -"Full path of project for the current file", 'P',
         Expand_Aliases_Entities'Access);
      Register_Special_Alias_Entity
        (Kernel, -"Directory of current file", 'd',
         Expand_Aliases_Entities'Access);

      --  Create the module-wide GCs.
      --  We need to do that in a callback to "map"

      if not Mapped_Is_Set (Get_Main_Window (Kernel)) then
         Widget_Callback.Connect
           (Get_Main_Window (Kernel), "map",
            Marsh => Widget_Callback.To_Marshaller (Map_Cb'Access),
            After => True);

      else
         Map_Cb (Get_Main_Window (Kernel));
      end if;

      Remove_Blank_Lines_Pixbuf := Gdk_New_From_Xpm_Data (close_block_xpm);
      Hide_Block_Pixbuf   := Gdk_New_From_Xpm_Data (fold_block_xpm);
      Unhide_Block_Pixbuf := Gdk_New_From_Xpm_Data (unfold_block_xpm);
   end Register_Module;

   -------------------------
   -- Preferences_Changed --
   -------------------------

   procedure Preferences_Changed
     (K : access GObject_Record'Class; Kernel : Kernel_Handle)
   is
      pragma Unreferenced (K);
      Id                        : Source_Editor_Module :=
        Source_Editor_Module (Src_Editor_Module_Id);
      Pref_Display_Line_Numbers : constant Boolean :=
        Get_Pref (Kernel, Display_Line_Numbers);

   begin
      if Pref_Display_Line_Numbers = Id.Display_Line_Numbers then
         return;
      end if;

      Id.Display_Line_Numbers := Pref_Display_Line_Numbers;

      --  Connect necessary signal to display line numbers.
      if Pref_Display_Line_Numbers then
         if Id.Source_Lines_Revealed_Id = No_Handler then
            Id.Source_Lines_Revealed_Id :=
              Kernel_Callback.Connect
                (Kernel,
                 Source_Lines_Revealed_Signal,
                 On_Lines_Revealed'Access,
                 Kernel);

            declare
               Files : VFS.File_Array := Open_Files (Kernel);
            begin
               for Node in Files'Range loop
                  Create_Line_Information_Column
                    (Kernel,
                     Files (Node),
                     Src_Editor_Module_Name,
                     Stick_To_Data => False,
                     Every_Line    => True);
               end loop;
            end;
         end if;

      elsif Id.Source_Lines_Revealed_Id /= No_Handler then
         Gtk.Handlers.Disconnect
           (Kernel, Id.Source_Lines_Revealed_Id);
         Id.Source_Lines_Revealed_Id := No_Handler;

         Remove_Line_Information_Column
           (Kernel, VFS.No_File, Src_Editor_Module_Name);
      end if;
   end Preferences_Changed;

   -------------
   -- Destroy --
   -------------

   procedure Destroy (Id : in out Source_Editor_Module_Record) is
   begin
      String_List_Utils.String_List.Free (Id.Unopened_Files);
      Mark_Identifier_List.Free (Id.Stored_Marks);

      Unref (Id.Post_It_Note_GC);
      Unref (Id.Blank_Lines_GC);

      --  Destroy graphics
      Unref (Remove_Blank_Lines_Pixbuf);
      Unref (Hide_Block_Pixbuf);
      Unref (Unhide_Block_Pixbuf);
   end Destroy;

   -----------------
   -- Find_Editor --
   -----------------

   function Find_Editor
     (Kernel : access Glide_Kernel.Kernel_Handle_Record'Class;
      File   : VFS.Virtual_File) return Gtkada.MDI.MDI_Child
   is
      Iter  : Child_Iterator := First_Child (Get_MDI (Kernel));
      Child : MDI_Child;
      Full  : VFS.Virtual_File;

   begin
      if File = VFS.No_File then
         return null;
      end if;

      if Is_Absolute_Path (File) then
         Full := File;
      else
         Full := Create
           (Get_Full_Path_From_File
              (Get_Registry (Kernel), Full_Name (File).all, True, False));
      end if;

      loop
         Child := Get (Iter);

         exit when Child = null
           or else Get_Filename (Child) = Full

            --  Handling of file identifiers
           or else Get_Title (Child) = Full_Name (File).all;

         Next (Iter);
      end loop;

      return Child;
   end Find_Editor;

   -----------------------
   -- Find_Other_Editor --
   -----------------------

   function Find_Other_Editor
     (Kernel : access Glide_Kernel.Kernel_Handle_Record'Class;
      View   : Gtk_Text_View;
      Buffer : Gtk_Text_Buffer) return Src_Editor_Box.Source_Editor_Box
   is
      Iter   : Child_Iterator := First_Child (Get_MDI (Kernel));
      Editor : Src_Editor_Box.Source_Editor_Box;
      Child  : MDI_Child;
      Source : Source_Buffer;
   begin
      Child := Get (Iter);

      while Child /= null loop
         if Get_Widget (Child).all in Source_Box_Record'Class then
            Editor := Source_Box (Get_Widget (Child)).Editor;

            Source := Get_Buffer (Editor);

            if Gtk_Text_Buffer (Source) = Buffer
              and then Gtk_Text_View (Get_View (Editor)) /= View
            then
               return Editor;
            end if;
         end if;

         Next (Iter);
         Child := Get (Iter);
      end loop;

      return null;
   end Find_Other_Editor;

   ----------------
   -- Find_Child --
   ----------------

   function Find_Child
     (Kernel : access Glide_Kernel.Kernel_Handle_Record'Class;
      Editor : access Src_Editor_Box.Source_Editor_Box_Record'Class)
      return Gtkada.MDI.MDI_Child
   is
      Iter  : Child_Iterator := First_Child (Get_MDI (Kernel));
      Child : MDI_Child;

   begin
      loop
         Child := Get (Iter);

         exit when Child = null
           or else (Get_Widget (Child).all in Source_Box_Record'Class
                    and then Source_Box (Get_Widget (Child)).Editor =
                      Source_Editor_Box (Editor));
         Next (Iter);
      end loop;

      return Child;
   end Find_Child;

end Src_Editor_Module;
