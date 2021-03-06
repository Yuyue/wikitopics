#!/bin/bash
#$ -N redir_stat
#$ -S /bin/bash
#$ -j y
#$ -cwd
#$ -V
#$ -o /home/hltcoe/bahn/log/grid
#$ -l h_vmem=2G

echo $HOSTNAME redirect_stats.sh $* >&2

# check environment variables
if [ "$WIKITOPICS" == "" ]; then
	echo "Set the WIKITOPICS environment variable first." >&2
	exit 1
fi
REDIR_SCRIPT="$WIKITOPICS/src/wiki/redirect_stats.py"
if [ ! -f "$REDIR_SCRIPT" ]; then
	echo "$REDIR_SCRIPT not found" >&2
	exit 1
fi

# check the command-line options
if [ "$1" == "--dry-run" ]; then
    DRYRUN=1
    shift
fi
if [ $# -lt 3 -o $# -gt 4 ]; then
    echo "Usage: $0 [--dry-run] DATA_SET REDIRECTS START_DATE [END_DATE]" >&2
    echo "Given: $0 $*" >&2
    exit 1
fi
if [ $DRYRUN ]; then
    echo "Running a dry run..."
fi

DATA_SET="$1"
REDIRECTS=$2
START_DATE=`date --date "$3" +"%Y%m%d"`
if [ "$4" == "" ]; then
	END_DATE=$START_DATE
else
	END_DATE=`date --date "$4" +"%Y%m%d"`
fi
if [ $START_DATE \> $END_DATE ]; then
    echo "$START_DATE > $END_DATE" >&2
    exit 1
fi

# don't use LANG or LANGUAGE -- they are used by Perl.
LANG_OPTION=`echo $DATA_SET | sed -e 's/-.\+$//'`
INPUT_DIR="$WIKISTATS/archive"
OUTPUT_DIR="$WIKISTATS/process/$DATA_SET"
SRC_DIR="$OUTPUT_DIR/daily"
TRG_DIR="$OUTPUT_DIR/redir/daily"

# save the current working directory
CWD=`pwd`

# get full path for directories
if [ ! -e $SRC_DIR ]; then
    echo "$SRC_DIR not found" >&2
    exit 1
fi
cd $SRC_DIR; SRC_DIR=`pwd`

cd $CWD; mkdir -p $TRG_DIR; cd $TRG_DIR; TRG_DIR=`pwd`
if [ $SRC_DIR == $TRG_DIR ]; then
    echo "$SRC_DIR == $TRG_DIR" >&2
    exit 1
fi

cd $SRC_DIR
DATE=$START_DATE
while [ ! $DATE \> $END_DATE ]; do
    YEAR=${DATE:0:4}
    MONTH=${DATE:4:2}
    for FILE in *$DATE*.gz $MONTH/*$DATE*.gz $YEAR/*$DATE*.gz $YEAR/$MONTH/*$DATE*.gz; do
        if [ ! -e $FILE ]; then
            # if there is no files of the name of the given pattern, it returns pattern itself.
            # if such pattern found, pass.
            continue
        fi
        if [ $DRYRUN ]; then
            echo "$REDIR_SCRIPT $FILE > $TRG_DIR/$FILE"
        else
            mkdir -p `dirname $TRG_DIR/$FILE`
            $REDIR_SCRIPT -l $LANG_OPTION -r $REDIRECTS $FILE | gzip -c > $TRG_DIR/$FILE 
        fi
    done
    DATE=`date --date "$DATE 1 day" +"%Y%m%d"`
done

# cd back to the previous working directory
cd $CWD
