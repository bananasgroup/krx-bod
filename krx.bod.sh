#!/bin/sh
#
# NBH
# Script will run on both hnx and hsx server, and hostname of these servers must contain "hnx" or "hsx"
# Requires:
#	- Tested on Ubuntu 20
#	- Script must run as root
#   - Create logs folder at: ${script_path}/logs/
#	- Allow firewall rule from MDDS server to api.telegram.org port 443 if want to send alert to telegram api.
#
# Adding directly to /etc/crontab file (change the path if needed):
# 00 23 * * * root sh /opt/apps/script/krx.bod.sh | tee -a /opt/apps/script/logs/krx.bod.log
#
# Specific these values in SET PARAM block:
#	sftp_total_file_required
#	sftp_folder
#	script_path
#	api_port
#	api_uri
#	api_action
#
# You can search and change all value with tag ###Changeable
#
# Success code:
# 	1  - success and do next task
# 	0  - failed -> create crontab to try again after 30 minutes
# 	-1 - exit
#
# Comment out Email or Telegram block at the end for sending output via email or telegram api.
#

OUTPUT=""
OUTPUT=${OUTPUT}"===========================================%0A"
OUTPUT=${OUTPUT}"================ KRX BOD ==================%0A"
OUTPUT=${OUTPUT}"===========================================%0A"
OUTPUT=${OUTPUT}"%0A"


# check if system date format is 24 hours
if ! grep -q "LC_TIME=\"C.UTF-8\"" /etc/default/locale
then
	OUTPUT=${OUTPUT}$(date +%T)": System date format is not set to 24 hours. We recommend to use 24 hours format for this script working perfectly.%0A"
	OUTPUT=${OUTPUT}$(date +%T)": Modify LC_TIME....%0A"
	OUTPUT=${OUTPUT}"LC_TIME=\"C.UTF-8\"" | tee -a /etc/default/locale
fi
OUTPUT=${OUTPUT}"%0A"


### SET SAFE TIME
# Set protect time that script cannot run. Script should be run after download sftp and before next start time.
# Default is from 8h00 to 20h59
#
not_before=21 						###Changeable
not_after=8 						###Changeable
logs_path=/opt/apps/script/logs 	###Changeable

c_hour=$(date +%H)
c_minute=$(date +%M)
c_dow=$(date +%u)
success=1

if [ ${c_hour}  -ge ${not_after} ] && [ ${c_hour}  -lt ${not_before} ]
then
	OUTPUT=${OUTPUT}$(date +%T)": Not in running time...%0A"
	success=-1
fi

### SET WEEKEND
# Script will not run if weekend (Day of week are 6-Sat and 7-Sun).
# It will BOD to next Monday if run at Friday night.
#
if [ ${c_dow} -gt 5 ]
then
	if [ ${c_dow} -eq 6 ] && grep -q "auto_bod_crontab" /etc/crontab
	then
		success=1
	else
		OUTPUT=${OUTPUT}$(date +%T)": Weekend: $(date +%a)...%0A"
		OUTPUT=${OUTPUT}$(date +%T)": Not run in weekend...%0A"
		success=-1
	fi
fi

### SET DATE
# If script run from 18h00 - 23h59 -> BOD date is next date, also add ?date=Ymd to api param when call BOD.
# If running from 18h to 23h59, BOD date is next day (or next 3 days if current date is Friday) and SFTP date folder is current date. Param ?date=Ymd must be added.
# If running after 00h00, BOD date is current date and SFTP date folder is yesterday.
# Declare db_date type Y/m/d for checking DB date in BOD block
#
if [ ${c_hour} -ge 18 ] && [ ${c_hour} -le 23 ]
then
	if [ ${c_dow} -eq 6 ] # in case script failed from friday and re-run til saturday
	then
		date=$(date -d '+2 day' '+%Y%m%d')
		db_date=$(date -d '+2 day' '+%Y/%m/%d')
		param="?date=${date}"
		sftp_date=$(date -d '-1 day' '+%Y%m%d')
	elif [ ${c_dow} -eq 5 ] # if run at friday, bod date is next 3 days (Monday).
	then
		date=$(date -d '+3 day' '+%Y%m%d')
		db_date=$(date -d '+3 day' '+%Y/%m/%d')
		param="?date=${date}"
		sftp_date=$(date '+%Y%m%d')
	else
		date=$(date -d '+1 day' '+%Y%m%d')
		db_date=$(date -d '+1 day' '+%Y/%m/%d')
		param="?date=${date}"
		sftp_date=$(date '+%Y%m%d')
	fi
