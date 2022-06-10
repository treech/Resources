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

+ [Android clipToPadding 使用与疑难点解析](https://www.jianshu.com/p/5404ff08f4fa)

+ [Android clipChildren 使用与疑难点解析](https://www.jianshu.com/p/99cae82ad0a2)

+ android:adjustViewBounds属性解析
  https://blog.csdn.net/qinxue24/article/details/80093833

+ Paint的setStrokeCap、setStrokeJoin、setPathEffect
  https://blog.csdn.net/lxk_1993/article/details/102936227
  
+ Android Canvas Layer 图层

  https://www.twle.cn/l/yufei/android/android-basic-canvas-layer.html

+ 44


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

## adb录屏

   ```sh
   adb shell screenrecord --time 8 --verbose /sdcard/demo.mp4
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

# 发布Maven库到本地仓库

Gradle7.0 以上使用**publishLocal.gradle**文件

```
apply plugin: 'maven-publish'

// 源代码一起打包
task androidSourcesJar(type: Jar) {
    // 如果有Kotlin那么就需要打入dir : getSrcDirs
    if (project.hasProperty("kotlin")) {
        from android.sourceSets.main.java.getSrcDirs()
    } else if (project.hasProperty("android")) {
        from android.sourceSets.main.java.sourceFiles
    } else {
        from sourceSets.main.allSource
    }
    classifier = 'sources'
}

afterEvaluate {
    publishing {
        publications {
            // Creates a Maven publication called "release".
            release(MavenPublication) {
                from components.release

                groupId project.ext.groupId
                artifactId project.ext.artifactId
                version project.ext.version
                artifact(androidSourcesJar)
            }
        }

        repositories {
            maven {
                url "http://localhost:8081/repository/maven-releases/"
            }
        }
    }
}
```

Gradle7.0 以下使用**publishLocal.gradle**文件

```
apply plugin: 'maven'

def ANDROID_SDK_PATH = "D:\\code\\android\\LocalMaven"

uploadArchives {
    repositories {
        mavenDeployer {
            repository(url: "file://" + ANDROID_SDK_PATH)
            pom.groupId = project.ext.groupId
            pom.artifactId = project.ext.artifactId
            pom.version = project.ext.version
        }
    }
}
```

lib库引用

```
ext {
    groupId = 'com.apowersoft.common'
    artifactId = 'wxtracker'
    version = "10.0.1"
}
apply from: '../publishLocal.gradle'
```

根build.gradle url

```
方式一：
maven {
	url 'http://maven.aoscdn.com/repository/maven-snapshots/'
	allowInsecureProtocol true
	credentials {
		username deployUserName
		password deployPassword
	}
}

方式二：
maven {
	url 'file://D:\\code\\android\\LocalMaven'
}
```

# Gradle初始化脚本（init.gradle）

```
//针对gradle7.0以下build.gradle使用
allprojects {
    repositories {
        maven {url 'file://D:\\code\\android\\LocalMaven'}
        mavenLocal()
        google()
        jcenter()
        mavenCentral()
    }
}

//针对gradle7.0以上settings.gradle使用
settingsEvaluated {
  it.dependencyResolutionManagement {
    repositories {
        maven {url 'file://D:\\code\\android\\LocalMaven'}
        mavenLocal()
        google()
        jcenter()
        mavenCentral()
    }
  }
}
```

```
//打印maven地址
task showRepositories{
    repositories.each {
        println "ygq repository: ${it.name} ('${it.url}')"
    }
}
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



# Https抓包

network_security_config.xml配置

```
<network-security-config>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">picwishsz.oss-cn-shenzhen.aliyuncs.com</domain>
        <domain includeSubdomains="true">gw.aoscdn.com</domain>
        <domain includeSubdomains="true">aw.aoscdn.com</domain>
        <domain includeSubdomains="true">awpp.aoscdn.com</domain>
        <domain includeSubdomains="true">awvp.aoscdn.com</domain>
        <domain includeSubdomains="true">awpy.aoscdn.com</domain>
    </domain-config>
</network-security-config>
```

# 隐私合规检测

```
https://github.com/ChenJunsen/Hegui3.0
```

