-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                        Copyright (C) 2003                         --
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

with Ada.Calendar;
with GNAT.OS_Lib;
with HTables;
with Tries;
with VFS;
with Dynamic_Arrays;
with Projects;

--  This package contains the list of all files and entities used in the
--  current project.
--  Some notes about reference counting: this structure provides reference
--  counting for all the public structures. However, this reference counting is
--  reserved for users of these structures and not used internally.

package Entities is

   type Source_File_Record is tagged private;
   type Source_File is access Source_File_Record'Class;

   type LI_Handler_Record is abstract tagged limited private;
   type LI_Handler is access all LI_Handler_Record'Class;
   --  General type to handle and generate Library Information data (for
   --  cross-references, and the various queries for the browsers).
   --  Derived types should be created for all the languages supported.

   -----------------------
   -- Entities_Database --
   -----------------------

   type Entities_Database is private;

   function Create return Entities_Database;
   --  Return a new empty database

   procedure Destroy (Db : in out Entities_Database);
   --  Free the memory occupied by Db

   function Get_LI_Handler
     (Db              : Entities_Database;
      Source_Filename : VFS.Virtual_File) return LI_Handler;
   --  Return the LI_Handler to use to get the cross-reference information for
   --  that file.

   procedure Register_Language_Handler
     (Db : Entities_Database; Handler : LI_Handler);
   --  Register a new language handler

   ------------
   -- E_Kind --
   ------------

   type E_Kinds is
     (Overloaded_Entity,
      --  This special kind of entity is used for overloaded symbols that
      --  couldn't be resolved by the parser. See the comment at the beginning
      --  of the private part for a more complete explanation.

      Unresolved_Entity,
      --  This special kind indicates that we do not know the exact kind of
      --  entity. This can happen for instance in C, in the following case:
      --     typedef old_type new_type;
      --  but old_type is defined nowhere in the closure of the include files.

      Access_Kind,
      Array_Kind,
      Boolean_Kind,
      Class_Wide,
      Class,
      Decimal_Fixed_Point,
      Entry_Or_Entry_Family,
      Enumeration_Literal,
      Enumeration_Kind,
      Exception_Entity,
      Floating_Point,
      Label_On_Block,
      Label_On_Loop,
      Label_On_Statement,
      Modular_Integer,
      Named_Number,
      Function_Or_Operator,
      Package_Kind,
      Procedure_Kind,
      Ordinary_Fixed_Point,
      Private_Type,
      Protected_Kind,
      Record_Kind,
      Signed_Integer,
      String_Kind,
      Task_Kind);
   --  The entity kind (sorted by alphabetical order).
   --
   --  Note that Boolean is treated in a special way: it is treated as
   --  Boolean_Type/Object, rather than as an Enumeration_Type/Object.

   type E_Kind is record
      Kind        : E_Kinds;
      Is_Generic  : Boolean;
      Is_Type     : Boolean;
      Is_Abstract : Boolean;
   end record;
   --  Description for the type of an entity.
   --  Kind describes its general family.
   --  Is_Generic is set to true if this is a generic entity (or a template in
   --  the C++ case).
   --  Is_Type is true if this is a type, instead of an instance of a type.

   Unresolved_Entity_Kind : constant E_Kind :=
     (Unresolved_Entity, False, False, False);

   --------------------
   -- Reference_Kind --
   --------------------

   type Reference_Kind is
     (Reference,
      Modification,
      Instantiation_Reference,
      Body_Entity,
      Completion_Of_Private_Or_Incomplete_Type,
      Discriminant,
      Type_Extension,
      Implicit,
      Primitive_Operation,
      Overriding_Primitive_Operation,
      With_Line,
      Label,
      Subprogram_In_Parameter,
      Subprogram_In_Out_Parameter,
      Subprogram_Out_Parameter,
      Subprogram_Access_Parameter,
      Formal_Generic_Parameter,
      Parent_Package,
      End_Of_Spec,
      End_Of_Body);
   --  The kind of reference to an entity. They have the following meaning:
   --    - Reference: The entity is used
   --    - Modification: The value of the entity is changed
   --    - Instantiation_Reference: Reference to the instantiation of a
   --      generic.
   --    - Body_Entity: Used for spec entities that are repeated in a body,
   --      including the unit name itself, and the formals in the case of
   --      a subprogram. Also used for entry-names in accept statements.
   --    - Completion_Of_Private_Or_Incomplete_Type: Used to mark the
   --      completion of a private type or incomplete type
   --    - type_Extension: Used to mark the reference as the entity from
   --      which a tagged type is extended.
   --    - Implicit: Used to identify a reference to the entity in a generic
   --      actual or in a default in a call.
   --    - Label: Used for cases where the name of the entity appears in
   --      syntactic constructs only, but doesn't impact the code, for instance
   --      in "end Foo;" constructs in Ada.
   --    - End_Of_Spec: Used to identify the end of the following constructs.
   --      Block statement, loop statement, package specification, task
   --      definition, protected definition, record definition.
   --    - End_Of_Body: Used to identify the end of the following constructs.
   --      Subprogram body, package body, task body, entry body, protected
   --      body, accept statement.
   --    - Primitive_Operation: used for primitive operations of tagged types
   --      (in Ada), or for methods (in C++).
   --    - Overriding_Primitive_Operation is used for primitive operations
   --      that override one of the inherited operations from the parent (for
   --      instance A derives from B and both define the operation foo() with
   --      the same profile, foo() will be marked as an overriding primitive
   --      operation for B.
   --    - Subprogram_*_Parameter: for a subprogram declaration, references all
   --      its parameters, along with their passing mode ("in", "in out", ...)
   --    - Formal_Generic_Parameter: for a generic, reference its format
   --      parameters.
   --    - Parent_Package: for a child Ada package, reference its parent. This
   --      parent, in turn, references its own parent package.
   --    - Discriminant: points to the declaration of the discriminants for
   --      this type.

   function Is_End_Reference (Kind : Reference_Kind) return Boolean;
   pragma Inline (Is_End_Reference);
   --  Whether Kind represents a reference that indicates the end of scope for
   --  an entity (either for its spec or its body)

   -------------
   -- LI_File --
   -------------

   type LI_File_Record is tagged private;
   type LI_File is access LI_File_Record'Class;

   function Get_LI_Filename (LI : LI_File) return VFS.Virtual_File;
   --  Return the name of the file

   procedure Unref (LI : in out LI_File);
   procedure Ref   (LI : LI_File);
   --  Change reference counting for the file. When it reaches 0, the memory
   --  is freed.

   procedure Reset (LI : LI_File);
   --  Indicate that the parsed contents of LI is no longer valid. All
   --  associated cross-references are removed from the table.

   function Get_Or_Create
     (Db        : Entities_Database;
      File      : VFS.Virtual_File;
      Project   : Projects.Project_Type) return LI_File;
   --  Get (or create) a new entry for File in the database. If an entry
   --  already exists, it is returned.
   --  You need to Ref the entry if you intend to keep it in a separate
   --  structure.

   procedure Update_Timestamp
     (LI : LI_File; Timestamp : Ada.Calendar.Time := VFS.No_Time);
   pragma Inline (Update_Timestamp);
   --  Update the timestamp that indicates when LI was last parsed

   function Get_Project (LI : LI_File) return Projects.Project_Type;
   pragma Inline (Get_Project);
   --  Return the project to which LI belongs

   function Get_Database (LI : LI_File) return Entities_Database;
   pragma Inline (Get_Database);
   --  Return the global LI database to which LI belongs

   function Get_Timestamp (LI : LI_File) return Ada.Calendar.Time;
   pragma Inline (Get_Timestamp);
   --  Return the timestamp last set through Update_Timestamp

   -----------------
   -- Source_File --
   -----------------

   function Get_Filename (File : Source_File) return VFS.Virtual_File;
   pragma Inline (Get_Filename);
   --  Return the name of the file file

   function Get_LI (File : Source_File) return LI_File;
   pragma Inline (Get_LI);
   --  Return the LI file that contains the information for File.
   --  null can be returned if the information is not known.

   function Get_Database (File : Source_File) return Entities_Database;
   pragma Inline (Get_Database);
   --  Return the global LI database to which LI belongs

   procedure Unref (F : in out Source_File);
   procedure Ref   (F : Source_File);
   --  Change reference counting for the file. When it reaches 0, the memory
   --  is freed.

   function Get_Or_Create
     (Db           : Entities_Database;
      File         : VFS.Virtual_File;
      LI           : LI_File := null;
      Timestamp    : Ada.Calendar.Time := VFS.No_Time;
      Allow_Create : Boolean := True) return Source_File;
   --  Get or create a Source_File corresponding to File.
   --  If there is already an entry for it in the database, the corresponding
   --  Source_File is returned, and the timestamp is adjusted if the
   --  parameter is not No_Time. Otherwise, a new entry is added.
   --  You need to Ref the entry if you intend to keep it in a separate
   --  structure.
   --  The cross-references for this file are not updated. You need to call
   --  Update_Xref if needed.
   --  The file is automatically added to the list of files for that LI.

   procedure Update_Xref (File : Source_File);
   --  Update the cross-reference information for File, if the information on
   --  the disk is more up-to-date

   procedure Add_Depends_On
     (File                : Source_File;
      Depends_On          : Source_File;
      Explicit_Dependency : Boolean := False);
   --  Add a new dependency to File. Nothing is done if the dependency has
   --  already been registered.
   --  File is automatically added to the list of files that Depends_On
   --  imports.
   --  If Explicit_Dependency is true, this indicates an explicit #include
   --  or with statement in the file.

   procedure Reset (File : Source_File);
   --  Indicate that the parsed contents of File is no longer valid. All
   --  associated cross-references are removed from the table.

   function Get_Predefined_File (Db : Entities_Database) return Source_File;
   --  Returns a special source file, which should be used for all
   --  predefined entities of the languages

   -------------------
   -- File_Location --
   -------------------

   type File_Location is record
      File   : Source_File;
      Line   : Natural;
      Column : Natural;
   end record;
   No_File_Location : constant File_Location := (null, 0, 0);

   ------------------------
   -- Entity_Information --
   ------------------------

   type Entity_Information_Record is tagged private;
   type Entity_Information is access Entity_Information_Record'Class;

   procedure Unref (Entity : in out Entity_Information);
   procedure Ref   (Entity : Entity_Information);
   --  Change reference counting for the file. When it reaches 0, the memory
   --  is freed.

   function Get_Or_Create
     (Db     : Entities_Database;
      Name   : String;
      File   : Source_File;
      Line   : Natural;
      Column : Natural) return Entity_Information;
   --  Get an existing or create a new declaration for an entity. File, Line
   --  and column are the location of irs declaration.

   procedure Get_End_Of_Scope
     (Entity   : Entity_Information;
      Location : out File_Location;
      Kind     : out Reference_Kind);
   --  Return the current end of scope for the entity

   ----------------------
   -- Setting entities --
   ----------------------
   --  The following subprogram is used to create new entities and their
   --  properties.

   procedure Set_Kind (Entity : Entity_Information; Kind : E_Kind);
   procedure Set_End_Of_Scope
     (Entity   : Entity_Information;
      Location : File_Location;
      Kind     : Reference_Kind);
   procedure Set_Is_Renaming_Of
     (Entity : Entity_Information; Renaming_Of : Entity_Information);
   --  Override some information for the entity.

   procedure Add_Reference
     (Entity   : Entity_Information;
      Location : File_Location;
      Kind     : Reference_Kind);
   --  Add a new reference to the entity. No Check is done whether this
   --  reference already exists.

   procedure Set_Type_Of
     (Entity : Entity_Information; Is_Of_Type : Entity_Information);
   --  Specifies the type of a variable. If Entity is a type, this also
   --  registers it as a child of Is_Of_Type for faster lookup. Multiple
   --  parents are supported.

   procedure Add_Primitive_Subprogram
     (Entity : Entity_Information; Primitive : Entity_Information);
   --  Add a new primitive operation to Entity

   procedure Set_Pointed_Type
     (Entity : Entity_Information; Points_To : Entity_Information);
   --  For an access type, indicates which type it points to

   procedure Set_Returned_Type
     (Entity : Entity_Information; Returns : Entity_Information);
   --  Stores the type returned by a subprogram

   -------------
   -- Queries --
   -------------

   function Is_Subprogram (Entity : Entity_Information) return Boolean;
   --  Return True if Entity is associated with a subprograms

   ----------------
   -- Scope_Tree --
   ----------------

   type Scope_Tree is private;

   ----------------
   -- LI_Handler --
   ----------------

   procedure Destroy (Handler : in out LI_Handler_Record);
   procedure Destroy (Handler : in out LI_Handler);
   --  Free the memory occupied by Handler. By default, this does nothing

   function Get_Source_Info
     (Handler         : access LI_Handler_Record;
      Source_Filename : VFS.Virtual_File) return Source_File is abstract;
   --  Return a handle to the source file structure corresponding to
   --  Source_Filename. If necessary, the LI file is parsed from the disk to
   --  update the internal structure.

   function Case_Insensitive_Identifiers
     (Handler         : access LI_Handler_Record) return Boolean is abstract;
   --  Return True if the language associated with Handler is case-insensitive.
   --  Note that for case insensitive languages, the identifier names must be
   --  storer in lower cases in the LI structure.

   procedure Parse_All_LI_Information
     (Handler         : access LI_Handler_Record;
      Project         : Projects.Project_Type;
      In_Directory    : String := "") is abstract;
   --  Parse all the existing LI information for all the files in Project.
   --  The search is limited to files in In_Directory if this isn't the
   --  empty string.

private

   ----------------
   -- Scope_Tree --
   ----------------

   type Scope_Tree_Node;
   type Scope_Tree is access Scope_Tree_Node;
   type Scope_Tree_Node is record
      Sibling  : Scope_Tree;
      Parent   : Scope_Tree;
      Entity   : Entity_Information;
      --  The entity addressed by this node

      Contents : Scope_Tree;
      --  The first entity referenced under that node.

      Location : File_Location;
      --  The precise location we are talking about. If
      --  Location = Entity.Declaration, we are in a node describing the
      --  declaration of an entity.
   end record;

   procedure Destroy (Tree : in out Scope_Tree);
   --  Free the memory occupied by the scope tree

   -----------------------------
   -- Entity_Information_List --
   -----------------------------

   package Entity_Information_Arrays is new Dynamic_Arrays
     (Data                    => Entity_Information,
      Table_Multiplier        => 1,
      Table_Minimum_Increment => 10,
      Table_Initial_Size      => 5);
   subtype Entity_Information_List is Entity_Information_Arrays.Instance;
   Null_Entity_Information_List : constant Entity_Information_List :=
     Entity_Information_Arrays.Empty_Instance;

   function Find
     (List   : Entity_Information_List; Loc : File_Location)
      return Entity_Information;
   --  Return entity declared at Loc, or null if there is no such entity

   ---------------------
   -- References_List --
   ---------------------

   type Entity_Reference is record
      Location : File_Location;
      Kind     : Reference_Kind;
   end record;
   No_Entity_Reference : constant Entity_Reference :=
     (No_File_Location, Reference);

   package Entity_Reference_Arrays is new Dynamic_Arrays
     (Data                    => Entity_Reference,
      Table_Multiplier        => 1,
      Table_Minimum_Increment => 10,
      Table_Initial_Size      => 5);
   subtype Entity_Reference_List is Entity_Reference_Arrays.Instance;
   Null_Entity_Reference_List : constant Entity_Reference_List :=
     Entity_Reference_Arrays.Empty_Instance;

   ------------------------
   -- Entity_Information --
   ------------------------

   type Entity_Information_Record is tagged record
      Name                  : GNAT.OS_Lib.String_Access;
      Kind                  : E_Kind;

      Declaration           : File_Location;
      --  The location of the declaration for this entity.

      End_Of_Scope          : Entity_Reference;
      --  The location at which the declaration of this entity ends. This is
      --  used for all entites that contain other entities (records, C++
      --  classes, packages,...)
      --  The handling of end_of_scope is the following: if the entity
      --  has only one of these, it is stored in its declaration. If
      --  the entity has two of these (spec+body of a package for
      --  instance, only the one for the body is stored). However, in
      --  the latter case we need to save the end-of-scope for the
      --  spec in the standard list of references so that scope_trees
      --  can be generated.

      Parent_Types          : Entity_Information_List;
      Pointed_Type          : Entity_Information;
      Returned_Type         : Entity_Information;
      Primitive_Op_Of       : Entity_Information;
      --  These contain information for parent types, supertypes, pointed
      --  types, type of entity contained in an array or returned type for
      --  a function.
      --  It also contains a pointer to the class for which this entity is
      --  a primitive operation
      --  ??? These could be collapsed into a single list, depending on the
      --  kind of the current entity.

      Rename                : Entity_Information;
      --  The entity that this one renames.

      Primitive_Subprograms : Entity_Information_List;

      Child_Types           : Entity_Information_List;
      --  All the types derives from this one.

      References            : Entity_Reference_List;
      --  All the references to this entity in the parsed files

      Ref_Count             : Natural := 1;
      --  The reference count for this entity. When it reaches 0, the entity
      --  is released from memory.
   end record;

   --------------------
   -- Entities_Table --
   --------------------

   type Entity_Information_List_Access is access Entity_Information_List;

   function Get_Name (D : Entity_Information) return GNAT.OS_Lib.String_Access;
   function Get_Name
     (D : Entity_Information_List_Access) return GNAT.OS_Lib.String_Access;
   --  Return the name of the first entity in the list

   procedure Destroy (D : in out Entity_Information_List_Access);

   package Entities_Tries is new Tries
     (Data_Type => Entity_Information_List_Access,
      No_Data   => null,
      Get_Index => Get_Name,
      Free      => Destroy);
   --  Each node in the tree contains all the entities with the same name.

   procedure Add (Entities         : in out Entities_Tries.Trie_Tree;
                  Entity           : Entity_Information;
                  Check_Duplicates : Boolean);
   --  Add a new entity, if not already there, to D

   procedure Remove  (D : in out Entities_Tries.Trie_Tree;
                      E : Entity_Information);
   --  Remove the information for a specific entity from the table.

   ----------------------
   -- Source_File_List --
   ----------------------

   package Source_File_Arrays is new Dynamic_Arrays
     (Data                    => Source_File,
      Table_Multiplier        => 1,
      Table_Minimum_Increment => 10,
      Table_Initial_Size      => 5);
   subtype Source_File_List is Source_File_Arrays.Instance;
   Null_Source_File_List : constant Source_File_List :=
     Source_File_Arrays.Empty_Instance;

   type File_Dependency is record
      File     : Source_File;
      Explicit : Boolean;
   end record;

   package Dependency_Arrays is new Dynamic_Arrays
     (Data                    => File_Dependency,
      Table_Multiplier        => 1,
      Table_Minimum_Increment => 10,
      Table_Initial_Size      => 5);
   subtype Dependency_List is Dependency_Arrays.Instance;
   Null_Dependency_List : constant Dependency_List :=
     Dependency_Arrays.Empty_Instance;

   procedure Remove (E : in out Dependency_List; File : Source_File);
   --  Remove the first dependency that mentions File

   -----------------
   -- Source_File --
   -----------------

   type Source_File_Record is tagged record
      Db           : Entities_Database;

      Timestamp    : Ada.Calendar.Time := VFS.No_Time;
      --  The timestamp of the file at the time it was parsed. This is left
      --  to No_Time if the file has never been parsed.

      Name        : VFS.Virtual_File;

      Entities    : Entities_Tries.Trie_Tree;
      --  All the entities defined in the source file

      Depends_On  : Dependency_List;
      Depended_On : Source_File_List;
      --  The list of dependencies on or from this file

      Scope       : Scope_Tree;
      --  The scope tree for this file. This is created on-demand the first
      --  time it is needed.

      LI          : LI_File;
      --  The LI file used to parse the file. This might be left to null if
      --  the file was created appart from parsing a LI file.

      All_Entities : Entities_Tries.Trie_Tree;
      --  The list of all entities referenced in the file, and that are defined
      --  in other files.
      --  ??? This could be computed by traversing all the files in Depends_On,
      --  and check whether their entities have references in the current file.

      Ref_Count   : Integer := 0;
      Is_Valid    : Boolean;
      --  The reference counter. If Is_Valid is True, this indicates that the
      --  information for that file is not up-to-date and not available.
   end record;

   -----------------
   -- Files_Table --
   -----------------

   type HTable_Header is new Natural range 0 .. 3000;
   function Hash (Key : VFS.Virtual_File) return HTable_Header;

   package Files_HTable is new HTables.Simple_HTable
     (Header_Num   => HTable_Header,
      Element      => Source_File,
      Free_Element => Unref,
      No_Element   => null,
      Key          => VFS.Virtual_File,
      Hash         => Hash,
      Equal        => VFS."=");

   -------------
   -- LI_File --
   -------------

   type LI_File_Record is tagged record
      Db        : Entities_Database;

      Name      : VFS.Virtual_File;
      Timestamp : Ada.Calendar.Time := VFS.No_Time;

      Project   : Projects.Project_Type;

      Files     : Source_File_List;
      --  All the files for which xref is provided by this LI_File.

      Ref_Count : Natural := 1;
      --  The reference counter
   end record;

   --------------
   -- LI_Table --
   --------------

   package LI_HTable is new HTables.Simple_HTable
     (Header_Num   => HTable_Header,
      Element      => LI_File,
      Free_Element => Unref,
      No_Element   => null,
      Key          => VFS.Virtual_File,
      Hash         => Hash,
      Equal        => VFS."=");

   -----------------------
   -- Entities_Database --
   -----------------------

   type Entities_Database_Record is record
      Entities : Entities_Tries.Trie_Tree := Entities_Tries.Empty_Trie_Tree;
      Files    : Files_HTable.HTable;
      LIs      : LI_HTable.HTable;

      Predefined_File : Source_File;
      Handlers        : LI_Handler;   --  ??? should be Language_Handler
   end record;
   type Entities_Database is access Entities_Database_Record;

   type LI_Handler_Record is abstract tagged limited null record;

end Entities;
