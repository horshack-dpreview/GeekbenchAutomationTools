#!/bin/bash
#
# BenchIndividualCores.sh - Script to benchmark individual CPU cores, demonstrating
# how to use GeekbenchRun.sh
#
#

source ./GeekbenchRun.sh

gCountCoresManaged=""

#
# point this variable to your Geekbench 5 executable. The executable can downloaded
# from https://www.geekbench.com/download/linux/
#
Geekbench_Executable="/home/user/.local/bin/Geekbench-5.4.4-Linux/geekbench5"

#
# Returns the number of processor cores in system
#
# Arguents:
#   None
# Returns:
#   retVal = Number of cores 
#
getCoreCount() {
    if ! coreCount=$(lscpu | grep "^CPU(s):"  | sed -nE "s/CPU\(s\):\s*([0-9]+)/\1/p"); then
        echo "Error obtaining core count from lscpu"
        exit 1
    fi
    if [ -z $coreCount ] || [ $coreCount -eq 0 ]; then
        echo "Invalid core count parsed from lscpu"
    fi
    retVal=$coreCount
}

#
# Calculates the average of numbers in an array
#
# Arguments:
#   $1 - Array to calculate average for
# Returns:
#   retVal - Average of numbers in array
#
calcArrayAverage() {
    local theArray=("$@")
    local average 
    local oldIFS="$IFS"; IFS=+; average=$(echo "scale=2; (${theArray[*]}) / ${#theArray[@]}" | bc -l); IFS="$oldIFS"
    retVal=$average
}

#
# Calculates how close two numbers are difference-wise
#
# Arguments:
#   $1 - Number #1
#   $2 - Number #2
# Returns:
#   retVal - Percentage proxomity of the two numbers
#
calcPctDiffGap() {

    local num1=$1
    local num2=$2

    strDiff=$(echo "scale=2; ($num1-$num2) / (($num1+$num2)/2) * 100" | bc -l)
    strDiff="${strDiff%.*}" # remove decimal portion of value
    strDiff="${strDiff#-*}" # remove any leading -1 (ie, do abs of value)
    retVal="$strDiff"
}

#
# Enables all CPU cores
# Arguments:
#   $1 - Number of cores to enable
#   $2 - Don't report or exit on error
#
enableAllCores() {

    local countCoresManaged=$1
    local dontReportErrors=$2

    #
    # note we use BASH brace expansion to specify range of cores. Brace expansion
    # doesn't support variables as a brace value, so we have to construct the
    # command string first then execute it via 'eval'
    #
    enableAllCoresCmd="echo 1 | tee /sys/devices/system/cpu/cpu{0..$((countCoresManaged-1))}/online 2>&1 > /dev/null"
    cmdResult=$(eval "$enableAllCoresCmd")
    if [ $? -ne 0 ] && [ $dontReportErrors -eq 0 ]; then
        if ! grep "Permission denied" < "$cmdResult"; then
            echo "Make sure 'cpu0_hotplug' kernel parameter is specified at boot time, otherwise this script can't change the online status of core #0."
            exit 1 
        fi
        echo "Error enabling all CPU cores"
        exit 1
    fi
}

#
# Enables a single processor core, disabling all others
#
# Arguents:
#   $1 - Core to enable
#   $2 - Number of cores we're managing
# Returns:
#   
#
isolatedCoreEnable() {

    local coreToEnable=$1
    local countCoresManaged=$2; 
    local core
    
    #
    # first enable all cores, to prevent a situation where we disable all cores in the system.
    #
    enableAllCores $countCoresManaged 0
    
    # now disable all other cores except the core we want enabled
    for (( core=0; core<$countCoresManaged; core++ )); do
        if [ $coreToEnable -ne $core ]; then
            if ! echo 0 > "/sys/devices/system/cpu/cpu${core}/online"; then
                echo "Error disabling CPU core #${core}"
                exit 1
            fi
        fi
    done
}

#
# SIGINT handler. Re-enables all CPU cores so we don't leave
# just one enabled when user kills our app
#
trap_SIGINT() {
    enableAllCores $gCountCoresManaged 1
}


#
# Creates array of numbers whose values are parsed from a range string. The range string
# can contain any combination of ranges (x-y) or indiviudal values (x), each separated
# by a comma.
#
# Examples:
#       "0-4"
#       "5"
#       "8, 12-15, 20, 33-35"
# Arguents:
#   $1 - String containing one or more ranges and/or values
# Returns:
#   retVal - Array of individual values parsed from specified range string
#
genNumberListFromRangeStr() {

    local rangeStr=$1
    local oldIFS
    local val

    # build an array containing each comma-separated value/value range
    oldIFS="$IFS"; IFS=,; rangeStrAsArray=($rangeStr); IFS="$oldIFS"

    # build array of values by parsing each value/value range
    valueArray=()
    for rangeElement in "${rangeStrAsArray[@]}"; do
        if [[ "$rangeElement" == *-* ]]; then
            # this element contains a dash - it's a value range
            lowVal=${rangeElement%-*}
            highVal=${rangeElement#*-}
        else
            lowVal=${rangeElement}
            highVal=${rangeElement}
        fi
        if [[ $lowVal =~ ^[0-9]+$ ]] && [[ $highVal =~ ^[0-9]+$ ]]; then # make sure both values are numbers
            if [ $lowVal -gt $highVal ]; then
                # low value is > high value - swap them
                local temp
                temp=$lowVal
                lowVal=$highVal
                highVal=$temp
            fi
            # add each value in range to the value array
            for (( val=$lowVal; val<=$highVal; val++ )); do
                valueArray+=($val)
            done
        else
            echo "Error: Non-number values specified in range element \"$rangeElement\""
            exit 1
        fi
    done
    retVal=("${valueArray[@]}")
}


#
#############################################################################
#
# script execution entry point
#
#############################################################################
#


#
# process command-line arguments
#

getCoreCount; countCores=$retVal 
geekbenchRunCount=3
coresToTestRangeStr=""

showHelp() {
    echo "Command line options:"
    echo "-c <a-b, x, y>- List of cores #'s to test, x-y range or indiviudal values"  
    echo "-e <path>     - Path to geekbench executable";
    echo "-r <count>    - Geekbench run count per core"
    echo "-h            - This help display"
    exit 
}
while getopts "h?r:c:e:" opt; do
  case "$opt" in
    h|\?)   showHelp ;;
    c)      coresToTestRangeStr=$OPTARG;; 
    e)      Geekbench_Executable=$OPTARG;;
    r)      geekbenchRunCount=$OPTARG;; 
  esac
