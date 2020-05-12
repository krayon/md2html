#!/bin/bash
# vim:set ts=4 sw=4 tw=80 et ai si:
# ( settings from: http://datapax.com.au/code_conventions/ )
#
#/**********************************************************************
#    md2html
#    Copyright (C) 2019-2020 Todd Harbour (Krayon)
#
#    This program is free software; you can redistribute it and/or
#    modify it under the terms of the GNU General Public License
#    version 3 ONLY, as published by the Free Software Foundation.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program, in the file COPYING or COPYING.txt; if
#    not, see http://www.gnu.org/licenses/ , or write to:
#      The Free Software Foundation, Inc.,
#      51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
# **********************************************************************/

# md2html
# -------
# wrapper to call markdown_py with a template
#
# Required:
#     markdown_py (python-markdown)
# Recommended:
#     inotifywait (inotify-tools)
#     notify-send (libnotify-bin)

# Config paths
_APP_NAME="md2html"
_CONF_FILENAME="${_APP_NAME}.conf"
_ETC_CONF="/etc/${_CONF_FILENAME}"



############### STOP ###############
#
# Do NOT edit the CONFIGURATION below. Instead generate the default
# configuration file in your XDG_CONFIG directory thusly:
#
#     ./md2html.bash -C >"$XDG_CONFIG_HOME/md2html.conf"
#
# or perhaps:
#     ./md2html.bash -C >~/.config/md2html.conf
#
# Consult --help for more complete information.
#
####################################

# [ CONFIG_START

# iCal Import Default Configuration
# =================================

# DEBUG
#   This defines debug mode which will output verbose info to stderr or, if
#   configured, the debug file ( ERROR_LOG ).
DEBUG=0

# ERROR_LOG
#   The file to output errors and debug statements (when DEBUG != 0) instead of
#   stderr.
#ERROR_LOG="${HOME}/md2html.log"

# ] CONFIG_END



####################################{
###
# Config loading
###

# A list of configs - user provided prioritised over system
# (built backwards to save fiddling with CONFIG_DIRS order)
_CONFS=""

# XDG Base (v0.8) - User level
# ( https://specifications.freedesktop.org/basedir-spec/0.8/ )
# ( xdg_base_spec.0.8.txt )
_XDG_CONF_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}"
# As per spec, non-absolute paths are invalid and must be ignored
[ "${_XDG_CONF_DIR:0:1}" == "/" ] && {
        for conf in\
            "${_XDG_CONF_DIR}/${_APP_NAME}/${_CONF_FILENAME}"\
            "${_XDG_CONF_DIR}/${_CONF_FILENAME}"\
        ; do #{
            [ -r "${conf}" ] && _CONFS="${conf}:${_CONFS}"
        done #}
}

# XDG Base (v0.8) - System level
# ( https://specifications.freedesktop.org/basedir-spec/0.8/ )
# ( xdg_base_spec.0.8.txt )
_XDG_CONF_DIRS="${XDG_CONFIG_DIRS:-/etc/xdg}"
# NOTE: Appending colon as read's '-d' sets the TERMINATOR (not delimiter)
[ "${_XDG_CONF_DIRS: -1:1}" != ":" ] && _XDG_CONF_DIRS="${_XDG_CONF_DIRS}:"
while read -r -d: _XDG_CONF_DIR; do #{
    # As per spec, non-absolute paths are invalid and must be ignored
    [ "${_XDG_CONF_DIR:0:1}" == "/" ] && {
        for conf in\
            "${_XDG_CONF_DIR}/${_APP_NAME}/${_CONF_FILENAME}"\
            "${_XDG_CONF_DIR}/${_CONF_FILENAME}"\
        ; do #{
            [ -r "${conf}" ] && _CONFS="${conf}:${_CONFS}"
        done #}
    }
done <<<"${_XDG_CONF_DIRS}" #}

# _CONFS now contains a list of config files, in reverse importance order. We
# can therefore source each in turn, allowing the more important to override the
# earlier ones.

