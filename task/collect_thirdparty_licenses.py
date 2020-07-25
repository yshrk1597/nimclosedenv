# -*- coding: utf-8 -*-


import sys
import os
import pathlib
import json
import urllib.parse
import requests


'''
json format
[
	{
		"name": "",
		"url": "",
		"category":"",
		"filename-format":""
	},
]
'''

def download(session, url, filename):
    print(f"get {url}")
    r = session.get(url)
    if r.status_code == requests.codes.ok:
        print(f"save {filename}")
        data = r.text
        with open(filename, "w", encoding='utf-8') as f:
            f.write(data)
    else:
        print(f"failed {url}")
        print(f"status_code = {r.status_code}")
        sys.quit(1)

if __name__ == '__main__':
    if len(sys.argv) >= 2:
        settingfilename = sys.argv[1]
        setting = None
        with open(settingfilename, encoding='utf-8') as f:
            setting = json.load(f)
        if setting is not None:
            with requests.Session() as session:
                session.headers.update({'Accept': '*/*'})
                for p in setting:
                    name = p["name"]
                    url = p["url"]
                    category = p["category"]
                    urlfilename = urllib.parse.urlsplit(url).path.split('/')[-1]
                    if "filename-format" in p and len(p["filename-format"]) > 0:
                        f = p["filename-format"]
                    else:
                        if len(category) > 0:
                            f = "{category}/{name}-{urlfilename}"
                        else:
                            f = "{name}-{urlfilename}"
                    filename = f.format(name=name, category=category, urlfilename=urlfilename)
                    parent_dir = pathlib.Path(filename).parent
                    if str(parent_dir) != ".":
                        parent_dir.mkdir(parents=True, exist_ok=True)
                    download(session, url, filename)
    else:
        print("must arg \"jsonfile\"")
        sys.quit(1)