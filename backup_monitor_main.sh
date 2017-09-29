#! /bin/bash

#Input handling
deep=0
if [ $# == 1 ]
then
    if [ "$1" != "-deep" ]
    then
	echo "Usage : backup_monitor.sh [-deep]"
	exit 9
    else
	echo 'Running deep test'
	deep=1
    fi
fi
if [ $# -gt 1 ]
then
    echo "Usage : backup_monitor.sh [-deep]"
    exit 9
fi

## Variables
host='bob'
series_num=1
loop_num=1
date_h=$(date +%Y-%m-%d)
date_e=$(date -d $date_h +%s)
file_date=''
file_group_date=''
date14=(60*60*24*14) # 14 days in seconds
newest_match=''
failLog='error_Log_backup.txt'
email_log='temp_log.txt'
backup_admin='dhayes@e115.chtc.wisc.edu'
errors=0

## Prep Email
echo "Good Morning Backup Administrator," >> $email_log
echo "The following errors were found during the backup check today "$date_h >> $email_log
echo " " >> $email_log 

echo 'date ='$date_h
#echo 'date epoch = '$date_e
while read i
do   
    #echo 'loop # '$loop_num    
    let 'loop_num++'
    #echo $i' ---what was read'
    
    ##check if folder is there 
    if [ ! -d ./$i ]
    then
	echo "Error : No folder for host "$i
	echo $(date +"%Y-%m-%d_%T") $i ' : has no backup folder' | tee -a $email_log >> $failLog
	errors=1
	continue
    fi
    
    ##check if any files are here
    if [ -z "$( ls $i )" ] 
    then
	echo "Error : there are no files in host folder "$i
	echo $(date +"%Y-%m-%d_%T") $i ' : backup folder contained no files' | tee -a $email_log >> $failLog
	errors=1
	continue
    fi
    
    ##get newest file matching the scheme
    host=$(echo $i | sed s=\\.=_=g )
    newest_match=$(ls -t $i/*$host* | head -1 | awk -F"/" '{print $2}') 

    ##check if there was a matching file 
    if [ -z "$(echo $newest_match | grep $host)" ] 
    then
	echo 'Error : there were no files matching the expected schema of '$host
	echo $(date +"%Y-%m-%d_%T") $host ' : backup folder contained no files that matched the expected schema of '$host | tee -a $email_log >> $failLog
	errors=1
	continue
    fi

    ##get file date of newest file
    file_date=$(date -r $i/$newest_match +%F) 
    #file_date=2014-10-22

    ##check if that is todays date
    if [ ! $date_h = $file_date ]
    then
	echo 'Error : backup has not run for host '$i
	echo $(date +"%Y-%m-%d_%T") $i ' : backup was not run today, '$date_h', for host '$i | tee -a $email_log  >> $failLog
	errors=1
    fi

    ##get date of file_group date
    file_group_date=$(echo $newest_match | awk -F"." '{print $1}' | awk -F"_" '{print $NF}')
    file_group_date=$(date -d $file_group_date +%s)
    date=$(date -d $date_h +%s)

    ##check if file date < file_group_date +14
    two_weeks_ago=$(date -d @$((date - date14 )) +%s )
    
    if [ $two_weeks_ago -gt $file_group_date ]
    then
	echo 'Error : current backup of '$i ' is more than 2 weeks old.'
    	echo $(date +"%Y-%m-%d_%T") $i ' : backup run today is more than 2 weeks older than the first in the series.' | tee -a $email_log >> $failLog 
	errors=1
    fi

    ##check if file size is > 0
    size=$(stat -c %s $i/$newest_match)
    if [ 0 -gt $size ]
    then
	echo 'Error : file has no size'
	echo $(date +"%Y-%m-%d_%T") $i ' : backup run today has a size of 0 or less.' | tee -a $email_log >> $failLog
	errors=1
    fi
    cur_series=$(echo $newest_match | awk -F"." '{print $1}' )
    first=$cur_series'.1.backup'
    size=$(stat -c %s $i/$first)
    if [ 0 -gt $size ]
    then
	echo 'Error : '$first ', the first file in the series as no size'
	echo $(date +"%Y-%m-%d_%T") $i ' : backup of the first backup of the series has a size of 0 or less.' | tee -a $email_log >> $failLog
	errors=1
    fi

    ##get backup series number
    series_num=$(echo $newest_match | awk -F"." '{print $2}' )
    
    ##check if all the previous in the series are there #TODO
    if [ $deep -eq 1 ]
    then
	echo going deep
	let 'series_num--'
	while [ $series_num -gt 1 ]
	do
	    first=$cur_series'.'$series_num'.backup'
	    #echo 'first = ' $first
	    size=$(stat -c %s $i/$first)
	    if [ 0 -gt $size ]
	    then
		echo 'Error : '$first ', the first file in the series as no size'
		echo $(date +"%Y-%m-%d_%T") $i ' : the backup '$first' has a size of 0 or less.' | tee -a $email_log >> $failLog
		errors=1
	    fi  
	done
    #do
	newest_match='' #TODO
	size=$(stat -c %s $i/$newest_match)
    #done
    
    host=$host"_"$date_h"."$series_num.backup
    fi
done < "./hosts"

##send error report
#cat $email_log | mail -s "Backup ERROR" $backup_admin
if [ $errors -eq 1 ]
then
    mail -s "Backup ERROR" $backup_admin < $email_log
fi

rm $email_log

exit 0
# option, double check that it works for the different dates.
