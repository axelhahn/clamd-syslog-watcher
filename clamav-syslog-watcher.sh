#!/bin/bash
# ======================================================================
#
# CLAMD SYSLOG WATCHER
#
# ----------------------------------------------------------------------
# License: GPL 3.0
# Source: <https://github.com/axelhahn/TODO>
# Docs: <https://www.axel-hahn.de/docs/TODO/>
# ----------------------------------------------------------------------
# 2023-09-xx  ahahn  0.x  initial lines
# ======================================================================

. $( dirname $0 )/color.class.sh || exit 1
APP_VERSION=0.2

logdir=$( dirname $0 )/log
infctionslog=${logdir}/infections__$( date +"%y-%m" ).txt

# current day at 00:00
logstart=$( date +"%y-%m-%d 00:00:00" )
# logstart=$( date +"%y-%m-%d %H:%M:%S" --date="-60 minutes")

sleeptime=30
bSilent=0
bFhowhelp=0


# ----------------------------------------------------------------------
# FUNCTIONS
# ----------------------------------------------------------------------

function showHelp(){
    local _self; _self=$( basename $0 )
    cat << EOH
HELP:
It is a cyclic watcher into journalctl and scans for clamd messages.
On detection it shows the log lines on termimal amd sends a list of
infected files to the desktop using 'notify-send'.

The script writes a log with mothly log files with 1st occurance
per infecte file. See subdir ./log/infections__*.txt

PARAMETERS:
    -h|--help     show this help
    -n|--nocolor  do not show colored output; NO_COLOR=1 is respected too.
    -q|--quiet    Do not show unneeded output
    -s|--sleep N  sleeptime in sec between checks; default: $sleeptime

EXITCODES:
    1 - Failed to source file 'color.class.sh'
    2 - unknown parameter was given
    3 - clamonacc not found (clamav was not installed yet)
    4 - unable to create log directory

EXAMPLES:
    $_self -s 60   start scan and set scan interval to 60 sec
    $_self -n -q   Show only found infections and no coloring

EOH
}

# ----------------------------------------------------------------------
# MAIN
# ----------------------------------------------------------------------

# parse params
while [[ "$#" -gt 0 ]]; do case $1 in
    -h|--help)     bFhowhelp=1;   shift 1;;
    -n|--nocolor)  NO_COLOR=1;    shift 1;;
    -q|--quiet)    bSilent=1;     shift 1;;
    -s|--sleep)    sleeptime=$2;  shift 1; shift 1;;
    *) echo "UNKNOWN PARAMETER $1";
        exit 2
    ;;
esac; done

test "$bSilent" = "0" && (
    echo
    echo
    color.echo yellow "  ---===<<<###|  CLAMD SYSLOG WATCHER  *  v${APP_VERSION}  |###>>>===---"
    echo
    echo
)

if [ $bFhowhelp -eq 1 ]; then
    showHelp
    exit 0
fi

# ----------------------------------------------------------------------


color.echo "purple"  ">>>>>>>>>> Pre checks"

which clamonacc >/dev/null 2>&1 || (
    color.print "red" "ERROR: "
    echo "Clam On access scanner was not found."
    echo "Install Clamav first. Aborting."
    echo
)
which clamonacc >/dev/null 2>&1 || exit 3

for myprocess in clamd freshclam clamonacc
do
    if ! pgrep "$myprocess" >/dev/null; then
        color.print "yellow" "INFO: "
        echo "'$myprocess' does not run as a process."
    else
        color.print "green" "OK:   "
        echo "'$myprocess' is running."
    fi
done


if ! which notify-send >/dev/null 2>&1 ; then
    color.print "yellow" "INFO: "
    echo "'notify-send' was not found."
    echo "You cannot get desktop notifications and get the output about infections on"
    echo "terminal only."
else
    color.print "green" "OK:   "
    echo "'notify-send' for desktop notifications was found."
fi

test -d "${logdir}" || (
    color.print "yellow" "INFO: "
    echo "Creating log dir..."
    mkdir "${logdir}" || exit 4
)
echo

# ----------------------------------------------------------------------
# LOOP
# ----------------------------------------------------------------------

while true;
do
    now=$( date +"%y-%m-%d %H:%M:%S" )
    test $bSilent -eq 0 && color.print "purple"  ">>>>>>>>>> $now - scan since $logstart >>>>> "
    out=$( journalctl --since "$logstart" -u "clamav-daemon" | grep -e ' -> /' )
    if [ -n "$out" ]; then
        test $bSilent -eq 0 && echo

        # filelist=$( echo "$out" | cut -f 2- -d '>' | sort -u )
        echo "$out" | while read -r logline; do
            detection=$( cut -f 2- -d '>' <<< "$logline" )
            if ! grep -e "${detection}" "${infctionslog}" >/dev/null 2>/dev/null; then
                color.print "green" "NEW: "
                echo "$logline" | tee -a "${infctionslog}"
                which notify-send >/dev/null 2>&1 && notify-send -u critical "Clamd" "$detection"
            else
                color.echo "darkgray" "OLD: $logline"
            fi
        done
        # echo "$out"
        test $bSilent -eq 0 && echo
        # which notify-send >/dev/null 2>&1 && notify-send -u critical "Clamd" "$filelist"
    else
        test $bSilent -eq 0 && color.print "cyan" "nothing ... "
    fi
    logstart="$now"
    test $bSilent -eq 0 && echo -n "sleeping $sleeptime sec ..."
    sleep "${sleeptime}"
    echo
done

# ----------------------------------------------------------------------

