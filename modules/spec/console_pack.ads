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

with Ada.Synchronous_Task_Control; use Ada.Synchronous_Task_Control;

with CRTP_Pack;                    use CRTP_Pack;

package Console_Pack is

   --  Procedures and functions

   --  Initialize the console module.
   procedure Console_Init;

   --  Flush the console buffer.
   procedure Console_Flush (Has_Succeed : out Boolean);

   --  Test if the console module is initialized.
   function  Console_Test return Boolean;

   --  Put a string in the console buffer, and send it if a newline
   --  character is found.
   procedure Console_Put_Line
     (Message     : String;
      Has_Succeed : out Boolean);

private

   --  Global variables

   Is_Init          : Boolean := False;
   Console_Access   : Suspension_Object;
   Message_To_Print : CRTP_Packet_Handler;

   --  Procedures and functions

   --  Send the console buffer via CRTP.
   procedure Console_Send_Message (Has_Succeed : out Boolean);

end Console_Pack;