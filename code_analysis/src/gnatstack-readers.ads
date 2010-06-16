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

private with Ada.Containers.Hashed_Maps;
with Ada.Containers.Hashed_Sets;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;

private with Sax.Attributes;
with Sax.Readers;
private with Unicode.CES;

package GNATStack.Readers is

   type Reader is new Sax.Readers.Reader with private;

   type Stack_Usage_Information is record
      Size      : Integer;
      Qualifier : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   type Subprogram_Location is record
      Name   : Ada.Strings.Unbounded.Unbounded_String;
      File   : Ada.Strings.Unbounded.Unbounded_String;
      Line   : Positive;
      Column : Positive;
   end record;

   function Hash
     (Item : Subprogram_Location) return Ada.Containers.Hash_Type;

   package Subprogram_Location_Sets is
     new Ada.Containers.Hashed_Sets (Subprogram_Location, Hash, "=");

   type Subprogram_Identifier is record
      Prefix_Name : Ada.Strings.Unbounded.Unbounded_String;
      Locations   : Subprogram_Location_Sets.Set;
   end record;

   type Object_Information is record
      Name   : Ada.Strings.Unbounded.Unbounded_String;
      File   : Ada.Strings.Unbounded.Unbounded_String;
      Line   : Positive;
      Column : Positive;
   end record;

   package Object_Information_Vectors is
     new Ada.Containers.Vectors (Positive, Object_Information);

   type Indirect_Call_Information is record
      File : Ada.Strings.Unbounded.Unbounded_String;
      Line : Positive;
   end record;

   package Indirect_Call_Information_Vectors is
     new Ada.Containers.Vectors (Positive, Indirect_Call_Information);

   type Subprogram_Information;
   type Subprogram_Information_Access is access all Subprogram_Information;

   function Hash
     (Item : Subprogram_Information_Access) return Ada.Containers.Hash_Type;

   function Equivalent_Elements
     (Left  : Subprogram_Information_Access;
      Right : Subprogram_Information_Access) return Boolean;

   package Subprogram_Information_Vectors is
     new Ada.Containers.Vectors (Positive, Subprogram_Information_Access);

   package Subprogram_Information_Vector_Vectors is
     new Ada.Containers.Vectors
       (Positive,
        Subprogram_Information_Vectors.Vector,
        Subprogram_Information_Vectors."=");

   package Subprogram_Information_Sets is
     new Ada.Containers.Hashed_Sets
       (Subprogram_Information_Access, Hash, Equivalent_Elements);

   type Subprogram_Information is record
      Identifier   : Subprogram_Identifier;
      Global_Usage : Stack_Usage_Information;
      Local_Usage  : Stack_Usage_Information;
      Calls        : Subprogram_Information_Sets.Set;
      Unbounded    : Object_Information_Vectors.Vector;
      Indirects    : Indirect_Call_Information_Vectors.Vector;

      --  For entry subprograms

      Is_Entry     : Boolean := False;
      Entry_Usage  : Stack_Usage_Information;
      Chain        : Subprogram_Information_Vectors.Vector;

      --  For external subprograms

      Is_External  : Boolean := False;
   end record;

   type Analysis_Information is record
      Accurate       : Boolean;
      Subprogram_Set : Subprogram_Information_Sets.Set;
      Unbounded_Set  : Subprogram_Information_Sets.Set;
      External_Set   : Subprogram_Information_Sets.Set;
      Indirect_Set   : Subprogram_Information_Sets.Set;
      Cycle_Set      : Subprogram_Information_Vector_Vectors.Vector;
      Entry_Set      : Subprogram_Information_Sets.Set;
   end record;

