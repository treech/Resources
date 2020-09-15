# 背景

![](https://github.com/yeguoqiang/PicRemote/blob/master/common/gitconfig%E6%9C%AC%E5%9C%B0%E8%B7%AF%E5%BE%84.png?raw=true)

由于开了梯子，每次提交公司代码(私有服务器)都需要手动开关proxy，严重影响我们的开发效率，于是我手写了windows环境和linux环境下的代理设置脚本。

# windows 脚本(set_proxy.bat)

```bash
CHCP 65001
@echo off
:again
cls
echo.
echo.
echo ######################输入编号######################
echo 1.开启git代理
echo 2.关闭git代理
set /p num=
if "%num%"=="1" (
git config --global https.proxy https://127.0.0.1:1080
git config --global http.proxy http://127.0.0.1:1080
echo 代理已开启
)

if "%num%"=="2" (
git config --global --unset http.proxy
git config --global --unset https.proxy
echo 代理已关闭
)
git config --global --get http.proxy
git config --global --get https.proxy
pause
```

# linux脚本(set_proxy.sh)

```sh
#!/bin/bash
echo 'Please choose your operation:'
echo '1: add git http proxy'
echo '2: delete git http proxy'
read num

proxy(){
    if [[ 1 == $num ]]; then
        git config --global http.proxy https://127.0.0.1:1080
        git config --global https.proxy http://127.0.0.1:1080
        return 1
    elif [[ 2 == $num ]]; then
        git config --global --unset http.proxy
        git config --global --unset https.proxy
        return 2
    fi
}

proxy

if [ 1 == $? ]; then
	echo "git proxy was setted!"
else
    echo 'git proxy was deleted!'
fi

echo 'final proxy info'	
	git config --global --get http.proxy
	git config --global --get https.proxy
```

**注：由于本地pac文件只能在浏览github等网页时直接走代理，但不能让git工具上传下载代码时走代理，因此才有了这两个工具的由来。**