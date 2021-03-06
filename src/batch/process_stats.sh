#!/bin/bash
#$ -N proc_stats
#$ -S /bin/bash
#$ -j y
#$ -cwd
#$ -V
#$ -o /home/hltcoe/bahn/log/grid
#$ -l h_vmem=6G

# process_stats.sh
echo $HOSTNAME "process_stats.sh $*" >&2

# check environment variables
if [ "$WIKITOPICS" == "" ]; then
	echo "Set the WIKITOPICS environment variable first." >&2
	exit 1
fi

# check command-line options
while [ "$1" == "-r" -o "$1" == "-s" ]; do
    if [ "$1" == "-r" ]; then
        REDIRECTS="$2"
        shift; shift
        if [ ! -e "$REDIRECTS" ]; then
            echo "Redirect file $REDIRECTS not found" >&2
            exit 1
        fi
		# Redirects will be ignored
	elif [ "$1" == "-s" ]; then
		STARTING_STEP="$2"
		shift; shift
    fi
done

if [ $# -lt 2 -o $# -gt 3 ]
then
    echo "Usage: $0 [-s STARTING_STEP] DATA_SET START_DATE [END_DATE]" >&2
	echo "steps: 1) articles, 2) clusters, 3) sentences" >&2
	echo "no starting step: starts from aggregating statistics and processing redirects"
	echo "1) articles: starts from articles selection and checking Wikipedia revision IDs"
	echo "2) clusters: starts from fetching the article text and clustering"
	echo "3) sentences: starts from running Serif"
    exit 1
fi

DATA_SET="$1"
START_DATE=`date --date "$2" +"%Y%m%d"`
if [ "$3" == "" ]; then
	END_DATE=$START_DATE
else
	END_DATE=`date --date "$3" +"%Y%m%d"`
fi

# don't use LANG or LANGUAGE -- they are used by Perl.
LANG_OPTION=`echo $DATA_SET | sed -e 's/-.\+$//'`
if echo $DATA_SET | grep - > /dev/null; then
	FILTER="-f `echo $DATA_SET | sed -e 's/^.\+-//'`"
fi

if [ "$LANG_OPTION" == "en" -o "$LANG_OPTION" == "ar" -o "$LANG_OPTION" == "zh" -o "$LANG_OPTION" == "ur" -o "$LANG_OPTION" == "hi" -o "$LANG_OPTION" == "es" -o "$LANG_OPTION" == "de" -o "$LANG_OPTION" == "fr" -o "$LANG_OPTION" == "cs" -o "$LANG_OPTION" == "ko" -o "$LANG_OPTION" == "ja" ]; then
	SENTENCE_SPLIT=1
fi

if [ "$LANG_OPTION" == "en" ]; then
	# process only English. Serif is available for Arabic and Chinese, but SerifArabic crashed quite often - once a few days. - 9/29/2011 bahn.
	SERIFABLE=1
fi

if [ "$DATA_SET" == "ko" ]; then
	REDIRECTS="$WIKIDUMP/kowiki-20110303/redirects.txt"
elif [ "$DATA_SET" == "zh" ]; then
	REDIRECTS="$WIKIDUMP/zhwiki-20110502/redirects.txt"
	CUT_OFF="-c 25"
elif [ "$DATA_SET" == "ar" ]; then
	REDIRECTS="$WIKIDUMP/arwiki-20110504/redirects.txt"
	CUT_OFF="-c 25"
elif [ "$DATA_SET" == "ja" ]; then
	REDIRECTS="$WIKIDUMP/jawiki-20110308/redirects.txt"
	CUT_OFF="-c 100"
elif [ "$DATA_SET" == "en" ]; then
	REDIRECTS="$WIKIDUMP/enwiki-20110115/redirects.txt"
	CUT_OFF="-c 100"
elif [ "$DATA_SET" == "en-10" ]; then
	REDIRECTS="$WIKIDUMP/enwiki-20110115/redirects.txt"
else
	CUT_OFF="-c 50"
fi

if [ "$HOSTNAME" != "a05" -a "$HOSTNAME" != "a05.clsp.jhu.edu" -a -f "/export/common/tools/serif/bin/SerifEnglish" ]; then
	HLTCOE=1
fi

if [ "$STARTING_STEP" == "" ]; then
	WORKING=1
fi

if [ $HLTCOE -a $START_DATE != $END_DATE ]; then
	if [ "$STARTING_STEP" != "" ]; then
		STARTING_STEP="-s $STARTING_STEP"
	fi
	# parallel version
	$WIKITOPICS/src/batch/parallelize_stats.sh $STARTING_STEP $DATA_SET $START_DATE $END_DATE "$REDIRECTS" "$CUT_OFF" # just in case redirects is null
else
	# serial version
	date +"%Y-%m-%d %H:%M:%S" >&2
	
	if [ $WORKING ]; then
		time $WIKITOPICS/src/batch/add_hourly_stats.sh $DATA_SET $START_DATE $END_DATE

		if [ "$REDIRECTS" != "" ]; then
			time $WIKITOPICS/src/batch/redirect_stats.sh $DATA_SET $REDIRECTS $START_DATE $END_DATE
		fi
	fi

	if [ "$STARTING_STEP" == "1" -o "$STARTING_STEP" == "articles" -o "$STARTING_STEP" == "article_selection" ]; then
		WORKING=1
	fi

	if [ $WORKING ]; then
		time $WIKITOPICS/src/batch/list_topics.sh $CUT_OFF $DATA_SET $START_DATE $END_DATE
		time $WIKITOPICS/src/batch/check_revisions.sh $DATA_SET $START_DATE $END_DATE
	fi

	if [ "$STARTING_STEP" == "2" -o "$STARTING_STEP" == "clusters" -o "$STARTING_STEP" == "clustering" ]; then
		WORKING=1
	fi

	if [ $SENTENCE_SPLIT ]; then
		if [ $WORKING ]; then
			time $WIKITOPICS/src/batch/fetch_sentences.sh $DATA_SET $START_DATE $END_DATE
			time $WIKITOPICS/src/batch/kmeans.sh $DATA_SET $START_DATE $END_DATE
		fi

		if [ "$STARTING_STEP" == "3" -o "$STARTING_STEP" == "sentences" -o "$STARTING_STEP" == "sentence_selection" ]; then
			WORKING=1
		fi

		if [ $HLTCOE ]; then
			if [ $SERIFABLE ]; then # parallelize
				if [ $WORKING ]; then
					$WIKITOPICS/src/batch/parallelize_serif.sh $DATA_SET $START_DATE $END_DATE
				fi

				# serial version
				#time $WIKITOPICS/src/batch/filter_sentences.sh $DATA_SET $START_DATE $END_DATE
				#time $WIKITOPICS/src/batch/serif.sh $DATA_SET $START_DATE $END_DATE
				#time $WIKITOPICS/src/batch/pick_sentence.sh $DATA_SET first $START_DATE $END_DATE
				#time $WIKITOPICS/src/batch/pick_sentence.sh $DATA_SET recent $START_DATE $END_DATE
				#time $WIKITOPICS/src/batch/pick_sentence.sh $DATA_SET self $START_DATE $END_DATE
				#time $WIKITOPICS/src/batch/convert_clusters.sh $DATA_SET $START_DATE $END_DATE
			else
				time $WIKITOPICS/src/batch/convert_clusters.sh $DATA_SET $START_DATE $END_DATE
			fi
		else
			time $WIKITOPICS/src/batch/convert_clusters.sh $DATA_SET $START_DATE $END_DATE
		fi
	else
		time $WIKITOPICS/src/batch/convert_topics.sh $DATA_SET $START_DATE $END_DATE
	fi
	date +"%Y-%m-%d %H:%M:%S" >&2
fi
