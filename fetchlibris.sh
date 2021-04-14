#!/bin/bash

script_dir="$(dirname "$(readlink -f "$0")")"
source "$script_dir/fetchlibris.sh.conf"

# Datumformat ex. 20020401
today=`date +%Y%m%d`

# Logfiler
debug_log_file="$log_dir/debug.$today.log"
log_file="$log_dir/$today.log"

# Städa ifall gamla logfiler ligger kvar
if [ -f $debug_log_file ]; then
  mv $debug_log_file $debug_log_file.old > /dev/null
fi

if [ -f $log_file ]; then
  mv $log_file $log_file.old > /dev/null
fi

# Librisfil med dagens datum
yesterday=`/bin/date -d "-1 day" +"%Y%m%d"`
file_name="GUB.$yesterday.marc"

echo `date` "Skriptet $0 startar" > $log_file

failed_files=$(ls -tr $begun_dir)

if [ -n "$failed_files" ]; then
  echo `date` "Följande filer har tidigare försökt hämtats, men misslyckats: ${failed_files//$'\n'/, }. Försöker igen" >> $log_file
fi

# Starta fattigmanstransaktion
touch "$begun_dir/$file_name"

# Includerar även filer där tidigare hämtningar misslyckats
remote_files=$(ls -tr $begun_dir)

# Kommando för att hämta filen
ftp="/usr/bin/ncftpget -d $debug_log_file -V"

# Sökväg på LIBRIS ftp-server
server="ftp.libris.kb.se"
remote_path="/pub/export2/GUB/marc/"

cd $out_dir
for file_name in $remote_files; do
  # Hämta filen och lagra exitstatus
  echo `date` "Försöker att hämta librisfilen \"$file_name\"..." >> $log_file

  # TODO: Will probably have exit status <> 0 if file not exists
  # But if file not exists "transaction should still be ended
  # or we will never get rid of it
  ftp_command="$ftp ftp://$server$remote_path$file_name"
  ftp_command_output=`$ftp_command 2>&1`
  status=$?
  if [ -n "$ftp_command_output" ]; then
    echo `date` $ftp_command_output >> $log_file
  fi
  if [ $status -ne 0 ]; then
    # Bad practice to sniff error messages, but quick and easy
    if [[ $status -eq 3 && $ftp_command_output = *"No such file"* ]]; then
      message="Filen \"$file_name\" fanns ej att hämta, ingen fil för denna dag"
      echo `date` "$message" >> $log_file
      # Avsluta fattigmanstransaktion
      rm "$begun_dir/$file_name"
      # mailx -r "gunda@ub.gu.se" -s "GUNDA: $message" $mail_user < $log_file
    else
      # Kommer forsoka igen:
      echo `date` "\"$ftp_command\" misslyckades med felstatus $status" >> $log_file
    fi
  elif [ -f $file_name ]; then
    echo `date` "Filhämnting lyckades: " `ls -l $file_name` >> $log_file 2>&1
    # Avsluta fattigmanstransaktion
    rm "$begun_dir/$file_name"
  else
    echo `date` "\"$ftp_command\" lyckades, men fil saknas, detta borde inte kunna inträffa" >> $log_file
  fi
done

echo `date` "Skriptet avslutas" >> $log_file
