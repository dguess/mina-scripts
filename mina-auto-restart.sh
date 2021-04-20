##Credits
# _thanos for original snarkstopper - https://forums.minaprotocol.com/t/guide-script-automagically-stops-snark-work-prior-of$
# jrwashburn for original restart script - https://github.com/jrwashburn/mina-node-install/blob/main/scripts/mina-status-mon$

# MINA_STATUS=""
# STAT=""
# ARCHIVESTAT=0
# CONNECTINGCOUNT=0
# OFFLINECOUNT=0
# TOTALCONNECTINGCOUNT=0
# TOTALOFFLINECOUNT=0
total_stuck_count=0
# ARCHIVEDOWNCOUNT=0
# SNARKWORKERTURNEDOFF=1 ### assume snark worker not turned on for the first run
# SNARKWORKERSTOPPEDCOUNT=0
# readonly FEE=YOUR_SW_FEE ### SET YOUR SNARK WORKER FEE HERE ###
# readonly SW_ADDRESS=YOUR_SW_ADDRESS ### SET YOUR SNARK WORKER ADDRESS HERE ###

while :; do
    mina_status_json="$(mina client status -json)"

    sync_status="$(echo $mina_status_json | jq .sync_status)"
    next_block_production="$(echo $mina_status_json | jq .next_block_production.timing[1].time)"
    highest_block_length_received="$(echo $mina_status_json | jq .highest_block_length_received)"
    highest_unvalidated_block_length_received="$(echo $mina_status_json | jq .highest_unvalidated_block_length_received)"
    #   ARCHIVERUNNING=`ps -A | grep coda-archive | wc -l`

    # Calculate whether block producer will run within the next 5 mins
    # If up for a block within 5 mins, stop snarking, resume on next pass
    #   NEXTPROP="${NEXTPROP:1}"
    #   NEXTPROP="${NEXTPROP:0:-1}"
    #   NOW="$(date +%s%N | cut -b1-13)"
    #   TIMEBEFORENEXT="$(($NEXTPROP-$NOW))"
    #   TIMEBEFORENEXTSEC="${TIMEBEFORENEXT:0:-3}"
    #   TIMEBEFORENEXTMIN="$((${TIMEBEFORENEXTSEC} / ${SECONDS_PER_MINUTE}))"
    #   if [ $TIMEBEFORENEXTMIN -lt 5 ]; then
    #     echo "Stop snarking"
    #     mina client set-snark-worker
    #     ((SNARKWORKERTURNEDOFF++))
    #   else
    #     if [[ "$SNARKWORKERTURNEDOFF" -gt 0 ]]; then
    #       mina client set-snark-worker -address ${SW_ADDRESS}
    #       mina client set-snark-work-fee $FEE
    #       SNARKWORKERTURNEDOFF=0
    #     fi
    #   fi

    # Calculate difference between validated and unvalidated blocks
    # If block height is too many blocks behind, somthing is likely wrong
    delta_validated="$(($highest_unvalidated_block_length_received - $highest_block_length_received))"
    if [[ "$delta_validated" -gt 5 ]]; then
        printf "\n!!!ERROR: Validated block height is more than 5 blocks behind. Initiating node restart.\n"
        ((total_stuck_count++))
        systemctl --user restart mina
    fi

    #   if [[ "$STAT" == "\"Synced\"" ]]; then
    #     OFFLINECOUNT=0
    #     CONNECTINGCOUNT=0
    #   fi

    #   if [[ "$STAT" == "\"Connecting\"" ]]; then
    #     ((CONNECTINGCOUNT++))
    #     ((TOTALCONNECTINGCOUNT++))
    #   fi

    #   if [[ "$STAT" == "\"Offline\"" ]]; then
    #     ((OFFLINECOUNT++))
    #     ((TOTALOFFLINECOUNT++))
    #   fi

    #   if [[ "$CONNECTINGCOUNT" -gt 1 ]]; then
    #     systemctl --user restart mina
    #     CONNECTINGCOUNT=0
    #   fi

    #   if [[ "$OFFLINECOUNT" -gt 3 ]]; then
    #     systemctl --user restart mina
    #     OFFLINECOUNT=0
    #   fi

    #   if [[ "$ARCHIVERUNNING" -gt 0 ]]; then
    #     ARCHIVERRUNNING=0
    #   else
    #     ((ARCHIVEDOWNCOUNT++))
    #   fi
    #   echo "Status:" $STAT, "Connecting Count, Total:" $CONNECTINGCOUNT $TOTALCONNECTINGCOUNT, "Offline Count, Total:" $OFFLIN$
    printf "====================================================\n"
    printf "Sync Status: \t\t\t\t $sync_status \n"
    printf "Max observed block height: \t\t $highest_block_length_received \n"
    printf "Max observed unvalidated block height: \t $highest_unvalidated_block_length_received \n"
    printf "Total restarts required (stuck node): \t\t $total_stuck_count \n"    
    
    sleep 300s
    
    # check if sleep exited with break (ctrl+c) to exit the loop
    test $? -gt 128 && break;
done
