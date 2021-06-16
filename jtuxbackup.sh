#!/bin/bash
#
#  Author: James Sakala
#  Purpose : Backup a mysql/mariadb database backup LDAP/PostgresSQL/DATA
#  Date: 22 July, 2018
#  Updated : 31 07 2018 to include rsync
#  Updated : 03 08 2018 to  modulerise improve cleanup
#            rsync and allow providing config file to
#            overide defaults set up in this file.
#  Updated : 06 08 2018 to ractify bug in backup cleaning
#  Updated : 07 08 2018 to ractify bug in synching to server paths
#          : Added ability to touch log file if not exist
#  Updated : 09 01 2019 to Added LDAP Backup Factionality
#  Updated : 09 02 2019 to Added Posgress Backup Factionality
#  Updated : 20 03 2019 to Automate Creation of Local Backup and NFS Mount point Dirs
#            If they dont exist and Killed Bug for Provided config (Raised "if" upwards :-D 
#			 Added,Self Installation of self and Config Files and MAIL Settings.
#			 Added  Support for Installation of Default config file and its usage if it exists as last resort if non is provided
#			 Added, Data Backup Compression Support;
#			 Made Logging Moduler and Added Buffer Support to it to ease email report notification
#  Updated : 21 03 2019 to Add granuler SQL,PGres , Data and LDAP Local and Remote Backup Cleanup in same "BASE" Directory.
#  Updated : 27 03 2019 to To Kill The Cleanup Bug and Add Separate Granular Cleanup Settings for LOCAL and REMOTE.
#  Updated : 20 06 2019 to To Kill Irritating Postgress backup bug.
#  Updated : 25 06 2020 Added Astrisc PBX Data Backup.
#  Updated : 25 07 2020 Added Light Backup Mode (Over SSH and RSYNC).
#  Updated : 27 07 2020 Added Cleanup to Light Backup Mode (Over SSH and RSYNC).
#  Version : 00.00.016
#  WARNING : Do Not Modify anything in here. simply edit /etc/jtuxbackup.sh/jtuxbackup.sh.conf instead
#  WARNING : ONLY!! MODIFY VARIABLES WITH COMMENTS ON TOP
#            LEAVE THE REST AS IS. YOU HAVE BEEN WARNED!!
############################################################################################################################
#
#--------------------EMAIL NOTIFICATION----------------------------#
##If Yes, Ensure you installed mutt,msmtp and configs in to /etc/{msmtprc,mailrc}##
##Send Notification?  0=No,1=Yes##
SEND_NOTIFICATION=0
##To what mail address should BCC notifications be sent?##
BCC_EMAIL_ADDRESS="admin@example.com"
##To what mail address should notifications be sent?##
EMAIL_ADDRESS="admin2@example.com"
##Subject of email notification?##
EMAIL_SUBJECT_SUFFIX="JBackup Summery Notice"
#--------------------BACKUP SETTING--------------------------------#
#1 = OVER SSH & RSYNC , 2 = OVER NFS/SAMBA #
BACKUP_MODE_FLAG=1
#1 = Network Only , 2 = Local Only , 3 = Both (network and Local #
BACKUP_TO_FLAG=3
#--------------------MOUNT POINTS ---------------------------------#
##folder to save local backups. without trailing slash!!##
LOCAL_BACKUP_DIR="/backup"
##what folder to save systems backups in local and remote NFS directories##
LOCAL_SYSTEM_NAME_PREFIX="MyWebsite"
##FQDN or IP Address of NFS backup Server?##
NFS_SERVER_ADDRESS="192.168.56.100"
##NFS Share path to save backups on NFS Backup Server ?##
NFS_SERVER_BACKUP_DIR="/data/NFS"
##path where to mount NFS Backup share on local system?##
NFS_LOCAL_MOUNT_POINT="/media/nfs/0"
#--------------------LIGHT RESERVED STUFF--------------------------#
SSHCMD=$(which ssh)
##SSHOPTS=" -4 -p 22 -o StrictHostKeyChecking=no -o Compression=no -o Cipher=arcfour -i /etc/jtuxbackup.sh/ssh-keys/jtuxbackup-light-sshkey"
SSHOPTS=" -4 -p 222 -o StrictHostKeyChecking=no -o Compression=no -o Cipher=arcfour -i /etc/jtuxbackup.sh/ssh-keys/jtuxbackup-light-sshkey"
SSHUSER_SERVER="yoda@192.168.56.100"
SSHDATA_BASE_PATH="/data/jtuxbackups/MyWebSite"
SSHPASSCMD=$(which sshpass)
SSHPASSOPTS=" -p "YourSSHPasswordHere""
##SSHPASSOPTS=" -p "yoda""
#--------------------RESERVED STUFF--------------------------------#
RSYNCCMD=$(which  rsync)
##RSYNCOPTS=" -chazP -e"
RSYNCOPTS=" -cazPq --delete -e"
#--------------------RESERVED STUFF--------------------------------#
BACKUP_FILE_NAME_DATE_SUFFIX=`date +%d%B%Y%H%M%S_%s`
#--------------------RESERVED STUFF--------------------------------#
LOG_FILE_NAME_SUFFIX=`date +%B%Y`
#--------------------RESERVED STUFF--------------------------------#
#MONTH_YEAR_PREFIX=`date +%d%B%Y`
MONTH_YEAR_PREFIX=`date +%B%Y`
#--------------------RESERVED STUFF--------------------------------#
LOCAL_HOSTNAME="`hostname -f`"
#--------------------RESERVED STUFF--------------------------------#
LOCAL_IP_ADDRESS="`hostname -I`"
#--------------------RESERVED STUFF--------------------------------#
NFS_SERVER_SHARE_PATH="${NFS_SERVER_ADDRESS}:$NFS_SERVER_BACKUP_DIR"
#--------------------RESERVED STUFF--------------------------------#
LOCAL_LOG_FILE="${LOCAL_BACKUP_DIR}/${LOCAL_SYSTEM_NAME_PREFIX}/${MONTH_YEAR_PREFIX}.log"
#--------------------RESERVED STUFF--------------------------------#
#REQUIRED_COMMAND_TOOLS_LIST='echo basename cut tr openssl find bzip2 gzip cp rsync mysql mysqldump pg_dumpall'
REQUIRED_COMMAND_TOOLS_LIST='echo basename cut tr openssl find bzip2 gzip cp rsync'
#--------------------RESERVED STUFF--------------------------------#
###what program should we use to do compression? bzip2 , gzip , ....
COMPRESSION_COMMAND=bzip2
###Compression Command Options When Compressing Directly, EG "-z" for bzip2###
COMPRESSION_COMMAND_OPTIONS_COMPRESS="-z"
####what file backup extention to use for compressed files ? bz2 , gz , ...##
BACKUP_FILE_EXTENSION=bz2
#--------------------MYSQL------------------------------#
##Back Up SQL ?  0=No,1=Yes##
BACKUPSQL=0
## BACKUP TAG FOR MYSQL ###
MYSQL_BACKUP_TAG='sql'
## HOW MANY REMOTE DAYS/COUNT FOR MYSQL TO KEEP? ####
MYSQL_REMOTE_BACKUP_COUNT=1
## IS THE ABOVE 2, DAYS or COUNT ? ( 0 = DAYS, 1 = COUNT ## 
MYSQL_REMOTE_BACKUP_DAYS_OR_COUNT=1
## HOW MANY LOCAL DAYS/COUNT FOR MYSQL TO KEEP? ####
MYSQL_LOCAL_BACKUP_COUNT=1
## IS THE ABOVE 2, DAYS or COUNT ? ( 0 = DAYS, 1 = COUNT ## 
MYSQL_LOCAL_BACKUP_DAYS_OR_COUNT=1
##MariaDB/MySQL username allowed to do SQL Backups ?##
DB_USER="DatabaseBackupUserName"
##MariaDB/MySQL password of username allowed to do SQL Backups ?##
DB_PASSWORD="DatabaseBackupUserPassword"
##DO Not TOUCH##
MYSQLDUMPCMD=$(which mysqldump)
MYSQLDUMP_OPTS=" --force --opt --user=${DB_USER} --password=${DB_PASSWORD}  --all-databases --lock-tables --dump-date --events --routines --log-error="/tmp/mysqldump.err.log""
#------MYSQL HELP/HINT/TIP-----------------#
#EXCUTE THE FOLLOWING TO YOU MYSQL/MariaDB##
#CREATE USER 'jdbbackupusr'@'%' IDENTIFIED BY 'ZmRmNGJmYWMxZmI';
#GRANT ALL ON *.*  TO 'jdbbackupusr'@'%';
#FLUSH PRIVILEGES;
#EXIT;
#--------------------PGRESS------------------------------#
##Back Up PostGress ?  0=No,1=Yes##
BACKUPPOSTGRESS=0
## BACKUP TAG FOR PGRESS ###
PGRESS_BACKUP_TAG='pgres'
## HOW MANY REMOTE DAYS/COUNT FOR PGRESS TO KEEP? ####
PGRESS_REMOTE_BACKUP_COUNT=35
## IS THE ABOVE, DAYS or COUNT ? ( 0 = DAYS, 1 = COUNT ## 
PGRESS_REMOTE_BACKUP_DAYS_OR_COUNT=1
## HOW MANY LOCAL DAYS/COUNT FOR PGRESS TO KEEP? ####
PGRESS_LOCAL_BACKUP_COUNT=1
## IS THE ABOVE, DAYS or COUNT ? ( 0 = DAYS, 1 = COUNT ## 
PGRESS_LOCAL_BACKUP_DAYS_OR_COUNT=1
#----------------------LDAP------------------------------#
##Back Up LDAP ?  0=No,1=Yes##
BACKUPLDAP=0
## BACKUP TAG FOR LDAP ###
LDAP_BACKUP_TAG='ldap'
## HOW MANY REMOTE DAYS/COUNT FOR LDAP TO KEEP? ####
LDAP_REMOTE_BACKUP_COUNT=1
## IS THE ABOVE, DAYS or COUNT ? ( 0 = DAYS, 1 = COUNT ## 
LDAP_REMOTE_BACKUP_DAYS_OR_COUNT=1
## HOW MANY LOCAL DAYS/COUNT FOR LDAP TO KEEP? ####
LDAP_LOCAL_BACKUP_COUNT=1
## IS THE ABOVE, DAYS or COUNT ? ( 0 = DAYS, 1 = COUNT ## 
LDAP_LOCAL_BACKUP_DAYS_OR_COUNT=1
###############LDAP ADMIN CREDENTIALS HERE. EG  [cn=admin,dc=example,dc=com] ##########
LDAP_ADMIN_PATH="cn=admin,dc=example,dc=com"
###############LDAP BASE CREDENTIALS HERE. EG  [dc=example,dc=com] ##########
LDAP_BASEPATH="dc=example,dc=com"
###############LDAP BASE CREDENTIALS HERE. EG  [dc=example,dc=com] ##########
LDAP_ADMIN_PWD="LDAPPasswordHere"
#----------------------ASTRIX PBX------------------------------#
##Back Up DATA ?  0=No,1=Yes##
BACKUPPBX=1
##PBX_USERNAME HERE###
PBX_USERNAME="phonesystem"
## BACKUP TAG FOR DATA ###
PBX_BACKUP_TAG='pbxdata'
## HOW MANY REMOTE DAYS/COUNT FOR DATA TO KEEP? ####
PBX_REMOTE_BACKUP_COUNT=35
## IS THE ABOVE, DAYS or COUNT ? ( 0 = DAYS, 1 = COUNT ## 
PBX_REMOTE_BACKUP_DAYS_OR_COUNT=1
## HOW MANY LOCAL DAYS/COUNT FOR DATA TO KEEP? ####
PBX_LOCAL_BACKUP_COUNT=2
## IS THE ABOVE, DAYS or COUNT ? ( 0 = DAYS, 1 = COUNT ## 
PBX_LOCAL_BACKUP_DAYS_OR_COUNT=1
#--------------------DATA------------------------------#
##Back Up DATA ?  0=No,1=Yes##
BACKUPDATA=1
## BACKUP TAG FOR DATA ###
DATA_BACKUP_TAG='data'
## HOW MANY REMOTE DAYS/COUNT FOR DATA TO KEEP? ####
DATA_REMOTE_BACKUP_COUNT=35
## IS THE ABOVE, DAYS or COUNT ? ( 0 = DAYS, 1 = COUNT ## 
DATA_REMOTE_BACKUP_DAYS_OR_COUNT=1
## HOW MANY LOCAL DAYS/COUNT FOR DATA TO KEEP? ####
DATA_LOCAL_BACKUP_COUNT=2
## IS THE ABOVE, DAYS or COUNT ? ( 0 = DAYS, 1 = COUNT ## 
DATA_LOCAL_BACKUP_DAYS_OR_COUNT=1
#--------------------RSYNC------------------------------#
##Sync Data ?  0=No,1=Yes##
SYNCHDATA=0
###Rsync folder to in backup folder to store synched files/directories###
RSYNCHSUFFIX='RSYNC'
#--------------------DATA PATHS-----------------------#
LIST_OF_PATHS_TO_BACKUP="
/etc
/usr/bin/jtuxbackup.sh
/var/spool/cron
/var/www/html
"
#--------------------RSYNC PATHS----------------------#
LIST_OF_PATHS_TO_SYNC="
/etc/ssh
"
#--------------------RESERVED STUFF--------------------------------#
MESSAGE_2_SEND=" "
BACKUP_FILE_DELIMETER='_'
UNIQUE_FIELD_NUMBER_INBACKUP_FILE=3
MYSQL_BACKUP_FILE_NAME="${LOCAL_HOSTNAME}${BACKUP_FILE_DELIMETER}${BACKUP_FILE_NAME_DATE_SUFFIX}.${MYSQL_BACKUP_TAG}.${BACKUP_FILE_EXTENSION}"
DATA_BACKUP_FILE_NAME="${LOCAL_HOSTNAME}${BACKUP_FILE_DELIMETER}${BACKUP_FILE_NAME_DATE_SUFFIX}.${DATA_BACKUP_TAG}.tar"
LDAP_BACKUP_FILE_NAME="${LOCAL_HOSTNAME}${BACKUP_FILE_DELIMETER}${BACKUP_FILE_NAME_DATE_SUFFIX}.${LDAP_BACKUP_TAG}.${BACKUP_FILE_EXTENSION}"
PGRESS_BACKUP_FILE_NAME="${LOCAL_HOSTNAME}${BACKUP_FILE_DELIMETER}${BACKUP_FILE_NAME_DATE_SUFFIX}.${PGRESS_BACKUP_TAG}.${BACKUP_FILE_EXTENSION}"
PBX_BACKUP_FILE_NAME="${LOCAL_HOSTNAME}${BACKUP_FILE_DELIMETER}${BACKUP_FILE_NAME_DATE_SUFFIX}.${PBX_BACKUP_TAG}.zip"
BACKUP_LOGFILE_NAME="${LOG_FILE_NAME_SUFFIX}.log"
MYMOUNTEDFLAG=0
SCRIPT_NAME=`basename $0`
SCRIPT_DIR=`dirname $0`
LOG_BUFFER_DATE=`date +%s`
LOG_BUFFER="/tmp/${LOG_BUFFER_DATE}.temp.log"

