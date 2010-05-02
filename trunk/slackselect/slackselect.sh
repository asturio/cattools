#!/bin/sh
#

DEBUG=0
if [ ${DEBUG} -eq 0 ]
then
    CACHE=/var/cache/slackselect
else
    CACHE=/var/tmp/slackselect-${USER}
fi
TMP=${CACHE}/tmp
DOWNLOAD=${CACHE}/download

NAME="SlackSelect"
VERSION=0.5
DIALOGO="--backtitle ${NAME}_${VERSION}" # --title Selection"
ALL_INSTALLED=${CACHE}/packages.all.installed
INST_SOURCE=${CACHE}/packages.all.source
DESCRIPTIONS=${CACHE}/packages.all.descriptions
AVAIL=${CACHE}/packages.avail
INSTALLED=${CACHE}/packages.installed
OBSOLET=${CACHE}/packages.obsolets
OT_VERSION=${CACHE}/packages.version
PACKAGES=${CACHE}/PACKAGES.TXT
RES="${TMP}/res.$$"
TLIST="${TMP}/tlist.$$"
NAVER="${TMP}/name-version.$$"
PAPRE="${TMP}/packages.present.$$"
WGET="/usr/bin/wget -c --retr-symlinks -nv -nc --timeout=120"
FTPSOURCE=${CACHE}/sources.ftp
CDROM="/media/cdrom"
CDROMDEV="/dev/cdrom"

export LC_COLLATE=C

###########################################
function gpl() {
    echo "slackselect Version: ${VERSION} - (c) Claudio Clemens"
    echo ""
    echo "slackselect comes with ABSOLUTELY NO WARRANTY; for details see the file"
    echo "COPYING.  This is free software, and you are welcome to redistribute it"
    echo "under certain conditions."
    echo ""
    echo "Continuing in 3 s."
    sleep 3
}


###########################################
function init() {
    ID=`/usr/bin/id | sed "s/^uid=\([0-9]*\)(.*/\1/"`
    if [ ${ID} -ne 0 ]
    then
	echo "WARNING: This program needs root to work properly."
    fi
    mkdir -p ${CACHE} 2> /dev/null
    mkdir -p ${TMP} 2> /dev/null
    mkdir -p ${DOWNLOAD} 2> /dev/null

}

function clear_downloads() {
    echo "Should I delete downloaded files?"
    read d
    case ${d} in
	[YyJj])
	    echo "Removing Download-Cache"
	    rm -f ${DOWNLOAD}/*.tgz
	;;
    esac
}

###########################################
function recompute_packages () {
    (
    # Merge sourcelists
    #echo "Merging source lists"
    for i in ${INST_SOURCE}-*
    do
	for j in ${INST_SOURCE}-*
	do
	    if [ "${i}" != "${j}" ]
	    then
		if [ -f "${i}" -a -f "${j}" ]
		then
		    if (diff "${i}" "${j}" > /dev/null)
		    then
			echo ${i} ${j} are the same.
			rm "${i}"
			inst_source=`basename ${INST_SOURCE}`
			ibase=`basename "${i}"`
			pcknme=`echo "${ibase}" | sed "s/${inst_source}-//"`
			rm ${PACKAGES}-${pcknme}
		    fi
		fi
	    fi
	done
    done
    echo "15"
    cat ${INST_SOURCE}-* | sort | uniq > ${INST_SOURCE}

    #echo Recomputing packages list
    #echo -n "Extracting installed package names and versions"
    sed "s/\(.*\)-\([^-]\+\)-[^-]\+-[^-]\+$/\1 \2/g" ${ALL_INSTALLED} > ${NAVER}
    echo "30"
    
    # Which are present?
    #echo -n "Listing present packages (same or other version)"
    sed 's/\(.*\) .*/^\1-[^-]\\+-[^-]\\+-[^-]\\+$/' ${NAVER} > ${NAVER}.1
    grep -f ${NAVER}.1 ${INST_SOURCE} | sort > ${PAPRE}
    echo "45"
    rm ${NAVER}.1

    # Which are identical?
    #echo -n "Creating list of identical INSTALLED packages"
    sed 's/\(.*\)/^\1/' ${ALL_INSTALLED} > ${PAPRE}.1
    grep -f ${PAPRE}.1 ${INST_SOURCE} | sort > ${INSTALLED}
    echo "60"

    # These packages are installed, but CD-Version differs from installed one
    #echo -n "Creating list of DIFFERENT packages"
    diff ${INSTALLED} ${PAPRE} | grep "^[<>]" | sed "s/^> //g" > ${OT_VERSION}
    echo "75"

    # These packages are not more available
    #echo -n "Creating list of OBSOLETE packages"
    for i in `cut -f 1 -d " " ${NAVER}`
    do
	if !(grep "^${i}-[^-]\+-[^-]\+-[^-]\+$" ${INST_SOURCE} > /dev/null)
	then 
	    grep "^${i}-[^-]\+-[^-]\+-[^-]\+$" ${ALL_INSTALLED}
	fi
    done > ${OBSOLET}
    echo "90"

    # And now the list of uninstalled packages
    #echo -n "Creating list of AVAILABLE packages"
    diff ${INST_SOURCE} ${PAPRE} | grep "^[<>]" | sed "s/^< //g" > ${AVAIL}
    echo "100"
    rm -f ${NAVER} ${PAPRE} ${PAPRE}.1
    ) | dialog ${DIALOGO} --gauge "Recomputing state cache" 6 40
}

