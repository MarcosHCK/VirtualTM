/* Copyright 2023-2025 MarcosHCK
 * This file is part of virtualtm.
 *
 * virtualtm is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * virtualtm is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with virtualtm. If not, see <http://www.gnu.org/licenses/>.
 */

namespace VirtualTM
{
  public class Application : GLib.Application, Daemon
    {
      private VirtualTM.Database database;

      private GLib.OptionEntry[] option_entries;
      private GLib.ActionEntry[] action_entries;
      private uint daemonid = 0;

      private unowned bool local_opt = false;
      private unowned int bank_opt = 44556677;
      private unowned int bankid_opt = 33445566;
      private unowned int port_opt = 8999;
      private unowned int tmid_opt = 22334455;
      private unowned string database_opt = "virtualtm.db";
      private unowned string endpoint_opt = "/";
      private unowned string phone_opt = "+53 5xxxxxxx";

      public static int main (string[] argv)
        {
          var application = new Application ();
          var result = application.run (argv);
          return result;
        }

      public Application ()
        {
          Object (application_id : "org.hck.virtualtm.Daemon", flags : 0);

          action_entries =
            {
              { "quit", () => quit (), null, null, null, },
            };

          option_entries =
            {
              { "bank", 0, 0, GLib.OptionArg.INT, ref bank_opt, "Set notification Bank field value to VALUE", "VALUE", },
              { "bankid", 0, 0, GLib.OptionArg.INT, ref bankid_opt, "Set notification BankId field value to VALUE", "VALUE", },
              { "database", 'd', 0, GLib.OptionArg.FILENAME, ref database_opt, "Use database FILE", "FILE", },
              { "endpoint", 0, 0, GLib.OptionArg.STRING, ref endpoint_opt, "Expose REST API on endpoint NAME", "NAME", },
              { "local", 'l', 0, GLib.OptionArg.NONE, ref local_opt, "Only listen locally", null, },
              { "phone", 0, 0, GLib.OptionArg.STRING, ref phone_opt, "Set notification Phone field value to VALUE", "VALUE", },
              { "port", 'p', 0, GLib.OptionArg.INT, ref port_opt, "Listen to requests at port PORT", "PORT", },
              { "tmid", 0, 0, GLib.OptionArg.INT, ref tmid_opt, "Set notification TmId field value to VALUE", "VALUE", },
              { "version", 'V', 0, GLib.OptionArg.NONE, null, "Print version and exit", null, },
            };

          add_action_entries (action_entries, this);
          add_main_option_entries (option_entries);
        }

      public override void activate ()
        {
          hold ();
        }

      public override bool dbus_register (GLib.DBusConnection connection, string object_path) throws GLib.Error
        {
          var result = base.dbus_register (connection, object_path);
          var regid = connection.register_object (object_path, (Daemon) this);
            daemonid = regid;
          return result;
        }

      public override void dbus_unregister (GLib.DBusConnection connection, string object_path)
        {
          if (daemonid > 0)
            connection.unregister_object (daemonid);
          base.dbus_unregister (connection, object_path);
        }

      public override int handle_local_options (GLib.VariantDict dict)
        {
          bool flag;
          if (dict.lookup ("version", "b", out flag))
            {
              print ("%s\n", Config.PACKAGE_STRING);
              return Posix.EXIT_SUCCESS;
            }
        return -1;
        }

      public string[] list () throws GLib.Error
        {
          return database.get_pending ();
        }

      public bool pay (string externalid) throws GLib.Error
        {
          var payment = database.get_payment (externalid);
          return true;
        }

      public override void shutdown ()
        {
          base.shutdown ();
        }

      public override void startup ()
        {
          base.startup ();

          try {
            database = new VirtualTM.Database (database_opt);
            }
          catch (GLib.Error e)
            {
              critical (@"$(e.domain): $(e.code): $(e.message)");
            }
        }
    }
}
