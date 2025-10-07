#!/bin/bash
# Close all existing bars
eww close-all

# Get number of monitors
count=$(hyprctl monitors -j | jq length)

# Open bars based on monitor count
case $count in
    1)
        eww open bar-allmonitors-0
        ;;
    2) 
        eww open bar-allmonitors-0
        eww open bar-allmonitors-1
        ;;
    3)
        eww open bar-allmonitors-0
        eww open bar-allmonitors-1
        eww open bar-allmonitors-2
        ;;
    4)
        eww open bar-allmonitors-0
        eww open bar-allmonitors-1  
        eww open bar-allmonitors-2
        eww open bar-allmonitors-3
        ;;
esac