###########################################
function res () {
    RESP=`cat ${RES}`
    rm -f ${RES}
}

###########################################
function update_lists () {
    dialog ${DIALOGO} --menu "Update list" 15 42 6 1 "Update installed list" 2 "Update/Add CD" 3 "Update/Add FTP" 4 "Remove a package list" 2> ${RES}
    res
    case ${RESP} in
	"1")
	    update_installed
	    update_lists
	    ;;
	"2")
	    read_cd
	    update_lists
	    ;;
	"3")
	    update_ftp
	    update_ftp_list
	    update_lists
	    ;;
	"4")
	    remove_lists
	    update_lists
	    ;;
    esac
}

###########################################
function splitftp () {
    zeile=`cat ${FTPSOURCE}`
    ftpurl=`echo ${zeile} | cut -f 1 -d ";"`
    ftpnick=`echo ${zeile} | cut -f 2 -d ";"`
}

###########################################
function update_ftp () {
    splitftp
    dialog ${DIALOGO} --form "Enter the ftp configuration" 12 70 5 Server 1 1 "${ftpurl}" 2 1 128 128 Nickname 4 1 "${ftpnick}" 5 1 32 32 2> ${RES}
    # don't call res here
    (	read ftpurl; 
	read ftpnick; 
	if [ "${ftpurl}" -a "${ftpnick}" ]
	then
	    echo "${ftpurl};${ftpnick}" > ${FTPSOURCE}
	fi
    ) < ${RES}
    rm -f ${RES}
}

###########################################
function remove_lists () {
    NAMES=""
    for i in ${INST_SOURCE}-*
    do
	inst_source=`basename ${INST_SOURCE}`
	ibase=`basename ${i}`
	name=`echo ${ibase} | sed "s/${inst_source}-\(.*\)$/\1/g"`
	NAMES="${NAMES} ${name} ${name} off"
    done
    dialog ${DIALOGO} --checklist "Remove list" 17 60 10 ${NAMES} 2> ${RES} 
    res
    if [ "${RESP}" ] 
    then
	RESP=`echo ${RESP} | tr -d \"` # remove quotes
	for i in ${RESP}
	do
	    if [ ${DEBUG} -eq 0 ]
	    then
		rm ${INST_SOURCE}-${i} ${PACKAGES}-${i}
	    else
		echo "DEBUG: rm ${INST_SOURCE}-${i} ${PACKAGES}-${i}"
	    fi
	done
	[ ${DEBUG} -ne 0 ] && sleep 3
	sleep 3
    fi
}

###########################################
function install_p () {
    sed "s/^\(.*\)-\([^-]\+\)\(-[^-]\+-[^-]\+\)$/\1-\2\3 \2 off/g" ${AVAIL} | sort | uniq > ${TLIST}
    if [ -s ${TLIST} ]
    then
	dialog ${DIALOGO} --checklist "Install packages" 20 60 13 `cat ${TLIST}` 2> ${RES} 
	rm -f ${TLIST}
	res
	if [ "${RESP}" ]
	then
	    RESP=`echo ${RESP} | tr -d \"`
	    dialog ${DIALOGO} --msgbox "I will install: ${RESP}" 0 0
	    # Install the latest release per default
	    for i in ${RESP}
	    do
		upgrade_install ${i} install
	    done
	    clear_downloads
	    update_installed
	    recompute_packages
	fi
    else
	dialog ${DIALOGO} --msgbox "No packages in this category found." 5 50
    fi
}

