------------------------------------------------------------------------------
--                                  G P S                                   --
--                                                                          --
--                     Copyright (C) 2016-2017, AdaCore                     --
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

with Command_Lines;    use Command_Lines;

procedure Test_Cmd_Line is
   procedure Test_For_GNATY;
   procedure Check
     (CL       : Command_Line;
      Expanded : Boolean;
      Switch_1 : String;
      Switch_2 : String := "");
   --  Check if given command line contains Switch_1, Switch_2

   -----------
   -- Check --
   -----------

   procedure Check
     (CL       : Command_Line;
      Expanded : Boolean;
      Switch_1 : String;
      Switch_2 : String := "")
   is
      Iter : Command_Line_Iterator;
   begin
      CL.Start (Iter, Expanded);
      if not
        (Has_More (Iter)
         and then Current_Switch (Iter) = Switch_1)
      then
         raise Constraint_Error;
      end if;

      if Switch_2 /= "" then
         Next (Iter);

         if not
           (Has_More (Iter)
            and then Current_Switch (Iter) = Switch_2)
         then
            raise Constraint_Error;
         end if;
      end if;

      Next (Iter);

      if Has_More (Iter) then
         raise Constraint_Error;
      end if;
   end Check;

   procedure Test_For_GNATY is
      --  Define
      --  * -gnaty as prefix
      --  * -gnaty as parameter with an argument without separator (-gnaty2)
      --  * -gnatya as switch without parameters
      --  * -gnaty as alias for -gnaty2x
      --  Then check:
      --  * add '-gnatyx'
      --  * add '-gnaty2'
      --  * remove '-gnatx'

      Config : Command_Line_Configuration;
   begin
      Config.Define_Prefix ("-gnaty");
      Config.Define_Switch_With_Parameter ("-gnaty");
      Config.Define_Switch ("-gnatyx");
      Config.Define_Alias ("-gnaty", "-gnaty2x");  --  -gnatyx2

      declare
         CL : Command_Line;
      begin
         CL.Set_Configuration (Config);
         CL.Append_Switch ("-gnatyx");
         Check (CL, False, "-gnatyx");
         Check (CL, True, "-gnatyx");
         CL.Append_Switch ("-gnaty", Parameter => "2");
         Check (CL, False, "-gnaty");  --  As alias for -gnaty2x
         Check (CL, True, "-gnaty", "-gnatyx");
         CL.Remove_Switch ("-gnatyx");
         Check (CL, False, "-gnaty2");
         Check (CL, True, "-gnaty");
      end;

      declare
         CL : Command_Line;
      begin
         CL.Set_Configuration (Config);
         CL.Append_Switch ("-gnaty");
         Check (CL, False, "-gnaty");  --  As alias for -gnaty2x
         Check (CL, True, "-gnaty", "-gnatyx");
      end;

      declare
         CL : Command_Line;
      begin
         CL.Set_Configuration (Config);
         CL.Append_Switch ("-gnaty1");
         Check (CL, False, "-gnaty1");
         Check (CL, True, "-gnaty");
      end;
   end Test_For_GNATY;
begin
   Test_For_GNATY;
end Test_Cmd_Line;