done
shift $((OPTIND-1))

if [[ $# -ne 0 ]]; then
    # found positional arguments after option arguments
    echo "Error: Unknown argument(s) \"$@\" specified"
    exit 1
fi

if [ -z "$coresToTestRangeStr" ]; then
    # no core list specified - use all cores 
    coresToTestRangeStr="0-$((countCores-1))"
fi
genNumberListFromRangeStr $coresToTestRangeStr; coresToTestList=("${retVal[@]}")
countCoresToTest="${#coresToTestList[@]}"

#
# make sure script is running with root privilege, which we need to
# enable/disable cores
#
if [ $(id -u) -ne 0 ]; then
    echo "This script must be run with root privileges (root user or with 'sudo')"
    exit 1
fi

#
# make sure we have the right path to the Geekbench executable
#
if [ ! -f "$Geekbench_Executable" ]; then
    echo "Error: Geekbench executable path not found. Specify correct path via -e <path>  or edit \"Geekbench_Executable\" at the top of this script"
    exit 1
fi

if [ $geekbenchRunCount -lt 1 ]; then
    echo "Geekbench run count must be 1 or greater"
    exit 1
fi

#
# set-up a ctrl-c handler that will re-enable all cores, so we don't leave
# the user's system running with just a single core in case we're interrupted
#
gCountCoresManaged=${countCores} # trap_SIGINT needs to know the cores we're managing to know what to enable
trap trap_SIGINT INT

#
# Execute Geekbench with only each core enabled at a time. We run
# Geekbench multiple times for each core and use the average 
#
echo "Found ${countCores} CPU cores, testing  ${countCoresToTest} cores [$coresToTestRangeStr]"
resultsPerCore=() # array of results for each core - contains average of all Geekbench run(s) on core

for core in "${coresToTestList[@]}"; do

    echo
    echo "Testing Core $core"

    #
    # enable the next core
    #
    isolatedCoreEnable $core $countCores

    #
    # run Geekbench multiple times so we can calculate a stable average
    #
    Geekbench_Run_N_Times 1 $geekbenchRunCount

    #
    # since we ran Geekbench with only a single core enabled, the single
    # and multi-core results should be comparable, which means we can
    # use both in calculating the overall average. As a sanity check
    # we make sure the percentage gap between the single and multi
    # core result averages are within 15% of each other (arbitrary %).
    # If the gap between the single and multi-core results is greater
    # than this percentage then it indicates we haven't correctly
    # isolated a single core (ie, more than one core was enabled during
    # the test)
    #
    #
    calcArrayAverage ${retVal_1[@]}; singleCoreAverage="$retVal"  
    calcArrayAverage ${retVal_2[@]}; multiCoreAverage="$retVal"  
    calcPctDiffGap $singleCoreAverage $multiCoreAverage; singleMultiAverageGap="$retVal"

    singleMultiCoreResults=("${retVal_1[@]}" "${retVal_2[@]}")
    calcArrayAverage ${singleMultiCoreResults[@]}; singleMultiCoreAverage="$retVal"
    resultsPerCore+=($singleMultiCoreAverage)

    Geekbench_Results_Str_From_Array "${retVal_1[@]}"; single_core_results_str="$retVal"
    Geekbench_Results_Str_From_Array "${retVal_2[@]}"; multi_core_results_str="$retVal"

    echo "Single-core: Average=${singleCoreAverage}, each run: ${single_core_results_str}"
    echo " Multi-core: Average=${multiCoreAverage}, each run: ${multi_core_results_str}"
    echo "       Both: Average=${singleMultiCoreAverage}"

    if [ ${singleMultiAverageGap%.*} -gt 15 ]; then
        echo "    Warning: Gap between single and multi-core results is ${singleMultiAverageGap}%, implying this script isn't correctly isolating each core"
    fi

done

#
# report the relative performance of each core. We arbitrarily use the first core tested 
# as our baseline, then show the percentage difference from that baseline for the other cores
#
echo
echo "Summary of results"
echo "-----------------------------------------------"

for (( coreIndex=0; coreIndex<$countCoresToTest; coreIndex++ )); do
    core=${coresToTestList[$coreIndex]};
    printf "Core #%2d: Average=%-8s " "$core" "${resultsPerCore[$coreIndex]}"
    if [ $coreIndex -eq 0 ]; then
        printf "*** Baseline ***\n"
    else
        averagePctRelativeToBaseline=$(echo "scale=4; ${resultsPerCore[$coreIndex]} / ${resultsPerCore[0]} * 100" | bc -l)
        averagePctRelativeToBaseline=${averagePctRelativeToBaseline%??}
        printf "vs Baseline: %6s%%\n" "$averagePctRelativeToBaseline"
    fi
done


#
# all done - enable all cores
#
enableAllCores $gCountCoresManaged 0

