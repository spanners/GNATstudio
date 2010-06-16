-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                     Copyright (C) 2010, AdaCore                   --
--                                                                   --
-- GPS is Free  software;  you can redistribute it and/or modify  it --
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
with Ada.Strings.Unbounded.Hash;

package body GNATStack.Readers is

   use Ada.Strings.Unbounded;
   use Subprogram_Information_Maps;
   use Subprogram_Location_Sets;

   ------------------------------
   -- Analyze_accurate_End_Tag --
   ------------------------------

   procedure Analyze_accurate_End_Tag (Self : in out Reader) is
      pragma Assert (Self.State.Kind = Boolean_Value_State);

      Value : constant Boolean := Self.State.Boolean_Value;

   begin
      Self.Pop;
      Self.Analysis.Accurate := Value;
   end Analyze_accurate_End_Tag;

   --------------------------------
   -- Analyze_accurate_Start_Tag --
   --------------------------------

   procedure Analyze_accurate_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class)
   is
      pragma Assert (Self.Stack.Is_Empty);
      pragma Assert (Attributes.Get_Value ("type") = "booleans");

   begin
      Self.Push;
      Self.State := (Kind => Boolean_Value_State, others => <>);
   end Analyze_accurate_Start_Tag;

   -------------------------------
   -- Analyze_callchain_End_Tag --
   -------------------------------

   procedure Analyze_callchain_End_Tag (Self : in out Reader) is
      pragma Assert (Self.State.Kind = Entry_State);

   begin
      null;
   end Analyze_callchain_End_Tag;

   ---------------------------------
   -- Analyze_callchain_Start_Tag --
   ---------------------------------

   procedure Analyze_callchain_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class)
   is
      pragma Assert (Self.State.Kind = Entry_State);

   begin
      null;
   end Analyze_callchain_Start_Tag;

   ----------------------------
   -- Analyze_column_End_Tag --
   ----------------------------

   procedure Analyze_column_End_Tag (Self : in out Reader) is
      pragma Assert (Self.State.Kind = Integer_Value_State);

      Value : constant Integer := Self.State.Integer_Value;

   begin
      Self.Pop;

      if Self.State.Kind = Location_State then
         Self.State.Location.Column := Value;

      elsif Self.State.Kind = Unbounded_Object_State then
         Self.State.Object.Column := Value;
      end if;
   end Analyze_column_End_Tag;

   ------------------------------
   -- Analyze_column_Start_Tag --
   ------------------------------

   procedure Analyze_column_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class)
   is
      pragma Assert
        (Self.State.Kind = Location_State
           or else Self.State.Kind = Unbounded_Object_State);
      pragma Assert (Attributes.Get_Value ("type") = "integers");

   begin
      Self.Push;
      Self.State := (Kind => Integer_Value_State, others => <>);
   end Analyze_column_Start_Tag;

   ---------------------------
   -- Analyze_cycle_End_Tag --
   ---------------------------

   procedure Analyze_cycle_End_Tag (Self : in out Reader) is
      pragma Assert (Self.State.Kind = Cycle_State);

      Cycle : constant Subprogram_Information_Vectors.Vector :=
                Self.State.Cycle;

   begin
      Self.Pop;
      Self.Analysis.Cycle_Set.Append (Cycle);
   end Analyze_cycle_End_Tag;

   -----------------------------
   -- Analyze_cycle_Start_Tag --
   -----------------------------

   procedure Analyze_cycle_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class)
   is
      pragma Unreferenced (Attributes);

      pragma Assert (Self.State.Kind = Cycle_Set_State);

   begin
      Self.Push;
      Self.State := (Kind => Cycle_State, others => <>);
   end Analyze_cycle_Start_Tag;

   ------------------------------
   -- Analyze_cycleset_End_Tag --
   ------------------------------

   procedure Analyze_cycleset_End_Tag (Self : in out Reader) is
      pragma Assert (Self.State.Kind = Cycle_Set_State);
      pragma Assert (Self.Stack.Is_Empty);
      --  "cycleset" is child of "global" element

   begin
      null;
   end Analyze_cycleset_End_Tag;

   --------------------------------
   -- Analyze_cycleset_Start_Tag --
   --------------------------------

   procedure Analyze_cycleset_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class)
   is
      pragma Unreferenced (Attributes);

      pragma Assert (Self.Stack.Is_Empty);
      --  "cycleset" is top level element

   begin
      Self.State := (Kind => Cycle_Set_State, others => <>);
   end Analyze_cycleset_Start_Tag;

   ---------------------------
   -- Analyze_entry_End_Tag --
   ---------------------------

   procedure Analyze_entry_End_Tag (Self : in out Reader) is
      pragma Assert (Self.State.Kind = Entry_State);

      Subprogram : constant Subprogram_Information_Access :=
                     Self.Resolve_Or_Create
                       ((Self.State.C_Prefix_Name, Self.State.C_Locations));
      Value      : constant Subprogram_Information_Vectors.Vector :=
                     Self.State.Chain;

   begin
      Self.Pop;
      Self.Analysis.Entry_Set.Insert (Subprogram);
      Subprogram.Is_External := True;
      Subprogram.Chain := Value;
   end Analyze_entry_End_Tag;

   -----------------------------
   -- Analyze_entry_Start_Tag --
   -----------------------------

   procedure Analyze_entry_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class)
   is
      pragma Unreferenced (Attributes);

      pragma Assert (Self.State.Kind = Entry_Set_State);
      pragma Assert (Self.Stack.Is_Empty);

   begin
      Self.Push;
      Self.State := (Kind => Entry_State, others => <>);
   end Analyze_entry_Start_Tag;

   ------------------------------
   -- Analyze_entryset_End_Tag --
   ------------------------------

   procedure Analyze_entryset_End_Tag (Self : in out Reader) is
      pragma Assert (Self.State.Kind = Entry_Set_State);
      pragma Assert (Self.Stack.Is_Empty);
      --  "entryset" is top level element

   begin
      null;
   end Analyze_entryset_End_Tag;

   --------------------------------
   -- Analyze_entryset_Start_Tag --
   --------------------------------

   procedure Analyze_entryset_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class)
   is
      pragma Unreferenced (Attributes);

      pragma Assert (Self.Stack.Is_Empty);
      --  "entryset" is top level element

   begin
      Self.State := (Kind => Entry_Set_State, others => <>);
   end Analyze_entryset_Start_Tag;

   ------------------------------
   -- Analyze_external_End_Tag --
   ------------------------------

   procedure Analyze_external_End_Tag (Self : in out Reader) is
      pragma Assert (Self.State.Kind = External_State);

      Subprogram : constant Subprogram_Information_Access :=
                     Self.Resolve_Or_Create
                       ((Self.State.E_Prefix_Name, Self.State.E_Locations));

   begin
      Self.Pop;
      Self.Analysis.External_Set.Insert (Subprogram);
      Subprogram.Is_External := True;
   end Analyze_external_End_Tag;

   --------------------------------
   -- Analyze_external_Start_Tag --
   --------------------------------

   procedure Analyze_external_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class)
   is
      pragma Unreferenced (Attributes);

      pragma Assert (Self.State.Kind = External_Set_State);

   begin
      Self.Push;
      Self.State := (Kind => External_State, others => <>);
   end Analyze_external_Start_Tag;

   ---------------------------------
   -- Analyze_externalset_End_Tag --
   ---------------------------------

   procedure Analyze_externalset_End_Tag (Self : in out Reader) is
      pragma Assert (Self.State.Kind = External_Set_State);
      pragma Assert (Self.Stack.Is_Empty);
      --  "externalset" is top level element

   begin
      null;
   end Analyze_externalset_End_Tag;

   -----------------------------------
   -- Analyze_externalset_Start_Tag --
   -----------------------------------

   procedure Analyze_externalset_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class)
   is
      pragma Unreferenced (Attributes);

      pragma Assert (Self.Stack.Is_Empty);
      --  "externalset" is top level element

   begin
      Self.State := (Kind => External_Set_State, others => <>);
   end Analyze_externalset_Start_Tag;

   --------------------------
   -- Analyze_file_End_Tag --
   --------------------------

   procedure Analyze_file_End_Tag (Self : in out Reader) is
      pragma Assert (Self.State.Kind = String_Value_State);

      Value : constant Unbounded_String := Self.State.String_Value;

   begin
      Self.Pop;

      if Self.State.Kind = Indirect_Call_State then
         Self.State.Indirect.File := Value;

      elsif Self.State.Kind = Location_State then
         Self.State.Location.File := Value;

      elsif Self.State.Kind = Unbounded_Object_State then
         Self.State.Object.File := Value;
      end if;
   end Analyze_file_End_Tag;

   ----------------------------
   -- Analyze_file_Start_Tag --
   ----------------------------

   procedure Analyze_file_Start_Tag
     (Self       : in out Reader'Class;
      Attributes : Sax.Attributes.Attributes'Class'Class)
   is
      pragma Assert
        (Self.State.Kind = Indirect_Call_State
           or Self.State.Kind = Location_State
           or Self.State.Kind = Unbounded_Object_State);
      pragma Assert (Attributes.Get_Value ("type") = "strings");

   begin
      Self.Push;
      Self.State := (Kind => String_Value_State, others => <>);
   end Analyze_file_Start_Tag;

   ----------------------------
   -- Analyze_global_End_Tag --
   ----------------------------

   procedure Analyze_global_End_Tag (Self : in out Reader) is
      pragma Assert (Self.Stack.Is_Empty);
      --  "global" is top level element

   begin
      null;
   end Analyze_global_End_Tag;

   ------------------------------
   -- Analyze_global_Start_Tag --
   ------------------------------

   procedure Analyze_global_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class)
   is
      pragma Assert (Self.Stack.Is_Empty);
      --  "global" is top level element

   begin
      null;
   end Analyze_global_Start_Tag;

   --------------------------------------
   -- Analyze_globalstackusage_End_Tag --
   --------------------------------------

   procedure Analyze_globalstackusage_End_Tag (Self : in out Reader) is
      pragma Assert (Self.State.Kind = Stack_Usage_State);

      Value : constant Stack_Usage_Information := Self.State.Stack_Usage;

   begin
      Self.Pop;
      Self.State.Global_Usage := Value;
   end Analyze_globalstackusage_End_Tag;

   ----------------------------------------
   -- Analyze_globalstackusage_Start_Tag --
   ----------------------------------------

   procedure Analyze_globalstackusage_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class)
   is
      pragma Unreferenced (Attributes);

      pragma Assert (Self.State.Kind = Subprogram_State);
      pragma Assert (not Self.State.Is_Reference);

   begin
      Self.Push;
      Self.State := (Kind => Stack_Usage_State, others => <>);
   end Analyze_globalstackusage_Start_Tag;

   ------------------------------
   -- Analyze_indirect_End_Tag --
   ------------------------------

   procedure Analyze_indirect_End_Tag (Self : in out Reader) is
      pragma Assert (Self.State.Kind = Indirect_State);

      Subprogram : constant Subprogram_Information_Access :=
                     Self.State.I_Subprogram;

   begin
      Self.Pop;
      Self.Analysis.Indirect_Set.Insert (Subprogram);
   end Analyze_indirect_End_Tag;

   --------------------------------
   -- Analyze_indirect_Start_Tag --
   --------------------------------

   procedure Analyze_indirect_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class)
   is
      pragma Unreferenced (Attributes);

      pragma Assert (Self.State.Kind = Indirect_Set_State);

   begin
      Self.Push;
      Self.State := (Kind => Indirect_State, others => <>);
   end Analyze_indirect_Start_Tag;

   ----------------------------------
   -- Analyze_indirectcall_End_Tag --
   ----------------------------------

   procedure Analyze_indirectcall_End_Tag (Self : in out Reader) is
      pragma Assert (Self.State.Kind = Indirect_Call_State);

      Value : constant Indirect_Call_Information := Self.State.Indirect;

   begin
      Self.Pop;
      Self.State.I_Subprogram.Indirects.Append (Value);
   end Analyze_indirectcall_End_Tag;

   ------------------------------------
   -- Analyze_indirectcall_Start_Tag --
   ------------------------------------

   procedure Analyze_indirectcall_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class)
   is
      pragma Unreferenced (Attributes);

      pragma Assert (Self.State.Kind = Indirect_State);

   begin
      Self.Push;
      Self.State := (Kind => Indirect_Call_State, others => <>);
   end Analyze_indirectcall_Start_Tag;

   -------------------------------------
   -- Analyze_indirectcallset_End_Tag --
   -------------------------------------

   procedure Analyze_indirectcallset_End_Tag (Self : in out Reader) is
      pragma Assert (Self.State.Kind = Indirect_State);

   begin
      null;
   end Analyze_indirectcallset_End_Tag;

   ---------------------------------------
   -- Analyze_indirectcallset_Start_Tag --
   ---------------------------------------

   procedure Analyze_indirectcallset_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class)
   is
      pragma Unreferenced (Attributes);

      pragma Assert (Self.State.Kind = Indirect_State);

   begin
      Self.State.I_Subprogram :=
        Self.Resolve_Or_Create
          ((Self.State.I_Prefix_Name, Self.State.I_Locations));
   end Analyze_indirectcallset_Start_Tag;

   ---------------------------------
   -- Analyze_indirectset_End_Tag --
   ---------------------------------

   procedure Analyze_indirectset_End_Tag (Self : in out Reader) is
      pragma Assert (Self.State.Kind = Indirect_Set_State);
      pragma Assert (Self.Stack.Is_Empty);
      --  "indirectset" is child of "global" element

   begin
      null;
   end Analyze_indirectset_End_Tag;

   -----------------------------------
   -- Analyze_indirectset_Start_Tag --
   -----------------------------------

   procedure Analyze_indirectset_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class)
   is
      pragma Unreferenced (Attributes);

      pragma Assert (Self.Stack.Is_Empty);
      --  "indirectset" is child of "global" element

   begin
      Self.State := (Kind => Indirect_Set_State, others => <>);
   end Analyze_indirectset_Start_Tag;

   --------------------------
   -- Analyze_line_End_Tag --
   --------------------------

   procedure Analyze_line_End_Tag (Self : in out Reader) is
      pragma Assert (Self.State.Kind = Integer_Value_State);

      Value : constant Integer := Self.State.Integer_Value;

   begin
      Self.Pop;

      if Self.State.Kind = Indirect_Call_State then
         Self.State.Indirect.Line := Value;

      elsif Self.State.Kind = Location_State then
         Self.State.Location.Line := Value;

      elsif Self.State.Kind = Unbounded_Object_State then
         Self.State.Object.Line := Value;
      end if;
   end Analyze_line_End_Tag;

   ----------------------------
   -- Analyze_line_Start_Tag --
   ----------------------------

   procedure Analyze_line_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class)
   is
      pragma Assert
        (Self.State.Kind = Indirect_Call_State
           or else Self.State.Kind = Location_State
           or else Self.State.Kind = Unbounded_Object_State);
      pragma Assert (Attributes.Get_Value ("type") = "integers");

   begin
      Self.Push;
      Self.State := (Kind => Integer_Value_State, others => <>);
   end Analyze_line_Start_Tag;

   -------------------------------------
   -- Analyze_localstackusage_End_Tag --
   -------------------------------------

   procedure Analyze_localstackusage_End_Tag (Self : in out Reader) is
      pragma Assert (Self.State.Kind = Stack_Usage_State);

      Value : constant Stack_Usage_Information := Self.State.Stack_Usage;

   begin
      Self.Pop;

      if Self.State.Kind = Entry_State then
         Self.State.Entry_Usage := Value;

      elsif Self.State.Kind = Subprogram_State then
         Self.State.Local_Usage := Value;
      end if;
   end Analyze_localstackusage_End_Tag;

   ---------------------------------------
   -- Analyze_localstackusage_Start_Tag --
   ---------------------------------------

   procedure Analyze_localstackusage_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class)
   is
      pragma Unreferenced (Attributes);

      pragma Assert
        (Self.State.Kind = Entry_State
           or else Self.State.Kind = Subprogram_State);
      pragma Assert
        (Self.State.Kind /= Subprogram_State
           or else not Self.State.Is_Reference);

   begin
      Self.Push;
      Self.State := (Kind => Stack_Usage_State, others => <>);
   end Analyze_localstackusage_Start_Tag;

   ------------------------------
   -- Analyze_location_End_Tag --
   ------------------------------

   procedure Analyze_location_End_Tag (Self : in out Reader) is
      pragma Assert (Self.State.Kind = Location_State);

      Value : constant Subprogram_Location := Self.State.Location;

   begin
      Self.Pop;
      Self.State.Location_Set.Insert (Value);
   end Analyze_location_End_Tag;

   --------------------------------
   -- Analyze_location_Start_Tag --
   --------------------------------

   procedure Analyze_location_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class)
   is
      pragma Unreferenced (Attributes);

      pragma Assert (Self.State.Kind = Location_Set_State);

   begin
      Self.Push;
      Self.State := (Kind => Location_State, others => <>);
   end Analyze_location_Start_Tag;

   ---------------------------------
   -- Analyze_locationset_End_Tag --
   ---------------------------------

   procedure Analyze_locationset_End_Tag (Self : in out Reader) is
      pragma Assert (Self.State.Kind = Location_Set_State);

      Value : constant Subprogram_Location_Sets.Set :=
                Self.State.Location_Set;

   begin
      Self.Pop;

      if Self.State.Kind = Entry_State then
         Self.State.C_Locations := Value;

      elsif Self.State.Kind = External_State then
         Self.State.E_Locations := Value;

      elsif Self.State.Kind = Indirect_State then
         Self.State.I_Locations := Value;

      elsif Self.State.Kind = Subprogram_State then
         Self.State.S_Locations := Value;

      elsif Self.State.Kind = Unbounded_State then
         Self.State.U_Locations := Value;
      end if;
   end Analyze_locationset_End_Tag;

   -----------------------------------
   -- Analyze_locationset_Start_Tag --
   -----------------------------------

   procedure Analyze_locationset_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class)
   is
      pragma Unreferenced (Attributes);

      pragma Assert
        (Self.State.Kind = Entry_State
           or else Self.State.Kind = External_State
           or else Self.State.Kind = Indirect_State
           or else Self.State.Kind = Subprogram_State
           or else Self.State.Kind = Unbounded_State);

   begin
      Self.Push;
      Self.State := (Kind => Location_Set_State, others => <>);
   end Analyze_locationset_Start_Tag;

   ----------------------------
   -- Analyze_object_End_Tag --
   ----------------------------

   procedure Analyze_object_End_Tag (Self : in out Reader) is
      pragma Assert (Self.State.Kind = String_Value_State);

      Value : constant Unbounded_String := Self.State.String_Value;

   begin
      Self.Pop;
      Self.State.Object.Name := Value;
   end Analyze_object_End_Tag;

   ------------------------------
   -- Analyze_object_Start_Tag --
   ------------------------------

   procedure Analyze_object_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class)
   is
      pragma Assert (Self.State.Kind = Unbounded_Object_State);
      pragma Assert (Attributes.Get_Value ("type") = "strings");

   begin
      Self.Push;
      Self.State := (Kind => String_Value_State, others => <>);
   end Analyze_object_Start_Tag;

   --------------------------------
   -- Analyze_prefixname_End_Tag --
   --------------------------------

   procedure Analyze_prefixname_End_Tag (Self : in out Reader) is
      pragma Assert (Self.State.Kind = String_Value_State);

      Value : constant Unbounded_String := Self.State.String_Value;

   begin
      Self.Pop;

      if Self.State.Kind = Entry_State then
         Self.State.C_Prefix_Name := Value;

      elsif Self.State.Kind = External_State then
         Self.State.E_Prefix_Name := Value;

      elsif Self.State.Kind = Indirect_State then
         Self.State.I_Prefix_Name := Value;

      elsif Self.State.Kind = Subprogram_State then
         Self.State.S_Prefix_Name := Value;

      elsif Self.State.Kind = Unbounded_State then
         Self.State.U_Prefix_Name := Value;
      end if;
   end Analyze_prefixname_End_Tag;

   ----------------------------------
   -- Analyze_prefixname_Start_Tag --
   ----------------------------------

   procedure Analyze_prefixname_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class)
   is
      pragma Assert
        (Self.State.Kind = Entry_State
           or else Self.State.Kind = External_State
           or else Self.State.Kind = Indirect_State
           or else Self.State.Kind = Subprogram_State
           or else Self.State.Kind = Unbounded_State);
      pragma Assert (Attributes.Get_Value ("type") = "strings");

   begin
      Self.Push;
      Self.State := (Kind => String_Value_State, others => <>);
   end Analyze_prefixname_Start_Tag;

   -------------------------------
   -- Analyze_qualifier_End_Tag --
   -------------------------------

   procedure Analyze_qualifier_End_Tag (Self : in out Reader) is
      pragma Assert (Self.State.Kind = String_Value_State);

      Value : constant Unbounded_String := Self.State.String_Value;

   begin
      Self.Pop;
      Self.State.Stack_Usage.Qualifier := Value;
   end Analyze_qualifier_End_Tag;

   ---------------------------------
   -- Analyze_qualifier_Start_Tag --
   ---------------------------------

   procedure Analyze_qualifier_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class)
   is
      pragma Unreferenced (Attributes);

      pragma Assert (Self.State.Kind = Stack_Usage_State);
      --  There is no "type" for "qualifier" in XML file specified

   begin
      Self.Push;
      Self.State := (Kind => String_Value_State, others => <>);
   end Analyze_qualifier_Start_Tag;

   --------------------------
   -- Analyze_size_End_Tag --
   --------------------------

   procedure Analyze_size_End_Tag (Self : in out Reader) is
      pragma Assert (Self.State.Kind = Integer_Value_State);

      Value : constant Integer := Self.State.Integer_Value;

   begin
      Self.Pop;
      Self.State.Stack_Usage.Size := Value;
   end Analyze_size_End_Tag;

   ----------------------------
   -- Analyze_size_Start_Tag --
   ----------------------------

   procedure Analyze_size_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class)
   is
      pragma Assert (Self.State.Kind = Stack_Usage_State);
      pragma Assert (Attributes.Get_Value ("type") = "integers");

   begin
      Self.Push;
      Self.State := (Kind => Integer_Value_State, others => <>);
   end Analyze_size_Start_Tag;

   --------------------------------
   -- Analyze_subprogram_End_Tag --
   --------------------------------

   procedure Analyze_subprogram_End_Tag (Self : in out Reader) is
      pragma Assert (Self.State.Kind = Subprogram_State);

      Value : constant Parser_State := Self.State;
      Info  : Subprogram_Information_Access;

   begin
      Self.Pop;
      Info :=
        Self.Resolve_Or_Create ((Value.S_Prefix_Name, Value.S_Locations));

      if Self.State.Kind = Entry_State then
         --  Insert subprogram into the chain

         Self.State.Chain.Append (Info);

      elsif Self.State.Kind = Subprogram_Set_State then
         --  Fill data

         Info.Global_Usage := Value.Global_Usage;
         Info.Local_Usage := Value.Local_Usage;
         Info.Calls := Value.Calls;

      elsif Self.State.Kind = Subprogram_Called_Set_State then
         --  Insert subprogram into the set

         Self.State.Called_Set.Insert (Info);

      elsif Self.State.Kind = Cycle_State then
         --  Insert subprogram into the chain

         Self.State.Cycle.Append (Info);
      end if;
   end Analyze_subprogram_End_Tag;

   ----------------------------------
   -- Analyze_subprogram_Start_Tag --
   ----------------------------------

   procedure Analyze_subprogram_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class)
   is
      pragma Unreferenced (Attributes);

      pragma Assert
        (Self.State.Kind = Entry_State
           or else Self.State.Kind = Cycle_State
           or else Self.State.Kind = Subprogram_Called_Set_State
           or else Self.State.Kind = Subprogram_Set_State);

      Is_Reference : constant Boolean :=
                       Self.State.Kind /= Subprogram_Set_State;

   begin
      Self.Push;
      Self.State :=
        (Kind         => Subprogram_State,
         Is_Reference => Is_Reference,
         others       => <>);
   end Analyze_subprogram_Start_Tag;

   -----------------------------------------
   -- Analyze_subprogramcalledset_End_Tag --
   -----------------------------------------

   procedure Analyze_subprogramcalledset_End_Tag (Self : in out Reader) is
      pragma Assert (Self.State.Kind = Subprogram_Called_Set_State);

      Set : constant Subprogram_Information_Sets.Set := Self.State.Called_Set;

   begin
      Self.Pop;
      Self.State.Calls := Set;
   end Analyze_subprogramcalledset_End_Tag;

   -------------------------------------------
   -- Analyze_subprogramcalledset_Start_Tag --
   -------------------------------------------

   procedure Analyze_subprogramcalledset_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class)
   is
      pragma Unreferenced (Attributes);

      pragma Assert (Self.State.Kind = Subprogram_State);

   begin
      Self.Push;
      Self.State := (Kind => Subprogram_Called_Set_State, others => <>);
   end Analyze_subprogramcalledset_Start_Tag;

   ------------------------------------
   -- Analyze_subprogramname_End_Tag --
   ------------------------------------

   procedure Analyze_subprogramname_End_Tag (Self : in out Reader) is
      pragma Assert (Self.State.Kind = String_Value_State);

      Value : constant Unbounded_String := Self.State.String_Value;

   begin
      Self.Pop;
      Self.State.Location.Name := Value;
   end Analyze_subprogramname_End_Tag;

   --------------------------------------
   -- Analyze_subprogramname_Start_Tag --
   --------------------------------------

   procedure Analyze_subprogramname_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class)
   is
      pragma Assert (Self.State.Kind = Location_State);
      pragma Assert (Attributes.Get_Value ("type") = "strings");

   begin
      Self.Push;
      Self.State := (Kind => String_Value_State, others => <>);
   end Analyze_subprogramname_Start_Tag;

   -----------------------------------
   -- Analyze_subprogramset_End_Tag --
   -----------------------------------

   procedure Analyze_subprogramset_End_Tag (Self : in out Reader) is
      pragma Assert (Self.State.Kind = Subprogram_Set_State);

      pragma Assert (Self.Stack.Is_Empty);
      --  "subprogramset" is top level element

   begin
      null;
   end Analyze_subprogramset_End_Tag;

   -------------------------------------
   -- Analyze_subprogramset_Start_Tag --
   -------------------------------------

   procedure Analyze_subprogramset_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class)
   is
      pragma Unreferenced (Attributes);

      pragma Assert (Self.Stack.Is_Empty);
      --  "subprogramset" is top level element

   begin
      Self.State := (Kind => Subprogram_Set_State, others => <>);
   end Analyze_subprogramset_Start_Tag;

   -------------------------------
   -- Analyze_unbounded_End_Tag --
   -------------------------------

   procedure Analyze_unbounded_End_Tag (Self : in out Reader) is
      pragma Assert (Self.State.Kind = Unbounded_State);

      Value : constant Subprogram_Information_Access :=
                Self.State.U_Subprogram;

   begin
      Self.Pop;
      Self.Analysis.Unbounded_Set.Insert (Value);
   end Analyze_unbounded_End_Tag;

   ---------------------------------
   -- Analyze_unbounded_Start_Tag --
   ---------------------------------

   procedure Analyze_unbounded_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class)
   is
      pragma Unreferenced (Attributes);

      pragma Assert (Self.State.Kind = Unbounded_Set_State);

   begin
      Self.Push;
      Self.State := (Kind => Unbounded_State, others => <>);
   end Analyze_unbounded_Start_Tag;

   -------------------------------------
   -- Analyze_unboundedobject_End_Tag --
   -------------------------------------

   procedure Analyze_unboundedobject_End_Tag (Self : in out Reader) is
      pragma Assert (Self.State.Kind = Unbounded_Object_State);

      Value : constant Object_Information := Self.State.Object;

   begin
      Self.Pop;

      --  Resolve subprogram's record or create new one.

      if Self.State.U_Subprogram = null then
         Self.State.U_Subprogram :=
           Self.Resolve_Or_Create
             ((Self.State.U_Prefix_Name, Self.State.U_Locations));
      end if;

      Self.State.U_Subprogram.Unbounded.Append (Value);
   end Analyze_unboundedobject_End_Tag;

   ---------------------------------------
   -- Analyze_unboundedobject_Start_Tag --
   ---------------------------------------

   procedure Analyze_unboundedobject_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class)
   is
      pragma Unreferenced (Attributes);

      pragma Assert (Self.State.Kind = Unbounded_State);

   begin
      Self.Push;
      Self.State := (Kind => Unbounded_Object_State, others => <>);
   end Analyze_unboundedobject_Start_Tag;

   ----------------------------------------
   -- Analyze_unboundedobjectset_End_Tag --
   ----------------------------------------

   procedure Analyze_unboundedobjectset_End_Tag (Self : in out Reader) is
      pragma Assert (Self.State.Kind = Unbounded_State);
      --  "unboundedobjectset" element is ignored, parser's state is unchanged
      --  to allow direct access to members of Unbounded_Set state.

   begin
      null;
   end Analyze_unboundedobjectset_End_Tag;

   ------------------------------------------
   -- Analyze_unboundedobjectset_Start_Tag --
   ------------------------------------------

   procedure Analyze_unboundedobjectset_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class)
   is
      pragma Assert (Self.State.Kind = Unbounded_State);

   begin
      --  "unboundedobjectset" element is ignored, parser's state is unchanged
      --  to allow direct access to members of Unbounded_Set state.

      null;
   end Analyze_unboundedobjectset_Start_Tag;

   ----------------------------------
   -- Analyze_unboundedset_End_Tag --
   ----------------------------------

   procedure Analyze_unboundedset_End_Tag (Self : in out Reader) is
      pragma Assert (Self.State.Kind = Unbounded_Set_State);
      pragma Assert (Self.Stack.Is_Empty);
      --  "unboundedset" is top level element

   begin
      null;
   end Analyze_unboundedset_End_Tag;

   ------------------------------------
   -- Analyze_unboundedset_Start_Tag --
   ------------------------------------

   procedure Analyze_unboundedset_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class)
   is
      pragma Unreferenced (Attributes);

      pragma Assert (Self.Stack.Is_Empty);
      --  "unboundedset" is child of "global" element

   begin
      Self.State := (Kind => Unbounded_Set_State, others => <>);
   end Analyze_unboundedset_Start_Tag;

   ----------------
   -- Characters --
   ----------------

   overriding procedure Characters
     (Self : in out Reader;
      Text : Unicode.CES.Byte_Sequence) is
   begin
      if Self.State.Kind in Value_Kinds then
         case Self.State.Kind is
            when Boolean_Value_State =>
               Self.State.Boolean_Value := Boolean'Value (Text);

            when Integer_Value_State =>
               Self.State.Integer_Value := Integer'Value (Text);

            when String_Value_State =>
               Append (Self.State.String_Value, Text);

            when others =>
               raise Program_Error;
               --  Must never be happen.
         end case;
      end if;
   end Characters;

   -----------------
   -- End_Element --
   -----------------

   overriding procedure End_Element
     (Self          : in out Reader;
      Namespace_URI : Unicode.CES.Byte_Sequence := "";
      Local_Name    : Unicode.CES.Byte_Sequence := "";
      Qname         : Unicode.CES.Byte_Sequence := "")
   is
      pragma Unreferenced (Namespace_URI, Qname);

   begin
      if Local_Name = "GNATstack_Information" then
         null;

         pragma Assert (Self.Stack.Is_Empty);
         --  "GNATstack_Information" is root element

      elsif Local_Name = "accurate" then
         Self.Analyze_accurate_End_Tag;

      elsif Local_Name = "callchain" then
         Self.Analyze_callchain_End_Tag;

      elsif Local_Name = "column" then
         Self.Analyze_column_End_Tag;

      elsif Local_Name = "cycle" then
         Self.Analyze_cycle_End_Tag;

      elsif Local_Name = "cycleset" then
         Self.Analyze_cycleset_End_Tag;

      elsif Local_Name = "entry" then
         Self.Analyze_entry_End_Tag;

      elsif Local_Name = "entryset" then
         Self.Analyze_entryset_End_Tag;

      elsif Local_Name = "external" then
         Self.Analyze_external_End_Tag;

      elsif Local_Name = "externalset" then
         Self.Analyze_externalset_End_Tag;

      elsif Local_Name = "file" then
         Self.Analyze_file_End_Tag;

      elsif Local_Name = "global" then
         Self.Analyze_global_End_Tag;

      elsif Local_Name = "globalstackusage" then
         Self.Analyze_globalstackusage_End_Tag;

      elsif Local_Name = "indirect" then
         Self.Analyze_indirect_End_Tag;

      elsif Local_Name = "indirectcall" then
         Self.Analyze_indirectcall_End_Tag;

      elsif Local_Name = "indirectcallset" then
         Self.Analyze_indirectcallset_End_Tag;

      elsif Local_Name = "indirectset" then
         Self.Analyze_indirectset_End_Tag;

      elsif Local_Name = "line" then
         Self.Analyze_line_End_Tag;

      elsif Local_Name = "localstackusage" then
         Self.Analyze_localstackusage_End_Tag;

      elsif Local_Name = "location" then
         Self.Analyze_location_End_Tag;

      elsif Local_Name = "locationset" then
         Self.Analyze_locationset_End_Tag;

      elsif Local_Name = "object" then
         Self.Analyze_object_End_Tag;

      elsif Local_Name = "prefixname" then
         Self.Analyze_prefixname_End_Tag;

      elsif Local_Name = "qualifier" then
         Self.Analyze_qualifier_End_Tag;

      elsif Local_Name = "size" then
         Self.Analyze_size_End_Tag;

      elsif Local_Name = "subprogram" then
         Self.Analyze_subprogram_End_Tag;

      elsif Local_Name = "subprogramcalledset" then
         Self.Analyze_subprogramcalledset_End_Tag;

      elsif Local_Name = "subprogramname" then
         Self.Analyze_subprogramname_End_Tag;

      elsif Local_Name = "subprogramset" then
         Self.Analyze_subprogramset_End_Tag;

      elsif Local_Name = "unbounded" then
         Self.Analyze_unbounded_End_Tag;

      elsif Local_Name = "unboundedobject" then
         Self.Analyze_unboundedobject_End_Tag;

      elsif Local_Name = "unboundedobjectset" then
         Self.Analyze_unboundedobjectset_End_Tag;

      elsif Local_Name = "unboundedset" then
         Self.Analyze_unboundedset_End_Tag;

      elsif Local_Name = "value" then
         null;

      else
         raise Program_Error;
      end if;
   end End_Element;

   -------------------------
   -- Equivalent_Elements --
   -------------------------

   function Equivalent_Elements
     (Left  : Subprogram_Information_Access;
      Right : Subprogram_Information_Access) return Boolean is
   begin
      return Left.Identifier = Right.Identifier;
   end Equivalent_Elements;

   ----------
   -- Hash --
   ----------

   function Hash
     (Item : Subprogram_Location) return Ada.Containers.Hash_Type is
   begin
      return
        Ada.Strings.Unbounded.Hash
          (Item.Name
           & Item.File
           & Integer'Image (Item.Line)
           & Integer'Image (Item.Column));
   end Hash;

   ----------
   -- Hash --
   ----------

   function Hash
     (Item : Subprogram_Identifier) return Ada.Containers.Hash_Type
   is
      Position : Subprogram_Location_Sets.Cursor := Item.Locations.First;
      Aux      : Unbounded_String                := Item.Prefix_Name;

   begin
      while Has_Element (Position) loop
         declare
            Location : constant Subprogram_Location := Element (Position);

         begin
            Append (Aux, Location.Name);
            Append (Aux, Location.File);
            Append (Aux, Integer'Image (Location.Line));
            Append (Aux, Integer'Image (Location.Column));

            Next (Position);
         end;
      end loop;

      return Ada.Strings.Unbounded.Hash (Aux);
   end Hash;

   ----------
   -- Hash --
   ----------

   function Hash
     (Item : Subprogram_Information_Access) return Ada.Containers.Hash_Type is
   begin
      return Hash (Item.Identifier);
   end Hash;

   ---------
   -- Pop --
   ---------

   procedure Pop (Self : in out Reader) is
   begin
      Self.State := Self.Stack.Last_Element;
      Self.Stack.Delete_Last;
   end Pop;

   ----------
   -- Push --
   ----------

   procedure Push (Self : in out Reader) is
   begin
      Self.Stack.Append (Self.State);
      Self.State := (Kind => None_State);
   end Push;

   -----------------------
   -- Resolve_Or_Create --
   -----------------------

   function Resolve_Or_Create
     (Self       : not null access Reader;
      Identifier : Subprogram_Identifier)
      return Subprogram_Information_Access
   is
      Position : constant Subprogram_Information_Maps.Cursor :=
                   Self.Subprogram_Map.Find (Identifier);
      Info     : Subprogram_Information_Access;

   begin
      if Has_Element (Position) then
         return Element (Position);

      else
         Info :=
           new Subprogram_Information'(Identifier => Identifier, others => <>);
         Self.Analysis.Subprogram_Set.Insert (Info);
         Self.Subprogram_Map.Insert (Info.Identifier, Info);

         return Info;
      end if;
   end Resolve_Or_Create;

   -------------------
   -- Start_Element --
   -------------------

   overriding procedure Start_Element
     (Self          : in out Reader;
      Namespace_URI : Unicode.CES.Byte_Sequence := "";
      Local_Name    : Unicode.CES.Byte_Sequence := "";
      Qname         : Unicode.CES.Byte_Sequence := "";
      Atts          : Sax.Attributes.Attributes'Class)
   is
      pragma Unreferenced (Namespace_URI, Qname);

   begin
      if Local_Name = "GNATstack_Information" then
         null;

      elsif Local_Name = "accurate" then
         Self.Analyze_accurate_Start_Tag (Atts);

      elsif Local_Name = "callchain" then
         Self.Analyze_callchain_Start_Tag (Atts);

      elsif Local_Name = "column" then
         Self.Analyze_column_Start_Tag (Atts);

      elsif Local_Name = "cycle" then
         Self.Analyze_cycle_Start_Tag (Atts);

      elsif Local_Name = "cycleset" then
         Self.Analyze_cycleset_Start_Tag (Atts);

      elsif Local_Name = "entry" then
         Self.Analyze_entry_Start_Tag (Atts);

      elsif Local_Name = "entryset" then
         Self.Analyze_entryset_Start_Tag (Atts);

      elsif Local_Name = "external" then
         Self.Analyze_external_Start_Tag (Atts);

      elsif Local_Name = "externalset" then
         Self.Analyze_externalset_Start_Tag (Atts);

      elsif Local_Name = "file" then
         Self.Analyze_file_Start_Tag (Atts);

      elsif Local_Name = "global" then
         Self.Analyze_global_Start_Tag (Atts);

      elsif Local_Name = "globalstackusage" then
         Self.Analyze_globalstackusage_Start_Tag (Atts);

      elsif Local_Name = "indirect" then
         Self.Analyze_indirect_Start_Tag (Atts);

      elsif Local_Name = "indirectcall" then
         Self.Analyze_indirectcall_Start_Tag (Atts);

      elsif Local_Name = "indirectcallset" then
         Self.Analyze_indirectcallset_Start_Tag (Atts);

      elsif Local_Name = "indirectset" then
         Self.Analyze_indirectset_Start_Tag (Atts);

      elsif Local_Name = "line" then
         Self.Analyze_line_Start_Tag (Atts);

      elsif Local_Name = "localstackusage" then
         Self.Analyze_localstackusage_Start_Tag (Atts);

      elsif Local_Name = "location" then
         Self.Analyze_location_Start_Tag (Atts);

      elsif Local_Name = "locationset" then
         Self.Analyze_locationset_Start_Tag (Atts);

      elsif Local_Name = "object" then
         Self.Analyze_object_Start_Tag (Atts);

      elsif Local_Name = "prefixname" then
         Self.Analyze_prefixname_Start_Tag (Atts);

      elsif Local_Name = "qualifier" then
         Self.Analyze_qualifier_Start_Tag (Atts);

      elsif Local_Name = "size" then
         Self.Analyze_size_Start_Tag (Atts);

      elsif Local_Name = "subprogram" then
         Self.Analyze_subprogram_Start_Tag (Atts);

      elsif Local_Name = "subprogramcalledset" then
         Self.Analyze_subprogramcalledset_Start_Tag (Atts);

      elsif Local_Name = "subprogramname" then
         Self.Analyze_subprogramname_Start_Tag (Atts);

      elsif Local_Name = "subprogramset" then
         Self.Analyze_subprogramset_Start_Tag (Atts);

      elsif Local_Name = "unbounded" then
         Self.Analyze_unbounded_Start_Tag (Atts);

      elsif Local_Name = "unboundedobject" then
         Self.Analyze_unboundedobject_Start_Tag (Atts);

      elsif Local_Name = "unboundedobjectset" then
         Self.Analyze_unboundedobjectset_Start_Tag (Atts);

      elsif Local_Name = "unboundedset" then
         Self.Analyze_unboundedset_Start_Tag (Atts);

      elsif Local_Name = "value" then
         pragma Assert (Self.State.Kind in Value_Kinds);
         pragma Assert (not Self.State.Value_Tag);

         Self.State.Value_Tag := True;

      else
         raise Program_Error with "Unexpected element '" & Local_Name & ''';
      end if;
   end Start_Element;

end GNATStack.Readers;
