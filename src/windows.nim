# Copyright (c) 2020 Hiroki YASUHARA
# MIT License - Look at LICENSE.txt for details.

import os
import httpclient
import asyncdispatch
import sets
import strformat
import strutils
import tables
import uri
import macros

import zip/zipfiles
import nim7z
import progress

import ./conf as conf

macro dynamicImport(dummy: static[string]): untyped =
  result = newNimNode(nnkStmtList)
  if fileExists(currentSourcePath().splitPath.head / "generatedcode" / "staticlink.nim"):
    result.add(nnkImportStmt.newTree(newIdentNode("./generatedcode/staticlink")))
    static:
      echo("add import ./generatedcode/staticlink")
  result.add(newEmptyNode())
dynamicImport("")

const
  directoryNim = "nim"
  directoryNimble = "nimble"
  directoryHome = "home"
  directoryTemp = "temp"
  directoryScripts = "scripts"
  directoryProjects = "projects"
  directoryMingw = "mingw64"

  directoriesForCreate = [
    directoryNimble,
    directoryHome,    
    directoryTemp,
    directoryScripts,
    directoryProjects,
    directoryHome / "AppData" / "Local",
    directoryHome / "AppData" / "LocalLow",
    directoryHome / "AppData" / "Roaming",
  ]

  downloadNimFilename = "download_nim.zip"

  downloadUrlForMingw = "https://nim-lang.org/download/mingw64.7z"
  downloadMingwFilename = "download_mingw64.7z"

  scriptActivateFilepath = directoryScripts / "activate.ps1"
  scriptDeactivateFilepath = directoryScripts / "deactivate.ps1"
  scriptNimbleInstallFilepath = directoryScripts / "nimbleinstall.ps1"

let 
  downloadUrlTableForNim = {
    "latest": "https://nim-lang.org/download/nim-1.2.4_x64.zip",
    "1.2.4": "https://nim-lang.org/download/nim-1.2.4_x64.zip",
    "1.2.2": "https://nim-lang.org/download/nim-1.2.2_x64.zip",
    "1.2.0": "https://nim-lang.org/download/nim-1.2.0_x64.zip",
    "1.0.6": "https://nim-lang.org/download/nim-1.0.6_x64.zip",
    "1.0.4": "https://nim-lang.org/download/nim-1.0.4_x64.zip",
    "1.0.2": "https://nim-lang.org/download/nim-1.0.2_x64.zip",
    "1.0.0": "https://nim-lang.org/download/nim-1.0.0_x64.zip",
  }.newTable

template errorHook(msg: string, body: untyped): untyped = 
  try:
    body
  except:
    stderr.writeLine(msg)
    stderr.writeLine(getCurrentExceptionMsg())
    raise

when defined(release):
  template topWrap(body: untyped): untyped =
    try:
      body
    except:
      quit(QuitFailure)     
else:
  template topWrap(body: untyped): untyped =
    body

proc getContentForScriptActivate(nimDir, mingwDir: string) : ref string =
  var contentLineForNim, contentLineForMingw: string
  if len(nimDir) == 0:
    contentLineForNim = "$NimDir = Join-Path $TopDir \"nim\""
  else:
    contentLineForNim = &"$NimDir = \"{nimDir}\""
  if len(mingwDir) == 0:
    contentLineForMingw = "$MingwDir = Join-Path $TopDir \"mingw64\""
  else:
    contentLineForMingw = &"$MingwDir = \"{mingwDir}\""
  result = new string
  result[] = """
if ($env:PATH_BACKUP_NCE -ne $null) {
	Write-Host "already activated"
	exit
}
$env:PATH_BACKUP_NCE = $env:PATH

if ($env:NIMBLE_DIR -ne $null) {
    $env:NIMBLE_DIR_BACKUP_NCE = $env:NIMBLE_DIR
}
if ($env:TEMP -ne $null) {
    $env:TEMP_BACKUP_NCE = $env:TEMP
}
if ($env:USERPROFILE -ne $null) {
    $env:USERPROFILE_BACKUP_NCE = $env:USERPROFILE
}

$TopDir  = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$ScriptsDir = $PSScriptRoot
$NimbleDir = Join-Path $TopDir "nimble"
<contentLineForNim>
<contentLineForMingw>
$TempDir = Join-Path $TopDir "temp"
$HomeDir = Join-Path $TopDir "home"

$env:NIMBLE_DIR = $NimbleDir
$env:TEMP = $TempDir
$env:USERPROFILE = $HomeDir
$env:PATH = ($ScriptsDir + ";" + (Join-Path $NimbleDir "bin") + ";" + (Join-Path $NimDir "bin") + ";" + (Join-Path $MingwDir "bin") + ";" + $env:PATH)
""".fmt('<', '>')

