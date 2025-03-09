```sh
#!/bin/bash

# Define the remote server (IP address) where the GitLab PostgreSQL backups are stored.
# This server is responsible for hosting the backups that will be transferred.
REMOTE_SERVER="***"

# Define the remote directory on the source server that contains the backup files.
# This is where the script will pull the backups from.
REMOTE_BACKUP_DIR="/home/aress/postgres_backup/backup"

# Define the local directory on the destination server (130) where backups will be stored.
# The script will sync the files from the remote server into this directory.
LOCAL_BACKUP_DIR="/home/aress/script_postgres"

# Define the number of days to retain old backups on the local server.
# Any backups older than this number of days will be deleted after synchronization.
RETENTION_DAYS=7

# Print a message indicating that the backup synchronization process is starting.
echo "Starting backup synchronization from ${REMOTE_SERVER} to server 130..."

# Use `rsync` to transfer new and modified backup files from the remote server to the local server.
# Options:
# -a : Archive mode (preserves permissions, symbolic links, etc.).
# -v : Verbose mode (displays progress).
# -z : Compress files during transfer to reduce bandwidth usage.
# --progress : Show progress of each file being transferred.
rsync -avz --progress aress@${REMOTE_SERVER}:${REMOTE_BACKUP_DIR}/ ${LOCAL_BACKUP_DIR}/

# Check if the transfer was successful by examining the exit status of `rsync`.
if [ $? -eq 0 ]; then
    echo "Backups successfully retrieved."
else
    echo "Error retrieving backups from server ${REMOTE_SERVER}!"
    exit 1
fi

# Remove old backups from the local server that exceed the defined retention period.
# The `find` command searches for files older than `RETENTION_DAYS` and removes them.
echo "Removing backups older than ${RETENTION_DAYS} days on server 130..."
find ${LOCAL_BACKUP_DIR} -type f -mtime +${RETENTION_DAYS} -exec rm -f {} \;

# Print a final message indicating that the backup synchronization and cleanup process is complete.
echo "Backup synchronization and cleanup process completed successfully."
```
