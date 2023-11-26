## Info
1. Script will run on both HNX and HSX server.
2. If all conditions (check time, check sftp) are failed:  
        - Auto create cron job and rerun after every 30 minutes. These cron job will be remove if running complete.  
        - Script will run from start (00h30 as we specify) to 8h00 next day. After that, this will stop create cron job at last run.  
        - Some backup of crontab file also created in /etc (/etc/crontab.xxxx.bk), so you can remove all of this backup file with: rm /etc/crontab.*.bk  
        - Script will not run after $not_after and before $not_before. These value you must config following also.

3. Requires:    
	- Tested on Ubuntu 20    
	- Script must run as root    
    
4. Specific values in SET PARAM block with tag ###Changeable:    
 
## Use    
To use just put script at /opt/apps/script/ then adding directly to /etc/crontab file (change the path if needed):    
 _00 23 * * * root sh /opt/apps/script/krx.bod.sh_

## Notification

1. Telegram
- Uncomment these lines, fill CHAT_TOKEN and CHAT_ID:  
CHAT_TOKEN=""  
CHAT_ID=""  
curl -s -X POST https://api.telegram.org/bot$CHAT_TOKEN/sendMessage -d chat_id=$CHAT_ID -d text="$OUTPUT" > /dev/null  
  
2. Email  
- Install mutt by: apt update -y && apt install -y mutt  
- Config mutt (global config for all user) by add these lines at the end of /etc/Muttrc:  
_set smtp_url = "smtps://mail@example.com:password@mail.example.com:465"  
set from='krx.notification@dag.vn'  
set realname='KRX Notification'_
  
- Uncomment these lines, fill mailto:  
_mailto=mail@example.com  
subject="[KRX] BOD job notification"  
checkmutt=$(mutt -version > /dev/null)  
if echo ${checkmutt} | grep "Command 'mutt' not found"  
then  
    OUTPUT=${OUTPUT}"%0A"  
    OUTPUT=${OUTPUT}$(date +%T)": Mutt Util is not installed on your server. Cannot send email....%0A"  
    OUTPUT=${OUTPUT}"%0A"  
else  
    echo ${OUTPUT} | sed -r 's/%0A/\n/g' | mutt -s "${subject}" -- ${mailto}  
fi_  
