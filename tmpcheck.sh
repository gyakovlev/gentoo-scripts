#!/bin/bash

# Filename: tmpcheck.sh
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 12/01/2018

# Copyright (C) 2018  Michael Mair-Keimberger
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

# Discription:
#	prototype script for new scripts

#
### IMPORTANT SETTINGS START ###
#
DEBUG=false

SCRIPT_NAME="tmpcheck"
SCRIPT_SHORT="TMC"
SCRIPT_MODE=false

WORKDIR="/tmp/${SCRIPT_NAME}-${RANDOM}"
PORTTREE="/usr/portage/"
DL='|'
SITEDIR="${HOME}/${SCRIPT_NAME}/"

# set scriptmode=true on host vs4
if [ "$(hostname)" = vs4 ]; then
	SCRIPT_MODE=true
	SITEDIR="/var/www/gentooqa.levelnine.at/results/"
fi
# get dirpath and load funcs.sh
startdir="$(dirname $(readlink -f $BASH_SOURCE))"
if [ -e ${startdir}/funcs.sh ]; then
	source ${startdir}/funcs.sh
else
	echo "Missing funcs.sh"
	exit 1
fi
# switch to the PORTTREE dir
cd ${PORTTREE}
# set the search depth
depth_set ${1}
# export important variables
export PORTTREE WORKDIR SCRIPT_MODE DL DEBUG SCRIPT_SHORT
#
### IMPORTANT SETTINGS STOP ###
#

main() {
	local absolute_path=${1}
	local category="$(echo ${absolute_path}|cut -d'/' -f2)"
	local package="$(echo ${absolute_path}|cut -d'/' -f3)"
	local filename="$(echo ${absolute_path}|cut -d'/' -f4)"
	local packagename="${filename%.*}"
	local full_path="${PORTTREE}/${category}/${package}"
	local full_path_ebuild="${PORTTREE}/${category}/${package}/${filename}"
	local maintainer="$(get_main_min "${category}/${package}")"

	if ${DEBUG}; then
		# Debug
		echo "absolute path: ${absolute_path}"
		echo "full path: ${full_path}"
		echo "full path ebuild: ${full_path_ebuild}"
		echo "category: ${category}"
		echo "package: ${package}"
		echo "filename: ${filename}"
		echo "packagename: ${packagename}"
		echo "fileage: $(get_age "${filename}")"
		echo "maintainer: ${maintainer}"
		echo
	fi

	if ${SCRIPT_MODE}; then
		echo "$(get_age "${filename}")${DL}${category}${DL}${package}${DL}${filename}${DL}${maintainer}" >> ${WORKDIR}/${SCRIPT_SHORT}-IMP-tmpcheck/full.txt
	else
		echo "$(get_age "${filename}")${DL}${category}${DL}${package}${DL}${filename}${DL}${maintainer}"
	fi
}

export -f main

${SCRIPT_MODE} && mkdir -p ${WORKDIR}

find ./${level} \( \
	-path ./scripts/\* -o \
	-path ./profiles/\* -o \
	-path ./packages/\* -o \
	-path ./licenses/\* -o \
	-path ./distfiles/\* -o \
	-path ./metadata/\* -o \
	-path ./eclass/\* -o \
	-path ./.git/\* \) -prune -o -type f -name "*.ebuild" -exec egrep -l 'dev-libs/openssl.*dev-libs/libressl' {} \; | parallel main {}

if ${SCRIPT_MODE}; then
	foldername="${SCRIPT_SHORT}-IMP-tmpcheck/"
	newpath="${WORKDIR}/${foldername}"

	gen_sort_main ${newpath}/full.txt 5 ${newpath} ${DL}
	gen_sort_pak ${newpath}/full.txt 3 ${newpath} ${DL}

	rm -rf ${SITEDIR}/checks/${foldername}
	cp -r ${newpath} ${SITEDIR}/checks/
	rm -rf ${WORKDIR}
fi