##############################################SANDBOX###########################################################

if [ $EUID -ne 0 ]; then 
    echo '**Please Run This Script as the root user!'
    echo '**Exiting.....BYE!'
    exit 0
fi

if [ ! -d "${LOCAL_BACKUP_DIR}/${LOCAL_SYSTEM_NAME_PREFIX}/" ];then
	mkdir -p "${LOCAL_BACKUP_DIR}/${LOCAL_SYSTEM_NAME_PREFIX}/"
	if [ ! -e "$LOCAL_LOG_FILE" ];then
		touch "$LOCAL_LOG_FILE" 2>/dev/null
		echo "Creating backup directory  .................[INFO]"
		echo "Creating local logfile  ..................[INFO]" 
	fi
fi

log_it(){
	# 1 = LOGFILE; 2 = LOG BUFFER ; 3 = Message; 4 = New Line ? ( 1 = Yes, 0 = No); 5 = TimeStamp ? ( 1 = Yes , 0 = No)
	if [ ! -e "$1" ];then
		touch "$1" 2>/dev/null
	fi

	if [ ! -e "$2" ];then
		touch "$2" 2>/dev/null
	fi
	
	if [ $5 -eq 1 ];then
		ZE_TIME_STAMP="$(date "+%d-%m-%Y_%H:%M:%S:%s")"
		ZE_TIME_STAMP="[${ZE_TIME_STAMP}] "
	else
		ZE_TIME_STAMP=""
	fi
	
    if [ $4 -eq 1 ];then
        echo -n "$ZE_TIME_STAMP$3" >> $1
        echo -n "$ZE_TIME_STAMP$3" >> $2
    else
        echo "$ZE_TIME_STAMP$3" >> $1
        echo "$ZE_TIME_STAMP$3" >> $2
    fi
}

