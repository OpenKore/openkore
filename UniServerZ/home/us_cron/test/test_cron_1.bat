@echo off
rem This file is used only for testing.
rem Enable block [Test_cron_1] in Cron configuration file cron.ini

rem ### working directory current folder 
pushd %~dp0
   echo Cron test 1 BAT file test >> test_cron_1_bat_result.txt
rem ### restore original working directory
popd
