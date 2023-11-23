#!/bin/sh
#
#NBH
#Script will run on both hnx and hsx server, and hostname of these servers must contain "hnx" or "hsx"
#Requires:
#	- Tested on Ubuntu 20
#	- Script must run as root
#
#Adding directly to /etc/crontab file (change the path if needed):
# 30 00 * * * root sh /opt/apps/script/krx.bod.sh | tee -a /opt/apps/script/logs/krx.bod.log
#Specific these values in SET PARAM block:
#	sftp_total_file_required
#	sftp_folder
#	script_path
#	api_port
#	api_uri
#	api_action
#

echo "==========================================="
echo "================ KRX BOD =================="
echo "==========================================="
echo ""

### SET SAFE TIME
# Set time that script will be safe to run. Normal after download sftp and before next start time.
#
not_before=22
not_after=8

c_hour=$(date +%H)
c_minute=$(date +%M)

if [ ${c_hour}  -ge ${not_after} ] || [ ${c_hour}  -lt ${not_before} ]
then
	echo $(date +%r)": Not in running time. Exitting..."
	sleep 1
	exit
fi

### SET PARAM
# If script run from 18h00 - 23h59 -> BOD date is next date, also add date to api param when call BOD.
# We check working server base on server hostname. So hostname must content "hnx" or "hsx" to continue this script.
# Or you can declare other string to differentiate HNX and HSX server, depend on your hostname.
#
# api_port is mdds api port. Default is 5003
# api_uri is valid path of uri. Default is mdds
# api_action is action of this script. Default is bod (bod?date=Ymd denpend on running time)
# sftp_total_file_required is number of file that you downloaded everyday. script will check number of file after download and compare to this value.
# sftp_folder is woking directory path of sftp, normaly is /opt/apps/sftp/Ymd
# script_path is location of this script (not include / at the end)

if [ ${c_hour} -ge 18 ]&& [ ${c_hour} -le 23 ]
then
	date=$(date -d '+1 day' '+%Y%m%d')
	db_date=$(date -d '+1 day' '+%Y/%m/%d')
	param="?date=${date}"
else
	date=$(date '+%Y%m%d')
	db_date=$(date '+%Y/%m/%d')
	param=""
fi
hostname=$(hostname)

api_port=5003
api_uri=mdds
api_action=bod${param}

sftp_folder=/opt/apps/sftp/${date}
sftp_total_file_required_hnx=9
sftp_total_file_required_hsx=10
script_path=/opt/apps/script

if echo ${hostname} | grep "hnx"
then
        echo $(date +%r)": Working server is HNX..."
        sftp_total_file_required=${sftp_total_file_required_hnx}
elif echo ${hostname} | grep "hsx"
then
	echo $(date +%r)": Working server is HSX..."
        sftp_total_file_required=${sftp_total_file_required_hsx}
else
        echo $(date +%r)": Cannot run this script on other server. Exitting...."
	sleep 2
        exit
fi

echo $(date +%r)": - BOD date: ${date}"
echo $(date +%r)": - API URL: http://localhost:${api_port}/${api_uri}/${api_action}"
echo $(date +%r)": - Number of file expected: ${sftp_total_file_required}"
echo $(date +%r)": - SFTP local path: ${sftp_folder}"
echo $(date +%r)": - Script location: ${script_path}"
echo ""



### CHECK SYSTEM SERVICE
# Check that mdds service is running or not.
#
echo $(date +%r)": Checking MDDS service...."
check=$(curl -X GET --connect-timeout 20 "http://localhost:${api_port}/${api_uri}/status" -H "accept: */*")
if ! echo ${check} | grep "\"code\":\"OK\""
then
	echo $(date +%r)": MDDS service does not response. Exitting...."
	sleep 1
	exit
fi
echo ""

### REMOVE CURRENT CRON JOB
# Get current time: hour and minute for cron
# Round minute for crontab. We just create and check crontab at every 30 minutes.
# check if system date format is 24 hours
if ! grep -q "LC_TIME=\"C.UTF-8\"" /etc/default/locale
then
	echo $(date +%r)": System date format is not set to 24 hours. We recommend to use 24 hours format for this script working perfectly."
	echo $(date +%r)": Modify LC_TIME...."
	echo "LC_TIME=\"C.UTF-8\"" | tee -a /etc/default/locale
