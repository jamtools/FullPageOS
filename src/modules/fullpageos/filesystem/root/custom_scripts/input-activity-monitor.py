#!/usr/bin/env python3
"""
Input Activity Monitor - Monitors all input devices for activity
Writes the timestamp of the last activity to a file for consumption by other processes
"""

import select
import sys
import time
import glob
import os

TIMESTAMP_FILE = "/tmp/last_input_activity"

def find_input_devices():
    """Find all readable input event devices"""
    devices = []
    for device_path in glob.glob("/dev/input/event*"):
        try:
            # Try to open device for reading
            fd = os.open(device_path, os.O_RDONLY | os.O_NONBLOCK)
            devices.append((device_path, fd))
        except (OSError, PermissionError):
            pass
    return devices

def update_timestamp():
    """Update the timestamp file with current time in milliseconds"""
    timestamp_ms = int(time.time() * 1000)
    try:
        with open(TIMESTAMP_FILE, 'w') as f:
            f.write(str(timestamp_ms))
    except IOError as e:
        print(f"Error writing timestamp: {e}", file=sys.stderr)

def main():
    devices = find_input_devices()

    if not devices:
        print("Error: No readable input devices found", file=sys.stderr)
        sys.exit(1)

    print(f"Monitoring {len(devices)} input devices:")
    for path, _ in devices:
        print(f"  - {path}")
    sys.stdout.flush()

    # Initialize timestamp
    update_timestamp()

    # Create poll object
    poll = select.poll()
    for _, fd in devices:
        poll.register(fd, select.POLLIN)

    try:
        while True:
            # Wait for activity on any device (timeout 1 second to periodically check)
            events = poll.poll(1000)

            if events:
                # Activity detected on at least one device
                update_timestamp()

                # Consume the events to clear the buffer
                for _, fd in devices:
                    try:
                        # Read and discard data
                        os.read(fd, 4096)
                    except (OSError, BlockingIOError):
                        pass

    except KeyboardInterrupt:
        print("\nStopping input monitor...")
    finally:
        # Clean up file descriptors
        for _, fd in devices:
            try:
                os.close(fd)
            except OSError:
                pass

if __name__ == "__main__":
    main()