else
	date=$(date '+%Y%m%d')
	db_date=$(date '+%Y/%m/%d')
	param=""
	if [ ${c_dow} -eq 1 ] # if running on Monday, sftp date is last 3 days (Friday)
	then
		sftp_date=$(date -d '-3 day' '+%Y%m%d')
	else
		sftp_date=$(date -d '-1 day' '+%Y%m%d')
	fi
fi


### SET PARAM
# 
# We check working server base on server hostname. So hostname must content "hnx" or "hsx" to continue this script.
# Or you can specify other string to differentiate HNX and HSX server, depend on your hostname.
#
# api_port is mdds api port. Default is 5003
# api_uri is valid path of uri. Default is mdds
# api_action is action of this script. Default is bod (bod?date=Ymd denpend on running time)
# sftp_total_file_required is number of file that you downloaded everyday. script will check number of file after download and compare to this value.
# sftp_folder is woking directory path of sftp, normaly is /opt/apps/sftp/[hnx|hsx]/Ymd
# script_path is location of this script (not include / at the end)
#
if [ ${success} = 1 ]
then

	api_port=5003 				###Changeable
	api_uri=mdds 				###Changeable
	api_action=bod${param} 		###Changeable

	sftp_total_file_required_hnx=9 		###Changeable
	sftp_total_file_required_hsx=10 	###Changeable
	hostname=$(hostname)

	if echo ${hostname} | grep "hnx" 	###Changeable
	then
	    OUTPUT=${OUTPUT}$(date +%T)": Working server is HNX...%0A"
	    sftp_total_file_required=${sftp_total_file_required_hnx}
	    prefix=hnx
	elif echo ${hostname} | grep "hsx" 	###Changeable
	then
		OUTPUT=${OUTPUT}$(date +%T)": Working server is HSX...%0A"
	    sftp_total_file_required=${sftp_total_file_required_hsx}
	    prefix=hsx
	else
	    OUTPUT=${OUTPUT}$(date +%T)": Cannot run this script on this server: ${hostname} .%0A"
		success=-1
		prefix=_
	fi

	sftp_folder=/opt/apps/sftp/${prefix}/${sftp_date} 		###Changeable
	script_path=/opt/apps/script 		###Changeable

	OUTPUT=${OUTPUT}"%0A"
	OUTPUT=${OUTPUT}$(date +%T)": - BOD date: ${date}%0A"
	OUTPUT=${OUTPUT}$(date +%T)": - DoW: ${c_dow} - $(date +%a)%0A"
	OUTPUT=${OUTPUT}$(date +%T)": - API URL: http://localhost:${api_port}/${api_uri}/${api_action}%0A"
	OUTPUT=${OUTPUT}$(date +%T)": - Number of SFTP file expected: ${sftp_total_file_required}%0A"
	OUTPUT=${OUTPUT}$(date +%T)": - SFTP local path: ${sftp_folder}%0A"
	OUTPUT=${OUTPUT}$(date +%T)": - Script location: ${script_path}%0A"
	OUTPUT=${OUTPUT}$(date +%T)": - Logs location: ${logs_path}%0A"
	OUTPUT=${OUTPUT}"%0A"
fi

### ========== ###
### ========== ###
# Uncomment following 2 lines, and manual run this script (not in protect time you set above) to print all param to stdout and re-check if needed.
# This action does not make any effect to MDDS date.
# Manual run by this command: sudo sh krx.bod.sh
#
#echo ${OUTPUT} | sed -r 's/%0A/\n/g' 	#uncomment this
#exit 	#uncomment this
#
### ========== ###
### ========== ###

### CHECK SYSTEM SERVICE
# Check that mdds service is running or not.
#
if [ ${success} = 1 ]
then
	OUTPUT=${OUTPUT}$(date +%T)": Checking MDDS service....%0A"
	check=$(curl -X GET --connect-timeout 20 "http://localhost:${api_port}/${api_uri}/status" -H "accept: */*")
	OUTPUT=${OUTPUT}${check}"%0A"

	if ! echo ${check} | grep "\"code\":\"OK\""
	then
		OUTPUT=${OUTPUT}$(date +%T)": MDDS service does not response...%0A"
		OUTPUT=${OUTPUT}$(date +%T)": Checking MDDS service: FAILED%0A"
		success=-1
	else
		OUTPUT=${OUTPUT}$(date +%T)": Checking MDDS service: PASS%0A"
	fi
