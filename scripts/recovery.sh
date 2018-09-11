#!/bin/bash
#:       Title: recovery.sh - Recovers files from dump and add information about differences to log.
#:    Synopsis: recovery.sh CLIENT_NAME LOG_FILE
#:        Date: 2018-09-10
#:     Version: 0.9
#:      Author: Paweł Renc
#:     Options: -h - Print usage information
## Script metadata
scriptname=${0##*/}			# name that script is invoked with
usage_information="${scriptname} [-h] CLIENT_NAME LOG_FILE"
description="Recovers files from dump."
## File localizations
home_dir="/home/aide/aide"	# path to AIDE files
client_recovery="${home_dir}/clients/${client}/recovery"
## Shell additional options
shopt -s extglob 			# turn on extended globbing	
shopt -s nullglob 			# allow globs to return null string
## Function definitions
source ${home_dir}/scripts/info_functions
## Parse command-line options
while (( $# )); do
	case $1 in
	-h) 
		usage 
	;;
	*) 
		client="$1"
	    logfile="$2"
		break
	esac
done
## Script body
backup_command="${home_dir}/scripts/backup.sh ${client}"
files_to_change=$(awk 'BEGIN{FS=" ";ORS=" "}($0 ~ "^changed:"){print $2}' ${logfile} 2>/dev/null)
files_to_add=$(awk 'BEGIN{FS=" ";ORS=" "}($0 ~ "^added:"){print $2}' ${logfile} 2>/dev/null)
files_to_remove=$(awk 'BEGIN{FS=" ";ORS=" "}($0 ~ "^removed:"){print $2}' ${logfile} 2>/dev/null)
[[ ! -z ${files_to_change} ]] && backup_command+=" -c ${files_to_change}"
[[ ! -z ${files_to_add} ]] && backup_command+=" -a ${files_to_add}"
[[ ! -z ${files_to_remove} ]] && backup_command+=" -r ${files_to_remove}"
eval ${backup_command}
status="$?"
if (( status == 0 )); then
	ok "New files in recovery directory."
	${home_dir}/scripts/backup.sh ${client} -n -c ${files_to_change}
	status="$?"
	if (( status == 0 )); then
		for f in ${files_to_change}; do
			name="${f#/}"
			name="${name////@}"
			unset last
			for f ${client_recovery}/${name}.new.+([0-9]); do
				last="${f}"
			done
			[[ ! -f ${last} ]] && warrning "${name} has not been found in new dump." && continue
			old_recovery=(${client_recovery}/${name}.old.+([0-9]))
			new_recovery=(${client_recovery}/${name}.new.+([0-9]))
			old_ver=${old_recovery[-1]}
			new_ver=${new_recovery[-1]}
			f=${f////\\/}
			difference=$(diff ${old_ver} ${new_ver})
			diff_status="$?"
			difference=$(echo "${difference}" | sed '$!s/$/\\/')
			if (( diff_status == 1 )); then 
				sed "/^File: ${f}$/a ${difference}" "${logfile}" > /tmp/xxx
			elif (( diff_status == 2 )); then
				sed "/^File: ${f}$/a Some troubles were encountered while looking for differences.\n" "${logfile}" > /tmp/xxx
			else
				sed "/^File: ${f}$/a No differences were found. It means dump is corrupted.\n" "${logfile}" > /tmp/xxx
			fi
			mv /tmp/xxx "${logfile}"
		done
		for f in ${client_recovery}/${name}.new.+([0-9]); do
			rm -f "${f}"
		done
	else
		sed "1i Something went wrong during recovery\!\!\!\n\n" ${logfile} > /tmp/xxx && mv /tmp/xxx ${logfile}
	fi
else
	error "Something went wrong while extracting old versions from archive." 2
fi