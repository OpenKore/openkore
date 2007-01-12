#!/bin/bash
# This script removes all files in the MediaWiki folder,
# useful for MediaWiki file upgrades.
for EXT in inc js mli css sql png gif php xsd txt manual; do
	find . -name "*.$EXT" | xargs rm
done
