#!/bin/sh
#
# $Header: bhp.sh                                              Exp $
# $Author: (c) 2012-2016 tokiclover <tokiclover@gmail.com>     Exp $
# $License: MIT (or 2-clause/new/simplified BSD)               Exp $
# $Version: 1.4 2016/03/20                                     Exp $
#

TMPDIR_LIBDIR="${0%/*}"
if ! source "${TMPDIR_LIBDIR}"/sh/functions.sh; then
	echo "Failed to load functions.sh" >&2
	exit 1;
fi

mktmp_message_help()
{
	cat <<-EOH
usage: mktmp [-p] [-d|-f] [-m mode] [-o owner[:group] TEMPLATE-XXXXXX
  -d, --dir           (Create a) directory
  -f, --file          (Create a) file
  -o, --owner <name>  Use owner name
  -g, --group <name>  Use group name
  -m, --mode   1700   Use octal mode
  -p, --tmpdir[=DIR]  Enable mktmp mode
  -h, --help          Help/Exit
EOH
}

mktmp()
{
	[ ${#} = 0 ] && { mktmp_message_help; return 1; }

	local ARGS NAME=mktmp
	ARGS="$(getopt \
		-o dfg:hm:o:p: \
		-l dir,file,group:,tmpdir:,help,mode:owner: \
		-s sh -n mktmp -- "${@}")"
	[ ${?} = 0 ] || { mktmp_message_help; return 2; }
	eval set -- ${ARGS}
	ARGS=

	local group mode owner temp=-XXXXXX tmp type
	while true; do
		case "${1}" in
			(-p|--tmpd*) tmpdir="${2:-${TMPDIR:-/tmp}}"; shift;;
			(-h|--help) mktmp_message_help; return;;
			(-m|--mode)  mode="${2}" ; shift;;
			(-o|--owner) owner="${2}"; shift;;
			(-g|--group) group="${2}"; shift;;
			(-d|--dir) ARGS=-d type=dir;;
			(-f|--file)  type=file;;
			(*) shift; break;;
		esac
		shift
	done

	if ! [ ${#} -eq 1 -a -n "${1}" ]; then
		pr_error "Invalid argument(s)"
		return 3
	fi
	case "${1}" in
		(*${temp}) ;;
		(*) pr_error "Invalid TEMPLATE"; return 4;;
	esac
	local mktmp
	if type -p mktemp >/dev/null 2>&1; then
		mktmp=mktemp
	elif type -p busybox >/dev/null 2>&1; then
		mktmp='busybox mktemp'
	fi
	if [ -n "${mktmp}" ]; then
		tmp="$(${mktmp} ${tmpdir:+-p} "${tmpdir}" ${ARGS} "${1}")"
	fi
	if [ ! -e "${tmp}" ]; then
		tmp="${tmpdir}/${1%-*}-$(echo "${temp}" | cut -c-6)"
	fi
	case "${type}" in
		(dir) [ -d "${tmp}" ] || mkdir -p "${tmp}";;
		(*)   [ -e "${tmp}" ] || { mkdir -p "${tmp%/*}"; touch  "${tmp}"; };;
	esac
	[ ${?} = 0 ] || { pr_error "Failed to create ${tmp}"; return 5; }

	[ -h "${tmp}" ] && return
	[ "${owner}" ] && chown "${owner}" "${tmp}"
	[ "${group}" ] && chgrp "${group}" "${tmp}"
	[ "${mode}"  ] && chmod "${mode}"  "${tmp}"
	echo "${tmp}"
}

bhp_message_help()
{
	cat <<-EOH
usage: ${BHP_ZERO} [OPTIONS] [BROWSER]
  -c, --compressor='lzop -1'  Use lzop compressor, default to lz4
  -d, --daemon 300            Sync time (in sec) when daemonized
  -t, --tmpdir=DIR            Set up a particular TMPDIR
  -p, --profile=PROFILE       Select a particular profile
  -s, --set                   Set up tarball archives
  -h, --help                  Print help message and exit
EOH
}

#
# @FUNCTION: Find a browser to setup
#
bhp_find_browser()
{
	local BROWSERS MOZ_BROWSERS group browser
	MOZILLA_BROWSERS='aurora firefox icecat seamonkey'
	BROWSERS='conkeror chrome chromium epiphany midory opera otter qupzilla netsurf vivaldi'

	case "${1}" in
		(aurora|firefox|icecat|seamonkey)
			BROWSER="${1}" BHP_PROFILE="mozilla/${1}"; return;;
		(conkeror|chrome|chromium|epiphany|midory|opera|otter|qupzilla|netsurf|vivaldi)
			BROWSER="${1}" BHP_PROFILE="config/${1}" ; return;;
	esac

	for group in "mozilla:${MOZILLA_BROWSERS}" "config:${BROWSERS}"; do
		for browser in ${group#*:}; do
			group="${group%:*}"
			[ -d "${HOME}/.${group}/${browser}" ] &&
				{ BROWSER="${browser}" BHP_PROFILE="${group}/${browser}"; return; }
		done
	done
	return 1
}

#
# @FUNCTION: Find a Mozilla family browser profile
#
bhp_mozilla_profile()
{
	[ -n "${2}" -a -d "${HOME}/.${1}/${2}" ] &&
		{ BHP_PROFILE="${1}/${2}"; return; }

	BHP_PROFILE="${1}/$(sed -nre "s|^[Pp]ath=(.*$)|\1|p" \
		${HOME}/.${1}/profiles.ini)"
	[ -n "${BHP_PROFILE}" -a -d "${HOME}/.${BHP_PROFILE}" ] ||
		{ pr_error "No mozilla profile dir found"; return 113; }
}

#
# @FUNCTION: Profile initializer function and temporary directories setup
#
bhp_init_profile()
{
	local ARGS DIR EXT OLD PROFILE browser dir char NAME="${BHP_ZERO}" tmpdir
	local SETUP_TARBALL=false
	ARGS="$(getopt \
		-o c:d:hp:st: -l compressor:,daemon:,help,profile:,set,tmpdir: \
		-n bhp -s sh -- "${@}")"
	[ ${?} = 0 ] || return 111
	eval set -- ${ARGS}

	while true; do
		case "${1}" in
			(-c|--compressor) BHP_COMPRESSOR="${2}"; shift;;
			(-h|--help) bhp_message_help   ; return 128;;
			(-d|--daemon) BHP_DAEMON="${2}"; shift;;
			(-p|--profile) PROFILE="${2}"  ; shift;;
			(-t|--tmpdir) tmpdir="${2}"    ; shift;;
			(-s|--set) SET_TARBALL=true   ;;
			(*) shift; break;;
		esac
		shift
	done

	bhp_find_browser "${browser:-${1:-$BROWSER}}"
	[ -n "${BROWSER}" ] && export BROWSER || 
		{ pr_error "No browser found."; return 112; }
	case "${BHP_PROFILE}" in
		(mozilla*) bhp_mozilla_profile "${BHP_PROFILE}" "${PROFILE}";;
	esac

:	${BHP_COMPRESSOR:=lz4 -1}
:	${EXT=.tar.${BHP_COMPRESSOR%% *}}
:	${tmpdir:=${TMPDIR:-/tmp/$USER}}
:	${PROFILE:=${BHP_PROFILE##*/}}

	[ -d "${TMPDIR}" ] || mkdir -p -m 1700 "${TMPDIR}" ||
		{ pr_error "No suitable directory found"; return 2; }

	for dir in "${HOME}"/.${BHP_PROFILE} "${HOME}"/.cache/${BHP_PROFILE#config/}; do
		[ -d "${dir}" ] || continue
		if mount_info "${dir}"; then
			${SET_TARBALL} && bhp "${dir}"
			continue
		fi
		OLD="${PWD}"
		cd "${dir%/*}" || { pr_end 1 Directory; continue; }

		pr_begin "Setting up directory... "
		if [ ! -f "${PROFILE}${EXT}" ] || [ ! -f "${PROFILE}.old${EXT}" ]; then
			tar -cpf ${PROFILE}${EXT}  -I "${BHP_COMPRESSOR}" ${PROFILE} ||
				{ pr_end 1 Tarball; continue; }
		fi

		case "${dir}" in
			(*.cache/*) char=c;;
			(*) char=p;;
		esac
		DIR="$(mktmp -p "${tmpdir}" -d bh${char}-XXXXXX)"
		sudo mount --bind "${DIR}" "${dir}" ||
			{ pr_end 1 Mounting; continue; }
		pr_end "${?}"

		if ${SET_TARBALL}; then
			bhp "${dir}"
		fi
		cd "${OLD}"
	done
}

#
# @FUNCTION: Maintain BHP archive tarballs
#
bhp()
{
	local EXT OLD PROFILE NAME=bhp tarball
	EXT=".tar.${BHP_COMPRESSOR%% *}" PROFILE="${BHP_PROFILE##*/}"

	for dir in ${@:-"${HOME}"/.${BHP_PROFILE} "${HOME}"/.cache/${BHP_PROFILE#config/}}; do
		[ -d "${dir}" ] || continue
		OLD="${PWD}"
		cd "${dir%/*}" || continue

		pr_begin "Setting up tarball... "
		if [ -f ${PROFILE}/.unpacked ]; then
			if [ -f ${PROFILE}${EXT} ]; then
				mv -f ${PROFILE}${EXT} ${PROFILE}.old${EXT} ||
					{ pr_end 1 Moving; continue; }
			fi
			tar -X ${PROFILE}/.unpacked -cpf ${PROFILE}${EXT}  -I "${BHP_COMPRESSOR}" \
				${PROFILE} || { pr_end 1 Packing; continue; }
		else
			if [ -f ${PROFILE}${EXT} ]; then
				tarball=${PROFILE}${EXT}
			elif [ -f ${PROFILE}.old${EXT} ]; then
				tarball=${PROFILE}.old${EXT}
			else
				pr_warn "No tarball found."; continue
			fi
			tar -xpf ${PROFILE}${EXT}  -I "${BHP_COMPRESSOR}" &&
				touch ${PROFILE}/.unpacked || { pr_end 1 Unpacking; continue; }
		fi
		pr_end "${?}"
		cd "${OLD}"
	done
}

#
# @FUNCTION: Simple function to handle syncing the tarball archive to disk
#
bhp_daemon_loop()
{
	while true; do
		sleep "${BHP_DAEMON}"
		bhp
	done
}

case "${0##*/}" in
	(bhp*|browser-home-profile*)
		BHP_ZERO="${0##*/}"
		if [ -t 1 ] && yesno "${PRINT_COLOR:-Yes}"; then
			eval_colors
		fi
		bhp_init_profile "${@}"
		if [ -n "${BHP_DAEMON}" -a "${?}" = 0 ]; then
			bhp_daemon_loop "${BHP_DAEMON}"
		fi
		;;
	(*) NAME="bhp";;
esac

#
# vim:fenc=utf-8:ft=sh:ci:pi:sts=2:sw=2:ts=2:
#
