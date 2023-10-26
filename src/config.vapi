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

[CCode (cheader_filename = "config.h", cprefix = "", lower_case_cprefix = "")]
namespace Config
{
  public const int PACKAGE_VERSION_MAJOR;
  public const int PACKAGE_VERSION_MICRO;
  public const int PACKAGE_VERSION_MINOR;
  public const string PACKAGE_BUGREPORT;
  public const string PACKAGE_NAME;
  public const string PACKAGE_STRING;
  public const string PACKAGE_TARNAME;
  public const string PACKAGE_URL;
  public const string PACKAGE_VERSION_STAGE;
  public const string PACKAGE_VERSION;
}
