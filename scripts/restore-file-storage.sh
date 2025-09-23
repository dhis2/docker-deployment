#!/bin/sh

set -o errexit

if [ -z "$FILE_STORAGE_RESTORE_SOURCE_DIR" ]; then
  echo 'Error: FILE_STORAGE_RESTORE_SOURCE_DIR environment variable must be set'
  exit 1
fi

# Add trailing slash to ensure content of the folder is copied rather than the folder itself
SRC=/backups/$FILE_STORAGE_RESTORE_SOURCE_DIR/

if [ ! -d "$SRC" ]; then
  echo "Error: Restore directory $SRC not found"
  exit 1
fi

rclone copy "$SRC" "$RESTORE_DESTINATION_PATH" --verbose --create-empty-src-dirs

echo 'File storage restore completed successfully'
