-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                     Copyright (C) 2002-2003                       --
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

with Basic_Types;            use Basic_Types;
with Glib;                   use Glib;
with Gdk.Event;              use Gdk.Event;
with Gdk.Types;              use Gdk.Types;
with Gdk.Types.Keysyms;      use Gdk.Types.Keysyms;
with Gtk.Box;                use Gtk.Box;
with Gtk.Enums;              use Gtk.Enums;
with Gtk.GEntry;             use Gtk.GEntry;
with Gtk.Combo;              use Gtk.Combo;
with Gtk.Frame;              use Gtk.Frame;
with Gtk.Scrolled_Window;    use Gtk.Scrolled_Window;
with Gtk.Tree_View;          use Gtk.Tree_View;
with Gtk.Tree_Selection;     use Gtk.Tree_Selection;
with Gtk.Tree_Model;         use Gtk.Tree_Model;
with Gtk.Tree_Store;         use Gtk.Tree_Store;
with Gtk.Cell_Renderer_Text; use Gtk.Cell_Renderer_Text;
with Gtk.Tree_View_Column;   use Gtk.Tree_View_Column;
with Gtk.Widget;             use Gtk.Widget;
with Gtkada.Handlers;        use Gtkada.Handlers;
with Glide_Intl;             use Glide_Intl;
with GUI_Utils;              use GUI_Utils;

