#!/usr/bin/env python3

"""
This script updates the Bughunters League Table on the wiki
https://rpg.hamsterrepublic.com/ohrrpgce/index.php?title=Bughunters_League_Table

It reads a file called bughunters.txt which contains an emacs org-mode-formatted
table with a list of bugs, (and other junk which is ignored), converts the
bughunters table to mediawiki markup and generates the summary tables, then
fetches the existing Bughunters_League_Table page from the wiki and pastes in
the new tables, leaving the rest of the page alone.  The result is then written
to leaguetable_wiki.txt to be manually put on the wiki.

License: Released into the public domain.
"""

import io
from collections import Counter, defaultdict
from bs4 import BeautifulSoup, NavigableString
import bs4
import argparse
from urllib.request import urlopen, urlretrieve
#from urllib.error import HTTPError

parse_lib = "html.parser"


def auto_decode(data, default_encoding = 'utf-8'):
    try:
        data = data.decode(default_encoding)
    except UnicodeDecodeError:
        data = data.decode('latin-1')
    return data

def get_url(url):
    print("Fetching", url)
    response = urlopen(url)
    return response.read()

def get_page(url, encoding = 'utf-8'):
    """Download a URL of an HTML page or fetch it from the cache, and return a BS object"""
    data = get_url(url)
    data = auto_decode(data, encoding)
    # Convert non-breaking spaces to spaces
    #data = data.replace(u'\xa0', ' ')
    data = data.replace("&#160;", ' ')
    return BeautifulSoup(data, parse_lib)

def get_old_page():
    """Get the (mediawiki markup) contents of Bughunters_League_Table article"""
    dom = get_page("https://rpg.hamsterrepublic.com/ohrrpgce/index.php?title=Bughunters_League_Table&action=edit")
    return dom.find(id="wpTextbox1").string

######################################################################

