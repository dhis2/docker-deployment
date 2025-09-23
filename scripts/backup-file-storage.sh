#!/bin/sh

set -o errexit

rclone copy "$BACKUP_SOURCE_PATH" "/backups/file-storage-${BACKUP_TIMESTAMP}" --verbose --create-empty-src-dirs

echo 'File storage backup completed successfully'