package body Gtkada.Entry_Completion is

   procedure On_Destroy (The_Entry : access Gtk_Widget_Record'Class);
   --  Callback when the widget is destroyed.

   function On_Entry_Tab
     (The_Entry : access Gtk_Widget_Record'Class;
      Event     : Gdk_Event) return Boolean;
   --  Handles the completion key in the entry.

   procedure Selection_Changed (The_Entry : access Gtk_Widget_Record'Class);
   --  Called when a line has been selected in the list of possible
   --  completions.

   -------------
   -- Gtk_New --
   -------------

   procedure Gtk_New
     (The_Entry : out Gtkada_Entry; Use_Combo : Boolean := True) is
   begin
      The_Entry := new Gtkada_Entry_Record;
      Gtkada.Entry_Completion.Initialize (The_Entry, Use_Combo);
   end Gtk_New;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (The_Entry : access Gtkada_Entry_Record'Class;
      Use_Combo : Boolean := True)
   is
      Renderer : Gtk_Cell_Renderer_Text;
      Col      : Gtk_Tree_View_Column;
      Num      : Gint;
      pragma Unreferenced (Num);

      Scrolled : Gtk_Scrolled_Window;
      Frame    : Gtk_Frame;
      List : Widget_List.Glist := Widget_List.Null_List;

   begin
      Initialize_Vbox (The_Entry, Homogeneous => False, Spacing => 5);

      if Use_Combo then
         Gtk_New (The_Entry.Combo);
         Disable_Activate (The_Entry.Combo);
         Pack_Start (The_Entry, The_Entry.Combo, Expand => False);
      else
         Gtk_New (The_Entry.GEntry);
         Pack_Start (The_Entry, The_Entry.GEntry, Expand => False);
      end if;

      Set_Activates_Default (Get_Entry (The_Entry), True);
      Set_Width_Chars (Get_Entry (The_Entry), 25);

      Gtk_New (Frame);
      Pack_Start (The_Entry, Frame, Expand => True, Fill => True);

      Gtk_New (Scrolled);
      Set_Policy (Scrolled, Policy_Automatic, Policy_Automatic);
      Add (Frame, Scrolled);

      Gtk_New (The_Entry.View);
      Add (Scrolled, The_Entry.View);
      Set_Mode (Get_Selection (The_Entry.View), Selection_Single);

      Gtk_New (The_Entry.List, (0 .. 0 => GType_String));
      Set_Model (The_Entry.View, Gtk_Tree_Model (The_Entry.List));

      Gtk_New (Renderer);

      Gtk_New (Col);
      Set_Title (Col, -"Completions");
      Set_Sort_Column_Id (Col, 0);

      Num := Append_Column (The_Entry.View, Col);
      Pack_Start (Col, Renderer, False);
      Add_Attribute (Col, Renderer, "text", 0);

      Clicked (Col);

      Widget_List.Append (List, Gtk_Widget (Get_Entry (The_Entry)));
      Widget_List.Append (List, Gtk_Widget (Frame));
      Set_Focus_Chain (The_Entry, List);
      Widget_List.Free (List);

      Widget_Callback.Object_Connect
        (Get_Selection (The_Entry.View), "changed",
         Widget_Callback.To_Marshaller (Selection_Changed'Access),
         Slot_Object => The_Entry);

      Widget_Callback.Connect
        (The_Entry, "destroy",
         Widget_Callback.To_Marshaller (On_Destroy'Access));
      Return_Callback.Object_Connect
        (Get_Entry (The_Entry), "key_press_event",
         Return_Callback.To_Marshaller (On_Entry_Tab'Access), The_Entry);
   end Initialize;

   ---------------
   -- Get_Entry --
   ---------------

   function Get_Entry (The_Entry : access Gtkada_Entry_Record)
      return Gtk.GEntry.Gtk_Entry is
   begin
      if The_Entry.GEntry /= null then
         return The_Entry.GEntry;
      else
         return Get_Entry (The_Entry.Combo);
      end if;
   end Get_Entry;

   -----------------------
   -- Selection_Changed --
   -----------------------

   procedure Selection_Changed (The_Entry : access Gtk_Widget_Record'Class) is
      Ent   : constant Gtkada_Entry := Gtkada_Entry (The_Entry);
      Model : Gtk_Tree_Model;
      Iter  : Gtk_Tree_Iter;

   begin
      Get_Selected
        (Selection => Get_Selection (Ent.View),
         Model     => Model,
         Iter      => Iter);

      --  Selection could be null if we are in the process of clearing up the
      --  list

      if Iter /= Null_Iter then
         Set_Text (Get_Entry (Ent), Get_String (Model, Iter, 0));
         Ent.Completion_Index := Integer'First;
         Grab_Focus (Get_Entry (Ent));
      end if;
   end Selection_Changed;

   ---------------
   -- Get_Combo --
   ---------------

   function Get_Combo (The_Entry : access Gtkada_Entry_Record)
      return Gtk.Combo.Gtk_Combo is
   begin
      return The_Entry.Combo;
   end Get_Combo;

   ----------------
   -- On_Destroy --
   ----------------

   procedure On_Destroy (The_Entry : access Gtk_Widget_Record'Class) is
   begin
      Free (Gtkada_Entry (The_Entry).Completions);
   end On_Destroy;

   ---------------------
   -- Set_Completions --
   ---------------------

   procedure Set_Completions
     (The_Entry   : access Gtkada_Entry_Record;
      Completions : Basic_Types.String_Array_Access) is
   begin
      Clear (The_Entry.List);
      Free (The_Entry.Completions);
      The_Entry.Completions := Completions;
      The_Entry.Completion_Index := Completions'First - 1;
   end Set_Completions;

   ------------------
   -- On_Entry_Tab --
   ------------------

   function On_Entry_Tab
     (The_Entry : access Gtk_Widget_Record'Class;
      Event     : Gdk_Event) return Boolean
   is
      GEntry : Gtkada_Entry := Gtkada_Entry (The_Entry);

      function Next_Matching
        (T : String; Start_At, End_At : Integer) return Integer;
      --  Return the integer of the first possible completion for T, after
      --  index Start_At, and found before End_At.
      --  Integer'First is returned if no completion was found.

      -------------------
      -- Next_Matching --
      -------------------

      function Next_Matching
        (T : String; Start_At, End_At : Integer) return Integer is
      begin
         for S in Start_At .. End_At loop
            if GEntry.Completions (S)'Length >= T'Length
              and then GEntry.Completions (S)
              (GEntry.Completions (S)'First
                 .. GEntry.Completions (S)'First + T'Length - 1) = T
            then
               return S;
            end if;
         end loop;

         return Integer'First;
      end Next_Matching;

   begin
      if (Get_Key_Val (Event) = GDK_Tab
            or else Get_Key_Val (Event) = GDK_KP_Tab)
        and then GEntry.Completions /= null
      then
         declare
            T                     : constant String :=
              Get_Text (Get_Entry (GEntry));
            Completion, Tmp       : String_Access;
            Index, S, First_Index : Integer;
            Iter                  : Gtk_Tree_Iter;
            Col                   : constant Gint := Freeze_Sort (GEntry.List);

         begin
            --  If there is no current series of tab (ie the user has pressed a
            --  key other than tab since the last tab).
            if GEntry.Completion_Index = Integer'First then
               Clear (GEntry.List);
               GEntry.Last_Position := Integer
                 (Get_Position (Get_Entry (GEntry)));
               First_Index := Next_Matching
                 (T, GEntry.Completions'First, GEntry.Completions'Last);

               --  At least one match
               if First_Index /= Integer'First then
                  S := First_Index;

                  Append
                    (GEntry.List, Iter => Iter, Parent => Null_Iter);
                  Set (GEntry.List, Iter, 0, GEntry.Completions (S).all);

                  Completion := new String'(GEntry.Completions (S)
                    (GEntry.Completions (S)'First + T'Length
                     .. GEntry.Completions (S)'Last));

                  loop
                     S := Next_Matching (T, S + 1, GEntry.Completions'Last);
                     exit when S = Integer'First;

                     Append
                       (GEntry.List, Iter => Iter, Parent => Null_Iter);
                     Set (GEntry.List, Iter, 0, GEntry.Completions (S).all);

                     Index := Completion'First;
                     while Index <= Completion'Last
                       and then Completion (Index) =
                       GEntry.Completions (S)(Index - Completion'First
                          + GEntry.Completions (S)'First + T'Length)
                     loop
                        Index := Index + 1;
                     end loop;

                     Tmp := new String'
                       (Completion (Completion'First .. Index - 1));
                     Free (Completion);
                     Completion := Tmp;
                  end loop;

                  if Completion'Length /= 0 then
                     GEntry.Completion_Index := Integer'First;
                     Append_Text (Get_Entry (GEntry), Completion.all);
                     Set_Position (Get_Entry (GEntry), -1);

                  else
                     GEntry.Completion_Index := GEntry.Completions'First - 1;
                     Free (Completion);
                  end if;

                  Thaw_Sort (GEntry.List, Col);
                  return True;
               end if;

            --  Else we display the next possible match
            else
               First_Index := Next_Matching
                 (T (T'First .. GEntry.Last_Position),
                  GEntry.Completion_Index + 1, GEntry.Completions'Last);

               if First_Index = Integer'First then
                  First_Index := GEntry.Completions'First - 1;
                  Delete_Text (Get_Entry (GEntry),
                               Gint (GEntry.Last_Position), -1);
               end if;
            end if;

            GEntry.Completion_Index := First_Index;

            if First_Index >= GEntry.Completions'First then
               Set_Text (Get_Entry (GEntry),
                         GEntry.Completions (First_Index).all);
               Set_Position (Get_Entry (GEntry), -1);
            end if;

            Thaw_Sort (GEntry.List, Col);
         end;

         return True;
      end if;

      GEntry.Completion_Index := Integer'First;
      return False;

   exception
      when others =>
         GEntry.Completion_Index := Integer'First;
         return False;
   end On_Entry_Tab;

end Gtkada.Entry_Completion;
