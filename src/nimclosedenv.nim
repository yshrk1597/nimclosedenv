# Copyright (c) 2020 Hiroki YASUHARA
# MIT License - Look at LICENSE.txt for details.

import os
import ./conf as conf

when defined(windows):
  import ./windows as platform
  static:
    echo("target platform is windows")
elif defined(macosx):
  import ./macosx as platform
  static:
    echo("target platform is macosx")
elif defined(linux):
  import ./linux as platform
  static:
    echo("target platform is linux")
else:
  {.fatal: "not defined os" }

when isMainModule:
  var c = conf.newConfigRef()
  try:
    c.parse(commandLineParams())
  except:
    quit(QuitFailure)      
  platform.setup(c)
