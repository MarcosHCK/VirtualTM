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
using VirtualTM.RestApi;

namespace VirtualTM
{
  public errordomain EndpointError
    {
      FAILED,
      MISSING_FIELD,
      MISSING_HEADER;

      public extern static GLib.Quark quark ();
    }

  public class Endpoint : GLib.Object, GLib.Initable
    {
      private Soup.Server server;

      /* properties */
      public bool local { get; construct; }
      public string endpoint { get; construct; }
      public uint port { get; construct; }

      /* constants */
      private const string identity = "VirtualTM/" + Config.PACKAGE_VERSION + " ";

      public Endpoint (string endpoint, bool local, uint port, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          Object (local : local, endpoint : endpoint, port : port);
          this.init (cancellable);
        }

      public bool init (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          server = new Soup.Server ("server-header", identity);

          if (local)
            server.listen_local (port, 0);
          else
            server.listen_all (port, 0);

            server.add_handler (endpoint, handle_request);
        return true;
        }

        /*
         * Currently as I'am writing this code Vala has not support for
         * signal accumulators. Ideally `RestAPI::got_request' shold use
         * `g_signal_accumulator_true_handled'-like accumulator so first 
         * handler who returns a valid result sets message response, or
         * fallback to default handler (this one)
         *
         * In this program there will be exactly one handler which will
         * surely handle the request. Even so, the complain is valid.
         *
         * {
         *   // This should be class signal handler
         *   return new RestApi.PaymentResult (false, "Unimplemented", 0);
         * }
         *
         */

      [Signal (no_recurse = true, run = "last")]
      public virtual signal PaymentResult? got_request (RestApi.Credentials credentials, PaymentParams @params);

      public void shutdown ()
        {
          server.disconnect ();
        }

      private void handle_request (Soup.Server server, Soup.ServerMessage message, string path, GLib.HashTable<string, string>? query)
        {
          unowned var method = message.get_method ();
          unowned var status = Soup.Status.OK;

          if (path != endpoint)
            {
              status = Soup.Status.SEE_OTHER;
              message.set_redirect (status, endpoint);
            }
          else if (method != "POST")
            {
              status = Soup.Status.METHOD_NOT_ALLOWED;
              message.set_status (status, Soup.Status.get_phrase (status));
            }
          else try
            {
              handle_request2 (message);
              status = (Soup.Status) message.get_status ();
            }
          catch (GLib.Error e)
            {
              status = Soup.Status.BAD_REQUEST;
              message.set_status (status, Soup.Status.get_phrase (status));
            }
        }

      private void handle_request2 (Soup.ServerMessage message) throws GLib.Error
        {
          unowned var body = message.get_request_body ();
          unowned var headers = message.get_request_headers ();
          unowned var password = (string?) null;
          unowned var source = (string?) null;
          unowned var username = (string?) null;

          if (unlikely ((password = headers.get_one ("password")) == null))
            throw new EndpointError.MISSING_HEADER ("Missing request header");
          else if (unlikely ((source = headers.get_one ("source")) == null))
            throw new EndpointError.MISSING_HEADER ("Missing request header");
          else if (unlikely ((username = headers.get_one ("username")) == null))
            throw new EndpointError.MISSING_HEADER ("Missing request header");
          else
            {
              var credentials = new RestApi.Credentials (password, source, username);
              var payment_object = Json.gobject_from_data (typeof (RestApi.PaymentRequest), (string) body.data, (ssize_t) body.length);
              var payment = payment_object as RestApi.PaymentRequest;
                credentials.check_source (payment.request.Source);
              var result = got_request (credentials, payment.request);
              var status = Soup.Status.OK;

              if (unlikely (result == null))
                {
                  status = Soup.Status.INTERNAL_SERVER_ERROR;
                  message.set_status (status, Soup.Status.get_phrase (status));
                }
              else
                {
                  var response = new PaymentResponse (result);
                  var length = (size_t) 0;
                  var data = Json.gobject_to_data (response, out length);

                  message.set_status (status, Soup.Status.get_phrase (status));
                  message.set_response (RestApi.CONTENT_TYPE, Soup.MemoryUse.COPY, data.data);
                }
            }
        }
    }
}
