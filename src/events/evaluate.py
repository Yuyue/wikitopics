#!/usr/bin/env python
#
# evaluate.py
#
# The script to evalute the automatically selected Wikipedia articles
# against the articles linked from the Wikipedia official current events.
# 
# Usage:
# 	evaluate.py events_link events_pageviews trends window_size
# 
# Input:
# 	events_link
# 		the links from the Wikipedia current events. e.g. data/events/events_links_2009
# 		Each line contains the date and the index of the event (which is reset every day),
# 		and the title of an article linked from the event.
# 		e.g.
# 20090101 0 BART_Police_shooting_of_Oscar_Grant
# 20090101 0 California
# 20090101 0 Bay_Area_Rapid_Transit
# 20090101 0 Fruitvale_%28BART_station%29
# ...
# 
# 	events_pageviews
# 		the daily pageviews for Wikipedia articles. e.g. data/events/events_page_views_2009
# 		The file format should be JSON compatible. The date format does not matter.
# 		The example would be either:
# 		["14th_Dalai_Lama", [["20081201", 2112], ..., ["20091231", 1811]]]
# 		or:
# 		["14th_Dalai_Lama", [["12/1/2008", 2112], ..., ["12/31/2009", 1811]]]
# 
# 	trends
# 		the file that has the list of the automatically selected Wikipedia articles.
# 		e.g. data/topics/topics_2009
# 		The name of each file of the daily page views are written in a line
# 		followed by the selected articles, one in a line.
# 		The format:
# pagecounts-20090101.gz	13226
# Boxing_Day	477075
# Eartha_Kitt	370776
# Hanukkah	350016
# Gaza_Strip	347104
# ...
# 
# 	window_size
# 		the window size with which the selected articles are evaluated
# 		against the articles linked from the Wikipedia current events.

import sys
import simplejson

if len(sys.argv) < 4:
	print 'usage: evaluate.py events_link events_pageviews trends window_size'
	sys.exit(0)

events_filename = sys.argv[1]
pageviews_filename = sys.argv[2]
trends_filename = sys.argv[3]

pageviews = {}
pageviews_file = open(pageviews_filename)
for line in pageviews_file:
	json = simplejson.loads(line)
	peak = 0
	title = json[0]
	counts = json[1]
	for count in counts:
		if count[1] > peak:
			peak = count[1]
	pageviews[title] = peak
under1k = 0

total_bullets = 0
total_gold = 0

bullets = {} # events for a particular bullet
events = {} # all events for a particular date
events_file = open(events_filename)
for line in events_file:
	column = line.split()
	title = column[2]
	bullet = column[1]
	date = column[0]
	if not date in events:
		events[date] = []
		bullets[date] = {}
	events[date].append(title)
	if not bullet in bullets[date]:
		bullets[date][bullet] = []
		total_bullets += 1
	bullets[date][bullet].append(title) 
	total_gold += 1
	if not title in pageviews:
		under1k += 1
	elif pageviews[title] < 1000:
		under1k += 1

dates = []

total_topics = 0
trends = {} # topics for each date
trends_file = open(trends_filename)
date = ''
for line in trends_file:
	column = line.split()
	title = column[0]
	if title.startswith('pagecounts'):
		date = title.split('-')[1].split('.')[0]
		dates.append(date)
	elif date:
		if not date in trends:
			trends[date] = []
		trends[date].append(title)
		total_topics += 1
		
date = '20091015'
dates.append(date)
dates.sort()

slack = 0
if len(sys.argv) == 5:
	slack = int(sys.argv[4])

true_positives = 0
beforehands = 0
exactday = 0
afterwards = 0

for i, date in enumerate(dates):
	if not date in trends:
		continue
	for trend in trends[date]:
		is_exact = False
		is_before = False
		is_after = False
		for j in range(-slack, slack+1):
			k = i + j
			if k >= 0 and k < len(dates):
				lookup_date = dates[k]
				if lookup_date in events and trend in events[lookup_date]:
					if j == 0:
						is_exact = True
					elif j < 0:
						is_before = True
					else:
						is_after = True
		if is_exact or is_before or is_after:
			true_positives += 1
		if is_exact:
			exactday += 1
		if is_before:
			beforehands += 1
		if is_after:
			afterwards += 1

# Check the articles by bullet-wise.
#
# under1k_bullets: the number of articles all links of which
#                  has page views less than 1000.
# t: the number of articles at least one of links of which
#    has page views lest than 1000.
checked_bullets = 0
under1k_bullets = 0
t = 0

for i, date in enumerate(dates):
	if not date in bullets:
		continue
	for bullet in bullets[date]:
		found = False
		all_under1k = True
		all_over1k = True
		for title in bullets[date][bullet]:
			if title in pageviews and pageviews[title] >= 1000:
				all_under1k = False
			if not title in pageviews or pageviews[title] < 1000:
				all_over1k = False
			for j in range(-slack, slack+1):
				k = i + j
				if k >= 0 and k < len(dates):
					lookup_date = dates[k]
					if lookup_date in trends and title in trends[lookup_date]:
						found = True
						break
			if found:
				checked_bullets += 1
				break
		else:
			if all_under1k:
				under1k_bullets += 1
			if not all_over1k:
				t += 1

print "true_positives:", true_positives
print "total_gold:", total_gold
print "total_topics:", total_topics
print
print "precision:", (float(true_positives) / float(total_topics))
print "recall:", (float(true_positives) / float(total_gold))
print "recall over 1k:", (float(true_positives) / float(total_gold - under1k))
print "under1k:", under1k
print
print "beforehands:", beforehands
print "exactday:", exactday
print "afterwards:", afterwards
print
print "checked_bullets:", checked_bullets
print "total_bullets:", total_bullets
print "under1k_bullets:", under1k_bullets
print "bullets with at least one link under 1k:", t
print
print "recall per bullets:", (float(checked_bullets)/float(total_bullets))
print "recall per bullets (one over 1k):", (float(checked_bullets)/float(total_bullets - under1k_bullets))
print "recall per bullets (all over 1k):", (float(checked_bullets)/float(total_bullets - t))

