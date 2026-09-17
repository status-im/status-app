## This script runs the app in a loop for `TOTAL_NUM_OF_TRIES` times and closes it
## after each successful run. If all runs go well, script will place a success message,
## otherwise you will get an error and an info in which  run an error occurred.
##
## Tested on MacOs!
##
## You need to build the app before running this script.

TOTAL_NUM_OF_TRIES=100
COUNTER=0
RES=1
PID=-1

function checkSuccess {
  if [ "$RES" -eq "0" ]; then
    printf "\x1B[1;32m$1\x1B[0m\n";
  else
    printf "\x1B[1;31m$2\x1B[0m\n"; exit 1
  fi
}

while [ $COUNTER -lt $TOTAL_NUM_OF_TRIES ]
do
  echo "------------------------------------"
  ((COUNTER=COUNTER+1))
  echo "Running the app..."
  export LD_LIBRARY_PATH=.statusgo-build/build/bin:.statusgo-build/.sds-build/build${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
  ./bin/nim_status_client &
  PID=$!
  sleep 4
  output=$(ps -p "$PID")
  RES=$?
  checkSuccess "App successfully started in PID{$PID} for the $COUNTER. time" "An error starting the app occurred in $COUNTER. try"
  echo "Closing the app..."
  kill -9 $PID
  sleep 3
  echo "------------------------------------"
done

printf "\x1B[1;32m ALL $TOTAL_NUM_OF_TRIES TRIES WERE SUCCESSFUL! \x1B[0m\n";