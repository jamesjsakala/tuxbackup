# tuxbackup
A Quick Bash Shell Script To Backup Data to Remote NFS Share or SSH Server

# Installation / Requirements
   sudo apt-get install msmtp msmtp-mta ca-certificates mutt nfs-common bzip2 -y
   
   mkdir -p /etc/jtuxbackup/ssh-keys &&  ssh-keygen -f /etc/jtuxbackup/ssh-keys/jtuxbackup-light-sshkey
   
   chmod +x jtuxbackup.sh



# Install Script
  ./jtuxbackup.sh install  
    


# Edit the main configuration file and enable what you need
    nano /etc/jtuxbackup/jtuxbackup.sh.conf



# If you want to backup MySQL/MariaDB. Run query below
   *CREATE USER 'dbbackupusr'@'localhost' IDENTIFIED BY 'ComplexPassword';*
   *GRANT ALL ON *.*  TO 'jdbbackupusr'@'localhost;*
   *FLUSH PRIVILEGES;*
   *EXIT;* 


# If you want email notifications
    nano /etc/msmtprc
    
    nano /etc/mailrc
    
    

# Create Cron Job
   crontab -e



# Add A Job To Run At midnight
   0 1 * * *  /usr/bin/jtuxbackup.sh backup "/etc/jtuxbackup.sh/jtuxbackup.sh.conf" ###at midnight every day
