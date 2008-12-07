-----------------------------------------------------------------------
--                               G P S                               --
--                                                                   --
--                    Copyright (C) 2008, AdaCore                    --
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
-- a copy of the GNU General Public License along with this library; --
-- if not,  write to the  Free Software Foundation, Inc.,  59 Temple --
-- Place - Suite 330, Boston, MA 02111-1307, USA.                    --
-----------------------------------------------------------------------

with Ada.Characters.Handling; use Ada.Characters.Handling;
with Switches_Parser;
with String_Utils;    use String_Utils;

package body Build_Configurations is

   use GNAT.OS_Lib;
   use Target_List;

   ------------------------
   -- Local declarations --
   ------------------------

   procedure Add_Target
     (Registry : Build_Config_Registry_Access;
      Target   : Target_Access);
   --  Add Target to Registry

   function "-" (Msg : String) return String;
   --  Convenient shortcut to the Gettext function

   function Command_Line_To_XML
     (CL  : GNAT.OS_Lib.Argument_List;
      Tag : String) return Node_Ptr;
   function XML_To_Command_Line
     (N : Node_Ptr) return GNAT.OS_Lib.Argument_List;
   --  Convert between a command line to/from the following XML representation
   --          <command-line>
   --             <arg>COMMAND</arg>
   --             <arg>ARG1</arg>
   --                 ...
   --             <arg>ARGN</arg>
   --          </command-line>

   function Copy (T : Target_Access) return Target_Access;
   --  Allocate and return a deep copy of T

   function Deep_Copy (CL : Argument_List_Access) return Argument_List_Access;
   --  Allocate and return a deep copy of CL

   function Equals (T1 : Target_Access; T2 : Target_Access) return Boolean;
   --  Deep comparison between T1 and T2

   procedure Free (Target : in out Target_Access);
   procedure Free (List : in out Target_List.List);
   procedure Free (Models : in out Model_Map.Map);
   procedure Free (Modes : in out Mode_Map.Map);
   --  Free memory

   ---------------
   -- Deep_Copy --
   ---------------

   function Deep_Copy
     (CL : Argument_List_Access) return Argument_List_Access
   is
      CL2 : Argument_List_Access;
   begin
      if CL = null then
         return null;
      end if;

      CL2 := new Argument_List (CL'Range);
      for J in CL'Range loop
         if CL (J) /= null then
            CL2 (J) := new String'(CL (J).all);
         end if;
      end loop;
      return CL2;
   end Deep_Copy;

   ----------
   -- Copy --
   ----------

   function Copy (T : Target_Access) return Target_Access is
   begin
      return new Target_Type'
        (Name         => T.Name,
         Model        => T.Model,
         Command_Line => Deep_Copy (T.Command_Line),
         Properties   => T.Properties);
   end Copy;

   ------------
   -- Equals --
   ------------

   function Equals (T1 : Target_Access; T2 : Target_Access) return Boolean is

      function Equals (A, B : Argument_List_Access) return Boolean;
      --  Comparison function

      ------------
      -- Equals --
      ------------

      function Equals (A, B : Argument_List_Access) return Boolean is
      begin
         if A = null and then B = null then
            return True;
         end if;

         if        A = null
           or else B = null
           or else A'First /= B'First
           or else A'Last /= B'Last
         then
            return False;
         end if;

         for J in A'Range loop
            if not (A (J) = null and then B (J) = null) then
               if A (J) = null
                 or else B (J) = null
                 or else A (J).all /= B (J).all
               then
                  return False;
               end if;
            end if;
         end loop;
         return True;
      end Equals;

   begin
      if        T1.Name       /= T2.Name
        or else T1.Model      /= T2.Model
        or else T1.Properties /= T2.Properties
        or else not Equals (T1.Command_Line, T2.Command_Line)
      then
         return False;
      end if;

      return True;
   end Equals;

   ---------
   -- "-" --
   ---------

   function "-" (Msg : String) return String is
   begin
      --  ??? Provide implementation
      return Msg;
   end "-";

   ---------
   -- Log --
   ---------

   procedure Log
     (Registry : Build_Config_Registry_Access;
      Message  : String;
      Mode     : Message_Mode := Error) is
   begin
      if Registry.Logger /= null then
         Registry.Logger (Message, Mode);
      end if;
   end Log;

   ---------------------------
   -- Create_Model_From_XML --
   ---------------------------

   procedure Create_Model_From_XML
     (Registry : Build_Config_Registry_Access;
      XML      : Node_Ptr)
   is
      Model : Target_Model_Type;

      procedure Parse_Target_Model_Node (N : Node_Ptr);
      --  Parse a global target model node

      procedure Parse_Switches_Node (N : Node_Ptr);
      --  Parse switches node

      -----------------------------
      -- Parse_Target_Model_Node --
      -----------------------------

      procedure Parse_Target_Model_Node (N : Node_Ptr) is
         Name  : constant String := Get_Attribute (N, "name", "");
         Cat   : constant String := Get_Attribute (N, "category", "");
         Child : Node_Ptr;

         use type Glib.String_Ptr;
      begin
         if Name = "" then
            Log
              (Registry,
               -("target-model nodes must have non-empty" &
                 " ""name"" attribute"));
            return;
         end if;

         Model.Name := To_Unbounded_String (Name);
         Model.Category := To_Unbounded_String (Cat);

         Child := N.Child;

         while Child /= null loop
            if Child.Tag.all = "switches" then
               Parse_Switches_Node (Child);

            elsif Child.Tag.all = "description" then
               if Child.Value /= null then
                  Model.Description :=
                    To_Unbounded_String (Child.Value.all);
               end if;

            elsif Child.Tag.all = "command-line" then
               Model.Default_Command_Line :=
                 new GNAT.OS_Lib.Argument_List'(XML_To_Command_Line (Child));

            elsif Child.Tag.all = "icon" then
               if Child.Value /= null then
                  Model.Icon := To_Unbounded_String (Child.Value.all);
               end if;

            elsif Child.Tag.all = "server" then
               Model.Server := Server_Type'Value (Child.Value.all);

            elsif Child.Tag.all = "uses-shell" then
               Model.Uses_Shell := Boolean'Value (Child.Value.all);

            else
               Log
                 (Registry,
                  (-"tag not recognized as child of ""target-model"" node:")
                  & Child.Tag.all);
            end if;

            Child := Child.Next;
         end loop;
      end Parse_Target_Model_Node;

      -------------------------
      -- Parse_Switches_Node --
      -------------------------

      procedure Parse_Switches_Node (N : Node_Ptr) is
         M        : Unbounded_String;
         Switches : Switches_Editor_Config;
      begin
         Switches_Parser.Parse_Switches_Node
           (Current_Tool_Name   => "",
            Current_Tool_Config => Switches,
            Error_Message       => M,
            Finder              => null,
            Node                => N);

         if M /= "" then
            Log (Registry, To_String (M));
         end if;

         Model.Switches := Switches;
      end Parse_Switches_Node;

      use type Glib.String_Ptr;
   begin
      if XML = null or else XML.Tag = null then
         Log (Registry, -"Error: empty XML passed to builder configuration");
         return;
      end if;

      if XML.Tag.all /= "target-model" then
         --  This means in fact a program error: we should never reach this
         --  procedure with a node that does not correspond to a target model
         Log (Registry, -"Error: invalid XML passed to builder configuration");
         return;
      end if;

      --  Parse the XML
      Parse_Target_Model_Node (XML);

      --  Detect whether the model exists

      if Registry.Models.Contains (Model.Name) then
         Log (Registry,
              (-"Error: a model is already registered with the name '")
              & To_String (Model.Name) & "'");
         return;
      end if;

      --  Register the model
      Registry.Models.Insert (Model.Name, new Target_Model_Type'(Model));
   end Create_Model_From_XML;

   -------------------
   -- Create_Target --
   -------------------

   procedure Create_Target
     (Registry     : Build_Config_Registry_Access;
      Name         : String;
      Category     : String;
      Model        : String;
      Command_Line : Argument_List := (1 .. 0 => null))
   is
      Target    : Target_Access;
      The_Model : Target_Model_Access;
   begin
      --  Lookup the model

      if not Registry.Models.Contains (To_Unbounded_String (Model)) then
         Log
           (Registry,
            Name & (-": cannot create target: no model registered with name ")
            & Model);
         return;
      end if;

      if Name = "" then
         Log (Registry, -"Cannot create target with an empty name");
         return;
      end if;

      The_Model := Registry.Models.Element (To_Unbounded_String (Model));

      Target := new Target_Type;
      Target.Name := To_Unbounded_String (Strip_Single_Underscores (Name));
      Target.Properties.Menu_Name := To_Unbounded_String (Name);
      Target.Properties.Category := To_Unbounded_String (Category);
      Target.Model := The_Model;

      if Command_Line'Length > 0 then
         Set_Command_Line (Registry, Target, Command_Line);
      elsif The_Model.Default_Command_Line /= null then
         Set_Command_Line
           (Registry, Target, The_Model.Default_Command_Line.all);
      end if;

      Add_Target (Registry, Target);
   end Create_Target;

   ------------------
   -- Change_Model --
   ------------------

   procedure Change_Model
     (Registry : Build_Config_Registry_Access;
      Target   : String;
      Model    : String)
   is
      The_Target : Target_Access;
      The_Model  : Target_Model_Access;
   begin
      --  Lookup the model

      if not Registry.Models.Contains (To_Unbounded_String (Model)) then
         Log
           (Registry,
            (-"cannot change model: no model registered with name ") & Model);
         return;
      end if;

      The_Model := Registry.Models.Element (To_Unbounded_String (Model));
      The_Target := Get_Target_From_Name (Registry, Target);

      if The_Target = null then
         Log
           (Registry,
            (-"Cannot change model: no target registered with name ")
            & Target);
         return;
      end if;

      The_Target.Model := The_Model;

      --  Only change the executable name from the command line, and keep the
      --  previous argument list, which should be a good appromixation in most
      --  cases, except when the model's command line is empty, in which case,
      --  reset the command line.

      if The_Model.Default_Command_Line = null then
         Set_Command_Line (Registry, The_Target, (1 .. 0 => null));
      else
         declare
            Old_Cmd_Line : constant Argument_List :=
                             Get_Command_Line_Unexpanded
                               (Registry, The_Target);
            New_Cmd_Line : Argument_List (Old_Cmd_Line'Range);

         begin
            if New_Cmd_Line'Length > 0 then
               New_Cmd_Line (New_Cmd_Line'First) :=
                 new String'(The_Model.Default_Command_Line
                             (The_Model.Default_Command_Line'First).all);

               for J in New_Cmd_Line'First + 1 .. New_Cmd_Line'Last loop
                  New_Cmd_Line (J) := new String'(Old_Cmd_Line (J).all);
               end loop;

               Set_Command_Line (Registry, The_Target, New_Cmd_Line);

               for J in New_Cmd_Line'Range loop
                  Free (New_Cmd_Line (J));
               end loop;
            end if;
         end;
      end if;
   end Change_Model;

   ----------------------
   -- Duplicate_Target --
   ----------------------

   procedure Duplicate_Target
     (Registry     : Build_Config_Registry_Access;
      Src_Name     : String;
      New_Name     : String;
      New_Category : String)
   is
      Src  : Target_Access;
      Dest : Target_Access;
   begin
      Src := Get_Target_From_Name (Registry, Src_Name);

      if Src = null then
         Log (Registry, -("Cannot duplicate: source target not found: ")
              & Src_Name);
         return;
      end if;

      if Get_Target_From_Name (Registry, New_Name) /= null then
         Log (Registry, -("Cannot duplicate: target already exists: ")
              & New_Name);
         return;
      end if;

      Create_Target (Registry     => Registry,
                     Name         => New_Name,
                     Category     => New_Category,
                     Model        => To_String (Src.Model.Name),
                     Command_Line =>
                       Get_Command_Line_Unexpanded (Registry, Src));

      Dest := Get_Target_From_Name (Registry, New_Name);

      if Dest = null then
         --  This should never happen, but we test just in case
         Log (Registry, -("Could not create target ") & New_Name);
         return;
      end if;

      Dest.Properties := Src.Properties;

      --  If we have duplicated a target using this subprogram, this means the
      --  target is user-created.
      Dest.Properties.Read_Only := False;
   end Duplicate_Target;

   ------------------
   -- Element_Mode --
   ------------------

   function Element_Mode
     (Registry : Build_Config_Registry_Access;
      Name     : Unbounded_String) return Mode_Record is
   begin
      return Registry.Modes.Element (Name);
   end Element_Mode;

   ---------------------
   -- Number_Of_Modes --
   ---------------------

   function Number_Of_Modes
     (Registry : Build_Config_Registry_Access) return Natural is
   begin
      return Natural (Mode_Map.Length (Registry.Modes));
   end Number_Of_Modes;

   -------------------
   -- Contains_Mode --
   -------------------

   function Contains_Mode
     (Registry : Build_Config_Registry_Access;
      Name     : Unbounded_String) return Boolean is
   begin
      return Registry.Modes.Contains (Name);
   end Contains_Mode;

   ----------------
   -- First_Mode --
   ----------------

   function First_Mode
     (Registry : Build_Config_Registry_Access) return Mode_Map.Cursor is
   begin
      return Registry.Modes.First;
   end First_Mode;

   -----------------
   -- Insert_Mode --
   -----------------

   procedure Insert_Mode
     (Registry : Build_Config_Registry_Access;
      Name     : Unbounded_String;
      Mode     : Mode_Record) is
   begin
      if Registry.Modes.Contains (Name) then
         Log (Registry,
              -("Mode with this name already exists: ") & To_String (Name));
      else
         Registry.Modes.Insert (Name, Mode);
      end if;
   end Insert_Mode;

   ------------------
   -- Replace_Mode --
   ------------------

   procedure Replace_Mode
     (Registry : Build_Config_Registry_Access;
      Name     : Unbounded_String;
      Mode     : Mode_Record) is
   begin
      Registry.Modes.Replace (Name, Mode);
   end Replace_Mode;

   ----------------------
   -- Set_Command_Line --
   ----------------------

   procedure Set_Command_Line
     (Registry     : Build_Config_Registry_Access;
      Target       : Target_Access;
      Command_Line : GNAT.OS_Lib.Argument_List)
   is
      pragma Unreferenced (Registry);

   begin
      if Target.Command_Line /= null then
         for J in Target.Command_Line'Range loop
            Free (Target.Command_Line (J));
         end loop;

         Unchecked_Free (Target.Command_Line);
      end if;

      Target.Command_Line := new GNAT.OS_Lib.Argument_List
        (Command_Line'Range);

      for J in Command_Line'Range loop
         Target.Command_Line (J) := new String'(Command_Line (J).all);
      end loop;
   end Set_Command_Line;

   --------------
   -- Contains --
   --------------

   function Contains
     (List : Target_List.List; Key : Unbounded_String) return Boolean
   is
      C : Cursor;
   begin
      C := List.First;

      while Has_Element (C) loop
         if Element (C).Name = Key then
            return True;
         end if;

         Next (C);
      end loop;

      return False;
   end Contains;

   ----------------
   -- Add_Target --
   ----------------

   procedure Add_Target
     (Registry : Build_Config_Registry_Access;
      Target   : Target_Access) is
   begin
      if Contains (Registry.Targets, Target.Name) then
         Log (Registry, -("Target with this name already exists: ")
              & To_String (Target.Name));
         return;
      end if;

      Log (Registry,
           "Creating target '" & To_String (Target.Name) & "'",
           Trace);
      Registry.Targets.Append (Target);
   end Add_Target;

   -------------------
   -- Remove_Target --
   -------------------

   procedure Remove_Target
     (Registry    : Build_Config_Registry_Access;
      Target_Name : String)
   is
      C : Cursor;
      T : Target_Access;
   begin
      C := Registry.Targets.First;

      while Has_Element (C) loop
         if To_String (Element (C).Name) = Target_Name then
            T := Element (C);
            Free (T);
            Registry.Targets.Delete (C);
            exit;
         end if;

         Next (C);
      end loop;
   end Remove_Target;

   --------------------------
   -- Get_Target_From_Name --
   --------------------------

   function Get_Target_From_Name
     (Registry : Build_Config_Registry_Access;
      Name     : String) return Target_Access
   is
      C : Cursor;
   begin
      C := Registry.Targets.First;

      while Has_Element (C) loop
         if To_String (Element (C).Name) = Name then
            return Element (C);
         end if;

         Next (C);
      end loop;

      return null;
   end Get_Target_From_Name;

   ---------------------------------
   -- Get_Command_Line_Unexpanded --
   ---------------------------------

   function Get_Command_Line_Unexpanded
     (Registry : Build_Config_Registry_Access;
      Target   : Target_Access) return GNAT.OS_Lib.Argument_List
   is
      pragma Unreferenced (Registry);
      Empty : constant Argument_List (1 .. 0) := (others => null);
   begin
      if Target = null
        or else Target.Command_Line = null
      then
         --  A target command line should at least contain the command to
         --  launch; if none can be found, return.
         return Empty;
      end if;

      return Target.Command_Line.all;
   end Get_Command_Line_Unexpanded;

   ----------------------
   -- Get_Switch_Value --
   ----------------------

   function Get_Switch_Value
     (Target : Target_Access;
      Switch : String) return String is
   begin
      --  Generated stub: replace with real body!
      raise Program_Error;
      return Get_Switch_Value (Target, Switch);
   end Get_Switch_Value;

   ----------
   -- Free --
   ----------

   procedure Free (Target : in out Target_Type) is
   begin
      GNAT.OS_Lib.Free (Target.Command_Line);
   end Free;

   ------------
   -- Create --
   ------------

   function Create
     (Logger : Logger_Type) return Build_Config_Registry_Access
   is
      Result : Build_Config_Registry_Access;
   begin
      Result := new Build_Config_Registry;
      Result.Logger := Logger;

      return Result;
   end Create;

   -------------------------
   -- Command_Line_To_XML --
   -------------------------

   function Command_Line_To_XML
     (CL   : GNAT.OS_Lib.Argument_List;
      Tag  : String) return Node_Ptr
   is
      N, Arg : Node_Ptr;
   begin
      N := new Node;
      N.Tag := new String'(Tag);

      if CL'Length <= 0 then
         return N;
      end if;

      N.Child := new Node;
      Arg := N.Child;

      for J in CL'Range loop
         Arg.Tag   := new String'("arg");
         Arg.Value := new String'(CL (J).all);

         if J /= CL'Last then
            Arg.Next := new Node;
            Arg := Arg.Next;
         end if;
      end loop;

      return N;
   end Command_Line_To_XML;

   -------------------------
   -- XML_To_Command_Line --
   -------------------------

   function XML_To_Command_Line
     (N : Node_Ptr) return GNAT.OS_Lib.Argument_List
   is
      Count : Natural := 0;
      Arg   : Node_Ptr;
      use type Glib.String_Ptr;
   begin
      Arg := N.Child;

      --  Count the arguments
      while Arg /= null loop
         Count := Count + 1;
         Arg := Arg.Next;
      end loop;

      --  Create the command line
      declare
         CL : GNAT.OS_Lib.Argument_List (1 .. Count);
      begin
         Arg := N.Child;
         for J in 1 .. Count loop
            if Arg.Value = null then
               CL (J) := new String'("");
            else
               CL (J) := new String'(Arg.Value.all);
            end if;

            Arg := Arg.Next;
         end loop;

         return CL;
      end;
   end XML_To_Command_Line;

   ------------------------
   -- Save_Target_To_XML --
   ------------------------

   function Save_Target_To_XML
     (Registry : Build_Config_Registry_Access;
      Target   : Target_Access) return Node_Ptr
   is
      pragma Unreferenced (Registry);
      N : Node_Ptr;
      C : Node_Ptr;
   begin
      N := new Node;
      N.Tag := new String'("target");

      --  Main node
      N.Attributes := new String'
        ("model="""
         & Glib.Xml_Int.Protect (To_String (Target.Model.Name))
         & """ category="""
         & Glib.Xml_Int.Protect (To_String (Target.Properties.Category))
         & """ name="""
         & Glib.Xml_Int.Protect  (To_String (Target.Properties.Menu_Name))
         & """");
      --  Insert a <icon> node if needed

      N.Child := new Node;
      C := N.Child;
      C.Tag := new String'("in-toolbar");
      C.Value := new String'(Target.Properties.In_Toolbar'Img);

      if Target.Properties.Icon /= "" then
         C.Next := new Node;
         C := C.Next;
         C.Tag := new String'("icon");
         C.Value := new String'(To_String (Target.Properties.Icon));
      end if;

      C.Next := new Node;
      C := C.Next;
      C.Tag := new String'("in-menu");
      C.Value := new String'(Target.Properties.In_Menu'Img);

      C.Next := new Node;
      C := C.Next;
      C.Tag := new String'("launch-mode");
      C.Value := new String'(Target.Properties.Launch_Mode'Img);

      C.Next := new Node;
      C := C.Next;
      C.Tag := new String'("read-only");
      C.Value := new String'(Target.Properties.Read_Only'Img);

      C.Next := new Node;
      C := C.Next;
      C.Tag := new String'("target-type");
      C.Value := new String'(To_Lower
                             (To_String (Target.Properties.Target_Type)));

      C.Next := new Node;
      C := C.Next;
      C.Tag := new String'("key");
      C.Value := new String'(To_String (Target.Properties.Key));

      C.Next := new Node;
      C := C.Next;
      C.Tag := new String'("server");
      C.Value := new String'(Target.Properties.Server'Img);

      if Target.Command_Line /= null then
         C.Next := Command_Line_To_XML
           (Target.Command_Line.all, "command-line");
         C := C.Next;
      end if;

      return N;
   end Save_Target_To_XML;

   --------------------------
   -- Load_Target_From_XML --
   --------------------------

   function Load_Target_From_XML
     (Registry  : Build_Config_Registry_Access;
      XML       : Node_Ptr;
      From_User : Boolean) return Target_Access
   is
      Child  : Node_Ptr;
      Target : Target_Access;

      use type Glib.String_Ptr;
   begin
      if XML = null
        or else XML.Tag = null
      then
         Log (Registry, -"Error: empty XML passed to target builder");
         return null;
      end if;

      if XML.Tag.all /= "target" then
         Log (Registry, -"Error: wrong XML passed to target builder");
         return null;
      end if;

      --  Main node

      declare
         Menu_Name : constant String := (Get_Attribute (XML, "name", ""));
         Target_Name : constant String := Strip_Single_Underscores (Menu_Name);
         Category  : constant String := (Get_Attribute (XML, "category", ""));
         Model     : constant String := (Get_Attribute (XML, "model", ""));
      begin
         if Menu_Name = "" then
            Log (Registry,
                 -"Error: <target> node should have a ""name"" attribute");
            return null;
         end if;
         if Category = "" then
            Log (Registry,
                 -"Error: <target> node should have a ""category"" attribute");
            return null;
         end if;
         if Model = "" then
            Log (Registry,
                 -"Error: <target> node should have a ""model"" attribute");
            return null;
         end if;

         if not Registry.Models.Contains (To_Unbounded_String (Model)) then
            Log (Registry, (-"Error: unknown target model: ") & Model);
            return null;
         end if;

         if Contains (Registry.Targets, To_Unbounded_String (Target_Name)) then
            if From_User then
               --  In this case, it is OK to overwrite the data contained in
               --  the target.
               Target := Get_Target_From_Name (Registry, Target_Name);
               Change_Model (Registry, Target_Name, Model);
            else
               Log (Registry, -"Error: target already registered: "
                    & Target_Name);
               return null;
            end if;

         else
            Target := new Target_Type;
            Target.Name  := To_Unbounded_String (Target_Name);
            Target.Properties.Menu_Name := To_Unbounded_String (Menu_Name);
            Target.Properties.Category := To_Unbounded_String (Category);
            Target.Model := Registry.Models.Element
              (To_Unbounded_String (Model));

            Add_Target (Registry, Target);
         end if;
      end;

      Child := XML.Child;

      while Child /= null loop
         if Child.Tag.all = "command-line" then
            Free (Target.Command_Line);
            Target.Command_Line := new GNAT.OS_Lib.Argument_List'
              (XML_To_Command_Line (Child));

         elsif Child.Value = null then
            Log (Registry, -"Warning: empty node in target: " & Child.Tag.all);

         elsif Child.Tag.all = "launch-mode" then
            Target.Properties.Launch_Mode := Launch_Mode_Type'Value
              (Child.Value.all);

         elsif Child.Tag.all = "icon" then
            Target.Properties.Icon := To_Unbounded_String (Child.Value.all);

         elsif Child.Tag.all = "in-toolbar" then
            Target.Properties.In_Toolbar := Boolean'Value (Child.Value.all);

         elsif Child.Tag.all = "in-menu" then
            Target.Properties.In_Menu := Boolean'Value (Child.Value.all);

         elsif Child.Tag.all = "key" then
            Target.Properties.Key := To_Unbounded_String (Child.Value.all);

         elsif Child.Tag.all = "read-only" then
            Target.Properties.Read_Only := Boolean'Value (Child.Value.all);

         elsif Child.Tag.all = "target-type" then
            Set_Unbounded_String
              (Target.Properties.Target_Type, Child.Value.all);

         elsif Child.Tag.all = "server" then
            Target.Properties.Server := Server_Type'Value (Child.Value.all);

         else
            Log (Registry, (-"Warning: invalid child to <target> node: ")
                 & Child.Tag.all);
         end if;

         Child := Child.Next;
      end loop;

      --  At this point, the target data has been updated. If this target is
      --  not from the user configuration, copy it to the original targets.

      Registry.Original_Targets.Append (Copy (Target));

      return Target;
   end Load_Target_From_XML;

   -----------------------------
   -- Save_All_Targets_To_XML --
   -----------------------------

   function Save_All_Targets_To_XML
     (Registry : Build_Config_Registry_Access) return Node_Ptr
   is
      N                  : Node_Ptr;
      Child              : Node_Ptr;
      C                  : Cursor;
      C2                 : Cursor;
      Name               : Unbounded_String;
      Equals_To_Original : Boolean;

   begin
      N := new Node;
      N.Tag := new String'("targets");

      C := Registry.Targets.First;

      while Has_Element (C) loop
         --  Check whether the target has been modified. If so, save it

         Name := Element (C).Name;
         Equals_To_Original := False;
         C2 := Registry.Original_Targets.First;

         while Has_Element (C2) loop
            if Element (C2).Name = Name then
               if Equals (Element (C2), Element (C)) then
                  Equals_To_Original := True;
               end if;
               exit;
            end if;
            Next (C2);
         end loop;

         if not Equals_To_Original then
            if Child = null then
               N.Child := Save_Target_To_XML (Registry, Element (C));
               Child := N.Child;
            else
               Child.Next := Save_Target_To_XML (Registry, Element (C));
               Child := Child.Next;
            end if;
         end if;

         Next (C);
      end loop;

      return N;
   end Save_All_Targets_To_XML;

   -------------------------------
   -- Load_All_Targets_From_XML --
   -------------------------------

   procedure Load_All_Targets_From_XML
     (Registry : Build_Config_Registry_Access;
      XML      : Node_Ptr)
   is
      N : Node_Ptr;
      T : Target_Access;
      pragma Unreferenced (T);
      use type Glib.String_Ptr;
   begin
      if XML = null
        or else XML.Tag = null
        or else XML.Tag.all /= "targets"
      then
         Log (Registry, "Invalid XML found when loading multiple targets");
         return;
      end if;

      N := XML.Child;

      while N /= null loop
         T := Load_Target_From_XML
           (Registry => Registry, XML => N, From_User => True);
         N := N.Next;
      end loop;
   end Load_All_Targets_From_XML;

   --------------------
   -- Get_Properties --
   --------------------

   function Get_Properties (Target : Target_Access) return Target_Properties is
   begin
      return Target.Properties;
   end Get_Properties;

   ----------------------
   -- Get_First_Target --
   ----------------------

   function Get_First_Target
     (Registry : Build_Config_Registry_Access) return Target_Cursor is
   begin
      return Target_Cursor (Registry.Targets.First);
   end Get_First_Target;

   ----------------
   -- Get_Target --
   ----------------

   function Get_Target (Cursor : Target_Cursor) return Target_Access is
   begin
      if Has_Element (Cursor) then
         return Element (Cursor);
      else
         return null;
      end if;
   end Get_Target;

   ----------
   -- Next --
   ----------

   overriding procedure Next (Cursor : in out Target_Cursor) is
   begin
      Target_List.Next (Target_List.Cursor (Cursor));
   end Next;

   --------------
   -- Get_Name --
   --------------

   function Get_Name (Target : Target_Access) return String is
   begin
      return To_String (Target.Name);
   end Get_Name;

   -------------------
   -- Get_Menu_Name --
   -------------------

   function Get_Menu_Name (Target : Target_Access) return String is
   begin
      return To_String (Target.Properties.Menu_Name);
   end Get_Menu_Name;

   ------------------
   -- Get_Category --
   ------------------

   function Get_Category (Target : Target_Access) return String is
   begin
      return To_String (Target.Properties.Category);
   end Get_Category;

   ----------------
   -- Get_Server --
   ----------------

   function Get_Server (Target : Target_Access) return Server_Type is
   begin
      if Target.Properties.Server = GPS_Server then
         return Target.Model.Server;
      else
         return Target.Properties.Server;
      end if;
   end Get_Server;

   --------------
   -- Get_Icon --
   --------------

   function Get_Icon (Target : Target_Access) return String is
   begin
      if Target.Properties.Icon = "" then
         return To_String (Target.Model.Icon);
      else
         return To_String (Target.Properties.Icon);
      end if;
   end Get_Icon;

   -------------------------
   -- Is_Registered_Model --
   -------------------------

   function Is_Registered_Model
     (Registry : Build_Config_Registry_Access;
      Name     : Unbounded_String) return Boolean is
   begin
      return Registry.Models.Contains (Name);
   end Is_Registered_Model;

   -------------------
   -- Revert_Target --
   -------------------

   procedure Revert_Target
     (Registry : Build_Config_Registry_Access;
      Target   : String)
   is
      O, C : Cursor;
      T    : Target_Access;
   begin
      O := Registry.Targets.First;

      while Has_Element (O) loop
         if Element (O).Name = Target then
            T := Element (O);
            exit;
         end if;

         Next (O);
      end loop;

      if not Has_Element (O) then
         Log (Registry, "Revert_Target: original target not found", Trace);
         return;
      end if;

      C := Registry.Original_Targets.First;

      while Has_Element (C) loop
         if Element (C).Name = Target then
            Free (T);  --  Free old target
            Registry.Targets.Replace_Element (O, Copy (Element (C)));
            exit;
         end if;

         Next (C);
      end loop;
   end Revert_Target;

   ---------------
   -- Get_Model --
   ---------------

   function Get_Model (Target : Target_Access) return String is
   begin
      return To_String (Target.Model.Name);
   end Get_Model;

   ----------------
   -- Uses_Shell --
   ----------------

   function Uses_Shell (Target : Target_Access) return Boolean is
   begin
      return Target.Model.Uses_Shell;
   end Uses_Shell;

   ----------
   -- Free --
   ----------

   procedure Free (Target : in out Target_Access) is
      procedure Unchecked_Free is new Ada.Unchecked_Deallocation
        (Target_Type, Target_Access);
   begin
      if Target /= null then
         --  Target.Model;   --  No need to free, references in the Registry
         Free (Target.Command_Line);
         --  Free (Target.Properties);  --  Nothing to free

         Unchecked_Free (Target);
      end if;
   end Free;

   ----------
   -- Free --
   ----------

   procedure Free (List : in out Target_List.List) is
      C : Target_List.Cursor := First (List);
      T : Target_Access;
   begin
      while Has_Element (C) loop
         T := Element (C);
         Free (T);
         Next (C);
      end loop;

      Target_List.Clear (List);
   end Free;

   ----------
   -- Free --
   ----------

   procedure Free (Models : in out Model_Map.Map) is
      procedure Unchecked_Free is new Ada.Unchecked_Deallocation
        (Target_Model_Type, Target_Model_Access);
      use Model_Map;

      C : Model_Map.Cursor := First (Models);
      M : Target_Model_Access;
   begin
      while Has_Element (C) loop
         M := Element (C);

         Free (M.Default_Command_Line);
         Free (M.Switches);
         Unchecked_Free (M);

         Next (C);
      end loop;

      Model_Map.Clear (Models);
   end Free;

   ----------
   -- Free --
   ----------

   procedure Free (Modes : in out Mode_Map.Map) is
      use Mode_Map;
      C : Mode_Map.Cursor := Mode_Map.First (Modes);
      M : Mode_Record;
   begin
      while Has_Element (C) loop
         M := Element (C);
         Free (M.Args);
         Free (M.Subst_Src);
         Free (M.Subst_Dest);
         Next (C);
      end loop;

      Mode_Map.Clear (Modes);
   end Free;

   ----------
   -- Free --
   ----------

   procedure Free (Registry : in out Build_Config_Registry_Access) is
      procedure Unchecked_Free is new Ada.Unchecked_Deallocation
        (Build_Config_Registry, Build_Config_Registry_Access);
   begin
      if Registry /= null then
         Free (Registry.Models);
         Free (Registry.Targets);
         Free (Registry.Modes);
         Free (Registry.Original_Targets);
         Unchecked_Free (Registry);
      end if;
   end Free;

end Build_Configurations;
