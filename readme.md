
# GeekbenchAutomationTools
Scripts for automating the execution and results collection from the command-line version of Geekbench (linux) 

## Installation
Download the script by right-clicking [here - GeekbenchRun.sh](https://raw.githubusercontent.com/horshack-dpreview/GeekbenchAutomationTools/main/GeekbenchRun.sh) and make it executable via "chmod +x GeekbenchRun.sh". If you'd like to benchmark individual cores do the same [here - BenchIndividualCores.sh](https://raw.githubusercontent.com/horshack-dpreview/GeekbenchAutomationTools/main/BenchIndividualCores.sh) and do "chmod +x BenchIndividualCores.sh"

### GeekbenchRun
`./GeekbenchRun.sh <options>`

Example: `./GeekbenchRun.sh -e ./geekbench5 -r 3 -o results.txt`

#### Tech Details
The free version of Geekbench supports command-line execution but not the automated collection of results - that requires the paid version. The free version instead uploads its results to Primate Lab's site (Geekbench developer) and provides a invocation-specific URL to view them. This script runs Geekbench, extracts the resulting URL, downloads the content from that URL, then parses and reports the single and multi-core results. 

#### Sample Output
    $ ./GeekbenchRun.sh -q -o -
    Single-core, 1811
    Multi-core, 7909

#### Command Line Options
    Command line options:
    -e <path>     - Path to Geekbench executable
    -r <count>    - Geekbench run count (default is 1)
    -o <filename> - Output a copy of the results to specified file. Use -o - to output to stdout
    -q            - Quiet - don't output anything to console. If you use this option then use -o to write results to a file or stdout.
    -h            - This help display

### BenchIndividualCores
`./BenchIndividualCores.sh <options>`

Example: `sudo ./BenchIndividualCores.sh -e ./geekbench5 -c 0-5,12-19`

#### Tech Details
Measures the relative performance of individual processor cores by selectively enabling cores and running Geekbench against each. The /sys/devices/system/cpu/cpu\<x\>\online interface is used to enable/disable cores. You'll need to use a kernel (and processor) that supports hot-plugging cores. You'll also need to enable support for hot-plugging of core #0, which is disabled by default. This is done by specifying the`cpu0_hotplug` kernel boot option in GRUB. This script must be run with root privileges to have access to enable/disable CPU cores.

You can specify which cores are tested via the `-c` option, using any combination of ranges or individual values. For example, `-c 0-2 12,15-18` will measure performance on cores 0, 1, 2, 12, 15, 16, 17, and 18.

#### Sample Output

    $ sudo ./BenchIndividualCores.sh -c 0,12 -e ./geekbench5
    Found 20 CPU cores, testing  2 cores [0,12]
    
    Testing Core 0
    Single-core: rverage=1721.66, each run: 1724,1717,1724
     Multi-core: Average=1708.33, each run: 1704,1706,1715
           Both: Average=1715.00
    
    Testing Core 12
    Single-core: rverage=1089.00, each run: 1089,1090,1088
     Multi-core: Average=1090.33, each run: 1092,1085,1094
           Both: Average=1089.66
    
    Summary of results
    -----------------------------------------------
    Core # 0: Average=1715.00  *** Baseline ***
    Core #12: Average=1089.66  vs Baseline:  63.53%

This was run on an i7-12700h, comparing the performance of the first performance core (core #0) to the first efficiency core (core #12).
	
#### Command Line Options
    Command line options:
    -c <a-b, x, y>- List of cores #'s to test, x-y range or indiviudal values
    -e <path>     - Path to geekbench executable
    -r <count>    - Geekbench run count per core (default is 3)
    -h            - This help display



