-----------------------------------------------------------------------
--                   GVD - The GNU Visual Debugger                   --
--                                                                   --
--                      Copyright (C) 2000-2001                      --
--                              ACT-Europe                           --
--                                                                   --
-- GVD is free  software;  you can redistribute it and/or modify  it --
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

--  This package implements a text area target for the display of source
--  code.
--  It knows how to highlight keywords, strings and commands, and how
--  to display icons at the beginning of each line where a given function
--  returns True.
--  It also provides a source explorer that can quickly display and jump
--  in the various entities in the file (e.g procedures, types, ...).
--
--  Caches
--  =======
--
--  Some data is expensive to recompute for each file (e.g the list of lines
--  that contain code). We have thus implemented a system of caches so that
--  we don't need to recompute this data every time the file is reloaded.
--  This information is also computed in a lazy fashion, ie while nothing
--  else is happening in the application.

with Glib;
with Gdk.Color;
with Gtk.Menu;
with Gtk.Paned;
with Gtk.Scrolled_Window;
with Gtk.Widget;
with Gtk.Box;
with Gtkada.Types;
with Language;
with GVD.Explorer;
with GVD.Text_Box.Asm_Editor;
with GVD.Text_Box.Source_Editor;
with GVD.Types;
with Basic_Types;

package GVD.Code_Editors is

   type Code_Editor_Record is new Gtk.Box.Gtk_Hbox_Record with private;
   type Code_Editor is access all Code_Editor_Record'Class;

   type View_Mode is (Source, Asm, Source_Asm);
   --  Describe what kind of source GVD should display.

   procedure Gtk_New_Hbox
     (Editor      : out Code_Editor;
      Process     : access Gtk.Widget.Gtk_Widget_Record'Class);
   --  Create a new editor window.
   --  The name and the parameters are chosen so that this type is compatible
   --  with the code generated by Gate for a Gtk_Box.

   procedure Initialize
     (Editor      : access Code_Editor_Record'Class;
      Process     : access Gtk.Widget.Gtk_Widget_Record'Class);
   --  Internal procedure.

   procedure Apply_Mode
     (Editor : access Code_Editor_Record; Mode : View_Mode);
   --  Apply mode changes to the editor.

   procedure Show_Message
     (Editor      : access Code_Editor_Record;
      Message     : String);
   --  Display a message in the editor window.

   procedure Load_File
     (Editor      : access Code_Editor_Record;
      File_Name   : String;
      Set_Current : Boolean := True;
      Force       : Boolean := False);
   --  Load and append a file in the editor.
   --  If Set_Current is True, then File_Name becomes the current file for the
   --  debugger (ie the one that contains the current execution line).
   --  If the file is already displayed, nothing is done unless Force is True.

   procedure Set_Line
     (Editor      : access Code_Editor_Record;
      Line        : Natural;
      Set_Current : Boolean := True);
   --  Set the current line (and draw the button on the side).
   --  If Set_Current is True, then the line becomes the current line (ie the
   --  one on which the debugger is stopped). Otherwise, Line is simply the
   --  line that we want to display in the editor.

   procedure Set_Address
     (Editor : access Code_Editor_Record;
      Pc     : String);
   --  Set the address the debugger is currently stopped at.

   procedure Update_Breakpoints
     (Editor    : access Code_Editor_Record;
      Br        : GVD.Types.Breakpoint_Array);
   --  Change the list of breakpoints to highlight in the editor (source and
   --  assembly editors).
   --  All the breakpoints that previously existed are removed from the screen,
   --  and replaced by the new ones.
   --  The breakpoints that do not apply to the current file are ignored.

   procedure Configure
     (Editor            : access Code_Editor_Record;
      Source            : GVD.Text_Box.Source_Editor.Source_Editor;
      Ps_Font_Name      : String;
      Font_Size         : Glib.Gint;
      Current_Line_Icon : Gtkada.Types.Chars_Ptr_Array;
      Stop_Icon         : Gtkada.Types.Chars_Ptr_Array;
      Strings_Color     : Gdk.Color.Gdk_Color;
      Keywords_Color    : Gdk.Color.Gdk_Color);
   --  Set the various settings of an editor.
   --  Source is the source editor associated with Editor.
   --  Ps_Font_Name is the name of the postscript font that will be used to
   --  display the text. It should be a fixed-width font, which is nice for
   --  source code.
   --  Default_Icon is used for the icon that can be displayed on the left of
   --  each line.
   --  Current_Line_Icon is displayed on the left of the line currently
   --  "active" (using the procedure Set_Line below).

   function Get_Line (Editor : access Code_Editor_Record) return Natural;
   --  Return the current line.

   function Get_Mode (Editor : access Code_Editor_Record) return View_Mode;
   --  Return the current view mode of Editor.

   function Get_Process
     (Editor : access Code_Editor_Record'Class) return Gtk.Widget.Gtk_Widget;
   --  Return the process tab in which the editor is inserted.

   function Get_Source
     (Editor : access Code_Editor_Record'Class)
      return GVD.Text_Box.Source_Editor.Source_Editor;
   --  Return the widget used to display the source code

   function Get_Explorer_Scroll
     (Editor : access Code_Editor_Record'Class)
      return Gtk.Scrolled_Window.Gtk_Scrolled_Window;
   --  Return the window containing the Explorer.

   function Get_Explorer
     (Editor : access Code_Editor_Record'Class)
      return GVD.Explorer.Explorer_Access;
   --  Return the explorer associated with Editor.

   function Get_Asm
     (Editor : access Code_Editor_Record'Class)
      return GVD.Text_Box.Asm_Editor.Asm_Editor;
   --  Return the widget used to display the asm code

   function Get_Current_File
     (Editor : access Code_Editor_Record) return String;
   --  Return the name of the currently edited file.
   --  "" is returned if there is no current file.

   procedure Display_Selection (Editor : access Code_Editor_Record);
   --  Adjust the vertical position of the scrolled window
   --  so that the current selection is visible.

   procedure Set_Current_Language
     (Editor : access Code_Editor_Record;
      Lang   : Language.Language_Access);
   --  Change the current language for the source editor.
   --  The text already present in the editor is not re-highlighted for the
   --  new language, this only influences future addition to the editor.
   --
   --  If Lang is null, then no color highlighting will be performed.

   procedure Append_To_Contextual_Menu
     (Editor : access Code_Editor_Record;
      Menu   : access Gtk.Menu.Gtk_Menu_Record'Class);
   --  Append some general items to the contextual Menu.
   --  These items do not depend on whether the source code or the assembly
   --  code is currently displayed, and are not specific to either.

   procedure On_Executable_Changed
     (Editor : access Gtk.Widget.Gtk_Widget_Record'Class);
   --  Called when the executable associated with the editor has changed.

   procedure Preferences_Changed
     (Editor : access Gtk.Widget.Gtk_Widget_Record'Class);
   --  Called when the preferences have changed, and the editor should be
   --  redisplayed with the new setup.

   function Get_Window_Size
     (Editor : access Code_Editor_Record'Class) return Glib.Gint;
   --  Return the size of the Asm/source text window.

private

   type Code_Editor_Record is new Gtk.Box.Gtk_Hbox_Record with record
      Source           : GVD.Text_Box.Source_Editor.Source_Editor;
      Asm              : GVD.Text_Box.Asm_Editor.Asm_Editor;
      Source_Asm_Pane  : Gtk.Paned.Gtk_Paned;

      Mode             : View_Mode := GVD.Code_Editors.Source;

      Source_Line      : Natural;
      Asm_Address      : Basic_Types.String_Access;

      Process          : Gtk.Widget.Gtk_Widget;
      --  The process tab in which the editor is found.

      Explorer        : GVD.Explorer.Explorer_Access;
      Explorer_Scroll : Gtk.Scrolled_Window.Gtk_Scrolled_Window;
   end record;

end GVD.Code_Editors;
