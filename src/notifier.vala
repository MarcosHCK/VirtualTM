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
  public errordomain NotifyError
    {
      FAILED,
      BAD_URI;

      public extern static GLib.Quark quark ();
    }

  public class Notifier : GLib.Object
    {
      private Soup.Session session;

      public int bank { get; construct; }
      public int bankid { get; construct; }
      public int tmid { get; construct; }

      construct
        {
          session = new Soup.Session ();
        }

      public Notifier (int bank, int bankid, int tmid)
        {
          Object (bank : bank, bankid : bankid, tmid : tmid);
        }

      public new bool notify (Payment payment) throws GLib.Error
        {
          var externalid = payment.@params.ExternalId;
          var phone = payment.@params.Phone;
          var urlresponse = payment.@params.UrlResponse;
          var source = payment.@params.Source;

          var object = new RestApi.NotifyRequest (bank, bankid, source, tmid, externalid, phone);
          var length = (size_t) 0;
          var data = Json.gobject_to_data (object, out length);

          var message = new Soup.Message ("POST", urlresponse);

          if (unlikely (message == null))
            throw new NotifyError.BAD_URI ("Failed to parse '%s'", urlresponse);
          else
            {
              var body = new GLib.Bytes.static (data.data);
              var headers = message.get_request_headers ();

              headers.append ("password", payment.credentials.password);
              headers.append ("source", payment.credentials.source);
              headers.append ("username", payment.credentials.username);
              message.set_request_body_from_bytes (RestApi.CONTENT_TYPE, body);

              var response_data = session.send_and_read (message);
              var response_object = Json.gobject_from_data (typeof (RestApi.NotifyResponse), (string) response_data.get_data (), (ssize_t) response_data.get_size ());
              var response = response_object as RestApi.NotifyResponse;

              if (response.Success == false)
                throw new NotifyError.FAILED ("%s", response.Resultmsg);
            }
          return true;
        }
    }
}
