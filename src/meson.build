# Copyright 2023-2025 MarcosHCK
# This file is part of virtualtm.
#
# virtualtm is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# virtualtm is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with virtualtm. If not, see <http://www.gnu.org/licenses/>.
#

virtualtm = executable ('virtualtm',
    sources : [ 'client.vala', 'daemon.vala', ],
    c_args : [ ],
    dependencies : [ libgio_dep, libglib_dep, libgobject_dep, ],
    gnu_symbol_visibility : 'hidden',
    include_directories : [ configinc, srcinc, ],
  )

virtualtm_server = executable ('virtualtm-server',
    sources : [ 'daemon.vala', 'database.vala', 'endpoint.vala', 'models.vala', 'notifier.vala', 'server.vala', ],
    c_args : [ ],
    dependencies : [ libgio_dep, libglib_dep, libgobject_dep, libjson_dep, libsoup_dep, libsqlite_dep, ],
    gnu_symbol_visibility : 'hidden',
    include_directories : [ configinc, srcinc, ],
  )
