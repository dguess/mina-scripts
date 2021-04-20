#!/bin/bash

# This script monitors a Mina node and forces a restart under the following conditions:
#  - validated block height is more than 5 blocks behind
#  - node has been in status connecting for longer than 5 minutes
#  - node has been in status offline for longer than 10 minutes

# Credits:
#  - _thanos for original snarkstopper - https://forums.minaprotocol.com/t/guide-script-automagically-stops-snark-work-prior-of$
#  - jrwashburn for original restart script - https://github.com/jrwashburn/mina-node-install/blob/main/scripts/mina-status-mon$

connecting_count=0
offline_count=0
total_connecting_count=0
total_offline_count=0
total_stuck_count=0

while :; do
    mina_status_json="$(mina client status -json)"

    sync_status="$(echo $mina_status_json | jq .sync_status)"
    next_block_production="$(echo $mina_status_json | jq .next_block_production.timing[1].time)"
    highest_block_length_received="$(echo $mina_status_json | jq .highest_block_length_received)"
    highest_unvalidated_block_length_received="$(echo $mina_status_json | jq .highest_unvalidated_block_length_received)"

    # Calculate difference between validated and unvalidated blocks
    # If block height is too many blocks behind, somthing is likely wrong
    delta_validated="$(($highest_unvalidated_block_length_received - $highest_block_length_received))"
    if [[ "$delta_validated" -gt 5 ]]; then
        printf "\n!!!ERROR: Validated block height is more than 5 blocks behind. Initiating node restart.\n"
        ((total_stuck_count++))
        systemctl --user restart mina
    fi

    # Node is synced so reset (offline/connecting) counters
    if [[ "$sync_status" == "\"Synced\"" ]]; then
        offline_count=0
        connecting_count=0
    fi

    # Node status is connecting so we log it
    if [[ "$sync_status" == "\"Connecting\"" ]]; then
        ((connecting_count++))
    fi

    # Node status is offline so we log it
    if [[ "$sync_status" == "\"Offline\"" ]]; then
        ((offline_count++))
    fi

    # Node has been in status connecting for longer than 5 minutes so restart it
    if [[ "$connecting_count" -gt 1 ]]; then
        printf "\n!!!ERROR: Node has been in status 'Connecting' for longer than 5 minutes. Initiating node restart.\n"
        systemctl --user restart mina
        connecting_count=0
        ((total_connecting_count++))        
    fi

    # Node has been in status offline for longer than 10 minutes so restart it
    if [[ "$offline_count" -gt 2 ]]; then
        printf "\n!!!ERROR: Node has been in status 'Offline' for longer than 10 minutes. Initiating node restart.\n"
        systemctl --user restart mina
        offline_count=0
        ((total_offline_count++))        
    fi

    printf "====================================================\n"
    printf "Sync Status: \t\t\t\t $sync_status \n"
    printf "Max observed block height: \t\t $highest_block_length_received \n"
    printf "Max observed unvalidated block height: \t $highest_unvalidated_block_length_received \n"
    printf "\nStats:\n"
    printf " - Total restarts required (stuck): \t $total_stuck_count \n"
    printf " - Total restarts required (offline): \t $total_offline_count \n"
    printf " - Total restarts required (connecting): $total_connecting_count \n"

    sleep 300s

    # check if sleep exited with break (ctrl+c) to exit the loop
    test $? -gt 128 && break
done
