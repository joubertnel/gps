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

with Gtk;                 use Gtk;
with Gtk.Check_Menu_Item; use Gtk.Check_Menu_Item;
with Gtk.Object;          use Gtk.Object;
with Gtk.Widget;          use Gtk.Widget;
with Gtk.Accel_Group;     use Gtk.Accel_Group;
with Gtkada.Handlers;     use Gtkada.Handlers;
with Gtkada.Types;
with GVD.Types;           use GVD.Types;
with GVD.Dialogs;         use GVD.Dialogs;
with GVD.Preferences;     use GVD.Preferences;
with GVD.Process;         use GVD.Process;
with GVD.Memory_View;     use GVD.Memory_View;

with Language.Ada; use Language.Ada;
with Language.C;   use Language.C;
with Language.Cpp; use Language.Cpp;
with Language;     use Language;

with System;       use System;
with Interfaces.C.Strings; use Interfaces.C.Strings;

package body GVD.Main_Window is

   Signals : constant Gtkada.Types.Chars_Ptr_Array :=
     (1 => New_String ("preferences_changed"));
   Class_Record : System.Address := System.Null_Address;

   procedure Gtk_New (Main_Window : out GVD_Main_Window) is
   begin
      Main_Window := new GVD_Main_Window_Record;
      GVD.Main_Window.Initialize (Main_Window);
   end Gtk_New;

   procedure Initialize (Main_Window : access GVD_Main_Window_Record'Class) is
   begin
      Main_Debug_Window_Pkg.Initialize (Main_Window);
      Initialize_Class_Record (Main_Window, Signals, Class_Record);

      Gtk_New (Main_Window.Task_Dialog, Gtk_Window (Main_Window));
      Gtk_New (Main_Window.Thread_Dialog, Gtk_Window (Main_Window));
      Gtk_New (Main_Window.History_Dialog, Gtk_Window (Main_Window));
      Gtk_New (Main_Window.Memory_View, Gtk_Widget (Main_Window));
      Lock (Gtk.Accel_Group.Get_Default);
      Reset_File_Extensions;
      Add_File_Extensions (Ada_Lang, Get_Pref (Ada_Extensions));
      Add_File_Extensions (C_Lang,   Get_Pref (C_Extensions));
      Add_File_Extensions (Cpp_Lang, Get_Pref (Cpp_Extensions));
   end Initialize;

   -----------------------------
   -- Update_External_Dialogs --
   -----------------------------

   procedure Update_External_Dialogs
     (Window   : access GVD_Main_Window_Record'Class;
      Debugger : Gtk.Widget.Gtk_Widget := null)
   is
      Tab : Debugger_Process_Tab := Debugger_Process_Tab (Debugger);
   begin
      if Debugger = null then
         Tab := Get_Current_Process (Window);
      end if;

      if Tab /= null then
         Update_Call_Stack (Tab);
         Update (Window.Task_Dialog, Tab);
         Update (Window.History_Dialog, Tab);
      end if;
   end Update_External_Dialogs;

   ----------------
   -- Find_Match --
   ----------------

   procedure Find_Match
     (H   : in out History_List;
      Num : in Natural;
      D   : in Direction)
   is
      Data    : GNAT.OS_Lib.String_Access;
      Current : History_Data;
   begin
      begin
         Data := Get_Current (H).Command;
      exception
         when No_Such_Item =>
            Data := null;
      end;

      loop
         if D = Backward then
            Move_To_Previous (H);
         else
            Move_To_Next (H);
         end if;

         Current := Get_Current (H);

         exit when Current.Debugger_Num = Num
           and then Current.Mode /= Hidden
           and then (Data = null
                     or else Current.Command.all /= Data.all);
      end loop;
   end Find_Match;

   -------------------------
   -- Preferences_Changed --
   -------------------------

   procedure Preferences_Changed
     (Window : access GVD_Main_Window_Record'Class) is
   begin
      Widget_Callback.Emit_By_Name
        (Gtk_Widget (Window), "preferences_changed");

      if Get_Active (Window.Call_Stack) /= Get_Pref (Show_Stack) then
         Set_Active (Window.Call_Stack, Get_Pref (Show_Stack));
      end if;

      Reset_File_Extensions;
      Add_File_Extensions (Ada_Lang, Get_Pref (Ada_Extensions));
      Add_File_Extensions (C_Lang,   Get_Pref (C_Extensions));
      Add_File_Extensions (Cpp_Lang, Get_Pref (Cpp_Extensions));
   end Preferences_Changed;

end GVD.Main_Window;
