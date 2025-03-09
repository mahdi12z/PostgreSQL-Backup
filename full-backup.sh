```sh
#!/bin/bash

# Define the name of the PostgreSQL pod and the namespace in which it is running.
# These details are required to interact with the correct database instance within Kubernetes.
POD_NAME="postgres-timescaldb-0"
NAMESPACE="ns-production2"

# Define PostgreSQL connection details.
# PGUSER: The username used to connect to PostgreSQL.
PGUSER="**"

# Define the directory where backups will be stored locally.
# The script ensures that this directory exists before proceeding.
BACKUP_DIR="/home/**/postgres_backup/full_backup"
mkdir -p "$BACKUP_DIR"

# Define the backup retention policy (number of days to keep old backups).
# Any backups older than this number of days will be deleted after the backup process is completed.
RETENTION_DAYS=7

# Generate a timestamp to append to the backup directory name.
# This ensures that each backup is uniquely named and prevents overwriting previous backups.
DATE=$(date +%F_%H-%M-%S)
BACKUP_PATH="$BACKUP_DIR/fullbackup_$DATE"

# Print a message indicating the start of the full backup process.
echo "Starting full PostgreSQL backup in Kubernetes..."

# Execute the `pg_basebackup` command inside the Kubernetes pod to take a full server backup.
# This command creates a physical backup of the entire PostgreSQL database instance.
kubectl exec -n $NAMESPACE $POD_NAME -- pg_basebackup -D "/tmp/fullbackup" -Fp -Xs -P -U $PGUSER -R

# Check if the backup process was successful by examining the exit status of the previous command.
if [[ $? -eq 0 ]]; then
    echo "Full backup successfully taken inside the pod. Now transferring to local storage..."

    # Copy the backup files from the Kubernetes pod to the local Linux server.
    kubectl cp $NAMESPACE/$POD_NAME:/tmp/fullbackup $BACKUP_PATH

    # Remove the temporary backup files from the pod to free up space.
    kubectl exec -n $NAMESPACE $POD_NAME -- rm -rf /tmp/fullbackup

    # Print a message indicating where the backup has been stored on the local machine.
    echo "Full backup stored at: $BACKUP_PATH"
else
    # If the backup process fails, print an error message and exit the script with a failure status.
    echo "Backup process failed!"
    exit 1
fi

# Perform cleanup by removing old backups that are older than the defined retention period.
# The `find` command searches for backup directories older than `RETENTION_DAYS` and deletes them.
echo "Removing backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -type d -mtime +$RETENTION_DAYS -exec rm -rf {} \;

# Print a message indicating that old backups have been successfully removed.
echo "Old backups cleaned up."

# Print a final message indicating that the backup process is complete.
echo "Full backup process completed successfully!"
```
