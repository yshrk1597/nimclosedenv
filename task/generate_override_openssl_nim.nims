# Copyright (c) 2020 Hiroki YASUHARA
# MIT License - Look at LICENSE.txt for details.

from os import `/`, isAbsolute
import strutils
import strformat

include ./constparameter

const opensslNimFilename = "openssl.nim"
const outputDir = projectDir() / ".." / "src" / "overridestdlib"

if not existsDir(projectDir() / ".." / "src" / opensslDir):
  echo("Not Exist OpenSSL CSource Directory.")
  quit(QuitSuccess)

const insert_pragma_definition = """
when compileOption("dynlibOverride", "ssl"):
  when defined(windows):
    {.pragma: dllssldynlib.}
    {.pragma: dllutildynlib.}
  else:
    {.pragma: dllssldynlib, dynlib: DLLSSLName.}
    {.pragma: dllutildynlib, dynlib: DLLUtilName.}
else:
  {.pragma: dllssldynlib, dynlib: DLLSSLName.}
  {.pragma: dllutildynlib, dynlib: DLLUtilName.}
"""

let pattern1 = "import dynlib"
let pattern2 = "dynlib: DLLSSLName"
let pattern3 = "dynlib: DLLUtilName"
let replace2 = "dllssldynlib"
let replace3 = "dllutildynlib"

var originalOpenSslNimPath : string

let nimDumpStr = gorge("nim dump")
for line in nimDumpStr.splitLines():
  if isAbsolute(line):
    #echo("path: " & line)
    if existsFile(line / opensslNimFilename):
      originalOpenSslNimPath = line / opensslNimFilename
      echo("find " & originalOpenSslNimPath)
      break

if originalOpenSslNimPath.len() != 0:
  if not existsDir(outputDir):
    mkDir(outputDir)
    echo("create dir " & outputDir)
  let outputFilePath = outputDir / opensslNimFilename
  let sourceStr = readFile(originalOpenSslNimPath)
  var outputLines: seq[string]
  echo("write file " & outputFilePath)
  var outputLine: string
  for line in sourceStr.splitLines():
    if pattern1 in line:
      outputLines.add(insert_pragma_definition)
      outputLine = line
    else:
      outputLine = line.replace(pattern2, replace2).replace(pattern3, replace3)
    outputLines.add(outputLine)
  writeFile(outputFilePath, outputLines.join("\n"))
else:
  echo("cannot find " & opensslNimFilename)

echo("Finish!")

