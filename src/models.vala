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
  public sealed class Payment : GLib.Object
    {
      public RestApi.Credentials credentials { get; set; }
      public RestApi.PaymentParams @params { get; set; }

      public Payment (RestApi.Credentials credentials, RestApi.PaymentParams @params)
        {
          Object (credentials : credentials, @params : @params);
        }
    }

  namespace RestApi
  {
    const string CONTENT_TYPE = "application/json";

    public class Credentials : GLib.Object
      {
        public string password { get; set; }
        public string source { get; set; }
        public string username { get; set; }

        public Credentials (string password, string source, string username)
          {
            this.password = password;
            this.source = source;
            this.username = username;
          }

        public bool check_source (int64 against) throws GLib.NumberParserError
          {
            int64 value;
            int64.from_string (source, out value);
            return value == against;
          }
      }

    public class GenericResult : GLib.Object, Json.Serializable
      {
        public string Resultmsg { get; set; }
        public bool Success { get; set; }

        public GenericResult (bool success, string message)
          {
            Object (Resultmsg : message, Success : success);
          }
      }

    public class NotifyRequest : GLib.Object, Json.Serializable
      {
        public int64 Bank { get; set; }
        public int64 BankId { get; set; }
        public int64 Source { get; set; }
        public int64 TmId { get; set; }
        public string ExternalId { get; set; }
        public string Phone { get; set; }

        public NotifyRequest (int64 bank, int64 bankid, int64 source, int64 tmid, string externalid, string phone)
          {
            Object (Bank : bank, BankId : bankid, Source : source, TmId : tmid, ExternalId : externalid, Phone : phone);
          }
      }

    public class NotifyResponse : GenericResult
      {
        public int Status { get; set; }

        public NotifyResponse (bool success, string message, int status)
          {
            Object (Resultmsg : message, Success : success, Status : status);
          }
      }

    public class PaymentParams : GLib.Object, Json.Serializable
      {
        public double Amount { get; set; }
        public int64 Source { get; set; }
        public int64 ValidTime { get; set; }
        public string Currency { get; set; }
        public string Description { get; set; }
        public string ExternalId { get; set; }
        public string Phone { get; set; }
        public string UrlResponse { get; set; }

        public PaymentParams (double amount, string currency, string description, string externalid,
                              string phone, int64 source, string urlresponse, int64 validtime)
          {
            Object (Amount : amount, Currency : currency, Description : description, ExternalId : externalid,
                    Phone : phone, Source : source, UrlResponse : urlresponse, ValidTime : validtime);
          }
      }

    public class PaymentRequest : GLib.Object, Json.Serializable
      {
        public PaymentParams request { get; set; }
        public PaymentRequest (PaymentParams @params) { Object (request : @params); }
      }

    public class PaymentResponse : GLib.Object, Json.Serializable
      {
        public PaymentResult PayOrderResult { get; set; }
        public PaymentResponse (PaymentResult result) { Object (PayOrderResult : result); }
      }

    public class PaymentResult : GenericResult
      {
        public int64 OrderId { get; set; }

        public PaymentResult (bool success, string message, int64 orderid)
          {
            Object (Resultmsg : message, Success : success, OrderId : orderid);
          }
      }
  }
}
