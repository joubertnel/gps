-----------------------------------------------------------------------
--                                                                   --
--                     Copyright (C) 2001                            --
--                          ACT-Europe                               --
--                                                                   --
-- This library is free software; you can redistribute it and/or     --
-- modify it under the terms of the GNU General Public               --
-- License as published by the Free Software Foundation; either      --
-- version 2 of the License, or (at your option) any later version.  --
--                                                                   --
-- This library is distributed in the hope that it will be useful,   --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of    --
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU --
-- General Public License for more details.                          --
--                                                                   --
-- You should have received a copy of the GNU General Public         --
-- License along with this library; if not, write to the             --
-- Free Software Foundation, Inc., 59 Temple Place - Suite 330,      --
-- Boston, MA 02111-1307, USA.                                       --
--                                                                   --
-- As a special exception, if other files instantiate generics from  --
-- this unit, or you link this unit with other files to produce an   --
-- executable, this  unit  does not  by itself cause  the resulting  --
-- executable to be covered by the GNU General Public License. This  --
-- exception does not however invalidate any other reasons why the   --
-- executable file  might be covered by the  GNU Public License.     --
-----------------------------------------------------------------------

with Gdk.Bitmap;            use Gdk.Bitmap;
with Gdk.Color;             use Gdk.Color;
with Gdk.Event;             use Gdk.Event;
with Gdk.Font;              use Gdk.Font;
with Gdk.Pixmap;            use Gdk.Pixmap;
with Gdk.Types;             use Gdk.Types;
with Glib;                  use Glib;
with Gtk.Alignment;         use Gtk.Alignment;
with Gtk.Arrow;             use Gtk.Arrow;
with Gtk.Box;               use Gtk.Box;
with Gtk.Button;            use Gtk.Button;
with Gtk.Button_Box;        use Gtk.Button_Box;
with Gtk.Clist;             use Gtk.Clist;
with Gtk.Enums;             use Gtk.Enums;
with Gtk.GEntry;            use Gtk.GEntry;
with Gtk.Handlers;          use Gtk.Handlers;
with Gtk.Hbutton_Box;       use Gtk.Hbutton_Box;
with Gtk.Label;             use Gtk.Label;
with Gtk.Menu;              use Gtk.Menu;
with Gtk.Menu_Item;         use Gtk.Menu_Item;
with Gtk.Scrolled_Window;   use Gtk.Scrolled_Window;
with Gtk.Style;             use Gtk.Style;
with Gtk.Table;             use Gtk.Table;
with Gtk.Widget;            use Gtk.Widget;
with Gtkada.File_Selection; use Gtkada.File_Selection;
with Gtkada.Handlers;       use Gtkada.Handlers;
with Gtkada.Types;          use Gtkada.Types;

with GNAT.Directory_Operations; use GNAT.Directory_Operations;
with GNAT.OS_Lib;               use GNAT.OS_Lib;

with Prj.PP;   use Prj.PP;
with Prj.Tree; use Prj.Tree;
with Prj;      use Prj;

with Wizards;          use Wizards;
with Directory_Tree;   use Directory_Tree;
with Switches_Editors; use Switches_Editors;
with Naming_Editors;   use Naming_Editors;
with Prj_API;          use Prj_API;

