# Copyright (c) 2020 Hiroki YASUHARA
# MIT License - Look at LICENSE.txt for details.

from os import `/`, splitPath
import strutils
import strformat
import regex

include ./constparameter

const generatedNimFilename = "staticlink.nim"
const outputDir = projectDir() / ".." / "src" / "generatedcode"

const importCodeStr = """
import os

{.used.}
"""

const zlibStaticLinkCodeStr = """
# zlib
{.passC: "-I" & (currentSourcePath().splitPath.head / ".." / "<zlibDir>").}
{.compile: (".." / "<zlibDir>" / "*.c", "zlib_$#.obj").} 
""".fmt('<', '>')

const opensslStaticLinkCodeStr = """
# openssl
{.passC: "-D" & "OPENSSLDIR=\"\\\"C:\\\"\"".}
{.passC: "-D" & "ENGINESDIR=\"\\\"C:\\\"\"".}
{.passC: "-I" & (currentSourcePath().splitPath.head / ".." / "<opensslDir>").}
{.passC: "-I" & (currentSourcePath().splitPath.head / ".." / "<opensslDir>" / "include").}
{.passC: "-I" & (currentSourcePath().splitPath.head / ".." / "<opensslDir>" / "crypto").}
{.passC: "-I" & (currentSourcePath().splitPath.head / ".." / "<opensslDir>" / "crypto" / "modes").}
{.passC: "-I" & (currentSourcePath().splitPath.head / ".." / "<opensslDir>" / "crypto" / "ec" / "curve448").}
{.passC: "-I" & (currentSourcePath().splitPath.head / ".." / "<opensslDir>" / "crypto" / "ec" / "curve448" / "arch_32").}
{.passL: "-lws2_32 -lcrypt32".}
""".fmt('<', '>')

var outputLines: seq[string]

if existsDir(projectDir() / ".." / "src" / zlibDir):
  outputLines.add(zlibStaticLinkCodeStr)

if existsDir(projectDir() / ".." / "src" / opensslDir):
  outputLines.add(opensslStaticLinkCodeStr)
  let makefileStr = readFile(projectDir() / ".." / "src" / opensslDir / "makefile")
  let r = re"^(libcrypto|libssl)\.lib:"
  for line in makefileStr.splitLines():
    if r in line:
      for word in line.splitWhitespace():
        if word.endsWith(".obj"):
          let sourcePath = ".." / opensslDir / word[0..^4] & "c"
          let objPath = &"openssl_{word.splitPath().tail}"
          let compileStmt = "{.compile: (<repr(sourcePath)>, <repr(objPath)>).}".fmt('<', '>')
          outputLines.add(compileStmt)

if outputLines.len() > 0:
  outputLines.insert(importCodeStr, 0)
  if not existsDir(outputDir):
    mkDir(outputDir)
    echo("create dir " & outputDir)
  let outputFilePath = outputDir / generatedNimFilename
  echo("write file " & outputFilePath)
  writeFile(outputFilePath, outputLines.join("\n"))
else:
  echo("not generate " & generatedNimFilename)

echo("Finish!")