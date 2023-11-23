1. Script will run on both HNX and HSX server.
2. If all conditions (check time, check sftp) are failed:  
        - Auto create cron job and rerun after every 30 minutes. These cron job will be remove if running complete.  
        - Script will run from start (00h30 as we specify) to 8h00 next day. After that, this will stop create cron job at last run.
        - Some backup of crontab file also created in /etc (/etc/crontab.xxxx.bk), so you can remove all of this backup file with: rm /etc/crontab.*.bk
        - Script will not run after $not_after and before $not_before. These value you must config following also.
4. Requires:    
	- Tested on Ubuntu 20    
	- Script must run as root    
	- Server hostname should contains "hnx" or "hsx" for detecting working server  
    
5. Specific these values in SET PARAM block:    
	- sftp_total_file_required    
	- sftp_folder    
	- api_port    
	- api_uri     
	- sftp_folder  
	- api_action  
    
6. To use just adding directly to /etc/crontab file (change the path if needed):    
 _30 00 * * * root sh /opt/apps/script/krx.bod.sh | tee -a /opt/apps/script/logs/krx.bod.log_

  