###########################################
function remove_p () {
    sed "s/^\(.*-[^-]\+-[^-]\+-[^-]\+\)$/\1 obsolete off/g" ${OBSOLET} | sort > ${TLIST} 
    grep -v -f ${OBSOLET} ${ALL_INSTALLED} | \
    sed "s/^\(.*\)-\([^-]\+\)\(-[^-]\+-[^-]\+\)$/\1-\2\3 \2 off/g" | sort >> ${TLIST}
    if [ -s ${TLIST} ]
    then
	dialog ${DIALOGO} --checklist "Remove packages" 20 60 13 `cat ${TLIST}` 2> ${RES} 
	rm -f ${TLIST}
	res
	if [ "${RESP}" ]
	then
	    RESP=`echo ${RESP} | tr -d \"`
	    dialog ${DIALOGO} --msgbox "I will remove: ${RESP}" 0 0
	    for i in ${RESP}
	    do
		i=`echo ${i} | sed "s/^\"\(.*\)-[^-]\+\"/\1/"`
		if [ ${DEBUG} -eq 0 ]
		then
		    /sbin/removepkg ${i}
		else
		    echo "DEBUG: /sbin/removepkg ${i}"
		    sleep 3
		fi
	    done
	    update_installed
	    recompute_packages
	fi
    else
	dialog ${DIALOGO} --msgbox "No packages in this category found." 5 50
    fi
}

###########################################
function update_installed () {
    if [ ${DEBUG} -eq 0 ] 
    then
	(cd /var/log/packages/; \ls -1) | sort > ${ALL_INSTALLED}
    else 
	echo "DEBUG: (cd /var/log/packages/; \ls -1) | sort > ${ALL_INSTALLED}"
	sleep 3
    fi
}

###########################################
function update_p () {
    echo "Preparing Update-List"
    PACKS=`get_inst_names`
    rm -f ${TLIST}
    for i in ${PACKS}
    do
	# Get version of the installed package
	VER=`version_of "${i}"`
	for j in `grep "^${i}-[^-]\+-[^-]\+-[^-]\+$" ${OT_VERSION}`
	do
	    # Get version of the available package
	    VER2=`echo ${j} | sed "s/^.*-\([^-]\+\)-[^-]\+-\([^-]\+\)$/\1-\2/"`
	    echo "version_checker '${VER2}' '${VER}'"
	    UPDOWN=`version_checker "${VER2}" "${VER}"`
	    echo "${j} ${UPDOWN}:${VER} off" >> ${TLIST}
	done
    done
    if [ -s ${TLIST} ]
    then
	dialog ${DIALOGO} --checklist "Upgrade packages" 20 60 13 `cat ${TLIST}` 2> ${RES} 
	res
	if [ "${RESP}" ]
	then
	    RESP=`echo ${RESP} | tr -d \"`
	    dialog ${DIALOGO} --msgbox "I will update: ${RESP}" 0 0
	    for i in ${RESP}
	    do
		upgrade_install ${i} upgrade
	    done
	    clear_downloads
	    update_installed
	    recompute_packages
	fi
	rm -f ${TLIST}
    else
	dialog ${DIALOGO} --msgbox "No upgradable packages found." 5 50
    fi
}

