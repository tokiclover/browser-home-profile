#!/bin/sh
#
# $Header: bhp.sh                                              Exp $
# $Author: (c) 2012-2016 tokiclover <tokiclover@gmail.com>     Exp $
# $License: MIT (or 2-clause/new/simplified BSD)               Exp $
# $Version: 1.0 2016/02/24                                     Exp $
#

if [ -n "${ZSH_VERSION}" ]; then
	emulate sh
	NULLCMD=:
	setopt SH_WORD_SPLIT
	setopt EXTENDED_GLOB NULL_GLOB
elif [ -n "${BASH_VERSION}" ]; then
	shopt -qs nullglob
	shopt -qs extglob
fi

NULL=/dev/null
case "${0##*/}" in
	(bhp*|browser-home-profile*) BHP_ZERO="${0##*/}";;
	(*) BHP_ZERO=bhp;;
esac

#
# @FUNCTION: Print error message to stderr
#
pr_error()
{
	local PFX=${name:+" ${CLR_MAG}${name}:${CLR_RST}"}
	echo -e "${PR_EOL} ${CLR_RED}*${CLR_RST}${PFX} ${@}" >&2
}

#
# @FUNCTION: Print error message to stderr & exit
#
die()
{
	local ret=${?}; pr_error "${@}"; exit ${ret}
}

#
# @FUNCTION: Print info message to stdout
#
pr_info()
{
	local PFX=${name:+" ${CLR_YLW}${name}:${CLR_RST}"}
	echo -e "${PR_EOL} ${CLR_BLU}*${CLR_RST}${PFX} ${@}"
}

#
# @FUNCTION: Print warn message to stdout
#
pr_warn()
{
	local PFX=${name:+" ${CLR_RED}${name}:${CLR_RST}"}
	echo -e "${PR_EOL} ${CLR_YLW}*${CLR_RST}${PFX} ${@}"
}

#
# @FUNCTION: Print begin message to stdout
#
pr_begin()
{
	echo -en "${PR_EOL}"
	PR_EOL="\n"
	local PFX=${name:+"${CLR_MAG}[${CLR_RST} ${CLR_BLU}${name}${CLR_RST}: ${CLR_MAG}]${CLR_RST}"}
	echo -en " ${PFX} ${@}"
}

#
# @FUNCTION: Print end message to stdout
#
pr_end()
{
	local suffix
	case "${1-0}" in
		(0) suffix="${CLR_BLU}[${CLR_RST} ${CLR_GRN}Ok${CLR_RST} ${CLR_BLU}]${CLR_RST}";;
		(*) suffix="${CLR_YLW}[${CLR_RST} ${CLR_RED}No${CLR_RST} ${CLR_YLW}]${CLR_RST}";;
	esac
	shift
	echo -en " ${@} ${suffix}\n"
	PR_EOL=
}

#
# @FUNCTION: YES or NO helper
#
yesno()
{
	case "${1:-NO}" in
	(0|[Dd][Ii][Ss][Aa][Bb][Ll][Ee]|[Oo][Ff][Ff]|[Ff][Aa][Ll][Ss][Ee]|[Nn][Oo])
		return 1;;
	(1|[Ee][Nn][Aa][Bb][Ll][Ee]|[Oo][Nn]|[Tt][Rr][Uu][Ee]|[Yy][Ee][Ss])
		return 0;;
	(*)
		return 2;;
	esac
}

# @FUNCTION: Colors handler
#
eval_colors()
{
	local BLD ESC FGD clr
	BLD='1;' ESC='\e[' FGD='3'

	for clr in 0:BLK 1:RED 2:GRN 3:YLW 4:BLU 5:MAG 6:CYN 7:WHT; do
		eval CLR_${clr#*:}="'${ESC}${BLD}${FGD}${clr%:*}m'"
	done
	CLR_RST="${ESC}0m"
}

if [ -t 1 ] && yesno "${COLOR:-Yes}"; then
	eval_colors
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

	local ARGS name=mktmp
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
	if type -p mktemp >${NULL} 2>&1; then
		mktmp=mktemp
	elif type -p busybox >${NULL} 2>&1; then
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
  -b, --browser=Web-Browser   Select a browser to set up
  -c, --compressor='lzop -1'  Use lzop compressor, default to lz4
  -t, --tmpdir=DIR            Set up a particular TMPDIR
  -p, --profile=PROFILE       Select a particular profile
  -h, --help                  Print help message and exit
EOH
}