fi
OUTPUT=${OUTPUT}"%0A"

### REMOVE CURRENT CRON JOB
# Get current time: hour and minute for cron
# Round minute for crontab. We just create and check crontab at every 30 minutes.
#
if [ ${success} = 1 ]
then
	if [ ${c_minute} -ge 30 ]
	then
		c_minute_round_pass=30
		c_minute_round_fu=00
	else
		c_minute_round_pass=00
		c_minute_round_fu=30
	fi

	if grep -q "auto_bod_crontab" /etc/crontab
	then
		#Remove auto genarate crontab. We will re-gen later if download failed.
		#Backup crontab file also
		OUTPUT=${OUTPUT}"===========================================%0A"
	    cp /etc/crontab /etc/crontab.${c_hour}${c_minute}.bk
		OUTPUT=${OUTPUT}$(date +%T)": Attempt to run auto_crontab: ${c_hour}:${c_minute_round_pass}%0A"
		awk '!/auto_bod_crontab/' /etc/crontab > ~/auto_cron_temp && mv ~/auto_cron_temp /etc/crontab
	fi
fi

### CHECK FILES EXIST
# If files are not exist, add crontab to redownload later.
# We also check if total files after download are less then ${total_files_download}
# If you dont want to redownload, just add comment out these lines by adding # at every first line.
#
if [ ${success} = 1 ]
then
	OUTPUT=${OUTPUT}$(date +%T)": Checking SFTP files....%0A"
	numfile=$(ls ${sftp_folder} | wc -l)
	OUTPUT=${OUTPUT}$(date +%T)": Number of SFTP file after download: ${numfile}%0A"
	if [ ${numfile} -lt ${sftp_total_file_required} ]
	then
		OUTPUT=${OUTPUT}$(date +%T)": Missing file in SFTP folder. Try to BOD later...%0A"
		OUTPUT=${OUTPUT}$(date +%T)": Checking SFTP files: FAILED%0A"
		success=0
	else
		OUTPUT=${OUTPUT}$(date +%T)": Checking SFTP files: PASS%0A"
		success=1
	fi
fi


### CHECK STATUS
# Only BOD if MDDS is STOP. If it's running, check current DB date.
# If current DB date is new date, do nothing and exit script.
# If current DB date is old date, STOP MDDS.
#
if [ ${success} = 1 ]
then
	OUTPUT=${OUTPUT}"%0A"
	OUTPUT=${OUTPUT}$(date +%T)": Checking for DB date...%0A"
	check_date=$(curl -X GET --connect-timeout 20 "http://localhost:${api_port}/${api_uri}/date" -H "accept: */*")
	OUTPUT=${OUTPUT}${check_date}"%0A"

	if echo ${check_date} | grep "Database date: ${db_date}"
	then
		OUTPUT=${OUTPUT}"%0A"
		OUTPUT=${OUTPUT}$(date +%T)": MDDS is BOD already. Nothing to do.%0A"
		success=-1
	else
		OUTPUT=${OUTPUT}"%0A"
		OUTPUT=${OUTPUT}$(date +%T)": DB date is valid to BOD....%0A"
		OUTPUT=${OUTPUT}$(date +%T)": Checking MDDS status....%0A"
		status=$(curl -X GET --connect-timeout 20 "http://localhost:${api_port}/${api_uri}/status" -H "accept: */*")
		OUTPUT=${OUTPUT}${status}"%0A"

		if echo ${status} | grep "\"data\":{\"status\":\"RUNNING\""
		then
			OUTPUT=${OUTPUT}"%0A"
			OUTPUT=${OUTPUT}$(date +%T)": MDDS is in RUNNING state. Stopping MDDS for BOD..."
			OUTPUT=${OUTPUT}$(curl -X GET --connect-timeout 20 "http://localhost:${api_port}/${api_uri}/stop" -H "accept: */*")
		fi
	fi
fi

### DO BOD IF ALL SUCCESS
if [ ${success} = 1 ]
then
	OUTPUT=${OUTPUT}"%0A"
	OUTPUT=${OUTPUT}$(date +%T)": Start BOD...%0A"
    response=$(curl -X GET --connect-timeout 20 "http://localhost:${api_port}/${api_uri}/${api_action}" -H "accept: */*")
    OUTPUT=${OUTPUT}${response}"%0A"

    if ! echo  ${response} | grep "\"code\":\"OK\""
    then
    	OUTPUT=${OUTPUT}"%0A"
    	OUTPUT=${OUTPUT}"BOD failed... Try to BOD in next 30 minutes....%0A"
        success=0
    fi
