------------------------------------------------------------------------------
--                                  G P S                                   --
--                                                                          --
--                     Copyright (C) 2005-2016, AdaCore                     --
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

with Ada.Unchecked_Conversion;
with System;                 use System;

with Glib;                   use Glib;
with Glib.Object;            use Glib.Object;
with Glib.Main;              use Glib.Main;
with Gtk.Box;                use Gtk.Box;
with Gtk.Enums;              use Gtk.Enums;
with Gtk.Menu;               use Gtk.Menu;
with Gtk.Text_View;
with Gtk.Widget;             use Gtk.Widget;
with Gtkada.Handlers;        use Gtkada.Handlers;
with Gtkada.MDI;             use Gtkada.MDI;

pragma Warnings (Off);
with GNAT.Expect.TTY;        use GNAT.Expect.TTY;
with GNAT.TTY;               use GNAT.TTY;
pragma Warnings (On);
with GNAT.Expect;            use GNAT.Expect;
with GNAT.Regpat;            use GNAT.Regpat;
with GNAT.OS_Lib;            use GNAT.OS_Lib;
with GNAT.Strings;
with GNATCOLL.Utils;         use GNATCOLL.Utils;

with Debugger;               use Debugger;
with Generic_Views;          use Generic_Views;
with GPS.Debuggers;          use GPS.Debuggers;
with GPS.Kernel.MDI;         use GPS.Kernel.MDI;
with GPS.Kernel.Modules;     use GPS.Kernel.Modules;
with GPS.Kernel.Modules.UI;  use GPS.Kernel.Modules.UI;
with GPS.Kernel.Preferences; use GPS.Kernel.Preferences;
with GPS.Intl;               use GPS.Intl;
with GVD.Generic_View;       use GVD.Generic_View;
with GVD.Process;            use GVD.Process;
with GVD.Types;              use GVD.Types;
with GVD_Module;             use GVD_Module;
with Histories;              use Histories;
with Process_Proxies;        use Process_Proxies;
with String_List_Utils;      use String_List_Utils;
with GNATCOLL.Traces;        use GNATCOLL.Traces;
with Default_Preferences;    use Default_Preferences;