###########################################
function info_p () {
    # Update descriptions
    if [ ${INST_SOURCE} -nt ${DESCRIPTIONS} -o ${ALL_INSTALLED} -nt ${DESCRIPTIONS} ]
    then
	ilines=`sed "s/^\(.*\)-[^-]\+-[^-]\+-[^-]\+$/\1/" ${INST_SOURCE} | uniq | wc -l`
	pcent=0
	pcount=0
	rm -f ${DESCRIPTIONS}
	for pname in `sed "s/^\(.*\)-[^-]\+-[^-]\+-[^-]\+$/\1/" ${INST_SOURCE} | uniq`
	do
	    let pcount=pcount+1
	    let pcent=100*${pcount}/${ilines}
	    echo ${pcent}
	    VER=`version_of ${pname}`
	    # Read info from only one file
	    sdesc=""
	    for i in ${PACKAGES}-*
	    do
		sdesc=`grep "^${pname}:" ${i} | head -1 | cut -f2 -d:`
		[ "${sdesc}" ] || sdesc=`grep "^${pname}-[^-]\+-[^-]\+-[^-]\+:" ${i} | head -1 | cut -f2 -d:`
		[ "${sdesc}" ] && break
	    done
	    sdesc=`echo ${sdesc} | sed "s/[^(]\+(\([^)]\+\)).*/\1/" | tr "\"" "'"`
	    if [ ${VER} ]
	    then
		echo "${pname} \"i:${sdesc}\"" >> ${DESCRIPTIONS}
	    else
		echo "${pname} \"a:${sdesc}\"" >> ${DESCRIPTIONS}
	    fi
	done | dialog ${DIALOGO} --gauge "Regenerating Description cache." 6 40
    fi
    if [ -s ${DESCRIPTIONS} ]
    then
	while (true)
	do
	    # Select letter
	    letters=""
	    for i in `cut -c1 ${DESCRIPTIONS} | sort | uniq`
	    do
		letters="${letters} ${i} \"Begining with ${i}\"" 
	    done
	    COMM=`tempfile`
	    echo "dialog ${DIALOGO} --menu 'Select begining letter:' 15 50 8 ${letters} 2> ${RES}" > ${COMM}
	    bash ${COMM}
	    rm ${COMM}
	    res
	    if [ "${RESP}" ]
	    then
		items=`grep "^${RESP}" ${DESCRIPTIONS}`
		items=`echo ${items}` # Strip newlines
		COMM=`tempfile`
		echo "dialog ${DIALOGO} --menu 'Package Information' 19 70 12 ${items} 2> ${RES}" > ${COMM}
		bash ${COMM}
		rm ${COMM}
		res
		if [ "${RESP}" ]
		then
		    RESP=`echo ${RESP} | tr -d \"`
		    DESC=""
		    for i in ${PACKAGES}-*
		    do
			DESC=`grep "^${RESP}:" ${i} | cut -f2 -d:`
			# Some packages have a bad name.
			[ "${DESC}" ] || DESC=`grep "^${RESP}-[^-]\+-[^-]\+-[^-]\+:" ${i} | cut -f2 -d:`
			[ "${DESC}" ] && break
		    done
		    DESC=`echo ${DESC} | tr "\"" "'"` # Strip spaces
		    dialog ${DIALOGO} --msgbox "Information on: ${RESP}\n ${DESC}" 0 0
		    # Display Information
		fi
	    else
		break
	    fi
	done
    else
	dialog ${DIALOGO} --msgbox "No packages in this category found." 5 50
    fi
}

###########################################
function upgrade_install () {
    echo "Trying to ${2} ${1}"
    # cdrom comes allways before FTP
    source=`grep -l "${1}.tgz" ${PACKAGES}-* | head -1`
    fromcd=0
    if (echo ${source} | grep ${PACKAGES}-cdrom- > /dev/null)
    then
	fromcd=1
    fi
    site=`echo ${source} | cut -f3- -d "-"`
    urlnick=`echo ${site} | sed "s/\(^.*\)-[^-]*$/\1/"`
    subdir=`grep -A 1 "PACKAGE NAME: *${1}.tgz" ${source} | tail -1 | cut -f 2- -d.`
    if [ ${fromcd} -eq 1 ]
    then
	targeturl=${CDROM}${subdir}/${1}.tgz
	echo "Install from ${targeturl}"
	insert_cd_with ${targeturl} ${site}
	if [ ${DEBUG} -eq 0 ]
	then 
	    mount ${CDROM}
	    /sbin/${2}pkg ${targeturl}
	    umount ${CDROM}
	else
	    echo "DEBUG mount ${CDROM}"
	    echo "DEBUG /sbin/${2}pkg ${targeturl}"
	    echo "DEBUG umount ${CDROM}"
	    sleep 3
	fi
    else
	url=`grep ";${urlnick}$" ${FTPSOURCE} | cut -f 1 -d ";"`
	targeturl=${url}${subdir}/${1}.tgz
	echo "To download ${targeturl}"
	# Install from FTP 
	if [ ${DEBUG} -eq 0 ]
	then 
	    ${WGET} -O ${DOWNLOAD}/${1}.tgz ${targeturl} && /sbin/${2}pkg ${DOWNLOAD}/${1}.tgz || echo ${1} >> /var/tmp/error.${2}
	else
	    echo "DEBUG: ${WGET} -O ${DOWNLOAD}/${1}.tgz ${targeturl} && /sbin/${2}pkg ${DOWNLOAD}/${1}.tgz"
	    sleep 3
	fi
    fi
}

###########################################
function insert_cd_with () {
    mount ${CDROM}
    while [ ! -f ${1} ]
    do
	umount ${CDROM}
	echo "Please insert CD `echo ${2} | cut -d- -f1`"
	read a
	mount ${CDROM}
    done
    umount ${CDROM}
}


###########################################
function version_of () { 
# XXX: There is a problem if you have more than one version of the same
# package, can happen with kernel-source for example
    grep "^${1}-[^-]\+-[^-]\+-[^-]\+$" ${ALL_INSTALLED} | sed "s/.*-\([^-]\+\)-[^-]\+-\([^-]\+\)$/\1-\2/g"
}

###########################################
function get_inst_names () {
    sed "s/^\(.*\)-[^-]\+-[^-]\+-[^-]\+$/\1/g" ${OT_VERSION} | sort | uniq
}

