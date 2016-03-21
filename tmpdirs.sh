#!/bin/sh
#
# $Header: tmpdir.sh                                           Exp $
# $Author: (c) 2016 tokiclover <tokiclover@gmail.com>          Exp $
# $License: MIT (or 2-clause/new/simplified BSD)               Exp $
# $Version: 1.0 2016/03/18                                     Exp $
#
#
# This package manage temporary directory (hierarchy) build on top of a collection
# of helpers and utilities divided in several export tags.
#
# Temporary directory can be pretty plain by using only --tmpdir-prefix
# to get a plain tmpfs mounted directory. And then, building a hierarchy of
# --tmpdir-saved and --tmpdir-unsaved directories can be easily done. This can
# be handy to regroup a few writable directories for read only systems, or more
# generarly, reduce disk seeks for whatever reason (e.g. system responsiveness.) 
#
# --tmpdir-unsaved can be seen as make a directory writable in the filesystem and
# then discard everything afterwards with system reboot/shutdown. --tmpdir-saved
# can be used, for example, to make '/var/log' a temporary storage on quick access
# filesystem, and then, maybe save before system reboot/shutdown to disk.
#
# This usage can be extended to other directories to get a responsive system.
# Extra space efficiency can be atained by using zram which can be stacked with
# this type of usage.
#

TMPDIR_LIBDIR="${0%/*}"
version_string=1.0
if ! source "${TMPDIR_LIBDIR}"/sh/functions.sh; then
	echo "Failed to load functions.sh" >&2
	exit 1
fi

:	${tmpdir_size:=10%}
:	${tmpdir_compressor:=lz4 -1}
:	${tmpdir_extension:=.tar.${tmpdir_compressor%% *}}

#
# @FUNCTION: Setup a temporary directory hierarchy with optional tarball
#   archives for entries requiring state retention
#
tmpdir_setup()
{
	tmpdir_init || return
	local DIR IFS=":${IFS}" dir

	for dir in ${tmpdir_saved} ${tmpdir_unsaved}; do
		DIR="${tmpdir_prefix}${dir}"
		mount_info "${DIR}" && continue
		mkdir -p "${DIR}"
		pr_begin  "Mounting ${DIR}"
		mount --bind "${DIR}" "${dir}"
		pr_end "$?"
	done
	tmpdir_restore
	return 0
}

#
# @FUNCTION: Intialize a temporary directory hierarchy by mounting the prefix
#   directory
#
tmpdir_init()
{
	local IFS=":${IFS}" dir ret
	for dir in ${tmpdir_saved}; do
		[ -e "${dir}${tmpdir_extension}" ] && continue
		[ -d "${dir}" ] && tmpdir_save "${dir}" || mkdir -p "${dir}"
	done

	mount_info "${tmpdir_prefix}" && return
	[ -d "${tmpdir_prefix}" ] || mkdir -p "${tmpdir_prefix}"
	mount -o rw,nodev,relatime,mode=755,size=${tmpdir_size:-20%} \
		-t tmpfs tmpdir "${tmpdir_prefix}"
}

#
# @FUNCTION: Restore temporary directory hierarchy from tarball archives
#
tmpdir_restore()
{
	local IFS=":${IFS}" cwd="${PWD}" tarball

	for dir in ${@:-${tmpdir_saved}}; do
		cd "${dir%/*}" || continue

		if [ -f "${dir}${tmpdir_extension}" ]; then
		:	tarball="${dir}${tmpdir_extension}"
		elif [ -f "${dir}.old${tmpdir_extension}" ]; then
		:	tarball="${dir}.old${tmpdir_extension}"
		else
			pr_warn "No tarball found for ${dir}"
			continue
		fi
		pr_begin  "Restoring ${dir}"
		tar -xpf "${tarball}" -I "${tmpdir_compressor}" "${dir##*/}"
		pr_end "${?}"
	done
	cd "${cwd}"
}

