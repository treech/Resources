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

# 经验
## android
1 Ubuntu下Android Studio的设备连接后设备名后为[null]的解决方法
>  [error: insufficient permissions for device](http://blog.csdn.net/xiaxiangnanxp1989/article/details/8605611) （解决adb shell问题)  //后边不要加GROUP=“***