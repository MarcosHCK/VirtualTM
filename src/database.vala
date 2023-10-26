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
  public errordomain DatabaseError
    {
      FAILED,
      INSERT,
      SELECT,
      OPEN;

      public extern static GLib.Quark quark ();
    }

  public sealed class Database : GLib.Object, GLib.Initable
    {
      /* properties */
      public string filename { get; construct; }

      /* database and statements */
      private Sqlite.Database sqlite;
      private Sqlite.Statement insert_stmt;
      private Sqlite.Statement select_payment_stmt;
      private Sqlite.Statement select_pending_stmt;
      private Sqlite.Statement update_pending_stmt;

      /* constants */

      /* columns from data */
      private const string column_amount = "Amount";
      private const string column_currency = "Currency";
      private const string column_description = "Description";
      private const string column_externalid = "ExternalId";
      private const string column_phone = "Phone";
      private const string column_source = "Source";
      private const string column_urlresponse = "UrlResponse";
      private const string column_validtime = "ValidTime";

      /* columns from headers */
      private const string column_password = "Password";
      private const string column_username = "Username";

      /* columns added by logic */
      private const string column_id = "Id";
      private const string column_pending = "Pending";

      /* database */
      private const string table_name = "Payment";

      /* queries template */
      private const string insert_sql
          = "INSERT INTO " + table_name + " ("
            + column_amount + ", " + column_currency + ", " + column_description + ", "
            + column_externalid + ", " + column_phone + ", " + column_source + ", "
            + column_urlresponse + ", " + column_validtime + ", " + column_password + ", "
            + column_username + ") "
          + "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);";
      private const string select_payment_sql
          = "SELECT "
            + column_amount + ", " + column_currency + ", " + column_description + ", "
            + column_externalid + "," + column_phone + ", " + column_source + ", "
            + column_validtime + ", " + column_urlresponse + ", " + column_password + ", "
            + column_username + " "
          + "FROM " + table_name + " "
          + "WHERE " + column_externalid + " = ?;";
      private const string select_pending_sql
          = "SELECT "
            + column_externalid + " "
          + "FROM " + table_name + " "
          + "WHERE " + column_pending + " = 1;";
      private const string update_pending_sql
          = "UPDATE " + table_name + " "
          + "SET " + column_pending + " = ? "
          + "WHERE " + column_externalid + " = ?;";

      /* api */

      /*
       * Little complain first. SQLite statements uses 1-indexing for parameters, but
       * uses instead 0-indexing for column retrieval, FOR GOD'S SAKE.
       */

      public Database (string filename, GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          Object (filename : filename);
          this.init (cancellable);
        }

      public bool init (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
          if (unlikely (Sqlite.Database.open_v2 (filename, out sqlite, Sqlite.OPEN_READWRITE) != Sqlite.OK))
            throw new DatabaseError.OPEN (sqlite.errmsg ());
          if (unlikely (sqlite.prepare_v2 (insert_sql, -1, out insert_stmt) != Sqlite.OK))
            throw new DatabaseError.OPEN (sqlite.errmsg ());
          if (unlikely (sqlite.prepare_v2 (select_payment_sql, -1, out select_payment_stmt) != Sqlite.OK))
            throw new DatabaseError.OPEN (sqlite.errmsg ());
          if (unlikely (sqlite.prepare_v2 (select_pending_sql, -1, out select_pending_stmt) != Sqlite.OK))
            throw new DatabaseError.OPEN (sqlite.errmsg ());
          if (unlikely (sqlite.prepare_v2 (update_pending_sql, -1, out update_pending_stmt) != Sqlite.OK))
            throw new DatabaseError.OPEN (sqlite.errmsg ());
          return true;
        }

      public Payment? get_payment (string externalid) throws GLib.Error
        {
          var errmsg = (string?) null;
          var payment = (Payment?) null;

          select_payment_stmt.bind_text (1, externalid);

          if (unlikely (select_payment_stmt.step () != Sqlite.ROW))
            {
              errmsg = sqlite.errmsg ();
              select_payment_stmt.reset ();
              throw new DatabaseError.SELECT (errmsg);
            }
          else
            {
              payment = new Payment
                (
                  new RestApi.Credentials
                    (
                      select_payment_stmt.column_text (8),
                      select_payment_stmt.column_int64 (5).to_string (),
                      select_payment_stmt.column_text (9)
                    ),
                  new RestApi.PaymentParams
                    (
                      select_payment_stmt.column_double (0),
                      select_payment_stmt.column_text (1),
                      select_payment_stmt.column_text (2),
                      select_payment_stmt.column_text (3),
                      select_payment_stmt.column_text (4),
                      select_payment_stmt.column_int64 (5),
                      select_payment_stmt.column_text (6),
                      select_payment_stmt.column_int64 (7)
                    )
                );
 
              if (unlikely (select_payment_stmt.step () != Sqlite.DONE))
                assert_not_reached ();
              else if (unlikely (select_payment_stmt.reset () != Sqlite.OK))
                throw new DatabaseError.SELECT (sqlite.errmsg ());
            }
        return payment;
        }

      public string[] get_pending () throws GLib.Error
        {
          var accum = new GenericArray<string?> ();
          var errmsg = (string?) null;
          var result = Sqlite.OK;

          while (true)
            {
              result = select_pending_stmt.step ();

              if (result == Sqlite.DONE)
                break;
              else if (result == Sqlite.ROW)
                {
                  accum.add (select_pending_stmt.column_text (0));
                }
              else
                {
                  errmsg = sqlite.errmsg ();
                  select_pending_stmt.reset ();
                  throw new DatabaseError.SELECT (errmsg);
                }
            }

          if (unlikely (select_pending_stmt.reset () != Sqlite.OK))
            throw new DatabaseError.SELECT (sqlite.errmsg ());
        return accum.steal ();
        }

      public bool register (Payment payment) throws GLib.Error
        {
          string errmsg;
          insert_stmt.bind_double (1, payment.@params.Amount);
          insert_stmt.bind_text (2, payment.@params.Currency);
          insert_stmt.bind_text (3, payment.@params.Description);
          insert_stmt.bind_text (4, payment.@params.ExternalId);
          insert_stmt.bind_text (5, payment.@params.Phone);
          insert_stmt.bind_int64 (6, payment.@params.Source);
          insert_stmt.bind_text (7, payment.@params.UrlResponse);
          insert_stmt.bind_int64 (8, payment.@params.ValidTime);
          insert_stmt.bind_text (9, payment.credentials.password);
          insert_stmt.bind_text (10, payment.credentials.username);

          if (unlikely (insert_stmt.step () != Sqlite.DONE))
            {
              errmsg = sqlite.errmsg ();
              insert_stmt.reset ();
              throw new DatabaseError.INSERT (errmsg);
            }
          else
            {
              if (unlikely (insert_stmt.reset () != Sqlite.OK))
                {
                  throw new DatabaseError.INSERT (sqlite.errmsg ());
                }
            }
        return true;
        }

      public bool update (string externalid, bool pending) throws GLib.Error
        {
          update_pending_stmt.bind_int (1, pending ? 1 : 0);
          update_pending_stmt.bind_text (2, externalid);

          if (unlikely (update_pending_stmt.step () != Sqlite.DONE))
            {
              update_pending_stmt.reset ();
              throw new DatabaseError.INSERT (sqlite.errmsg ());
            }
          else
            {
              if (unlikely (update_pending_stmt.reset () != Sqlite.OK))
                throw new DatabaseError.INSERT (sqlite.errmsg ());
            }
        return true;
        }
    }
}
