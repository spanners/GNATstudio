-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                     Copyright (C) 2008, AdaCore                   --
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

with Glib.Values;
with Gtk.Tree_Model;

with Code_Peer.Message_Categories_Models;

package Code_Peer.Messages_Filter_Models is

   Active_Column      : constant := 0;
   Name_Column        : constant := 1;
   Column_Count       : constant := 2;

   type Messages_Filter_Model_Record is
     new Code_Peer.Message_Categories_Models.Message_Categories_Model_Record
       with private;

   type Messages_Filter_Model is access all Messages_Filter_Model_Record'Class;

   procedure Gtk_New
     (Model      : in out Messages_Filter_Model;
      Categories : Code_Peer.Message_Category_Sets.Set);

   procedure Initialize
     (Self       : access Messages_Filter_Model_Record'Class;
      Categories : Code_Peer.Message_Category_Sets.Set);

   procedure Show
     (Self     : access Messages_Filter_Model_Record'Class;
      Category : Code_Peer.Message_Category_Access);

   procedure Hide
     (Self     : access Messages_Filter_Model_Record'Class;
      Category : Code_Peer.Message_Category_Access);

   function Get_Visible_Categories
     (Self : access Messages_Filter_Model_Record'Class)
      return Code_Peer.Message_Category_Sets.Set;

   overriding procedure Clear (Self : access Messages_Filter_Model_Record);

private

   type Messages_Filter_Model_Record is
     new Code_Peer.Message_Categories_Models.Message_Categories_Model_Record
       with record
      Categories : Code_Peer.Message_Category_Sets.Set;
   end record;

   overriding function Get_N_Columns
     (Self : access Messages_Filter_Model_Record) return Glib.Gint;

   overriding function Get_Column_Type
     (Self  : access Messages_Filter_Model_Record;
      Index : Glib.Gint) return Glib.GType;

   overriding procedure Get_Value
     (Self   : access Messages_Filter_Model_Record;
      Iter   : Gtk.Tree_Model.Gtk_Tree_Iter;
      Column : Glib.Gint;
      Value  : out Glib.Values.GValue);

end Code_Peer.Messages_Filter_Models;