bhp_find_browser()
{
	local BROWSERS MOZ_BROWSERS set brs dir
	MOZ_BROWSERS='aurora firefox icecat seamonkey'
	BROWSERS='conkeror chrom epiphany midory opera otter qupzilla netsurf vivaldi'

	case "${1}" in
		(*aurora|firefox*|icecat|seamonkey)
			BROWSER="${1}" BHP_PROFILE="mozilla/${1}"; return;;
		(conkeror*|*chrom*|epiphany|midory|opera*|otter*|qupzilla|netsurf*|vivaldi*)
			BROWSER="${1}" BHP_PROFILE="config/${1}" ; return;;
	esac

	for set in "mozilla:${MOZ_BROWSERS}" "config:${BROWSERS}"; do
		for brs in ${set#*:}; do
			set="${set%:*}"
			for dir in "${HOME}"/.${set}/*${brs}*; do
				[ -d "${dir}" ] && { BROWSER="${brs}" BHP_PROFILE="${set}/${brs}"; return; }
			done
		done
	done
	return 1
}

bhp_mozilla_profile()
{
	[ -n "${2}" -a -d "${HOME}/.${1}/${2}" ] &&
		{ BHP_PROFILE="${1}/${2}"; return; }

	BHP_PROFILE="${1}/$(sed -nre "s|^[Pp]ath=(.*$)|\1|p" \
		${HOME}/.${1}/profiles.ini)"
	[ -n "${BHP_PROFILE}" -a -d "${HOME}/.${BHP_PROFILE}" ] ||
		{ pr_error "No firefox profile dir found"; return 113; }
}

#
# Use a private initializer function
#
bhp_init_profile()
{
	local ARGS DIR EXT OLD PROFILE browser dir char name="${BHP_ZERO}" tmpdir
	ARGS="$(getopt \
		-o b:c:hp:t: -l browser:,compressor:,help,profile:,tmpdir: \
		-n bhp -s sh -- "${@}")"
	[ ${?} = 0 ] || return 111
	eval set -- ${ARGS}

	while true; do
		case "${1}" in
			(-c|--compressor) BHP_COMPRESSOR="${2}";;
			(-h|--help) bhp_message_help; return 128;;
			(-b|--browser) browser="${2}";;
			(-p|--profile) PROFILE="${2}";;
			(-t|--tmpdir) tmpdir="${2}";;
			(*) shift; break;;
		esac
		shift 2
	done

	bhp_find_browser "${browser:-${1:-$BROWSER}}"
	[ -n "${BROWSER}" ] && export BROWSER || 
		{ pr_error "No browser found."; return 112; }
	case "${BHP_PROFILE}" in
		(mozilla*) bhp_mozilla_profile "${BHP_PROFILE}" "${PROFILE}";;
	esac

:	${BHP_COMPRESSOR:=lz4 -1 -}
:	${EXT=.tar.${BHP_COMPRESSOR%% *}}
:	${tmpdir:=${TMPDIR:-/tmp/$USER}}
:	${PROFILE:=${BHP_PROFILE##*/}}

	[ -d "${TMPDIR}" ] || mkdir -p -m 1700 "${TMPDIR}" ||
		{ pr_error "No suitable directory found"; return 2; }

	for dir in "${HOME}"/.${BHP_PROFILE} "${HOME}"/.cache/${BHP_PROFILE#config/}; do
		[ -d "${dir}" ] || continue
		grep -q "${dir}" /proc/mounts && continue
		OLD="${PWD}"

		pr_begin "Setting up directory...\n"
		cd "${dir%/*}" || { pr_end 1 Directory; continue; }
		if [ ! -f "${PROFILE}${EXT}" ] || [ ! -f "${PROFILE}.old${EXT}" ]; then
			tar -Ocp ${PROFILE} | ${BHP_COMPRESSOR} ${PROFILE}${EXT} ||
				{ pr_end 1 Tarball; continue; }
		fi
		cd "${OLD}"

		case "${dir}" in
			(*.cache/*) char=c;;
			(*) char=p;;
		esac
		DIR="$(mktmp -p "${tmpdir}" -d bh${char}-XXXXXX)"
		sudo mount --bind "${DIR}" "${dir}" 2>${NULL} ||
			{ pr_end 1 Mounting; continue; }
		pr_end "${?}"
	done
}
bhp_init_profile "${@}"
BHP_RET="${?}"

#
# @FUNCTION: Maintain BHP archive tarballs
#
bhp()
{
	local EXT OLD PROFILE name=bhp tarball
	EXT=".tar.${BHP_COMPRESSOR%% *}" PROFILE="${BHP_PROFILE##*/}"

	for dir in "${HOME}"/.${BHP_PROFILE} "${HOME}"/.cache/${BHP_PROFILE#config/}; do
		[ -d "${dir}" ] || continue
		OLD="${PWD}"

		pr_begin "Setting up tarball...\n"
		cd "${dir%/*}" || continue
		if [ -f ${PROFILE}/.unpacked ]; then
			if [ -f ${PROFILE}${EXT} ]; then
				mv -f ${PROFILE}${EXT} ${PROFILE}.old${EXT} ||
					{ pr_end 1 Moving; continue; }
			fi
			tar -X ${PROFILE}/.unpacked -Ocp ${PROFILE} | \
				${BHP_COMPRESSOR} ${PROFILE}${EXT} ||
				{ pr_end 1 Packing; continue; }
		else
			if [ -f ${PROFILE}${EXT} ]; then
				tarball=${PROFILE}${EXT}
			elif [ -f ${PROFILE}.old${EXT} ]; then
				tarball=${PROFILE}.old${EXT}
			else
				pr_warn "No tarball found."; continue
			fi
			${BHP_COMPRESSOR%% *} -cd ${tarball} | tar -xp &&
				touch ${PROFILE}/.unpacked ||
				{ pr_end 1 Unpacking; continue; }
		fi
		pr_end "${?}"
		cd "${OLD}"
	done
}

case "${0##*/}" in
	(bhp|browser-home-profile) [ ${BHP_RET} = 0 ] && bhp;;
esac
unset BHP_RET

#
# vim:fenc=utf-8:ft=sh:ci:pi:sts=2:sw=2:ts=2:
#
