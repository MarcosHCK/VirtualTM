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

project ('VirtualTM', 'c', 'vala',
  default_options : [ 'warning_level=3', ],
  meson_version : '>= 1.2',
  version : '@0@.@1@.@2@'.format (
    run_command ('git', 'describe', check : true).stdout ().strip ().split ('-').get (0).split ('.').get (0).substring (1),
    run_command ('git', 'describe', check : true).stdout ().strip ().split ('-').get (0).split ('.').get (1),
    run_command ('git', 'describe', check : true).stdout ().strip ().split ('-').get (0).split ('.').get (2)))

cc = meson.get_compiler ('c')

########################
# Extract version info #
########################

git_version = run_command ('git', 'describe', check : true).stdout ().strip ()
git_version_list = git_version.split ('-')
git_version_list2 = git_version_list.get (0).split ('.')
git_version_stage = git_version_list.get (1)
git_version_major = git_version_list2.get (0).substring (1)
git_version_minor = git_version_list2.get (1)
git_version_micro = git_version_list2.get (2)

########################
# Dependencies         #
########################

libgio_dep = dependency ('gio-2.0', required : true, version : '>=2.78')
libglib_dep = dependency ('glib-2.0', required : true, version : '>=2.78')
libgobject_dep = dependency ('gobject-2.0', required : true, version : '>=2.78')
libjson_dep = dependency ('json-glib-1.0', required : true, version : '>=1.8')

########################
# Include directories  #
########################

configinc = include_directories ('.')
srcinc = include_directories ('src')

########################
# Configuration begins #
########################

configh = configuration_data ()
configh.set ('DEBUG', get_option ('debug').to_int ())
configh.set ('DEVELOPER', get_option ('developer').to_int ())
configh.set ('G_LOG_USE_STRUCTURED', 1)
configh.set ('PACKAGE_VERSION_MAJOR', git_version_major)
configh.set ('PACKAGE_VERSION_MICRO', git_version_micro)
configh.set ('PACKAGE_VERSION_MINOR', git_version_minor)
configh.set_quoted ('G_LOG_DOMAIN', 'VirtualTM')
configh.set_quoted ('PACKAGE_BUGREPORT', 'nouser@nohost.com')
configh.set_quoted ('PACKAGE_NAME', meson.project_name ())
configh.set_quoted ('PACKAGE_STRING', '@0@ @1@'.format (meson.project_name (), git_version))
configh.set_quoted ('PACKAGE_TARNAME', meson.project_name ())
configh.set_quoted ('PACKAGE_URL', 'https://github.com/MarcosHCK/VirtualTM')
configh.set_quoted ('PACKAGE_VERSION_STAGE', git_version_stage)
configh.set_quoted ('PACKAGE_VERSION', git_version)

add_project_arguments ([ '--pkg', 'config', '--pkg', 'posix', ], language : 'vala')
add_project_arguments ([ '--vapidir', meson.current_source_dir () / 'src', ], language : 'vala')
add_project_arguments ([ '-D', 'DEBUG=@0@'.format (get_option ('debug')), ], language : 'vala')
add_project_arguments ([ '-D', 'DEVELOPER=@0@'.format (get_option ('developer')), ], language : 'vala')
add_project_arguments ([ '-D', 'G_LOG_DOMAIN=VirtualTM', ], language : 'vala')
add_project_arguments ([ '-D', 'G_LOG_USE_STRUCTURED=1', ], language : 'vala')

if cc.get_id () == 'gcc' or cc.get_id () == 'clang'
  warning_c_args = [
    '-Waggregate-return',
    '-Warray-bounds',
    '-Wduplicated-branches',
    '-Werror=format=2',
    '-Werror=implicit-function-declaration',
    '-Werror=init-self',
    '-Werror=missing-include-dirs',
    '-Werror=missing-prototypes',
    '-Werror=pointer-arith',
    '-Werror=pointer-sign',
    '-Werror=unused-result',
    '-Wimplicit-fallthrough',
    '-Wmisleading-indentation',
    '-Wmissing-field-initializers',
    # Due to pervasive use of things like GPOINTER_TO_UINT(), we do not support
    # building with -Wbad-function-cast.
    '-Wno-bad-function-cast',
    # Due to pervasive use of things like GPOINTER_TO_UINT(), we do not support
    # building with -Wbad-function-cast.
    '-Wno-cast-function-type',
    # A zero-length format string shouldn't be considered an issue.
    '-Wno-format-zero-length',
    # Due to function casts through (void*) we cannot support -Wpedantic:
    # ./docs/toolchain-requirements.md#Function_pointer_conversions.
    '-Wno-pedantic',
    '-Wno-string-plus-int',
    # Due to maintained deprecated code, we do not want to see unused parameters
    '-Wno-unused-parameter',
    # We explicitly require variadic macros
    '-Wno-variadic-macros',
    '-Wnonnull',
    '-Wshadow',
    '-Wstrict-prototypes',
    '-Wunused',
    '-Wunused-function',
    '-Wunused-label',
    '-Wunused-value',
  ]

  warning_c_link_args = [
    '-Wl,-z,nodelete',
  ]
else
  error ('Unsupported compiler')
endif

add_project_arguments (cc.get_supported_arguments (warning_c_args), language : 'c')
add_project_link_arguments (cc.get_supported_link_arguments (warning_c_link_args), language : 'c')
configure_file (output : 'config.h', configuration : configh)

########################
# Subdirectories       #
########################

subdir ('src')

########################
# Summaries            #
########################

summary ({
    'C Compiler' : cc.get_id (),
    'debug build' : get_option ('debug') ? 'yes' : 'no',
    'develop build' : get_option ('developer') ? 'yes' : 'no',
    'host cpu' : host_machine.cpu_family (),
    'host endian' : host_machine.endian (),
    'host system' : host_machine.system (),
  }, section: 'Build environment')

if build_machine.system () != host_machine.system ()
  summary ({
      'build cpu' : build_machine.cpu_family (),
      'build endian' : build_machine.endian (),
      'build system' : build_machine.system (),
    }, section: 'Build environment')
endif
