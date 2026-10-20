"""Builds supabase/functions/_shared/names.json from public-domain US data:
first names by birth decade and sex (SSA baby names, top 1000 per year) and surnames (Census 2010).

Sources (put both in one folder, pass it as the first argument):
  - hadley.csv: https://raw.githubusercontent.com/hadley/data-baby-names/master/baby-names.csv
    (a mirror of the SSA national data, 1880-2008; ssa.gov blocks scripted downloads)
  - census/Names_2010Census.csv: unzip https://www2.census.gov/topics/genealogy/2010surnames/names.zip

    python3 tools/kb-import/build_names.py <source folder> supabase/functions/_shared/names.json
"""
import csv, json, re, sys
from collections import defaultdict
src, out = sys.argv[1], sys.argv[2]
FIRST_PER_DECADE, SURNAMES = 200, 3000
first = {"F": defaultdict(lambda: defaultdict(float)), "M": defaultdict(lambda: defaultdict(float))}
with open(f"{src}/hadley.csv") as f:
    for r in csv.DictReader(f):
        year = int(r["year"])
        if year < 1920: continue
        decade = str(year // 10 * 10)
        first["F" if r["sex"] == "girl" else "M"][decade][r["name"]] += float(r["percent"])
firsts = {sex: {d: [[n, round(w, 5)] for n, w in sorted(names.items(), key=lambda x: -x[1])[:FIRST_PER_DECADE]]
                for d, names in sorted(by.items())} for sex, by in first.items()}
def title(s):
    s = s.title()
    s = re.sub(r"\bMc([a-z])", lambda m: "Mc" + m.group(1).upper(), s)
    s = re.sub(r"\bO([a-z])(?=[a-z]{2})", lambda m: "O" + m.group(1), s)
    return s
last = []
with open(f"{src}/census/Names_2010Census.csv") as f:
    for r in csv.DictReader(f):
        n = r["name"]
        if not n or n.startswith("ALL OTHER") or not r["count"].isdigit(): continue
        last.append([title(n), int(r["count"])])
        if len(last) >= SURNAMES: break
json.dump({"about": "Fictional patient names. First names: SSA baby names by birth decade and sex (top 200 per decade, 1920s-2000s; weight = share of births). Surnames: US Census 2010 (top 3000; weight = people). Both US government works, public domain.",
           "first": firsts, "last": last}, open(out, "w"), separators=(",", ":"))
print("decades", list(firsts["F"]), "surnames", len(last))
