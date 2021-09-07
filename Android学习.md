# UI

## 新手指引

1. [来抠个图吧~——更优雅的Android UI界面控件高亮的实现](https://juejin.cn/post/6844904120315281422)

## RecyclerView

### Recyclerview



### Adapter

1. [重学RecyclerView Adapter封装的深度思考和实现](https://segmentfault.com/a/1190000023196243)

# Jetpack

- [Android 架构组件基本示例](https://github.com/android/architecture-components-samples/tree/main/BasicSample)

### 自定义View

[Android clipToPadding 使用与疑难点解析](https://www.jianshu.com/p/5404ff08f4fa)

[Android clipChildren 使用与疑难点解析](https://www.jianshu.com/p/99cae82ad0a2)

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

+ 操作环境：oppo K1 Android 10
+ ![image-20210709094453079](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20210709094453079.png)

1. 查看设备列表

   ```sh
   adb devices
   ```

2. 连接adb端口

   ```sh
   adb connect 192.168.0.129:6666
   ```

3. 文件传输模式切换至充电模式

4. 再次查看设备列表会发现报错

   ```sh
   adb devices
   
   cannot connect to 192.168.0.129:6666: 由于目标计算机积极拒绝，无法连接。 (10061)
   ```

5. 再次打开adb调试后

   ```sh
   adb connect 192.168.0.129:6666
   ```
   
6. 再次连接adb端口会提示有多个设备，此时拔掉数据线，adb wifi环境已经OK

   ```sh
   adb tcpip 6666
   
   error: more than one device/emulator
   ```

参考资料：

https://blog.csdn.net/ezconn/article/details/82621724

**adb无线连接正常拔线显示offline解决方案**

https://blog.csdn.net/u013250424/article/details/105616276

# NDK学习

### 视频

1.JNI补充_文件拆分.avi              时间节点 ： 49min

### 获取sdk类的签名

D:\programs\Android\Sdk\platforms\android-30>javap -classpath android.jar -s android.app.Activity

dev正式签名

95:79:7C:B8:39:A7:5D:E0:36:2C:2E:3E:3D:9C:0B:93:81:5A:05:0B

95797CB839A75DE0362C2E3E3D9C0B93815A050B

# android MavenCentral库上传

PGP指纹：

```sh
2C9C998F86E40AD147C2C6632AF1983C6C3E621B
```

github ssh keys

```sh
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
```

picGo token

```sh
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
```

github token

```sh
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
```

# 开源库学习

+ 弹出框

    https://github.com/goweii/AnyDialog

    https://github.com/goweii/AnyLayer
    
    https://github.com/kakajika/RelativePopupWindow

+ 状态布局

    https://github.com/KingJA/LoadSir
	
+ 图片编辑

    https://github.com/siwangqishiq/ImageEditor-Android.git
    
+ 工具类（更新时间20210705）

    https://github.com/Blankj/AndroidUtilCode

+ AndroidSdk配置

    ```gradle
    signing.keyId=6C3E621B
    signing.password=_qiang2017
    signing.secretKeyRingFile=D\:\\wx\\yeguoqiang_0x6C3E621B_SECRET.gpg
    sonatype.username=ygq
    sonatype.password=Abcd1234567,
    ```

# Kotlin学习

   1. [教你如何完全解析Kotlin中的类型系统](https://blog.csdn.net/u013064109/article/details/88985474)

#### 1) os.getcwd();<span id="jump2"></span>

```python
3
```