fi

### GENERATE NEW CRONTAB
# Create new crontab if all above checks are failed
# Last cron job will be created at 7h30 AM everyday. After that, this loop will be stopped even task is success or not.
#
if [ ${success} = 0 ]
then
	if [ ${c_hour} -ge 7 ] && [ ${c_hour} -lt 18 ]
	then
		OUTPUT=${OUTPUT}$(date +%T)": Cannot BOD MDDS. Check log file for more detail. Exitting...%0A"
	else
		OUTPUT=${OUTPUT}$(date +%T)": Adding new crontab....%0A"
		if [ ${c_minute_round_pass} -eq 30 ]
		then
			c_hour_new=$((${c_hour}+1))
   			if [ ${c_hour_new} -eq 24 ]
      		then
				c_hour_new=00
  			fi
		else
			c_hour_new=${c_hour}
		fi
		echo "${c_minute_round_fu} ${c_hour_new} * * 1-6 root sh ${script_path}/krx.bod.sh #auto_bod_crontab.log" | tee -a /etc/crontab

	fi
elif  [ ${success} = 1 ]
then
	date=$(curl -X GET --connect-timeout 20 "http://localhost:${api_port}/${api_uri}/date" -H "accept: */*")
	OUTPUT=${OUTPUT}${date}"%0A"
	OUTPUT=${OUTPUT}"%0A"
    OUTPUT=${OUTPUT}$(date +%T)": BOD complete.....%0A"
	echo ${date}
	OUTPUT=${OUTPUT}"%0A"
    OUTPUT=${OUTPUT}$(date +%T)": Exiting.....%0A"
    OUTPUT=${OUTPUT}"%0A"
else
	OUTPUT=${OUTPUT}"%0A"
    OUTPUT=${OUTPUT}$(date +%T)": Exiting.....%0A"
    OUTPUT=${OUTPUT}"%0A"
fi
OUTPUT=${OUTPUT}"%0A"
OUTPUT=${OUTPUT}"%0A"


### OUTPUT SETTING
#
# Telegram
# Uncomment these lines for sending all output to Telegram
#
echo $(date +%T)": Send Telegram notification...."

CHAT_TOKEN="1780537418:AAH-2vpNHEjX4M7DvNTHhvMj1jzaw5pzb9w"
CHAT_ID="-463661337"
curl -s -X POST https://api.telegram.org/bot$CHAT_TOKEN/sendMessage -d chat_id=$CHAT_ID -d text="$OUTPUT" > /dev/null

# Email
# 
# Uncomment these lines for sending all output via Email
# We use muttutil for sendding email
# Install by: apt update -y && apt install -y mutt
# Or download at: http://www.mutt.org/download.html
#
# Config Mutt by add these line to /etc/Muttrc:
# set smtp_url = "smtp[s]://mail@mail.com:password@mail_server:port"
# set from='mail@mail.com'
# set realname='KRX Notification'
#
# Test send mail by: echo "test" | mutt -s "Subject" -- recipients@mail.com 
# Multiple recipients seprate by comma: a@mail.com,b@mail.com
#
echo $(date +%T)": Send email notification...."

mailto=it@dag.vn
subject="[KRX] BOD job notification"

checkmutt=$(mutt -version > /dev/null)
if echo ${checkmutt} | grep "Command 'mutt' not found"
then
	OUTPUT=${OUTPUT}"%0A"
	OUTPUT=${OUTPUT}$(date +%T)": Mutt Util is not installed on your server. Cannot send email....%0A"
	OUTPUT=${OUTPUT}"%0A"
else
	echo ${OUTPUT} | sed -r 's/%0A/\n/g' | mutt -s "${subject}" -- ${mailto}
fi


## Write log file
# Defaul is output to log file
# Optional is send message to telegram or email.
# Create logs folder if not exist
#
if [ ! -d ${logs_path} ]
then
	OUTPUT=${OUTPUT}"%0A"
	OUTPUT=${OUTPUT}$(date +%T)": Logs folder is not exist. Create logs folder....%0A"
	mkdir ${logs_path} -p
fi

echo ${OUTPUT} | sed -r 's/%0A/\n/g' | tee -a ${logs_path}/krx.bod.log