logstart(){
	zedate=`date "+%d %B %Y - %R.%S.%s"`
	log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" '---------------------------[BEGIN]----------------------' 0 1
	log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "---------------${zedate}---------------" 0 1
}

logend(){
	zedate=`date "+%d %B %Y - %R.%S.%s"`
	log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "---------------${zedate}---------------" 0 1
	log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" '---------------------------[END]------------------------' 0 1
}

#############START LOGGING############
logstart
if [ $# -eq 2 ];then
	log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Custom Config : \"$2\" Provided  ...............[INFO]" 0 1
	if [ -e "$2" ];then
		log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Custom Config : \"$2\" Provided  ............[INFO]" 0 1
		##Include Custom Config File
		.  "$2"
	else
		log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Custom Config : \"$2\" NOT FOUND  ..............[WARN]" 0 1
		if [[ -f "/etc/$SCRIPT_NAME/${SCRIPT_NAME}.conf" ]];then
			log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Default Config : \"/etc/$SCRIPT_NAME/${SCRIPT_NAME}.conf\" Found  ...............[INFO]" 0 1
			.  "/etc/$SCRIPT_NAME/${SCRIPT_NAME}.conf"
		else
			log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER"  "Default Config : \"/etc/$SCRIPT_NAME/${SCRIPT_NAME}.conf\" NOT Found  ..................[INFO]" 0 1
		fi
	fi
else
	if [[ -f "/etc/$SCRIPT_NAME/${SCRIPT_NAME}.conf" ]];then
		log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Default Config : \"/etc/$SCRIPT_NAME/${SCRIPT_NAME}.conf\" Found  ................[INFO]" 0 1
		.  "/etc/$SCRIPT_NAME/${SCRIPT_NAME}.conf"
	else
		log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER"  "Default Config : \"/etc/$SCRIPT_NAME/${SCRIPT_NAME}.conf\" NOT Found  ...................[INFO]" 0 1
	fi
fi


if [ ! -d "${LOCAL_BACKUP_DIR}/${LOCAL_SYSTEM_NAME_PREFIX}/" ];then
	mkdir -p "${LOCAL_BACKUP_DIR}/${LOCAL_SYSTEM_NAME_PREFIX}/"
	if [ ! -e "$LOCAL_LOG_FILE" ];then
		touch "$LOCAL_LOG_FILE"
		log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Creating backup directory  .................[INFO]" 0 1
		log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Creating local logfile  ..................[INFO]" 0 1
	fi
fi

precommands() {
	log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Running Precommands  ..............................[INFO]" 0 1
	########ADD COMMANDS TO RUN BEFORE BACKUP HERE########
	#echo hello >> /dev/null
	##ps auxww | awk '{print $1" "$2}' | grep zimbra | kill -9 `awk '{print $2}'`
}

postcommands() {
	log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Running Postcommands  .............[INFO]" 0 1
	########ADD COMMANDS TO RUN AFTER BACKUP HERE########
	#echo hello >> /dev/null
}


checkrequiredcommands() {
    for i in $REQUIRED_COMMAND_TOOLS_LIST
    do
        which $i  1> /dev/null 2> /dev/null 
        if [ $? != 0 ];then
            log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "***Please Install $i and Try again ...........[Exiting]" 0 1
            log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" '***BYE! :-(' 0 1
            exit 0
        fi
    done
}

checkifrootisrunningscript() {
   	if [ $EUID -ne 0 ]; then 
        log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" '**Please Run This Script as the root user!'  0 1
        log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" '**Exiting.....BYE!' 0 1
        exit 0
    fi
}

dobackup(){
	ZECONTINUEFLAG=1
	if [ ! -d "$1/$LOCAL_SYSTEM_NAME_PREFIX" ];then
  		mkdir -p "$1/$LOCAL_SYSTEM_NAME_PREFIX" 1> /dev/null 2> /dev/null
  		if [ $? -eq 0 ];then
		    log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "\"$1/$LOCAL_SYSTEM_NAME_PREFIX\" Doesnt exist. Creating it [OK]" 0 1
		    ZECONTINUEFLAG=1
		else   
		    log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "\"$1/$LOCAL_SYSTEM_NAME_PREFIX\" Doesnt exist. Creating it [FAILED]" 0 1
		    ZECONTINUEFLAG=0
  		fi
  	else
		log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "\"$1/$LOCAL_SYSTEM_NAME_PREFIX\" Exists. Using it [INFO]" 0 1
		ZECONTINUEFLAG=1
	fi


	if [ $ZECONTINUEFLAG -eq 1 ];then
		if [ $BACKUPSQL -eq 1 ];then
			mysqldump --force --opt --user=$DB_USER --password=$DB_PASSWORD  --all-databases --lock-tables --dump-date --events --routines  --log-error="$LOCAL_LOG_FILE.$BACKUP_FILE_NAME_DATE_SUFFIX.sqldump.err.log"   | $COMPRESSION_COMMAND  >  "$1/$LOCAL_SYSTEM_NAME_PREFIX/$MYSQL_BACKUP_FILE_NAME"
			if [ $? -eq 0 ];then
			  log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Backing up Database to \"$1/${LOCAL_SYSTEM_NAME_PREFIX}/$MYSQL_BACKUP_FILE_NAME\" [OK]" 0 1
			else
			  log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Backing up Database to \"$1/${LOCAL_SYSTEM_NAME_PREFIX}/$MYSQL_BACKUP_FILE_NAME\" [FAILED]" 0 1
			fi
		fi

		if [ $BACKUPDATA -eq 1 ];then
			for currentPATH in $LIST_OF_PATHS_TO_BACKUP
			do
				if [ -e "$currentPATH" ];then
					tar uf "$1/$LOCAL_SYSTEM_NAME_PREFIX/$DATA_BACKUP_FILE_NAME"   "$currentPATH" 1>/dev/null 2>/dev/null
					if [ $? -eq 0 ];then
						log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Adding \"$currentPATH\" to archive \"$1/${LOCAL_SYSTEM_NAME_PREFIX}/$DATA_BACKUP_FILE_NAME\" [OK]" 0 1
					else
						log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Adding \"$currentPATH\" to archive \"$1/${LOCAL_SYSTEM_NAME_PREFIX}/$DATA_BACKUP_FILE_NAME\" [FAILED]" 0 1
					fi
				else
					log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "\"$currentPATH\" doesnt exist. Skipping it [INFO]" 0 1
				fi
			done

			###################### COMPRESS THE DATA BACKUP ######################
			if [ -f "$1/$LOCAL_SYSTEM_NAME_PREFIX/$DATA_BACKUP_FILE_NAME" ];then
				$COMPRESSION_COMMAND $COMPRESSION_COMMAND_OPTIONS_COMPRESS  "$1/$LOCAL_SYSTEM_NAME_PREFIX/$DATA_BACKUP_FILE_NAME"  2> /dev/null
				if [ -f "$1/$LOCAL_SYSTEM_NAME_PREFIX/$DATA_BACKUP_FILE_NAME.${BACKUP_FILE_EXTENSION}" ] && [ ! -f "$1/$LOCAL_SYSTEM_NAME_PREFIX/$DATA_BACKUP_FILE_NAME" ];then
					log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Compressing Data Backup File : \"$1/$LOCAL_SYSTEM_NAME_PREFIX/$DATA_BACKUP_FILE_NAME\" To : \"$1/$LOCAL_SYSTEM_NAME_PREFIX/$DATA_BACKUP_FILE_NAME.${BACKUP_FILE_EXTENSION}\" ..... [OK]" 0 1
					DATA_BACKUP_FILE_NAME="${DATA_BACKUP_FILE_NAME}.${BACKUP_FILE_EXTENSION}"
				else
					log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Compressing Data Backup File : \"$1/$LOCAL_SYSTEM_NAME_PREFIX/$DATA_BACKUP_FILE_NAME\" To : \"$1/$LOCAL_SYSTEM_NAME_PREFIX/$DATA_BACKUP_FILE_NAME.${BACKUP_FILE_EXTENSION}\" ..... [FAILED]" 0 1
				fi
			fi
		fi

		
		if [ $BACKUPPOSTGRESS -eq 1 ];then
            su - postgres -c "/usr/bin/pg_dumpall  2> /dev/null "  | $COMPRESSION_COMMAND $COMPRESSION_COMMAND_OPTIONS_COMPRESS  >  "$1/$LOCAL_SYSTEM_NAME_PREFIX/$PGRESS_BACKUP_FILE_NAME"
			if [ $? -eq 0 ];then
			  log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Backing up Postgress Database to \"$1/${LOCAL_SYSTEM_NAME_PREFIX}/$PGRESS_BACKUP_FILE_NAME\" [OK]" 0 1
			else
			  log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Backing up Postgress Database to \"$1/${LOCAL_SYSTEM_NAME_PREFIX}/$PGRESS_BACKUP_FILE_NAME\" [FAILED]" 0 1
			fi
		fi

		if [ $BACKUPPBX -eq 1 ];then
			PBXBACKUPCMD=`which 3CXBackupCmd`
			su - ${PBX_USERNAME} -c "$PBXBACKUPCMD --file=/tmp/full_pbx_backup.zip --options=ALL --log=/var/tmp/pbx-backup_cmd.log" 1> /dev/null 2> /dev/null
			if [ $? -eq 0 ];then
				log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Backing up PBX Data to \"/tmp/full_pbx_backup.zip\" [OK]" 0 1
				if [ -f "/tmp/full_pbx_backup.zip" ];then
					  cp -f "/tmp/full_pbx_backup.zip"  "$1/${LOCAL_SYSTEM_NAME_PREFIX}/$PBX_BACKUP_FILE_NAME"  1> /dev/null 2> /dev/null
					  cp -f "/var/tmp/pbx-backup_cmd.log"  "$1/${LOCAL_SYSTEM_NAME_PREFIX}/$PBX_BACKUP_FILE_NAME.log"  1> /dev/null 2> /dev/null
					  log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Moving PBX Data Backup to \"$1/${LOCAL_SYSTEM_NAME_PREFIX}/$PBX_BACKUP_FILE_NAME\" [OK]" 0 1
				else
					  log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Moving PBX Data Backup to \"$1/${LOCAL_SYSTEM_NAME_PREFIX}/$PBX_BACKUP_FILE_NAME\" [FAILED]" 0 1
				fi
			else
			  log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Backing up PBX Data to \"/tmp/full_pbx_backup.zip\" [FAILED]" 0 1
			fi
			
			if [ -f "/tmp/full_pbx_backup.zip" ];then
				rm -f "/tmp/full_pbx_backup.zip"  1> /dev/null 2> /dev/null
				rm -f "/var/tmp/pbx-backup_cmd.log" 1> /dev/null  2> /dev/null
			fi
		fi

		if [ $BACKUPLDAP -eq 1 ];then
			ldapsearch -LLL -x -D "$LDAP_ADMIN_PATH" -w "$LDAP_ADMIN_PWD" -b "$LDAP_BASEPATH" | $COMPRESSION_COMMAND 2> /dev/null >  "$1/$LOCAL_SYSTEM_NAME_PREFIX/$LDAP_BACKUP_FILE_NAME"
			if [ $? -eq 0 ];then
			  log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Backing up LDAP to \"$1/${LOCAL_SYSTEM_NAME_PREFIX}/$LDAP_BACKUP_FILE_NAME\" [OK]" 0 1
			else
			  log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Backing up LDAP to \"$1/${LOCAL_SYSTEM_NAME_PREFIX}/$LDAP_BACKUP_FILE_NAME\" [FAILED]" 0 1
			fi
		fi

	else
		log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Will be exiting due to last error.................[WARN]" 0 1
	fi


	if [ $SYNCHDATA -eq 1 ];then
		ZECONTINUEFLAG=1
		if [ ! -d "$1/$LOCAL_SYSTEM_NAME_PREFIX/$RSYNCHSUFFIX" ];then
			mkdir -p "$1/$LOCAL_SYSTEM_NAME_PREFIX/$RSYNCHSUFFIX" 1> /dev/null 2> /dev/null
			if [ $? -eq 0 ];then
			    log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "\"$1/$LOCAL_SYSTEM_NAME_PREFIX/$RSYNCHSUFFIX\" Doesnt exist. Creating it [OK]" 0 1
			    ZECONTINUEFLAG=1
			else   
			    log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "\"$1/$LOCAL_SYSTEM_NAME_PREFIX/$RSYNCHSUFFIX\" Doesnt Exists! Creating it failed. No Data Will be Synched! [WARN]" 0 1
			    ZECONTINUEFLAG=0
			fi
		else
			log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "\"$1/$LOCAL_SYSTEM_NAME_PREFIX/$RSYNCHSUFFIX\" Exists! Using it! [INFO]" 0 1
			ZECONTINUEFLAG=1
		fi	

		if [ $ZECONTINUEFLAG -eq 1 ];then
			for currentPATH in $LIST_OF_PATHS_TO_SYNC
			do
				if [ -e "$currentPATH" ];then
					rsync -aHK --no-g  --no-o --delete "$currentPATH"   "$1/$LOCAL_SYSTEM_NAME_PREFIX/$RSYNCHSUFFIX/"   1> /dev/null 2> /dev/null
					if [ $? -eq 0 ];then
						log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Synching \"$currentPATH\" to \"$1/$LOCAL_SYSTEM_NAME_PREFIX/$RSYNCHSUFFIX/\" [OK]" 0 1
					else
						log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Synching \"$currentPATH\" to \"$1/$LOCAL_SYSTEM_NAME_PREFIX/$RSYNCHSUFFIX/\" [FAILED]" 0 1
					fi
				else
					log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "\"$currentPATH\" doesnt exist. Skipping it [INFO]" 0 1
				fi
			done
		fi
	fi	
}


remove_old_backups(){
	## 1 = BASE PATH ; 2 = SYSTEM TAG ; 3 = Days3 ; 4 = DELETE TAG ; 5 = (1 = Count, 0 = Days ## 
	if [ -d "$1/$2" ];then
		MIDSECSTRING=""
		if [[ $5 -eq 1 ]];then
			MIDSECSTRING=";Param:Count ;Unit:$3"
			FLINES=$(find "$1/$2" -iname "${LOCAL_HOSTNAME}*${4}*" -maxdepth 1 -type f  2>/dev/null | sort -t "_" -k3  | wc -l | tr -d '\n')
			if [ $FLINES -gt 0 ] && [ $FLINES -gt $3 ];then
				FDEL=$(( $FLINES - $3 ))
				find "$1/$2" -iname "${LOCAL_HOSTNAME}*${4}*" -maxdepth 1 -type f  2>/dev/null | sort -t "$BACKUP_FILE_DELIMETER" -k$UNIQUE_FIELD_NUMBER_INBACKUP_FILE | head -n $FDEL | xargs rm -f  >/dev/null 2>/dev/null  
				log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Cleaning In : \"$1/$2\" $MIDSECSTRING ....... [INFO]" 0 1
			else
				log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Nothing To Cleanup In : \"$1/$2\" $MIDSECSTRING ....... [INFO]" 0 1
			fi
		elif [[ $5 -eq 0 ]];then
			MIDSECSTRING=";Param:Days ;Unit:$3"
			find "$1/$2" -maxdepth 1 -type f -mtime +$3 -iname "${LOCAL_HOSTNAME}*${4}*" -exec  rm -f "{}" \;
			log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Cleaning up : \"$1/$2\" $MIDSECSTRING ....... [INFO]" 0 1
		fi
	fi
}


recursively_delete_old_data(){
	## 1 = BASE PATH ; 2 = SYSTEM TAG ; 3 = Days3 ; 4 = DELETE TAG ; 5 = (1 = Count, 0 = Days ## 
	if [[ $3 -eq 1 ]];then
		if [[ $BACKUPSQL -eq 1 ]];then
			log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Cleaning Up Remote MySQL Backups ....... [INFO]" 0 1
			remove_old_backups "$1" "$2" "$MYSQL_REMOTE_BACKUP_COUNT" "$MYSQL_BACKUP_TAG" "$MYSQL_REMOTE_BACKUP_DAYS_OR_COUNT"
		fi
			
		if [[ $BACKUPPOSTGRESS -eq 1 ]];then
			log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Cleaning Up Remote PGresSQL Backups ....... [INFO]" 0 1
			remove_old_backups "$1" "$2" "$PGRESS_REMOTE_BACKUP_COUNT" "$PGRESS_BACKUP_TAG" "$PGRESS_REMOTE_BACKUP_DAYS_OR_COUNT"
		fi

		if [[ $BACKUPLDAP -eq 1 ]];then
			log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Cleaning Up Remote LDAP Backups ....... [INFO]" 0 1
			remove_old_backups "$1" "$2" "$LDAP_REMOTE_BACKUP_COUNT" "$LDAP_BACKUP_TAG" "$LDAP_REMOTE_BACKUP_DAYS_OR_COUNT"
		fi
			
		if [[ $BACKUPDATA -eq 1 ]];then
			log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Cleaning Up Remote Data Backups ....... [INFO]" 0 1
			remove_old_backups "$1" "$2" "$DATA_REMOTE_BACKUP_COUNT" "$DATA_BACKUP_TAG" "$DATA_REMOTE_BACKUP_DAYS_OR_COUNT"
		fi

		if [ $BACKUPPBX -eq 1 ];then
			log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Cleaning Up Remote PBX Data Backups ....... [INFO]" 0 1
			remove_old_backups "$1" "$2" "$PBX_REMOTE_BACKUP_COUNT" "$PBX_BACKUP_TAG" "$PBX_REMOTE_BACKUP_DAYS_OR_COUNT"
		fi
	elif [[ $3 -eq 0 ]];then
		if [[ $BACKUPSQL -eq 1 ]];then
			log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Cleaning Up Local MySQL Backups ....... [INFO]" 0 1
			remove_old_backups "$1" "$2" "$MYSQL_LOCAL_BACKUP_COUNT" "$MYSQL_BACKUP_TAG" "$MYSQL_LOCAL_BACKUP_DAYS_OR_COUNT"
		fi
			
		if [[ $BACKUPPOSTGRESS -eq 1 ]];then
			log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Cleaning Up Local PGresSQL Backups ....... [INFO]" 0 1
			remove_old_backups "$1" "$2" "$PGRESS_LOCAL_BACKUP_COUNT" "$PGRESS_BACKUP_TAG" "$PGRESS_LOCAL_BACKUP_DAYS_OR_COUNT"
		fi

		if [[ $BACKUPLDAP -eq 1 ]];then
			log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Cleaning Up Local LDAP Backups ....... [INFO]" 0 1
			remove_old_backups "$1" "$2" "$LDAP_LOCAL_BACKUP_COUNT" "$LDAP_BACKUP_TAG" "$LDAP_LOCAL_BACKUP_DAYS_OR_COUNT"
		fi
			
		if [[ $BACKUPDATA -eq 1 ]];then
			log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Cleaning Up Local Data Backups ....... [INFO]" 0 1
			remove_old_backups "$1" "$2" "$DATA_LOCAL_BACKUP_COUNT" "$DATA_BACKUP_TAG" "$DATA_LOCAL_BACKUP_DAYS_OR_COUNT"
		fi

		if [ $BACKUPPBX -eq 1 ];then
			log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Cleaning Up Remote PBX Data Backups ....... [INFO]" 0 1
			remove_old_backups "$1" "$2" "$PBX_LOCAL_BACKUP_COUNT" "$PBX_BACKUP_TAG" "$PBX_REMOTE_LOCAL_DAYS_OR_COUNT"
		fi
	else
		log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Misconfiguration In Units To Clean up: $3 ....... [INFO]" 0 1
	fi
}


showusagemessage(){
	echo "Usage : $0 [ backup [custom_config_file)]| clean [(custom_config_file)]] | install [(custom_config_file)]]"
}

mountbackupdrive(){
	MOUNTRETVAL=`cat  /etc/mtab  | grep "$NFS_LOCAL_MOUNT_POINT" | wc -c`
	mount  | grep \'$NFS_MOUNT_POINT\'
	if [ "$MOUNTRETVAL" = "0" ];then

		#####IF Mount Point Doesnt Exists, Create It###########
		if [ ! -d "$NFS_LOCAL_MOUNT_POINT" ];then
	   		log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Mount Point : \"$NFS_LOCAL_MOUNT_POINT\" Not Found ....[INFO]" 0 1
	   		mkdir -p "$NFS_LOCAL_MOUNT_POINT" 2> /dev/null
	   		if [[ $? -eq 0 ]];then
				log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Creating Directory : \"$NFS_LOCAL_MOUNT_POINT\"  ....[FAILED]" 0 1
	   		else
				log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Creating Directory : \"$NFS_LOCAL_MOUNT_POINT\"  ....[OK]" 0 1
	   		fi
		fi
	
		mount $NFS_SERVER_SHARE_PATH   $NFS_LOCAL_MOUNT_POINT  1> /dev/null 2> /dev/null
		if [ $? -eq 0 ];then
	   		log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Mounting  \"$NFS_SERVER_SHARE_PATH\" on \"$NFS_LOCAL_MOUNT_POINT\" : [OK]" 0 1
			MYMOUNTEDFLAG=1
        else
			log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Mounting  \"$NFS_SERVER_SHARE_PATH\" on \"$NFS_LOCAL_MOUNT_POINT\" : [FAILED]" 0 1
        fi
    else
	   log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Something is already mounter on \"$NFS_LOCAL_MOUNT_POINT\" : [INFO]" 0 1
	fi
}

unmountbackupdrive(){
	umount $NFS_SERVER_SHARE_PATH   $NFS_LOCAL_MOUNT_POINT  1> /dev/null 2> /dev/null
	log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Unmounting  \"$NFS_SERVER_SHARE_PATH\" from \"$NFS_LOCAL_MOUNT_POINT\" : [INFO]" 0 1
}

send_notification(){
	if [ $SEND_NOTIFICATION -eq 1 ];then
	    log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Sending Notification  Email To : ${EMAIL_ADDRESS} ,${BCC_EMAIL_ADDRESS} [INFO]" 0 1
	    MSG2SEND=`cat "$LOG_BUFFER"`
	    echo -e ${MSG2SEND} | mutt -F /etc/mailrc -b ${BCC_EMAIL_ADDRESS}  -s "ALERT : ${LOCAL_HOSTNAME} - ${EMAIL_SUBJECT_SUFFIX} - ${LOCAL_IP_ADDRESS}"   ${EMAIL_ADDRESS}  1> /dev/null 2> /dev/null
	fi
}



synclocalbackstoremote(){
	ZECONTINUEFLAG=1
	if [ ! -d "$NFS_LOCAL_MOUNT_POINT/$LOCAL_SYSTEM_NAME_PREFIX" ];then
  		mkdir -p "$NFS_LOCAL_MOUNT_POINT/$LOCAL_SYSTEM_NAME_PREFIX" 1> /dev/null 2> /dev/null
  		if [ $? -eq 0 ];then
		    log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "\"$NFS_LOCAL_MOUNT_POINT/$LOCAL_SYSTEM_NAME_PREFIX\" Doesnt exist. Creating it [OK]" 0 1
		    ZECONTINUEFLAG=1
		else   
		    log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "\"$NFS_LOCAL_MOUNT_POINT/$LOCAL_SYSTEM_NAME_PREFIX\" Doesnt Exists! Creating it failed. No Data Will be copied! [WARN]" 0 1
		    ZECONTINUEFLAG=0
  		fi
  	else
		log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "\"$NFS_LOCAL_MOUNT_POINT/$LOCAL_SYSTEM_NAME_PREFIX\" Exists. Using it [INFO]" 0 1
		ZECONTINUEFLAG=1
	fi

	if [ $ZECONTINUEFLAG -eq 1 ];then
		if [ $BACKUPSQL -eq 1 ];then
			cp -f "$LOCAL_BACKUP_DIR/$LOCAL_SYSTEM_NAME_PREFIX/$MYSQL_BACKUP_FILE_NAME"    "$NFS_LOCAL_MOUNT_POINT/$LOCAL_SYSTEM_NAME_PREFIX/$MYSQL_BACKUP_FILE_NAME"   1> /dev/null 2> /dev/null
			if [ $? -eq 0 ];then
			  log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Copying SQL Backup to Server  \"$LOCAL_BACKUP_DIR/$LOCAL_SYSTEM_NAME_PREFIX/$MYSQL_BACKUP_FILE_NAME\"  -> \"$NFS_LOCAL_MOUNT_POINT/$LOCAL_SYSTEM_NAME_PREFIX/$MYSQL_BACKUP_FILE_NAME\" [OK]" 0 1
			else
			  log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Copying SQL Backup to Server  \"$LOCAL_BACKUP_DIR/$LOCAL_SYSTEM_NAME_PREFIX/$MYSQL_BACKUP_FILE_NAME\"  -> \"$NFS_LOCAL_MOUNT_POINT/$LOCAL_SYSTEM_NAME_PREFIX/$MYSQL_BACKUP_FILE_NAME\" [FAILED]" 0 1
			fi
		fi
		
		if [ $BACKUPPOSTGRESS -eq 1 ];then
			cp -f "$LOCAL_BACKUP_DIR/$LOCAL_SYSTEM_NAME_PREFIX/$PGRESS_BACKUP_FILE_NAME"    "$NFS_LOCAL_MOUNT_POINT/$LOCAL_SYSTEM_NAME_PREFIX/$PGRESS_BACKUP_FILE_NAME"   1> /dev/null 2> /dev/null
			if [ $? -eq 0 ];then
			  log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Copying Postgress Database Backup to Server  \"$LOCAL_BACKUP_DIR/$LOCAL_SYSTEM_NAME_PREFIX/$PGRESS_BACKUP_FILE_NAME\"  -> \"$NFS_LOCAL_MOUNT_POINT/$LOCAL_SYSTEM_NAME_PREFIX/$PGRESS_BACKUP_FILE_NAME\" [OK]" 0 1
			else
			  log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Copying Postgress Database Backup to Server  \"$LOCAL_BACKUP_DIR/$LOCAL_SYSTEM_NAME_PREFIX/$PGRESS_BACKUP_FILE_NAME\"  -> \"$NFS_LOCAL_MOUNT_POINT/$LOCAL_SYSTEM_NAME_PREFIX/$PGRESS_BACKUP_FILE_NAME\" [FAILED]" 0 1
			fi
		fi

		if [ $BACKUPPBX -eq 1 ];then
			cp -f "$LOCAL_BACKUP_DIR/$LOCAL_SYSTEM_NAME_PREFIX/$PBX_BACKUP_FILE_NAME.log"    "$NFS_LOCAL_MOUNT_POINT/$LOCAL_SYSTEM_NAME_PREFIX/$PBX_BACKUP_FILE_NAME.log"   1> /dev/null 2> /dev/null
			cp -f "$LOCAL_BACKUP_DIR/$LOCAL_SYSTEM_NAME_PREFIX/$PBX_BACKUP_FILE_NAME"    "$NFS_LOCAL_MOUNT_POINT/$LOCAL_SYSTEM_NAME_PREFIX/$PBX_BACKUP_FILE_NAME"   1> /dev/null 2> /dev/null
			if [ $? -eq 0 ];then
			  log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Copying PBX Data Backup to Server  \"$LOCAL_BACKUP_DIR/$LOCAL_SYSTEM_NAME_PREFIX/$PBX_BACKUP_FILE_NAME\"  -> \"$NFS_LOCAL_MOUNT_POINT/$LOCAL_SYSTEM_NAME_PREFIX/$PBX_BACKUP_FILE_NAME\" [OK]" 0 1
			else
			  log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Copying PBX Data Backup to Server  \"$LOCAL_BACKUP_DIR/$LOCAL_SYSTEM_NAME_PREFIX/$PBX_BACKUP_FILE_NAME\"  -> \"$NFS_LOCAL_MOUNT_POINT/$LOCAL_SYSTEM_NAME_PREFIX/$PBX_BACKUP_FILE_NAME\" [FAILED]" 0 1
			fi
		fi

		if [ $BACKUPDATA -eq 1 ];then
			cp -f "$LOCAL_BACKUP_DIR/$LOCAL_SYSTEM_NAME_PREFIX/$DATA_BACKUP_FILE_NAME"   "$NFS_LOCAL_MOUNT_POINT/$LOCAL_SYSTEM_NAME_PREFIX/$DATA_BACKUP_FILE_NAME"   1> /dev/null 2> /dev/null
			if [ $? -eq 0 ];then
			  log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Copying Data Backup to Server  \"$LOCAL_BACKUP_DIR/$LOCAL_SYSTEM_NAME_PREFIX/$DATA_BACKUP_FILE_NAME\"  -> \"$NFS_LOCAL_MOUNT_POINT/$LOCAL_SYSTEM_NAME_PREFIX/$DATA_BACKUP_FILE_NAME\" [OK]" 0 1
			else
			  log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Copying Data Backup to Server  \"$LOCAL_BACKUP_DIR/$LOCAL_SYSTEM_NAME_PREFIX/$DATA_BACKUP_FILE_NAME\"  -> \"$NFS_LOCAL_MOUNT_POINT/$LOCAL_SYSTEM_NAME_PREFIX/$DATA_BACKUP_FILE_NAME\" [FAILED]" 0 1
			fi
		fi

		if [ $BACKUPLDAP -eq 1 ];then
			cp -f "$LOCAL_BACKUP_DIR/$LOCAL_SYSTEM_NAME_PREFIX/$LDAP_BACKUP_FILE_NAME"    "$NFS_LOCAL_MOUNT_POINT/$LOCAL_SYSTEM_NAME_PREFIX/$LDAP_BACKUP_FILE_NAME"   1> /dev/null 2> /dev/null
			if [ $? -eq 0 ];then
			  log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Copying LDAP Backup to Server  \"$LOCAL_BACKUP_DIR/$LOCAL_SYSTEM_NAME_PREFIX/$LDAP_BACKUP_FILE_NAME\"  -> \"$NFS_LOCAL_MOUNT_POINT/$LOCAL_SYSTEM_NAME_PREFIX/$LDAP_BACKUP_FILE_NAME\" [OK]" 0 1
			else
			  log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Copying LDAP Backup to Server  \"$LOCAL_BACKUP_DIR/$LOCAL_SYSTEM_NAME_PREFIX/$LDAP_BACKUP_FILE_NAME\"  -> \"$NFS_LOCAL_MOUNT_POINT/$LOCAL_SYSTEM_NAME_PREFIX/$LDAP_BACKUP_FILE_NAME\" [FAILED]" 0 1
			fi
		fi

	fi

	if [ $SYNCHDATA -eq 1 ];then
		ZECONTINUEFLAG=1
		if [ ! -d "$NFS_LOCAL_MOUNT_POINT/$LOCAL_SYSTEM_NAME_PREFIX/$RSYNCHSUFFIX" ];then
			mkdir -p "$NFS_LOCAL_MOUNT_POINT/$LOCAL_SYSTEM_NAME_PREFIX/$RSYNCHSUFFIX" 1> /dev/null 2> /dev/null
			if [ $? -eq 0 ];then
			    log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "\"$NFS_LOCAL_MOUNT_POINT/$LOCAL_SYSTEM_NAME_PREFIX/$RSYNCHSUFFIX\" Doesnt exist. Creating it [OK]" 0 1
			    ZECONTINUEFLAG=1
			else   
			    log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "\"$NFS_LOCAL_MOUNT_POINT/$LOCAL_SYSTEM_NAME_PREFIX/$RSYNCHSUFFIX\" Doesnt Exists! Creating it failed. No Data Will be Synched! [WARN]" 0 1
			    ZECONTINUEFLAG=0
			fi
		else
			log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "\"$NFS_LOCAL_MOUNT_POINT/$LOCAL_SYSTEM_NAME_PREFIX/$RSYNCHSUFFIX\" Exists! Using it! [INFO]" 0 1
			ZECONTINUEFLAG=1
		fi	

		if [ $ZECONTINUEFLAG -eq 1 ];then
			for currentPATH in $LIST_OF_PATHS_TO_SYNC
			do
				if [ -e "$currentPATH" ];then
					rsync -avHK  --no-g  --no-o --delete "$currentPATH"   "$NFS_LOCAL_MOUNT_POINT/$LOCAL_SYSTEM_NAME_PREFIX/$RSYNCHSUFFIX/"   1> /dev/null 2> /dev/null
					if [ $? -eq 0 ];then
						log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Synching \"$currentPATH\" to \"$NFS_LOCAL_MOUNT_POINT/$LOCAL_SYSTEM_NAME_PREFIX/$RSYNCHSUFFIX/\" [OK]" 0 1
					else
						log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Synching \"$currentPATH\" to \"$NFS_LOCAL_MOUNT_POINT/$LOCAL_SYSTEM_NAME_PREFIX/$RSYNCHSUFFIX/\" [FAILED]" 0 1
					fi
				else
					log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "\"$currentPATH\" doesnt exist. Skipping it [INFO]" 0 1
				fi
			done
		fi
	fi	
}


letsbackup(){
    if [ $BACKUP_MODE_FLAG -eq 2 ];then
        checkifrootisrunningscript
        checkrequiredcommands
        precommands
        mountbackupdrive
        if [ $MYMOUNTEDFLAG -eq 1 -a $BACKUP_TO_FLAG -eq 1 ];then
        ############NFS WAS OK , BACK UP TO REMOTE ONLY AS USER SAID ###############
        log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Remote Backup Requested. Remote FS Mounted. Remote Backup Will be Done..... [INFO]" 0 1
        dobackup "$NFS_LOCAL_MOUNT_POINT"
        ## 1 = BASE PATH ; 2 = SYSTEM TAG ; 3 = (0=Local, 1=Remote) ; ##
        recursively_delete_old_data  "$NFS_LOCAL_MOUNT_POINT" "$LOCAL_SYSTEM_NAME_PREFIX" 1 
        elif [ $MYMOUNTEDFLAG -eq 0 -a $BACKUP_TO_FLAG -eq 1 ];then
        ############NFS WAS NACK , DONT BACK UP ANYTHING AS USER SAID ##############
        log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Remote Backup Requested. Remote FS NOT Mounted. Remote Backup Will NOT be Done..... [INFO]" 0 1
        elif [ $BACKUP_TO_FLAG -eq 2 ];then
        ############NFS DOESNT MATTER , BACK UP TO LOCAL AS USER SAID ##############
        log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Local Backup Requested. Local Backup Will be Done..... [INFO]" 0 1
        dobackup "$LOCAL_BACKUP_DIR"
        ## 1 = BASE PATH ; 2 = SYSTEM TAG ; 3 = (0=Local, 1=Remote) ; ##
        recursively_delete_old_data  "$LOCAL_BACKUP_DIR" "$LOCAL_SYSTEM_NAME_PREFIX" 0 
        elif [ $MYMOUNTEDFLAG -eq 1 -a $BACKUP_TO_FLAG -eq 3 ];then
        ############NFS WAS OK AND USER SAID BACKUP TO BOTH. DO BOTH ###############
        log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Remote and Local Backup Requested. Remote and Local Backup Will be Done..... [INFO]" 0 1
        dobackup "$LOCAL_BACKUP_DIR"
        synclocalbackstoremote
        ## 1 = BASE PATH ; 2 = SYSTEM TAG ; 3 = (0=Local, 1=Remote) ; ##
        recursively_delete_old_data  "$NFS_LOCAL_MOUNT_POINT" "$LOCAL_SYSTEM_NAME_PREFIX" 1 
        ## 1 = BASE PATH ; 2 = SYSTEM TAG ; 3 = (0=Local, 1=Remote) ; ##
        recursively_delete_old_data  "$LOCAL_BACKUP_DIR" "$LOCAL_SYSTEM_NAME_PREFIX" 0
        elif [ $MYMOUNTEDFLAG -eq 0 -a $BACKUP_TO_FLAG -eq 3 ];then
        ############NFS WAS NACK AND USER SAID BACKUP TO BOTH. DO LOCAL ONLY########
        log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Remote and Local Backup Requested. Remote FS Mounting Failed. ONLY Local Backup Will be Done..... [INFO]" 0 1
        dobackup "$LOCAL_BACKUP_DIR"
        ## 1 = BASE PATH ; 2 = SYSTEM TAG ; 3 = (0=Local, 1=Remote) ; ##
        recursively_delete_old_data  "$LOCAL_BACKUP_DIR" "$LOCAL_SYSTEM_NAME_PREFIX" 0
        else
        ############YOU MAY HAVE A MISCONFUGRATION DUDE. LOG HELP ON CONFIG ########
        log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "An Exceptio Has Occured! Most Like due to a configuration error. Exiting! [WARN]" 0 1
        fi
        unmountbackupdrive
        postcommands
    fi
}

###Backup Light Version Modules#
mariadb_mysql_backup(){
	if [[ $BACKUPSQL -eq 1 ]];then
		${MYSQLDUMPCMD} ${MYSQLDUMP_OPTS} 2>/dev/null | ${COMPRESSION_COMMAND} ${COMPRESSION_COMMAND_OPTIONS_COMPRESS} | $SSHPASSCMD ${SSHPASSOPTS}  ${SSHCMD} ${SSHOPTS}  ${SSHUSER_SERVER}  "cat > "${SSHDATA_BASE_PATH}${LOCAL_SYSTEM_NAME_PREFIX}/${MYSQL_BACKUP_FILE_NAME}"" 1>/dev/null 2>/dev/null
		if [[ $? -eq 0 ]];then
			log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Backing Up MariaDB/MySQL -> [${SSHUSER_SERVER}:${SSHDATA_BASE_PATH}${LOCAL_SYSTEM_NAME_PREFIX}/${MYSQL_BACKUP_FILE_NAME}] ........[DONE]" 0 1
		else
			log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Backing Up MariaDB/MySQL -> [${SSHUSER_SERVER}:${SSHDATA_BASE_PATH}${LOCAL_SYSTEM_NAME_PREFIX}/${MYSQL_BACKUP_FILE_NAME}] ........[FAILED]" 0 1
        	fi

		log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Cleaning Up Old  MariaDB/MySQL Backups From [${SSHUSER_SERVER}:${SSHDATA_BASE_PATH}${LOCAL_SYSTEM_NAME_PREFIX}/*] ........[START]" 0 1
    		$SSHPASSCMD ${SSHPASSOPTS} ${SSHCMD} ${SSHOPTS} ${SSHUSER_SERVER} "find "${SSHDATA_BASE_PATH}${LOCAL_SYSTEM_NAME_PREFIX}" -iname "${LOCAL_HOSTNAME}${BACKUP_FILE_DELIMETER}*.${MYSQL_BACKUP_TAG}.${BACKUP_FILE_EXTENSION}" -maxdepth 1 -type f -mtime +${MYSQL_REMOTE_BACKUP_COUNT}  -exec rm -f '{}' \;"
		log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Cleaning Up Old  MariaDB/MySQL Backups From [${SSHUSER_SERVER}:${SSHDATA_BASE_PATH}${LOCAL_SYSTEM_NAME_PREFIX}/*] ........[DONE]" 0 1
	fi
}
rsync_over_ssh_data(){
	if [[ $BACKUPDATA -eq 1 ]];then
		for i in $LIST_OF_PATHS_TO_BACKUP
		do
		   if [ -e "$i" ];then	
			THEBASENAME=$(basename $i)
			log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "File/Dir : [$i], Found! ........[INFO]" 0 1
			log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Backing Up : [$i]->[${SSHUSER_SERVER}:${SSHDATA_BASE_PATH}${LOCAL_SYSTEM_NAME_PREFIX}/${THEBASENAME}] ........[START]" 0 1
			$SSHPASSCMD ${SSHPASSOPTS} ${RSYNCCMD} ${RSYNCOPTS} "${SSHCMD} ${SSHOPTS}"  "${i}" "${SSHUSER_SERVER}:${SSHDATA_BASE_PATH}${LOCAL_SYSTEM_NAME_PREFIX}/${THEBASENAME}"
			if [[ $? -eq 0 ]];then
				log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Backing Up : [$i]->[${SSHUSER_SERVER}:${SSHDATA_BASE_PATH}${LOCAL_SYSTEM_NAME_PREFIX}/${THEBASENAME}] ........[DONE]" 0 1
			else
				log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Backing Up : [$i]->[${SSHUSER_SERVER}:${SSHDATA_BASE_PATH}${LOCAL_SYSTEM_NAME_PREFIX}/${THEBASENAME}] ........[FAILED]" 0 1
			fi
		   else
			log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "File/Dir : [$i] , Doesnt Exists. Skipping ........[INFO]" 0 1
		   fi
		done
	fi
}
check_for_remote_backup_dir(){
    $SSHPASSCMD ${SSHPASSOPTS} ${SSHCMD} ${SSHOPTS} ${SSHUSER_SERVER} "test -d "${SSHDATA_BASE_PATH}${LOCAL_SYSTEM_NAME_PREFIX}""
    if [[ $? -ne 0 ]];then
	log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Directory : [${SSHUSER_SERVER}:${SSHDATA_BASE_PATH}${THEBASENAME}${LOCAL_SYSTEM_NAME_PREFIX}],Not Found .......[INFO]" 0 1
	$SSHPASSCMD ${SSHPASSOPTS} ${SSHCMD} ${SSHOPTS} ${SSHUSER_SERVER} "mkdir -p "${SSHDATA_BASE_PATH}${LOCAL_SYSTEM_NAME_PREFIX}""
	if [[ $? -eq 0 ]];then
            log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Directory : [${SSHUSER_SERVER}:${SSHDATA_BASE_PATH}${THEBASENAME}${LOCAL_SYSTEM_NAME_PREFIX}],Created .......[OK]" 0 1
        else
            log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Directory : [${SSHUSER_SERVER}:${SSHDATA_BASE_PATH}${THEBASENAME}${LOCAL_SYSTEM_NAME_PREFIX}],Created .......[FAILED]" 0 1
        fi
    else
	log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Directory : [${SSHUSER_SERVER}:${SSHDATA_BASE_PATH}${THEBASENAME}${LOCAL_SYSTEM_NAME_PREFIX}],Found .......[INFO]" 0 1
    fi
}
letsbackuplight(){
    if [ $BACKUP_MODE_FLAG -eq 1 ];then
        checkifrootisrunningscript
        checkrequiredcommands
	check_for_remote_backup_dir
        rsync_over_ssh_data
        mariadb_mysql_backup
    fi
}




install_myself(){
	if [ ! -d "/var/log/msmtp" ];then
		echo -n "Creating [/var/log/msmtp] ....."
		mkdir -p  "/var/log/msmtp"  1> /dev/null 2> /dev/null
		if [ $? -eq 0 ];then
			echo "[DONE]"
		else
			echo "[FAILED]"
		fi
	fi
	if [ ! -f "/var/log/msmtp/msmtp.log" ];then
		echo -n "Creating \"/var/log/msmtp/msmtp.log\" ....."
		touch /var/log/msmtp/msmtp.log  1> /dev/null 2> /dev/null
		chmod 666 /var/log/msmtp/msmtp.log  1> /dev/null 2> /dev/null
		if [ $? -eq 0 ];then
			echo "[DONE]"
		else
			echo "[FAILED]"
		fi
	fi

	pushd .  2> /dev/null
	cd "$SCRIPT_DIR" 2> /dev/null
	if [ -f "$SCRIPT_NAME" ];then
		echo -n "Copying : \"$SCRIPT_NAME\" ....."
		cp -f "$SCRIPT_NAME"  "/usr/bin/jtuxbackup.sh"  1> /dev/null 2> /dev/null
		chmod +x /usr/bin/jtuxbackup.sh  1> /dev/null 2> /dev/null
		if [ $? -eq 0 ];then
			echo "[DONE]"
		else
			echo "[FAILED]"
		fi
	fi

	if [ ! -d "/etc/$SCRIPT_NAME" ];then
		echo -n "Creating \"/etc/$SCRIPT_NAME\" ....."
		mkdir -p  "/etc/$SCRIPT_NAME"  1> /dev/null 2> /dev/null
		if [ $? -eq 0 ];then
			echo "[DONE]"
		else
			echo "[FAILED]"
		fi
	fi
	
	if [ -f "${SCRIPT_NAME}.conf" ];then
		echo -n "Copying : \"${SCRIPT_NAME}.conf\" ....."
		cp -f "${SCRIPT_NAME}.conf"  "/etc/$SCRIPT_NAME/${SCRIPT_NAME}.conf"  1> /dev/null 2> /dev/null
		if [ $? -eq 0 ];then
			echo "[DONE]"
		else
			echo "[FAILED]"
		fi
	fi	

    if [ -d "ssh-keys" ];then
		echo -n "Copying : \"ssh-keys\" ....."
		cp -Rv "ssh-keys"  "/etc/$SCRIPT_NAME/ssh-keys"  1>/dev/null 2> /dev/null
		if [ $? -eq 0 ];then
			echo "[DONE]"
			chown -R root:root "/etc/$SCRIPT_NAME/ssh-keys" 1>/dev/null 2> /dev/null
			chmod 600 "/etc/$SCRIPT_NAME/ssh-keys/jtuxbackup-light-sshkey" 1>/dev/null 2> /dev/null
		else
			echo "[FAILED]"
		fi
	fi	
	
	if [ -f "./mailrc" ];then
		echo -n "Copying [mailrc] ....."
		cp -f  "./mailrc"  "/etc/mailrc"   1> /dev/null 2> /dev/null
		sudo chmod 444   "/etc/mailrc"  1> /dev/null 2> /dev/null
		if [ $? -eq 0 ];then
			echo "[DONE]"
		else
			echo "[FAILED]"
		fi
	fi

	if [ -f "./msmtprc" ];then
		echo -n "Copying [msmtprc] ....."
		cp -f "./msmtprc"  "/etc/msmtprc"  1> /dev/null 2> /dev/null
		sudo chmod 444   "/etc/msmtprc"  1> /dev/null 2> /dev/null
		if [ $? -eq 0 ];then
			echo "[DONE]"
		else
			echo "[FAILED]"
		fi
	fi
	popd 1> /dev/null 2> /dev/null


	if [ ! -d "$LOCAL_BACKUP_DIR" ];then
		echo -n "Creating [$LOCAL_BACKUP_DIR] ....."
		mkdir -p  "$LOCAL_BACKUP_DIR"  1> /dev/null 2> /dev/null
		chmod 777 "$LOCAL_BACKUP_DIR"  1> /dev/null 2> /dev/null
		if [ $? -eq 0 ];then
			echo "[DONE]"
		else
			echo "[FAILED]"
		fi
	fi

	if [ ! -d "$NFS_LOCAL_MOUNT_POINT" ];then
		echo -n "Creating [$NFS_LOCAL_MOUNT_POINT] ....."
		mkdir -p "$NFS_LOCAL_MOUNT_POINT"  1> /dev/null 2> /dev/null
		if [ $? -eq 0 ];then
			echo "[DONE]"
		else
			echo "[FAILED]"
		fi
	fi
}


letscleanup(){
    if [ $BACKUP_MODE_FLAG -eq 2 ];then
        checkifrootisrunningscript
        checkrequiredcommands
        mountbackupdrive
        if [ $MYMOUNTEDFLAG -eq 1 ];then
            log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Clean up Requested. Remote FS Mounted. Both Remote and Local Backup Cleanup Will be Done..... [INFO]" 0 1
            ## 1 = BASE PATH ; 2 = SYSTEM TAG ; 3 = (0=Local, 1=Remote) ; ##
            recursively_delete_old_data  "$NFS_LOCAL_MOUNT_POINT" "$LOCAL_SYSTEM_NAME_PREFIX" 1 
            unmountbackupdrive
            ## 1 = BASE PATH ; 2 = SYSTEM TAG ; 3 = (0=Local, 1=Remote) ; ##
            recursively_delete_old_data  "$LOCAL_BACKUP_DIR" "$LOCAL_SYSTEM_NAME_PREFIX" 0 
        else
            log_it "$LOCAL_LOG_FILE" "$LOG_BUFFER" "Clean up Requested. Remote FS Mountinf FAILED. ONLY Local Backup Cleanup Will be Done..... [INFO]" 0 1
            ## 1 = BASE PATH ; 2 = SYSTEM TAG ; 3 = (0=Local, 1=Remote) ; ##
            recursively_delete_old_data  "$LOCAL_BACKUP_DIR" "$LOCAL_SYSTEM_NAME_PREFIX" 0 
        fi
    fi
}



case "$1" in
  backup)
	letsbackup
	letsbackuplight
        ;;
  clean)
	letscleanup
        ;;
  install)
	install_myself
		;;
  *)
	showusagemessage
        ;;
esac
rm -f "$LOG_BUFFER" 2>/dev/null

#####################END LOGGING###############
logend
send_notification

exit 0
