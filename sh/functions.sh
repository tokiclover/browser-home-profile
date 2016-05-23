#
# $Header: tmpdir/sh/functions.sh                              Exp $
# $Author: (c) 2012-2016 tokiclover <tokiclover@gmail.com>     Exp $
# $License: MIT (or 2-clause/new/simplified BSD)               Exp $
# $Version: 1.4 2016/03/18                                     Exp $
#
#
# Some reusable helpers to format print output prepended with 'NAME:' or '[NAME]'
# (NAME refer to global name with ANSI color (escapes)  support.
# COLOR_<VAL> variables hold the common named ANSI color escapes sequence.
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
trap 'PRINT_COL="$(tput cols)"' WINCH

#
# Setup a few environment variables beforehand
#
PRINT_COL="$(tput cols)"

#
# @FUNCTION: Print error message to stderr
#
pr_error()
{
	local msg="${*}"
	PRINT_LEN=$((${#NAME}+3+${#msg}))
	local PFX="${NAME:+${COLOR_MAG}${NAME}:${COLOR_RST}}"
	echo -e "${PRINT_EOL}${COLOR_RED}ERROR:${COLOR_RST} ${PFX} ${@}" >&2
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
	local msg="${*}"
	PRINT_LEN=$((${#NAME}+3+${#msg}))
	local PFX="${NAME:+${COLOR_YLW}${NAME}:${COLOR_RST}}"
	echo -e "${PRINT_EOL}${COLOR_BLU}INFO:${COLOR_RST} ${PFX} ${@}"
}

#
# @FUNCTION: Print warn message to stdout
#
pr_warn()
{
	local msg="${*}"
	PRINT_LEN=$((${#NAME}+3+${#msg}))
	local PFX="${NAME:+${COLOR_RED}${NAME}:${COLOR_RST}}"
	echo -e "${PRINT_EOL}${COLOR_YLW}WARN:${COLOR_RST} ${PFX} ${@}"
}

#
# @FUNCTION: Print begin message to stdout
#
pr_begin()
{
	echo -en "${PRINT_EOL}"
	PRINT_EOL="\n"
	local msg="${*}"
	PRINT_LEN=$((${#NAME}+3+${#msg}))
	local PFX="${NAME:+${COLOR_MAG}[${COLOR_BLU}${NAME}${COLOR_MAG}]${COLOR_RST}}"
	echo -en "${PFX} ${@}"
}

#
# @FUNCTION: Print end message to stdout
#
pr_end()
{
	local suffix
	case "${1-0}" in
		(0) suffix="${COLOR_BLU}[${COLOR_GRN}Ok${COLOR_BLU}]${COLOR_RST}";;
		(*) suffix="${COLOR_YLW}[${COLOR_RED}No${COLOR_YLW}]${COLOR_RST}";;
	esac
	shift
	PRINT_LEN=$((${PRINT_COL}-${PRINT_LEN}))
	printf "%*b\n" "${PRINT_LEN}" "${@} ${suffix}"
	PRINT_EOL=
	PRINT_LEN=0
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

#
# @FUNCTION: ANSI Colors intialization handler
#
eval_colors()
{
	local ESC FGD BGD clr
	ESC='\e[' FGD='3' BGD='4'

	for clr in 0:BLK 1:RED 2:GRN 3:YLW 4:BLU 5:MAG 6:CYN 7:WHT; do
		eval COLOR_${clr#*:}="'${ESC}${FGD}${clr%:*}m'"
		eval COLOR_BG_${color#*:}="'${ESC}${BGD}${color%:*}m'"
	done
	COLOR_RST="${ESC}0m"
	COLOR_BLD="${ESC}1m"
	COLOR_UND="${ESC}4m"
	COLOR_ITA="${ESC}3m"
	if [ "${1}" = 256 ]; then
		for i in seq 0 255; do
			eval BG_${i}="'${ESC}${BGD}${i}m'"
			eval FG_${i}="'${ESC}${FGD}${i}m'"
		done
	fi
}

#
# @FUNCTION: Simple helper to probe dir, dev, module
#
mount_info()
{
	local file
	case "${1}" in
		(-s) file="/proc/swaps"  ; shift;;
		(-m) file="/proc/modules"; shift;;
		(*)  file="/proc/mounts"        ;;
	esac
	grep -qw "${1}" "${file}"
}

#
# vim:fenc=utf-8:ft=sh:ci:pi:sts=2:sw=2:ts=2:
#
