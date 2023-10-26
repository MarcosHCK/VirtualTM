# VirtualTM - Transfermovil REST API Emulator

Transfermovil is a closed API, which makes development of applications really painful. To overcome such limitations this repo holds a virtual (does not involves money) implementation of such API.

## Requirements

VirtualTM is written in Vala, so make sure to have a compiler at the ready:

  * [valac](https://vala.dev/) (= 0.56)

VirtualTM uses:

  * [gio-2.0](https://gitlab.gnome.org/GNOME/glib) (>= 2.78)
  * [glib-2.0](https://gitlab.gnome.org/GNOME/glib) (>= 2.78)
  * [gobject-2.0](https://gitlab.gnome.org/GNOME/glib) (>= 2.78)
  * [json-glib-1.0](https://gitlab.gnome.org/GNOME/json-glib) (>= 1.8)
  * [soup-3.0](https://gitlab.gnome.org/GNOME/libsoup) (>= 3.4.3)
  * [SQLite3](https://www.sqlite.org/index.html) (>= 3.43.1)

VirtualTM components comunicates over DBus so make sure to have one of those. It also uses a SQLite database (of course) called **virtualtm.db** by default, although you can use any other, just pass it using -d option to server instance.

## How to use it

VirtualTM consists of two components: a server and a command line utility. The server works on the background and listens to incoming REST API requests, stores them in a database, and notifies clients when the payment is completed. The command line utility on the other hand controls server instance by two main methods: listing pending (not payed - virtually) payments, and paying those payments (again, **virtually**). And that's it.

## Limitations

VirtualTM is a in-a-hurry kind of application. It means it was not meant for production environment, nor for performance. It is also full synchronous, which means a request at a time, a command line interaction at a time (exclusive).

By the way, you must create the database on your own, so have fun. Here is the code to create the needed table:

```SQL
  CREATE TABLE "Payment" (
    "Id"	INTEGER NOT NULL,
    "Amount"	REAL NOT NULL,
    "Currency"	TEXT NOT NULL,
    "Description"	TEXT NOT NULL,
    "ExternalId"	TEXT NOT NULL UNIQUE,
    "Phone"	TEXT NOT NULL,
    "Source"	INTEGER NOT NULL,
    "UrlResponse"	TEXT NOT NULL,
    "ValidTime"	INTEGER NOT NULL,
    "Password"	TEXT NOT NULL,
    "Username"	TEXT NOT NULL,
    "Pending"	INTEGER NOT NULL DEFAULT 1,
    PRIMARY KEY("Id" AUTOINCREMENT)
  );
```
