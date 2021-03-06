#!/bin/bash
#$ -N filt_sent
#$ -S /bin/bash
#$ -j y
#$ -cwd
#$ -V
#$ -o /home/hltcoe/bahn/log/grid

echo filter_sentences.sh $* >&2

if [ "$WIKITOPICS" == "" ]; then
	echo "Set the WIKITOPICS environment variable first." >&2
	exit 1
fi

# check command-line options
if [ "$1" == "-v" ]; then
	VERBOSE=1
	shift
fi

if [ $# -lt 1 -o $# -gt 3 ]; then
	echo "USAGE: $0 [-v] LANGUAGE [START_DATE [END_DATE]]" >&2
	exit 1
fi

DATA_SET="$1"
# to avoid using LANG, which is used by Perl
LANG_OPTION=`echo $DATA_SET | sed -e 's/-.\+$//'`
if [ "$2" != "" ]; then
	START_DATE=`date --date "$2" +"%Y-%m-%d"`
	if [ $? -ne 0 ]; then
		echo "error using date... fallback to using plain text" >&2
		START_DATE=$2
	fi

	if [ "$3" == "" ]; then
		END_DATE="$START_DATE"
	else
		END_DATE=`date --date "$3" +"%Y-%m-%d"`
		if [ $? -ne 0 ]; then
			echo "error using date... fallback to using plain text" >&2
			END_DATE=$3
		fi
	fi
else
# if DATE is omitted, process all articles
	START_DATE="0000-00-00"
	END_DATE="9999-99-99"
fi

ARTICLE_DIR="$WIKITOPICS/data/articles"
SENTENCE_DIR="$WIKITOPICS/data/serif/input"

if [ ! -d "$ARTICLE_DIR/$DATA_SET" ]; then
	echo "input directory not found: $ARTICLE_DIR/$DATA_SET" >&2
	exit 1
fi

for DIR in $ARTICLE_DIR/$DATA_SET/*/*; do
	if [ ! -d "$DIR" ]; then # such directory not found
		continue
	fi
	BASEDIR=`basename $DIR`
	echo $BASEDIR | grep "^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$" > /dev/null
	if [ $? -ne 0 ]; then # the directory's name is not a date
		continue
	fi
	if [ "$START_DATE" \> "$BASEDIR" -o "$END_DATE" \< "$BASEDIR" ]; then # if the date falls out of the range
		continue
	fi

	YEAR=${BASEDIR:0:4}
	for FILE in $DIR/*.sentences; do
		if [ -f $FILE ]; then
			BASENAME=`basename $FILE`
			if [ $VERBOSE ]; then
				echo "$FILE" >&2
			fi
			OUTPUT_DIR="$SENTENCE_DIR/$DATA_SET/$YEAR/$BASEDIR"
			mkdir -p "$OUTPUT_DIR"
			# page title
			echo $BASENAME | sed -e 's/\.sentences$//' | sed -e 's/_/ /g' | perl -e 'use URI::Escape; print uri_unescape(<STDIN>);' > "$OUTPUT_DIR/$BASENAME"
			#cat $FILE | perl -ne "if (/[\.\,\'\"\!\?\:\;][\)]?$/) { print }" >> "$OUTPUT_DIR/$BASENAME"
			cat $FILE >> "$OUTPUT_DIR/$BASENAME"
			SERIFXML=`echo $BASENAME | sed -e 's/\.sentences$/\.xml/'`
			$WIKITOPICS/src/sent/generate_serifxml.py $OUTPUT_DIR/$BASENAME > $OUTPUT_DIR/$SERIFXML
		fi
	done
done
