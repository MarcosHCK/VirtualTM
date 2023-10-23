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
#include <json-glib/json-glib.h>
#include <libsoup/soup-message-body.h>
#include <libsoup/soup-server-message.h>
#include <libsoup/soup-server.h>
#include <sqlite3.h>

struct _VtmApplication
{
  GApplication parent;

  /* <private> */
  gchar* endpoint;
  SoupServer* server;
  sqlite3* database;
};

typedef enum
{
  VTM_APPLICATION_ERROR_FAILED,
  VTM_APPLICATION_ERROR_INVALID_HEADER_PASSWORD,
  VTM_APPLICATION_ERROR_INVALID_HEADER_SOURCEID,
  VTM_APPLICATION_ERROR_INVALID_HEADER_USERNAME,
  VTM_APPLICATION_ERROR_INVALID_REQUEST_JSON,
} VtmApplicationError;

#define REQUEST_PARAM_AMOUNT "Amount"
#define REQUEST_PARAM_CURRENCY "Currency"
#define REQUEST_PARAM_DESCRIPTION "Description"
#define REQUEST_PARAM_EXTERNALID "ExternalId"
#define REQUEST_PARAM_SOURCE "Source"
#define REQUEST_PARAM_NOTIFYURL "UrlResponse"
#define REQUEST_PARAM_VALIDTIME "ValidTime"

#define SQL_LIST_PAYMENT "SELECT * FROM Payment;"

G_DECLARE_FINAL_TYPE (VtmApplication, vtm_application, VTM, APPLICATION, GApplication);
G_DEFINE_FINAL_TYPE (VtmApplication, vtm_application, G_TYPE_APPLICATION);

#define VTM_APPLICATION_ERROR (vtm_application_error_quark ())
#define VTM_TYPE_APPLICATION (vtm_application_get_type ())

#define _g_free0(var) ((var == NULL) ? NULL : (var = (g_free (var), NULL)))
#define _g_object_unref0(var) ((var == NULL) ? NULL : (var = (g_object_unref (var), NULL)))
#define _sqlite3_close0(var) ((var == NULL) ? NULL : (var = (sqlite3_close (var), NULL)))
#define _sqlite3_finalize0(var) ((var == NULL) ? NULL : (var = (sqlite3_finalize (var), NULL)))

#define cool_real_member(object,name) (cool_member ((object), (name), G_TYPE_DOUBLE) || cool_member ((object), (name), G_TYPE_INT64))

static G_DEFINE_QUARK (vtm-application-error-quark, vtm_application_error);
static int cool_member (JsonObject* object, const gchar* name, GType expected_type);
static int handle_cmdline (GApplicationCommandLine* cmdline);
static int handle_client (VtmApplication* self, GApplicationCommandLine* cmdline);
static void handle_request (SoupServer* server, SoupServerMessage* message, const gchar* path, GHashTable* query, VtmApplication* self);
static int handle_request2 (VtmApplication* self, SoupServerMessage* message, GError** error);
static int handle_request3 (VtmApplication* self, SoupServerMessage* message, JsonObject* request, GError** error);

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

      /* handle remotely (server options) */
      { "database", 'd', G_OPTION_FLAG_NONE, G_OPTION_ARG_FILENAME, NULL, "Use database FILE", "FILE", },
      { "endpoint", 0, G_OPTION_FLAG_NONE, G_OPTION_ARG_STRING, NULL, "Expose REST API on endpoint NAME", "NAME", },
      { "local", 'l', G_OPTION_FLAG_NONE, G_OPTION_ARG_NONE, NULL, "Only listen locally", NULL, },
      { "port", 'p', G_OPTION_FLAG_NONE, G_OPTION_ARG_INT, NULL, "Listen to requests at port PORT", "PORT", },

      /* handle remotely (client options) */
      { "list", 'l', G_OPTION_FLAG_NONE, G_OPTION_ARG_NONE, NULL, "List pending payments", NULL, },
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

static int cool_member (JsonObject* object, const gchar* name, GType expected_type)
{
  if (json_object_has_member (object, name))
    {
      JsonNode* node = NULL;
      GType got_type = 0;

      if (JSON_NODE_HOLDS_VALUE (node = json_object_get_member (object, name)))
        {
          got_type = json_node_get_value_type (node);
          return g_type_is_a (got_type, expected_type);
        }
    }
return FALSE;
}

