# Package

version       = "0.1.10204"
author        = "yshrk1597"
description   = "set up nim closed environment"
license       = "MIT"
srcDir        = "src"
binDir        = "output"
bin           = @["nimclosedenv"]
backend       = "c"

# Dependencies

requires "nim >= 1.2.0", "zip >= 0.2.1", "nim7z >= 0.1.5", "progress >= 1.1.1", "regex >= 0.15.0"
