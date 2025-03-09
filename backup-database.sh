```sh
#!/bin/bash

# Define the name of the PostgreSQL pod and the namespace in which it is running.
# This is necessary to identify the correct database instance within Kubernetes.
POD_NAME="postgres-timescaldb-0"
NAMESPACE="ns-production2"

# Define PostgreSQL connection details.
# PGUSER: The username used to connect to PostgreSQL.
# PGHOST: The host where PostgreSQL is running (in this case, inside the Kubernetes pod).
# PGPORT: The port used to communicate with PostgreSQL (default is 5432).
PGUSER="**"
PGHOST="localhost"
PGPORT="5432"

# Define the directory where backups will be stored locally.
# The script ensures that this directory exists before proceeding.
BACKUP_DIR="/home/**/postgres_backup/backup"
mkdir -p "$BACKUP_DIR"

# Generate a timestamp to append to the backup filenames.
# This ensures that each backup is uniquely named and prevents overwriting previous backups.
DATE=$(date +%F_%H-%M-%S)

# Retrieve a list of all PostgreSQL databases that are not template databases.
# This allows the script to back up only user-created databases.
DATABASES=$(kubectl exec -n $NAMESPACE $POD_NAME -- psql -U $PGUSER -d postgres -t -c "SELECT datname FROM pg_database WHERE datistemplate = false;")

# Loop through each database retrieved and perform a backup.
for DB in $DATABASES; do
    # Trim any extra spaces from the database name.
    DB=$(echo $DB | xargs)

    # Define the backup file path for the current database.
    BACKUP_FILE="$BACKUP_DIR/${DB}_$DATE.backup"

    # Check if the TimescaleDB extension is installed in the database.
    HAS_TIMESCALEDB=$(kubectl exec -n $NAMESPACE $POD_NAME -- psql -U $PGUSER -d $DB -t -c "SELECT COUNT(*) FROM pg_extension WHERE extname = 'timescaledb';" | xargs)

    # Print a message indicating which database is being backed up.
    echo "Backing up database: $DB"

    # If the TimescaleDB extension is detected, apply a TimescaleDB-specific backup strategy.
    if [[ "$HAS_TIMESCALEDB" -gt 0 ]]; then
        echo "TimescaleDB detected in $DB. Using TimescaleDB-specific backup..."
        kubectl exec -n $NAMESPACE $POD_NAME -- pg_dump -h $PGHOST -p $PGPORT -U $PGUSER -d $DB --format=custom --no-owner --no-privileges --file="/tmp/$DB.backup"
    else
        echo "TimescaleDB not detected in $DB. Using standard PostgreSQL backup..."
        kubectl exec -n $NAMESPACE $POD_NAME -- pg_dump -h $PGHOST -p $PGPORT -U $PGUSER -d $DB --format=custom --no-owner --no-privileges --file="/tmp/$DB.backup"
    fi

    # Copy the backup file from the Kubernetes pod to the local machine.
    kubectl cp $NAMESPACE/$POD_NAME:/tmp/$DB.backup $BACKUP_FILE

    # Remove the temporary backup file from the pod to free up space.
    kubectl exec -n $NAMESPACE $POD_NAME -- rm -f /tmp/$DB.backup

    # Print a message indicating that the backup for this database is complete.
    echo "Backup for $DB completed and stored at: $BACKUP_FILE"
done

# Define the archive filename, which includes the current timestamp.
ARCHIVE_FILE="$BACKUP_DIR/postgres_backup_$DATE.tar.gz"

# Create a compressed tar archive of all backup files in the backup directory.
# The script excludes existing archive files to prevent redundant compression.
echo "Creating archive: $ARCHIVE_FILE"
tar -czf "$ARCHIVE_FILE" -C "$BACKUP_DIR" --exclude="*.tar.gz" .

# Verify if the archive was successfully created.
if [[ -f "$ARCHIVE_FILE" ]]; then
    echo "Archive created successfully. Now removing individual backup files..."

    # If the archive was created successfully, remove individual backup files to save space.
    find "$BACKUP_DIR" -type f -name "*.backup" -delete
else
    echo "Archive creation failed! Backup files will not be deleted."
fi

# Print a final message indicating that the backup process is complete.
echo "Backup process completed successfully!"

```
