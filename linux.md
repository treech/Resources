# 国内镜像源(以清华 阿里 官方三选一)
[清华大学开源镜像软件镜像站](https://mirrors.tuna.tsinghua.edu.cn/help/ubuntu/)

[ubuntu源列表（清华，阿里，官方，选一即可)](https://www.cnblogs.com/iamhenanese/p/5514111.html)


#  技巧
1 Linux下nautilus：图形与终端的结合 
>[ Linux下nautilus：图形与终端的结合 ](http://blog.csdn.net/xy_kok/article/details/72954046) 

>$ nautilus .        // 命令后面一个“.”，表示当前目录

>$ nautilus -q	//如果当前打开了多个文件管理器，不需要鼠标一个个点掉，一个命令就可以将其尽数关闭

2 Vi
>grep -niR '想要查找的字符' xxx
注：n，显示行号　R，查找所有文件包含子目录　i,忽略大小写 最后的“xxx”表示想要查找的文件名

> 查找并显示test.log文件中含有关键字的行
grep -E 'abc|123' test.log
grep 'abc' test.log|grep '123' 
grep -C 5 foo file -n显示file文件里匹配foo字串那行以及上下5行
grep -B 5 foo file -n显示foo及前5行
grep -A 5 foo file -n显示foo及后5行

参考资料:[linux grep命令详解](https://www.cnblogs.com/ggjucheng/archive/2013/01/13/2856896.html)

# 经验
## android
1 Ubuntu下Android Studio的设备连接后设备名后为[null]的解决方法
>  [error: insufficient permissions for device](http://blog.csdn.net/xiaxiangnanxp1989/article/details/8605611) （解决adb shell问题)  //后边不要加GROUP=“***
2 Ubuntu adb配置
>etc/udev/rules.d路径下新建51-android.rules文件，内容如下:

SUBSYSTEM=="usb", ATTRS{idVendor}=="12d1", ATTRS{idProduct}=="103a",MODE="0666"
SUBSYSTEM=="usb",ATTRS{idVendor}=="18d1",ATTRS{idProduct}=="4ee7",MODE="0666"
SUBSYSTEM=="usb",ATTRS{idVendor}=="18d1",ATTRS{idProduct}=="201c",MODE="0666"
注意:只需要修改idVendor与idProduct属性即可.
如果以上不行需要用下面这种:
SUBSYSTEM=="usb", ATTR{idVendor}=="12d1", MODE="0666", GROUP="plugdev"

# adb命令
查找:
find . -name "*.java"|xargs grep -rwni 'abc' --color

查看activity堆栈
adb shell logcat | grep ActivityManager
adb shell dumpsys activity activities

adb 查看最上层成activity名字:
linux:
adb shell dumpsys activity | grep "mFocusedActivity"

windows:
adb shell dumpsys activity | findstr "mFocusedActivity"

查看Android 系统发送的广播：
adb shell dumpsys |grep BroadcastRecord

# 重新装ubuntu需要用到的东西
[gradle地址](http://services.gradle.org/distributions/)

# 需要提前下载好的东西
android-studio sdk jdk

# 需要备份的配置
有四个:

~/.bashrc

~/.vimrc

.gitconfig

etc/udev/rules.d/51-android.rules

有6个包需要备份:

~/.gradle

android-studio

sdk

eclipse

jdk

sublime_text


# 装双系统需知
u盘装windows需要用大白菜装机</br>
u盘装ubuntu需要用ultralSO</br>
windows引导启动ubuntu需要用easybcd</br>
参考：[Ubuntu 16.04 安装基础入门教程](https://jingyan.baidu.com/article/3c48dd348bc005e10be358eb.html),需要注意的是便捷启动改成syslinux,ubuntu安装完成再用windows中的easybcd引导启动，同时选择syslinux与boot所在分区的盘。

# 装ubuntu需要安装的插件
terminal管理工具:Terminator终端终结者
sublime_text3
melt