package body Creation_Wizard is

   Logo_Xpm : aliased Chars_Ptr_Array (0 .. 0);
   pragma Import (C, Logo_Xpm, "logo_xpm");

   function First_Page (Wiz : access Prj_Wizard_Record'Class)
      return Gtk_Widget;
   function Second_Page (Wiz : access Prj_Wizard_Record'Class)
      return Gtk_Widget;
   function Third_Page (Wiz : access Prj_Wizard_Record'Class)
      return Gtk_Widget;
   function Fourth_Page (Wiz : access Prj_Wizard_Record'Class)
      return Gtk_Widget;
   function Fifth_Page (Wiz : access Prj_Wizard_Record'Class)
      return Gtk_Widget;
   --  Return the widget to use for any of the pages in the wizard

   procedure Add_Src_Directory
     (Wiz : access Prj_Wizard_Record'Class;
      Dir : String;
      Recursive : Boolean);
   --  Add Dir in the tree to the list of source directories associated with
   --  the project, and return the matching row in Wiz.Src_Dir_List.  If
   --  recursive is True, then all the subdirectories are also added.

   procedure Add_Src_Directory_Cb (W : access Gtk_Widget_Record'Class);
   --  Callback for the up button in the source directory selection

   procedure Add_Single_Src_Directory_Cb (W : access Gtk_Widget_Record'Class);
   --  Callback for the up button in the source directory selection.
   --  The addition is not recursive.
   --  ??? This could be merged with the above procedure if Object_Connect
   --  could use a User_Data parameter.

   procedure Remove_Src_Directory
     (Wiz : access Prj_Wizard_Record'Class; Recursive : Boolean);
   --  Remove the currently selected directory.
   --  If recursive is True, then all the subdirectories are also removed

   procedure Remove_Src_Directory_Cb (W : access Gtk_Widget_Record'Class);
   --  Callback for the down button in the source directory selection

   procedure Remove_Single_Src_Directory_Cb
     (W : access Gtk_Widget_Record'Class);
   --  Remove the currently selected directory in W.Src_Dir_List. This doesn't
   --  remove children of the directory.

   function Directory_Button_Press_Cb
     (W : access Gtk_Widget_Record'Class;
      Event  : Gdk.Event.Gdk_Event) return Boolean;
   --  Callback to display the contextual menu in the directory selection
   --  (second page of the wizard).

   function Src_List_Button_Press_Cb
     (W : access Gtk_Widget_Record'Class;
      Event  : Gdk.Event.Gdk_Event) return Boolean;
   --  Callback to display the contextual menu in the source directory list
   --  (second page of the wizard).

   function Is_Source_Directory
     (Wiz : access Prj_Wizard_Record'Class; Name : String) return Gint;
   --  -1 if Name is not a source directory for the project defined in Wiz.
   --  Otherwise, the index of Name in Wiz.Src_Dir_List is returned.

   procedure Advanced_Prj_Location (W : access Gtk_Widget_Record'Class);
   --  Open up a dialog to select the project location.

   procedure Advanced_Make_Switches (W : access Gtk_Widget_Record'Class);
   procedure Advanced_Compiler_Switches (W : access Gtk_Widget_Record'Class);
   procedure Advanced_Binder_Switches (W : access Gtk_Widget_Record'Class);
   procedure Advanced_Linker_Switches (W : access Gtk_Widget_Record'Class);
   --  Callbacks used to provide an advanced switches editor

   function Directory_Name (File_Name : String) return String;
   --  Return the directory name for File_Name (always ends with a directory
   --  separator).

   procedure Generate_Prj (W : access Gtk_Widget_Record'Class);
   --  Generate the project files from the contents of the wizard W.

   procedure Emit_Switches
     (Wiz : access Prj_Wizard_Record'Class;
      Project : Project_Node_Id;
      Name : String;
      Tool : Tool_Names);
   --  Create a new variable in a package called Name to represent the default
   --  switches to use for this tool

   -------------
   -- Gtk_New --
   -------------

   procedure Gtk_New (Wiz : out Prj_Wizard) is
   begin
      Wiz := new Prj_Wizard_Record;
      Creation_Wizard.Initialize (Wiz);
   end Gtk_New;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize (Wiz : access Prj_Wizard_Record'Class) is
      Pix  : Gdk_Pixmap;
      Mask : Gdk_Bitmap;
      Font : Gdk_Font;
   begin
      Wizards.Initialize (Wiz, "Project setup", "#0476bc");
      Set_USize (Wiz, 640, -1);

      Create_From_Xpm_D
        (Pix, null, Get_Default_Colormap, Mask, Null_Color, Logo_Xpm);
      Add_Logo (Wiz, Pix, Mask);

      Wiz.Title_Style := Copy (Get_Style (Wiz));
      Load (Font, "-adobe-helvetica-bold-*-*-*-*-180-*-*-*-*-*-*");
      if Font /= null then
         Set_Font (Wiz.Title_Style, Font);
      end if;

      Add_Page (Wiz, First_Page (Wiz),  "Naming the project");
      Add_Page (Wiz, Second_Page (Wiz), "Selecting sources");
      Add_Page (Wiz, Third_Page (Wiz),  "Selecting build directory");
      Add_Page (Wiz, Fourth_Page (Wiz), "Selecting switches");
      Add_Page (Wiz, Fifth_Page (Wiz),  "Choosing the naming scheme");

      Widget_Callback.Object_Connect
        (Finish_Button (Wiz), "clicked",
         Widget_Callback.To_Marshaller (Generate_Prj'Access), Wiz);
   end Initialize;

   ----------------
   -- First_Page --
   ----------------

   function First_Page (Wiz : access Prj_Wizard_Record'Class)
      return Gtk_Widget
   is
      Table  : Gtk_Table;
      Box    : Gtk_Box;
      Label  : Gtk_Label;
      Button : Gtk_Button;
      Align  : Gtk_Alignment;
   begin
      Gtk_New_Vbox (Box, Spacing => 8);
      Set_Border_Width (Box, 5);

      Gtk_New (Label, "Creating a new project");
      Set_Style (Label, Wiz.Title_Style);
      Pack_Start (Box, Label, Fill => False, Expand => False);

      Gtk_New (Align, 0.0, 0.5, 1.0, 0.0);
      Pack_Start (Box, Align, Expand => True, Fill => True);

      Gtk_New (Table, Rows => 4, Columns => 2, Homogeneous => False);
      Add (Align, Table);

      Gtk_New (Label, "Enter the name of the project to create:");
      Attach (Table, Label, 0, 2, 0, 1);

      Gtk_New (Wiz.Project_Name, 255);
      Attach (Table, Wiz.Project_Name, 0, 1, 1, 2);

      Set_Row_Spacing (Table, 1, 20);

      Gtk_New (Label, "Enter the directory where to copy the file to:");
      Attach (Table, Label, 0, 2, 2, 3);

      Gtk_New (Wiz.Project_Location, 255);
      Attach (Table, Wiz.Project_Location, 0, 1, 3, 4);

      Gtk_New (Button, "...");
      Attach (Table, Button, 1, 2, 3, 4, Xoptions => 0);
      Widget_Callback.Object_Connect
        (Button, "clicked",
         Widget_Callback.To_Marshaller (Advanced_Prj_Location'Access), Wiz);

      return Gtk_Widget (Box);
   end First_Page;

   -----------------
   -- Second_Page --
   -----------------

   function Second_Page (Wiz : access Prj_Wizard_Record'Class)
      return Gtk_Widget
   is
      Arrow_Buttons_Width  : constant := 30;
      Arrow_Buttons_Height : constant := 15;
      Box, Vbox : Gtk_Box;
      Bbox      : Gtk_Hbutton_Box;
      Button    : Gtk_Button;
      Scrolled  : Gtk_Scrolled_Window;
      Label     : Gtk_Label;
      Arrow     : Gtk_Arrow;
   begin
      Add_Events (Wiz, Button_Press_Mask or Button_Release_Mask);

      Gtk_New_Vbox (Vbox, Homogeneous => False, Spacing => 8);

      Gtk_New (Label, "Please select the source directories for this project");
      Set_Style (Label, Wiz.Title_Style);
      Pack_Start (Vbox, Label, Expand => False, Fill => False);

      Gtk_New_Vbox (Box, Homogeneous => False);
      Pack_End (Vbox, Box, Expand => True, Fill => True);

      Gtk_New (Scrolled);
      Set_Policy (Scrolled, Policy_Automatic, Policy_Automatic);
      Pack_Start (Box, Scrolled, Expand => True, Fill => True);

      Gtk_New (Wiz.Src_Dir_Selection, "/");
      Show_Directory (Wiz.Src_Dir_Selection, Get_Current_Dir);
      Add (Scrolled, Wiz.Src_Dir_Selection);
      Gtkada.Handlers.Return_Callback.Object_Connect
        (Wiz.Src_Dir_Selection, "button_press_event",
         Gtkada.Handlers.Return_Callback.To_Marshaller
            (Directory_Button_Press_Cb'Access),
         Wiz);

      Gtk_New (Bbox);
      Set_Layout (Bbox, Buttonbox_Spread);
      Set_Child_Size_Default (Arrow_Buttons_Width, Arrow_Buttons_Height);
      Pack_Start (Box, Bbox, Expand => False, Fill => False);

      Gtk_New (Button);
      Gtk_New (Arrow, Arrow_Down, Shadow_In);
      Add (Button, Arrow);
      Pack_Start (Bbox, Button, Expand => False, Fill => False);
      Widget_Callback.Object_Connect
        (Button, "clicked",
         Widget_Callback.To_Marshaller (Add_Src_Directory_Cb'Access),
         Wiz);

      Gtk_New (Button);
      Gtk_New (Arrow, Arrow_Up, Shadow_In);
      Add (Button, Arrow);
      Pack_Start (Bbox, Button, Expand => False, Fill => False);
      Widget_Callback.Object_Connect
        (Button, "clicked",
         Widget_Callback.To_Marshaller (Remove_Src_Directory_Cb'Access),
         Wiz);

      Gtk_New (Scrolled);
      Set_Policy (Scrolled, Policy_Automatic, Policy_Automatic);
      Pack_Start (Box, Scrolled, Expand => True, Fill => True);

      Gtk_New (Wiz.Src_Dir_List, Columns => 1);
      Add (Scrolled, Wiz.Src_Dir_List);
      Set_Selection_Mode (Wiz.Src_Dir_List, Selection_Extended);
      Gtkada.Handlers.Return_Callback.Object_Connect
        (Wiz.Src_Dir_List, "button_press_event",
         Gtkada.Handlers.Return_Callback.To_Marshaller
            (Src_List_Button_Press_Cb'Access),
         Wiz);

      --  ??? This is a workaround for a horizontal scrollbar problem: When the
      --  clist is put in a scrolled window, and if this is not called, the
      --  scrollbar does not allow us to scroll as far right as possible...
      Set_Column_Auto_Resize (Wiz.Src_Dir_List, 0, True);

      return Gtk_Widget (Vbox);
   end Second_Page;

   ----------------
   -- Third_Page --
   ----------------

   function Third_Page (Wiz : access Prj_Wizard_Record'Class)
      return Gtk_Widget
   is
      Vbox : Gtk_Box;
      Label : Gtk_Label;
      Scrolled  : Gtk_Scrolled_Window;
   begin
      Gtk_New_Vbox (Vbox, Homogeneous => False);

      Gtk_New (Label, "Please select the build directory for this project");
      Set_Style (Label, Wiz.Title_Style);
      Pack_Start (Vbox, Label, Expand => False, Fill => False);

      Gtk_New (Scrolled);
      Set_Policy (Scrolled, Policy_Automatic, Policy_Automatic);
      Pack_Start (Vbox, Scrolled, Expand => True, Fill => True);

      Gtk_New (Wiz.Obj_Dir_Selection, "/");
      Show_Directory (Wiz.Obj_Dir_Selection, Get_Current_Dir);
      Add (Scrolled, Wiz.Obj_Dir_Selection);

      return Gtk_Widget (Vbox);
   end Third_Page;

   -----------------
   -- Fourth_Page --
   -----------------

   function Fourth_Page (Wiz : access Prj_Wizard_Record'Class)
      return Gtk_Widget
   is
      Vbox : Gtk_Box;
      Label : Gtk_Label;
   begin
      Gtk_New_Vbox (Vbox, Homogeneous => False);

      Gtk_New (Label, "Please select the switches to build the project");
      Set_Style (Label, Wiz.Title_Style);
      Pack_Start (Vbox, Label, Expand => False, Fill => False);

      Gtk_New (Wiz.Switches);
      Pack_Start
        (Vbox, Get_Window (Wiz.Switches), Expand => True, Fill => True);

      return Gtk_Widget (Vbox);
   end Fourth_Page;

   ----------------
   -- Fifth_Page --
   ----------------

   function Fifth_Page (Wiz : access Prj_Wizard_Record'Class)
      return Gtk_Widget
   is
      Vbox : Gtk_Box;
      Label : Gtk_Label;
   begin
      Gtk_New_Vbox (Vbox, Homogeneous => False);

      Gtk_New (Label, "Please select the naming scheme to use");
      Set_Style (Label, Wiz.Title_Style);
      Pack_Start (Vbox, Label, Expand => False, Fill => False);

      Gtk_New (Wiz.Naming);
      Pack_Start
        (Vbox, Get_Window (Wiz.Naming), Expand => True, Fill => True);

      return Gtk_Widget (Vbox);
   end Fifth_Page;

   -------------------------
   -- Is_Source_Directory --
   -------------------------

   function Is_Source_Directory
     (Wiz : access Prj_Wizard_Record'Class; Name : String) return Gint
   is
      Num_Rows : constant Gint := Get_Rows (Wiz.Src_Dir_List);
   begin
      --  Check if the directory is already there
      for J in 0 .. Num_Rows - 1 loop
         if Get_Text (Wiz.Src_Dir_List, J, 0) = Name then
            return J;
         end if;
      end loop;
      return -1;
   end Is_Source_Directory;

   -----------------------
   -- Add_Src_Directory --
   -----------------------

   procedure Add_Src_Directory
     (Wiz : access Prj_Wizard_Record'Class;
      Dir : String;
      Recursive : Boolean)
   is
      Row : Gint;
      Handle : Dir_Type;
      File : String (1 .. 255);
      Last : Natural;
   begin
      Row := Is_Source_Directory (Wiz, Dir);
      if Row = -1 then
         Row := Append (Wiz.Src_Dir_List, Null_Array + Dir);
      end if;
      Select_Row (Wiz.Src_Dir_List, Row, -1);

      if Recursive then
         Open (Handle, Dir);
         loop
            Read (Handle, File, Last);
            exit when Last = 0;

            --  ??? Should share filter with Directory_Tree
            if File (File'First .. Last) /= "."
              and then File (File'First .. Last) /= ".."
              and then Is_Directory (Dir & File (File'First .. Last))
            then
               Add_Src_Directory
                 (Wiz, Dir & File (1 .. Last) & Directory_Separator, True);
            end if;
         end loop;

         Close (Handle);
      end if;
   end Add_Src_Directory;

   --------------------------
   -- Remove_Src_Directory --
   --------------------------

   procedure Remove_Src_Directory
     (Wiz : access Prj_Wizard_Record'Class; Recursive : Boolean)
   is
      use type Gint_List.Glist;
      List : Gint_List.Glist := Get_Selection (Wiz.Src_Dir_List);
      Next : Gint_List.Glist;
      Num  : Guint := Gint_List.Length (List);
   begin
      --  Add the directories recursively to the selection (we can't remove
      --  them right away, since this would cancel the current selection and
      --  thus we wouldn't be able to remove all the user-selected ones).

      if Recursive then
         for J in 1 .. Num loop
            declare
               Row : constant Gint := Gint_List.Get_Data (List);
               Dir : constant String := Get_Text (Wiz.Src_Dir_List, Row, 0);
            begin
               for J in 0 .. Get_Rows (Wiz.Src_Dir_List) - 1 loop
                  declare
                     N : constant String := Get_Text (Wiz.Src_Dir_List, J, 0);
                  begin
                     if N'Length > Dir'Length
                       and then N (N'First .. N'First + Dir'Length - 1) = Dir
                     then
                        Select_Row (Wiz.Src_Dir_List, J, -1);
                     end if;
                  end;
               end loop;
            end;
            List := Gint_List.Next (List);
         end loop;
      end if;

      --  Now remove the whole selection

      List := Get_Selection (Wiz.Src_Dir_List);
      while List /= Gint_List.Null_List loop
         Next := Gint_List.Next (List);
         Remove (Wiz.Src_Dir_List, Gint_List.Get_Data (List));
         List := Next;
      end loop;

      --  Workaround for a possible bug in gtk+: when all the rows in the
      --  clist are removed with the loop above, we get a STORAGE_ERROR,
      --  unless we do the following

      Remove (Wiz.Src_Dir_List, Append (Wiz.Src_Dir_List, Null_Array + ""));
   end Remove_Src_Directory;

   --------------------------
   -- Add_Src_Directory_Cb --
   --------------------------

   procedure Add_Src_Directory_Cb (W : access Gtk_Widget_Record'Class) is
      Wiz : Prj_Wizard := Prj_Wizard (W);
   begin
      Freeze (Wiz.Src_Dir_List);
      Unselect_All (Wiz.Src_Dir_List);
      Add_Src_Directory (Wiz, Get_Selection (Wiz.Src_Dir_Selection), True);
      Sort (Wiz.Src_Dir_List);
      Thaw (Wiz.Src_Dir_List);

      --  Show the first selected item
      Moveto (Wiz.Src_Dir_List,
              Gint_List.Get_Data (Get_Selection (Wiz.Src_Dir_List)),
              0, 0.0, 0.2);
   end Add_Src_Directory_Cb;

   ---------------------------------
   -- Add_Single_Src_Directory_Cb --
   ---------------------------------

   procedure Add_Single_Src_Directory_Cb
     (W : access Gtk_Widget_Record'Class)
   is
      Wiz : Prj_Wizard := Prj_Wizard (W);
   begin
      Add_Src_Directory (Wiz, Get_Selection (Wiz.Src_Dir_Selection), False);
      Sort (Wiz.Src_Dir_List);
   end Add_Single_Src_Directory_Cb;

   -----------------------------
   -- Remove_Src_Directory_Cb --
   -----------------------------

   procedure Remove_Src_Directory_Cb (W : access Gtk_Widget_Record'Class) is
      Wiz : Prj_Wizard := Prj_Wizard (W);
   begin
      Freeze (Wiz.Src_Dir_List);
      Remove_Src_Directory (Wiz, Recursive => True);
      Thaw (Wiz.Src_Dir_List);
   end Remove_Src_Directory_Cb;

   ------------------------------------
   -- Remove_Single_Src_Directory_Cb --
   ------------------------------------

   procedure Remove_Single_Src_Directory_Cb
     (W : access Gtk_Widget_Record'Class) is
   begin
      Remove_Src_Directory (Prj_Wizard (W), Recursive => False);
   end Remove_Single_Src_Directory_Cb;

   -------------------------------
   -- Directory_Button_Press_Cb --
   -------------------------------

   function Directory_Button_Press_Cb
     (W : access Gtk_Widget_Record'Class;
      Event  : Gdk.Event.Gdk_Event) return Boolean
   is
      Wiz  : Prj_Wizard := Prj_Wizard (W);
      Item : Gtk_Menu_Item;
      Selected_Row, Selected_Col : Gint;
      Is_Valid : Boolean;

   begin
      if Get_Button (Event) = 3
        and then Get_Event_Type (Event) = Button_Press
      then
         if Wiz.Dir_Contextual_Menu /= null then
            Destroy (Wiz.Dir_Contextual_Menu);
         end if;

         Get_Selection_Info
           (Wiz.Src_Dir_Selection,
            Gint (Get_X (Event)), Gint (Get_Y (Event)),
            Selected_Row, Selected_Col, Is_Valid);

         if Is_Valid then
            Select_Row (Wiz.Src_Dir_Selection, Selected_Row, Selected_Col);

            Gtk_New (Wiz.Dir_Contextual_Menu);
            Gtk_New (Item, "Add directory recursive");
            Widget_Callback.Object_Connect
              (Item, "activate",
               Widget_Callback.To_Marshaller (Add_Src_Directory_Cb'Access),
               Wiz);
            Append (Wiz.Dir_Contextual_Menu, Item);

            Gtk_New (Item, "Add directory");
            Widget_Callback.Object_Connect
              (Item, "activate",
               Widget_Callback.To_Marshaller
                 (Add_Single_Src_Directory_Cb'Access),
               Wiz);
            Append (Wiz.Dir_Contextual_Menu, Item);

            Show_All (Wiz.Dir_Contextual_Menu);

            Popup (Wiz.Dir_Contextual_Menu,
                   Button        => Gdk.Event.Get_Button (Event),
                   Activate_Time => Gdk.Event.Get_Time (Event));
            Emit_Stop_By_Name (Wiz.Src_Dir_Selection, "button_press_event");
            return True;
         end if;
      end if;

      return False;
   end Directory_Button_Press_Cb;

   ------------------------------
   -- Src_List_Button_Press_Cb --
   ------------------------------

   function Src_List_Button_Press_Cb
     (W : access Gtk_Widget_Record'Class;
      Event  : Gdk.Event.Gdk_Event) return Boolean
   is
      use type Gint_List.Glist;
      Wiz  : Prj_Wizard := Prj_Wizard (W);
      Item : Gtk_Menu_Item;
      Is_Valid : constant Boolean :=
        Get_Selection (Wiz.Src_Dir_List) /= Gint_List.Null_List;

   begin
      if Get_Button (Event) = 3
        and then Get_Event_Type (Event) = Button_Press
      then
         if Wiz.Src_Dir_Contextual_Menu /= null then
            Destroy (Wiz.Src_Dir_Contextual_Menu);
         end if;

         Gtk_New (Wiz.Src_Dir_Contextual_Menu);
         Gtk_New (Item, "Remove directory recursive");
         Widget_Callback.Object_Connect
           (Item, "activate",
            Widget_Callback.To_Marshaller (Remove_Src_Directory_Cb'Access),
            Wiz);
         Set_Sensitive (Item, Is_Valid);
         Append (Wiz.Src_Dir_Contextual_Menu, Item);

         Gtk_New (Item, "Remove directory");
         Widget_Callback.Object_Connect
           (Item, "activate",
            Widget_Callback.To_Marshaller
            (Remove_Single_Src_Directory_Cb'Access),
            Wiz);
         Set_Sensitive (Item, Is_Valid);
         Append (Wiz.Src_Dir_Contextual_Menu, Item);

         Show_All (Wiz.Src_Dir_Contextual_Menu);

         Popup (Wiz.Src_Dir_Contextual_Menu,
                Button        => Gdk.Event.Get_Button (Event),
                Activate_Time => Gdk.Event.Get_Time (Event));
         Emit_Stop_By_Name (Wiz.Src_Dir_List, "button_press_event");
         return True;
      end if;

      return False;
   end Src_List_Button_Press_Cb;

   ----------------------------
   -- Advanced_Make_Switches --
   ----------------------------

   procedure Advanced_Make_Switches (W : access Gtk_Widget_Record'Class) is
   begin
      null;
   end Advanced_Make_Switches;

   --------------------------------
   -- Advanced_Compiler_Switches --
   --------------------------------

   procedure Advanced_Compiler_Switches (W : access Gtk_Widget_Record'Class) is
   begin
      null;
   end Advanced_Compiler_Switches;

   ------------------------------
   -- Advanced_Binder_Switches --
   ------------------------------

   procedure Advanced_Binder_Switches (W : access Gtk_Widget_Record'Class) is
   begin
      null;
   end Advanced_Binder_Switches;

   ------------------------------
   -- Advanced_Linker_Switches --
   ------------------------------

   procedure Advanced_Linker_Switches (W : access Gtk_Widget_Record'Class) is
   begin
      null;
   end Advanced_Linker_Switches;

   --------------------
   -- Directory_Name --
   --------------------

   function Directory_Name (File_Name : String) return String is
   begin
      for J in reverse File_Name'Range loop
         if File_Name (J) = GNAT.OS_Lib.Directory_Separator
           or else File_Name (J) = '/'
         then
            return File_Name (File_Name'First .. J);
         end if;
      end loop;
      return "";
   end Directory_Name;

   ---------------------------
   -- Advanced_Prj_Location --
   ---------------------------

   procedure Advanced_Prj_Location (W : access Gtk_Widget_Record'Class) is
      Name : constant String := File_Selection_Dialog
         ("Select project file location", Dir_Only => True);
   begin
      if Name /= "" then
         Set_Text (Prj_Wizard (W).Project_Location, Name);
      end if;
   end Advanced_Prj_Location;

   -------------------
   -- Emit_Switches --
   -------------------

   procedure Emit_Switches
     (Wiz : access Prj_Wizard_Record'Class;
      Project : Project_Node_Id;
      Name : String;
      Tool : Tool_Names)
   is
      Pack, Var : Project_Node_Id;
      Arr : Argument_List := Get_Switches (Wiz.Switches, Tool);
   begin
      if Arr'Length /= 0 then
         Pack := Get_Or_Create_Package (Project, Name);
         Var := Get_Or_Create_Variable (Pack, "switches", List);
         for J in Arr'Range loop
            Append_To_List (Var, Arr (J).all);
         end loop;
         Free (Arr);
      end if;
   end Emit_Switches;

   ------------------
   -- Generate_Prj --
   ------------------

   procedure Generate_Prj (W : access Gtk_Widget_Record'Class) is
      Wiz  : Prj_Wizard := Prj_Wizard (W);
      Project, Var : Project_Node_Id;
      Num_Src_Dir : constant Gint := Get_Rows (Wiz.Src_Dir_List);
   begin
      Project := Create_Project
        (Name => Get_Chars (Wiz.Project_Name),
         Path => Get_Chars (Wiz.Project_Location));

      --  Append the source directories
      Var := Get_Or_Create_Variable (Project, "src_dir", List);
      for J in 0 .. Num_Src_Dir - 1 loop
         Append_To_List (Var, Get_Text (Wiz.Src_Dir_List, J, 0));
      end loop;

      --  Append the build directory
      Var := Get_Or_Create_Variable (Project, "obj_dir", Single);
      Set_Value (Var, Get_Selection (Wiz.Obj_Dir_Selection));

      --  Append the switches
      Emit_Switches (Wiz, Project, "gnatmake", Gnatmake);
      Emit_Switches (Wiz, Project, "gcc", Compiler);
      Emit_Switches (Wiz, Project, "gnatbind", Binder);
      Emit_Switches (Wiz, Project, "gnatlink", Linker);

      --  Append the naming scheme
      Create_Project_Entry (Wiz.Naming, Project);

      Pretty_Print (Project);
   end Generate_Prj;

end Creation_Wizard;
