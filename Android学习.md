# UI

## 新手指引

1. [来抠个图吧~——更优雅的Android UI界面控件高亮的实现](https://juejin.cn/post/6844904120315281422)

## RecyclerView

### Recyclerview



### Adapter

1. [重学RecyclerView Adapter封装的深度思考和实现](https://segmentfault.com/a/1190000023196243)

# Jetpack

- [Android 架构组件基本示例](https://github.com/android/architecture-components-samples/tree/main/BasicSample)



# 反编译

1、支持android 8的dex2jar版本
直通车：https://github.com/DexPatcher/dex2jar/releases/tag/v2.1-20190905-lanchon

![image-20210528091737934](https://raw.githubusercontent.com/yeguoqiang/PicRemote/master/common/image-20210528091737934.png)

2、在使用 `jd_gui` 反编译Java项目， 反编译失败的时候，不妨试试这个工具 `Luyten`

直通车：https://github.com/deathmarine/Luyten

参考：https://paper.seebug.org/710/

# adb 命令

## 获取当前activity信息

#8.1之前
window 通过adb shell dumpsys activity | findstr “mFocus”
Linux 通过adb shell dumpsys activity | grep “mFocus”

#8.1之后
window 通过adb shell dumpsys activity | findstr “mResume”
Linux 通过adb shell dumpsys activity | grep “mResume”

## adb 无线调试

**基本操作**

> 1、插上usb连接设备后连接6666端口
>
> adb connect 192.168.10.91:6666
>
> 2、断线后adb tcpip 6666(断线后要调成充电模式下进行调试)

https://blog.csdn.net/ezconn/article/details/82621724

**adb无线连接正常拔线显示offline解决方案**

https://blog.csdn.net/u013250424/article/details/105616276

# NDK学习

### 视频

1.JNI补充_文件拆分.avi              时间节点 ： 4min

### 获取sdk类的签名

D:\programs\Android\Sdk\platforms\android-30>javap -classpath android.jar -s android.app.Activity

dev正式签名

95:79:7C:B8:39:A7:5D:E0:36:2C:2E:3E:3D:9C:0B:93:81:5A:05:0B

95797CB839A75DE0362C2E3E3D9C0B93815A050B

# Android APP 一键退出的方法总结分析

pdf分享 弹出框item间距调大

app端和平板

点击更多-》弹出框框应该在下方 间距调大

android库上传

密钥对创建成功。

指纹：2C9C998F86E40AD147C2C6632AF1983C6C3E621B

github token

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
