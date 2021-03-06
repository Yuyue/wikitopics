#$ -N serif
#$ -S /bin/bash
#$ -j y
#$ -cwd
#$ -V
#$ -o /home/hltcoe/bahn/log/grid
#$ -l h_vmem=4G

echo serif.sh $* >&2

if [ "$WIKITOPICS" == "" ]; then
	echo "Set the WIKITOPICS environment variable first." >&2
	exit 1
fi

if [ "$1" == "--dry-run" ]; then
	DRYRUN=1
	shift
fi
if [ $# -lt 1 ]; then
	echo "Usage: $0 [--dry-run] LANG START_DATE [END_DATE]" >&2
	exit 1
fi

DATA_SET="$1"
# to avoid using LANG, which is used by Perl
LANG_OPTION=`echo $DATA_SET | sed -e 's/-.\+$//'`
if [ "$2" != "" ]; then
	START_DATE=`date --date "$2" +"%Y-%m-%d"`
	if [ "$3" == "" ]; then
		END_DATE="$START_DATE"
	else
		END_DATE=`date --date "$3" +"%Y-%m-%d"`
	fi
else
# if DATE is omitted, process all articles
	START_DATE="0000-00-00"
	END_DATE="9999-99-99"
fi

SENTENCE_DIR="$WIKITOPICS/data/serif/input"
SERIF_DIR="$WIKITOPICS/data/serif"


if [ ! -d "$SENTENCE_DIR/$DATA_SET" ]; then
	echo "input directory not found: $SENTENCE_DIR/$DATA_SET" >&2
	exit 1
fi

for DIR in $SENTENCE_DIR/$DATA_SET/*/*; do
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
	OUTPUT_DIR="$SERIF_DIR/$DATA_SET/$YEAR/$BASEDIR"
	mkdir -p "$OUTPUT_DIR"

### list the input files
	find "$DIR" -type f -name *.xml \
	> "$OUTPUT_DIR/input_list.txt"


	if [ $DRYRUN ]; then
		cat "$OUTPUT_DIR/input_list.txt" >&2
	else
### run SERIF
		if [ "$LANG_OPTION" == "en" ]; then
			/export/common/tools/serif/bin/SerifEnglish \
			/export/common/tools/serif/par/english.par \
			-p start_stage=tokens \
			-p source_format=serifxml \
			-p output_format=serifxml \
			-p batch_file="$OUTPUT_DIR/input_list.txt" \
			-o "$OUTPUT_DIR"
		elif [ "$LANG_OPTION" == "ar" ]; then
			/export/common/tools/serif/bin/SerifArabic \
			/export/common/tools/serif/par/arabic.par \
			-p start_stage=tokens \
			-p source_format=serifxml \
			-p output_format=serifxml \
			-p batch_file="$OUTPUT_DIR/input_list.txt" \
			-o "$OUTPUT_DIR"
		elif [ "$LANG_OPTION" == "zh" ]; then
			/export/common/tools/serif/bin/SerifChinese \
			/export/common/tools/serif/par/chinese.par \
			-p start_stage=tokens \
			-p source_format=serifxml \
			-p output_format=serifxml \
			-p batch_file="$OUTPUT_DIR/input_list.txt" \
			-o "$OUTPUT_DIR"
		else
			echo "no serif version for the language $LANG_OPTION" >&2
		fi
	fi
done
