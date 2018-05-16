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

### 自定义View
*	[自定义View，有这一篇就够了](http://blog.csdn.net/huachao1001/article/details/51577291)

### View的事件体系
#### view的事件体系五部曲
*	[View的事件体系(一)View的基础知识](http://www.jianshu.com/p/531b366f56f2)
*	[View的事件体系(二)实现View滑动的三种方式](http://www.jianshu.com/p/0da16dbe427e)
*	[View的事件体系(三)View的弹性滑动](http://www.jianshu.com/p/6eca3fa1b0de)
*	[View的事件体系(四)View 的事件分发机制](http://www.jianshu.com/p/804eb1a5dd13)
*	[View的事件体系(五)View滑动冲突的解决方案](http://www.jianshu.com/p/bb6814073f5f)

### 事件分发机制
*	[一篇文章彻底搞懂Android事件分发机制](https://mp.weixin.qq.com/s?__biz=MzI0MjE3OTYwMg==&mid=2649550048&idx=1&sn=613c0cf5bcd2050e960c195537cdc562&chksm=f118079dc66f8e8b372d9afcfb691accf9edbc14251e59a7eb85982f5495835cc4354c48e232&mpshare=1&scene=24&srcid=1027NJY4DeGRYeayjT3EkYvB#rd)
	>![](http://mmbiz.qpic.cn/mmbiz_png/jE32KtUXy6HJWUt6gmArFJJLSwLBf7QV6OibwmHVAFjZJBmmoaz3xhtEZDZ8lX4cUwcXQT2Yk5B1GIQ63wKuicqg/640?wx_fmt=png&wxfrom=5&wx_lazy=1)

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
*	[如何将既有项目重构成 MVP 模式](https://mp.weixin.qq.com/s?__biz=MzI0MjE3OTYwMg==&mid=2649549997&idx=1&sn=774f53be2eeba53b8a0813dce1fcfcb8&chksm=f11807d0c66f8ec68dc014dd55fdbb93c755b9d11c2608ea19ae9f7f5dd10a50e1ac8f5e80d3&mpshare=1&scene=24&srcid=1027vXARAR6wV3DbwIpVTghR#rd)
*	[antoniolg/androidmvp](https://github.com/antoniolg/androidmvp)
	>MVP Android Example
*	[MindorksOpenSource/android-mvp-architecture](https://github.com/MindorksOpenSource/android-mvp-architecture)
	>This repository contains a detailed sample app that implements MVP architecture using Dagger2, GreenDao, RxJava2, FastAndroidNetworking and PlaceholderView https://mindorks.com/open-source-proj…
*	[android10/Android-CleanArchitecture](https://github.com/android10/Android-CleanArchitecture)
	>MVVM模式一个干净的设计框架
*	[Android架构合集](https://github.com/wwttt2004/Android-Architecture)
*	组件化之后组件间activity跳转，如果完全解耦需使用[**ActivityRouter**](https://github.com/mzule/ActivityRouter)以及阿里巴巴路由框架[**ARouter**](https://github.com/alibaba/ARouter)
*	[基于开源项目搭建 Android 技术堆栈](https://mp.weixin.qq.com/s?__biz=MzA3ODg4MDk0Ng==&mid=2651113557&idx=1&sn=8d1ef7cf5f65f9b53cf726c5de108c38&chksm=844c6188b33be89e487955f1da533402ab845aa2e27eda04afbb96436e77b8d88c259fd0ae33&mpshare=1&scene=24&srcid=10248D7nCMjrfL9tnZ2TQqgT#rd)
*	[[墙裂推荐]Android搭建属于自己的技术堆栈和App架构](https://mp.weixin.qq.com/s?__biz=MzI0MjE3OTYwMg==&mid=2649550530&idx=1&sn=fcf00db3ec87704fa5ddbc3319687cb4&chksm=f11805bfc66f8ca95d0ded31919a18c61501903ce9aede538b5157030feeb07a50b766a8f3f9&mpshare=1&scene=24&srcid=10172hwfQK6VtLphhAgZXwmR#rd)



## 开源框架学习
### Dagger2
*	[解锁Dagger2使用姿势（一）](http://blog.csdn.net/u012702547/article/details/52200927)
*	[解锁Dagger2使用姿势（二）之带你理解@Scope](http://blog.csdn.net/u012702547/article/details/52213706)
*	[Dagger2从入门到放弃再到恍然大悟](http://www.jianshu.com/p/39d1df6c877d)
*	[最简单的Dagger2入门教程](http://blog.csdn.net/lisdye2/article/details/51942511)
*	[依赖注入的原理](http://blog.csdn.net/lisdye2/article/details/51887402)

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

### git clone远程分支资源太大总是失败?
	1. git clone -b 远程分支名 远程库url --depth 1   //仅下载最新版本的代码
	[现象] git clone 一个大的项目时失败，错误类似fatal: The remote end hung up unexpectedly | fatal: early EOF | fatal: index-pack failed
	[原因]项目过大，受硬件限制（类似过载保护），clone过程中会中断
	[解决]      a、先做一个浅：git clone --depth 1 <repo_URI>；
		    b、将浅repo回复完全：git fetch --unshallow
		    c、then do regular pull ：git pull --all
注:参考连接:[git&gerrit 使用过程中遇到的问题及解决方法](http://blog.csdn.net/smithallenyu/article/details/50205817) 