# NOTE: Appending colon as read's '-d' sets the TERMINATOR (not delimiter)
[ "${_CONF: -1:1}" != ":" ] && _CONF="${_CONF}:"
while read -r -d: conf; do #{
    . "${conf}"
done <<<"${_CONFS}" #}
####################################}



# Version
APP_NAME="Markdown 2 HTML"
APP_VER="0.01"
#TODO:
#APP_URL="https://gitlab.com/krayon/qdnxtools/md2html.bash"

# Program name
_binname="${_APP_NAME}"
_binname="${0##*/}"
_binnam_="$(echo -n "${_binname}"|tr -c ' ' ' ')"

# exit condition constants
ERR_NONE=0
ERR_UNKNOWN=1
# START /usr/include/sysexits.h {
ERR_USAGE=64       # command line usage error
ERR_DATAERR=65     # data format error
ERR_NOINPUT=66     # cannot open input
ERR_NOUSER=67      # addressee unknown
ERR_NOHOST=68      # host name unknown
ERR_UNAVAILABLE=69 # service unavailable
ERR_SOFTWARE=70    # internal software error
ERR_OSERR=71       # system error (e.g., can't fork)
ERR_OSFILE=72      # critical OS file missing
ERR_CANTCREAT=73   # can't create (user) output file
ERR_IOERR=74       # input/output error
ERR_TEMPFAIL=75    # temp failure; user is invited to retry
ERR_PROTOCOL=76    # remote error in protocol
ERR_NOPERM=77      # permission denied
ERR_CONFIG=78      # configuration error
# END   /usr/include/sysexits.h }
ERR_MISSINGDEP=90

# Defaults not in config

tmpdir=""
pwd="$(pwd)"



# Params:
#   $1 =  (s) command to look for
#   $2 =  (s) complete path to binary
#   $3 =  (i) print error (1 = yes, 0 = no)
#   $4 = [(s) suspected package name]
# Outputs:
#   Path to command, if found
# Returns:
#   $ERR_NONE
#   -or-
#   $ERR_MISSINGDEP
check_for_cmd() {
    # Check for ${1} command
    local ret=${ERR_NONE}
    local path=""
    local cmd="${1}"; shift 1
    local bin="${1}"; shift 1
    local msg="${1}"; shift 1
    local pkg="${1}"; shift 1
    [ -z "${pkg}" ] && pkg="${cmd}"

    path="$(type -P "${bin}" 2>&1)" || {
        # Not found
        ret=${ERR_MISSINGDEP}

        [ "${msg}" -eq 1 ] &>/dev/null && {

cat <<EOF >&2
ERROR: Cannot find ${cmd}${bin:+ (as }${bin}${bin:+)}.  This is required.
Ensure you have ${pkg} installed or search for ${cmd}
in your distribution's packages.
EOF

            return ${ret}
        }
    }

    [ ! -z "${path}" ] && echo "${path}"

    return ${ret}
} # check_for_cmd()

# Params:
#   NONE
show_version() {
    echo -e "\
${APP_NAME} v${APP_VER}\n\
${APP_URL}\n\
"
} # show_version()

