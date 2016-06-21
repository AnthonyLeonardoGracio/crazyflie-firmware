------------------------------------------------------------------------------
--                              Certyflie                                   --
--                                                                          --
--                     Copyright (C) 2015-2016, AdaCore                     --
--                                                                          --
--  This library is free software;  you can redistribute it and/or modify   --
--  it under terms of the  GNU General Public License  as published by the  --
--  Free Software  Foundation;  either version 3,  or (at your  option) any --
--  later version. This library is distributed in the hope that it will be  --
--  useful, but WITHOUT ANY WARRANTY;  without even the implied warranty of --
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                    --
--                                                                          --
--  As a special exception under Section 7 of GPL version 3, you are        --
--  granted additional permissions described in the GCC Runtime Library     --
--  Exception, version 3.1, as published by the Free Software Foundation.   --
--                                                                          --
--  You should have received a copy of the GNU General Public License and   --
--  a copy of the GCC Runtime Library Exception along with this program;    --
--  see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see   --
--  <http://www.gnu.org/licenses/>.                                         --
--                                                                          --
--  As a special exception, if other files instantiate generics from this   --
--  unit, or you link this unit with other files to produce an executable,  --
--  this  unit  does not  by itself cause  the resulting executable to be   --
--  covered by the GNU General Public License. This exception does not      --
--  however invalidate any other reasons why the executable file  might be  --
--  covered by the  GNU Public License.                                     --
------------------------------------------------------------------------------

with Ada.Unchecked_Conversion;

with Log;                      use Log;

package body Power_Management
with Refined_State => (Power_Management_State => (Current_Power_Info,
                                                  Current_Power_State,
                                                  Battery_Voltage,
                                                  Battery_Voltage_Min,
                                                  Battery_Voltage_Max,
                                                  Battery_Low_Time_Stamp))
is

   ---------------------------
   -- Power_Management_Init --
   ---------------------------

   procedure Power_Management_Init is
      Group_ID : Natural;
      Has_Succeed : Boolean;
      pragma Unreferenced (Has_Succeed);

   begin
      Current_Power_State := Battery;

      Create_Log_Group
        (Name        => "pm",
         Group_ID    => Group_ID,
         Has_Succeed => Has_Succeed);
      Append_Log_Variable_To_Group
        (Group_ID     => Group_ID,
         Name         => "vbat",
         Log_Type     => LOG_FLOAT,
         Variable     => Battery_Voltage'Address,
         Has_Succeed  => Has_Succeed);
   end Power_Management_Init;

   ------------------------------------------
   -- Power_Management_Set_Battery_Voltage --
   ------------------------------------------

   procedure Power_Management_Set_Battery_Voltage (Voltage : Float) is
   begin
      Battery_Voltage := Voltage;

      if Battery_Voltage_Max < Voltage then
         Battery_Voltage_Max := Voltage;
      end if;

      if Battery_Voltage_Min > Voltage then
         Battery_Voltage_Min := Voltage;
      end if;
   end Power_Management_Set_Battery_Voltage;

   ------------------------------------------
   -- Power_Management_Get_Battery_Voltage --
   ------------------------------------------

   function Power_Management_Get_Battery_Voltage return Float is
     (Battery_Voltage);

   ----------------------------------------------
   -- Power_Management_Get_Charge_From_Voltage --
   ----------------------------------------------

   function Power_Management_Get_Charge_From_Voltage
     (Voltage : Float) return Integer
   is
      Charge : Integer := 0;
   begin
      if Voltage < Bat_671723HS25C (1) then
         return 0;
      end if;

      if Voltage > Bat_671723HS25C (9) then
         return 9;
      end if;

      while Voltage > Bat_671723HS25C (Charge) loop
         Charge := Charge + 1;
      end loop;

      return Charge;
   end Power_Management_Get_Charge_From_Voltage;

   -------------------------------------
   -- Power_Management_Syslink_Update --
   -------------------------------------

   procedure Power_Management_Syslink_Update (Sl_Packet : Syslink_Packet) is
      subtype Power_Data is T_Uint8_Array (1 .. 9);
      function Syslink_Data_To_Power_Syslink_Info is
         new Ada.Unchecked_Conversion (Power_Data, Power_Syslink_Info);
   begin
      Current_Power_Info :=
        Syslink_Data_To_Power_Syslink_Info (Sl_Packet.Data (1 .. 9));
      Power_Management_Set_Battery_Voltage (Current_Power_Info.V_Bat_1);
   end Power_Management_Syslink_Update;

   --------------------------------
   -- Power_Management_Get_State --
   --------------------------------

   function Power_Management_Get_State
     (Power_Info : Power_Syslink_Info) return Power_State
   is
      State : Power_State;
      Is_Charging      : Boolean;
      Is_Pgood         : Boolean;
      Battery_Low_Time : Time_Span;
   begin
      Is_Charging := Power_Info.Charging;
      Is_Pgood := Power_Info.Pgood;
      Battery_Low_Time := Clock - Battery_Low_Time_Stamp;

      if Is_Pgood and not Is_Charging
      then
         State := Charged;
      elsif Is_Charging then
         State := Charging;
      elsif not Is_Pgood and not Is_Charging and
        Battery_Low_Time > PM_BAT_LOW_TIMEOUT
      then
         State := Low_Power;
      else
         State := Battery;
      end if;

      return State;
   end Power_Management_Get_State;

   -------------------------------------
   -- Power_Management_Is_Discharging --
   -------------------------------------

   function Power_Management_Is_Discharging return Boolean is
      State : Power_State;
   begin
      State := Power_Management_Get_State (Current_Power_Info);

      return State = Battery;
   end Power_Management_Is_Discharging;

   --------------------
   -- Set_Power_LEDs --
   --------------------

   procedure Set_Power_LEDs (State : Power_State) is
   begin
      case State is
         when Charging =>
            Enable_LED_Status (Charging_Battery);
         when Charged =>
            Enable_LED_Status (Ready_To_Fly);
         when Low_Power =>
            Enable_LED_Status (Low_Power_Battery);
         when Battery =>
            Enable_LED_Status (Ready_To_Fly);
         when others =>
            null;
      end case;
      --  TODO: find other led feedback for the other power states
   end Set_Power_LEDs;

   ---------------------------
   -- Power_Management_Task --
   ---------------------------

   task body Power_Management_Task is
      Next_Period     : Time;
      New_Power_State : Power_State;
   begin
      Next_Period := Clock + Milliseconds (500);

      Battery_Low_Time_Stamp := Clock;

      loop
         delay until Next_Period;

         if Battery_Voltage > PM_BAT_LOW_VOLTAGE then
            Battery_Low_Time_Stamp := Clock;
         end if;

         New_Power_State := Power_Management_Get_State (Current_Power_Info);

         --  Set the leds accordingly if teh power state has changed
         if Current_Power_State /= New_Power_State then
            Set_Power_LEDs (New_Power_State);
            Current_Power_State := New_Power_State;
         end if;

         Next_Period := Next_Period + Milliseconds (500);
      end loop;
   end Power_Management_Task;

end Power_Management;