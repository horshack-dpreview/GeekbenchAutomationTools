

# Geekbench Automation Tools
Scripts for automating the execution and results collection from the command-line version of Geekbench (linux) 

## Installation
Download the GeekbenchRun script by right-clicking [here](https://raw.githubusercontent.com/horshack-dpreview/GeekbenchAutomationTools/main/GeekbenchRun.sh) and make it executable via "chmod +x GeekbenchRun.sh". 

A separate script named BenchIndividualCores lets you benchmark each core separately - to install it, right-click [here](https://raw.githubusercontent.com/horshack-dpreview/GeekbenchAutomationTools/main/BenchIndividualCores.sh) and do "chmod +x BenchIndividualCores.sh". Place it in the same directory as `GeekbenchRun.sh`

### GeekbenchRun
The free version of Geekbench supports command-line execution but not the automated collection of results - that requires the paid version. The free version instead uploads its results to Primate Lab's site (Geekbench developer) and provides a invocation-specific URL to view them. This script runs Geekbench, extracts the resulting URL, downloads the content from that URL, then parses and reports the single and multi-core results. This script can run both as a stand-alone utility, or can be included via `source` to access the functionality from your own script - this is demonstrated in `BenchIndividualCores.sh`.

#### Sample Output
    $ ./GeekbenchRun.sh -q -o -
    Single-core, 1811
    Multi-core, 7909

#### Command Line Options
    -e <path>     - Path to Geekbench executable
    -r <count>    - Geekbench run count (default is 1)
    -o <filename> - Output a copy of the results to specified file. Use -o - to output to stdout
    -q            - Quiet - don't output anything to console. If you use this option then use -o to write results to a file or stdout.
    -h            - This help display

### BenchIndividualCores
Measures the relative performance of individual processor cores by selectively enabling cores and running Geekbench against each. The /sys/devices/system/cpu/cpu\<x\>\online interface is used to enable/disable cores. You'll need to use a kernel (and processor) that supports hot-plugging cores. You'll also need to enable support for hot-plugging of core #0, which is disabled by default. This is done by specifying the`cpu0_hotplug` kernel boot option in GRUB. This script must be run with root privileges to have access to enable/disable CPU cores.

You can specify which cores are tested via the `-c` option, using any combination of ranges or individual values. For example, `-c 0-2 12,15-18` will measure performance on cores 0, 1, 2, 12, 15, 16, 17, and 18.

#### Sample Output
    $ sudo ./BenchIndividualCores.sh -c 0-5,12-19 -e ./geekbench5
    Found 20 CPU cores, testing  14 cores [0-5,12-19]

    Testing Core 0
    Single-core: Average=1770.66, each run: 1772,1771,1769
     Multi-core: Average=1771.33, each run: 1768,1775,1771
           Both: Average=1771.00

    Testing Core 1
    Single-core: Average=1771.00, each run: 1768,1773,1772
     Multi-core: Average=1770.00, each run: 1774,1769,1767
           Both: Average=1770.50

    Testing Core 2
    Single-core: Average=1767.66, each run: 1772,1765,1766
     Multi-core: Average=1767.00, each run: 1764,1767,1770
           Both: Average=1767.33

    Testing Core 3
    Single-core: Average=1737.33, each run: 1676,1766,1770
     Multi-core: Average=1760.66, each run: 1754,1761,1767
           Both: Average=1749.00

    Testing Core 4
    Single-core: Average=1844.33, each run: 1844,1847,1842
     Multi-core: Average=1844.00, each run: 1840,1846,1846
           Both: Average=1844.16

    Testing Core 5
    Single-core: Average=1844.66, each run: 1845,1844,1845
     Multi-core: Average=1842.66, each run: 1840,1847,1841
           Both: Average=1843.66

    Testing Core 12
    Single-core: Average=1084.00, each run: 1056,1096,1100
     Multi-core: Average=1099.33, each run: 1100,1100,1098
           Both: Average=1091.66

    Testing Core 13
    Single-core: Average=1096.33, each run: 1096,1096,1097
     Multi-core: Average=1099.00, each run: 1100,1100,1097
           Both: Average=1097.66

    Testing Core 14
    Single-core: Average=1099.33, each run: 1099,1100,1099
     Multi-core: Average=1093.66, each run: 1094,1093,1094
           Both: Average=1096.50

    Testing Core 15
    Single-core: Average=1098.00, each run: 1099,1098,1097
     Multi-core: Average=1099.00, each run: 1101,1096,1100
           Both: Average=1098.50

    Testing Core 16
    Single-core: Average=1097.66, each run: 1097,1098,1098
     Multi-core: Average=1098.00, each run: 1102,1099,1093
           Both: Average=1097.83

    Testing Core 17
    Single-core: Average=1095.66, each run: 1099,1092,1096
     Multi-core: Average=1095.33, each run: 1092,1095,1099
           Both: Average=1095.50

    Testing Core 18
    Single-core: Average=1096.66, each run: 1097,1100,1093
     Multi-core: Average=1097.66, each run: 1098,1099,1096
           Both: Average=1097.16

    Testing Core 19
    Single-core: Average=1097.00, each run: 1096,1097,1098
     Multi-core: Average=1095.66, each run: 1092,1098,1097
           Both: Average=1096.33

    Summary of results
    -----------------------------------------------
    Core # 0: Average=1771.00  *** Baseline ***
    Core # 1: Average=1770.50  vs Baseline:  99.97%
    Core # 2: Average=1767.33  vs Baseline:  99.79%
    Core # 3: Average=1749.00  vs Baseline:  98.75%
    Core # 4: Average=1844.16  vs Baseline: 104.13%
    Core # 5: Average=1843.66  vs Baseline: 104.10%
    Core #12: Average=1091.66  vs Baseline:  61.64%
    Core #13: Average=1097.66  vs Baseline:  61.97%
    Core #14: Average=1096.50  vs Baseline:  61.91%
    Core #15: Average=1098.50  vs Baseline:  62.02%
    Core #16: Average=1097.83  vs Baseline:  61.98%
    Core #17: Average=1095.50  vs Baseline:  61.85%
    Core #18: Average=1097.16  vs Baseline:  61.95%
    Core #19: Average=1096.33  vs Baseline:  61.90%

This was run on an i7-12700h, comparing the performance of the six performance cores to to the eight efficiency cores. Notice how cores #3 and #4 are the fastest - these represent the "favored cores" on this particular CPU die (see [Intel Turbo Boost 3.0 Technology](https://www.tomshardware.com/reference/intel-favored-cpu-cores-turbo-boost-max-technology-3.0))
	
#### Command Line Options
    -c <a-b, x, y>- List of cores #'s to test, x-y range or indiviudal values
    -e <path>     - Path to geekbench executable
    -r <count>    - Geekbench run count per core (default is 3)
    -h            - This help display

