## Java基础
*	[为什么String要设计成不可变的](http://blog.csdn.net/renfufei/article/details/16808775)
*	请写出代码计算二叉树的最大深度，分别用『递归』和『非递归』的方式实现
*	[如何检查内存泄漏，并解决](http://www.jianshu.com/p/bf159a9c391a)



## Android基础知识
*	[GcsSloop/AndroidNote](https://github.com/GcsSloop/AndroidNote/tree/master)
	>安卓学习笔记
*	[tangqi92/Android-Tips](https://github.com/tangqi92/Android-Tips)
	>An awesome list of tips for android. http://itangqi.me/2015/09/14/android-…

### View
*	[三个案例带你看懂LayoutInflater中inflate方法两个参数和三个参数的区别](http://blog.csdn.net/u012702547/article/details/52628453)
*	[Android LayoutInflater原理分析，带你一步步深入了解View(一)](http://blog.csdn.net/guolin_blog/article/details/12921889)

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

## Android项目重构
*	[antoniolg/androidmvp](https://github.com/antoniolg/androidmvp)
	>MVP Android Example
*	[MindorksOpenSource/android-mvp-architecture](https://github.com/MindorksOpenSource/android-mvp-architecture)
	>This repository contains a detailed sample app that implements MVP architecture using Dagger2, GreenDao, RxJava2, FastAndroidNetworking and PlaceholderView https://mindorks.com/open-source-proj…
*	[android10/Android-CleanArchitecture](https://github.com/android10/Android-CleanArchitecture)
	>MVVM模式一个干净的设计框架
*	[Android架构合集](https://github.com/wwttt2004/Android-Architecture)
*	组件化之后组件间activity跳转，如果完全解耦需使用[**ActivityRouter**](https://github.com/mzule/ActivityRouter)以及阿里巴巴路由框架[**ARouter**](https://github.com/alibaba/ARouter)
*	[微信Android客户端后台保活经验分享](https://mp.weixin.qq.com/s?__biz=MjM5MDE0Mjc4MA==&mid=403445713&idx=3&sn=3a554cd59ada688ad7e0a3bd67c84d0d&scene=0#rd)




## Android常见问题
*  Fragment懒加载和ViewPager的坑
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




## Android开发细节问题
*	人民币符号适配(主要是￥中划线一横与两横的问题)

		char cny = (char)165;

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
### git上库指导
	1. git init
	2. git add .
	3. git commit -am "###"      -------以上3步只是本地提交
	4. git remote add origin git@xx.xx.xx.xx:repos/xxx/xxx/xxx.git
	5. git push origin 本地分支:远程分支
