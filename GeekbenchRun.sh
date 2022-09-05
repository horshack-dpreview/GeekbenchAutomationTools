#!/bin/bash
#
# GeekbenchRun.sh - Automation of Geekbench benchmark runs under linux.
#
# This script will run the command-line version of Geekbench one or more times,
# extracting the single and multi-core result from the resulting html page
# that Geekbench uploads to their site. This works with the free, unregistered
# version of Geekbench.
#

#
# point this variable to your Geekbench executable, either by modifying it
# here or by specifying it in your script that includes this script
#
: ${Geekbench_Executable:="/home/user/.local/bin/Geekbench-5.4.5-Linux/geekbench5"}

#
# Executes Geekbench, returning the results in a two-element array.
#
# Arguents:
#   $1 - Quiet - don't output anything to console. If false, the full output
#                of Geekbench is displayed
# Returns:
#   ${retVal[0]} = Single-core result
#   ${retVal[1]} = Multi-core result
#
Geekbench_Run() {

    local quiet=$1

    # execute Geekbench
    if [ $quiet -eq 0 ]; then
        exec 9>&1 # https://stackoverflow.com/a/49959484/5319360
        # note we use "stdbuf -oL" to fix issue of delayed stdout prints
        #  during Geekbench startup. see https://stackoverflow.com/a/3373534/5319360
        gb_output=$(stdbuf -oL $Geekbench_Executable | tee >(cat - >&9))
    else
        gb_output=$($Geekbench_Executable)
    fi
    if [ $? -ne 0 ]; then
        echo "Error: Geekbench failed"
        exit 1
    fi

    # extract results URL from Geekbench output
    gb_results_url=$(echo "$gb_output" | grep "https://" | tail -2 | head -1) # penultimate URL is a link to our results
    if [ -z "$gb_results_url" ]; then
        echo "Error: Unable to find results URL from Geekbench output"
        exit 1
    fi
    gb_results_url="${gb_results_url#"${gb_results_url%%[![:space:]]*}"}" # remove leading whitespace (https://stackoverflow.com/a/3352015/5319360)

    # retreive results page for our results URL
    gb_results_html=$(wget --timeout=30 -O - "$gb_results_url" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo "Error: wget of \"${gb_results_url}\" failed"
        exit 1
    fi

    # extract single and multi-core results from results page
    gb_single_multi_core_result_array=($(echo "$gb_results_html" | grep "<div class='score'>" | sed -nE "s/<div class='score'>([0-9]+)<\/div>/\1/p"))
    if [[ ${#gb_single_multi_core_result_array[@]} -ne 2 ]]; then
        echo "Error: Unable to extract single and multi-core results from results page"
        exit 1
    fi
    retVal=("${gb_single_multi_core_result_array[@]}")
}

#
# Executes Geekbench multiple times, return the results in two arrays
#
# Arguments:
#   $1 - Quiet - don't output anything to console
#   $2 - Number of times to run Geekbench
# Returns:
#   retVal_1 - Single-core results
#   retVal_2 - Multi-tcore results
#
Geekbench_Run_N_Times() {

    local quiet=$1
    local iterations=$2

    single_core_results=()
    multi_core_results=()
    for (( i=0; i<$iterations; i++ )); do
        [[ $quiet -eq 0 ]] && echo "Geekbench run #$((i+1)) starting..."
        Geekbench_Run $quiet
        single_core_results+=(${retVal[0]})
        multi_core_results+=(${retVal[1]})
    done
    retVal_1=("${single_core_results[@]}")
    retVal_2=("${multi_core_results[@]}")
}

#
# Converts an array of values into a comma-separated string of values
#
# Arguments:
#   $1 - Array to convert
# Returns:
#   retVal - String containing comma-separated list of values from array
#
Geekbench_Results_Str_From_Array() {
    local theArray=("$@")
    printf -v retVal "%s," "${theArray[@]}"
    retVal=${retVal%,}

}


#
# process command-line arguments and execute if we're being run as a stand-alone
# script, otherwise we're being included via "source", so the script including
# us will call our functions
#
(return 0 2>/dev/null) && sourced=1 || sourced=0 # https://stackoverflow.com/a/28776166/5319360
if [ $sourced -eq 1 ]; then
    return 0
fi


# default values before processing command line
geekbenchRunCount=1
outputFilename=""
quiet=0

showHelp() {
    echo "Command line options:"
    echo "-e <path>     - Path to Geekbench executable";
    echo "-r <count>    - Geekbench run count"
    echo "-o <filename> - Output a copy of the results to specified file"
    echo "-q            - Quiet. Don't display anything except for result"
    echo "-h            - This help display"
    exit 1 
}
while getopts "h?qr:o:e:" opt; do
  case "$opt" in
    h|\?)   showHelp ;;
    q)      quiet=1;;
    r)      geekbenchRunCount=$OPTARG;; 
    e)      Geekbench_Executable=$OPTARG;;
    o)      outputFilename=$OPTARG;;
  esac
done
shift $((OPTIND-1))

if [[ $# -ne 0 ]]; then
    # found positional arguments after option arguments
    echo "Count: $#"
    echo "Error: Unknown argument(s) \"$@\" specified"
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
    echo "geekbench run count must be 1 or greater"
    exit 1
fi

#
# run Geekbench
#
[[ $quiet -eq 0 ]] && echo "Running Geekbench ${geekbenchRunCount} time(s)..."
Geekbench_Run_N_Times $quiet $geekbenchRunCount
# process results
Geekbench_Results_Str_From_Array "${retVal_1[@]}"; single_core_results_str="$retVal"
Geekbench_Results_Str_From_Array "${retVal_2[@]}"; multi_core_results_str="$retVal"

#
# output results
#
if [ $quiet -eq 0 ] || [ "$outputFilename" = "-" ]; then
    echo "Single-core, ${single_core_results_str}"
    echo "Multi-core, ${multi_core_results_str}"
fi

if [ -n "$outputFilename" ] && [ "$outputFilename" != '-' ]; then
    echo "Single-core, ${single_core_results_str}" > $outputFilename
    echo "Multi-core, ${multi_core_results_str}" >> $outputFilename
fi