class LeagueTableUpdater:

    def __init__(self, since_rev = 0):
        self.counts = defaultdict(int)
        self.totalcounts = defaultdict(int)

        # Just for print_summary(), we can also count bugfixes since a certain revision
        # (I used this for stating summaries in my devlog)
        self.fixed_since_rev = since_rev
        self.fixed_since = defaultdict(int)

    def read_and_format_bugs_table(self, infile, only_version = None):
        """Scan infile for the org-mode table of bugs, process it (storing data in self),
        and return mediawiki-formatted table
        only_version: Single uppercase character. Limit to a bugs in that release, all other bugs ignored."""
        bugstbl = io.StringIO()

        self.points = Counter()
        self.bugs = Counter()
        intable = False
        bugstbl.write('{| class=wikitable\n')
        for line in infile.readlines():
            line = line.strip()
            if line.startswith("VERSIONS "):
                self.versions = line.split()[1:]
            elif line == "START_TABLE":
                intable = True
            elif not line.startswith("| "):
                intable = False
            elif intable:
                # Example line:
                #| sotrain515  |   2 | E       | no          | #2036 Crash when switching collections in slice collection editor  |
                parts = [p.strip() for p in line.split('|')]
                reporters = parts[1]
                pts = parts[2]
                version = parts[3]
                fixed = parts[4]
                if reporters == 'Reporter':
                    # This is the header row of the table
                    bugstbl.write("! Reporter || Points || Version || Fixed? || Bug\n")
                else:
                    if 'part' in fixed:
                        fixed = 'part'
                    # Change "yes (git)" to "yes"
                    if fixed.startswith('yes'):
                        fixed = 'yes'
                    reported_version = None  # Version it was reported in
                    fixed_version = None  # Version it was fixed in (note this doesn't end up in any summary table)
                    # If fixed is prefixed with the version it was fixed in, like "F/", split that out.
                    if len(fixed) > 2 and fixed[1] == '/':
                        fixed_version = fixed[0]
                        fixed = fixed[2:]
                    # If fixed is a list of one or more svn revisions, change to 'yes'
                    try:
                        fixed_revs = [int(x) for x in fixed.split('/')]
                        fixed = 'yes'
                    except:
                        fixed_revs = []
                        pass

                    if version != 'N/A':
                        # Remove '?' suffix and merge version codes:
                        # X X! X- => X
                        # X+      => X+
                        reported_version = version.replace('?','').replace('!','').replace('-','')
                        if only_version and reported_version.replace('+','') != only_version:
                            # Limiting to a certain release and nighlies, skip bug
                            continue
                        next_version = chr(ord(reported_version[0]) + 1)
                        if fixed == 'yes' and fixed_version and fixed_version > next_version:
                            fixed = 'later'  # Fixed in later release
                    if reported_version and fixed not in ('notabug', 'wontfix'):
                        # Tally bugs by version and status ('fixed') into 'self.counts' and 'self.totalcounts'
                        self.counts[(reported_version,fixed)] += 1
                        self.totalcounts[reported_version] += 1
                        # self.counts[('total',fixed)] += 1
                        # self.totalcounts['total'] += 1
                        if len(fixed_revs) >= 1 and fixed_revs[0] >= self.fixed_since_rev:
                            self.fixed_since[reported_version] += 1
                    try:
                        # Award points even for notabug (only worthy notabug's are tabulated) or wontfix
                        for who in reporters.split('/'):
                            if who not in ('Anonymous', 'tmc', 'James'):  # Exclude certain users
                                self.points[who] += float(pts)
                                self.bugs[who] += 1
                    except ValueError:
                        pass
                    if '#' in parts[5][:3]:
                        bugprefix, rest = parts[5].split('#', 1)
                        bugnum, rest = rest.split(' ', 1)
                        if bugprefix == 'sf':
                            # SourceForge bug number
                            parts[5] = '{{oldbug|%s}} ' % bugnum + rest
                        elif bugprefix in ('', 'gh'):
                            # GitHub bug number
                            parts[5] = '{{bug|%s}} ' % bugnum + rest
                    del parts[0]
                    del parts[-1]
                    bugstbl.write("|-\n| " + " || ".join(parts) + "\n")

        bugstbl.write("|}")
        return bugstbl.getvalue()

    def print_summary(self):
        """Print out a summary (to stdout) of bugs and bugfixes."""
        print("Reported |                |      ")
        print("Version  |     Status     | Count")
        for (version, status), count in sorted(self.counts.items()):
            print("%8s | %14s | %s" % (version, status, count))

        if self.fixed_since_rev:
            print("Since r%d fixed bugs: %s" % (self.fixed_since_rev, list(self.fixed_since.items())))

    def leaderboard_table(self, limit = None):
        """Return mediawiki table of people sorted by points, down to a certain placing."""
        def sortkey(who_points):
            who,pts = who_points
            return -pts, -self.bugs[who], who.lower()  # Lexicographic sort, by three keys
        point_pairs = sorted(self.points.items(), key=sortkey)

        leaguetbl = io.StringIO()
        leaguetbl.write("""{| class=wikitable
|-
! Place || Who || Points || Reported bugs
""")

        table = []
        mult = Counter()
        lastpair = None
        for i, (who, pts) in enumerate(point_pairs):
            pair = pts, self.bugs[who]
            if pair != lastpair:
                placing = i + 1
            mult[placing] += 1
            lastpair = pair
            table.append((placing, who, pts))

        for placing, who, pts in table:
            placestr = str(placing)
            bugcount = self.bugs[who]
            if mult[placing] > 1:
                placestr += "="
            if placing <= 3:
                placestr += " [[File:Golden star.png|25px]]" * (4 - placing)
            if placing <= 10:
                who = "'''%s'''" % who
            if limit and placing > limit:
                break
            leaguetbl.write("|-\n")
            leaguetbl.write("| %s || %s || %g || %d\n" % (placestr, who, pts, bugcount))
        leaguetbl.write("|}")
        return leaguetbl.getvalue()

        #print("Points:", sorted(self.points.items(), key= lambda x: x[1], reverse = True))
        #print("Points:", self.points.most_common())

        #print("Bugs:", self.bugs.most_common())

    def summary_table(self):
        """Return mediawiki table of bugs tallied by reported release and status"""
        ret = """{| class=wikitable
!rowspan="2"|  Reported in
!colspan="3"| Fixed  <!--Unmerged !! In later release !!  For next release-->
!rowspan="2"|  Partly fixed
!rowspan="2"|  Not fixed
!rowspan="2"|  Total reported
|-
! Unmerged !! In later release !!  For next release"""

        def row(code):
            def c(status):
                return self.counts[code, status]

            return ("<!--unmerged  later   yes   part    no     total-->\n"
                    "|       %3d || %3d || %3d || %3d || %3d || %3d" % (
                c('unmerged'), c('later'), c('yes'), c('part'), c('no'), self.totalcounts[code]
            ))

        for version in self.versions:
            code = version[0]
            ret += """
|-
! [[%s]]
%s
|-
! Post-[[%s]] [[nightly builds]]
%s""" % (version, row(code), version, row(code+'+'))

        # Add totals
        for (version,status),count in dict(self.counts).items():
            self.counts[('total',status)] += count
            self.totalcounts['total'] += count
        ret += """
|-
! Total
""" + row('total')

        ret += "\n|}"
        return ret

    def output_page(self, page):
        print("Writing leaguetable_wiki.txt")
        ofile = open("leaguetable_wiki.txt", "w")
        ofile.write("\n".join(page))

    def update_article(self):

        def skiptable(it):
            """Skip rest of a mediawiki-formatted table"""
            while True:
                line = next(it)
                if line == "|}": break

        def copy_till_table(it, dest, marker):
            line = None
            while line != marker:
                line = next(it)
                dest.append(line)
            skiptable(it)

        with open("bughunters.txt", "r") as infile:
            bugstbl = self.read_and_format_bugs_table(infile)

        self.print_summary()

        oldpage = get_old_page()
        #with open("oldpage.txt", "w") as oldfile:
        #    oldfile.write(oldpage)
        page = []
        it = iter(oldpage.split('\n'))

        copy_till_table(it, page, "<!--SCORETABLE-->")
        page.append(self.leaderboard_table())
        copy_till_table(it, page, "<!--SUMTABLE-->")
        page.append(self.summary_table())
        copy_till_table(it, page, "<!--BUGTABLE-->")
        page.append(bugstbl)
        page += list(it)

        self.output_page(page)

    def release_leaderboard(self, release):
        prev_release = chr(ord(release[0].upper()) - 1)  #In the leadup to $release

        with open("bughunters.txt", "r") as infile:
            bugstbl = self.read_and_format_bugs_table(infile, prev_release)

        self.print_summary()

        page = ["=" + release.title() + "=", "Bugs reported in the lead-up to [[" + release + "]] (in the previous major release or in [[nightly builds]] since).",
                "<big>", self.leaderboard_table(25), "</big>"]
        self.output_page(page)

######################################################################

parser = argparse.ArgumentParser(description="Updates Bughunters League Table; reads bughunters.txt and writes leaguetable_wiki.txt")
parser.add_argument("--since", help="Count bugs fixed since this svn revision (inclusive)", type=int, default=0)
parser.add_argument("--release", help="Produce leader table for bugs reported in a particular release (and nightlies)", type=str)
args = parser.parse_args()

updater = LeagueTableUpdater(args.since)
if args.release:
    updater.release_leaderboard(args.release)
else:
    updater.update_article()