static int handle_cmdline (GApplicationCommandLine* cmdline)
{
  GError* tmperr = NULL;
  GVariantDict* dict = NULL;
  VtmApplication* self = NULL;
  gint remote = FALSE;
  gint result = 0;

  const gchar* database;
  const gchar* endpoint;
  gboolean flag;
  gint port;

  dict = g_application_command_line_get_options_dict (cmdline);
  remote = g_application_command_line_get_is_remote (cmdline);
  self = g_object_get_data (G_OBJECT (cmdline), "vtm.app");

  if (remote)
    {
      result = handle_client (self, cmdline);
    }
  else
    {
      if (g_variant_dict_lookup (dict, "database", "s", &database) == NULL)
        database = "virtualtm.sqlite";
      if (g_variant_dict_lookup (dict, "endpoint", "s", &endpoint) == NULL)
        endpoint = "/";
      if (g_variant_dict_lookup (dict, "port", "i", &port) == FALSE)
        port = 8999;

      if ((result = sqlite3_open (database, &self->database)), G_UNLIKELY (result != SQLITE_OK))
        {
          g_application_command_line_printerr (cmdline, G_LOG_DOMAIN ": %s\n", sqlite3_errmsg (self->database));
          sqlite3_close (self->database);
          g_application_command_line_set_exit_status (cmdline, 1);
        }
      else
        {
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
            }
          else
            {
              g_application_command_line_printerr (cmdline, G_LOG_DOMAIN ": %s\n", tmperr->message);
              g_error_free (tmperr);
              g_application_command_line_set_exit_status (cmdline, 1);
            }
        }
    }
return G_SOURCE_REMOVE;
}

static int handle_client (VtmApplication* self, GApplicationCommandLine* cmdline)
{
  GVariantDict* dict;
  gboolean flag;

  dict = g_application_command_line_get_options_dict (cmdline);

  if (g_variant_dict_lookup (dict, "list", "b", &flag))
    {
    }
  return TRUE;
}

static void handle_request (SoupServer* server, SoupServerMessage* message, const gchar* path, GHashTable* query, VtmApplication* self)
{
  const gchar* method = soup_server_message_get_method (message);
  const gchar* version = NULL;

  GError* tmperr = NULL;
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
      if ((handle_request2 (self, message, &tmperr)), G_LIKELY (tmperr == NULL))

        soup_server_message_pause (message);
      else
        {
          if (tmperr->domain == JSON_PARSER_ERROR
           || tmperr->domain == VTM_APPLICATION_ERROR)
            status = SOUP_STATUS_BAD_REQUEST;
          else
            status = SOUP_STATUS_INTERNAL_SERVER_ERROR;

          soup_server_message_set_status (message, status, soup_status_get_phrase (status));
          g_warning ("%s: %u: %s", g_quark_to_string (tmperr->domain), tmperr->code, tmperr->message);
        }
    }

  g_print ("%s (HTTP %s) %s %i\n", method, version, path, status);
}