proc getContentForScriptDeactivate() : ref string = 
  result = new string
  result[] = """
if ($env:PATH_BACKUP_NCE -eq $null) {
	Write-Host "not activated yet"
	exit
}
$env:PATH = $env:PATH_BACKUP_NCE
Remove-Item Env:PATH_BACKUP_NCE

if ($env:NIMBLE_DIR -ne $null) {
    Remove-Item Env:NIMBLE_DIR
}
if ($env:NIMBLE_DIR_BACKUP_NCE -ne $null) {
    $env:NIMBLE_DIR = $env:NIMBLE_DIR_BACKUP_NCE
    Remove-Item Env:NIMBLE_DIR_BACKUP_NCE
}
if ($env:TEMP_BACKUP_NCE -ne $null) {
    $env:TEMP = $env:TEMP_BACKUP_NCE
    Remove-Item Env:TEMP_BACKUP_NCE
}
if ($env:USERPROFILE_BACKUP_NCE -ne $null) {
    $env:USERPROFILE = $env:USERPROFILE_BACKUP_NCE
    Remove-Item Env:USERPROFILE_BACKUP_NCE
}
"""

proc getContentForScriptNimbleInstall() : ref string = 
  result = new string
  result[] = """
$TopDir  = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$HomeDir = Join-Path $TopDir "home"

$env:USERPROFILE = $HomeDir
$NimbleArgs = @("install") + $Args

Start-Process -FilePath "nimble" -ArgumentList $NimbleArgs -NoNewWindow -Wait
"""

proc download(url: string, filename: string) {.async.} =
  var bar = newProgressBar(total = 10000)
  block:
    echo(&"download {url}")
    var client = newAsyncHttpClient()
    defer:
      client.close() 
    bar.start()
    client.onProgressChanged = proc(total, progress, speed: BiggestInt) {.async.} =
      var count: int = 0
      if total != 0:
        count = (progress.toBiggestFloat() / total.toBiggestFloat() * 10000).toInt
      bar.set(count)
    await client.downloadFile(url, filename)
    bar.finish()

proc downloadAndExtractNim(url: string) = 
  var topDirectories = initHashSet[string]()
  block:
    #[
    echo(&"download {url}")
    var client = newHttpClient()
    defer:
      client.close() 
    var response = client.get(download_url_for_nim)
    var z: ZipArchive
    z.fromBuffer(response.body) # unavailable in windows, because not implement inside function in libzip_all.c 
    ]#
    if existsFile(downloadNimFilename):
      removeFile(downloadNimFilename)
    waitFor download(url, downloadNimFilename)
  block:
    echo("extract nim")
    var z: ZipArchive
    if not z.open(downloadNimFilename):
      echo(&"cannot open \"{downloadNimFilename}\"")
      quit(QuitFailure)
    defer:
      z.close()
    z.extractAll("./")
    # specify top directory, and rename
    for file in walkFiles(z):
      var f : string
      if file.startsWith("./"):
        f = file.substr(2)
      else:
        f = file
      if f.contains("/"):
        topDirectories.incl(file[0..<file.find("/")])
  for dir in topDirectories:
    if dir.startsWith(directoryNim) and dir != directoryNim:
      moveDir(dir, directoryNim)
      echo(&"rename directory \"{dir}\" -> \"{directoryNim}\"")
  # delete download file
  removeFile(downloadNimFilename)

