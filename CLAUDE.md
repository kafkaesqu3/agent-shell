install.sh script should install the current claude config to the machine
or set it up in docker via the command line flag

the Dockerfile is the alternative way to deploy

all feature requests, make the changes in both locations

## Shell scripts

Always use LF line endings (`\n`), never CRLF (`\r\n`). CRLF shebangs
(`#!/usr/bin/env bash\r`) silently break execution on Linux. The repo enforces
this via `.gitattributes` — do not introduce `\r` in `.sh` files.
