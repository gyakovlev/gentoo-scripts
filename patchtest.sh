#!/bin/bash

# Filename: patchtest
# Autor: Michael Mair-Keimberger (m DOT mairkeimberger AT gmail DOT com)
# Date: 01/08/2016

# Copyright (C) 2017  Michael Mair-Keimberger
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
# simple scirpt to find unused patches in the gentoo portage tree

DEBUG=false

SCRIPT_MODE=false
SCRIPT_NAME="patchtest"
SCRIPT_SHORT="PAT"

PORTTREE="/usr/portage/"
SITEDIR="${HOME}/${SCRIPT_NAME}/"
WORKDIR="/tmp/${SCRIPT_NAME}-${RANDOM}/"
DL='|'

startdir="$(dirname $(readlink -f $BASH_SOURCE))"
if [ -e ${startdir}/funcs.sh ]; then
	source ${startdir}/funcs.sh
else
	echo "Missing funcs.sh"
	exit 1
fi

if [ "$(hostname)" = vs4 ]; then
	SCRIPT_MODE=true
	SITEDIR="/var/www/gentooqa.levelnine.at/results/"
fi

cd ${PORTTREE}
depth_set ${1}

main(){
	check_ebuild(){
		local patchfile=$1
		local found=false
		local pn='${PN}'
		local p='${P}'
		local pf='${PF}'
		local pv='${PV}'
		local pvr='${PVR}'
		local slot='${SLOT}'

		$DEBUG && >&2 echo
		$DEBUG && >&2 echo "*DEBUG: pachfile to check: $patchfile"

		for ebuild in ${fullpath}/*.ebuild; do
			$DEBUG && >&2 echo "**DEBUG: Check ebuild: $ebuild"

			# get ebuild detail
			local ebuild_full=$(basename ${ebuild%.*})
			local ebuild_version=$(echo ${ebuild_full/${package_name}}|cut -d'-' -f2)
			local ebuild_revision=$(echo ${ebuild_full/${package_name}}|cut -d'-' -f3)
			local ebuild_slot="$(grep ^SLOT $ebuild|cut -d'"' -f2)"

			$DEBUG && >&2 echo "**DEBUG: Ebuildvars: ver: $ebuild_version rever: $ebuild_revision slot: $ebuild_slot"

			local cn=()
			# create custom names to check
			cn+=("${patchfile}")
			cn+=("${patchfile/${package_name}/${pn}}")
			cn+=("${patchfile/${package_name}-${ebuild_version}/${p}}")
			cn+=("${patchfile/${ebuild_version}/${pv}}")

			local cn_name_vers="${patchfile/${package_name}/${pn}}"
			cn+=("${cn_name_vers/${ebuild_version}/${pv}}")

			# special naming
			if $(grep -E "^MY_PN=|^MY_P=|^MY_PV=|^MODULE_VERSION=|^DIST_VERSION=|^X509_VER" ${ebuild} >/dev/null); then
				# set variables
				local var_my_pn='${MY_PN}'
				local var_my_p='${MY_P}'
				local var_my_pv='${MY_PV}'
				local var_mod_ver='${MODULE_VERSION}'
				local var_dist_ver='${DIST_VERSION}'
				local var_x509_ver='${X509_VER}'

				local package_name_ver="${package_name}-${ebuild_version}"

				# get the variables from the ebuilds
				my_pn_name="$(grep ^MY_PN\= ${ebuild})"
				my_p_name="$(grep ^MY_P\= ${ebuild})"
				my_pv_name="$(grep ^MY_PV\= ${ebuild})"
				my_mod_ver="$(grep ^MODULE_VERSION\= ${ebuild})"
				my_dist_ver="$(grep ^DIST_VERSION\= ${ebuild})"
				my_x509_ver="$(grep ^X509_VER\= ${ebuild}|cut -d' ' -f1)"

				# i dont know
				[ -n "${my_pn_name}" ] && \
					eval my_pn_name="$(echo ${my_pn_name:6}|sed "s|PN|package_name|g")" >/dev/null 2>&1
				[ -n "${my_pv_name}" ] && \
					eval my_pv_name="$(echo ${my_pv_name:6}|sed "s|PV|ebuild_version|g")" >/dev/null 2>&1
				[ -n "${my_p_name}" ] && \
					eval my_p_name="$(echo ${my_p_name:5}|sed "s|P|package_name_ver|g")" >/dev/null 2>&1

				[ -n "${my_mod_ver}" ] && \
					eval my_mod_ver="$(echo ${my_mod_ver:15})" >/dev/null 2>&1
				[ -n "${my_dist_ver}" ] && \
					eval my_dist_ver="$(echo ${my_dist_ver:13})" >/dev/null 2>&1
				[ -n "${my_x509_ver}" ] && \
					eval my_x509_ver="$(echo ${my_x509_ver:9})" >/dev/null 2>&1

				$DEBUG && >&2 echo "***DEBUG: Found MY_P* vars: $my_pv_name, $my_pn_name, $my_p_name, $my_mod_ver, $my_dist_ver, $my_x509_ver"

				[ -n "${my_pn_name}" ] && cn+=("${patchfile/${my_pn_name}/${var_my_pn}}")
				[ -n "${my_pv_name}" ] && cn+=("${patchfile/${my_pv_name}/${var_my_pv}}")
				[ -n "${my_p_name}" ] && cn+=("${patchfile/${my_p_name}/${var_my_p}}")

				if [ -n "${my_mod_ver}" ]; then
					cn+=("${patchfile/${my_mod_ver}/${var_mod_ver}}")
					n1="${patchfile/${my_mod_ver}/${var_mod_ver}}"
					cn+=("${n1/${package_name}/${pn}}")
				fi

				if [ -n "${my_dist_ver}" ]; then
					cn+=("${patchfile/${my_dist_ver}/${var_dist_ver}}")
					n2="${patchfile/${my_dist_ver}/${var_dist_ver}}"
					cn+=("${n2/${package_name}/${pn}}")
				fi

				if [ -n "${my_x509_ver}" ]; then
					cn+=("${patchfile/${my_x509_ver}/${var_x509_ver}}")
					n2="${patchfile/${my_x509_ver}/${var_x509_ver}}"
					cn+=("${n2/${package_name}/${pn}}")
					cn+=("${n2/${package_name}-${ebuild_version}/${p}}")
				fi


			fi

			# add special naming if there is a revision
			if [ -n "${ebuild_revision}" ]; then
				cn+=("${patchfile/${package_name}-${ebuild_version}-${ebuild_revision}/${pf}}")
				cn+=("${patchfile/${ebuild_version}-${ebuild_revision}/${pvr}}")
			fi
			# looks for names with slotes, if slot is not 0
			if [ -n "${ebuild_slot}" ] && ! [ "${ebuild_slot}" = "0" ]; then
				cn+=("${patchfile/${ebuild_slot}/${slot}}")
				name_slot="${patchfile/${package_name}/${pn}}"
				name_slot="${name_slot/${ebuild_slot}/${slot}}"
				cn+=("${name_slot}")
			fi
			# find vmware-modules patches
			if [ "${package_name}" = "vmware-modules" ]; then
				local pv_major='${PV_MAJOR}'
				cn+=("${patchfile/${ebuild_version%%.*}/${pv_major}}")
			fi

			# remove duplicates
			mapfile -t cn < <(printf '%s\n' "${cn[@]}"|sort -u)
			# replace list with newpackages
			local searchpattern="$(echo ${cn[@]}|tr ' ' '\n')"

			$DEBUG && >&2 echo "**DEBUG: Custom names: ${cn[@]}"
			$DEBUG && >&2 echo "**DEBUG: Custom names normalized: ${searchpattern}"

			# check ebuild for the custom names
			if $(sed 's|"||g' ${ebuild} | grep -F "${searchpattern}" >/dev/null); then
				found=true
				$DEBUG && >&2 echo "**DEBUG: CHECK: found $patchfile"
			else
				found=false
				$DEBUG && >&2 echo "***DEBUG: CHECK: doesn't found $patchfile"
			fi

			$found && break
		done

		if $found; then
			echo true
		else
			echo false
		fi
	}

	find_braces_candidates(){
		local work_list=("${unused_patches[@]}")
		local patch
		local pat_found=()
		local count

		$DEBUG && >&2 echo
		$DEBUG && >&2 echo "*DEBUG: find_braces_candidates"

		# expect patches in braces to look like
		# 	packagename-{patch1,patch2}
		# 	$PN-{patch1,patch2}
		#   or
		# 	packagename-version-{patch1,patch2}
		# 	${P}-${PV}-{patch1,patch2}
		#   or
		# 	packagename-versoin-genname-{patch1,patch2}
		#
		# This means 1-3 parts of a filename before '-' should be
		# found at least 2 times

		# first generate a list of files which fits the rule
		for patch in "${work_list[@]}"; do
			local deli=$(echo ${patch%.patch}|grep -o '-'|wc -w)
			for n in 3 2 1; do
				if [ ${deli} -ge ${n} ]; then
					pat_found+=("$(echo $patch|cut -d '-' -f1-${deli})")
					$DEBUG && >&2 echo "***DEBUG: ${patch} with ${deli} \"-\" in filename: saving as $(echo $patch|cut -d '-' -f1-${deli})"
				fi
			done
		done
		# create a list of duplicates
		dup_list=()
		for patch in "${pat_found[@]}"; do
			# search for every element in the array
			# if there are duplicate elements
			$DEBUG && >&2 echo "**DEBUG: check for pattern ${patch}"

			count=$(echo ${pat_found[@]}|grep -P -o "${patch}(?=\s|$)"|wc -w)
			if [ $count -gt 1 ]; then
				dup_list+=($patch)
				$DEBUG && >&2 echo "***DEBUG: ${patch} has duplicates"
			fi
		done
		# remove duplicates from list
		mapfile -t dup_list < <(printf '%s\n' "${dup_list[@]}"|sort -u)
	}

	braces_patches() {
		local patch=$1
		# add matches to the patch_list
		local matches=()
		filess=()
		braces_patch_list=()

		for ffile in $(ls ${fullpath}/files/ |grep $patch); do
			filess+=($ffile)
			ffile="${ffile%.patch}"
			matches+=("${ffile##*-}")
		done

		# set the maximum permutations number (5-6 works)
		if [ ${#matches[@]} -eq 1 ]; then
			braces_patch_list+=("$(echo $patch-${matches[0]}.patch)")
		else
			if [ ${#matches[@]} -le 5 ]; then
				matches="${matches[@]}"
				local perm_list=$(get_perm "$matches")
				for search_patch in $perm_list; do
					braces_patch_list+=("$(echo $patch-{$search_patch}.patch)")
				done
			fi
		fi
	}

	local prechecks=true
	local package=${1}
	local category="$(echo ${package}|cut -d'/' -f2)"

	package_name=${package##*/}
	fullpath="/${PORTTREE}/${package}"

	$DEBUG && >&2 echo "DEBUG: checking: ${category}/${package_name}"
	# check if the patches folder exist
	if [ -e ${fullpath}/files ]; then
		$DEBUG && >&2 echo "DEBUG: found files dir in ${category}/${package_name}"

		# before checking, we have to generate a list of patches which we have to check
		patch_list=()
		
		# white list checking
		white_check(){
			local pfile=${1}
			if [ -e ${startdir}/whitelist ]; then
				source ${startdir}/whitelist
			else
				echo false
			fi

			if $(echo ${white_list[@]} | grep "${package:2};${pfile}" >/dev/null); then
				for white in ${white_list[@]}; do
					local cat_pak="$(echo ${white}|cut -d';' -f1)"
					local white_file="$(echo ${white}|cut -d';' -f2)"
					local white_ebuild="$(echo ${white}|cut -d';' -f3)"
					if [ "${package:2};${pfile}" = "${cat_pak};${white_file}" ]; then
						if [ "${white_ebuild}" = "*" ]; then
							echo true
							break
						else
							for wbuild in $(echo ${white_ebuild} | tr ':' ' '); do
								if [ -e ${PORTTREE}/${package}/${wbuild} ]; then
									echo true
									break 2
								fi
							done
						fi
						echo false
						break
					fi
				done
			else
				echo false
			fi

		}

		for file in ${fullpath}/files/*; do
			if ! [ -d ${file} ]; then
				file="${file##*/}"
				wlr="$(white_check ${file})"

				if ! ${wlr}; then
					if ${prechecks}; then
						if [ "${file}" = "rc-addon.sh" ]; then
							$(grep vdr-plugin-2 ${fullpath}/*.ebuild >/dev/null) || patch_list+=("${file}")
						# check for vdr-plugin-2 eclass which installs confd files if exists
						elif [ "${file}" = "confd" ]; then
							$(grep vdr-plugin-2 ${fullpath}/*.ebuild > /dev/null) || patch_list+=("${file}")
						# check for games-mods eclass which install server.cfg files
						elif [ "${file}" = "server.cfg" ]; then
							$(grep games-mods ${fullpath}/*.ebuild >/dev/null) || patch_list+=("${file}")
						# check for mysql cnf files
						elif [ "${file%%-*}" = "my.cnf" ]; then
							$(grep mysql-multilib-r1 ${fullpath}/*.ebuild >/dev/null) || patch_list+=("${file}")
						# check for apache-module eclass which installs conf files if a APACHE2_MOD_CONF is set
						elif [ "${file##*.}" = "conf" ]; then
							$(grep apache-module ${fullpath}/*.ebuild > /dev/null) && \
								$(grep APACHE2_MOD_CONF ${fullpath}/*.ebuild > /dev/null) || patch_list+=("${file}")
						# check for elisp eclass which install el files if a SITEFILE is set
						elif [ "${file##*.}" = "el" ]; then
							$(grep elisp ${fullpath}/*.ebuild > /dev/null) && \
								$(grep SITEFILE ${fullpath}/*.ebuild > /dev/null) || patch_list+=("${file}")
						# ignoring README.gentoo files
						elif $(echo ${file}|grep -i README.gentoo >/dev/null); then
							break
						else
							patch_list+=("${file}")
						fi
					else
						patch_list+=("${file}")
					fi
				fi
			fi
		done

		$DEBUG && >&2 echo "DEBUG: patchlist: ${patch_list[@]}"
		# first check
		#  every patchfile gets passed to check_ebuild, which replaces
		#  names and version with their corresponding ebuild name ($PN, PV, ..)
		#  and grep's the ebuild with them.
		unused_patches=()
		if [ -n "${patch_list}" ]; then
			for patchfile in "${patch_list[@]}"; do
				found=$(check_ebuild "${patchfile}")
				if ! $found; then
					unused_patches+=("${patchfile}")
				fi
			done
		fi

		# second check
		# find patches in braces (works only with *.patch files)
		# short description:
		#  find_braces_candidates:
		#   this function takes a list of patch file, and looks if the names
		#   look similar (except for the last part: patch-1, patch-2, ...)
		#   If yes it returns back that part of the filename which is the same.

		#  braces_patches:
		#   this function takes the filename which is the same and add the different
		#   ending in braces (like patch-{1,2,3}). In order to get other combinations
		#   it uses a python script to generate permutations.
		#   Also generates a list of filenames with the correct names, in order to remove the
		#   patches from the list if found.

		#  The filename list which was generated by the braces_patches function gets
		#  checked against the ebuilds via check_ebuild
		if [ -n ${unused_patches} ]; then
			find_braces_candidates
			$DEBUG && >&2 echo "DEBUG: duplist: ${dup_list[@]}"
			if [ -n "${dup_list}" ]; then
				for patch in "${dup_list[@]}"; do
					braces_patches ${patch}
					$DEBUG && >&2 echo "DEBUG: brace patches list: ${braces_patch_list[@]}"
					for patchfile in "${braces_patch_list[@]}"; do
						found=$(check_ebuild "${patchfile}")
						if $found; then
							$DEBUG && >&2 echo "DEBUG: found braces: ${patchfile}"
							$DEBUG && >&2 echo "DEBUG: remove from list: ${filess[@]}"
							for toremove in "${filess[@]}"; do
								for target in "${!unused_patches[@]}"; do
									if [ "${unused_patches[target]}" = "${toremove}" ]; then
										unset 'unused_patches[target]'
									fi
								done
							done
							break
						fi
					done
				done
			fi
		fi

		# third check
		# find pachtes which are called with an asterix (*)
		if [ -n ${unused_patches} ]; then
			$DEBUG && >&2 echo
			$DEBUG && >&2 echo "DEBUG: Nonzero unused patches, checking for asterixes"
			for aster_ebuild in ${fullpath}/*.ebuild; do
				for a in $(grep -E 'FILESDIR.*\*' ${aster_ebuild} ); do
					$DEBUG && >&2 echo "DEBUG: found asterixes in ebuild"
					if $(echo ${a}|grep FILESDIR >/dev/null); then
						if ! [ $(echo ${a}|grep -o '[/]'|wc -l) -gt 1 ]; then
							snip="$(echo ${a}|cut -d'/' -f2|grep \*|tr -d '"')"

							local pn='${PN}'
							local p='${P}'
							local pv='${PV}'
							local ebuild_full=$(basename ${aster_ebuild%.*})
							local ebuild_version=$(echo ${ebuild_full/${package_name}}|cut -d'-' -f2)

							snip="${snip/${p}/${package_name}-${ebuild_version}}"
							snip="${snip/${pv}/${ebuild_version}}"
							snip="${snip/${pn}/${package_name}}"

							b="ls ${fullpath}/files/${snip}"
							asterix_patches=$(eval ${b} 2> /dev/null)
							$DEBUG && >&2 echo "found following snipped: $(echo ${a}|cut -d'/' -f2|grep \*|tr -d '"')"
							$DEBUG && >&2 echo "matching following files: ${asterix_patches}"
							for x in ${asterix_patches}; do
								if $(echo ${unused_patches[@]} | grep $(basename ${x}) >/dev/null); then
									asterix_remove=$(basename ${x})
									$DEBUG && >&2 echo "removing from list: ${asterix_remove}"
									for target in "${!unused_patches[@]}"; do
										if [ "${unused_patches[target]}" = "${asterix_remove}" ]; then
											unset 'unused_patches[target]'
										fi
									done
								fi
							done
							[ "${#unused_patches[@]}" -eq 0 ] && break 2
						fi
					fi
				done
			done
		fi

		$DEBUG && echo >&2 "DEBUG: unused patches: ${unused_patches[@]}"
		$DEBUG && echo >&2

		main="$(get_main_min "${category}/${package_name}")"

		if [ ${#unused_patches[@]} -gt 0 ]; then
			if ${SCRIPT_MODE}; then
				for upatch in "${unused_patches[@]}"; do
					echo -e "${category}/${package_name}${DL}${upatch}${DL}${main}" >> ${WORKDIR}/${SCRIPT_SHORT}-BUG-unused_patches/full.txt
				done
			else
				for upatch in "${unused_patches[@]}"; do
					echo -e "${category}/${package_name}${DL}${upatch}${DL}${main}"
				done
			fi
		fi

		$DEBUG && >&2 echo && >&2 echo

	fi
}

export -f main get_perm get_main_min
export PORTTREE WORKDIR SCRIPT_MODE DEBUG DL startdir SCRIPT_SHORT

${SCRIPT_MODE} && mkdir -p ${WORKDIR}/${SCRIPT_SHORT}-BUG-unused_patches/

# Dont use parallel if DEBUG is enabled
if ${DEBUG}; then
	find ./${level} -mindepth $MIND -maxdepth $MAXD \( \
		-path ./scripts/\* -o \
		-path ./profiles/\* -o \
		-path ./packages/\* -o \
		-path ./licenses/\* -o \
		-path ./distfiles/\* -o \
		-path ./metadata/\* -o \
		-path ./eclass/\* -o \
		-path ./.git/\* \) -prune -o -type d -print | while read -r line; do
		main ${line}
	done
else
	find ./${level} -mindepth $MIND -maxdepth $MAXD \( \
		-path ./scripts/\* -o \
		-path ./profiles/\* -o \
		-path ./packages/\* -o \
		-path ./licenses/\* -o \
		-path ./distfiles/\* -o \
		-path ./metadata/\* -o \
		-path ./eclass/\* -o \
		-path ./.git/\* \) -prune -o -type d -print | parallel main {}
fi

if ${SCRIPT_MODE}; then
	foldername="${SCRIPT_SHORT}-BUG-unused_patches"
	newpath="${WORKDIR}/${foldername}"

	gen_sort_main ${newpath}/full.txt 3 ${newpath} ${DL}
	gen_sort_pak ${newpath}/full.txt 1 ${newpath} ${DL}

	rm -rf ${SITEDIR}/checks/${foldername}
	cp -r ${newpath} ${SITEDIR}/checks/
	rm -rf ${WORKDIR}
fi
