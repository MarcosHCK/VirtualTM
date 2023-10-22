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
#include <config.h>
#include <gio/gio.h>
#include <libsoup/soup-server.h>
#include <libsoup/soup-server-message.h>

struct _VtmApplication
{
  GApplication parent;

  /* <private> */
  gchar* endpoint;
  SoupServer* server;
};

G_DECLARE_FINAL_TYPE (VtmApplication, vtm_application, VTM, APPLICATION, GApplication);
G_DEFINE_FINAL_TYPE (VtmApplication, vtm_application, G_TYPE_APPLICATION);

#define _g_free0(var) ((var == NULL) ? NULL : (var = (g_free (var), NULL)))
#define _g_object_unref0(var) ((var == NULL) ? NULL : (var = (g_object_unref (var), NULL)))

static void handle_request2 (VtmApplication* self, SoupServerMessage* message);
static void handle_request (SoupServer* server, SoupServerMessage* message, const gchar* path, GHashTable* query, VtmApplication* self);
static int handle_cmdline (GApplicationCommandLine* cmdline);

int main (int argc, char* argv [])
{
  GApplication* application;
  GApplicationFlags flags = G_APPLICATION_HANDLES_COMMAND_LINE;
  const gchar* id = "org.hck.vitualtm";
  int result;

  const GOptionEntry entries [] =
    {
      /* handle locally */
      { "version", 'V', G_OPTION_FLAG_NONE, G_OPTION_ARG_NONE, NULL, "Print version and exit", NULL, },

      /* handle remotely */
      { "endpoint", 0, G_OPTION_FLAG_NONE, G_OPTION_ARG_STRING, NULL, "Expose REST API on endpoint NAME", "NAME", },
      { "local", 'l', G_OPTION_FLAG_NONE, G_OPTION_ARG_NONE, NULL, "Only listen locally", NULL, },
      { "port", 'p', G_OPTION_FLAG_NONE, G_OPTION_ARG_INT, NULL, "Listen to requests at port PORT", "PORT", },
      G_OPTION_ENTRY_NULL,
    };

  application = g_object_new (vtm_application_get_type (), "flags", flags, "application-id", id, NULL);
           g_application_add_main_option_entries (G_APPLICATION (application), entries);
  result = g_application_run (G_APPLICATION (application), argc, argv);
return (g_object_unref (application), result);
}

static void vtm_application_init (VtmApplication* self)
{
}

static int handle_cmdline (GApplicationCommandLine* cmdline)
{
  GError* tmperr = NULL;
  GVariantDict* dict = NULL;
  VtmApplication* self = NULL;
  int remote = FALSE;

  const gchar* endpoint;
  gboolean flag;
  gint port;

  dict = g_application_command_line_get_options_dict (cmdline);
  remote = g_application_command_line_get_is_remote (cmdline);
  self = g_object_get_data (G_OBJECT (cmdline), "vtm.app");

  if (remote == FALSE)
    {
      if (g_variant_dict_lookup (dict, "port", "i", &port) == FALSE)
        port = 8999;
      if (g_variant_dict_lookup (dict, "endpoint", "s", &endpoint) == FALSE)
        endpoint = "/";

      GPathBuf pathbuf = G_PATH_BUF_INIT;
      g_path_buf_push (&pathbuf, "/");
      g_path_buf_push (&pathbuf, endpoint);

      self->endpoint = g_path_buf_clear_to_path (&pathbuf);
      self->server = soup_server_new ("server-header", "VirtualTM Server ", NULL);

      if (g_variant_dict_lookup (dict, "local", "b", &flag))
        soup_server_listen_local (self->server, port, 0, &tmperr);
      else
        soup_server_listen_all (self->server, port, 0, &tmperr);

      if (G_LIKELY (tmperr == NULL))
        {
          g_application_hold (G_APPLICATION (self));
          soup_server_add_handler (self->server, self->endpoint, (SoupServerCallback) handle_request, self, NULL);

          g_message ("Listening on %u, '%s'", port, self->endpoint);
        }
      else
        {
          g_application_command_line_printerr (cmdline, G_LOG_DOMAIN ": %s\n", tmperr->message);
          g_error_free (tmperr);
          g_application_command_line_set_exit_status (cmdline, 1);
        }
    }
return G_SOURCE_REMOVE;
}

static void handle_request (SoupServer* server, SoupServerMessage* message, const gchar* path, GHashTable* query, VtmApplication* self)
{
  const gchar* method = soup_server_message_get_method (message);
  const gchar* version = NULL;
  gint status = SOUP_STATUS_OK;

  switch (soup_server_message_get_http_version (message))
    {
      default: g_assert_not_reached ();
      case SOUP_HTTP_1_0: version = "1.0"; break;
      case SOUP_HTTP_1_1: version = "1.1"; break;
      case SOUP_HTTP_2_0: version = "2.0"; break;
    }

  if (g_str_equal (path, self->endpoint) == FALSE)
    {
      status = SOUP_STATUS_SEE_OTHER;
      soup_server_message_set_redirect (message, status, self->endpoint);
    }
  else if (g_str_equal (method, "POST") == FALSE)
    {
      status = SOUP_STATUS_METHOD_NOT_ALLOWED;
      soup_server_message_set_status (message, status, soup_status_get_phrase (status));
    }
  else
    {
      handle_request2 (self, message);
    }

  g_print ("%s (HTTP %s) %s %i\n", method, version, path, status);
}

static void handle_request2 (VtmApplication* self, SoupServerMessage* message)
{
}

static int vtm_application_class_command_line (GApplication* pself, GApplicationCommandLine* cmdline)
{
  g_application_hold (pself);
  g_object_set_data_full (G_OBJECT (cmdline), "vtm.app", pself, (GDestroyNotify) g_application_release);
  g_idle_add_full (G_PRIORITY_DEFAULT_IDLE, (GSourceFunc) handle_cmdline, cmdline, g_object_unref);
return (g_object_ref (cmdline), EXIT_SUCCESS);
}

static void vtm_application_class_dispose (GObject* pself)
{
  VtmApplication* self = (gpointer) pself;
  _g_object_unref0 (self->server);
G_OBJECT_CLASS (vtm_application_parent_class)->dispose (pself);
}

static void vtm_application_class_finalize (GObject* pself)
{
  VtmApplication* self = (gpointer) pself;
  _g_free0 (self->endpoint);
G_OBJECT_CLASS (vtm_application_parent_class)->finalize (pself);
}

static int vtm_application_class_handle_local_options (GApplication* pself, GVariantDict* dict)
{
  gboolean count;

  if (g_variant_dict_lookup (dict, "version", "b", &count))
    {
      g_print ("%s\n", PACKAGE_STRING);
      return EXIT_SUCCESS;
    }
return -1;
}

static void vtm_application_class_shutdown (GApplication* pself)
{
  VtmApplication* self = (gpointer) pself;

  if (self->server != NULL)
    soup_server_disconnect (self->server);
}

static void vtm_application_class_init (VtmApplicationClass* klass)
{
  G_APPLICATION_CLASS (klass)->command_line = vtm_application_class_command_line;
  G_APPLICATION_CLASS (klass)->handle_local_options = vtm_application_class_handle_local_options;
  G_APPLICATION_CLASS (klass)->shutdown = vtm_application_class_shutdown;
  G_OBJECT_CLASS (klass)->dispose = vtm_application_class_dispose;
  G_OBJECT_CLASS (klass)->finalize = vtm_application_class_finalize;
}