package body GVD.Consoles is
   Me : constant Trace_Handle := Create ("CONSOLES");

   ANSI_Support : constant Trace_Handle :=
                   Create ("GVD.ANSI_Support", GNATCOLL.Traces.Off);

   Regexp_Any : constant Pattern_Matcher :=
     Compile (".+", Single_Line or Multiple_Lines);
   --  Any non empty string, as long as possible.

   Timeout : constant Guint := 50;
   --  Timeout between updates of the debuggee console

   type Console_Process_View_Record is abstract new Process_View_Record with
      record
         Console : Interactive_Console;
      end record;

   type Debugger_Console_Record is new Console_Process_View_Record with
      record
         Contextual_Menu : Gtk_Menu;
      end record;
   type Debugger_Console is access all Debugger_Console_Record'Class;

   type Debuggee_Console_Record is new Console_Process_View_Record with
      record
         Debuggee_TTY        : GNAT.TTY.TTY_Handle;
         Debuggee_Descriptor : GNAT.Expect.TTY.TTY_Process_Descriptor;
         Debuggee_Id         : Glib.Main.G_Source_Id := 0;
         TTY_Initialized     : Boolean := False;
         Cleanup_TTY         : Boolean := False;
      end record;
   type Debuggee_Console is access all Debuggee_Console_Record'Class;

   function Convert is new Ada.Unchecked_Conversion
     (System.Address, Debuggee_Console);
   function Convert is new Ada.Unchecked_Conversion
     (System.Address, Debugger_Console);

   package TTY_Timeout is new Glib.Main.Generic_Sources (Debuggee_Console);

   function Initialize
     (Self    : access Debugger_Console_Record'Class) return Gtk_Widget;
   function Initialize
     (Self    : access Debuggee_Console_Record'Class) return Gtk_Widget;
   --  Create each of the console types

   procedure Allocate_TTY (Console : access Debuggee_Console_Record'Class);
   procedure Close_TTY (Console : access Debuggee_Console_Record'Class);
   --  Allocate or close, if not done yet, a new tty on the console

   overriding procedure On_Attach
     (Console : access Debuggee_Console_Record;
      Process : not null access Base_Visual_Debugger'Class);
   --  Requires initialized when attaching the console to a process

   function Get_Debugger_Console
     (Process : not null access Base_Visual_Debugger'Class)
      return access Debugger_Console_Record'Class;
   function Get_Debuggee_Console
     (Process : not null access Base_Visual_Debugger'Class)
      return access Debuggee_Console_Record'Class;
   procedure Set_Debugger_Console
     (Process : not null access Base_Visual_Debugger'Class;
      Console : access Debugger_Console_Record'Class := null);
   procedure Set_Debuggee_Console
     (Process : not null access Base_Visual_Debugger'Class;
      Console : access Debuggee_Console_Record'Class := null);
   --  Get or set the consoles from the process

   package Debugger_MDI_Views is new Generic_Views.Simple_Views
     (Module_Name        => "Debugger_Console",
      View_Name          => -"Debugger Console",
      Formal_View_Record => Debugger_Console_Record,
      Formal_MDI_Child   => GPS_MDI_Child_Record,
      Reuse_If_Exist     => False,
      Commands_Category  => "",
      Areas              => Gtkada.MDI.Sides_Only,
      Group              => Group_Consoles,
      Position           => Position_Bottom,
      Initialize         => Initialize);
   package Debugger_Views is new GVD.Generic_View.Simple_Views
     (Views              => Debugger_MDI_Views,
      Formal_View_Record => Debugger_Console_Record,
      Formal_MDI_Child   => GPS_MDI_Child_Record,
      Get_View           => Get_Debugger_Console,
      Set_View           => Set_Debugger_Console);

   package Debuggee_MDI_Views is new Generic_Views.Simple_Views
     (Module_Name        => "Debugger_Execution",
      View_Name          => -"Debugger Execution",
      Formal_View_Record => Debuggee_Console_Record,
      Formal_MDI_Child   => GPS_MDI_Child_Record,
      Reuse_If_Exist     => False,
      Commands_Category  => "",
      Areas              => Gtkada.MDI.Sides_Only,
      Group              => Group_Consoles,
      Position           => Position_Bottom,
      Initialize         => Initialize);
   package Debuggee_Views is new GVD.Generic_View.Simple_Views
     (Views              => Debuggee_MDI_Views,
      Formal_View_Record => Debuggee_Console_Record,
      Formal_MDI_Child   => GPS_MDI_Child_Record,
      Get_View           => Get_Debuggee_Console,
      Set_View           => Set_Debuggee_Console);

   function Complete_Command
     (Input     : String;
      View      : access Gtk.Text_View.Gtk_Text_View_Record'Class;
      Console   : System.Address)
      return String_List_Utils.String_List.List;
   --  Return the list of completions for Input.

   procedure On_Debuggee_Destroy (Console : access Gtk_Widget_Record'Class);
   --  Callback for the "destroy" signal on the debugee console

   function TTY_Cb (Console : Debuggee_Console) return Boolean;
   --  Callback for communication with a tty.

   function Interpret_Command_Handler
     (Console    : access Interactive_Console_Record'Class;
      Input      : String;
      Debugger_C : System.Address) return String;
   --  Launch the command interpreter for Input and return the output.

   function Debuggee_Console_Handler
     (Console    : access Interactive_Console_Record'Class;
      Input      : String;
      Debuggee_C : System.Address) return String;
   --  Handler of I/O for the debuggee console.

   procedure On_Grab_Focus (Console : access Gtk_Widget_Record'Class);
   --  Callback for the "grab_focus" signal on the console.

   --------------------------------------
   -- Get_Debugger_Interactive_Console --
   --------------------------------------

   function Get_Debugger_Interactive_Console
     (Process : not null access GPS.Debuggers.Base_Visual_Debugger'Class)
      return access Interactive_Console_Record'Class
   is
      Console : constant Debugger_Console := Get_Debugger_Console (Process);
   begin
      if Console /= null then
         return Console.Console;
      else
         return null;
      end if;
   end Get_Debugger_Interactive_Console;

   --------------------------
   -- Get_Debugger_Console --
   --------------------------

   function Get_Debugger_Console
     (Process : not null access Base_Visual_Debugger'Class)
      return access Debugger_Console_Record'Class is
   begin
      return Debugger_Console (Visual_Debugger (Process).Debugger_Text);
   end Get_Debugger_Console;

   --------------------------
   -- Get_Debuggee_Console --
   --------------------------

   function Get_Debuggee_Console
     (Process : not null access Base_Visual_Debugger'Class)
      return access Debuggee_Console_Record'Class is
   begin
      return Debuggee_Console (Visual_Debugger (Process).Debuggee_Console);
   end Get_Debuggee_Console;

   --------------------------
   -- Set_Debugger_Console --
   --------------------------

   procedure Set_Debugger_Console
     (Process : not null access Base_Visual_Debugger'Class;
      Console : access Debugger_Console_Record'Class := null) is
   begin
      if Get_Debugger_Console (Process) /= null then
         Clear (Get_Debugger_Console (Process).Console);
      end if;

      Visual_Debugger (Process).Debugger_Text :=
        Abstract_View_Access (Console);
   end Set_Debugger_Console;

   --------------------------
   -- Set_Debuggee_Console --
   --------------------------

   procedure Set_Debuggee_Console
     (Process : not null access Base_Visual_Debugger'Class;
      Console : access Debuggee_Console_Record'Class := null) is
   begin
      if Get_Debuggee_Console (Process) /= null then
         Close_TTY (Get_Debuggee_Console (Process));
         Clear (Get_Debuggee_Console (Process).Console);
      end if;

      Visual_Debugger (Process).Debuggee_Console :=
        Abstract_View_Access (Console);
   end Set_Debuggee_Console;

   ------------
   -- TTY_Cb --
   ------------

   function TTY_Cb (Console : Debuggee_Console) return Boolean is
      Match  : Expect_Match;
   begin
      if Get_Process (Console) /= null then
         Expect (Console.Debuggee_Descriptor, Match, Regexp_Any, Timeout => 1);

         if Match /= Expect_Timeout then
            Insert (Console.Console,
                    Expect_Out (Console.Debuggee_Descriptor),
                    Add_LF => False);
            Highlight_Child
              (Find_MDI_Child
                 (Get_MDI (Visual_Debugger (Get_Process (Console)).Kernel),
                  Console));
         end if;
      end if;

      return True;

   exception
      when Process_Died =>
         Insert (Console.Console,
                 Expect_Out (Console.Debuggee_Descriptor),
                 Add_LF => False);
         Highlight_Child
           (Find_MDI_Child
              (Get_MDI (Visual_Debugger (Get_Process (Console)).Kernel),
               Console));

         --  Reset the TTY linking with the debugger and the console
         Close_TTY (Console);
         Allocate_TTY (Console);

         return True;
   end TTY_Cb;

   -------------------------
   -- On_Debuggee_Destroy --
   -------------------------

   procedure On_Debuggee_Destroy (Console : access Gtk_Widget_Record'Class) is
   begin
      Close_TTY (Debuggee_Console (Console));
   end On_Debuggee_Destroy;

   -------------------
   -- On_Grab_Focus --
   -------------------

   procedure On_Grab_Focus (Console : access Gtk_Widget_Record'Class)
   is
      C : constant Debugger_Console := Debugger_Console (Console);
   begin
      if Get_Process (C) /= null then
         Set_Current_Debugger
           (Visual_Debugger (Get_Process (C)).Kernel,
            Get_Process (C));
         String_History.Wind
           (Visual_Debugger (Get_Process (C)).Command_History,
            String_History.Forward);
      end if;
   end On_Grab_Focus;

   ----------------------
   -- Complete_Command --
   ----------------------

   function Complete_Command
     (Input   : String;
      View    : access Gtk.Text_View.Gtk_Text_View_Record'Class;
      Console : System.Address)
      return String_List_Utils.String_List.List
   is
      pragma Unreferenced (View);
      use String_List_Utils.String_List;
      C : constant Debugger_Console := Convert (Console);
      Result : List;
   begin
      if Get_Process (C) = null then
         return String_List_Utils.String_List.Null_List;

      elsif not
        Command_In_Process
          (Get_Process (Visual_Debugger (Get_Process (C)).Debugger))
      then
         --  Do not launch completion if the last character is ' ', as that
         --  might result in an output of several thousand entries, which
         --  will take a long time to parse.
         --  Do not complete either when the last character is '\' as it will
         --  hang GPS.
         if Input /= ""
           and then Input (Input'Last) /= ' '
           and then Input (Input'Last) /= '\'
         then
            declare
               S : GNAT.Strings.String_List :=
                  Complete (Visual_Debugger (Get_Process (C)).Debugger, Input);
            begin
               for J in S'Range loop
                  Append (Result, S (J).all);
               end loop;

               Free (S);
            end;
         end if;
      end if;

      if Is_Empty (Result) then
         Append (Result, Input);
      end if;

      return Result;
   end Complete_Command;

   -------------------------------
   -- Interpret_Command_Handler --
   -------------------------------

   function Interpret_Command_Handler
     (Console    : access Interactive_Console_Record'Class;
      Input      : String;
      Debugger_C : System.Address) return String
   is
      pragma Unreferenced (Console);
      C   : constant Debugger_Console := Convert (Debugger_C);
      P   : constant Visual_Debugger := Visual_Debugger (Get_Process (C));
   begin
      if P /= null then
         P.Is_From_Dbg_Console := True;
         Process_User_Command (P, Input, Mode => User);
      end if;
      return "";
   end Interpret_Command_Handler;

   ------------------------------
   -- Debuggee_Console_Handler --
   ------------------------------

   function Debuggee_Console_Handler
     (Console    : access Interactive_Console_Record'Class;
      Input      : String;
      Debuggee_C : System.Address) return String
   is
      pragma Unreferenced (Console);
      C   : constant Debuggee_Console := Convert (Debuggee_C);
      NL  : aliased Character := ASCII.LF;
      N   : Integer;
      pragma Unreferenced (N);

   begin
      if Get_Process (C) /= null then
         N := Write
           (TTY_Descriptor (C.Debuggee_TTY), Input'Address, Input'Length);
         N := Write (TTY_Descriptor (C.Debuggee_TTY), NL'Address, 1);
      end if;

      return "";
   end Debuggee_Console_Handler;

   ----------------
   -- Initialize --
   ----------------

   function Initialize
     (Self    : access Debugger_Console_Record'Class) return Gtk_Widget is
   begin
      Gtk.Box.Initialize_Vbox (Self);
      Gtk_New
        (Self.Console,
         Self.Kernel,
         Handler             => Interpret_Command_Handler'Access,
         User_Data           => Self.all'Address,
         Prompt              => "",
         History_List        => Get_History (Self.Kernel),
         Key                 => "gvd_console",
         Wrap_Mode           => Wrap_Char,
         ANSI_Support        => Active (ANSI_Support),
         Empty_Equals_Repeat => True);
      Self.Pack_Start (Self.Console, Fill => True, Expand => True);
      Set_Font_And_Colors (Get_View (Self.Console), Fixed_Font => True);

      Set_Max_Length (Get_History (Self.Kernel).all, 100, "gvd_console");
      Allow_Duplicates
        (Get_History (Self.Kernel).all, "gvd_console", True, True);

      Set_Highlight_Color (Self.Console, Preference (Comments_Style));
      Set_Completion_Handler
        (Self.Console, Complete_Command'Access, Self.all'Address);
      Widget_Callback.Object_Connect
        (Get_View (Self.Console), Signal_Grab_Focus, On_Grab_Focus'Access,
         Self);

      Setup_Contextual_Menu
        (Kernel          => Self.Kernel,
         Event_On_Widget => Get_View (Self.Console));

      return Gtk_Widget (Get_View (Self.Console));
   end Initialize;

   ------------------
   -- Allocate_TTY --
   ------------------

   procedure Allocate_TTY (Console : access Debuggee_Console_Record'Class) is
   begin
      if not Console.TTY_Initialized then
         Allocate_TTY (Console.Debuggee_TTY);
         Pseudo_Descriptor
           (Console.Debuggee_Descriptor, Console.Debuggee_TTY, 0);
         Flush (Console.Debuggee_Descriptor);

         Console.TTY_Initialized := True;
         Console.Debuggee_Id :=
           TTY_Timeout.Timeout_Add
             (Timeout, TTY_Cb'Access, Console.all'Access);

         if Get_Process (Console) /= null
           and then Visual_Debugger (Get_Process (Console)).Debugger /= null
         then
            Set_TTY
              (Visual_Debugger (Get_Process (Console)).Debugger,
               TTY_Name (Console.Debuggee_TTY));
         end if;
      end if;

   exception
      when E : others =>
         Trace (Me, E);
   end Allocate_TTY;

   ---------------
   -- Close_TTY --
   ---------------

   procedure Close_TTY (Console : access Debuggee_Console_Record'Class) is
      Debugger : Debugger_Access;
   begin
      if Console.TTY_Initialized then
         if Console.Debuggee_Id /= 0 then
            Glib.Main.Remove (Console.Debuggee_Id);
            Console.Debuggee_Id := 0;
         end if;

         if Get_Process (Console) /= null then
            Debugger := Visual_Debugger (Get_Process (Console)).Debugger;

            if Debugger /= null
              and then not Command_In_Process (Get_Process (Debugger))
            then
               Set_TTY (Visual_Debugger (Get_Process (Console)).Debugger,  "");
            end if;
         end if;

         Close_TTY (Console.Debuggee_TTY);
         Close_Pseudo_Descriptor (Console.Debuggee_Descriptor);
         Console.TTY_Initialized := False;
      end if;
   end Close_TTY;

   ----------------
   -- Initialize --
   ----------------

   function Initialize
     (Self    : access Debuggee_Console_Record'Class) return Gtk_Widget is
   begin
      Gtk.Box.Initialize_Vbox (Self);
      Gtk_New
        (Self.Console,
         Self.Kernel,
         Prompt      => "",
         Handler     => Debuggee_Console_Handler'Access,
         User_Data   => Self.all'Address,
         History_List => null,
         Key          => "gvd_tty_console",
         ANSI_Support => True,
         Wrap_Mode    => Wrap_Char);
      Self.Pack_Start (Self.Console, Expand => True, Fill => True);

      Set_Font_And_Colors (Get_View (Self.Console), Fixed_Font => True);
      Widget_Callback.Object_Connect
        (Self.Console, Signal_Destroy, On_Debuggee_Destroy'Access, Self);

      return Gtk_Widget (Get_View (Self.Console));
   end Initialize;

   --------------------------------
   -- Attach_To_Debugger_Console --
   --------------------------------

   procedure Attach_To_Debugger_Console
     (Debugger            : access Base_Visual_Debugger'Class;
      Kernel              : not null access Kernel_Handle_Record'Class;
      Create_If_Necessary : Boolean)
     renames Debugger_Views.Attach_To_View;

   procedure Attach_To_Debuggee_Console
     (Debugger            : access Base_Visual_Debugger'Class;
      Kernel              : not null access Kernel_Handle_Record'Class;
      Create_If_Necessary : Boolean)
     renames Debuggee_Views.Attach_To_View;

   ---------------
   -- On_Attach --
   ---------------

   overriding procedure On_Attach
     (Console : access Debuggee_Console_Record;
      Process : not null access Base_Visual_Debugger'Class)
   is
      pragma Unreferenced (Process);
   begin
      Allocate_TTY (Console);
   end On_Attach;

   --------------------------------
   -- Debugger_Console_Has_Focus --
   --------------------------------

   function Debugger_Console_Has_Focus
     (Process : not null access Visual_Debugger_Record'Class)
      return Boolean is
   begin
      return Get_Debugger_Console (Process).Console.Get_View.Has_Focus;
   end Debugger_Console_Has_Focus;

   ---------------------------------
   -- Display_In_Debugger_Console --
   ---------------------------------

   procedure Display_In_Debugger_Console
     (Process       : not null access GVD.Process.Visual_Debugger_Record'Class;
      Text           : String;
      Highlight      : Boolean := False;
      Add_To_History : Boolean := False) is
   begin
      Insert (Get_Debugger_Console (Process).Console,
              Text,
              Add_LF         => False,
              Highlight      => Highlight,
              Add_To_History => Add_To_History);
   end Display_In_Debugger_Console;

   ---------------------
   -- Register_Module --
   ---------------------

   procedure Register_Module
     (Kernel : access GPS.Kernel.Kernel_Handle_Record'Class) is
   begin
      --  Register the debugger console last so that it gets the initial focus
      Debuggee_Views.Register_Module (Kernel);
      Debugger_Views.Register_Module (Kernel);
   end Register_Module;
end GVD.Consoles;
