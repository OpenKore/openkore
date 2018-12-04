#This script is taked from rAthena function.sh as a checker for files in folder.
#Modified for educational purposes.
#This file is adapted for run shell to run many openkore instances.

O_CLI=openkore.pl
INST_PATH=/opt
PKG_PATH=$INST_PATH/$PKG
NOCOLOR='\033[0m'
RED='\033[0;31m'

check_files() {
    for i in ${O_CLI}
    do
        if [ ! -f ./$i ]; then
            echo "$i doesn't exist! or you are not in openkore folder"
	    echo "Make sure you are on the right directory"
	    echo "${RED}Exiting...${NOCOLOR}"
            exit 1;
        fi
    done
}
