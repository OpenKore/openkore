#This script is taked from rAthena function.sh as a checker for files in folder.
#Modified for educational purposes.
#This file is adapted for run shell to run many openkore instances.

O_CLI=openkore.pl
INST_PATH=/opt
PKG_PATH=$INST_PATH/$PKG

check_files() {
    for i in ${O_CLI}
    do
        if [ ! -f ./$i ]; then
            echo "$i does not exist... exiting..."
            exit 1;
        fi
    done
}
