#!/usr/bin/env python
# nonoverlapeval.py
#
# the clustering evaluation script that use simple B-cubed for non-overlapping clusters.
# Note that this script is for non-overlapping clusters.
# If the clusters have overlapping articles, you have to use eval.py instead.
# 
# Usage:
# 	./nonoverlapeval.py gold_standard test_set
# 		gold_standard and test_set are both cluster files.
# 		The B-cubed scores are evaluated for test_set against gold_standard.
# 		The scores are commutative, which means you will get the same scores
# 		if you exchange the test set and the gold standard.
# 
# Input:
# 	cluster files has the following format.
# 
# 	The title of an article is listed per line, and each cluster is divided by a blank line.
# 	The first article of each cluster may be the centroid article of the cluster.
# 	Comments followed by a hash (#) sign are allowed either at the beginning or end of a line.
# 
# 	An example cluster file follows:
# 	# Excitement about the upcoming superbowl.  Played on February 1, 2009.
# 	Super_Bowl_XLIII
# 	Super_Bowl
# 	Arizona_Cardinals
# 	Kurt_Warner
# 
# 	# The US airways flight that ditched into the Hudson, with no casualties 
# 	US_Airways_Flight_1549
# 	Chesley_Sullenberger
# 	Hudson_River
# 	Airbus_A320_family

import sys

gold_file = "/Users/bahn/work/wikitopics/data/clustering/clusters-ccb/pick0127.clusters-ccb"
clustering = "/Users/bahn/work/wikitopics/data/clustering/clusters-bahn/cluster0127.txt"

if sys.argv > 1:
    if len(sys.argv) == 3:
	gold_file = sys.argv[1]
	clustering = sys.argv[2]
    else:
	print 'Invalid arguments:', sys.argv
	sys.exit(1)

label = {}
cluster = {}

def read_clusters(filename, bag):
    f = open(filename, 'r')
    numClusters = 0
    numInstances = 0
    for line in f:
	if (line.find('#') != -1):
	    line = line[:line.find('#')].strip()
	tokens = line.split(None, 1)
	if len(tokens) == 0:
	    if numInstances:
		numClusters += 1
		numInstances = 0
	else:
	    topic = tokens[0].strip()
	    bag[topic] = numClusters
	    numInstances += 1
    if numInstances:
	numClusters += 1
	numInstances = 0
    return numClusters
    
print "gold standard:", gold_file
print "clustering:", clustering
ret = read_clusters(gold_file, cluster)
print "clusters of gold standard:", ret
ret = read_clusters(clustering, label)
print "clusters of test set:", ret
del ret

keys = label.keys()
for key in keys:
    if not key in cluster:
	print key, 'is missing in cluster'
	sys.exit(0)

for key in cluster.keys():
    if not key in label:
	print key, 'is missing in label'
	sys.exit(0)

precnum = 0
precden = 0
for e in keys:
    for e2 in keys:
	if e == e2:
	    continue
	if label[e] != label[e2]:
	    continue
	precden += 1
	if cluster[e] == cluster[e2]:
	    precnum += 1
precnum /= 2
precden /= 2

recnum = 0
recden = 0
for e in keys:
    for e2 in keys:
	if e == e2:
	    continue
	if cluster[e] != cluster[e2]:
	    continue
	recden += 1
	if label[e] == label[e2]:
	    recnum += 1
recnum /= 2
recden /= 2

precision = float(precnum) / float(precden)
recall = float(recnum) / float(recden)
fscore = 2*precision*recall / (precision + recall)
print "BCubed precision: %.4f (%d/%d)" % (precision, precnum, precden)
print "BCubed recall:    %.4f (%d/%d)" % (recall, recnum, recden)
print "BCubed F-score:   %.4f" % (fscore)