###########################################
function cd_name () {
    CDVOL=`(dd if=${CDROMDEV} bs=512 skip=64 count=1 | dd bs=1 skip=40 count=32) 2> /dev/null`
    CDVOL=`echo ${CDVOL} | tr " " "_"`
    echo ${CDVOL}
}

###########################################
function read_cd () {
    dialog ${DIALOGO} --msgbox "Please insert a CD in the CD-Rom Drive." 5 50
    mount ${CDROM}
    cd_name
    RESP=${CDVOL}
    dialog ${DIALOGO} --inputbox "Edit CD name" 8 40 ${CDVOL} 2> ${RES} && res
    rm -f ${RES}
    for dir in "" slackware testing extra
    do
	if [ -f ${CDROM}/${dir}/PACKAGES.TXT ]
	then
	    cp ${CDROM}/${dir}/PACKAGES.TXT ${PACKAGES}-cdrom-${RESP}-${dir}
	    grep "PACKAGE NAME" ${PACKAGES}-cdrom-${RESP}-${dir} | cut -f 2 -d: | \
	    sed -e "s/^ *//" -e "s/\.tgz$//" | sort > ${INST_SOURCE}-cdrom-${RESP}-${dir}
	fi
    done
    umount ${CDROM}
}

###########################################
function main_p () {
    dialog ${DIALOGO} --menu "Select the action:" 15 42 6 1 "Manage sourcelists" 2 "Install available packages" 3 "Remove installed packages" 4 "Update installed packages" 5 "Package Descriptions" 6 "Quit" 2> ${RES}

    res
    case ${RESP} in
	"1")
	    update_lists
	    recompute_packages
	    main_p
	    ;;
	"2")
	    install_p
	    main_p
	    ;;
	"3")
	    remove_p
	    main_p
	    ;;
	"4")
	    update_p
	    main_p
	    ;;
	"5")
	    info_p
	    main_p
	    ;;
	"6")
	    exit 0
	    ;;
    esac
}

###########################################
function update_ftp_list() {
    echo "Updating FTP-List"
    for ftp_site in `cat ${FTPSOURCE}`
    do
	splitftp
	for i in "" slackware extra testing patches pasture
	do 
	    site=${ftpurl}/${i}/`basename ${PACKAGES}`
	    filename=${PACKAGES}-ftp-${ftpnick}-${i}
	    ${WGET} -O ${filename} ${site}
	    grep "PACKAGE NAME" ${filename}  | cut -f 2 -d: | \
		sed -e "s/^ *//" -e "s/\.tgz$//" > ${INST_SOURCE}-ftp-${ftpnick}-${i}
	done
    done
}

###########################################
normalize_version() {
    local ver=${1}
    while ( echo ${ver} | grep [^0123456789\.] > /dev/null )
    do
	char=`echo ${ver} | sed 's/.*\([^0123456789.]\).*/\1/'`
	char_dec=`echo -n "${char}" | od -b | head -1 | awk {'print $2'}`
	ver=`echo ${ver} | sed "s/${char}/.${char_dec}./g"`
    done    
    ver=`echo ${ver} | sed -e 's/\.\./.0/g'`
    echo ${ver}
} 

###########################################
version_checker() {
    local ver1=`normalize_version ${1}`
    local ver2=`normalize_version ${2}`
    do_version_check "${ver1}" "${ver2}"
    res=$?
    case "${res}" in
	9)  echo "-"
	    ;;
	10) echo "="
	    ;;
	11) echo "+"
    esac
}

###########################################
do_version_check() {
    [ "${1}" == "${2}" ] && return 10
    ver1front=`echo ${1} | cut -d "." -f -1`
    ver1back=`echo ${1} | cut -d "." -f 2-`
    ver2front=`echo ${2} | cut -d "." -f -1`
    ver2back=`echo ${2} | cut -d "." -f 2-`
    if [ "${ver1front}" != "${1}" -o "${ver2front}" != "${2}" ]; then
	[ "${ver1front}" -gt "${ver2front}" ] && return 11
	[ "${ver1front}" -lt "${ver2front}" ] && return 9

	[ "${ver1front}" == "${1}" -o -z "${ver1back}" ] && ver1back=0
	[ "${ver2front}" == "${2}" -o -z "${ver2back}" ] && ver2back=0
	do_version_check "${ver1back}" "${ver2back}"
	return $?
    else
	[ "${1}" -gt "${2}" ] && return 11 || return 9
    fi
}

###########################################
#  MAIN Program here                      #
###########################################

gpl
init
main_p