fi
echo ""

if [ ${c_minute} -ge 30 ]
then
	c_minute_round_pass=30
	c_minute_round_fu=00
else
	c_minute_round_pass=00
	c_minute_round_fu=30
fi

if grep -q "auto_crontab_reconnect" /etc/crontab
then
	#remove auto genarate crontab. we will re-gen later if download failed.
	#backup crontab file also
	echo "==========================================="
    cp /etc/crontab /etc/crontab.${c_hour}${c_minute}.bk
	echo $(date +%r)": Attempt to run auto_crontab: ${c_hour}:${c_minute_round_pass}"
	awk '!/auto_bod_crontab/' /etc/crontab > ~/auto_cron_temp && mv ~/auto_cron_temp /etc/crontab
	awk '!/auto_crontab_re-bod/' /etc/crontab > ~/auto_cron_temp && mv ~/auto_cron_temp /etc/crontab
fi

### CHECK FILES EXIST
# If files are not exist, add crontab to redownload later.
# We also check if total files after download are less then ${total_files_download}
# If you dont want to redownload, just add comment out these lines by adding # at every first line.

numfile=$(ls ${sftp_folder} | wc -l)
echo $(date +%r)": Number of file after download: ${numfile}"
if [ ${numfile} -lt ${sftp_total_file_required} ]
then
	echo $(date +%r)": Missing file in SFTP folder. Try to BOD later..."
	success=0
else
	success=1
fi


### CHECK STATUS
# Only BOD if MDDS is STOP. If it's running, check current DB date. 
# If current DB date is new date, do nothing and exit script.
# If current DB date is old date, STOP MDDS.

if [ ${success} = 1 ]
then
	echo ""
	echo $(date +%r)": Checking MDDS status...."
	status=$(curl -X GET --connect-timeout 20 "http://localhost:${api_port}/${api_uri}/status" -H "accept: */*")
	if echo ${status} | grep "\"data\":{\"status\":\"RUNNING\""
	then
		echo ""
		echo $(date +%r)": MDDS is in RUNNING state. Checking for DB date..."
		date=$(curl -X GET --connect-timeout 20 "http://localhost:${api_port}/${api_uri}/date" -H "accept: */*")
		if echo ${date} | grep "Database date: ${db_date}"
		then
			echo ""
			echo $(date +%r)": MDDS is BOD already. Nothing to do. Exitting...."
			exit
		else
			echo ""
			echo $(date +%r)": MDDS DB date is old date. Stopping MDDS for BOD...."
			curl -X GET --connect-timeout 20 "http://localhost:${api_port}/${api_uri}/stop" -H "accept: */*"
		fi
	fi
fi

### DO BOD IF ALL SUCCESS
if [ ${success} = 1 ]
then
	echo ""
	echo $(date +%r)": Start BOD..."
    response=$(curl -X GET --connect-timeout 20 "http://localhost:${api_port}/${api_uri}/${api_action}" -H "accept: */*")
    if ! echo  ${response} | grep "\"code\":\"OK\""
    then
            success=0
    fi
fi

### GENERATE NEW CRONTAB
# Create new crontab if all above checks are failed
# Last cron job will be created at 7h30 AM everyday. After that, this loop will be stopped even task is success or not.

if [ ${success} = 0 ]
then
	if [ ${c_hour} -ge 7 ] && [ ${c_hour} -lt 18 ]
	then
		echo $(date +%r)": Cannot BOD MDDS. Check log file for more detail. Exitting..."
		sleep 1
	else
		echo $(date +%r)": Adding new crontab...."
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
		echo "#auto_crontab_re-bod" | tee -a /etc/crontab
		echo "${c_minute_round_fu} ${c_hour_new} * * 1-6 root sh ${script_path}/krx.bod.sh | tee -a ${script_path}/logs/auto_bod_crontab.log" | tee -a /etc/crontab
		# Create log folder if not exist
		if [ ! -d ${script_path}/logs ]
		then
			mkdir ${script_path}/logs/ -p
		fi
	fi
else
	date=$(curl -X GET --connect-timeout 20 "http://localhost:${api_port}/${api_uri}/date" -H "accept: */*")
    echo $(date +%r)": BOD complete....."
	echo ${date}
	echo ""
    echo $(date +%r)": Exiting....."
    echo ""
fi
echo ""
echo ""
