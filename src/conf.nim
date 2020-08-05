# Copyright (c) 2020 Hiroki YASUHARA
# MIT License - Look at LICENSE.txt for details.

import os
import strformat
import strutils
import parseopt
import regex

type
  ConfigRef* = ref object
    envPath*: string           # must set fullpath
    clean*: bool               # if set, remove existing env directory
    updateNim*: bool           # update nim
    updateScripts*: bool       # uodate 
    nimSpecified*: string      # set version number or download url
    localNimDirectory*: string # set if user want to use already installed nim
    when defined(windows):
      updateMingw*: bool       # update mingw
      localMingwDirectory*: string  # set if user want to use already installed mingw  

proc newConfigRef*(): ConfigRef =
  result = ConfigRef(
    envPath: "",
    clean: false,
    updateNim: false,
    updateScripts: false,
    nimSpecified: "latest",
    localNimDirectory: ""
  )
  when defined(windows):
    result.updateMingw = false
    result.localMingwDirectory = ""

proc useLocalNimDirectory*(config: ConfigRef): bool =
  result = config.localNimDirectory.len() != 0

when defined(windows):
  proc useLocalMingwDirectory*(config: ConfigRef) : bool =
    result = config.localMingwDirectory.len() != 0


proc getAppVersionStr() : string {.compileTime.} =
  let dotNimbleStr = staticRead(currentSourcePath().splitPath.head & DirSep & ".." & DirSep & "nimclosedenv.nimble")
  let r = re"^\s*version\s*=\s*""(.*)"""
  var matches: RegexMatch
  for line in dotNimbleStr.splitLines():
    if line.match(r, matches):
      return line[matches.group(0)[0]]
  return "???"

const versionStr = getAppVersionStr()
when defined(release):
  const buildConfiguration = ""
else:
  const buildConfiguration = "(develop)"

when defined(windows):
  let helpMessage: string = """
<splitPath(getAppFilename()).tail> version : <versionStr> <buildConfiguration>
Usage:
  <splitPath(getAppFilename()).tail> [options] envname
Options:
  --clean
    remove directory env before setup
    defalt: false
  --nim:(nimVersion|URL|localNimDirectory)
    if set version number or 'latest', download and install nim under env.
    if set directory path that nim already installed, use specified path. 
    example
      --nim:latest
        install nim under env. download version depend on this app version
      --nim:1.2.2
        install nim under env. download version is specified
      --nim:https://nim-lang.org/download/nim-1.2.4_x64.zip
        install nim under env. download direct url
      --nim:C:\Users\username\nim-1.2.6
        use already installed nim. path must be fullpath.  
        (not install nim under env)
    default: latest
  --mingw:localMingwDirectory
    use already installed local mingw if set mingw directory path. 
    (not install mingw under env)
    default: "" # this means to install mingw under env
  --updateAll
    set options "--updateNim" and "--updateScripts" and "--updateMingw"
    default: false
  --updateNim
    update nim that installed under env. if set localNimDirectory, ignore this option.
    default: false
  --updateScripts
    update scripts that installed under env.
    default: false
  --updateMingw
    update mingw that installed under env. if set localMingwDirectory, ignore this option.
    default: false
""".fmt('<', '>')
else:
  let helpMessage = """
"""

proc printHelp() =
  echo(helpMessage)

proc parse*(config: ConfigRef, args: seq[TaintedString]) =
  try:
    var parser = initOptParser(args)
    for kind, key, val in parser.getopt():
      case kind:
      of cmdArgument:
        if config.envPath.len() != 0:
          raise newException(CatchableError, "already set env name")
        if not isValidFilename(key):
          raise newException(CatchableError, "invalid env name")
        config.envPath = absolutePath(key)
      of cmdLongOption, cmdShortOption:
        case key:
        of "clean":
          config.clean = true
        of "nim":
          if isAbsolute(val):
            let binPath = joinPath(val, "bin")
            if not existsDir(binPath):
              raise newException(CatchableError, "not exist nim/bin directory")
            config.localNimDirectory = val
          else:
            config.nimSpecified = val
        of "mingw":
          when defined(windows):
            if isAbsolute(val):
              let binPath = joinPath(val, "bin")
              if not existsDir(binPath):
                raise newException(CatchableError, "not exist mingw/bin directory")
              config.localMingwDirectory = val
            else:
              raise newException(CatchableError, "mingw directory must be fullpath")
          else:
            raise newException(CatchableError, &"unknown option {key}")
        of "updateAll":
          config.updateNim = true
          config.updateScripts = true
          config.updateMingw = true
        of "updateNim":
          config.updateNim = true
        of "updateScripts":
          config.updateScripts = true
        of "updateMingw":
          when defined(windows):
            config.updateMingw = true
          else:
            raise newException(CatchableError, &"unknown option {key}")
        of "help":
          raise newException(CatchableError, "help")
        else:
          raise newException(CatchableError, &"unknown option {key}")
      of cmdEnd:
        if config.envPath.len() == 0:
          raise newException(CatchableError, "not set env name")
    if config.envPath.len() == 0:
      raise newException(CatchableError, "not set env name")    
  except:
    let mesg = getCurrentExceptionMsg()
    if mesg != "help":
      stderr.writeLine(getCurrentExceptionMsg())
    printHelp()
    raise