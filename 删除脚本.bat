@REM #########################################################  
@REM  Name: 递归删除指定的目录，请把此文件放在你希望执行的那个目录  
@REM  Desciption:   
@REM  Author: ygq  
@REM  Date: 2010-11-01  
@REM  Version: 1.0  
@REM  Copyright: Up to you.  
@REM #########################################################  
  
:: @echo on
setlocal enabledelayedexpansion  
  
@REM 设置你想删除的目录  
set WHAT_SHOULD_BE_DELETED=build
  
for /r . %%a in (!WHAT_SHOULD_BE_DELETED!) do (  
  if exist %%a (  
  echo "remove"%%a
  rd /s /q "%%a"  
 )  
)  
  
pause