# Params:
#   NONE
show_usage() {
    show_version
cat <<EOF

${APP_NAME} is a wrapper to call markdown_py with a template.

Usage: ${_binname} [-v|--verbose] -h|--help
       ${_binname} [-v|--verbose] -V|--version

       ${_binname} [-v|--verbose] [<infile> [...]]

-h|--help           - Displays this help
-V|--version        - Displays the program version
-C|--configuration  - Outputs the default configuration that can be placed in a
                      config file in XDG_CONFIG or one of the XDG_CONFIG_DIRS
                      (in order of decreasing precedence):
                          ${XDG_CONFIG_HOME:-${HOME}/.config}/${_APP_NAME}/${_CONF_FILENAME}
                          ${XDG_CONFIG_HOME:-${HOME}/.config}/${_CONF_FILENAME}
EOF
    while read -r -d: _XDG_CONF_DIR; do #{
        # As per spec, non-absolute paths are invalid and must be ignored
        [ "${_XDG_CONF_DIR:0:1}" != "/" ] && continue
cat <<EOF
                          ${_XDG_CONF_DIR}/${_APP_NAME}/${_CONF_FILENAME}
                          ${_XDG_CONF_DIR}/${_CONF_FILENAME}
EOF
    done <<<"${_XDG_CONF_DIRS:-/etc/xdg}:" #}
cat <<EOF
                      for editing.
-v|--verbose        - Displays extra debugging information.  This is the same
                      as setting DEBUG=1 in your config.

Example: ${_binname}
EOF
} # show_usage()

# Clean up
cleanup() {
    decho "Clean Up"

    [ ! -z "${tmpdir}" ] && rm -Rf "${tmpdir}" &>/dev/null
    [ ! -z "${pwd}"    ] && cd "${pwd}"        &>/dev/null
} # cleanup()

trapint() {
    >&2 echo "WARNING: Signal received: ${1}"

    cleanup

    exit ${1}
} # trapint()

# Output configuration file
output_config() {
    sed -n '/^# \[ CONFIG_START/,/^# \] CONFIG_END/p' <"${0}"
} # output_config()

# Debug echo
decho() {
    local line

    # Not debugging, get out of here then
    [ ${DEBUG} -le 0 ] && return

    # If message isn't specified, use stdin
    msg="${@}"
    [ -z "${msg}" ] && msg="$(</dev/stdin)"


    while IFS="" read -r line; do #{
        echo >&2 "[$(date +'%Y-%m-%d %H:%M')] DEBUG: ${line}"
    done< <(echo "${msg}") #}
} # decho()



# START #

ret=${ERR_NONE}

# If debug file, redirect stderr out to it
[ ! -z "${ERROR_LOG}" ] && exec 2>>"${ERROR_LOG}"



# SIGINT  =  2 # (CTRL-c etc)
# SIGKILL =  9
# SIGUSR1 = 10
# SIGUSR2 = 12
for sig in 2 9 10 12; do #{
    trap "trapint ${sig}" ${sig}
done #}



#----------------------------------------------------------
decho "START"

# Process command line parameters
opts=$(\
    getopt\
        --options v,h,V,C\
        --long verbose,help,version,configuration\
        --name "${_binname}"\
        --\
        "$@"\
) || exit ${ERR_USAGE}

eval set -- "${opts}"
unset opts

while :; do #{
    case "${1}" in #{
        # Verbose mode # [-v|--verbose]
        -v|--verbose)
            decho "Verbose mode specified"
            DEBUG=1
        ;;

        # Help # -h|--help
        -h|--help)
            decho "Help"

            show_usage
            exit ${ERR_NONE}
        ;;

        # Version # -V|--version
        -V|--version)
            decho "Version"

            show_version
            exit ${ERR_NONE}
        ;;

        # Configuration output # -C|--configuration
        -C|--configuration)
            decho "Configuration"

            output_config
            exit ${ERR_NONE}
        ;;

        --)
            shift
            break
        ;;

        *)
            >&2 echo "ERROR: Unrecognised parameter ${1}..."
            exit ${ERR_USAGE}
        ;;
    esac #}

    shift

done #}

# Check for non-optional parameters

# Create, a working directory
tmpdir="$(mktemp --tmpdir --directory ${_binname}.XXXXX)" || {
    >&2 echo "ERROR: Failed to create temp directory"
    exit ${ERR_CANTCREAT}
}

while [ ! -z "${1}" ]; do #{
    files+=("${1}")
    shift 1
done #}

[ -z "${files}" ] && {
    >&2 echo "ERROR: files not set, and none provided on command line"
    exit ${ERR_USAGE}
}

decho "DONE"

cleanup

exit ${ret}
