# 1. 痛点
   安卓开发都是使用Android Studio，但是AS默认的都会把以下4个目录缓存到C:\Users\Admin目录下，具体各个目录的作用如下：
1. .android Android SDK生成的AVD（Android Virtual Device Manager）即模拟器存放路径

2. .AndroidStudio 配置、插件缓存文件夹、最近打开的项目

3. .gradle 这其中存储的是本地的gradle全局配置文件 ，但是在每次更新gradle后，这个文件都会增大（可以配置离线gradle）

4. .m2 maven仓库下载的库文件保存在这里，使用的所有的maven仓库都会先缓存到这里，然后再添加到你的项目中进行使用。如果你用的插件越多这个文件夹将会持续增大（但目前仅java的项目需要配置）

# 2. 解决方式

## 2.1 配置环境变量

### 2.1.1 系统变量

- Java环境

```properties
JAVA_HOME
C:\programs\Java\jdk1.8.0_251

CLASSPATH
.;%JAVA_HOME%\lib;%JAVA_HOME%\lib\dt.jar;%JAVA_HOME%\lib\tools.jar

MAVEN_HOME
D:\programs\maven\apache-maven-3.6.3

Path中加入以下内容：
%JAVA_HOME%\bin
%MAVEN_HOME%\bin
```

- Android环境

  [官方Android Studio配置指南](https://developer.android.com/studio/intro/studio-config?hl=zh-cn​)

```properties
ANDROID_HOME
D:\programs\Android\Sdk

ANDROID_SDK_HOME
D:\programs\Android
注：1.Android官方已经弃用ANDROID_HOME环境变量，建议使用ANDROID_SDK_ROOT，挂上官方链接(https://developer.android.com/studio/command-line/variables)
   2.经本人测试ANDROID_SDK_HOME环境变量名暂时不能更改，否则更改AVD路径后无法被as识别

GRADLE_USER_HOME
D:\programs\Android\.gradle

Path中加入以下内容：
%ANDROID_HOME%\platform-tools
```

- Flutter环境

```properties
flutter
D:\programs\flutter\bin

Flutter 社区两个中国镜像地址
PUB_HOSTED_URL
https://pub.flutter-io.cn

FLUTTER_STORAGE_BASE_URL
https://storage.flutter-io.cn

Path中加入以下内容：
%flutter%

注：修改idea.properties后运行flutter doctor会报未安装andtoid studio的Error，
```

### 2.1.2 idea.properties配置

要解决痛点问题，最终要修改默认配置(把默认的配置注释打开，修改路径即可)

```properties
D:\programs\Android\AndroidStudio\bin\idea.properties
```

最终的`idea.properties`配置详细如下:

```properties
# Use ${idea.home.path} macro to specify location relative to IDE installation home.
# Use ${xxx} where xxx is any Java property (including defined in previous lines of this file) to refer to its value.
# Note for Windows users: please make sure you're using forward slashes (e.g. c:/idea/system).

idea.home.path=D:/programs/Android
#---------------------------------------------------------------------
# Uncomment this option if you want to customize path to IDE config folder. Make sure you're using forward slashes.
#---------------------------------------------------------------------
idea.config.path={idea.home.path}/.AndroidStudio4.0/config

#---------------------------------------------------------------------
# Uncomment this option if you want to customize path to IDE system folder. Make sure you're using forward slashes.
#---------------------------------------------------------------------
idea.system.path={idea.home.path}/.AndroidStudio4.0/system

#---------------------------------------------------------------------
# Uncomment this option if you want to customize path to user installed plugins folder. Make sure you're using forward slashes.
#---------------------------------------------------------------------
idea.plugins.path=${idea.config.path}/plugins

#---------------------------------------------------------------------
# Uncomment this option if you want to customize path to IDE logs folder. Make sure you're using forward slashes.
#---------------------------------------------------------------------
idea.log.path=${idea.system.path}/log

#---------------------------------------------------------------------
# Maximum file size (kilobytes) IDE should provide code assistance for.
# The larger file is the slower its editor works and higher overall system memory requirements are
# if code assistance is enabled. Remove this property or set to very large number if you need
# code assistance for any files available regardless their size.
#---------------------------------------------------------------------
idea.max.intellisense.filesize=2500

#---------------------------------------------------------------------
# Maximum file size (kilobytes) IDE is able to open.
#---------------------------------------------------------------------
idea.max.content.load.filesize=20000

#---------------------------------------------------------------------
# This option controls console cyclic buffer: keeps the console output size not higher than the specified buffer size (Kb).
# Older lines are deleted. In order to disable cycle buffer use idea.cycle.buffer.size=disabled
#---------------------------------------------------------------------
idea.cycle.buffer.size=1024

#---------------------------------------------------------------------
# Configure if a special launcher should be used when running processes from within IDE.
# Using Launcher enables "soft exit" and "thread dump" features
#---------------------------------------------------------------------
idea.no.launcher=false

#---------------------------------------------------------------------
# To avoid too long classpath
#---------------------------------------------------------------------
idea.dynamic.classpath=false

#---------------------------------------------------------------------
# Uncomment this property to prevent IDE from throwing ProcessCanceledException when user activity
# detected. This option is only useful for plugin developers, while debugging PSI related activities
# performed in background error analysis thread.
# DO NOT UNCOMMENT THIS UNLESS YOU'RE DEBUGGING IDE ITSELF. Significant slowdowns and lockups will happen otherwise.
#---------------------------------------------------------------------
#idea.ProcessCanceledException=disabled

#---------------------------------------------------------------------
# There are two possible values of idea.popup.weight property: "heavy" and "medium".
# If you have WM configured as "Focus follows mouse with Auto Raise" then you have to
# set this property to "medium". It prevents problems with popup menus on some
# configurations.
#---------------------------------------------------------------------
idea.popup.weight=heavy

#---------------------------------------------------------------------
# Removing this property may lead to editor performance degradation under Windows.
#---------------------------------------------------------------------
sun.java2d.d3d=false

#---------------------------------------------------------------------
# Set swing.bufferPerWindow=false to workaround a slow scrolling in JDK6 (see IDEA-35883),
# But this may lead to performance degradation in JDK8, because it disables a double buffering,
# which is needed to eliminate tearing on blit-accelerated scrolling and to restore
# a frame buffer content without the usual repainting, even when the EDT is blocked.
#---------------------------------------------------------------------
swing.bufferPerWindow=true

#---------------------------------------------------------------------
# Removing this property may lead to editor performance degradation under X Window.
#---------------------------------------------------------------------
sun.java2d.pmoffscreen=false

#---------------------------------------------------------------------
# Enables HiDPI support in JBRE
#---------------------------------------------------------------------
sun.java2d.uiScale.enabled=true

#---------------------------------------------------------------------
# Applicable to the Swing text components displaying HTML (except JEditorPane).
# Rebases CSS size map depending on the component's font size to let relative
# font size values (smaller, larger) scale properly. JBRE only.
#---------------------------------------------------------------------
javax.swing.rebaseCssSizeMap=true

#---------------------------------------------------------------------
# Workaround to avoid long hangs while accessing clipboard under Mac OS X.
#---------------------------------------------------------------------
#ide.mac.useNativeClipboard=True

#---------------------------------------------------------------------
# Maximum size (kilobytes) IDEA will load for showing past file contents -
# in Show Diff or when calculating Digest Diff
#---------------------------------------------------------------------
#idea.max.vcs.loaded.size.kb=20480

#---------------------------------------------------------------------
# IDEA file chooser peeks inside directories to detect whether they contain a valid project
# (to mark such directories with a corresponding icon).
# Uncommenting the option prevents this behavior outside of user home directory.
#---------------------------------------------------------------------
#idea.chooser.lookup.for.project.dirs=false

#-----------------------------------------------------------------------
# Experimental option that does a number of things to make truly smooth scrolling possible:
#
# * Enables hardware-accelerated scrolling.
#     Blit-acceleration copies as much of the rendered area as possible and then repaints only newly exposed region.
#     This helps to improve scrolling performance and to reduce CPU usage (especially if drawing is compute-intensive).
#
# * Enables "true double buffering".
#     True double buffering is needed to eliminate tearing on blit-accelerated scrolling and to restore
#     frame buffer content without the usual repainting, even when the EDT is blocked.
#
# * Adds "idea.true.smooth.scrolling.debug" option.
#     Checks whether blit-accelerated scrolling is feasible, and if so, checks whether true double buffering is available.
#
# * Enables handling of high-precision mouse wheel events.
#     Although Java 7 introduced MouseWheelEven.getPreciseWheelRotation() method, JScrollPane doesn't use it so far.
#     Depends on the Editor / General / Smooth Scrolling setting, remote desktop detection and power save mode state.
#     Ideally, we need to patch the runtime (on Windows, Linux and Mac OS) to improve handling of the fine-grained input data.
#     This feature can be toggled via "idea.true.smooth.scrolling.high.precision" option.
#
# * Enables handling of pixel-perfect scrolling events.
#     Currently this mode is available only under Mac OS with JetBrains Runtime.
#     This feature can be toggled via "idea.true.smooth.scrolling.pixel.perfect" option.
#
# * Enables interpolation of scrolling input (scrollbar, mouse wheel, touchpad, keys, etc).
#     Smooths input which lacks both spatial and temporal resolution, performs the rendering asynchronously.
#     Depends on the Editor / General / Smooth Scrolling setting, remote desktop detection and power save mode state.
#     The feature can be tweaked using the following options:
#       "idea.true.smooth.scrolling.interpolation" - the main switch
#       "idea.true.smooth.scrolling.interpolation.scrollbar" - scrollbar interpolation
#       "idea.true.smooth.scrolling.interpolation.scrollbar.delay" - initial delay for scrollbar interpolation (ms)
#       "idea.true.smooth.scrolling.interpolation.mouse.wheel" - mouse wheel / touchpad interpolation
#       "idea.true.smooth.scrolling.interpolation.mouse.wheel.delay.min" - minimum initial delay for mouse wheel interpolation (ms)
#       "idea.true.smooth.scrolling.interpolation.mouse.wheel.delay.max" - maximum initial delay for mouse wheel interpolation (ms)
#       "idea.true.smooth.scrolling.interpolation.precision.touchpad" - precision touchpad interpolation
#       "idea.true.smooth.scrolling.interpolation.precision.touchpad.delay" - initial delay for precision touchpad interpolation (ms)
#       "idea.true.smooth.scrolling.interpolation.other" - interpolation of other input sources
#       "idea.true.smooth.scrolling.interpolation.other.delay" - initial delay for other input source interpolation (ms)
#
# * Adds on-demand horizontal scrollbar in editor.
#     The horizontal scrollbar is shown only when it's actually needed for currently visible content.
#     This helps to save editor space and to prevent occasional horizontal "jitter" on vertical touchpad scrolling.
#     This feature can be toggled via "idea.true.smooth.scrolling.dynamic.scrollbars" option.
#-----------------------------------------------------------------------
#idea.true.smooth.scrolling=true

#---------------------------------------------------------------------
# IDEA can copy library .jar files to prevent their locking.
# By default this behavior is enabled on Windows and disabled on other platforms.
# Uncomment this property to override.
#---------------------------------------------------------------------
# idea.jars.nocopy=false

#---------------------------------------------------------------------
# The VM option value to be used to start a JVM in debug mode.
# Some JREs define it in a different way (-XXdebug in Oracle VM)
#---------------------------------------------------------------------
idea.xdebug.key=-Xdebug

#-----------------------------------------------------------------------
# Change to 'enabled' if you want to receive instant visual notifications
# about fatal errors that happen to an IDE or plugins installed.
#-----------------------------------------------------------------------
idea.fatal.error.notification=disabled

disable.android.first.run=true

#-----------------------------------------------------------------------
#环境变量配置
#ANDROID_HOME
#D:\programs\Android\Sdk
#ANDROID_SDK_HOME
#D:\programs\Android
#GRADLE_USER_HOME
#D:\programs\Android\.gradle
#path加入一下配置
#%ANDROID_HOME%\platform-tools
#-----------------------------------------------------------------------
```

### 2.1.3 最终效果图

![1597479217336](C:\Users\Admin\AppData\Roaming\Typora\typora-user-images\1597479217336.png)

**注：全部Android有关的文件都在Android文件夹下，后续更换电脑时也能一键转移**

### 2.1.4 爬坑问题

在修改了配置文件idea.properties后插件无法加载(即使已经配置好了idea.plugins.path=${idea.config.path}/plugins)，这是因为as默认加载缓存的配置，需要你手动删除以下缓存内容，重新生成该配置才能使更改路径后的插件被as认识

**D:\programs\Android\AndroidStudio\jre\jre\bin\{idea.home.path}**

