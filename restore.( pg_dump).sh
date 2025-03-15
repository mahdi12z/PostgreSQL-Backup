
```bash
#!/bin/bash

# Kubernetes pod and namespace details
POD_NAME="postgres-0"  # Name of the PostgreSQL pod
NAMESPACE="ns-production"  # Kubernetes namespace where the pod is running
PGUSER="**"  # PostgreSQL user with sufficient privileges
PGHOST="localhost"  # Database host (within the pod)
PGPORT="5432"  # Default PostgreSQL port
BACKUP_DIR="/home/*/postgres_backup"  # Directory containing backup files

# Get a list of unique database names from the latest backup files
BACKUP_DATABASES=$(ls -t $BACKUP_DIR/*.backup 2>/dev/null | awk -F'_' '{print $1}' | sort -u)

for DB in $BACKUP_DATABASES; do
    DB=$(echo $DB | xargs)  # Trim spaces

    # Find the latest backup file for the database
    BACKUP_FILE=$(ls -t $BACKUP_DIR/${DB}_*.backup 2>/dev/null | head -n 1)

    if [[ -z "$BACKUP_FILE" ]]; then
        echo "No backup found for $DB, skipping..."
        continue
    fi

    echo "Latest backup for $DB: $BACKUP_FILE"

    # Check if the database exists inside the PostgreSQL instance
    DB_EXISTS=$(kubectl exec -n $NAMESPACE $POD_NAME -- psql -U $PGUSER -d postgres -t -c "SELECT COUNT(*) FROM pg_database WHERE datname = '$DB';" | xargs)

    if [[ "$DB_EXISTS" -eq 0 ]]; then
        echo "Database $DB does not exist, creating it..."
        kubectl exec -n $NAMESPACE $POD_NAME -- psql -U $PGUSER -d postgres -c "CREATE DATABASE $DB OWNER $PGUSER;"
    else
        echo "Database $DB already exists."
    fi

    # Copy the latest backup file to the PostgreSQL pod
    kubectl cp $BACKUP_FILE $NAMESPACE/$POD_NAME:/tmp/$DB.backup

    echo "Backup copied to Pod, starting restore process..."

    # Check if TimescaleDB is installed in the database
    HAS_TIMESCALEDB=$(kubectl exec -n $NAMESPACE $POD_NAME -- psql -U $PGUSER -d $DB -t -c "SELECT COUNT(*) FROM pg_extension WHERE extname = 'timescaledb';" | xargs)

    if [[ "$HAS_TIMESCALEDB" -gt 0 ]]; then
        echo "TimescaleDB is installed, performing a normal restore..."
        kubectl exec -n $NAMESPACE $POD_NAME -- pg_restore --clean --if-exists --disable-triggers -U $PGUSER -d $DB /tmp/$DB.backup
    else
        echo "TimescaleDB is NOT installed, excluding TimescaleDB schemas during restore..."
        kubectl exec -n $NAMESPACE $POD_NAME -- pg_restore --clean --if-exists --disable-triggers --exclude-schema=_timescaledb_catalog --exclude-schema=_timescaledb_config -U $PGUSER -d $DB /tmp/$DB.backup
    fi

    echo "Backup successfully restored for $DB"
done

echo "Restore process completed successfully!"

```