proc downloadAndExtractMingw() = 
  block:
    if existsFile(downloadMingwFilename):
      removeFile(downloadMingwFilename)
    waitFor download(downloadUrlForMingw, downloadMingwFilename)
  block:
    echo("extract mingw")
    var svnz = new7zFile(downloadMingwFilename)
    defer:
      svnz.close()
    svnz.extract(".")
  # delete download file
  removeFile(downloadMingwFilename)

proc writeScriptActivate(nimDir, mingwDir: string) = 
  if not existsFile(scriptActivateFilepath):
    echo(&"write script \"{scriptActivateFilepath}\"")
    let content = getContentForScriptActivate(nimDir, mingwDir)
    writeFile(scriptActivateFilepath, content[])
  else:
    echo(&"already exist script \"{scriptActivateFilepath}\". skip")

proc writeScriptDeactivate() =
  if not existsFile(scriptDeactivateFilepath):
    echo(&"write script \"{scriptDeactivateFilepath}\"")
    let content = getContentForScriptDeactivate()
    writeFile(scriptDeactivateFilepath, content[])
  else:
    echo(&"already exist script \"{scriptDeactivateFilepath}\". skip")

proc writeScriptNimbleInstall() =
  if not existsFile(scriptNimbleInstallFilepath):
    echo(&"write script \"{scriptNimbleInstallFilepath}\"")
    let content = getContentForScriptNimbleInstall()
    writeFile(scriptNimbleInstallFilepath, content[])
  else:
    echo(&"already exist script \"{scriptNimbleInstallFilepath}\". skip")

proc setup*(config: conf.ConfigRef) =
  topWrap:
    let envPath = config.envPath
    if config.clean and existsDir(envPath):
      errorHook(&"failed to remove \"{envPath}\""):
        removeDir(envPath)
    # create closed environment directory
    if not existsDir(envPath):
      echo(&"create directory \"{envPath}\"")
      errorHook(&"failed to create \"{envPath}\""):
        createDir(envPath)
    setCurrentDir(envPath)

    # create sub directories
    var createdDirs: seq[string]
    errorHook("failed to create directory"):
      for d in directoriesForCreate:
        if not existsDir(d):
          echo(&"create directory \"{envPath}{DirSep}{d}\"")
          createDir(d)
          createdDirs.add(d)

    # install nim
    if not config.useLocalNimDirectory():
      errorHook("failed to install nim under env"):
        if config.updateNim and existsDir(directoryNim):
          removeDir(directoryNim)
        if not existsDir(directoryNim):
          var url: string
          if config.nimSpecified in downloadUrlTableForNim:
            url = downloadUrlTableForNim[config.nimSpecified]
          elif isAbsolute(parseUri(config.nimSpecified)):
            url = config.nimSpecified
          else:
            raise newException(CatchableError, "invalid nim version or nim download url")
          downloadAndExtractNim(url) 

    # install mingw
    if not config.useLocalMingwDirectory():
      errorHook("failed to install mingw under env"):
        if config.updateMingw and existsDir(directoryMingw):
          removeDir(directoryMingw)
        if not existsDir(directoryMingw):
          downloadAndExtractMingw()

    # create scripts
    echo("create(update) scripts if needed...")
    if config.updateScripts:
      errorHook("failed to remove script before update"):
        if existsFile(scriptActivateFilepath):
          removeFile(scriptActivateFilepath)
        if existsFile(scriptDeactivateFilepath):
          removeFile(scriptDeactivateFilepath)
        if existsFile(scriptNimbleInstallFilepath):
          removeFile(scriptNimbleInstallFilepath)
    errorHook("failed to write script"):
      writeScriptActivate(config.localNimDirectory, config.localMingwDirectory)
      writeScriptDeactivate()
      writeScriptNimbleInstall()

    # create nim.cfg  

    echo("Finish!")
    # if create "nimble" directory, encourage "nimble refresh"
    if directoryNimble in createdDirs:
      echo("please run \n>>> scripts\\activate.ps1; nimble refresh")

    
