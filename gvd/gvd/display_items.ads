-----------------------------------------------------------------------
--                 Odd - The Other Display Debugger                  --
--                                                                   --
--                         Copyright (C) 2000                        --
--                 Emmanuel Briot and Arnaud Charlet                 --
--                                                                   --
-- Odd is free  software;  you can redistribute it and/or modify  it --
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

with Glib;
with Gtk.Widget;
with Odd.Canvas;
with Gdk.Window;
with Items;
with Odd.Process;
with Gdk.Event;
with Odd.Types;
with Gtkada.Canvas;

package Display_Items is

   type Display_Item_Record is new
     Gtkada.Canvas.Canvas_Item_Record with private;
   type Display_Item is access all Display_Item_Record'Class;

   type Odd_Link_Record is new Gtkada.Canvas.Canvas_Link_Record with private;
   type Odd_Link is access all Odd_Link_Record'Class;

   procedure Gtk_New
     (Item           : out Display_Item;
      Win            : Gdk.Window.Gdk_Window;
      Variable_Name  : String;
      Debugger       : access Odd.Process.Debugger_Process_Tab_Record'CLass;
      Auto_Refresh   : Boolean := True;
      Default_Entity : Items.Generic_Type_Access := null);
   --  Create a new item to display the value of Variable_Name.
   --  Auto_Refresh should be set to True if the value of Variable should
   --  be parsed again whenever the debugger stops. This is the default
   --  behavior, that can be changed by the user.
   --
   --  If Variable_Name is "", then no parsing is done to get the type and
   --  or value of the variable.
   --  Default_Entity can be used to initialize the entity associated with the
   --  item. This will be used instead of Variable_Name if not null.

   procedure Gtk_New_And_Put
     (Item           : out Display_Item;
      Win            : Gdk.Window.Gdk_Window;
      Variable_Name  : String;
      Debugger       : access Odd.Process.Debugger_Process_Tab_Record'Class;
      Auto_Refresh   : Boolean := True;
      Link_From      : access Display_Item_Record'Class;
      Link_Name      : String := "";
      Default_Entity : Items.Generic_Type_Access := null);
   --  Same as above, but also create a link from Link_From to the new item.
   --  Link_Name is the label used for the link between the two items.

   procedure Free (Item : access Display_Item_Record);
   --  Remove the item from the canvas and free the memory occupied by it,
   --  including its type description.

   function Find_Item
     (Canvas : access Odd.Canvas.Odd_Canvas_Record'Class;
      Num    : Integer)
     return Display_Item;
   --  Return the item whose identifier is Num, or null if there is none

   procedure On_Button_Click (Item   : access Display_Item_Record;
                              Event  : Gdk.Event.Gdk_Event_Button);
   --  React to button clicks on an item.

   procedure Set_Auto_Refresh
     (Item          : access Display_Item_Record;
      Win           : Gdk.Window.Gdk_Window;
      Auto_Refresh  : Boolean;
      Update_Value  : Boolean := False);
   --  Change the auto refresh status of the item, and update its pixmap.
   --  If Update_Value is True, then the value of the item is recomputed
   --  if necessary.

   procedure On_Background_Click
     (Canvas : access Odd.Canvas.Odd_Canvas_Record'Class;
      Event  : Gdk.Event.Gdk_Event);
   --  Called for clicks in the background of the canvas.

   procedure On_Canvas_Process_Stopped
     (Object : access Gtk.Widget.Gtk_Widget_Record'Class);
   --  Called when the process associated with the Debugger_Process_Tab Object
   --  stops to update the display items.

   procedure Recompute_All_Aliases
     (Canvas : access Odd.Canvas.Odd_Canvas_Record'Class;
      Recompute_Values : Boolean := True);
   --  Recompute all the aliases, and reparse the values for all the
   --  displayed items if Recompute_Values is True

   function Update_On_Auto_Refresh
     (Canvas : access Gtkada.Canvas.Interactive_Canvas_Record'Class;
      Item   : access Gtkada.Canvas.Canvas_Item_Record'Class) return Boolean;
   --  Update the value of a specific item in the canvas. The new value is
   --  read from the debugger, parsed, and redisplayed.
   --  Do nothing if the auto-refresh status of Item is set to false.
   --  The general prototype for this function must be compatible with
   --  Gtkada.Canvas.Item_Processor.

   procedure Update
     (Canvas : access Odd.Canvas.Odd_Canvas_Record'Class;
      Item   : access Display_Item_Record'Class);
   --  Unconditionally update the value of Item after parsing the new value.

   procedure Reset_Recursive (Item : access Display_Item_Record'Class);
   --  Calls Reset_Recursive for the entity represented by the item.

   function Is_Alias_Of (Item : access Display_Item_Record)
                        return Display_Item;
   --  Return the item for which Item is an alias, or null if there is none.

   function Get_Name (Item : access Display_Item_Record) return String;
   --  Return the name of Item, or "" if there is no such name.

   function Get_Debugger
     (Item : access Display_Item_Record'Class)
     return Odd.Process.Debugger_Process_Tab;
   --  Return the process tab to which item belongs

   function Is_A_Variable
     (Item : access Display_Item_Record'Class)
     return Boolean;
   --  Return True if the item is a variable.

   procedure Set_Display_Mode
     (Item : access Display_Item_Record'Class;
      Mode : Items.Display_Mode);
   --  Set the display mode for the item and all its children

   function Get_Display_Mode (Item : access Display_Item_Record)
                             return Items.Display_Mode;
   --  Get the display mode for item

   procedure Update_Resize_Display
     (Item        : access Display_Item_Record'Class;
      Was_Visible : Boolean := False;
      Hide_Big    : Boolean := False);
   --  Recompute the size and update the contents of item.
   --  Was_Visible indicates whether the item was initially visible
   --  It also warns the canvas that the item has changed.
   --  If Hide_Big_Items, then components higher than a specific limit are
   --  forced to hidden state.

private
   type Display_Item_Record is new Gtkada.Canvas.Canvas_Item_Record with
      record
         Num          : Integer;
         Name         : Odd.Types.String_Access := null;
         Entity       : Items.Generic_Type_Access := null;
         Auto_Refresh : Boolean := True;
         Debugger     : Odd.Process.Debugger_Process_Tab;

         Is_A_Variable : Boolean := True;
         --  Set to False if the item is not related to a variable

         Title_Height : Glib.Gint;

         Id           : Odd.Types.String_Access := null;
         --  Uniq ID used for the variable.
         --  This Id is returned by the debugger, and can be the address of a
         --  variable (in Ada or C), or simply the name of the variable (in
         --  Java) when no overloading exists and addresses don't have any
         --  meaning.  This is used to detect aliases.

         Is_Alias_Of  : Display_Item := null;
         --  Item for which we are an alias.

         Is_Dereference : Boolean := False;
         --  True if the item was created as a result of a derefence of an
         --  access type. Such items can be hidden as a result of aliases
         --  detection, whereas items explicitly displayed by the user are
         --  never hidden.

         Was_Alias      : Boolean := False;
         --  Memorize whether the item was an alias in the previous display, so
         --  that we can compute a new position for it.

         Mode           : Items.Display_Mode := Items.Value;
         --  Whether we should display the mode itself.
      end record;

   type Odd_Link_Record is new Gtkada.Canvas.Canvas_Link_Record with record
      Alias_Link : Boolean := False;
      --  True if this Link was created as a result of an aliasing operation.
      --  Such links are always deleted before each update, and recreated
      --  whenever an aliasing is detected.
   end record;

end Display_Items;
