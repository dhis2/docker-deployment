#!/usr/bin/env bash
set -euo pipefail

TARGET_SIZE=${TARGET_SIZE:-$((10 * 1024 * 1024 * 1024))}
THREADS=${THREADS:-4}
CHUNK_SIZE=${CHUNK_SIZE:-$((TARGET_SIZE / THREADS))}

MIN_SIZE=${MIN_SIZE:-$((10 * 1024))}
MAX_SIZE=${MAX_SIZE:-$((5 * 1024 * 1024))}

OUTDIR=${OUTDIR:-"/opt/dhis2/files/generated_files"}
mkdir -p "$OUTDIR"

generate_files() {
    thread_id=$1
    target=$2
    current_size=0
    file_index=1

    while [ "$current_size" -lt "$target" ]; do
        size=$(( RANDOM * (MAX_SIZE - MIN_SIZE) / 32767 + MIN_SIZE ))

        if (( current_size + size > target )); then
            size=$(( target - current_size ))
        fi

        filename="$OUTDIR/t${thread_id}_file_${file_index}.bin"
        head -c "$size" /dev/urandom > "$filename"

        current_size=$((current_size + size))

        if (( file_index % 100 == 0 )); then
            echo "Thread $thread_id: created $file_index files, total: $(numfmt --to=iec-i $current_size)"
        fi
        file_index=$((file_index + 1))
    done
}

echo "Generating ~$(numfmt --to=iec-i "$TARGET_SIZE") bytes across $THREADS threads..."
for t in $(seq 1 "$THREADS"); do
    generate_files "$t" "$CHUNK_SIZE" &
done
wait

echo "✅ Done! Files are in $OUTDIR"
