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
  public class Client : GLib.Object
    {
      private const string bus_name = "org.hck.virtualtm.Daemon";
      private const string object_path = "/org/hck/virtualtm/Daemon";

      static bool handle_version (string option_name, string? val, void* data) throws GLib.Error
        {
          print ("%s\n", Config.PACKAGE_STRING);
          Posix.exit (Posix.EXIT_SUCCESS);

          /* not reached, Posix.exit misses NoReturn attribute */
          return true;
        }

      public static int main (string[] argv)
        {
          var connection = (GLib.DBusConnection) null;
          var externalid = (string) null;
          var list_opt = false;
          var quit_opt = false;
          var result = false;

          GLib.OptionEntry[] entries =
            {
              { "list", 'l', GLib.OptionFlags.NONE, GLib.OptionArg.NONE, ref list_opt, "List pending payments", null, },
              { "pay", 'p', GLib.OptionFlags.NONE, GLib.OptionArg.STRING, ref externalid, "Set pending payment ID as completed", "ID", },
              { "quit", 'q', GLib.OptionFlags.NONE, GLib.OptionArg.NONE, ref quit_opt, "Stop background daemon", null, },
              { "version", 'V', GLib.OptionFlags.NO_ARG, GLib.OptionArg.CALLBACK, (void*) handle_version, "Print version and exit", null, },
            };

          var context = new GLib.OptionContext (null);

          context.add_main_entries (entries, null);
          context.set_help_enabled (true);
          context.set_ignore_unknown_options (false);
          context.set_strict_posix (false);

          try
            {
              result = context.parse (ref argv);
              connection = GLib.Bus.get_sync (GLib.BusType.SESSION);

              if ((externalid == null ? 0 : 1) + (list_opt ? 1 : 0) + (quit_opt ? 1 : 0) != 1)
                printerr ("Specify one of: -l, -p or -q\n");
              else
                {
                  if (quit_opt)
                    {
                      var action_group = GLib.DBusActionGroup.@get (connection, bus_name, object_path);
                        action_group.activate_action ("quit", null);
                    }
                  else
                    {
                      var daemon = connection.get_proxy_sync<Daemon> (bus_name, object_path);

                      if (externalid != null)
                        daemon.pay (externalid);
                      else
                        {
                          foreach (var item in daemon.list ())
                            print ("%s\n", item);
                        }
                    }
                }

              connection.flush_sync ();
            }
          catch (GLib.Error e)
            {
              result = false;
              critical (@"$(e.domain): $(e.code): $(e.message)");
            }
          return result ? Posix.EXIT_SUCCESS : Posix.EXIT_FAILURE;
        }
    }
}
