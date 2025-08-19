#!/usr/bin/env python3

"""
Regenerates or updates the releases.ini file which lists available stable releases
in an archive directory. Looks for ohrrpgce or ohrrpgce-win zips such as
ohrrpgce-win-2025-08-10-kaleidophone+1.zip
"""

import argparse
import os
import re

HEADER = """# Used to check for new releases.
# The release.$release key on each line provides the name as used in download filenames.
# .name is the display name of a release.
# .date is YYYY-MM-DD.
# .update_for (optional) is the major version for which this is a minor update.
# .description (optional) describes a potential update, and if it changes the update
#     should be suggested again.
# .notice (optional) is for warnings that should be shown to users running that version.
#     Should be displayed whenever it changes.

downloads_url = https://rpg.hamsterrepublic.com/ohrrpgce/Downloads
archive_url = http://hamsterrepublic.com/ohrrpgce/archive/
"""

def read_releases(releases_file):
    "Reads a releases.txt file and returns a release name -> date dict."
    existing_releases = {}

    with open(releases_file, "r") as f:
        for line in f:
            match = re.match(r"^release\.([^.]+)\.date\s*=\s*(.+)$", line)
            if match:
                existing_releases[match.group(1)] = match.group(2)
    return existing_releases

def scan_archive_dir(archive_dir, existing_releases):
    """
    Get list of releases in archive_dir not in existing_releases
    Also sanity check for releases in existing_releases not in archive_dir.
    """
    for name, date in existing_releases.items():
        if not (os.path.exists(f"{archive_dir}/ohrrpgce-{date}-{name}.zip") or
                os.path.exists(f"{archive_dir}/ohrrpgce-win-{date}-{name}.zip")):
            print(f"Note: {name} is defined but couldn't find a .zip")

    new_releases = []
    for filename in os.listdir(archive_dir):
        # Match  ohrrpgce-2021-09-13-hrodvitnir.zip  (old style Windows builds since ubersetzung)
        # and    ohrrpgce-win-2025-08-10-kaleidophone+1.zip  (new style)
        # ignore ohrrpgce-win-2025-08-10-kaleidophone+1-win95.zip
        match = re.match(r"^ohrrpgce(-win)?-(\d{4}-\d{2}-\d{2})-([^-]+)\.zip$", filename)
        if match:
            _, date, name = match.groups()
            if name not in existing_releases:
                new_releases.append({"name": name, "date": date})
    return new_releases

def generate_release_text(releases):
    ret = ""
    for release in releases:
        name = release["name"]
        date = release["date"]

        ret += "\n"
        ret += f"release.{name}.name = {name}\n"
        ret += f"release.{name}.date = {date}\n"
        if "+" in name:
            major_release = name.split("+")[0]
            ret += f"release.{name}.update_for = {major_release}\n"
    return ret

def main():
    parser = argparse.ArgumentParser(description = __doc__)
    parser.add_argument(
        "archive_dir",
        help = "A directory containing ohrrpgce(-win)?-$date-$release.zip file for each release.",
    )
    parser.add_argument(
        "releases_file",
        default = "releases.txt",
        nargs = "?",
        help = "The releases.txt file to create or update.",
    )
    parser.add_argument(
        "--dry-run",
        action = "store_true",
        help = "Print new releases to stdout instead of updating the file.",
    )
    args = parser.parse_args()

    release_text = ""
    if not os.path.exists(args.releases_file):
        existing_releases = {}
        print(f"{args.releases_file} not found, recreating")
        release_text = HEADER
    else:
        existing_releases = read_releases(args.releases_file)
        print(f"Found {len(existing_releases)} existing releases in {args.releases_file}")

    if not os.path.isdir(args.archive_dir):
        print(f"Error: {archive_dir} not found")
        return

    new_releases = scan_archive_dir(args.archive_dir, existing_releases)

    print(f"Found {len(new_releases)} new releases in {args.archive_dir}")
    if not new_releases:
        return

    new_releases.sort(key = lambda release: release["date"])
    release_text += generate_release_text(new_releases)

    if args.dry_run:
        print(release_text)
    else:
        with open(args.releases_file, "a+") as ofile:
            ofile.write(release_text)
        print(f"Appended new releases to {args.releases_file}\n")


if __name__ == "__main__":
    main()