private

   function Hash
     (Item : Subprogram_Identifier) return Ada.Containers.Hash_Type;

   package Subprogram_Information_Maps is
     new Ada.Containers.Hashed_Maps
       (Subprogram_Identifier, Subprogram_Information_Access, Hash, "=");

   type Parser_State_Kinds is
     (None_State,
      Subprogram_Set_State,
      Subprogram_Called_Set_State,
      Location_Set_State,
      Location_State,
      Entry_Set_State,
      Entry_State,
      Cycle_Set_State,
      Cycle_State,
      Unbounded_Set_State,
      Unbounded_State,
      Unbounded_Object_State,
      External_Set_State,
      External_State,
      Indirect_Set_State,
      Indirect_State,
      Indirect_Call_State,
      Subprogram_State,
      Stack_Usage_State,
      Boolean_Value_State,
      Integer_Value_State,
      String_Value_State);

   subtype Value_Kinds is Parser_State_Kinds
     range Boolean_Value_State .. String_Value_State;

   type Parser_State (Kind : Parser_State_Kinds := None_State) is record
      case Kind is
         when None_State =>
            null;

         when Subprogram_Set_State =>
            null;

         when Cycle_Set_State =>
            null;

         when Unbounded_Set_State =>
            null;

         when External_Set_State =>
            null;

         when Entry_Set_State =>
            null;

         when Indirect_Set_State =>
            null;

         when Indirect_Call_State =>
            Indirect : Indirect_Call_Information;

         when Subprogram_Called_Set_State =>
            Called_Set : Subprogram_Information_Sets.Set;

         when Location_Set_State =>
            Location_Set : Subprogram_Location_Sets.Set;

         when Unbounded_Object_State =>
            Object : Object_Information;

         when Entry_State =>
            C_Prefix_Name : Ada.Strings.Unbounded.Unbounded_String;
            C_Locations   : Subprogram_Location_Sets.Set;
            Entry_Usage   : Stack_Usage_Information;
            Chain         : Subprogram_Information_Vectors.Vector;

         when External_State =>
            E_Prefix_Name : Ada.Strings.Unbounded.Unbounded_String;
            E_Locations   : Subprogram_Location_Sets.Set;

         when Indirect_State =>
            I_Prefix_Name : Ada.Strings.Unbounded.Unbounded_String;
            I_Locations   : Subprogram_Location_Sets.Set;
            I_Subprogram  : Subprogram_Information_Access;

         when Subprogram_State =>
            S_Prefix_Name : Ada.Strings.Unbounded.Unbounded_String;
            S_Locations   : Subprogram_Location_Sets.Set;
            Is_Reference  : Boolean;
            Global_Usage  : Stack_Usage_Information;
            Local_Usage   : Stack_Usage_Information;
            Calls         : Subprogram_Information_Sets.Set;

         when Location_State =>
            Location : Subprogram_Location;

         when Cycle_State =>
            Cycle : Subprogram_Information_Vectors.Vector;

         when Unbounded_State =>
            U_Prefix_Name : Ada.Strings.Unbounded.Unbounded_String;
            U_Locations   : Subprogram_Location_Sets.Set;
            U_Subprogram  : Subprogram_Information_Access;

         when Stack_Usage_State =>
            Stack_Usage : Stack_Usage_Information;

         when Value_Kinds =>
            Value_Tag : Boolean := False;

            case Kind is
               when Boolean_Value_State =>
                  Boolean_Value : Boolean;

               when Integer_Value_State =>
                  Integer_Value : Integer;

               when String_Value_State =>
                  String_Value : Ada.Strings.Unbounded.Unbounded_String;

               when others =>
                  null;
            end case;
      end case;
   end record;

   package Parser_State_Vectors is
     new Ada.Containers.Vectors (Positive, Parser_State);

   type Reader is new Sax.Readers.Reader with record
      State          : Parser_State;
      Stack          : Parser_State_Vectors.Vector;
      Subprogram_Map : Subprogram_Information_Maps.Map;
      Analysis       : Analysis_Information;
   end record;

   function Resolve_Or_Create
     (Self       : not null access Reader;
      Identifier : Subprogram_Identifier)
      return Subprogram_Information_Access;
   --  Resolves subprogram information record or creates new one.

   procedure Push (Self : in out Reader);
   --  Saves parser's current state into the stack. Current state is resetted
   --  to None.

   procedure Pop (Self : in out Reader);
   --  Sets parser's state from the stack. Previous state is lost.

   procedure Analyze_accurate_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyzes start tag of "accurate" element

   procedure Analyze_accurate_End_Tag (Self : in out Reader);
   --  Analyzes end tag of "accurate" element

   procedure Analyze_callchain_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyzes start tag of "callchain" element

   procedure Analyze_callchain_End_Tag (Self : in out Reader);
   --  Analyzes end tag of "callchain" element

   procedure Analyze_column_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyzes start tag of "column" element

   procedure Analyze_column_End_Tag (Self : in out Reader);
   --  Analyzes end tag of "column" element

   procedure Analyze_cycle_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyzes start tag of "cycle" element

   procedure Analyze_cycle_End_Tag (Self : in out Reader);
   --  Analyzes end tag of "cycle" element

   procedure Analyze_cycleset_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyzes start tag of "cycleset" element

   procedure Analyze_cycleset_End_Tag (Self : in out Reader);
   --  Analyzes end tag of "cycleset" element

   procedure Analyze_entry_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyzes start tag of "entry" element

   procedure Analyze_entry_End_Tag (Self : in out Reader);
   --  Analyzes end tag of "entry" element

   procedure Analyze_entryset_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyzes start tag of "entryset" element

   procedure Analyze_entryset_End_Tag (Self : in out Reader);
   --  Analyzes end tag of "entryset" element

   procedure Analyze_external_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyzes start tag of "external" element

   procedure Analyze_external_End_Tag (Self : in out Reader);
   --  Analyzes end tag of "external" element

   procedure Analyze_externalset_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyzes start tag of "externalset" element

   procedure Analyze_externalset_End_Tag (Self : in out Reader);
   --  Analyzes end tag of "externalset" element

   procedure Analyze_file_Start_Tag
     (Self       : in out Reader'Class;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyzes start tag of "file" element

   procedure Analyze_file_End_Tag (Self : in out Reader);
   --  Analyzes end tag of "file" element

   procedure Analyze_global_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyzes start tag of "global" element

   procedure Analyze_global_End_Tag (Self : in out Reader);
   --  Analyzes end tag of "global" element

   procedure Analyze_globalstackusage_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyze start tag of "globalstackusage" element

   procedure Analyze_globalstackusage_End_Tag (Self : in out Reader);
   --  Analyzes end tag of "globalstackusage" element

   procedure Analyze_indirect_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyzes start tag of "indirect" element

   procedure Analyze_indirect_End_Tag (Self : in out Reader);
   --  Analyzes end tag of "indirect" element

   procedure Analyze_indirectcall_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyzes start tag of "indirectcall" element

   procedure Analyze_indirectcall_End_Tag (Self : in out Reader);
   --  Analyzes end tag of "indirectcall" element

   procedure Analyze_indirectcallset_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyzes start tag of "indirectcallset" element

   procedure Analyze_indirectcallset_End_Tag (Self : in out Reader);
   --  Analyzes end tag of "indirectcallset" element

   procedure Analyze_indirectset_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyzes start tag of "indirectset" element

   procedure Analyze_indirectset_End_Tag (Self : in out Reader);
   --  Analyzes end tag of "indirectset" element

   procedure Analyze_line_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyzes start tag of "line" element

   procedure Analyze_line_End_Tag (Self : in out Reader);
   --  Analyzes end tag of "line" element

   procedure Analyze_localstackusage_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyzes start tag of "localstackusage" element.

   procedure Analyze_localstackusage_End_Tag (Self : in out Reader);
   --  Analyzes end tag of "localstackusage" element

   procedure Analyze_location_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyzes start tag of "location" element

   procedure Analyze_location_End_Tag (Self : in out Reader);
   --  Analyzes end tag of "location" element

   procedure Analyze_locationset_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyzes start tag of "locationset" element

   procedure Analyze_locationset_End_Tag (Self : in out Reader);
   --  Analyzes end tag of "locationset" element

   procedure Analyze_object_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyzes start tag of "object" element

   procedure Analyze_object_End_Tag (Self : in out Reader);
   --  Analyzes end tag of "object" element

   procedure Analyze_prefixname_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyzes start tag of "prefixname" element

   procedure Analyze_prefixname_End_Tag (Self : in out Reader);
   --  Analyzes end tag of "prefixname" element

   procedure Analyze_qualifier_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyzes start tag of "qualifier" element

   procedure Analyze_qualifier_End_Tag (Self : in out Reader);
   --  Analyzes end tag of "qualifier" element

   procedure Analyze_size_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyzes start tag of "size" element

   procedure Analyze_size_End_Tag (Self : in out Reader);
   --  Analyzes end tag of "size" element

   procedure Analyze_subprogram_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyzes start tag of "subprogram" element

   procedure Analyze_subprogram_End_Tag (Self : in out Reader);
   --  Analyzes end tag of "subprogram" element

   procedure Analyze_subprogramcalledset_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyze start tag of "subprogramcalledset" element

   procedure Analyze_subprogramcalledset_End_Tag (Self : in out Reader);
   --  Analyzes end tag of "subprogramcalledset" element

   procedure Analyze_subprogramname_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyzes start tag of "subprogramname" element

   procedure Analyze_subprogramname_End_Tag (Self : in out Reader);
   --  Analyzes end tag of "subprogramname" element

   procedure Analyze_subprogramset_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyzes start tag of "subprogramset" element

   procedure Analyze_subprogramset_End_Tag (Self : in out Reader);
   --  Analyze end tag of "subprogramset" element

   procedure Analyze_unbounded_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyzes start tag of "unbounded" element

   procedure Analyze_unbounded_End_Tag (Self : in out Reader);
   --  Analyze end tag of "unbounded" element

   procedure Analyze_unboundedobject_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyzes start tag of "unboundedobject" element

   procedure Analyze_unboundedobject_End_Tag (Self : in out Reader);
   --  Analyze end tag of "unboundedobject" element

   procedure Analyze_unboundedobjectset_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyzes start tag of "unboundedobjectset" element

   procedure Analyze_unboundedobjectset_End_Tag (Self : in out Reader);
   --  Analyze end tag of "unboundedobjectset" element

   procedure Analyze_unboundedset_Start_Tag
     (Self       : in out Reader;
      Attributes : Sax.Attributes.Attributes'Class);
   --  Analyzes start tag of "unboundedset" element

   procedure Analyze_unboundedset_End_Tag (Self : in out Reader);
   --  Analyze end tag of "unboundedset" element

   --  Overrided subprogram

   overriding procedure Start_Element
     (Self          : in out Reader;
      Namespace_URI : Unicode.CES.Byte_Sequence := "";
      Local_Name    : Unicode.CES.Byte_Sequence := "";
      Qname         : Unicode.CES.Byte_Sequence := "";
      Atts          : Sax.Attributes.Attributes'Class);

   overriding procedure End_Element
     (Self          : in out Reader;
      Namespace_URI : Unicode.CES.Byte_Sequence := "";
      Local_Name    : Unicode.CES.Byte_Sequence := "";
      Qname         : Unicode.CES.Byte_Sequence := "");

   overriding procedure Characters
     (Self : in out Reader;
      Text : Unicode.CES.Byte_Sequence);

end GNATStack.Readers;
