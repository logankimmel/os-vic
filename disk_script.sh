#!/bin/bash -e

export TERM=xterm
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin

# Exit if the disk doesn't exist
if [ ! -e /dev/sdb ]; then exit 0; fi

echo "Creating new disk and mounting at: ${mountpath}"

# to create the partitions programatically (rather than manually)
# we're going to simulate the manual input to fdisk
# The sed script strips off all the comments so that we can
# document what we're doing in-line with the actual commands
# Note that a blank line (commented as "defualt" will send a empty
# line terminated with a newline to take the fdisk default.
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk /dev/sdb
  o # clear the in memory partition table
  n # new partition
  p # primary partition
  1 # partition number 1
    # default - start at beginning of disk
    # use entire disk
  w # write the partition table
  q # and we're done
EOF

mkfs.ext4 /dev/sdb1

mkdir -p $mountpath

mount /dev/sdb1 $mountpath

echo "${mountpath}    /data    ext4    defaults     0   0" >> /etc/fstab
