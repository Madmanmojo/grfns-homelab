#!/bin/bash
# Start Calibre content server for Readarr integration
# Runs as abc user (PUID 501), port 8182, with local write enabled
su -s /bin/bash abc -c "calibre-server --port 8182 --enable-local-write --userdb /config/server-users.db --enable-auth /library &"