static int handle_request2 (VtmApplication* self, SoupServerMessage* message, GError** error)
{
  JsonParser* parser = NULL;
  SoupMessageBody* body = NULL;
  SoupMessageHeaders* headers = NULL;
  gboolean result = FALSE;
  guint64 source_id = 0;
  const gchar* password = NULL;
  const gchar* sourceid = NULL;
  const gchar* username = NULL;

  body = soup_server_message_get_request_body (message);
  headers = soup_server_message_get_request_headers (message);

  if ((password = soup_message_headers_get_one (headers, "password")), G_UNLIKELY (password == NULL))
    g_set_error (error, VTM_APPLICATION_ERROR, VTM_APPLICATION_ERROR_INVALID_HEADER_PASSWORD, "Invalid request data");
  else if ((sourceid = soup_message_headers_get_one (headers, "source")), G_UNLIKELY (sourceid == NULL))
    g_set_error (error, VTM_APPLICATION_ERROR, VTM_APPLICATION_ERROR_INVALID_HEADER_SOURCEID, "Invalid request data");
  else if ((username = soup_message_headers_get_one (headers, "username")), G_UNLIKELY (username == NULL))
    g_set_error (error, VTM_APPLICATION_ERROR, VTM_APPLICATION_ERROR_INVALID_HEADER_USERNAME, "Invalid request data");
  else if ((result = g_ascii_string_to_unsigned (sourceid, 10, 0, G_MAXINT64, &source_id, error)), G_LIKELY (result == TRUE))
    {
      parser = json_parser_new ();

      if ((result = json_parser_load_from_data (parser, body->data, body->length, error)), G_UNLIKELY (result == TRUE))
    {
      JsonNode* node;
      JsonObject* object;

      if (JSON_NODE_HOLDS_OBJECT (node = json_parser_get_root (parser)) == FALSE)
        g_set_error (error, VTM_APPLICATION_ERROR, VTM_APPLICATION_ERROR_INVALID_REQUEST_JSON, "Invalid request data");
      else
    {
      object = json_node_get_object (node);

      if (JSON_NODE_HOLDS_OBJECT (node = json_object_get_member (object, "request")) == FALSE)
        g_set_error (error, VTM_APPLICATION_ERROR, VTM_APPLICATION_ERROR_INVALID_REQUEST_JSON, "Invalid request data");
      else
    {
      object = json_node_get_object (node);

      if ((result = cool_real_member (object, REQUEST_PARAM_AMOUNT)), G_UNLIKELY (result == FALSE))
        g_set_error (error, VTM_APPLICATION_ERROR, VTM_APPLICATION_ERROR_INVALID_REQUEST_JSON, "Invalid request data");
      else if ((result = cool_member (object, REQUEST_PARAM_CURRENCY, G_TYPE_STRING)), G_UNLIKELY (result == FALSE))
        g_set_error (error, VTM_APPLICATION_ERROR, VTM_APPLICATION_ERROR_INVALID_REQUEST_JSON, "Invalid request data");
      else if ((result = cool_member (object, REQUEST_PARAM_DESCRIPTION, G_TYPE_STRING)), G_UNLIKELY (result == FALSE))
        g_set_error (error, VTM_APPLICATION_ERROR, VTM_APPLICATION_ERROR_INVALID_REQUEST_JSON, "Invalid request data");
      else if ((result = cool_member (object, REQUEST_PARAM_EXTERNALID, G_TYPE_STRING)), G_UNLIKELY (result == FALSE))
        g_set_error (error, VTM_APPLICATION_ERROR, VTM_APPLICATION_ERROR_INVALID_REQUEST_JSON, "Invalid request data");
      else if ((result = cool_member (object, REQUEST_PARAM_SOURCE, G_TYPE_INT64)), G_UNLIKELY (result == FALSE))
        g_set_error (error, VTM_APPLICATION_ERROR, VTM_APPLICATION_ERROR_INVALID_REQUEST_JSON, "Invalid request data");
      else if ((result = cool_member (object, REQUEST_PARAM_NOTIFYURL, G_TYPE_STRING)), G_UNLIKELY (result == FALSE))
        g_set_error (error, VTM_APPLICATION_ERROR, VTM_APPLICATION_ERROR_INVALID_REQUEST_JSON, "Invalid request data");
      else if ((result = cool_member (object, REQUEST_PARAM_VALIDTIME, G_TYPE_INT64)), G_UNLIKELY (result == FALSE))
        g_set_error (error, VTM_APPLICATION_ERROR, VTM_APPLICATION_ERROR_INVALID_REQUEST_JSON, "Invalid request data");
      else
    {
      const gchar* currency = json_object_get_string_member (object, REQUEST_PARAM_CURRENCY);
      const gchar* description = json_object_get_string_member (object, REQUEST_PARAM_DESCRIPTION);
      const gchar* externalid = json_object_get_string_member (object, REQUEST_PARAM_EXTERNALID);
      const gchar* notifyurl = json_object_get_string_member (object, REQUEST_PARAM_NOTIFYURL);
      gdouble amount = (gdouble) json_object_get_double_member (object, REQUEST_PARAM_AMOUNT);
      guint64 source = (guint64) json_object_get_int_member (object, REQUEST_PARAM_SOURCE);
      guint64 validtime = (guint64) json_object_get_int_member (object, REQUEST_PARAM_VALIDTIME);

      if (source_id != source)
        g_set_error (error, VTM_APPLICATION_ERROR, VTM_APPLICATION_ERROR_INVALID_REQUEST_JSON, "Non-matching sources");
      else result = handle_request3 (self, message, object, error);
    }}}}}
return (_g_object_unref0 (parser), result);
}

static int handle_request3 (VtmApplication* self, SoupServerMessage* message, JsonObject* request, GError** error)
{
  gboolean result = TRUE;
return result;
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
  _sqlite3_close0 (self->database);
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