#
# @FUNCTION: Save temporary directory hierarchy to disk
#
tmpdir_save()
{
	local IFS=":${IFS}" cwd="${PWD}"

	for dir in ${@:-${tmpdir_saved}}; do
		cd "${dir%/*}" || continue

		if [ -f "${dir}${tmpdir_extension}" ]; then
			mv -f "${dir}${tmpdir_extension}" "${dir}.old${tmpdir_extension}"
		fi
		pr_begin  "Saving ${dir}"
		tar -cpf "${dir}${tmpdir_extension}" -I "${tmpdir_compressor}" ${dir##*/}
		pr_end "${?}"
	done
	cd "${cwd}"
}

help_message()
{
	cat <<-EOH
Usage: ${0##*/} [OPTIONS] [--boot] [--tmpdir-prefix=DIRECTORY] [ZRAM_DEVICES]
  -z, --zram-num-dev=8                Setup ZRAM devices number (default to 4)
  -c, --zram-compressor=lzo           Setup ZRAM compressor (default to lz4)
  -s, --zram-stream=4                 Setup ZRAM stream number per device (deafault to 2)
  -p, --tmpdir-prefix=/var/tmp        Setup temporary directory hierarchy
  -C, --tmpdir-compressor='lzop -1'   Setup tmpdir compressor (default to lz4)
  -t, --tmpdir-saved=/var/log         Setup archived temporary directory
  -T, --tmpdir-unsaved=/var/run       Setup unarchived temporary directory
  -b, --boot                          Run subsystem initialization (kernel module)
  -h, --help                          Print help message
  -v, --version                       Print version message

Example:
* \`${0##*/} "512m swap" "8G ext4 /var/db 0755 user_xattr"' to create two devices
* \`${0##*/} --tmpdir-prefix=/var/test' to create a new (tmpfs) temporary-directory
* \`${0##*/} --boot -p /var/tmp --tmpdir-saved=/var/log "8G ext4 /var/tmp 1777"'
     to chain a temporary directory hierarchy on top of zram
EOH
}

version_message()
{
	echo "${0##*/} version ${version_string}"
}

:	${zram_num_dev:=4}
:	${zram_compressor:=lz4}
:	${zram_num_stream:=2}

#
# @FUNCTION:Setup zram device with the following format:
#   Size FileSystem Mount-Point Mode Mount-Options
#   (mode is an octal mode to be passed to chmod, mount-option to mount) 
#
zram_setup()
{
	zram_init
	local DEV dev fs="${2}" mode="${4}" dir="${3}" num=0 opt="${5}" ret size="${1}"

	#
	# Find the first free device
	#
	while true; do
		dev=/dev/zram${num}
		[ -b ${dev} ] || return 1
		if [ "$(cat /sys/block/zram${num}/size)" != 0 ]; then
			num=$((${num}+1)); continue;
		else
			break
		fi
	done
	DEV="/sys/block/zram${num}"
	#
	# Initialize device if defined
	#
	[ -n "${size}" ] || return 1
	[ -n "${zram_compressor}" ] && echo "${zram_compressor}" >${DEV}/comp_algorithm
	[ -n "${zram_num_stream}" ] && echo "${zram_num_stream}" >${DEV}/max_comp_streams
	echo "${size}" >${DEV}/disksize || return 2
	#
	# Setup device if requested
	#
	[ -n "${fs}" ] || return 0
	case "${fs}" in
		(swap)
			pr_begin "Setting up ${dev} swap device\n"
			mkswap ${dev} && swapon ${dev}
			pr_end "${?}";;
		([a-z]*)
			pr_begin "Setting up ${dev} for ${fs} filesystem\n"
			mkfs -t "${fs}" "${dev}"
			ret="${?}"; pr_end "${ret}"

			if [ "${ret}" = 0 ] && [ -n "${dir}" ]; then
				[ -d "${dir}" ] || mkdir -p "${dir}"

				pr_begin "Mounting ${dev} on ${dir}"
				mount -t "${fs}" ${opt:+-o} ${opt} "${dev}" "${dir}"
				pr_end "${?}"
				[ -n "${mode}" ] && chmod "${mode}" "${dir}"
			fi;;
	esac
	return 0
}

#
# @FUNCTION: Setup low level details and initialize kernel module if BOOT_SETUP
#   env-variable is set. passed. See zram_setup() for the hash keys/values.
#
zram_init()
{
	case "${zram_compressor}" in
		(lz4|lzo)           ;;
		(*) zram_compressor=;;
	esac
	[ -w /sys/block/zram0/comp_algorithm   ] || zram_compressor=
	[ -w /sys/block/zram0/max_comp_streams ] || zram_num_stream=

	yesno "${BOOT_SETUP}" || return 0
	if mount_info -m zram; then
		if ! rmmod zram >/dev/null 2>&1; then
			zram_reset && rmmod zram >/dev/null 2>&1 || return 1
		fi
	fi
	pr_begin "Setting up zram kernel module"
	modprobe zram num_devices=${zram_num_dev}
	pr_end "${?}"
}

#
# @FUNCTION: Initialize zram devices passed arguments or glob everything found
#   in /dev/zram*
#
zram_reset()
{
	local dev ret=0
	for dev in ${@:-/dev/zram[0-9]*}; do
		if mount_info "${dev}" || mount_info -s "${dev}"; then
			pr_warn "${dev} is busy"
			ret=$((${ret}+1))
			continue
		fi
		echo 1 >/sys/block/${dev#/dev}reset
	done
	return "${ret}"
}

if [ "${0##*/}" = "tmpdirs.sh" ]; then
	[ "${#}" = 0 ] && { tmpdir_help_message; exit 1; }
	if [ -t 1 ] && yesno "${PRINT_COLOR:-Yes}"; then
		eval_colors
	fi
	NAME="${0##*/}"
	ARGS="$(getopt \
		-o bC:c:hs:T:t:p:vz: -l boot,tmpdir-compressor,zram-compressor: \
		-l help,zram-stream:,tmpdir-prefix:,tmpdir-unsaved:,tmpdir-saved:,version \
		-l zram-num-dev -s sh -n "${0##*/}" -- "${@}")"
	[ "${?}" = 0 ] || { tmpdir_help_message; exit 2; }
	eval set -- ${ARGS}

	while true; do
		case "${1}" in
			(-t|--tmpdir-saved)    tmpdir_saved="${tmpdir_saved} ${2}"   ; shift;;
			(-C|--tmpdir-compressor) tmpdir_compressor="${2}"            ; shift;;
			(-T|--tmpdir-unsaved) tmpdir_unsaved="${tmpdir_unsaved} ${2}"; shift;;
			(-c|--zram-compressor) zram_compressor="${2}"                ; shift;;
			(-b|--boot)            BOOT_SETUP=true                              ;;
			(-h|--help)            help_message; exit 0                         ;;
			(-s|--zram-stream)     zram_num_stream="${2}"                ; shift;;
			(-p|--tmpdir-prefix) tmpdir_prefix="${2}"                    ; shift;;
			(-v|--version)      version_message; exit 0                         ;;
			(-z|--zram-num-dev) zram_num_dev=$((${zram_num_dev}+${2}))   ; shift;;
			(*) shift; break;;
		esac
		shift
	done

	for arg; do
		zram_setup ${arg}
	done
	if [ -n "${tmpdir_prefix}" ]; then
		tmpdir_setup
	elif [ -n "${tmpdir_saved}" ]; then
		tmpdir_save
	fi
fi

#
# vim:fenc=utf-8:ft=sh:ci:pi:sts=2:sw=2:ts=2:
#
