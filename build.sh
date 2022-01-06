#!/bin/bash
set -e

rm -fr *.deb
cp control pinormos-streamer-router/streamer-router-deb/DEBIAN/.
pinormos-streamer-router/gen-deb.sh
rm -fr streamer_router_deb.tar.gz
tar -zcf streamer_router_deb.tar.gz *
