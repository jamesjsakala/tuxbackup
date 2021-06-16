# tuxbackup
A Quick Bash Shell Script To Backup Data to Remote NFS Share or SSH Server

# Installation
   **sudo apt-get install msmtp msmtp-mta ca-certificates mutt nfs-common bzip2 -y**
   
   **mkdir -p /etc/jtuxbackup/ssh-keys &&  ssh-keygen -f /etc/jtuxbackup/ssh-keys/jtuxbackup-light-sshkey**
   
   **chmod +x jtuxbackup.sh**



# Install Script
  ./jtuxbackup.sh install  
    


# Edit The configuration file and Enable What You Need
    nano /etc/jtuxbackup/jtuxbackup.sh.conf



# If You Wish to Backup MySQL/MariaDB. Run Query in MySQL/MariaDB
   *CREATE USER 'dbbackupusr'@'localhost' IDENTIFIED BY 'ComplexPassword';*
   *GRANT ALL ON *.*  TO 'jdbbackupusr'@'localhost;*
   *FLUSH PRIVILEGES;*
   *EXIT;* 



# Create Cron Job
   crontab -e



# Add A Job To Run At midnight
   0 1 * * *  /usr/bin/jtuxbackup.sh backup "/etc/jtuxbackup.sh/jtuxbackup.sh.conf" ###at midnight every day
