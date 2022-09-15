#!/bin/bash
set -e

rm -fr *.deb
cp control pinormos-streamer-router/streamer-router-deb/DEBIAN/.
pinormos-streamer-router/gen-deb.sh
rm -fr pinormos-streamer-router/streamer-router-deb/DEBIAN/control
