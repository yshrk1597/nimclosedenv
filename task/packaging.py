# -*- coding: utf-8 -*-


import sys
import os
import pathlib
import json
import shutil
import tempfile
import re

current_dir = pathlib.Path.cwd().resolve()

this_script_parent = pathlib.Path(__file__).parent.resolve()
os.chdir(this_script_parent)

version = ""
with open("../nimclosedenv.nimble", encoding='utf-8') as f:
    p = re.compile(r'version\s*=\s*"(\S+)"')
    line = f.readline()
    while line:
        m = p.search(line)
        if m:
            version = m.group(1)
            print(f"version = {version}")
            break
        line = f.readline()

platform = ""
if sys.platform == "win32":
    platform = "win"
elif sys.platform == "linux":
    platform = "linux"
elif sys.platform == "darwin":
    platform = "mac"
else:
    print("platform not support")
    sys.quit(1)
print(f"platform = {platform}")

# load setting files
settings = {}
with open(f"package_setting_bin_{platform}.json", encoding='utf-8') as f:
    settings["bin"] = json.load(f)
with open(f"package_setting_src_{platform}.json", encoding='utf-8') as f:
    settings["src"] = json.load(f)

for target, s in settings.items():
    package_basename = f"nimclosedenv-{target}-{version}-{platform}"
    # tempdir 
    with tempfile.TemporaryDirectory() as temp_path:
        temp_dir = pathlib.Path(temp_path).resolve()
        # copy
        for cinfo in s["copies"]:
            src_path = this_script_parent.joinpath(cinfo["src"]).resolve()
            if len(cinfo["dst"]) > 0:
                dst_path = temp_dir.joinpath(cinfo["dst"]).resolve()
            else:
                dst_path = temp_dir
            if cinfo["type"] == "ff":
                parent_dir = dst_path.parent
            elif cinfo["type"] == "fd":
                parent_dir = dst_path
            elif cinfo["type"] == "dd":
                parent_dir = dst_path.parent
            else:
                parent_dir = None
            if parent_dir is not None and str(parent_dir) != ".":
                parent_dir.mkdir(parents=True, exist_ok=True)
            print(f"{src_path} -> {dst_path}")
            if cinfo["type"] == "dd":
                shutil.copytree(src_path, dst_path, dirs_exist_ok=True)
            else:
                shutil.copy(src_path, dst_path)
        # get third-party licenses
        script_path = this_script_parent.joinpath("collect_thirdparty_licenses.py").resolve()
        setting_path = this_script_parent.joinpath(s["license_setting_file"]).resolve()
        licenses_path = temp_dir.joinpath("thirdparty-licenses").resolve()
        licenses_path.mkdir(parents=True, exist_ok=True)
        os.chdir(licenses_path)
        ret = os.system(f'python "{script_path}" "{setting_path}"')
        if ret != 0:
            sys.quit(1)
        os.chdir(this_script_parent)
        # archive
        print(f"create zip {package_basename}.zip")
        shutil.make_archive(current_dir.joinpath(package_basename), 'zip', root_dir=temp_path)
