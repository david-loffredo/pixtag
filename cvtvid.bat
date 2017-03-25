@echo off
SETLOCAL
set script=cvtvid.pl
set args=

:set_args
   if %1X==X goto done_args
   set args=%args% %1
   shift
   goto set_args
:done_args

perl -S %script% %args%
ENDLOCAL

