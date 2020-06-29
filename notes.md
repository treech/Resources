[TOC]
## Java基础
*	[为什么String要设计成不可变的](http://blog.csdn.net/renfufei/article/details/16808775)
*	请写出代码计算二叉树的最大深度，分别用『递归』和『非递归』的方式实现
*	[如何检查内存泄漏，并解决](http://www.jianshu.com/p/bf159a9c391a)

## Android基础知识
* [GcsSloop/AndroidNote](https://github.com/GcsSloop/AndroidNote/tree/master)

  >安卓学习笔记
* [tangqi92/Android-Tips](https://github.com/tangqi92/Android-Tips)

  >An awesome list of tips for android. http://itangqi.me/2015/09/14/android-…
  >

* [A diagram of the Android Activity / Fragment lifecycle](https://github.com/xxv/android-lifecycle)

### View
*	[三个案例带你看懂LayoutInflater中inflate方法两个参数和三个参数的区别](http://blog.csdn.net/u012702547/article/details/52628453)
*	[Android LayoutInflater原理分析，带你一步步深入了解View(一)](http://blog.csdn.net/guolin_blog/article/details/12921889)

### 自定义View
* [自定义View，有这一篇就够了](http://blog.csdn.net/huachao1001/article/details/51577291)
* [Canvas中drawRoundRect()方法介绍](https://www.jianshu.com/p/c050bee691d3)
* [Android GradientDrawable取代shape的使用](https://www.jianshu.com/p/7588590f64a5)
* [ViewOutlineProvider实现圆角矩形](https://www.jianshu.com/p/14c502ab05f9)
* [【Android UI】TextView的垂直方向概念之top，bottom，ascent，descent，baseline](https://blog.csdn.net/xude1985/article/details/51532949)

### View的事件体系
#### view的事件体系五部曲
*	[View的事件体系(一)View的基础知识](http://www.jianshu.com/p/531b366f56f2)
*	[View的事件体系(二)实现View滑动的三种方式](http://www.jianshu.com/p/0da16dbe427e)
*	[View的事件体系(三)View的弹性滑动](http://www.jianshu.com/p/6eca3fa1b0de)
*	[View的事件体系(四)View 的事件分发机制](http://www.jianshu.com/p/804eb1a5dd13)
*	[View的事件体系(五)View滑动冲突的解决方案](http://www.jianshu.com/p/bb6814073f5f)

### 事件分发机制
* [一篇文章彻底搞懂Android事件分发机制](https://mp.weixin.qq.com/s?__biz=MzI0MjE3OTYwMg==&mid=2649550048&idx=1&sn=613c0cf5bcd2050e960c195537cdc562&chksm=f118079dc66f8e8b372d9afcfb691accf9edbc14251e59a7eb85982f5495835cc4354c48e232&mpshare=1&scene=24&srcid=1027NJY4DeGRYeayjT3EkYvB#rd)

  >![](http://mmbiz.qpic.cn/mmbiz_png/jE32KtUXy6HJWUt6gmArFJJLSwLBf7QV6OibwmHVAFjZJBmmoaz3xhtEZDZ8lX4cUwcXQT2Yk5B1GIQ63wKuicqg/640?wx_fmt=png&wxfrom=5&wx_lazy=1)

* [android ViewPager嵌套使用的滑动冲突解决方案，优先让里层的ViewPager滑动完毕后外层的ViewPager再滑动](https://blog.csdn.net/puyacheer/article/details/79091795)

### Fragment
*	[Fragment详解](http://blog.csdn.net/harvic880925/article/details/44927375)
	+ 1、《Fragment详解之一——概述》
	+ 2、《Fragment详解之二——基本使用方法》
	+ 3、《Fragment详解之三——管理Fragment（1）》
	+ 4、《Fragment详解之四——管理Fragment（2）》
	+ 5、《Fragment详解之五——Fragment间参数传递》
	+ 6、《Fragment详解之六——如何监听fragment中的回退事件与怎样保存fragment状态》
*	[Fragment的四种跳转](http://www.jianshu.com/p/ab1cb7ddf91f)
	+ 1、从同一个Activiy的一个Fragment跳转到另外一个Fragment
	+ 2、从一个Activity的Fragment跳转到另外一个Activity
	+ 3、从一个Activity跳转到另外一个Activity的Fragment上
	+ 4、从一个Activity的Fragment跳转到另外一个Activity的Fragment上
*	[YoKeyword/Fragmentation](https://github.com/YoKeyword/Fragmentation)
	>A powerful library that manage Fragment for Android! 
	>
	>特性
	>
	>1、可以快速开发出各种嵌套设计的Fragment App
	>
	>2、悬浮球／摇一摇实时查看Fragment的栈视图Dialog，降低开发难度
	>
	>3、增加启动模式、startForResult等类似Activity方法
	>
	>4、类似Android事件分发机制的Fragment回退方法：onBackPressedSupport()，轻松为每个Fragment实现Back按键事件
	>
	>5、提供onSupportVisible()等生命周期方法，简化嵌套Fragment的开发过程； 提供统一的onLazyInitView()懒加载方法
	>
	>6、提供 Fragment转场动画 系列解决方案，动态更换动画
	>
	>7、更强的兼容性, 解决多点触控、重叠等问题
	>
	>8、支持SwipeBack滑动边缘退出(需要使用Fragmentation_SwipeBack库,详情README)

## Android源码

- https://android.googlesource.com/

- 源码下载和阅读

    [windows环境下 android 源码阅读](https://blog.csdn.net/xunmeng_93/article/details/78562143)

- [![img](http://androidxref.com/images/title.png)](http://androidxref.com/)

## VLC有关问题

1. vlc无法全屏的问题解决方案

    https://code.videolan.org/videolan/libvlc-android-samples/-/blob/5c9c1ccd860f6ae1560fb1f159a6a592d6855e7d/java_sample/src/main/java/org/videolan/javasample/JavaActivity.java

    https://www.programcreek.com/java-api-examples/?code=KKorvin/uPods-android/uPods-android-master/app/src/main/java/com/chickenkiller/upods2/fragments/FragmentVideoPlayer.java

    注：首推第一个

## Android项目重构

*	[如何将既有项目重构成 MVP 模式](https://mp.weixin.qq.com/s?__biz=MzI0MjE3OTYwMg==&mid=2649549997&idx=1&sn=774f53be2eeba53b8a0813dce1fcfcb8&chksm=f11807d0c66f8ec68dc014dd55fdbb93c755b9d11c2608ea19ae9f7f5dd10a50e1ac8f5e80d3&mpshare=1&scene=24&srcid=1027vXARAR6wV3DbwIpVTghR#rd)
* [antoniolg/androidmvp](https://github.com/antoniolg/androidmvp)

  >MVP Android Example
* [MindorksOpenSource/android-mvp-architecture](https://github.com/MindorksOpenSource/android-mvp-architecture)

  >This repository contains a detailed sample app that implements MVP architecture using Dagger2, GreenDao, RxJava2, FastAndroidNetworking and PlaceholderView https://mindorks.com/open-source-proj…
* [android10/Android-CleanArchitecture](https://github.com/android10/Android-CleanArchitecture)

  >MVVM模式一个干净的设计框架
*	[Android架构合集](https://github.com/wwttt2004/Android-Architecture)
*	组件化之后组件间activity跳转，如果完全解耦需使用[**ActivityRouter**](https://github.com/mzule/ActivityRouter)以及阿里巴巴路由框架[**ARouter**](https://github.com/alibaba/ARouter)
*	[基于开源项目搭建 Android 技术堆栈](https://mp.weixin.qq.com/s?__biz=MzA3ODg4MDk0Ng==&mid=2651113557&idx=1&sn=8d1ef7cf5f65f9b53cf726c5de108c38&chksm=844c6188b33be89e487955f1da533402ab845aa2e27eda04afbb96436e77b8d88c259fd0ae33&mpshare=1&scene=24&srcid=10248D7nCMjrfL9tnZ2TQqgT#rd)
*	[[墙裂推荐]Android搭建属于自己的技术堆栈和App架构](https://mp.weixin.qq.com/s?__biz=MzI0MjE3OTYwMg==&mid=2649550530&idx=1&sn=fcf00db3ec87704fa5ddbc3319687cb4&chksm=f11805bfc66f8ca95d0ded31919a18c61501903ce9aede538b5157030feeb07a50b766a8f3f9&mpshare=1&scene=24&srcid=10172hwfQK6VtLphhAgZXwmR#rd)


## Android项目快速开发
* [tianzhijiexian/SelectorInjection](https://github.com/tianzhijiexian/SelectorInjection)

    >一个强大的selector注入器，它可以让view自动产生selector状态，免去了写selector文件的麻烦。
* [qyxxjd/MultipleStatusView](https://github.com/qyxxjd/MultipleStatusView) 

    >一个支持多种状态的自定义View,可以方便的切换到：加载中视图、错误视图、空数据视图、网络异常视图、内容视图。
* [czy1121/loadinglayout](https://github.com/czy1121/loadinglayout)

    >简单实用的页面多状态布局(content,loading,empty,error)
* [WangGanxin/LoadDataLayout](https://github.com/WangGanxin/LoadDataLayout)

    >App公共组件：加载数据Layout，高效开发必备！

## 开源框架学习
### Dagger2
*	[解锁Dagger2使用姿势（一）](http://blog.csdn.net/u012702547/article/details/52200927)
*	[解锁Dagger2使用姿势（二）之带你理解@Scope](http://blog.csdn.net/u012702547/article/details/52213706)
*	[Dagger2从入门到放弃再到恍然大悟](http://www.jianshu.com/p/39d1df6c877d)
*	[最简单的Dagger2入门教程](http://blog.csdn.net/lisdye2/article/details/51942511)
*	[依赖注入的原理](http://blog.csdn.net/lisdye2/article/details/51887402)

* [luxiaoming/dagger2Demo](https://github.com/luxiaoming/dagger2Demo)

  >有可能是最实战的dagger2教程，手把手教你使用。更多精彩，关注公众号:代码GG之家 欢迎

## Android常见问题
* Fragment懒加载和ViewPager的坑

  >参考资料：[http://www.cnblogs.com/dasusu/p/5926731.html](http://www.cnblogs.com/dasusu/p/5926731.html)
*  Activity嵌套多个fragment时，onResume的处理
	<font color=#FF1493>
	
	> 解决方法：</br>
	>不在fragmentA的onResume里写，而改成下面这样写，不可见时不操作，可见时再操作。</font></br>
>参考资料：[http://blog.csdn.net/binbin_1989/article/details/64437995](http://blog.csdn.net/binbin_1989/article/details/64437995)

	    @Override  
	    public void onHiddenChanged(boolean hidden) {  
	       super.onHiddenChanged(hidden);  
	     
	        if (hidden) {  
	            UtilsTools.Log_e(TAG, " --- 不可见()");  
	        } else {  
	            initData();  
	            UtilsTools.Log_e(TAG, " --- 当前可见()");  
	        }  
	}

*	Activity被回收后Fragment嵌套的Fragment不显示问题
	><font color=#FF1493>
	>解决方法：</br>
	>getFragmentManager()是所在fragment 父容器的碎片管理</br>
	>getChildFragmentManager()是在fragment 里面子容器的碎片管理</font></br>
    >参考资料：[http://blog.csdn.net/u012224845/article/details/50344199](http://blog.csdn.net/u012224845/article/details/50344199)

*   [Fragment返回栈的手动管理](https://blog.csdn.net/recordGrowth/article/details/83349653)

*	[Android资源文件夹下面values/style.xml、values-v19/style.xml、values-v21/style.xml主题调用规则](https://blog.csdn.net/amoscxy/article/details/77943127)

## Android开发细节问题
*	人民币符号适配(主要是￥中划线一横与两横的问题)

		char cny = (char)165;

*   关于数据库的操作，由于默认每次写操作(读操作可以不用)都会开启一个事务，大量数据的写操作需要用开启事务避免每次写操作都创建一个事务以提高app性能
	最常见的场景:for循环插入数据库execSQL,需要开启事务。
	伪代码:
	
	db.beginTransaction();  //手动设置开始事务
        try{
            //批量处理操作
            for(Collection c:colls){
                insert(db, c);
            }
            db.setTransactionSuccessful(); //设置事务处理成功，不设置会自动回滚不提交。
	    //在setTransactionSuccessful和endTransaction之间不进行任何数据库操作
           }catch(Exception e){
               MyLog.printStackTraceString(e);
           }finally{
               db.endTransaction(); //处理完成
           }

*  比较两个List集合中相同(不同)元素性能最高的方法
   参考文章:[获取两个List中的不同元素，4种方法，逐步优化，学习使用](https://www.cnblogs.com/arrrrrya/p/8119142.html)

*  Butterknife出现Bindview空指针异常主要有2个问题点需要排查：
    1.butterknife的gradle配置有问题;
    2.butterknife的binding过程是顶级布局往下一层一层绑定，一旦parent id绑定失败(一般是类型转换错误)，该父布局的子布局所有view都会绑定失败，error log通常只会提示子view的空指针异常，需要继续往上查找log查看父布局哪个view类型转换异常。

*   xshell执行远程虚拟机上的程序，需要xshell退出后远程虚拟机上的程序继续在后台执行
    1.nohup ./Demo.sh &

* [Activity切换动画实现，以及黑屏问题解决](https://www.jianshu.com/p/9b24929cf58e)

* Java调用kotlin扩展函数报参数错误解决方案(vararg)

    ```java
    //文件名为ViewKt.kt
    fun Activity.setOnClickListener(listener: View.OnClickListener, vararg ids: Int) {
        for (id in ids) {
            findViewById<View>(id).setOnClickListener(listener)
        }
    }
    
    ViewKt.setOnClickListener(
        this,
        new OnFastDoubleClickListener(this),
        R.id.album_btn,
        R.id.capture_btn);
    ```

    

## 权限问题

	 /**
	 * 检查权限是否被授予，此方法主要针对checkSelfPermission总是返回PERMISSION_GRANTED的问题
	 * @param permission
	 * @param context
	 * @return
	 */
	public static boolean selfPermissionGranted(String permission, Context context) {
		// For Android < Android M, self permissions are always granted.
		boolean result = true;
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
			if (getTargetSdkVersion(context) >= Build.VERSION_CODES.M) {
				// targetSdkVersion >= Android M, we can
				// use Context#checkSelfPermission
				result = context.checkSelfPermission(permission)
						== PackageManager.PERMISSION_GRANTED;
			} else {
				// targetSdkVersion < Android M, we have to use PermissionChecker
				result = PermissionChecker.checkSelfPermission(context, permission)
						== PermissionChecker.PERMISSION_GRANTED;
			}
		}
		return result;
	}
	
	public static int getTargetSdkVersion(Context context) {
		int targetSdkVersion = 0;
		try {
			final PackageInfo info = context.getPackageManager().getPackageInfo(
					context.getPackageName(), 0);
			targetSdkVersion = info.applicationInfo.targetSdkVersion;
		} catch (PackageManager.NameNotFoundException e) {
			e.printStackTrace();
		}
		return targetSdkVersion;
	}

## Paint画文字时文字居中显示
*  参考[paint.ascent()和paint.descent() 文字居中显示](https://blog.csdn.net/mori2014/article/details/77369782)

*  参考[用TextPaint来绘制文字](https://www.cnblogs.com/tianzhijiexian/p/4297664.html)

## git常用命令

	git push origin eas_local:eas_sync
	git checkout -b eas_local origin/eas_sync
	git pull
	git pull origin eas_sync:eas_local
	git pull origin master:dev
	git checkout -b dev//基于本地创建分支
	git checkout -b dev origin/dev //基于远程分支创建本地分支
	git clone https://git.oschina.net/telneter/iscs_calendar.git
	git checkout -b eas_local
	git pull origin eas_sync:eas_local
	git push origin eas_local:eas_sync

### git打tag
    git tag
    git tag -a v1.4 -m 'my version 1.4'
    git show v1.4
    参考：[Git 基础 - 打标签](https://git-scm.com/book/zh/v1/Git-%E5%9F%BA%E7%A1%80-%E6%89%93%E6%A0%87%E7%AD%BE)

### git同步远程已删除的分支和删除本地多余的分支
    [git同步远程已删除的分支和删除本地多余的分支](https://www.cnblogs.com/saysmy/p/9166331.html)
    git remote prune origin

### git上库指导
	1. git init
	2. git add .
	3. git commit -am "###"      -------以上3步只是本地提交
	4. git remote add origin git@xx.xx.xx.xx:repos/xxx/xxx/xxx.git
	5. git push origin 本地分支:远程分支

### git clone远程分支资源太大总是失败?
	1. git clone -b 远程分支名 远程库url --depth 1   //仅下载最新版本的代码
	[现象] git clone 一个大的项目时失败，错误类似fatal: The remote end hung up unexpectedly | fatal: early EOF | fatal: index-pack failed
	[原因]项目过大，受硬件限制（类似过载保护），clone过程中会中断
	[解决]   a、先做一个浅：git clone --depth 1 <repo_URI>；
		    b、将浅repo回复完全：git fetch --unshallow
		    c、then do regular pull ：git pull --all
注:参考连接:[git&gerrit 使用过程中遇到的问题及解决方法](http://blog.csdn.net/smithallenyu/article/details/50205817)

### git分支dev同步master分支代码

    分两步走:
       1.git checkout dev
       2. git merege origin/master
### git同步代码仓并保留提交记录
    cd existing_repo
    git remote rename origin old-origin
    git remote add origin http://172.16.90.180/netposa_whapp/vid.git
    git push -u origin --all
    git push -u origin --tag
git代码已push到服务器，如何进行回退

    a、在client 端撤消错误的提交：回到之前的一个提交
    git reset --hard HEAD^
    b、将新的提交 强制推到 git 服务器上：
    git push -f origin master

## github访问速度太慢解决方案

*	[加快访问GitHub的速度](https://blog.csdn.net/jiduochou963/article/details/87870710)
*	打开[码云](https://gitee.com/)，然后从github上导入进去，再下载速度贼快，大工程都这么下载

## adb命令
*   [ADB 清除Android手机缓存区域日志](https://blog.csdn.net/u013166958/article/details/79096221)
    adb logcat -c -b main -b events -b radio -b system
    adb logcat -c
    
*   [ADB logcat 过滤方法(抓取日志)](https://www.cnblogs.com/bydzhangxiaowei/p/8168598.html)
    adb logcat | grep -–color=auto $pid
    
*   [Android PC端用ADB抓取指定应用日志](https://blog.csdn.net/sun8532685/article/details/83861002)
    
    1. 查看所有应用pid
    
    >  adb shell ps
    
    2. 查看指定应用的pid
    
    >  adb shell "ps | grep com.antelope.app"
    >
   
*   在windows上不能使用grep关键字，而是应该用findstr
   
    如何只查看某个app日志的方法
   
    1. adb shell pm list packages -3 查看非系统第三方应用包名
      
    2. adb shell ps | findstr vchat.A  查看包名进程
      
    3. 根据进程来查看过滤app的日志
    
    ​        adb logcat | findstr vchat.A
    
    **注：CHCP 65001就设置成utf-8编码的了**
    
*   查看log并保存到本地
   
    1. adb logcat -c
    2. adb logcat |find "13696" > C:\Users\Admin\Desktop\aaaa.txt

## Gradle
* [Android Studio查看第三方库依赖树](https://www.jianshu.com/p/3b29f6890eac)
* [Android Studio版本与Gradle版本的对应关系](https://developer.android.google.cn/studio/releases/gradle-plugin)
* Gradle本地缓存文件过大，修改到D盘缓存的办法（不配置的话，Windows中默认是在C:\Users\<username>\.gradle），新建系统环境变量GRADLE_USER_HOME=D:\android\.gradle
* [AndroidX 版本 google版](https://developer.android.com/jetpack/androidx/versions)
* [AndroidX 版本 国内版](https://developer.android.google.cn//jetpack/androidx/versions)

### gradle和gradlew的区别
    gradlew命令会执行gradle-wrapper.properties中的gradle版本，gradle命令必须指定某个版本，而gradle会经常升级，所以最好用gradlew命令

### 发布开源库到Jcenter
- 多moduleAndroid库提交到Maven最佳实践

- [Android Studio将项目发布到Maven仓库（3种方式最新最全）](https://blog.csdn.net/xmxkf/article/details/80674232)

- [bintray-release使用指南（一）](https://www.jianshu.com/p/b4c46ee78b2f)

- [ttps://www.jianshu.com/p/d778f96a1e93](gradle 发布jar或者aar到maven私服时pom文件缺少依赖)

- https://docs.gradle.org/5.4.1/userguide/publishing_maven.html#publishing_maven

- [在 Docker 中用 Jenkins 搭建 Android 自动化打包](https://devbins.github.io/post/jenkins/)

#### 踩坑记录
- 开了ss后发现依然没法上传到`https://bintray.com/`,此时需要在`Project`的`gradle.properties`中添加以下proxy内容
    ```java
    systemProp.http.proxyHost=127.0.0.1
    systemProp.http.proxyPort=1080
    systemProp.https.proxyHost=127.0.0.1
    systemProp.https.proxyPort=1080
    ```

- 多Module Project需要单独发布某一个module时Gradle>`ModuleName`>Tasks>publishing>bintrayUpload即可单独发布某一个module

https://bintray.com/
username
yeguoqiang6
apikey
1809887721a2eee40615c2faf30e495136c6f8ed

## 源码学习
* [【Android源码解析】View.post()到底干了啥](https://www.cnblogs.com/dasusu/p/8047172.html)
  主要是分析HandlerActionQueue.post()方法以及view的原理

* [android面试题-okhttp内核剖析](https://www.jianshu.com/p/9ed2c2f2a52c)

## Flutter
* Flutter 第三方包 https://pub.flutter-io.cn/


## 工具的使用

### Charles抓https请求的爬坑路

第一步:[Android安装Charles证书（华为手机测试）](https://blog.csdn.net/weixin_42034554/article/details/86669159)

​	注意：可以使用电脑浏览器访问chls.pro/ssl，下载charles-proxy-ssl-proxying-certificate.pem文件然后adb push到sd卡

第二步:[Charles抓https显示unknown解决方法](https://www.jianshu.com/p/498884193013)

​	注意：Charles的SSL Proxying Settings，添加所有的域名这一步一定要有，否则就算信任了证书也全都是unknown

第三步:[如何解决 Android7.0之后部分手机无法抓包](https://blog.csdn.net/muranfei/article/details/89182997)
​	注意：关键代码

```
<network-security-config>
    <base-config cleartextTrafficPermitted="true">
        <trust-anchors>
            <certificates src="system" overridePins="true" />
            <certificates src="user" overridePins="true" />
        </trust-anchors>
    </base-config>
</network-security-config>
```

### [Windows下用Charles对Android抓包HTTPS](https://blog.csdn.net/ybdesire/article/details/80636248)
> Android 7.0以上抓取Https请求还需要添加网络安全配置`网络安全配置`,具体可以参考[网络安全配置](https://developer.android.com/training/articles/security-config.html)

 ```java
 <?xml version="1.0" encoding="utf-8"?>
 <manifest ... >
	 <application android:networkSecurityConfig="@xml/network_security_config"
					 ... >
		 ...
	 </application>
 </manifest>
 ```
 其中network_security_config.xml具体为以下内容
 ```java
 <?xml version="1.0" encoding="utf-8"?>
 <network-security-config>
	 <base-config>
		 <trust-anchors>
			 <certificates src="user" />
		 </trust-anchors>
	 </base-config>
 </network-security-config>
 ```
* [Android Studio 中超级常用的快捷键使用，提高代码编写效率](https://blog.csdn.net/Lone1yCode/article/details/79516856)

* [postman-变量/环境/过滤等](https://blog.csdn.net/zxz_tsgx/article/details/51681080)

* markdown神器 -Typora

* 抓包神器 -Charles、Fiddler

* 远程协助工具 -Teamviewer/向日葵

* API测试工具 -Postman

* 后台API展示-Swigger

* google浏览器插件-谷歌访问助手

## 科学上网
* PAC过滤规则

    ```yaml
    "github.com",
    "gist.github.com",
    "assets-cdn.github.com",
    "raw.githubusercontent.com",
    "gist.githubusercontent.com",
    "cloud.githubusercontent.com",
    "user-images.githubusercontent.com",
    "camo.githubusercontent.com",
    "avatars0.githubusercontent.com",
    "avatars1.githubusercontent.com",
    "avatars2.githubusercontent.com",
    "avatars3.githubusercontent.com",
    "avatars4.githubusercontent.com",
    "avatars5.githubusercontent.com",
    "avatars6.githubusercontent.com",
    "avatars7.githubusercontent.com",
    "avatars8.githubusercontent.com",
    "github-cloud.s3.amazonaws.com",
    "stackoverflow.com",
    "flutter.dev"
    ```

* [https://github.com/bannedbook/fanqiang](https://github.com/bannedbook/fanqiang)

* [【简单稳定】Vultr的购买和SS + v2ray-plugin +BBR的部署教程](https://www.aloneray.com/1279.html)

* [使用Vultr自带的Snapshots为VPS更换IP](https://www.aloneray.com/1143.html)

* [自建v2ray服务器教程]([https://github.com/Alvin9999/new-pac/wiki/%E8%87%AA%E5%BB%BAv2ray%E6%9C%8D%E5%8A%A1%E5%99%A8%E6%95%99%E7%A8%8B](https://github.com/Alvin9999/new-pac/wiki/自建v2ray服务器教程))

* https://ssr.tools/1026
    https://tlanyan.me/v2ray-clients-download/

    https://tlanyan.me/v2ray-tutorial/

    https://tlanyan.me/v2ray-clients-download/

* https://github.com/233boy/v2ray/wiki
  
    ```yaml
    bash <(curl -s -L https://git.io/v2ray.sh)
    v2ray info 查看 V2Ray 配置信息
    v2ray config 修改 V2Ray 配置
    v2ray link 生成 V2Ray 配置文件链接
    v2ray infolink 生成 V2Ray 配置信息链接
    v2ray qr 生成 V2Ray 配置二维码链接
    v2ray ss 修改 Shadowsocks 配置
    v2ray ssinfo 查看 Shadowsocks 配置信息
    v2ray ssqr 生成 Shadowsocks 配置二维码链接
    v2ray status 查看 V2Ray 运行状态
    v2ray start 启动 V2Ray
    v2ray stop 停止 V2Ray
    v2ray restart 重启 V2Ray
    v2ray log 查看 V2Ray 运行日志
    v2ray update 更新 V2Ray
    v2ray update.sh 更新 V2Ray 管理脚本
    v2ray uninstall 卸载 V2Ray
    
    # firewalld放行端口（适用于CentOS7/8）
    firewall-cmd --permanent --add-port=23581/tcp # 23581改成你配置文件中的端口号
    firewall-cmd --reload
    # ufw放行端口（适用于ubuntu）
    ufw allow 23581/tcp # 23581改成你的端口号
    # iptables 放行端口（适用于CentOS 6/7）
    iptables -I INPUT -p tcp --dport 23581 -j ACCEPT
    # 设置开机启动
    systemctl enable v2ray
    # 运行v2ray
    systemctl start v2ray
    ```
    
* [自建ss服务器教程](https://github.com/Alvin9999/new-pac/wiki/%E8%87%AA%E5%BB%BAss%E6%9C%8D%E5%8A%A1%E5%99%A8%E6%95%99%E7%A8%8B)

* [自建ss服务器教程](https://t1.free-air.org/%E8%87%AA%E5%BB%BAss%E6%9C%8D%E5%8A%A1%E5%99%A8%E6%95%99%E7%A8%8B/)

    > 脚本一：**CentOS 6和7/Debian6+/Ubuntu14+ ShadowsocksR一键部署管理脚本**
    >
    > ```
    > yum -y install wget
    > 
    > wget -N --no-check-certificate https://raw.githubusercontent.com/ToyoDAdoubi/doubi/master/ssr.sh && chmod +x ssr.sh && bash ssr.sh
    > ```
    >
    > 脚本二：**谷歌BBR加速**
    >
    > ```
    > yum -y install wget
    > 
    > wget --no-check-certificate https://github.com/teddysun/across/raw/master/bbr.sh
    > 
    > chmod +x bbr.sh
    > 
    > ./bbr.sh
    > ```
    > **查看加速bbr进程**
    >
    > + 输入命令lsmod | grep bbr 如果出现tcp_bbr字样表示bbr已安装并启动成功

* **电脑共享科学上网给手机，谷歌验证通过**

  1、ss客户端选项设置-本地代理-勾选“允许来自局域网的连接”

  2、手机连接此电脑共享的wifi
  
  3、连接好之后长按此wifi，勾选“显示高级选项”
  
  4、代理服务器选择“手动”
  
  5、代理主机名填写你自己电脑的ip地址，代理端口一般是1080
  
  6、连接上之后，电脑上务必关掉防火墙！我就因为没关防火墙浪费半天时间！
  
  7、如果你的电脑可以爬梯，那么手机应该也就没问题了。
  
  参考：http://www.samsungmembers.cn/thread-255981-29-15.html
  
* vps地址:https://www.vultr.com

