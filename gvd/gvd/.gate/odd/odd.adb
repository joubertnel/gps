with Gtk; use Gtk;
with Gtk.Main;
with Gtk.Widget; use Gtk.Widget;
with Main_Debug_Window_Pkg; use Main_Debug_Window_Pkg;
with Breakpoints_Pkg; use Breakpoints_Pkg;
with Open_Program_Pkg; use Open_Program_Pkg;
with Open_Session_Pkg; use Open_Session_Pkg;
with Memory_View_Pkg; use Memory_View_Pkg;
with Advanced_Breakpoint_Pkg; use Advanced_Breakpoint_Pkg;

procedure Odd is
   Main_Debug_Window : Main_Debug_Window_Access;
   Breakpoints : Breakpoints_Access;
   Open_Program : Open_Program_Access;
   Open_Session : Open_Session_Access;
   Memory_View : Memory_View_Access;
   Advanced_Breakpoint : Advanced_Breakpoint_Access;

begin
   Gtk.Main.Set_Locale;
   Gtk.Main.Init;
   Gtk_New (Main_Debug_Window);
   Show_All (Main_Debug_Window);
   Gtk_New (Breakpoints);
   Show_All (Breakpoints);
   Gtk_New (Open_Program);
   Show_All (Open_Program);
   Gtk_New (Open_Session);
   Show_All (Open_Session);
   Gtk_New (Memory_View);
   Show_All (Memory_View);
   Gtk_New (Advanced_Breakpoint);
   Show_All (Advanced_Breakpoint);
   Gtk.Main.Main;
end Odd;
