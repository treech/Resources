**更新时间：2022/10/07**

# Android

## 1.Activity

### 1.1.Activity启动流程

https://juejin.cn/post/6844903959581163528#heading-1

https://www.jianshu.com/p/b3a1ea7923e7

https://www.mianshifaq.com/archives/android%E5%90%AF%E5%8A%A8%E6%B5%81%E7%A8%8B%EF%BC%88activity%E7%9A%84%E5%86%B7%E5%90%AF%E5%8A%A8%E6%B5%81%E7%A8%8B%EF%BC%89/

Activity的启动流程图（放大可查看）如下所示：

![activity_start_flow](https://raw.githubusercontent.com/treech/PicRemote/master/common/activity_start_flow.png)

![yingyongqidong1](https://raw.githubusercontent.com/treech/PicRemote/master/common/yingyongqidong1.png)

简述（基于Android 12）：
1、Activity#startActivity->Activity#startActivityForResult->Instrumentation#**execStartActivity**开始进行跨进程通信

2、9.0之前直接通过Binder跨进程执到AMS的startActivity，9.0之后改成ATMS（ActivityTaskManagerService）startActivity，其中AMS和ATMS都是通过ServiceManager拿到的，ATMS是从AMS里拆分出来的，且AMS控制着ATMS->ActivityTaskManagerService#startActivityAsUser->接着在ActivityStarter里面判断activity所在的进程是否已经启动（如果已经启动了，执行的是ActivityTaskSupervisor#**realStartActivityLocked**），如果没有启动，执行的是ATMS#startProcessAsync->最终执行AMS->**Process#start**，发送Socket请求给Zygote进程fork出来新进程（启动的是app进程）

3、APP进程创建完毕后再通过反射调用ActivityThread#**main**()初始化主线程Handler->mgr.**attachApplication**(mAppThread, startSeq)，把ApplicationThread绑定到AMS->AMS拿到App进程的控制权后再操纵APP进程->ActivityThread#handleBindApplication进行application的创建

4、ActivityThread利用ClassLoader去加载Activity,并回调其生命周期方法。

细节：ActivityThread.handleLaunchActivity->onCreate ->完成DecorView和Activity的创建->handleResumeActivity->onResume()->DecorView添加到WindowManager->ViewRootImpl.performTraversals()。（**ApplicationThread是ActivityThread的内部类，作为AMS的代理**）

**ActivityThread.java**

```
public static void main(String[] args) {
    Trace.traceBegin(Trace.TRACE_TAG_ACTIVITY_MANAGER, "ActivityThreadMain");
    ...
    Looper.prepareMainLooper();
    
    ActivityThread thread = new ActivityThread();
    thread.attach(false, startSeq);

    if (sMainThreadHandler == null) {
        sMainThreadHandler = thread.getHandler();
    }

    // End of event ActivityThreadMain.
    Trace.traceEnd(Trace.TRACE_TAG_ACTIVITY_MANAGER);
    Looper.loop();

    throw new RuntimeException("Main thread loop unexpectedly exited");
}
```
**ActivityTaskSupervisor.java**

```
    void startSpecificActivity(ActivityRecord r, boolean andResume, boolean checkConfig) {
        // Is this activity's application already running?
        final WindowProcessController wpc =
                mService.getProcessController(r.processName, r.info.applicationInfo.uid);
        if (wpc != null && wpc.hasThread()) {
            try {
                realStartActivityLocked(r, wpc, andResume, checkConfig);
                return;
            } catch (RemoteException e) {
                Slog.w(TAG, "Exception when starting activity "
                        + r.intent.getComponent().flattenToShortString(), e);
            }
        }

        final boolean isTop = andResume && r.isTopRunningActivity();
        mService.startProcessAsync(r, knownToBeDead, isTop, isTop ? "top-activity" : "activity");
    }
```

**面试1：我们知道Android中所有的进程都是直接通过zygote进程fork出来的（fork可以理解为孵化出来的当前进程的一个副本），为什么所有进程都必须用`zygote`进程fork呢？**（https://cloud.tencent.com/developer/article/1803177）

- 这是因为`fork`的行为是复制整个用户的空间数据以及所有的系统对象，并且只复制当前所在的线程到新的进程中。也就是说，父进程中的`其他线程`在子进程中都消失了，为了防止出现各种问题（比如死锁，状态不一致）呢，就只让`zygote`进程，这个单线程的进程，来fork新进程。
- 而且在`zygote`进程中会做好一些初始化工作，比如启动虚拟机，加载系统资源。这样子进程fork的时候也就能直接共享，提高效率，这也是这种机制的优点。

**面试2：AMS通知Zygote进程为什么不是用Binder而是用Socket？**（https://www.zhihu.com/question/312480380）

首先，Binder通信需要使用Binder线程池。

然后，Zygote 在fork进程之前，会把多余的线程（包括Binder线程）都杀掉只保留一个线程。所以此时就无法把结果通过Binder把消息发送给system_server。fork()进程完成之后Zygote也会把其他线程重新启动，这时候即使有了Binder线程，也无法重新建立连接。

由于fork进程（Zygote）出来的进程A只有一个线程，如果Zygote有多个线程，那么A会丢失其他线程。这时可能造成死锁。

### 1.2.onSaveInstanceState(),onRestoreInstanceState的调用时机 

onSaveInstanceState()主要是屏幕发生旋转的时候调用。

onRestoreInstanceState(Bundle savedInstanceState)只有在activity确实是被系统回收，重新创建activity的情况下才会被调用。

#### 1.2.1.源码

系统会调用ActivityThread的performStopActivity方法中调用onSaveInstanceState， 将状态保存在mActivities中，
mActivities维护了一个Activity的信息表，当Activity重启时候，会从mActivities中查询到对应的
ActivityClientRecord。
如果有信息，则调用Activity的onResoreInstanceState方法，
在ActivityThread的performLaunchActivity方法中，统会判断ActivityClientRecord对象的state是否为空，不为空则通过Activity的onSaveInstanceState获取其UI状态信息，通过这些信息传递给Activity的onCreate方法。

### 1.3.Activity启动模式和使用场景

#### 1.3.1.启动模式
1. standard：标准模式：如果在mainfest中不设置就默认standard；standard就是新建一个Activity就在栈中新建一个activity实例；

2. singleTop：栈顶复用模式：与standard相比栈顶复用可以有效减少activity重复创建对资源的消耗，但是这要根据具体情况而定，不能一概而论；

3. singleTask：栈内单例模式，栈内只有一个activity实例，栈内已存activity实例，在其他activity中start这个activity，Android直接把这个实例上面其他activity实例踢出栈GC掉；

4. singleInstance :堆内单例，整个手机操作系统里面只有一个实例存在就是内存单例（**系统会单独给该Activity创建一个栈**）；

> 在singleTop、singleTask、singleInstance 中如果在应用内存在Activity实例，并且再次发生startActivity(Intent intent)回到Activity后,由于并不是重新创建Activity而是复用栈中的实例，因此Activity再获取焦点后并没调用onCreate、onStart，而是直接调用了onNewIntent(Intent intent)函数；

#### 1.3.2.使用场景
| LauchMode      | Instance                                                     |
| -------------- | ------------------------------------------------------------ |
| standard       | 邮件、mainfest中没有配置就默认标准模式                       |
| singleTop      | 登录页面、WXPayEntryActivity、WXEntryActivity 、推送通知栏   |
| singleTask     | 程序模块逻辑入口:主页面（Fragment的containerActivity）、WebView页面、扫一扫页面、电商中：购物界面，确认订单界面，付款界面 |
| singleInstance | 系统Launcher、锁屏键、来电显示等系统应用                     |

**测试SingleTop**

```
测试activity页面打开流程：main->standard->singleTop->standard->singleTop
总结：activity不在栈顶，会重新创建实例
```

![image-20220822114034563](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20220822114034563.png)

```
测试activity页面打开流程：main->standard->singleTop->singleTop
总结：activity在栈顶，会复用实例，并调用onNewIntent()
```

![image-20220822114457978](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20220822114457978.png)

### 1.4.Activity A跳转Activity B，再按返回键，生命周期执行的顺序

在A跳转B会执行：A onPause -> B onCreate -> B onStart -> B onResume->A onStop
在B按下返回键会执行：B onPause -> A onRestart -> A onStart -> A onResume-> B onStop -> B onDestroy
当A跳转到B的时候，A先执行onPause，然后居然是B再执行onCreate -> onStart -> onResume，最后才执行A的onStop!!!
当B按下返回键，B先执行onPause，然后居然是A再执行onRestart -> onStart -> onResume，最后才是B执行onStop -> onDestroy!!!
当 B Activity 的 launchMode 为 singleInstance，singleTask 且对应的 B Activity 有可复用的实例时，生命周期回调是这样的:
A.onPause -> B.onNewIntent -> B.onRestart -> B.onStart -> B.onResume -> A.onStop -> ( 如果 A 被移出栈的话还有一个 A.onDestory)
当 B Activity 的 launchMode 为 singleTop且 B Activity 已经在栈顶时（一些特殊情况如通知栏点击、连点），此时只有 B 页面自己有生命周期变化:B.onPause -> B.onNewIntent -> B.onResume

### 1.5.横竖屏切换,按home键,按返回键,锁屏与解锁屏幕,跳转透明Activity界面,启动一个 Theme 为 Dialog 的 Activity，弹出Dialog时Activity的生命周期
横竖屏切换：
从 Android 3.2 (API级别 13)开始
https://www.jianshu.com/p/dbc7e81aead2
1、不设置Activity的androidconfigChanges，或设置Activity的androidconfigChanges="orientation"，或设置Activity的android:configChanges="orientation|keyboardHidden"，切屏会重新调用各个生命周期，切横屏时会执行一次，切竖屏时会执行一次。
2、配置 android:configChanges="orientation|keyboardHidden|screenSize"，才不会销毁 activity，且只调用onConfigurationChanged方法。
竖屏：
启动：onCreat->onStart->onResume.
切换横屏时：
onPause-> onSaveInstanceState ->onStop->onDestory
onCreat->onStart->onSaveInstanceState->onResume.
如果配置这个属性:androidconfigChanges="orientation|keyboardHidden|screenSize"
就不会在调用Activity的生命周期，只会调用onConfigurationChanged方法
**HOME**键的执行顺序：onPause->onStop->onRestart->onStart->onResume
**BACK**键的顺序： onPause->onStop->onDestroy->onCreate->onStart->onResume
锁屏：锁屏时只会调用onPause()，而不会调用onStop方法，开屏后则调用onResume()。

弹出 Dialog： 直接是通过 WindowManager.addView 显示的（没有经过 AMS），所以不会对生命周期有任何影响。
启动theme为DialogActivity,跳转透明Activity
A.onPause -> B.onCrete -> B.onStart -> B.onResume
（ Activity 不会回调 onStop，因为只有在 Activity 切到后台不可见才会回调 onStop）

### 1.6.onStart 和 onResume、onPause 和 onStop 的区别

onStart 和 onResume 从 Activity 可见可交互区分
onStart 用户可以看到部分activity但不能与它交互 onResume()可以获得activity的焦点，能够与用户交互
onStop 和 onPause 从 Activity 是否位于前台，是否有焦点区分
onPause表示当前页面失去焦点。
onStop表示当前页面不可见。
dialog的主题页面，这个时候，打开着一个页面，就只会执行onPause，而不会执行onStop。

### 1.7.Activity之间传递数据的方式Intent是否有大小限制，如果传递的数据量偏大，有哪些方案

startActivity->startActivityForResult->Instrumentation.execStartActivity
->ActivityManger.getService().startActivity
intent中携带的数据要从APP进程传输到AMS进程，再由AMS进程传输到目标Activity所在进程
通过Binder来实现进程间通信
1.Binder 驱动在内核空间创建一个数据接收缓存区。
2.在内核空间开辟一块内核缓存区，建立内核缓存区和内核空间的数据接收缓存区之间的映射关系，以及内核中数据接收缓存区和接收进程用户空间地址的映射关系。
3.发送方进程通过系统调用 copyfromuser() 将数据 copy 到内核空间的内核缓存区，由于内核缓存区和接收进程的用
户空间存在内存映射，因此也就相当于把数据发送到了接收进程的用户空间，这样便完成了一次进程间的通信。
为当使用Intent来传递数据时，用到了Binder机制，数据就存放在了Binder的事务缓冲区里面，而事务缓冲区是有大
小限制的。普通的由Zygote孵化而来的用户进程，映射的Binder内存大小是不到1M的
Binder 本身就是为了进程间频繁-灵活的通信所设计的, 并不是为了拷贝大量数据
**如果非 ipc**
单例,eventBus,Application,sqlite、shared preference、file 都可以;
**如果是 ipc**
1.共享内存性能还不错， 通过 MemoryFile 开辟内存空间，获得 FileDescriptor； 将 FileDescriptor 传递给其他进
程； 往共享内存写入数据； 从共享内存读取数据。(https://www.jianshu.com/p/4a4bc36000fc)
2.Socket或者管道性能不太好，涉及到至少两次拷贝。

### 1.8.Activity的onNewIntent()方法什么时候执行

如果IntentActivity处于任务栈的顶端，也就是说之前打开过的Activity，现在处于onPause、onStop 状态，其他应用再发送Intent的话，执行顺序为：onNewIntent，onRestart，onStart，onResume。
ActivityA已经启动过,处于当前应用的Activity堆栈中;
当ActivityA的LaunchMode为SingleTop时，如果ActivityA在栈顶，且现在要再启动ActivityA，这时会调用onNewIntent()方法；
当ActivityA的LaunchMode为SingleInstance、SingleTask时，如果已经ActivityA已经在堆栈中，那么此时再次启动会调用onNewIntent()方法；

### 1.9.显示启动和隐式启动

#### 1.9.1.显示启动
1、构造方法传入Component，最常用的方式
2、setComponent(componentName)方法
3、setClass/setClassName方法
#### 1.9.2.隐式启动
https://www.jianshu.com/p/12c6253f1851
隐式Intent是通过在AndroidManifest文件中设置action、data、category，让系统来筛选出合适的Activity
**action**的匹配规则
Intent-filter action可以设置多条
intent中的action只要与intent-filter其中的一条匹配成功即可，且intent中action最多只有一条
Intent-filter内必须至少包含一个action。
**category**的匹配规则
Intent-filter内必须至少包含一个category，android:name为android.intent.category.DEFAULT。
intent-filter中，category可以有多条
intent中，category也可以有多条
intent中所有的category都可以在intent-filter中找到一样的（包括大小写）才算匹配成功
**data**的匹配规则
intent-filter中可以设置多个data
intent中只能设置一个data
intent-filter中指定了data，intent中就要指定其中的一个data

### 1.10.scheme使用场景,协议格式,如何使用

scheme是一种页面内跳转协议，是一种非常好的实现机制，通过定义自己的scheme协议，可以非常方便跳转app中
的各个页面

1. APP根据URL跳转到另外一个APP指定页面
2. 可以通过h5页面跳转app原生页面
3. 服务器可以定制化跳转app页面

Scheme链接格式样式
>样式scheme://host/path?query
>Uri.parse("hr://test:8080/goods?goodsId=8897&name=test")
>hr代表Scheme协议名称
>test代表Scheme作用的地址域
>8080代表改路径的端口号
>/goods代表的是指定页面(路径)
>goodsId和name代表传递的两个参数

使用

```xml
<intent-filter>
    <!-- 协议部分配置 ,注意需要跟web配置相同-->
    <!--协议部分，随便设置 hr://test:8080/goods?name=test -->
    <data android:scheme="hr"
    android:host="test"
    android:path="/goods"
    android:port="8080"/>
    <!--下面这几行也必须得设置-->
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <action android:name="android.intent.action.VIEW" />
</intent-filter>
```

调用

```java
Intent intent = new Intent(Intent.ACTION_VIEW,Uri.parse("hr://test:8080/goods?name=test"));
startActivity(intent);
```

### 1.11.ANR 的四种场景

1. Service TimeOut: service 未在规定时间执行完成：前台服务 20s，后台 200s
2. BroadCastQueue TimeOut: 未在规定时间内未处理完广播：前台广播 10s 内, 后台 60s 内
3. ContentProvider TimeOut: publish 在 10s 内没有完成
4. Input Dispatching timeout: 5s 内未响应键盘输入、触摸屏幕等事件

我们可以看到， Activity 的生命周期回调的阻塞并不在触发 ANR 的场景里面，所以并不会直接触发 ANR。只不过死循环阻塞了主线程，如果系统在有上述的四种事件发生，就无法在相应的时间内处理从而触发 ANR。

### 1.12.onCreate和onRestoreInstance方法中恢复数据时的区别

onSaveInstanceState 不一定会被调用，因为它只有在上次activity被回收了才会调用。
onCreate()里的Bundle参数可能为空，一定要做非空判断。 而onRestoreInstanceState的Bundle参数一定不会是空
值。

### 1.13.activty间传递数据的方式

1. 通过 Intent 传递（Intent.putExtra 的内部也是维护的一个 Bundle，因此，通过 putExtra 放入的 数据，取出时也可
2. 以通过 Bundle 去取）
3. 通过全局变量传递
4. 通过 SharedPreferences 传递
5. 通过数据库传递
6. 通过文件传递

### 1.14.跨App启动Activity的方式,注意事项

https://www.jianshu.com/p/ad01ac11b4f1
https://juejin.im/post/6844904056461197326#heading-0
使用intentFilter(隐式跳转)
在Manifest的Activity标签中添加：
启动时：startActivity(new Intent("com.example.test.action.BActivity"))
如果有两个action属性值相同的Activity，那么在启动时手机系统会让你选择启动哪一个Activity
要解决这个问题，需要给被启动的Activity再加上一个属性，
然后再启动该Activity的Intent中加上一个URI，其中“app”必须与data属性的scheme的值一样，
intent=new Intent("com.zs.appb.intent.action.BeStartActivity", Uri.parse("app://hello"));

**共享uid的App**
android中uid用于标识一个应用程序，uid在应用安装时被分配，并且在应用存在于手机上期间，都不会改变。一个
应用程序只能有一个uid，多个应用可以使用sharedUserId 方式共享同一个uid，前提是这些应用的签名要相同。
在AndroidManifest中：manifest标签中添加android:sharedUserId="xxxx"
启动时：startActivity(new Intent().setComponent(new
ComponentName("com.example.test","com.example.test.XxxActivity")));
**使用exported**
一旦设置了intentFilter之后，exported就默认被设置为true了
在Manifest中添加exported属性 
启动时：startActivity(new Intent().setComponent(new
ComponentName("com.example.zhu","com.example.zhu.XxxActivity")));
**注意(如何防止自己的Activity被外部非正常启动):**
如果AppB设置了android:permission=”xxx.xxx.xx”那么， 就必须在你的AppA的AndroidManifast.xml中usespermission xxx.xxx.xx才能访问人家的东西。
给AppA的manifest中添加权限：
给AppB中需要启动的Activity添加permission属性：
android:permission="com.example.test"

### 1.15.Activity任务栈是什么

1. android任务栈又称为Task，它是一个栈结构，具有后进先出的特性（**压栈和出栈**），用于存放我们的Activity组件。

2. 我们每次打开一个新的Activity或者退出当前Activity都会在一个称为任务栈的结构中添加或者减少一个Activity组
   件， 一个任务栈包含了一个activity的集合, 只有在任务栈栈顶的activity才可以跟用户进行交互。

3. 在我们退出应用程序时，必须把所有的任务栈中所有的activity清除出栈时,任务栈才会被销毁。当然任务栈也可以
   移动到后台, 并且保留了每一个activity的状态. 可以有序的给用户列出它们的任务, 同时也不会丢失Activity的状态信
   息。

4. 对应AMS中的ActivityRecord、TaskRecord、ActivityStack(AMS中的总结)  

### 1.16.有哪些Activity常用的标记位Flags

FLAG_ACTIVITY_NEW_TASK
此标记位作用是为Activity指定“singleTask”启动模式，其效果和在XML中指定相同
android:launchMode="singleTask"
FLAG_ACTIVITY_SINGLE_TOP
此标记位作用是为Activity指定“singleTop”启动模式，其效果和在XML中指定相同android:launchMode="singleTop"
FLAG_ACTIVITY_CLEAR_TOP
具有此标记位的Activity，当它启动时，在同一个任务栈中位于它上面的Activity都要出栈。此标记位一般会和
singleTask启动模式一起出现，此情况下，若被启动的Activity实例存在，则系统会调用它的onNewIntent。

### 1.17.Activity的数据是怎么保存的,进程被Kill后,保存的数据怎么恢复的

https://www.wanandroid.com/wenda/show/12574
在Activity的onSaveInstanceState方法回调时，put到参数outState（Bundle）里面。outState就是
ActivityClientRecord的state。
ActivityClientRecord实例，都存放在ActivityThread的mActivities里面。
Activity变得不可见时（onSaveInstanceState和onStop回调之后），在应用进程这边会通过
ActivityTaskManagerService的activityStopped方法，把刚刚在onSaveInstanceState中满载了数据的Bundle对象，
传到系统服务进程那边！ 然后（在系统服务进程这边），会进一步将这个Bundle对象，赋值到对应ActivityRecord的icicle上ActivityRecord是用来记录对应Activity的各种信息的，如theme，启动模式、当前是否可见等等（为了排版更简洁，上图只列出来一个icicle），它里面还有很多管理Activity状态的相关方法；
TaskRecord就是大家耳熟能详的任务栈（从上图可以看出并不真的是栈）了，它的主要职责就是管理ActivityRecord。每当Activity启动时，会先找到合适的TaskRecord（或创建新实例），然后将该Activity所对应的ActivityRecord添加到TaskRecord的mActivities中；
ActivityStack管理着TaskRecord，当新TaskRecord被创建后，会被添加到它mTaskHistory里面。

## 2.Service

### 2.1.service 的生命周期，两种启动方式的区别

**startService**
onCreate() -> onStartCommand() -> onDestroy()
**bindService**
onCreate() -> onbind() -> onUnbind()-> onDestroy()

区别

**启动**
如果服务已经开启，多次执行startService不会重复的执行onCreate()， 而是会调用onStart()和onStartCommand()。
如果服务已经开启，多次执行bindService时,onCreate和onBind方法并不会被多次调用
**销毁**
当执行stopService时，直接调用onDestroy方法
调用者调用unbindService方法或者调用者Context不存在了（如Activity被finish了），Service就会调用onUnbind->onDestroy
使用startService()方法启用服务，调用者与服务之间没有关连，即使调用者退出了，服务仍然运行。
使用bindService()方法启用服务，调用者与服务绑定在了一起，调用者一旦退出，服务也就终止。
1、单独使用startService & stopService
（1）第一次调用startService会执行onCreate、onStartCommand。
（2）之后再多次调用startService只执行onStartCommand，不再执行onCreate。
（3）调用stopService会执行onDestroy。
2、单独使用bindService & unbindService
（1）第一次调用bindService会执行onCreate、onBind。
（2）之后再多次调用bindService不会再执行onCreate和onBind。
（3）调用unbindService会执行onUnbind、onDestroy。

### 2.2.Service启动流程

http://gityuan.com/2016/03/06/start-service/

![start_service_process](http://gityuan.com/images/android-service/start_service/start_service_processes.jpg)

1.Process A进程采用Binder IPC向system_server进程发起startService请求；
2.system_server进程接收到请求后，向zygote进程发送创建进程的请求；
3.zygote进程fork出新的子进程Remote Service进程；
4.Remote Service进程，通过Binder IPC向sytem_server进程发起attachApplication请求；
5.system_server进程在收到请求后，进行一系列准备工作后，再通过binder IPC向remote Service进程发送scheduleCreateService请求；
6.Remote Service进程的binder线程在收到请求后，通过handler向主线程发送CREATE_SERVICE消息；
7.主线程在收到Message后，通过发射机制创建目标Service，并回调Service.onCreate()方法。
到此，服务便正式启动完成。当创建的是本地服务或者服务所属进程已创建时，则无需经过上述步骤2、3，直接创建服务即可。

**bindService**与**startService**见上面的链接

### 2.3.Service与Activity怎么实现通信

**通过Binder对象**
方式一：
1.Service中添加一个继承Binder的内部类，并添加相应的逻辑方法
2.Service中重写Service的onBind方法，返回我们刚刚定义的那个内部类实例
3.Activity中绑定服务,重写ServiceConnection，onServiceConnected时返回的IBinder（Service中的binder）调用逻辑方法

方式二：
Service通过BroadCast广播与Activity通信

### 2.4.IntentService是什么,IntentService原理，应用场景及其与Service的区别

what
IntentService 是 Service 的子类，默认开启了一个工作线程HandlerThread，使用这个工作线程逐一处理所有启动请求，在任务执行完毕后会自动停止服务。只要实现一个方法 onHandleIntent，该方法会接收每个启动请求的Intent，能够执行后台工作和耗时操作。
可以启动 IntentService 多次，而每一个耗时操作会以队列的方式在 IntentService 的 onHandlerIntent 回调方法中执行，并且，每一次只会执行一个工作线程，执行完第一个再执行第二个。并且等待所有消息都执行完后才终止服务。

how
1.创建一个名叫 ServiceHandler 的内部 Handler
2.把内部Handler与HandlerThread所对应的子线程进行绑定
3.HandlerThread开启线程 创建自己的looper
4.通过 onStartCommand() intent，依次插入到工作队列中，并发送给 onHandleIntent()逐个处理

**可以用作后台下载任务 静默上传**
why 
IntentService会创建独立的worker线程来处理所有的Intent请求 Service主线程不能处理耗时操
作,IntentService不会阻塞UI线程，而普通Serveice会导致ANR异常。
为Service的onBind()提供默认实现，返回null；onStartCommand提供默认实现，将请求Intent添加到队列中。
所有请求处理完成后，IntentService会自动停止，无需调用stopSelf()方法停止Service。

使用示例：

```kotlin
class LocalIntentService @JvmOverloads constructor(name: String? = null) : IntentService(name) {

    override fun onHandleIntent(intent: Intent?) {
        val action = intent!!.getStringExtra("task_action")
        val isMainThread = Thread.currentThread() === Looper.getMainLooper().thread
        Log.d(TAG, "receive task :$action, is main thread:$isMainThread")
        Thread.sleep(3000) //即使第一个任务休眠，后续的任务也会等待其执行完毕
        Log.i(TAG, "handle task :$action")
    }

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "onCreate")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return super.onStartCommand(intent, flags, startId)
        Log.i(TAG, "onStartCommand")
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.i(TAG, "onDestroy")
    }

    companion object {
        private const val TAG = "LocalIntentService"
    }
}
```

```kotlin
val service = Intent(this, LocalIntentService::class.java)
service.putExtra("task_action", "com.example.action.TASK1")
startService(service)

service.putExtra("task_action", "com.example.action.TASK2")
startService(service)

service.putExtra("task_action", "com.example.action.TASK3")
startService(service)
```
运行结果
![image-20220823100453130](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20220823100453130.png)

API 26以上推荐使用`JobIntentService`

![image-20220822211659062](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20220822211659062.png)

![image-20220823083406327](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20220823083406327.png)

可以看到也不推荐用`JobIntentService`，而是直接使用`WorkManager`

[从Service到WorkManager](https://juejin.cn/post/6844903609461653518)

PS：WorkManager可以做很多事情: 取消任务, 组合任务, 构建任务链, 将一个任务的参数合并到另一个任务。

### 2.5.Service 的 onStartCommand 方法有几种返回值?各代表什么意思? 

**START_NOT_STICKY**
在执行完 onStartCommand 后,服务被异常kill掉,系统不会自动重启该服务。
**START_STICKY**
重传 Intent。使用这个返回值时,如果在执行完 onStartCommand 后,服务被异常kill掉,系统会自动重启该服务 ，并且onStartCommand方法会执行,onStartCommand方法中的intent值为null。
适用于媒体播放器或类似服务。
**START_REDELIVER_INTENT** 
使用这个返回值时,服务被异 常kill掉,系统会自动重启该服务,并将 Intent 的值传入。
适用于主动执行应该立即恢复的作业（例如下载文件）的服务。

### 2.6.bindService和startService混合使用的生命周期以及怎么关闭?

如果你只是想要启动一个后台服务长期进行某项任务，那么使用startService便可以了。如果你还想要与正在运行的
Service取得联系，那么有两种方法：一种是使用broadcast，另一种是使用bindService。
https://blog.csdn.net/u014520745/article/details/49669641
如果先startService，再bindService
onCreate() -> onbind() -> onStartCommand()
如果先bindService，再startService
onCreate() -> onStartCommand() -> onbind()
如果只stopService
Service的OnDestroy()方法不会立即执行,在Activity退出的时候，会执行OnDestroy。
如果只unbindService
只有onUnbind方法会执行，onDestory不会执行
如果要完全退出Service，那么就得执行unbindService()以及stopService。

## 3.BroadCastReceiver

#### 3.1.广播的分类和使用场景

Android 广播分为两个角色：广播发送者、广播接受者
广播接收器的注册分为两种：静态注册、动态注册。
静态广播接收者：通过AndroidManifest.xml的标签来申明的BroadcastReceiver。
动态广播接收者：通过AMS.registerReceiver()方式注册的BroadcastReceiver，动态注册更为灵活，可在不需要时通
过unregisterReceiver()取消注册。
广播类型：根据广播的发送方式，

1. **普通广播**：通过Context.sendBroadcast()发送，可并行处理
2. **系统广播**：当使用系统广播时，只需在注册广播接收者时定义相关的action即可，不需要手动发送广播(网络变化,
   锁屏,飞行模式)
3. **有序广播**： 指的是发送出去的广播被 BroadcastReceiver 按照先后顺序进行接收 发送方式变为：
   sendOrderedBroadcast(intent);
   广播接受者接收广播的顺序规则（同时面向静态和动态注册的广播接受者）：按照 Priority 属性值从大-小排序，
   Priority属性相同者，动态注册的广播优先。
4. **App应用内广播**（Local Broadcast）
   背景 Android中的广播可以跨App直接通信（exported对于有intent-filter情况下默认值为true)
5. **粘性广播**（Sticky Broadcast） 由于在Android5.0 & API 21中已经失效，所以不建议使用，在这里也不作过多的总结。

冲突 可能出现的问题：
其他App针对性发出与当前App intent-filter相匹配的广播，由此导致当前App不断接收广播并处理；
其他App注册与当前App一致的intent-filter用于接收广播，获取广播具体信息； 即会出现安全性 & 效率性的问题。
解决方案 使用App应用内广播（Local Broadcast）
App应用内广播可理解为一种局部广播，广播的发送者和接收者都同属于一个App。 相比于全局广播（普通广播），
App应用内广播优势体现在：安全性高 & 效率高
具体使用1 - 将全局广播设置成局部广播
注册广播时将exported属性设置为false，使得非本App内部发出的此广播不被接收； 在广播发送和接收时，增设相
应权限permission，用于权限验证；
发送广播时指定该广播接收器所在的包名，此广播将只会发送到此包中的App内与之相匹配的有效广播接收器中。
具体使用2 - 使用封装好的LocalBroadcastManager类
对于LocalBroadcastManage,方式发送的应用内广播，只能通过LocalBroadcastManager动态注册，不能静态注册

**应用场景**
   同一 App 内部的不同组件之间的消息通信（单个进程）；
   不同 App 之间的组件之间消息通信；
   Android系统在特定情况下与App之间的消息通信，如：网络变化、电池电量、屏幕开关等。 

#### 3.2.广播的两种注册方式的区别  

静态注册：常驻系统，不受组件生命周期影响，即便应用退出，广播还是可以被接收，耗电、占内存。
动态注册：非常驻，跟随组件的生命变化，组件结束，广播结束。在组件结束前，需要先移除广播，否则容易造成内
存泄漏。  

#### 3.3.广播发送和接收的原理  

https://juejin.im/post/6844904057891471367#heading-0
http://gityuan.com/2016/06/04/broadcast-receiver/
动态注册
1.创建对象LoadedApk.ReceiverDispatcher.InnerReceiver的实例，该对象继承于
IIntentReceiver.Stub（InnerReceiver实际是一个binder本地对象(BBinder：本地Binder，服务实现方的基类，提供
了onTransact接口来接收请求)）。
2.将IIntentReceiver对象和注册所传的IntentFilter对象发送给AMS。 AMS记录IIntentReceiver、IntentFilter和注册
的进程ProcessRecord，并建立起它们的对应关系。
3.当有广播发出时，AMS根据广播intent所携带的IntentFilter找到IIntentReceiver和ProcessRecord，然后回调App
的ApplicationThread对象的scheduleRegisteredReceiver，将IIntentReceiver和广播的intent一并传给App，App直
接调用IIntentReceiver的performReceive。
4.因为广播是通过binder线程回调到接收进程的，接收进程通过ActivityThread里的H这个Handler将调用转到主线
程，然后回调BroadcastReceiver的onReceive。  

静态注册
静态注册是通过在Manifest文件中声明实现了BroadcastReceiver的自定义类和对应的IntentFilter，来告诉
PMS(PackageManagerService)这个App所注册的广播。
当AMS接收到广播后，会查找所有动态注册的和静态注册的广播接收器，静态注册的广播接收器是通过
PMS(PackageManagerService)发现的，PMS找到对应的App
对应进程已经创建，直接调用App的ApplicationThread对象的scheduleReceiver
对应进程尚未创建，先启动App进程，App进程启动后回调AMS的attachApplication，attachApplication则继续派发
刚才的广播App这边收到调用后会先通过Handler转到主线程，然后根据AMS传过来的参数实例化广播接收器的类，
接着调用广播接收器的onReceive。

#### 3.4.本地广播和全局广播的区别

BroadcastReceiver是针对应用间、应用与系统间、应用内部进行通信的一种方式
LocalBroadcastReceiver仅在自己的应用内发送接收广播，也就是只有自己的应用能收到，数据更加安全广播只在这
个程序里，而且效率更高。
BroadcastReceiver采用的binder方式实现跨进程间的通信；
LocalBroadcastManager使用Handler通信机制。
LocalBroadcastReceiver 使用
LocalBroadcastReceiver不能静态注册，只能采用动态注册的方式。
在发送和注册的时候采用，LocalBroadcastManager的sendBroadcast方法和registerReceiver方法
http://gityuan.com/2017/04/23/local_broadcast_manager/
注册过程，主要是向mReceivers和mActions添加相应数据：
mReceivers：数据类型为HashMap<BroadcastReceiver, ArrayList>， 记录广播接收者与IntentFilter列表的对应关
系；
mActions：数据类型为HashMap<String, ArrayList>， 记录action与广播接收者的对应关系
根据Intent的action来查询相应的广播接收者列表；
发送MSG_EXEC_PENDING_BROADCASTS消息，回调相应广播接收者的onReceive方法。

## 4.ContentProvider

### 4.1.什么是ContentProvider及其使用

ContentProvider的作用是为不同的应用之间数据共享，提供统一的接口，我们知道安卓系统中应用内部的数据是对外隔离的，要想让其它应用能使用自己的数据（例如通讯录）这个时候就用到了ContentProvider。
ContentProvider（内容提供者）通过 uri 来标识其它应用要访问的数据。
通过 ContentResolver（内容解析者）的增、删、改、查方法实现对共享数据的操作
还可以通过注册 ContentObserver（内容观察者）来监听数据是否发生了变化来对应的刷新页面 

### 4.2.ContentProvider,ContentResolver,ContentObserver之间的关系

ContentProvider：管理数据，提供数据的增删改查操作，数据源可以是数据库、文件、XML、网络等。
ContentResolver：外部进程可以通过 ContentResolver 与 ContentProvider 进行交互。其他应用中
ContentResolver 可以不同 URI 操作不同的 ContentProvider 中的数据。
ContentObserver：观察 ContentProvider 中的数据变化，并将变化通知给外界。

### 4.3.ContentProvider的实现原理

https://juejin.im/post/6844904062173839368#heading-0
http://gityuan.com/2016/07/30/content-provider/
https://blog.csdn.net/u011733869/article/details/83958712

ContentProvider的安装(ActivityThread.installProvider)
当主线程收到H.BIND_APPLICATION消息后，会调用handleBindApplication方法。
handleBindApplication->installProvider
installProvider()
创建了provider对象
创建ProviderClientRecord，这是一个provider在client进程中对应的对象
放入mProviderMap(记录所有contentProvider)
总结：把provider启动起来并记录和发布给AMS
ContentResolver.query
调用端App在使用ContentProvider前首先要获取ContentProvider
1.通过ContentResolver调用acquireProvider
2.ActivityThread首先通过一个map查找是否已经install过这个Provider，如果install过就直接将之返回给调用者，如果没有install过就调用AMS的getContentProvider，AMS首先查找这个Provider是否被publish过，如果publish过就直接返回，否则通过PMS找到Provider所在的App。
3.如果发现目标App进程未启动,就创建一个ContentProviderRecord对象然后调用其wait方法阻塞当前执行流程,启动目标App进程,AMS找到App的所有运行于当前进程的Provider,保存在map中,将要启动的所有Provider传给目标App进程,解除前面对获取Provider执行流程的阻塞。
4.如果目标App进程已启动，AMS在getContentProvider里会查找到要获取的Provider，就直接返回了，调用端App收到AMS的返回结果后(acquireProvider返回)，调用ActivityThread的installProvider将Provider记录到本地的一个map中，下次再调用acquireProvider就直接返回。
ContentProvider所提供的接口中只有query是基于共享内存的，其他都是直接使用binder的入参出参进行数据传递。
AMS作为一个中间管理员的身份，所有的provider会向它注册
向AMS请求到provider之后，就可以在client和server之间自行binder通信，不需要再经过systemserver

### 4.4.ContentProvider的优点

**封装**
采用ContentProvider方式，其解耦了底层数据的存储方式，使得无论底层数据存储采用何种方式，外界对数据的访问方式都是统一的，这使得访问简单 & 高效
如一开始数据存储方式 采用 SQLite 数据库，后来把数据库换成 MongoDB，也不会对上层数据ContentProvider使用代码产生影响

**提供一种跨进程数据共享的方式**
应用程序间的数据共享还有另外的一个重要话题，就是数据更新通知机制了。因为数据是在多个应用程序中共享的，
当其中一个应用程序改变了这些共享数据的时候，它有责任通知其它应用程序，让它们知道共享数据被修改了，这样它们就可以作相应的处理。

### 4.5.Uri 是什么

定义：Uniform Resource Identifier，即统一资源标识符
作用：唯一标识 ContentProvider & 其中的数据，URI分为 系统预置 & 自定义，分别对应系统内置的数据（如通讯录、日程表等等）和自定义数据库
每一个 ContentProvider 都拥有一个公共的 URI ，这个 URI 用于表示这个 ContentProvider 所提供的数据。

在Android中URI的格式如下图所示：

![435](https://raw.githubusercontent.com/treech/PicRemote/master/common/435.jpg)

- A（主题） : schema，已经由Android所规定为：content://
- B（授权信息） : 主机名（Authority），是URI的授权部分，是唯一标识符，用来定位ContentProvider
- C（表名） : 指向一个对象集合，一般用表的名字，如果没有指定D部分，则返回全部记录。
- D （ID）: 指向特定的记录，这里表示操作user表id为7的记录。如果要操作user表中id为7的记录的name字段， D部分变为 /7/name即可。

## 5.Handler

### 5.1.Handler的实现原理

从四个方面看`Handler`、`Message`、`MessageQueue` 和` Looper`
Handler:负责消息的发送和处理
Message:消息对象，类似于链表的一个结点;
MessageQueue:消息队列，用于存放消息对象的数据结构;
Looper:消息队列的处理者（用于轮询消息队列的消息对象)

**Handler发送消息时调用MessageQueue的enqueueMessage插入一条信息到MessageQueue,Looper不断轮询调用MeaasgaQueue的next方法 如果发现message就调用handler的dispatchMessage，dispatchMessage被成功调用，接着调用handlerMessage()**

### 5.2.Looper死循环为什么不会导致应用卡死？

点击app图标，首先会进入ActivityThread的main方法，这里是android程序的入口，线程是有生命周期的，任务执行结束，或者在执行任务过程中抛了异常，线程就结束了，正是由于 Looper 维护的这个死循环才能保证主线程不退出，如下所示：

```java
public static void main(String[] args) {
    Trace.traceBegin(Trace.TRACE_TAG_ACTIVITY_MANAGER, "ActivityThreadMain");
    ...
    Looper.prepareMainLooper();
    
    ActivityThread thread = new ActivityThread();
    thread.attach(false, startSeq);

    if (sMainThreadHandler == null) {
        sMainThreadHandler = thread.getHandler();
    }

    // End of event ActivityThreadMain.
    Trace.traceEnd(Trace.TRACE_TAG_ACTIVITY_MANAGER);
    Looper.loop();

    throw new RuntimeException("Main thread loop unexpectedly exited");
}
```

Activity的生命周期都是由Handler来完成的。Looper死循环指的是Looper.loop（）方法里无限循环取出消息。而应用卡死指的是应用ANR，即应用无响应。先看看loop方法

Looper.java

```java
public static void loop() {
    final Looper me = myLooper();
    if (me == null) {
        throw new RuntimeException("No Looper; Looper.prepare() wasn't called on this thread.");
    }

    for (;;) {
        if (!loopOnce(me, ident, thresholdOverride)) {
            return;
        }
    }
}
```

```java
private static boolean loopOnce(final Looper me,
        final long ident, final int thresholdOverride) {
    Message msg = me.mQueue.next(); // might block
    if (msg == null) {
        // No message indicates that the message queue is quitting.
        return false;
    }

    // Make sure the observer won't change while processing a transaction.
    final Observer observer = sObserver;

    Object token = null;
    if (observer != null) {
        token = observer.messageDispatchStarting();
    }
    long origWorkSource = ThreadLocalWorkSource.setUid(msg.workSourceUid);
    try {
        msg.target.dispatchMessage(msg);
        if (observer != null) {
            observer.messageDispatched(token, msg);
        }
        dispatchEnd = needEndTime ? SystemClock.uptimeMillis() : 0;
    } catch (Exception exception) {
        if (observer != null) {
            observer.dispatchingThrewException(token, msg, exception);
        }
        throw exception;
    } finally {
        ThreadLocalWorkSource.restore(origWorkSource);
        if (traceTag != 0) {
            Trace.traceEnd(traceTag);
        }
    }
    msg.recycleUnchecked();

    return true;
}
```
MessageQueue.java

```
Message next() {
	for (;;) {
		nativePollOnce(ptr, nextPollTimeoutMillis);
	}
}
```

上述可以看出for(;;)是一个无限循环，不停地轮询消息队列并取出消息，然后将消息分发出去（简单的描述）。Android应用程序就是通过这个方法来达到及时响应用户操作。这个过程并不会导致ANR，ANR指应用程序在一定时间内没有得到响应或者响应时间太长。在主线程的MessageQueue没有消息时，便阻塞在loop的queue.next()中的**nativePollOnce**()方法里，此时主线程会释放CPU资源进入休眠状态。因为没有消息，即不需要响应程序，便不会出现程序无响应（ANR）现象。

总结：loop无限循环用于取出消息并将消息分发出去，没有消息时会阻塞在queue.next()里的**nativePollOnce**()方法里，并释放CPU资源进入休眠。Android的绝大部分操作都是通过Handler机制来完成的，如果没有消息，则不需要程序去响应，就不会有ANR。ANR一般是消息的处理过程中耗时太长导致没有及时响应用户操作。

### 5.3.子线程中能不能直接new一个Handler,为什么主线程可以

主线程的Looper第一次调用loop方法,什么时候,哪个类不能，因为Handler的构造方法中，会通过Looper.myLooper()获取looper对象，如果为空，则抛出异常，主线程则因为已在入口处ActivityThread的main方法中通过 Looper.prepareMainLooper()获取到这个对象，并通过 Looper.loop()开启循环，在子线程中若要使用handler，可先通过Loop.prepare获取到looper对象，并使用Looper.loop()开启循环

### 5.4.Handler导致的内存泄露原因及其解决方案

原因:
1.Java中非静态内部类和匿名内部类都会隐式持有当前类的外部引用
2.我们在Activity中使用非静态内部类初始化了一个Handler,此Handler就会持有当前Activity的引用。
3.我们想要一个对象被回收，那么前提它不被任何其它对象持有引用，所以当我们Activity页面关闭之后,存在引用关系："未被处理 / 正处理的消息 -> Handler实例 -> 外部类"，如果在Handler消息队列还有未处理的消息 / 正在处理消息时，导致Activity不会被回收，从而造成内存泄漏 

解决方案: 
1.将Handler的子类设置成 静态内部类,使用WeakReference弱引用持有Activity实例 
2.当外部类结束生命周期时，清空Handler内消息队列

### 5.5.一个线程可以有几个Handler,几个Looper,几个MessageQueue对象 

一个线程可以有多个Handler,只有一个Looper对象,只有一个MessageQueue对象。Looper.prepare()函数中知道。在Looper的prepare方法中创建了Looper对象，并放入到ThreadLocal中，并通过ThreadLocal来获取looper的对象, ThreadLocal的内部维护了一个ThreadLocalMap类,ThreadLocalMap是以当前thread作为key的,因此可以得知，一个线程最多只能有一个Looper对象， 在Looper的构造方法中创建了MessageQueue对象，并赋值给mQueue字段。因为Looper对象只有一个，那么Messagequeue对象肯定只有一个。 

### 5.6.Message对象创建的方式有哪些 & 区别 

Message.obtain()怎么维护消息池的
1.Message msg = new Message();
每次需要Message对象的时候都创建一个新的对象，每次都要去堆内存开辟对象存储空间
2.Message msg =Message.obtain();
obtainMessage能避免重复Message创建对象。它先判断消息池是不是为空，如果非空的话就从消息池表头的Message取走,再把表头指向 next。
如果消息池为空的话说明还没有Message被放进去，那么就new出来一个Message对象。消息池使用 Message 链表结构实现，消息池默认最大值 50。消息在loop中被handler分发消费之后会执行回收的操作，将该消息内部数据清空并添加到消息链表的表头。
3.Message msg = handler.obtainMessage(); 其内部也是调用的obtain()方法 。

### 5.7.Handler 有哪些发送消息的方法

```java
sendMessage(Message msg)
sendMessageDelayed(Message msg, long uptimeMillis)
post(Runnable r)
postDelayed(Runnable r, long uptimeMillis)
sendMessageAtTime(Message msg,long when)
```

### 5.8.Handler的post与sendMessage的区别和应用场景

1.源码
sendMessage
sendMessage-sendMessageAtTime-enqueueMessage。
post
sendMessage-getPostMessage-sendMessageAtTime-enqueueMessage getPostMessage会先生成一个Messgae，并且把runnable赋值给message的callback
2.Looper->dispatchMessage处理时

```
public void dispatchMessage(@NonNull Message msg) {
    if (msg.callback != null) {
    	handleCallback(msg);
    } else {
    	if (mCallback != null) {
    		if (mCallback.handleMessage(msg)) {
    			return;
    		} 
    	}
    	handleMessage(msg);
    } 
}
```

dispatchMessage方法中直接执行post中的runnable方法。
而sendMessage中如果mCallback不为null就会调用mCallback.handleMessage(msg)方法，如果handler内的callback不为空，执行mCallback.handleMessage(msg)这个处理消息并判断返回是否为true，如果返回true，消息处理结束，如果返回false,handleMessage(msg)处理。否则会直接调用handleMessage方法。
post方法和handleMessage方法的不同在于，区别就是调用post方法的消息是在post传递的Runnable对象的run方法中处理，而调用sendMessage方法需要重写handleMessage方法或者给handler设置callback，在callback的handleMessage中处理并返回true

应用场景

post一般用于单个场景 比如单一的倒计时弹框功能 sendMessage的回调需要去实现handleMessage Message则作为参数 用于多判断条件的场景

### 5.9.handler postDelay后消息队列有什么变化，假设先 postDelay 10s, 再postDelay 1s, 怎么处理这2条消息sendMessageDelayedsendMessageAtTime-sendMessage

ostDelayed传入的时间，会和当前的时间SystemClock.uptimeMillis()做加和,而不是单纯的只是用延时时间。延时消息会和当前消息队列里的消息头的执行时间做对比，如果比头的时间靠前，则会做为新的消息头，不然则会从消息头开始向后遍历，找到合适的位置插入延时消息。
postDelay()一个10秒钟的Runnable A、消息进队，MessageQueue调用nativePollOnce()阻塞，Looper阻塞；
紧接着post()一个Runnable B、消息进队，判断现在A时间还没到、正在阻塞，把B插入消息队列的头部（A的前面），然后调用**nativeWake()**方法唤醒线程；
**MessageQueue.next()**方法被唤醒后，重新开始读取消息链表，第一个消息B无延时，直接返回给Looper；
Looper处理完这个消息再次调用next()方法，MessageQueue继续读取消息链表，第二个消息A还没到时间，计算一下剩余时间（假如还剩9秒）继续调用**nativePollOnce()**阻塞； 直到阻塞时间到或者下一次有Message进队；

### 5.10.MessageQueue是什么数据结构

内部存储结构并不是真正的队列，而是采用单链表的数据结构来存储消息列表
这点和传统的队列有点不一样，主要区别在于Android的这个队列中的消息是按照时间先后顺序来存储的，时间较早的消息，越靠近队头。 当然，我们也可以理解成，它是先进先出的，只是这里的先依据的不是谁先入队，而是消息待发送的时间

### 5.11.Handler怎么做到的一个线程对应一个Looper，如何保证只有一个，MessageQueue ThreadLocal在Handler机制中的作用

设计的初衷是为了解决多线程编程中的资源共享问题，
synchronized采取的是“以时间换空间”的策略，本质上是对关键资源上锁，让大家排队操作。
而ThreadLocal采取的是“以空间换时间”的思路， 它一个线程内部的数据存储类，通过它可以在制定的线程中存储数据，数据存储以后，只有在指定线程中可以获取到存储的数据， 对于其他线程就获取不到数据，可以保证本线程任何时间操纵的都是同一个对象。比如对于Handler，它要获取当前线程的Looper,很显然Looper的作用域就是线程，并且不同线程具有不同的Looper。 ThreadLocal本质是操作线程中ThreadLocalMap来实现本地线程变量的存储的ThreadLocalMap是采用数组的方式来存储数据，其中key(弱引用)指向当前ThreadLocal对象，value的值是通过ThreadLocal计算出Hash key，通过这个构造出 ThreadLocal对象，value为设的值。

### 5.12.HandlerThread是什么 & 好处 &原理 & 使用场景
HandlerThread本质上是一个线程类，它继承了Thread； HandlerThread有自己的内部Looper对象，通过Looper.loop()进行looper循环；
通过获取HandlerThread的looper对象传递给Handler对象，然后在handleMessage()方法中执行异步任务；
优势:
1.将loop运行在子线程中处理,减轻了主线程的压力,使主线程更流畅,有自己的消息队列,不会干扰UI线程
2.串行执行,开启一个线程起到多个线程的作用
劣势:
1.由于每一个任务队列逐步执行,一旦队列耗时过长,消息延时
2.对于IO等操作,线程等待,不能并发
我们可以使用HandlerThread处理本地IO读写操作（数据库，文件），因为本地IO操作大多数的耗时属于毫秒级别，
对于单线程 + 异步队列的形式 不会产生较大的阻塞

使用示例：
1. 创建 HandlerThread 实例对象

    ```java
    HandlerThread mHandlerThread = new HandlerThread("mHandlerThread");
    ```
    
2. 启动线程

    ```java
    mHandlerThread .start();
    ```
    
3. 创建Handler对象，重写handleMessage方法

    ```java
     @Override
    public boolean handleMessage(Message msg) {
           //消息处理
           return true;
     }
    ```
    
4. 使用工作线程Handler向工作线程的消息队列发送消息:

    ```java
     message.what = “2”
     message.obj = "骚风"
     mHandler.sendMessage(message);
    ```
    
5. 结束线程，即停止线程的消息循环

    ```java
    mHandlerThread.quit()；
    ```

### 5.13.IdleHandler及其使用场景  

Handler机制提供的一种，可以在 Looper 事件循环的过程中，当出现空闲的时候，允许我们执行任务的一种机制。
IdleHandler在looper里面的message处理完了的时候去调用
**怎么使用**
IdleHandler 被定义在 MessageQueue 中，它是一个接口. 定义时需要实现其 queueIdle() 方法。返回值为 true 表示是一个持久的 IdleHandler 会重复使用，返回 false 表示是一个一次性的 IdleHandler。
IdleHandler 被 MessageQueue 管理，对应的提供了 addIdleHandler() 和 removeIdleHandler() 方法。将其存入mIdleHandle addIdleHandler() 和 removeIdleHandler() 方法。将其存入 mIdleHandlers 这个 ArrayList 中。
**什么时候调用**
就在MessageQueue的next方法里面。 MessageQueue 为空，没有 Message； MessageQueue 中最近待处理的Message，是一个延迟消息（when>currentTime），需要滞后执行；
**使用场景**
1.Activity启动优化：onCreate，onStart，onResume中耗时较短但非必要的代码可以放到IdleHandler中执行，减少启动时间
2.想要在一个View绘制完成之后添加其他依赖于这个View的View，当然这个用View#post()也能实现，区别就是前者会在消息队列空闲时执行
优化页面的启动,较复杂的view填充 填充里面的数据界面view绘制之前的话，就会出现以上的效果了，view先是白的，再出现. app的进程其实是ActivityThread,performResumeActivity先回调onResume ， 之后执行view绘制的
measure, layout, draw,也就是说onResume的方法是在绘制之前，在onResume中做一些耗时操作都会影响启动时间，把在onResume以及其之前的调用的但非必须的事件（如某些界面View的绘制）挪出来找一个时机（即绘制完成以后）去调用即可。  

### 5.14.消息屏障，同步屏障机制what

同步屏障只在Looper死循环获取待处理消息时才会起作用，也就是说同步屏障在MessageQueue.next函数中发挥着作用。
在next()方法中，有一个屏障的概念(message.target ==null为屏障消息), 遇到target为null的Message，说明是同步屏障，循环遍历找出一条异步消息，然后处理。 在同步屏障没移除前，只会处理异步消息，处理完所有的异步消息后，就会处于堵塞 当出现屏障的时候，会滤过同步消息，而是直接获取其中的异步消息并返回, 就是这样来实现「异步消息优先执行」的功能
how
1、Handler构造方法中传入async参数，设置为true，使用此Handler添加的Message都是异步的；
2、创建Message对象时，直接调用setAsynchronous(true) 3.removeSyncBarrier() 移除同步屏障：
应用
在 View 更新时，draw、requestLayout、invalidate 等很多地方都调用了ViewRootImpl#scheduleTraversals(
Android应用框架中为了更快的响应UI刷新事件在ViewRootImpl.scheduleTraversals中使用了同步屏障

### 5.15.子线程能不能更新UI

刷新UI，都会调用到ViewRootImpl，Android每次刷新UI的时候，最终根布局ViewRootImpl.checkThread()来检验线
程是否是View的创建线程。 ViewRootImpl创建的第一个地方，从Acitivity声明周期handleResumeActivity会被优先
调用到，也就是说在OnResume后ViewRootImpl就被创建，这个时候无法在在子线程中访问UI了，上面子线程延迟
了一会，handleResumeActivity已经被调用了，所以发生了崩溃，不延迟在onCreate()里直接设置不会崩溃，子线程更新UI也
行，但是只能更新自己创建的View。

总结：

- 子线程可以在`ViewRootImpl`还没有被创建之前更新`UI`；
- 访问`UI`是没有加对象锁的，在子线程环境下更新`UI`，会造成不可预期的风险；
- 开发者更新`UI`一定要在主线程进行操作;

参考：https://www.jianshu.com/p/58c999d3ada7

### 5.16.为什么Android系统不建议子线程访问UI

在android中子线程可以有好多个，但是如果每个线程都可以对ui进行访问，我们的界面可能就会变得混乱不堪，这
样多个线程操作同一资源就会造成线程安全问题，当然，需要解决线程安全问题的时候，我们第一想到的可能就是加
锁，但是加锁会降低运行效率，所以android出于性能的考虑，并没有使用加锁来进行ui操作的控制。
### 5.17.Android中为什么主线程不会因为Looper.loop()里的死循环卡死？

MessageQueue.next() 在没有消息的时候会阻塞，如何恢复？
他不阻塞的原因是epoll机制，他是linux里面的，在native层会有一个读取端和一个写入端，当有消息发送过来的时
候会去唤醒读取端，然后进行消息发送与处理，没消息的时候是处于休眠状态，所以他不会阻塞他 
**具体可以看5.2**

### 5.18.Handler消息机制中，一个looper是如何区分多个Handler的，当Activity有多个Handler的时候，怎么样区分当前消息由哪个Handler处理，处理message的时候怎么知道是去哪个callback处理的

每个Handler会被添加到 Message 的target字段上面，Looper 通过调用 Message.target.handleMessage() 来让Handler 处理消息。

### 5.19.Looper.quit/quitSafely的区别

当我们调用Looper的quit方法时，实际上执行了MessageQueue中的removeAllMessagesLocked方法，该方法的作
用是把MessageQueue消息池中所有的消息全部清空， 无论是延迟消息（延迟消息是指通过sendMessageDelayed
或通过postDelayed等方法发送的需要延迟执行的消息）还是非延迟消息。
当我们调用Looper的quitSafely方法时，实际上执行了MessageQueue中的removeAllFutureMessagesLocked方
法，通过名字就可以看出，该方法只会清空MessageQueue消息池中所有的延迟消息，并将消息池中所有的非延迟
消息派发出去让Handler去处理，quitSafely相比于quit方法安全之处在于清空消息之前会派发所有的非延迟消息。  

### 5.20.通过Handler如何实现线程的切换

当在A线程中创建handler的时候，同时创建了MessageQueue与Looper，Looper在A线程中调用loop进入一个无限
的for循环从MessageQueue中取消息，当B线程调用handler发送一个message的时候，会通过
msg.target.dispatchMessage(msg);将message插入到handler对应的MessageQueue中，Looper发现有message
插入到MessageQueue中，便取出message执行相应的逻辑，因为Looper.loop()是在A线程中启动的，所以则回到
了A线程，达到了从B线程切换到A线程的目的  

### 5.21.Handler 如何与 Looper 关联的

通过构造方法 mLooper = Looper.myLooper()->sThreadLocal.get()( sThreadLocal.set)  

![image-20220823174512638](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20220823174512638.png)

![image-20220823174440842](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20220823174440842.png)

### 5.22.Looper 如何与 Thread 关联的

Looper 与 Thread 之间是通过 ThreadLocal 关联的，这个可以看 Looper.prepare() 方法 Looper 中有一个
ThreadLocal 类型的 sThreadLocal静态字段，Looper通过它的 get 和 set 方法来赋值和取值。 由于 ThreadLocal是
与线程绑定的，所以我们只要把 Looper 与 ThreadLocal 绑定了，那 Looper 和 Thread 也就关联上了

### 5.23.Looper.loop()源码
for无限循环，阻塞于消息队列的next方法 取出消息后调用msg.target.dispatchMessage(msg)进行消息分发

### 5.24.MessageQueue的enqueueMessage()方法如何进行线程同步的

就是单链表的插入操作 如果消息队列被阻塞回调用nativeWake去唤醒。 用synchronized代码块去进行同步。
### 5.25.MessageQueue的next()方法内部原理
next() 是如何处理一般消息的？
next() 是如何处理同步屏障的？
next() 是如何处理延迟消息的?

调用 MessageQueue.next() 方法的时候会调用 Native 层的 nativePollOnce() 方法进行精准时间的阻塞。在 Native
层，将进入 pullInner() 方法，使用 epoll_wait 阻塞等待以读取管道的通知。如果没有从 Native 层得到消息，那么这
个方法就不会返回。此时主线程会释放 CPU 资源进入休眠状态。

### 5.26.子线程中是否可以用MainLooper去创建Handler，Looper和Handler是否一定处于一个线程

可以的。 子线程中Handler handler = new Handler(Looper.getMainLooper());，此时两者就不在一个线程中

### 5.27.ANR和Handler的联系

Handler是线程间通讯的机制，Android中，网络访问、文件处理等耗时操作必须放到子线程中去执行，否则将会造成ANR异常。 ANR异常：Application Not Response 应用程序无响应，产生ANR异常的原因：在主线程执行了耗时操作，解决ANR异常的方法：耗时操作都在子线程中去执行，但是，Android不允许在子线程去修改UI，可我们又有在子线程去修改UI的需求，因此需要借助Handler。

以下四个条件都可以造成ANR发生：

- **InputDispatching Timeout**：5秒内无法响应屏幕触摸事件或键盘输入事件
- **BroadcastQueue Timeout** ：在执行前台广播（BroadcastReceiver）的`onReceive()`函数时10秒没有处理完成，后台为60秒。
- **Service Timeout** ：前台服务20秒内，后台服务在200秒内没有执行完毕。
- **ContentProvider Timeout** ：ContentProvider的publish在10s内没进行完。

## 6.View绘制

### 6.1.View绘制流程

https://cloud.tencent.com/developer/article/1745688

https://www.jianshu.com/p/58d22426e79e

https://www.jianshu.com/p/887336850177

https://blog.csdn.net/yanbober/article/details/46128379?ops_request_misc=%257B%2522request%255Fid%2522%253A%2522166131307516781667877242%2522%252C%2522scm%2522%253A%252220140713.130102334.pc%255Fblog.%2522%257D&request_id=166131307516781667877242&biz_id=0&utm_medium=distribute.pc_search_result.none-task-blog-2~blog~first_rank_ecpm_v1~rank_v31_ecpm-10-46128379-null-null.nonecase&utm_term=%E5%8A%A0%E8%BD%BD&spm=1018.2226.3001.4450

触发addView流程：  

![2828107-6dc539d3c3bd1dd1](https://raw.githubusercontent.com/treech/PicRemote/master/common/2828107-6dc539d3c3bd1dd1.webp)

performTraversals流程：  

![2828107-e48448d2a1057518](https://raw.githubusercontent.com/treech/PicRemote/master/common/2828107-e48448d2a1057518.webp)

measure、layout、draw流程：  

![2828107-db17d5b4e367b6ef](https://raw.githubusercontent.com/treech/PicRemote/master/common/2828107-db17d5b4e367b6ef.webp)![2828107-899e1d007adeca55](https://raw.githubusercontent.com/treech/PicRemote/master/common/2828107-899e1d007adeca55.webp)![12](https://raw.githubusercontent.com/treech/PicRemote/master/common/12.webp)![2828107-a31ce96a5d1612aa](https://raw.githubusercontent.com/treech/PicRemote/master/common/2828107-a31ce96a5d1612aa.webp)

理解一：

startActivity->ActivityThread.handleLaunchActivity->onCreate ->完成DecorView和Activity的创建->handleResumeActivity->onResume()->DecorView添加到WindowManager->ViewRootImpl.performTraversals()
方法，测量（measure）,布局（layout）,绘制（draw）, 从DecorView自上而下遍历整个View树。
Measure：测量视图宽高。
单一View:measure() **->** onMeasure() **->** getDefaultSize() 计算View的宽/高值 **->** setMeasuredDimension存储测量后的View宽 / 高
ViewGroup:
**->** measure()
**->** 需要重写onMeasure( ViewGroup没有定义测量的具体过程，因为ViewGroup是一个抽象类，其测量过程的onMeasure方法需要各个子类去实现。如：LinearLayout、RelativeLayout、FrameLayout等等，这些控件的特性都是不一样的，测量规则自然也都不一样。)遍历测量ViewGroup中所有的View
**->** 根据父容器的MeasureSpec和子View的LayoutParams等信息计算子View的MeasureSpec
**->** 合并所有子View计算出ViewGroup的尺寸
**->** setMeasuredDimension 存储测量后的宽 / 高 从顶层父View向子View的递归调用view.layout方法的过程，即父View根据上一步measure子View所得到的布局大小和布局参数，将子View放在合适的位置上。
Layout：先通过measure测量出ViewGroup宽高，ViewGroup再通过layout方法根据自身宽高来确定自身位置。当ViewGroup的位置被确定后，就开始在onLayout方法中调用子元素的layout方法确定子元素的位置。子元素如果是ViewGroup的子类，又开始执行onLayout，如此循环往复，直到所有子元素的位置都被确定，整个View树的layout过程就执行完了。
Draw：绘制视图。ViewRoot创建一个Canvas对象，然后调用OnDraw()。六个步骤：①、绘制视图的背景；②、保存画布的图层（Layer）；③、绘制View的内容；④、绘制View子视图，如果没有就不用；⑤、还原图层（Layer）；⑥、绘制View的装饰(例如滚动条等等)。

理解二：

**View的绘制从ActivityThread类中Handler的处理RESUME_ACTIVITY事件开始，在执行performResumeActivity之后，调用WindowManager的addView方法将DecorView添加到屏幕上，addView又调用ViewRootImpl的setView方法，最终执行performTraversals方法，依次执行performMeasure，performLayout，performDraw。也就是view绘制的三大过程。**

performMeasure会调用measure，measure又会调用onMeasure(),最终测量出view视图的大小，还需要调用setMeasuredDimension方法设置测量的结果，如果是ViewGroup需要调用measureChildren或者measureChild方法测量子view的大小从而计算自己的大小。

performLayout会调用layout，layout又会调用onLayout(),从而计算出view摆放的位置，View不需要实现，通常由ViewGroup实现，在实现onLayout时可以通过getMeasuredWidth等方法获取measure过程测量的结果进行摆放。

performDraw会调用draw，draw又会调用onDraw(),这个过程先是绘制背景，其次在onDraw()方法绘制view的内容，再然后调用dispatchDraw()调用子view的draw方法，最后绘制滚动条。ViewGroup默认不会执行onDraw方法，如果复写了onDraw(Canvas)方法，需要调用 setWillNotDraw(false);清除不需要绘制的标记。

### 6.2.requestLayout()、invalidate()与postInvalidate()有什么区别？

requestLayout()：该方法会递归调用父窗口的requestLayout()方法，直到触发ViewRootImpl的performTraversals()方法，此时mLayoutRequestede为true，会触发onMesaure()与onLayout()方法，不一定会触发onDraw()方法。

invalidate()：该方法递归调用父View的invalidateChildInParent()方法，直到调用ViewRootImpl的invalidateChildInParent()方法，最终触发ViewRootImpl的performTraversals()方法，此时mLayoutRequestede为false，不会触发onMesaure()与onLayout()方法，但是会触发onDraw()方法。

postInvalidate()：该方法功能和invalidate()一样，只是它可以在非UI线程中调用。
一般说来需要重新布局就调用requestLayout()方法，需要重新绘制就调用invalidate()方法。

### 6.3.MeasureSpec是什么

MeasureSpec表示的是一个32位的整形值，它的高2位表示测量模式SpecMode，低30位表示某种测量模式下的规格大小SpecSize。MeasureSpec是View类的一个静态内部类，用来说明应该如何测量这个View。它由三种测量模式，
如下：
EXACTLY：精确测量模式，视图宽高指定为match_parent或具体数值时生效，表示父视图已经决定了子视图的精确大小，这种模式下View的测量值就是SpecSize的值。
AT_MOST：最大值测量模式，当视图的宽高指定为wrap_content时生效，此时子视图的尺寸可以是不超过父视图允许的最大尺寸的任何尺寸。
UNSPECIFIED：不指定测量模式, 父视图没有限制子视图的大小，子视图可以是想要的任何尺寸，通常用于系统内部，应用开发中很少用到。
MeasureSpec通过将SpecMode和SpecSize打包成一个int值来避免过多的对象内存分配，为了方便操作，其提供了打包和解包的方法，打包方法为makeMeasureSpec，解包方法为getMode和getSize。

### 6.4.子View创建MeasureSpec创建规则是什么

https://www.helloworld.net/p/7576286967

根据父容器的MeasureSpec和子View的LayoutParams等信息计算子View的MeasureSpec

![25c4705583497db347c014312def6ad4](https://raw.githubusercontent.com/treech/PicRemote/master/common/25c4705583497db347c014312def6ad4.png)

### 6.5.自定义View wrap_content不起作用的原因
https://www.jianshu.com/p/c1f8df587985

1.因为onMeasure()->getDefaultSize()，当View的测量模式是AT_MOST或EXACTLY时，View的大小都会被设置成子View MeasureSpec的specSize。

```java
public static int getDefaultSize(int size, int measureSpec) {
    switch (specMode) {
        case MeasureSpec.UNSPECIFIED:
            result = size;
            break;
        case MeasureSpec.AT_MOST:
        case MeasureSpec.EXACTLY:
            result = specSize;
            break;
    }
    return result;
} 
```

2.View的MeasureSpec值是根据子View的布局参数（LayoutParams）和父容器的MeasureSpec值计算得来，具体计算逻辑封装在getChildMeasureSpec()。 当子View wrap_content或match_parent情况下，子View MeasureSpec的specSize被设置成parenSize = 父容器当前剩余空间大小

![674980-b6f05d7b681ca9ad](https://raw.githubusercontent.com/treech/PicRemote/master/common/674980-b6f05d7b681ca9ad.webp)

3.所以当给一个View/ViewGroup设置宽高为具体数值或者match_parent，它都能正确的显示，但是如果你设置的是wrap_content->AT_MOST，则默认显示出来是其父容器的大小。如果你想要它正常的显示为wrap_content，所以需要自己重写onMeasure()来自己计算它的宽高度并设置。此时，可以在wrap_content的情况下（对应MeasureSpec.AT_MOST）指定内部宽/高(mWidth和mHeight)。  

### 6.6.在Activity中获取某个View的宽高有几种方法

- Activity/View#onWindowFocusChanged：此时View已经初始化完毕，当Activity的窗口得到焦点和失去焦点时均会被调用一次，如果频繁地进行onResume和onPause，那么onWindowFocusChanged也会被频繁地调用。
- view.post(runnable)： 通过post将runnable放入ViewRootImpl的RunQueue中，RunQueue中runnable最后的执行时机，是在下一个performTraversals到来的时候，也就是view完成layout之后的第一时间获取宽高。
- ViewTreeObserver#addOnGlobalLayoutListener：当View树的状态发生改变或者View树内部的View的可见性发生改变时，onGlobalLayout方法将被回调。
- View.measure(int widthMeasureSpec, int heightMeasureSpec)： match_parent 直接放弃，无法measure出具体的宽/高。原因很简单，根据view的measure过程，构造此种MeasureSpec需要知道parentSize，即父容器的剩余空间，而这个时候我们无法知道parentSize的大小，所以理论上不可能测量出view的大小。
```
//wrap_content
int widthMeasureSpec = View.MeasureSpec.makeMeasureSpec((1<<30)-1,View.MeasureSpec.AT_MOST); 
int heightMeasureSpec = View.MeasureSpec.makeMeasureSpec((1<<30)-1,View.MeasureSpec.AT_MOST); v_view1.measure(widthMeasureSpec, heightMeasureSpec);
```
注意到(1<<30)-1，我们知道MeasureSpec的前2位为mode，后面30位为size，所以说我们使用最大size值去匹配该最大化模式，让view自己去计算需要的大小。 这个特殊的 int 值就是 View 理论上能支持的最大值。 View 的尺寸使用 30 位二进制来表示，也就是说最大是 30 个 1（即 2^30 -1），也就是 (1<<30)-1。
具体的数值(dp/px) 这种模式下，只需要使用具体数值去measure即可，比如宽/高都是100px： 

```
int widthMeasureSpec = View.MeasureSpec.makeMeasureSpec(100,View.MeasureSpec.EXACTLY);
int heightMeasureSpec = View.MeasureSpec.makeMeasureSpec(100,View.MeasureSpec.EXACTLY);
v_view1.measure(widthMeasureSpec, heightMeasureSpec)
```

### 6.7.为什么onCreate获取不到View的宽高  

Activity在执行完oncreate，onResume之后才创建ViewRootImpl,ViewRootImpl进行View的绘制工作
**调用链**
startActivity->ActivityThread.handleLaunchActivity->onCreate ->完成DecorView和Activity的创建-
\>handleResumeActivity->onResume()->DecorView添加到WindowManager->ViewRootImpl.performTraversals()方法，测量（measure）,布局（layout）,绘制（draw）, 从DecorView自上而下遍历整个View树。

### 6.8.View#post与Handler#post的区别

```java
public boolean post(Runnable action) {
    final AttachInfo attachInfo = mAttachInfo;
    if (attachInfo != null) {
    	return attachInfo.mHandler.post(action);
    } 
    getRunQueue().post(action);
    return true;
}
```

对于View#post当View已经attach到window，直接调用UI线程的Handler发送runnable。如果View还未attach到window，将runnable放入ViewRootImpl的RunQueue中，而不是通过MessageQueue。RunQueue的作用类似于MessageQueue，只不过这里面的所有runnable最后的执行时机，是在下一个performTraversals到来的时候，也就是view完成layout之后的第一时间获取宽高，MessageQueue里的消息处理的则是下一次loop到来的时候。

### 6.9.Android绘制和屏幕刷新机制原理

绘制原理
https://juejin.cn/post/6844904080989487118#heading-6
https://blog.csdn.net/freekiteyu/article/details/79483406
http://skyacer.github.io/2018/06/09/Android%E7%AA%97%E5%8F%A3%E7%AE%A1%E7%90%86%E5%88%86%E6%9E%90%EF%BC%88%E4%BA%8C%EF%BC%89%E2%80%94%E2%80%94%20WindowManagerService%E5%9B%BE%E5%B1%82%E7%AE%A1%E7%90%86%E4%B9%8B%E7%AA%97%E5%8F%A3%E7%9A%84%E6%B7%BB%E5%8A%A0/

1.在 App 进程中创建PhoneWindow 后会创建ViewRoot。ViewRoot 的创建会创建一个 Surface壳子，请求WMS填充Surface，WMS copyFrom() 一个 NativeSurface。
2.响应客户端事件，创建Layer(FrameBuffer)与客户端的Surface建立连接。
3.copyFrom()的同时创建匿名共享内存SharedClient（每一个应用和SurfaceFlinger之间都会创建一个SharedClient）
4.当客户端 addView() 或者需要更新 View 时，App 进程的SharedBufferClient 写入数据到共享内存ShareClient中,SurfaceFlinger中的 SharedBufferServer 接收到通知会将 FrameBuffer 中的数据传输到屏幕上。

绘制的过程 CPU准备数据，通过Driver层把数据交给GPU渲染,Display负责消费显示内容
1.CPU主要负责Measure、Layout、Record、Execute的数据计算工作
2.GPU负责Rasterization（栅格化(向量图形的格式表示的图像转换成位图用于显示器)）、渲染,渲染好后放到buffer(图像缓冲区)里存起来.
3.Display（屏幕或显示器）屏幕会以一定的帧率刷新，每次刷新的时候，就会从缓存区将图像数据读取显示出来,如果缓存区没有新的数据，就一直用旧的数据，这样屏幕看起来就没有变

刷新机制（https://juejin.cn/post/6863756420380196877#heading-11)

双缓存
> 屏幕刷新频是固定的,每16.6ms从buffer取数据显示完一帧,理想情况是帧率（GPU 在一秒内绘制操作的帧数，单位fps）和刷新频率保持一致，即每绘制完成一帧，显示器显示一帧,但是CPU/GPU写数据是不可控,所以会出现buffer里有些数据根本没显示出来就被重写了导致buffer抓取的帧并不是完整的一帧画面，即出现画面撕裂。

由于图像绘制和屏幕读取 使用的是同个buffer，所以屏幕刷新时可能读取到的是不完整的一帧画面。所以引入双缓存让绘制和显示器拥有各自的buffer：GPU 始终将完成的一帧图像数据写入到 Back Buffer，而显示器使用 Frame Buffer，当屏幕刷新时，Frame Buffer 并不会发生变化，当Back buffer准备就绪后，它们才进行交换。
什么时候进行交换 引入VSync
VSync（解决画面撕裂）
如果 Back buffer准备完成一帧数据以后就进行交换,时屏幕还没有完整显示上一帧内容的话，肯定是会出问题
如果 Frame buffer处理完一帧数据以后进行交换，可以。
vsync垂直同步利用 垂直同步脉冲（当扫描完一个屏幕后，设备需要重新回到第一行以进入下一次的循环，，此时屏幕没有在刷新，有一段时间空隙，这个时间点就是我们进行缓冲区交换的最佳时间。） 保证双缓冲在最佳时间点才进行交换。

在Android4.1之前，屏幕刷新也遵循 上面介绍的 双缓存+VSync 机制
第2帧的CPU/GPU计算 没能在VSync信号到来前完成，屏幕平白无故地多显示了一次第1帧。
解决方式如果 Vsyn到来时 CPU/GPU就开始操作的话，是有完整的16.6ms的，这样应该会基本避免jank的出现了
为了优化显示性能，Google在Android 4.1系统中对Android Display系统进行了重构，实现了Project Butter（黄油工程）
**1.drawing with VSync**

> 一旦收到VSync通知（16ms触发一次），CPU和GPU 才立刻开始计算然后把数据写入buffer，可以让CPU/GPU有完整的16ms时间来处理数据，减少了jank

**2.三缓存**
如果界面比较复杂，CPU/GPU的处理时间较长 超过了16.6ms, Back buffer正在被GPU用来处理B帧的数据， Frame buffer的内容用于Display的显示，这样两个buffer都被占用，CPU 则无法准备下一帧的数据,在Jank的阶段空空等待，存在CPU资源浪费。
三缓存就是在双缓冲机制基础上增加了一个 Graphic Buffer 缓冲区，这样可以最大限度的利用空闲时间，带来的坏处是多使用的一个 Graphic Buffer 所占用的内存。
让多增加一个Buffer给CPU用，让它提前忙起来，这样就能做到三方都有Buffer可用，CPU跟GPU不用争一个Buffer，真正实现并行处理
三缓冲有效利用了等待vysnc的时间，减少了jank，保证画面的连续性，提高柔韧性
**3.Choreographer**
Choreographer， 编舞者。指对CPU/GPU绘制的指导，收到VSync信号才开始绘制，保证绘制拥有完整的16.6ms，避免绘制的随机性。控制只在vsync信号来时触发重绘呢
比如说绘制可能随时发起，封装一个Runnable丢给Choreography，下一个vsync信号来的时候，开始处理消息，然后真正的开始界面的重绘了。相当于UI绘制的节奏完全由Choreography来控制。
应用程序调用requestLayout发起重绘，通过Choreographer发送异步消息，请求同步vsync信号，即下一次vsync信号过来时，系统服务SurfaceFlinger在第一时间通知我们，触发UI绘制。虽然可以手动多次调用，但是在一个vsync周期内，requestLayout只会执行一次。

### 6.10.Choreography原理

绘制是由应用端(任何时候都有可能)发起的，如果屏幕收到vsync信号，但是这一帧的还没有绘制完，就会显示上一帧的数据，这并不是因为绘制这一帧的时间过长(超过了信号发送周期)，只是信号快来的时候才开始绘制，如果频繁的出现的这种情况。一般调用requestLayout触发，这个函数随时都能调用，为了只控制在vsync信号来时触发重绘引入Choreography。 ViewRoot.doTravle()->mChoreographer.postCallback
Choreographer对外提供了postCallback等方法，最终他们内部都是通过调用postCallbackDelayedInternal（）实现这个方法主要会做两件事情 1存储Action 请求垂直同步，垂直同步 2垂直同步回调立马执行Action（CallBack/Runnable）。

### 6.11.什么是双缓冲

通俗来讲就是有两个缓冲区，一个后台缓冲区和一个前台缓冲区，每次后台缓冲区接受数据，当填充完整后交换给前台缓冲，这样就保证了前台缓冲里的数据都是完整的。 Surface对应了一块屏幕缓冲区，是要显示到屏幕的内容的载体。每一个Window都对应了一个自己的Surface。这里说的 window 包括 Dialog, Activity, Status Bar等。
SurfaceFlinger 最终会把这些 Surface 在 z 轴方向上以正确的方式绘制出来（比如 Dialog 在 Activity 之上）。
SurfaceView 的每个 Surface 都包含两个缓冲区，而其他普通 Window 的对应的 Surface 则不是。

### 6.12.为什么使用SurfaceView

我们知道View是通过刷新来重绘视图，系统通过发出VSSYNC信号来进行屏幕的重绘，刷新的时间间隔是16ms,如果我们可以在16ms以内将绘制工作完成，则没有任何问题，如果我们绘制过程逻辑很复杂，并且我们的界面更新还非常频繁，这时候就会造成界面的卡顿，影响用户体验，为此Android提供了SurfaceView来解决这一问题。他们的UI不适合在主线程中绘制。对一些游戏画面，或者摄像头，视频播放等，UI都比较复杂，要求能够进行高效的绘制，因此，他们的UI不适合在主线程中绘制。这时候就必须要给那些需要复杂而高效的UI视图生成一个独立的绘制表面Surface,并且使用独立的线程来绘制这些视图UI。

### 6.13.什么是SurfaceView

SurfaceView是View的子类，且实现了Parcelable接口，其中内嵌了一个专门用于绘制的Surface，SurfaceView可以控制这个Surface的格式和尺寸，以及Surface的绘制位置。可以理解为Surface就是管理数据的地方，SurfaceView就是展示数据的地方。使用双缓冲机制，有自己的surface，在一个独立的线程里绘制。
SurfaceView虽然具有独立的绘图表面，不过它仍然是宿主窗口的视图结构中的一个结点，因此，它仍然是可以参与到宿主窗口的绘制流程中去的。从SurfaceView类的成员函数draw和dispatchDraw的实现就可以看出，SurfaceView在其宿主窗口的绘图表面上面所做的操作就是将自己所占据的区域绘为黑色，除此之外，就没有其它更多的操作了，这是因为SurfaceView的UI是要展现在它自己的绘图表面上面的。 
优点：使用双缓冲机制，可以在一个独立的线程中进行绘制，不会影响主线程，播放视频时画面更流畅 
缺点：Surface不在View hierachy中，它的显示也不受View的属性控制，SurfaceView不能嵌套使用。在7.0版本之前不能进行平移，缩放等变换，也不能放在其它ViewGroup中，在7.0版本之后可以进行平移，缩放等变换。

### 6.14.View和SurfaceView的区别

1. View适用于主动更新的情况，而SurfaceView则适用于被动更新的情况，比如频繁刷新界面。 
2. View在主线程中对页面进行刷新，而SurfaceView则开启一个子线程来对页面进行刷新。
3. View在绘图时没有实现双缓冲机制，SurfaceView在底层机制中就实现了双缓冲机制。

### 6.15.SurfaceView为什么可以直接子线程绘制

通常View更新的时候都会调用ViewRootImpl中的performXXX()方法，在该方法中会首先使用checkThread()检查是否当前更新位于主线线程，SurfaceView提供了专门用于绘制的Surface，可以通过SurfaceView来控制Surface的格式和尺寸，SurfaceView更新就不需要考虑线程的问题，它既可以在子线程更新，也可以在主线程更新。

### 6.16.SurfaceView、TextureView、SurfaceTexture、GLSurfaceView

https://zhooker.github.io/2018/03/24/SurfaceTexture%E7%9A%84%E5%8C%BA%E5%88%AB/

SurfaceView：使用双缓冲机制，有自己的 surface，在一个独立的线程里绘制，Android7.0之前不能平移、缩放
TextureView：它不会在WMS中单独创建窗口，而是作为一个普通View，可以和其它普通View一样进行移动，旋转，缩放，动画等变化。值得注意的是TextureView必须在硬件加速的窗口中。
SurfaceTexture：SurfaceTexture和SurfaceView不同的是，它对图像流的处理并不直接显示，而是转为OpenGL外部纹理，因此可用于图像流数据的二次处理（如Camera滤镜，桌面特效等）。 
GLSurfaceView：SurfaceView不同的是，它加入了EGL的管理，并自带了渲染线程。

### 6.17.getWidth()方法和getMeasureWidth()区别

1. getMeasuredWidth方法获得的值是setMeasuredDimension方法设置的值，它的值在measure方法运行后就会确定
2. getWidth方法获得是layout方法中传递的四个参数中的mRight-mLeft，它的值是在layout方法运行后确定的
3. 一般情况下在onLayout方法中使用getMeasuredWidth方法，而在除onLayout方法之外的地方用getWidth方法

### 6.18.invalidate() 和 postInvalidate() 方法的区别

requestLayout：会触发三大流程。 
invalidate：触发 onDraw 流程，在 UI 线程调用。 
postInvalidate：触发onDraw 流程，在非 UI 线程中调用。
1. view的invalidate递归调用父view的invalidateChildInParent，直到ViewRootImpl的invalidateChildInParent，然后触发peformTraversals，会导致当前view被重绘,由于mLayoutRequested为false，不会导致onMeasure
和onLayout被调用，而OnDraw会被调用
2. postInvalidate(),它可以在UI线程调用，也可以在子线程中调用， postInvalidate()方法内部通过Handler发送了一个消息将线程切回到UI线程通知重新绘制。最终还是调用了子View的invalidate()。

### 6.19.Requestlayout，onlayout，onDraw，drawChild区别与联系

requestLayout()方法 ：会导致调用 measure()过程 和 layout()过程,不一定会触发OnDraw。 requestLayout会直接递归调用父窗口的requestLayout，直到ViewRootImpl,然后触发peformTraversals，由于mLayoutRequested为true，会导致onMeasure和onLayout被调用。不一定会触发OnDraw， 将会根据标志位判断是否需要onDraw。

onLayout()方法：(如果该View是ViewGroup对象，需要实现该方法，对每个子视图进行布局)

onDraw()方法：绘制视图本身 (每个View都需要重载该方法，ViewGroup不需要实现该方法)。 

drawChild()：去重新回调每个子视图的draw()方法

### 6.20.LinearLayout、FrameLayout 和 RelativeLayout 哪个效率高

**简单布局** FrameLayout>LinearLayout>RelativeLayout 
**复杂布局** RelativeLayout>LinearLayout>FrameLayout
（1）Fragment是从上到下的一个堆叠的方式布局的，那当然是绘制速度最快，只需要将本身绘制出来即可，但是由于它的绘制方式导致在复杂场景中直接是不能使用的，所以工作效率来说Fragment仅使用于单一场景
（2）RelativeLayout会让子View调用2次onMeasure，LinearLayout 在有weight时，也会调用子View 2次onMeasure。 由于RelativeLayout需要在横向和纵向分别进行一次measure过程。而LinearLayout只进行纵向或横向的测量，所以measure的时间会比RelativeLayout少很多。但是如果设置了 weight,在测量的过程中，
LinearLayout会将设置过weight的和没设置的分别测量一次，这样就导致measure两次。 （3）在不影响层级深度的情况下,使用LinearLayout和FrameLayout而不是RelativeLayout，复杂布局使用RelativeLayout
**简单布局**:在DecorView自己是FrameLayout但是它只有一个子元素是属于LinearLayout。因为DecorView的层级深度是已知而且固定的，上面一个标题栏，下面一个内容栏。采用RelativeLayout并不会降低层级深度，所以此时在根节点上用LinearLayout是效率最高的。
**复杂布局**:RelativeLayout 在性能上更好，使用 LinearLayout 容易产生多层嵌套的布局结构，这在性能上是不好的。而 RelativeLayout 通常层级结构都比较扁平，很多使用LinearLayout 的情况都可以用一个 RelativeLayout 来替代，以降低布局的嵌套层级，优化性能。

### 6.21.LinearLayout的绘制流程

**onMeasure()**:
1：把 ViewRootImpl 的测量模式 传递给 DecorView，然后 DecorView 把测量模式 传递给LinearLayout，遍历子元素并对每个子元素执行measureChildBeforeLayout方法，这个方法内部会调用子元素的measure方法，这样各个子元素就开始依次进入measure过程。 

2.LinearLayout类的measureVertical方法会遍历每一个子元素并且执行LinearLayout类的measureChildBeforeLayout方法对子元素进行测量，LinearLayout类的
measureChildBeforeLayout方法内部会执行子元素的measure方法。在代码中，变量mTotalLength会是用来存放LinearLayout在竖直方向上的当前高度，每遍历一个子元素，mTotalLength就会增加 
onLayout(): 其中onLayout()会遍历调用每个子View的setChildFrame方法为子元素确定对应的位置 其中会遍历调用每个子View的setChildFrame方法为子元素确定对应的位置。其中的childTop会逐渐增大，意味着后面的子元素会被放置在靠下的位置

### 6.22.自定义 View 的流程和注意事项

大多数自定义View要么是在onDraw方法中画点东西，和在onTouchEvent中处理触摸事件。
自定义View步骤 ： 

onMeasure	可以不重写，不重写的话就要在外面指定宽高，建议重写； 
onDraw	看情况重写，如果需要画东西就要重写；
onTouchEvent	也是看情况，如果要做能跟手指交互的View，就重写； 

自定义View注意事项：
如果有自定义布局属性的，在构造方法中取得属性后应及时调用recycle方法回收资源；
onDraw和onTouchEvent方法中都应尽量避免创建对象，过多操作可能会造成卡顿；

自定义ViewGroup步骤：
onMeasure（必须），在这里测量每一个子View，还有处理自己的尺寸；
onLayout（必须），在这里对子View进行布局；
如有自己的触摸事件，需要重写onInterceptTouchEvent或onTouchEvent;
自定义ViewGroup注意事项：
如果想在ViewGroup中画点东西，又没有在布局中设置background的话，会画不出来，这时候需要调用setWillNotDraw方法，并设置为false；
如果有自定义布局属性的，在构造方法中取得属性后应及时调用recycle方法回收资源；
onDraw和onTouchEvent方法中都应尽量避免创建对象，过多操作可能会造成卡顿；

### 6.23.自定义View如何考虑机型适配

合理使用warp_content，match_parent。 尽可能地使用RelativeLayout。
针对不同的机型，使用不同的布局文件放在对应的目录下，android会自动匹配。
尽量使用点9图片。
使用与密度无关的像素单位dp，sp。
引入android的百分比布局。
切图的时候切大分辨率的图，应用到布局当中，在小分辨率的手机上也会有很好的显示效果。

### 6.24.自定义控件优化方案
1. 降低View.onDraw（）的复杂度 onDraw不要创建新的局部对象 onDraw不执行耗时操作 
2. 避免过度绘制（Overdraw） 过度绘制会导致屏幕显示的色块不同，尽可能避免过度绘制的粉色 & 红色情况，
- 移除默认的Window背景，若不移除，则导致所有界面都多1次绘制，
- 移除控件中不必要的背景 对于1个ViewPager + 多个Fragment 组成的首页界面，若每个Fragment都设有背景色，即 ViewPager 则无必要设置，可移除减少布局文件的层级（嵌套） 减少不必要的嵌套 ->> UI层级少 ->> 过度绘制的可能性低，
- 自定义控件View优化：使用 clipRect() 、quickReject() 给 Canvas 设置一个裁剪区域，只有在该区域内才会被绘制，区域之外的都不绘制

### 6.25.invalidate怎么局部刷新

如下图所示，这个方法已经在API21废弃了，官方说明，开启硬件加速后，不需要关注脏区域；在21以上版本invalidate(Rect)等效于invalidate()全局刷新，并且更推荐使用invalidate()；

![image-20220824112618123](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20220824112618123.png)

解决措施：

step1：开启硬件加速

step2：使用clipRect(Rect)方法设置局部绘制

```
//脏区域自己计算
RectF dirtyRect = new RectF(0,0,50,50);
@Override
protected void onDraw(Canvas canvas) {
   if (isTest) {
      canvas.save();
      canvas.clipRect(dirtyRect);
      canvas.drawRoundRect(new RectF(0, 0, getWidth(), getHeight()), radius, radius, mPaint);
      canvas.restore();
   }
}
```
上述代码在view中只刷新了50x50的区域，并没有整个view都绘制

### 6.26.View加载流程（setContentView）

**注意区分View的绘制流程 6.1**

https://blog.csdn.net/pgg_cold/article/details/79481301

https://www.jianshu.com/p/9850c5cbf242

![2828107-c5358ff314530322](https://raw.githubusercontent.com/treech/PicRemote/master/common/2828107-c5358ff314530322.png)

1.DecorView初始化
2.通过LayoutInflate对象去加载View，主要步骤是
（1）通过xml的Pull方式去解析xml布局文件，获取xml信息，并保存缓存信息
（2）根据xml的tag标签通过反射创建View逐层构建View
（3）递归构建其中的子View，并将子View添加到父ViewGroup中

## 7.View事件分发

### 7.1.View事件分发机制  

https://www.jianshu.com/p/555ffeb64e68

https://www.jianshu.com/p/e99b5e8bd67b

三个角色

1、Activity：只有分发dispatchTouchEvent和消费onTouchEvent两个方法。 事件由ViewRootImpl中DecorView dispatchTouchEvent分发Touch事件->Activity的dispatchTouchEvent()- DecorView。superDispatchTouchEvent->ViewGroup的dispatchTouchEvent()。 如果返回false直接调用onTouchEvent，true表示被消费
2、ViewGroup：拥有**分发**、**拦截**和**消费**三个方法。：对应一个根ViewGroup来说，点击事件产生后，首先会传递给它，dispatchTouchEvent就会被调用，如果这个ViewGroup的onInterceptTouchEvent方法返回true就表示它要拦截当前事件， 事件就会交给这个ViewGroup的onTouchEvent处理。如果这个ViewGroup的onInterceptTouchEvent
方法返回false就表示它不拦截当前事件，这时当前事件就会继续传递给它的子元素，接着子元素的dispatchTouchEvent方法就会被调用。
3、View：只有**分发**和**消费**两个方法。方法返回值为true表示当前视图可以处理对应的事件；返回值为false表示当前视图不处理这个事件，会被传递给父视图的

三个核心事件

1、dispatchTouchEvent()：方法返回值为true表示事件被当前视图消费掉； 返回为false表示 停止往子View传递和分发,交给父类的onTouchEvent处理
2、onInterceptTouchEvent() ： return false 表示不拦截，需要继续传递给子视图。return true 拦截这个事件并交由自身的onTouchEvent方法进行消费.
3、 onTouchEvent() ： return false是不消费事件，会被传递给父视图的onTouchEvent方法进行处理。return true是消费事件。 

**用伪代码表示ViewGroup的事件分发过程**

```
public boolean dispatchTouchEvent(MotionEvent ev) {
    boolean consume = false;
    if (onInterceptTouchEvent(ev)) {
        consume = onTouchEvent(ev);
    } else {
        consume = child.dispatchTouchEvent(ev);
    }
    return consume;
}
```

对于一个ViewGroup来说，点击事件产生后，首先会传递给它，这时她的dispatchTouchEvent会被调用，如果这个ViewGroup的onInterceptTouchEvent方法返回true表示它要拦截当前事件，接着事件就会交给这个ViewGroup处理，即它的onTouchEvent就会被调用；如果这个这个ViewGroup的onInterceptTouchEvent方法返回false就表示它不拦截当前事件，这时事件就会传递给子元素，接着子元素的dispatchTouchEvent方法就会被调用，如此反复直到事件最终被处理。 

理解二：

https://juejin.cn/post/6922300686638153736

核心的方法有三个：dispatchTouchEvent、onInterceptTouchEvent、onTouchEvent。

简单来说：dispatchTouchEvent是核心的分发方法，所有分发逻辑都在这个方法中执行；onInterceptTouchEvent在viewGroup负责判断是否拦截；onTouchEvent是消费事件的核心方法。viewGroup中拥有这三个方法，而view没有onInterceptTouchEvent方法。

- viewGroup
    1. viewGroup的dispatchTouchEvent方法接收到事件消息，首先会去调用onInterceptTouchEvent判断是否拦截事件
        - 如果拦截，则调用自身的onTouchEvent方法
        - 如果不拦截则调用子view的dispatchTouchEvent方法
    2. 子view没有消费事件，那么会调用viewGroup本身的onTouchEvent
    3. 上面1、2步的处理结果为viewGroup的dispatchTouchEvent方法的处理结果，没有消费则返回false并返回给上一层的onTouchEvent处理，如果消费则分发结束并返回true。
- view
    1. view的dispatchTouchEvent默认情况下会调用onTouchEvent来处理事件，返回true表示消费事件，返回false表示没有消费事件
    2. 第1步的结果就是dispatchTouchEvent方法的处理结果，成功消费则返回true，没有消费则返回false并交给上一层的onTouchEvent处理

简单来说，在控件树中，每个viewGroup在dispatchTouchEvent方法中不断往下分发寻找消费的view，如果底层的view没有消费事件则会一层层网上调用viewGroup的onTouchEvent方法来处理事件。

同时，由于Activity继承了Window.CallBack接口，所以也有dispatchTouchEvent和onTouchEvent方法：

1. activity接收到触摸事件之后，会直接把触摸事件分发给viewGroup
2. 如果viewGroup的dispatchTouchEvent方法返回false，那么会调用Activity的onTouchEvent来处理事件
3. 第1、2步的处理结果就是activity的dispatchTouchEvent方法的处理结果，并返回给上层

### 7.2.view的onTouchEvent，OnClickListerner和OnTouchListener的onTouch方法 三者优先级

dispatchTouchEvent->onTouch->onInterceptTouchEvent->onTouchEvent。

1. dispatchTouchEvent中限制性mOnTouchListener.onTouch() onTouchListener的onTouch方法优先级比onTouchEvent高，会先触发。 
2. 假如onTouch方法返回false会接着触发onTouchEvent，返回true,onTouchEvent
方法不会被调用。 
3. onClick事件是在onTouchEvent的MotionEvent.ACTION_UP事件通过performClick() 触发的。
OnTouchListener中onTouch方法如果返回true，则不会执行view的onTouchEvent方法，也就更不会执行view的onClickListener的onClick方法,返回false，则两个都会执行。

### 7.3.onTouch 和onTouchEvent 的区别

onTouch方法是View的 OnTouchListener借口中定义的方法。 当一个View绑定了OnTouchLister后，当有touch事件触发时，就会调用onTouch方法 onTouchEvent 处理点击事件在dispatchTouchEvent中调用
onTouchListener的onTouch方法优先级比onTouchEvent高，会先触发。 假如onTouch方法返回false，会接着触发onTouchEvent，反之onTouchEvent方法不会被调用。 内置诸如click事件的实现等等都基于onTouchEvent，假如onTouch返回true，这些事件将不会被触发

### 7.4.ACTION_CANCEL什么时候触发

2.1.如果在父View中拦截ACTION_UP或ACTION_MOVE，在第一次父视图拦截消息的瞬间，父视图指定子视图不接受后续消息了，同时子视图会收到ACTION_CANCEL事件。
2.如果触摸某个控件，但是又不是在这个控件的区域上抬起（移动到别的地方了），就会出现action_cancel

### 7.5.事件是先到DecorView还是先到Window

https://juejin.cn/post/6965484155660402702

DecorView -> Activity -> PhoneWindow -> DecorView

当屏幕被触摸input系统事件从Native层分发Framework层的InputEventReceiver.dispachInputEvent()调用了
ViewRootImpl.WindowInputEventReceiver.dispachInputEvent()->ViewRootImpl中的DecorView.dispachInputEvent()->Activity.dispachInputEvent()->
window.superDispatchTouchEvent()->DecorView.superDispatchTouchEvent()->
Viewgroup.superDispatchTouchEvent()

![_0_0_0](https://raw.githubusercontent.com/treech/PicRemote/master/common/_0_0_0.webp)

### 7.6.点击事件被拦截，但是想传到下面的View，如何操作

重写子类的requestDisallowInterceptTouchEvent()方法返回true就不会执行父类的onInterceptTouchEvent()，可将点击事件传到下面的View, 剥夺了父view 对除了ACTION_DOWN以外的事件的处理权

### 7.7.如何解决View的事件冲突

常见开发中事件冲突的有ScrollView与RecyclerView的滑动冲突、RecyclerView内嵌同时滑动同一方向滑动冲突的实现方法：

外部拦截法：指点击事件都先经过父容器的拦截处理，如果父容器需要此事件就拦截，否则就不拦截。具体方法：需要重写父容器的onInterceptTouchEvent方法，在内部做出相应的拦截。 

内部拦截法：指父容器不拦截任何事件，而将所有的事件都传递给子容器，如果子容器需要此事件就直接消耗，否则就交由父容器进行处理。具体方法：需要配合requestDisallowInterceptTouchEvent方法。

https://www.jianshu.com/p/982a83271327

外部拦截法：
父View在ACTION_MOVE中开始拦截事件，那么后续ACTION_UP也将默认交给父View处理！
内部拦截法：
即父View不拦截任何事件，所有事件都传递给子View，子View根据需要决定是自己消费事件还是给父View处理
如果父容器需要获取点击事件则调用parent.requestDisallowInterceptTouchEvent(false)方法，让父容器去拦截事件


### 7.8.在 ViewGroup 中的 onTouchEvent 中消费 ACTION_DOWN 事件，

ACTION_UP事件是怎么传递一个事件序列只能被一个View拦截且消耗。因为一旦一个元素拦截了此事件，那么同一个事件序列内的所有事件都
会直接交给它处理（即不会再调用这个View的拦截方法去询问它是否要拦截了，而是把剩余的ACTION_MOVE、ACTION_DOWN等事件直接交给它来处理）。
Activity.dispatchTouchEvent() -> ViewGroup1.dispatchTouchEvent() -> ViewGroup1.onInterceptTouchEvent() ->
view1.dispatchTouchEvent() -> view1.onTouchEvent() -> ViewGroup1.onTouchEvent()
-> Activity.dispatchTouchEvent() -> ViewGroup1.dispatchTouchEvent() -> ViewGroup1.onTouchEvent()

### 7.9.Activity ViewGroup和View都不消费ACTION_DOWN,那么ACTION_UP事件是怎么传递的

ACTION_DOWN:-> Activity.dispatchTouchEvent() -> ViewGroup1.dispatchTouchEvent() ->
ViewGroup1.onInterceptTouchEvent() -> view1.dispatchTouchEvent() -> view1.onTouchEvent() ->
ViewGroup1.onTouchEvent() -> Activity.onTouchEvent()

ACTION_MOVE:-> Activity.dispatchTouchEvent() ->
Activity.onTouchEvent(); -> 消费

### 7.10.同时对父 View 和子 View 设置点击方法，优先响应哪个

优先响应子 view，如果先响应父 view，那么子 view 将永远无法响应，父 view 要优先响应事件，必须先调用onInterceptTouchEvent 对事件进行拦截，那么事件不会再往下传递，直接交给父 view 的 onTouchEvent 处理。

### 7.11.requestDisallowInterceptTouchEvent的调用时机

事件分发例子
https://blog.csdn.net/lmj623565791/article/details/39102591

## RecycleView

### 8.1.RecyclerView的多级缓存机制,每一级缓存具体作用是什么,分别在什么场景下会用到哪些缓存

https://zhooker.github.io/2017/08/14/%E5%85%B3%E4%BA%8ERecyclerview%E7%9A%84%E7%BC%93%E5%AD%98%E6%9C%BA%E5%88%B6%E7%9A%84%E7%90%86%E8%A7%A3/

https://www.wanandroid.com/wenda/show/14222

https://blog.csdn.net/u013700502/article/details/105058771

https://juejin.cn/post/6854573221702795277#heading-9

Scrap、Cache、ViewCacheExtension 、RecycledViewPool
Scrap缓存用在RecyclerView布局时，布局完成之后就会清空
添加到Cache缓存和RecyclerViewPool缓存的item，他们的View必须已经从RecyclerView中detached或removed
一级缓存：mAttachedScrap 和 mChangedScrap 
二级缓存：mCachedViews 
三级缓存：ViewCacheExtension 
四级缓存：RecycledViewPool 然后说怎么用，就是先从 1 级找，然后 2 级...然后4 级，找不到 create ViewHolder。
https://www.jianshu.com/p/467ae8a7ca6e
mAttachedScrap/mChangedScrap
屏幕内缓存
RecyclerView 的滑动场景来说，新卡位的复用以及旧卡位的回收机制，不会涉及到mChangedScrap和mAttachedScrap
notifyItemChanged/rangeChange，此时如果Holder发生了改变那么就放入changeScrap中，反之放入到AttachScrap。

mCachedViews
当列表滑动出了屏幕时，ViewHolder会被缓存在 mCachedViews ，其大小由mViewCacheMax决定，默认DEFAULT_CACHE_SIZE为2，可通过Recyclerview.setItemViewCacheSize()动态设置。

ViewCacheExtension
可以自己实现ViewCacheExtension类实现自定义缓存，可通过Recyclerview.setViewCacheExtension()设置。

缓存池
ViewHolder在首先会缓存在 mCachedViews 中，当超过了个数（比如默认为2）， 就会添加到 RecycledViewPool中。RecycledViewPool 会根据每个ViewType把ViewHolder分别存储在不同的列表中，每个ViewType最多缓存DEFAULT_MAX_SCRAP = 5 个ViewHolder

### 8.2.RecyclerView的滑动回收复用机制

https://www.jianshu.com/p/467ae8a7ca6e

RecyclerView 滑动的场景触发的回收复用机制工作时， 并不需要四级缓存都参与的。
1.RecyclerView 向下滑动操作的日志，第三行5个卡位的显示都是重新创建的 ViewHolder
新一行5个卡位和复用不可能会用到刚移出屏幕的5个卡位， 因为先复用再回收，新一行的5个卡位先去目前的mCachedViews和ViewPool的缓存中寻找复用，没有就重新创建，然后移出屏幕的那行的5个卡位再回收缓存到mCachedViews 和 ViewPool 里面。
2.RecyclerView 再次向上滑动重新显示第一行的5个卡位时，只有后面3个卡位触发了 onBindViewHolder() 方法，重新绑定数据。
滑动场景下涉及到的回收和复用的结构体是 mCachedViews 和 ViewPool，前者默认大小为2，后者为5。所以，当第三行显示出来后，第一行的5个卡位被回收，回收时先缓存在 mCachedViews，满了再移出旧的到 ViewPool 里，所有5个卡位有2个缓存在 mCachedViews 里，3个缓存在 ViewPool，所以最新的两个卡位是0、1，会放在mCachedViews 里，而2、3、4的卡位则放在 ViewPool 里。
3.而至于为什么会创建了17个 ViewHolder，那是因为再第四行的卡位要显示出来时，ViewPool 里只有3个缓存，而第四行的卡位又用不了 mCachedViews 里的2个缓存，因为这两个缓存的是6、7卡位的 ViewHolder，所以就需要再重新创建2个 ViewHodler 来给第四行最后的两个卡位使用。

### 8.3.RecyclerView的刷新回收复用机制

notifyXxx后会RecyclerView会进行两次布局，一次预布局，一次实际布局，然后执行动画操作

dispatchLayoutStep1
查找改变holder，并保存在mChangedScrap中；其他未改变的保存到mAttachedScrap中 （mChangedScrap保存的holder信息只有预布局时才会被复用）

dispatchLayoutStep2
此步骤会创建一个新的holder并执行绑定数据，充当改变位置的holder，其他位置holder从mAttachedScrap中获取

### 8.4.RecyclerView 为什么要预布局

https://juejin.cn/post/6890288761783975950#heading-0

why
这种负责执行动画的View在原布局或新布局中不存在的动画，就是预测动画。
因为RecyclerView 要执行预测动画。比如有A,B,C三个itemView，其中A和B被加载到屏幕上，这时候删除B后，按照最终效果我们会看到C移动到B的位置；因为我们只知道 C 最终的位置，但是不知道 C 的起始位置在哪里(即C还未被加载)。
用户有 A、B、C 三个 item，A，B 刚好显示在屏幕中，这个时候，用户把 B 删除了，那么最终 C 会显示在 B 原来的位置
因为我们只知道 C 最终的位置，但是不知道 C 的起始位置在哪里，无法确定 C 应该从哪里滑动过来。
在其他 LayoutManager 中，它可能是从侧面或者是其他地方滑动过来的。

what
当 Adapter 发生变化的时候，RecyclerView 会让 LayoutManager 进行两次布局。
第一次，预布局,为动画前的表项先执行一次pre-layout，根据 Adapter 的 notify 信息，我们知道哪些 item 即将变化了,将不可见的表项 3 也加载到布局中，形成一张布局快照（1、2、3）。
第二次，实际布局，也就是变化完成之后的布局同样形成一张布局快照（1、3）。
这样只要比较前后布局的变化，就能得出应该执行什么动画了，就称为预测动画。

### 8.5.ListView 与 RecyclerView区别

1.布局效果
ListView 的布局比较单一，只有一个纵向效果； RecyclerView 的布局效果丰富， 可以在 LayoutMananger 中设置：线性布局（纵向，横向），表格布局，瀑布流布局
2.局部刷新
RecyclerView中可以实现局部刷新，例如：notifyItemChanged()；
如果要在ListView实现局部刷新，依然是可以实现的，当一个item数据刷新时，我们可以在Adapter中，实现一个notifyItemChanged()方法，在方法里面通过这个 item 的 position，刷新这个item的数据
3.缓存区别
ListView有两级缓存，在屏幕与非屏幕内。RecyclerView比ListView多两级缓存，ListView缓存View， RecyclerView缓存RecyclerView.ViewHolder。

### 8.6.RecyclerView性能优化
1.数据处理与视图加载分离
简单来说就是在onBindViewHolder()只设置UI显示，不做任何逻辑判断，需要的业务逻辑在得到javabean之前处理好.
2.布局优化
减少过渡绘制 减少布局层级
3.设置RecyclerView.addOnScrollListener()来在滑动过程中停止加载的操作。

## 9.Viewpager&Fragment

### 9.1.Fragment的生命周期 & 结合Activity的生命周期

https://juejin.cn/post/6844903752114126855#heading-0

### 9.2.Activity和Fragment的通信方式， Fragment之间如何进行通信

Activity和Fragment
1.采用Bundle的方式 在activity中建一个bundle，把要传的值存入bundle，然后通过fragment的setArguments（bundle）传到fragment，在fragment中，用getArguments接收。
2.采用接口回调的方式
3.EventBus的方式
4.viewModel 做数据管理，activity 和 fragment 公用同个viewModel 实现数据传递

Fragment之间
1.EventBus的方式
2.采用接口回调的方式
3.Fragment 通过 getActivity 获取到Activity，Activity通过findFragmentByTag||findFragmentById获取Fragment,Fragment 实现接口.

### 9.3.为什么使用Fragment.setArguments(Bundle)传递参数

https://www.jianshu.com/p/c06efe090589

Activity.onCreate(Bundle saveInstance)->Fragment.instantitate()
当再次重建时会通过空参构造方法反射出新的fragment。并且给mArguments初始化为原先的值，而原来的Fragment实例的数据都丢失了。
Activity重新创建时，会重新构建它所管理的Fragment，原先的Fragment的字段值将会全部丢失，但是通过Fragment.setArguments(Bundle bundle)方法设置的bundle会保留下来，并在重建时恢复。所以，尽量使用Fragment.setArguments(Bundle bundle)方式来进行参数传递。

### 9.4.FragmentPageAdapter和FragmentStatePageAdapter区别及使用场景

使用FragmentPagerAdapter时 页面切换，只是调用detach，而不是remove，所以只执行onDestroyView，而不是onDestroy，不会摧毁Fragment实例，只会摧毁Fragment 的View；
使用FragmentStatePageAdapter时 页面切换，调用remove，执行onDestroy。直接摧毁Fragment。
FragmentPagerAdapter最好用在少数静态Fragments的场景，用户访问过的Fragment都会缓存在内存中，即使其视图层次不可见而被释放(onDestroyView) 。因为Fragment可能保存大量状态，因此这可能会导致使用大量内存。
页面很多时，可以考虑FragmentStatePagerAdapter

### 9.5.fragment懒加载

判断当前 Fragment 是否对用户可见，只是 onHiddenChanged() 是在 add+show+hide 模式下使用，
setUserVisibleHint 是在 ViewPager+Fragment 模式下使用。
https://juejin.cn/post/6844904050698223624#heading-0
https://www.jianshu.com/p/bef74a4b6d5e

**老的懒加载处理方案**
对 ViewPager 中的 Fragment 懒加载
方法1： 继承模式
通过继承懒加载Fragment基类，在setUserVisibleHint中判断可见并且 当onViewCreated()表明View已经加载完毕后再调用加载方法。
方法2:代理+反射模式
1.adapter中getitem时new一个代理fragment
2.setUserVisibleHint中根据反射得到真正的fragement
3.通过add commit把真正的fragement添加到代理fragment中
方法1：不可见的 Fragment 执行了 onResume() 方法。因为setUserVisibleHint位于onCreateView之前,此时为false，onResume之后为true，在true后加载相当于onResume()等方法在真实的createView之前调用，不可见的Fragment 执行了 onResume() 方法。

**Androidx 下的懒加载**
在 FragmentPagerAdapter 与 FragmentStatePagerAdapter 新增了含有 behavior 字段的构造函数
如果 behavior 的值为 BEHAVIOR_RESUME_ONLY_CURRENT_FRAGMENT ，那么当前选中的 Fragment 在Lifecycle.State#RESUMED 状态 ，其他不可见的 Fragment 会被限制在 Lifecycle.State#STARTED 状态
原因:FragmentPagerAdapter 在其 setPrimaryItem 方法中调用了 setMaxLifecycle, 所以说onResume中执行懒加载。

### 9.6.ViewPager2与ViewPager区别

https://juejin.cn/post/6844904020553760782#heading-0

2. 1. FragmentStateAdapter 替代FragmentStatePagerAdapter，PagerAdapter被RecyclerView.Adapter替代
2. 支持竖直滑动，禁止滑动
3. PageTransformer用来设置页面动画，设置页面间距
4. 预加载当setOffscreenPageLimit被设置为OFFSCREEN_PAGE_LIMIT_DEFAULT时候会使用RecyclerView的缓存机制。

## 10.WebView

10.1.如何提高WebView加载速度
https://tech.meituan.com/2017/06/09/webviewperf.html
WebView启动过程大概分为以下几个阶段：

![9a2f8beb](https://raw.githubusercontent.com/treech/PicRemote/master/common/9a2f8beb.png)

App中打开WebView的第一步并不是建立连接，而是启动浏览器内核。
1. 优化手段围绕着以下两个点进行
预加载WebView。
加载WebView的同时，请求H5页面数据
2. 常见的方法是
**全局WebView**
在客户端刚启动时，就初始化一个全局的WebView待用，并隐藏；
这种方法可以比较有效的减少WebView在App中的首次打开时间。当用户访问页面时，不需要初始化WebView的时间。
当然这也带来了一些问题，包括：
额外的内存消耗。
页面间跳转需要清空上一个页面的痕迹，更容易内存泄露。
**客户端代理页面请求WebView初始化完成后向客户端请求数据**
在客户端初始化WebView的同时，直接由native开始网络请求数据；
当页面初始化完成后，向native获取其代理请求的数据。
**asset存放离线包**
3. 除此之外还有一些其他的优化手段：
**DNS和链接慢**
想办法复用客户端使用的域名和链接，可以让客户端复用使用的域名与链接。
DNS采用和客户端API相同的域名
DNS会在系统级别进行缓存，对于WebView的地址，如果使用的域名与native的API相同，则可以直接使用缓存的DNS而不用再发起请求图片。
**脚本执行慢**
可以把框架代码拆分出来，在请求页面之前就执行好。
**后端处理慢**
可以让服务器分trunk输出，在后端计算的同时前端也加载网络静态资源。

### 10.2.WebView与 js的交互

https://blog.csdn.net/carson_ho/article/details/64904691

**Android去调用JS的代码**
1.通过WebView的loadUrl（）
2.通过WebView的evaluateJavascript（）

**JS调用Android代码的方法**
1.通过WebView的addJavascriptInterface（）进行对象映射
2.通过 WebViewClient 的shouldOverrideUrlLoading ()方法回调拦截 url
3.Android通过 WebChromeClient 的onJsAlert()、onJsConfirm()、onJsPrompt（方法回调分别拦截JS对话框（即上述三个方法），得到他们的消息内容，然后解析即可。

### 10.3.WebView的漏洞

https://blog.csdn.net/carson_ho/article/details/64904635

**任意代码执行漏洞**
JS调用Android的可以通过addJavascriptInterface接口进行对象映射
当JS拿到Android这个对象后，就可以调用这个Android对象中所有的方法，包括系统类（java.lang.Runtime 类），从而进行任意代码执行。
java.lang.Runtime 类，可以执行本地命令
解决
对于Android 4.2以前，需要采用拦截prompt（）的方式进行漏洞修复
原理
每次当 WebView 加载页面前加载一段本地的 JS 代码，
让JS调用一Javascript方法：该方法是通过调用prompt（）把JS中的信息（含特定标识，方法名称等）传递到Android端；
在Android的onJsPrompt（）中 ，解析传递过来的信息，再通过反射机制调用Java对象的方法，这样实现安全的JS调用Android代码。
对于Android 4.2以后，则只需要对被调用的函数以 @JavascriptInterface进行注解

**密码明文存储漏洞**
WebView默认开启密码保存功能
原因 WebView默认开启密码保存功能：mWebView.setSavePassword(true) 开启后，在用户输入密码时，会弹出提示框：询问用户是否保存密码； 如果选择”是”，密码会被明文保到
/data/data/com.package.name/databases/webview.db 中，这样就有被盗取密码的危险 解决 关闭密码保存提醒：
WebSettings.setSavePassword(false)

**域控制不严格漏洞**
当其他应用启动可以允许外部调用的Activity 时， intent 中的 data 直接被当作 url 来加载（假定传进来的 url 为file:///data/local/tmp/attack.html ），其他 APP 通过使用显式 ComponentName 或者其他类似方式就可以很轻松的启动该 WebViewActivity 并加载恶意url。
对于不需要使用 file 协议的应用，禁用 file 协议； // 禁用 file 协议； setAllowFileAccess(false);
setAllowFileAccessFromFileURLs(false); setAllowUniversalAccessFromFileURLs(false);
对于需要使用 file 协议的应用，禁止 file 协议加载 JavaScript。

### 10.4.JsBridge原理

https://juejin.cn/post/6844903585268891662#heading-0

https://www.jianshu.com/p/910e058a1d63

**优点**
1.JavaScript 端可以确定 JSBridge 的存在，直接调用即可
2.H5同时适配Android和iOS两个平台
3.java与js的交互存在一些安全漏洞

**原理**
JavaScript 调用 Native 注入 API 和 拦截 URL SCHEME。

1.注入API
在 4.2 之前，Android 注入 JavaScript 对象的接口是 addJavascriptInterface，但是这个接口有漏洞，可以被不法分子利用，危害用户的安全，因此在 4.2 中引入新的接口 @JavascriptInterface（上面代码中使用的）来替代这个接口，解决安全问题。所以 Android 注入对对象的方式是有兼容性问题的。

2.拦截 URL SCHEME
mWebView.registerHandler("startload", (data, function) -> { function.onCallBack("aaaaa");});
1. 初始化webview时,将WebViewJavascriptBridge.js文件注入页面。向body中添加一个不可见的iframe元素。通过改变一个不可见的iframe的src就可以让webview拦截到url，而用户是无感知的。
2. Web 端通过某种方式（例如 iframe.src）发送 URL Scheme 请求，通过shouldOverrideUrlLoading来拦截约定规则的Url

3.Native 调用 JavaScript
mWebView.callHandler("test", mJson, data -> LogUtil.d(回调:" + data));
webView.loadUrl("javascript:" + javaScriptString);
dosend发送消息时,带上callId，如果Js在调用Handler的时候设置了回调方法，会调用queueMessage的方法，然后往下就是走Native给Js发送消息的步骤。

## 11.动画

https://blog.csdn.net/carson_ho/article/details/79860980

https://anriku.top/2018/09/01/Android%E5%B1%9E%E6%80%A7%E5%8A%A8%E7%94%BB%E6%8E%A2%E7%B4%A2/

https://blog.csdn.net/carson_ho/article/details/72827747

https://juejin.cn/post/6846687601118691341#heading-12

### 11.1.动画的类型

#### 11.1.1.视图动画

https://blog.csdn.net/carson_ho/article/details/72827747

```xml
// 以下参数是4种动画效果的公共属性,即都有的属性
android:duration = "3000" // 动画持续时间（ms），必须设置，动画才有效果 
android:startOffset ="1000" // 动画延迟开始时间（ms） 
android:fillBefore = “true” // 动画播放完后，视图是否会停留在动画开始的状态，默认为true
android:fillAfter = “false” // 动画播放完后，视图是否会停留在动画结束的状态，优先于fillBefore值，默认为false
android:fillEnabled = “true” // 是否应用fillBefore值，对fillAfter值无影响，默认为true 
android:repeatMode = “restart” // 选择重复播放动画模式，restart代表正序重放，reverse代表倒序回放，默认为restart|
android:repeatCount = “0” // 重放次数（所以动画的播放次数=重放次数+1），为infinite时无限重复
android:interpolator = @nim/interpolator_resource // 插值器，即影响动画的播放速度,下面会详细讲
```

#### 11.1.2.逐帧动画

https://blog.csdn.net/carson_ho/article/details/73087488

按序播放一组预先定义好的图片
xml:animation-list
// item = 动画图片资源；

duration = 设置一帧持续时间(ms)

#### 11.1.3.补间动画

平移动画（Translate） 
```xml
// 1. fromXDelta ：视图在水平方向x 移动的起始值 
// 2. toXDelta ：视图在水平方向x 移动的结束值
// 3. fromYDelta ：视图在竖直方向y 移动的起始值 
// 4. toYDelta：视图在竖直方向y 移动的结束值 缩放动画（scale） 
android:fromXScale="0.0" // 动画在水平方向X的起始缩放倍数 0.0表示收缩到没有；1.0表示正常无伸缩 值小于1.0表示收缩；值大于1.0表示放大 
android:toXScale="2" //动画在水平方向X的结束缩放倍数
android:fromYScale="0.0" //动画开始前在竖直方向Y的起始缩放倍数 
android:toYScale="2" //动画在竖直方向Y的结束缩放倍数 
android:pivotX="50%" // 缩放轴点的x坐标 
android:pivotY="50%" // 缩放轴点的y坐标 旋转动画（rotate） 
android:fromDegrees="0" // 动画开始时 视图的旋转角度(正数 = 顺时针，负数 = 逆时针)
android:toDegrees="270" // 动画结束时 视图的旋转角度(正数 = 顺时针，负数 = 逆时针) 
android:pivotX="50%" //旋转轴点的x坐标 
android:pivotY="0" // 旋转轴点的y坐标 透明度动画（alpha） 
android:fromAlpha="1.0" // 动画开始时视图的透明度(取值范围: -1 ~ 1) 
android:toAlpha="0.0"// 动画结束时视图的透明度(取值范围: -1 ~ 1) 
```

#### 11.1.4.属性动画

顾名思义，通过控制对象的属性，来实现动画效果。官方定义：定义一个随着时间 （注：停个顿）更改任何对象属性的动画，无论其是否绘制到屏幕上

https://www.jianshu.com/p/821ef6d1e1c9

属性说明:
```
Duration：定义动画时长，默认是300 ms。
Time interpolation: 时间插值器，它可以指定属性值如何随时间变化的，反应了动画的运动速率。
Repeat count and behavior: 指定当动画结束时是否重复动画以及动画重复多少次，还可以设置反向播放动画，播放到达指定次数后动画结束。
Animator sets：把一组动画聚在一起，顺序播放或者同时播放或者延迟播放。
Frame refresh delay：指定刷新动画帧的频率，默认时间是10ms，但是刷新频率最终取决于系统是否繁忙以及系统服务底层计时器的快慢。
```

### 11.2. 补间动画和属性动画的区别

a. 作用对象局限：View
补间动画 只能够作用在视图View上，即只可以对一个Button、TextView、甚至是LinearLayout、或者其它继承自View的组件进行动画操作，但无法对非View的对象进行动画操。
有些情况下的动画效果只是视图的某个属性 & 对象而不是整个视图； 如，现需要实现视图的颜色动态变化，那么就需要操作视图的颜色属性从而实现动画效果，而不是针对整个视图进行动画操作
b. 没有改变View的属性，只是改变视觉效果
补间动画只是改变了View的视觉效果，而不会真正去改变View的属性。
如，将屏幕左上角的按钮 通过补间动画 移动到屏幕的右下角
点击当前按钮位置（屏幕右下角）是没有效果的，因为实际上按钮还是停留在屏幕左上角，补间动画只是将这个按钮绘制到屏幕右下角，改变了视觉效果而已。
c. 动画效果单一
补间动画只能实现平移、旋转、缩放 & 透明度这些简单的动画需求

### 11.3. ObjectAnimator，ValueAnimator及其区别
**ObjectAnimator**
位移

```
val objectAnimation =ObjectAnimator.ofFloat(llAddAccount, "translationX", 0f, -70f) 
```
第三参数为可变长参数，第一个值为动画开始的位置，第二个值为结束值得位置，如果数组大于3位数，那么前者将是后者的起始位置

旋转
```
val objectAnimation = ObjectAnimator.ofFloat(tvText, "rotation", 0f,180f,0f)
```

缩放
ofFloat()方法传入参数属性为scaleX和scaleY时，动态参数表示缩放的倍数透明 
```
val objectAnimation = ObjectAnimator.ofFloat(tvText, "alpha", 1f,0f,1f)
```

**ValueAnimator**

```
val valueAnimator = ValueAnimator.ofFloat(0f, 180f) valueAnimator.addUpdateListener { 	      	 				tvText.rotationY = it.animatedValue as Float //手动赋值
} 
valueAnimator.start()
```

等价于

```
ObjectAnimator.ofFloat(tvText, "rotationY", 0f, 180f).apply { start() }
```

ValueAnimator作为ObjectAnimator的父类，主要动态计算目标对象属性的值，然后设置给对象属性，达到动画效果
使用ValueAnimator实现动画，需要手动赋值给目标对象tvText的rotationY，而ObjectAnimator则是自动赋值，不需要手动赋值就可以达到效果

ObjectAnimator和ValueAnimator区别
其实二者都是属于属性动画，本质上是一样的，都是先改变值，然后赋值给对象属性，从而实现动画操作。
但二者区别就在与，ValueAnimator类是 手动 赋值给对象的属性，从而实现动画
而ObjectAnimator类，是 自动 赋值给对象的属性，从AnimatorSet
一个动画结束后播放另外一个动画，或者同时播放

```
val aAnimator = ObjectAnimator.ofInt(1) 
val bAnimator = ObjectAnimator.ofInt(1) 
val cAnimator = ObjectAnimator.ofInt(1) 
val dAnimator = ObjectAnimator.ofInt(1)
AnimatorSet().apply { 
    play(aAnimator).before(bAnimator)//a在b之前播放 
    play(bAnimator).with(cAnimator)// b和c同时播放动画效果 
    play(dAnimator).after(cAnimator)//d在c播放结束之后播放 
    start()
}
```

### 11.4. TimeInterpolator插值器，自定义插值器

TimeInterpolator
它的作用是根据时间流逝的百分比来计算出当前属性值改变的百分比
插值器 ，Interpolator负责控制动画变化的速率，使得基本的动画效果能够以匀速、加速、减速、抛物线速率等各种速率变化

匀速插值器 https://blog.csdn.net/qinxiandiqi/article/details/51719926 图1假设了一个对象需要对它的x属性设定动画，这个x属性代表这个对象在屏幕上面的横坐标。这个动画的时间设定为40毫秒，以及需要移动的距离是40个像素。每过10毫秒（默认的帧频率），这个对象就会在水平方向上移动10个像素。等到40毫秒之后，这个动画停止，
对象在水平方向上总共移动了40个像素。这个例子中的动画使用了一个线性插值器，意味着这个对象以匀速移动。
例子: http://static.kancloud.cn/alex_wsc/android_art/1828610 当时间t=20ms的时候，时间流逝的百分比是0.5（20/40=0.5）意味着现在时间过了一半，那x应该改变多少呢这个就由插值器和估值算法来确定
拿线性插值器来说，当时间流逝一半的时候，x的变换也应该是一半，即x的改变是0.5，为什么呢？因为它是线性插值器，是实现匀速动画的
估值器evaluate的三个参数分别表示估值小数、开始值和结束值，对应于我们的例子就分别是0.5、0、40。根据上述算法，整型估值返回给我们的结果是20，这就是（x=20, t=20ms）的由来。
系统已有的插值器： 

1. LinearInterpolator（线性插值器）：匀速动画。 
2. AccelerateDecelerateInterpolator（加速减速插值器）：动画两头慢，中间快。 
3. DecelerateInterpolator（减速插值器）：动画越来越慢。

自定义插值器
写一个自定义Interpolator：先减速后加速

```java
public class DecelerateAccelerateInterpolator implements TimeInterpolator {
	@Override
	public float getInterpolation(float input) {
        float result;
        if (input <= 0.5) {
            result = (float) (Math.sin(Math.PI * input)) / 2;
            // 使用正弦函数来实现先减速后加速的功能，逻辑如下：
            // 因为正弦函数初始弧度变化值非常大，刚好和余弦函数是相反的
            // 随着弧度的增加，正弦函数的变化值也会逐渐变小，这样也就实现了减速的效果。
            // 当弧度大于π/2之后，整个过程相反了过来，现在正弦函数的弧度变化值非常小，渐渐随着弧度继续增加，变化
            值越来越大，弧度到π时结束，这样从0过度到π，也就实现了先减速后加速的效果
        } else {
            result = (float) (2 - Math.sin(Math.PI * input)) / 2;
        } 
        return result;// 返回的result值 = 随着动画进度呈先减速后加速的变化趋势
	}
}
```

https://blog.csdn.net/carson_ho/article/details/72863901  

### 11.5. TypeEvaluator估值器
TypeEvaluator
估值器 据当前属性改变的百分比来计算改变后的属性值

1. IntEvaluator：针对整型属性 

2. FloatEvaluator：针对浮点型属性 

3. ArgbEvaluator：针对Color属性

```java
// FloatEvaluator实现了TypeEvaluator接口
public class FloatEvaluator implements TypeEvaluator {
    // 重写evaluate() 
    public Object evaluate(float fraction, Object startValue, Object endValue) {
    	// 参数说明 fraction：表示动画完成度（根据它来计算当前动画的值） startValue、endValue：动画的初始值和结束值 	
        float startFloat = ((Number) startValue).floatValue();
        return startFloat + fraction * (((Number) endValue).floatValue() - startFloat);
        // 初始值 过渡 到结束值 的算法是：
        // 1. 用结束值减去初始值，算出它们之间的差值
        // 2. 用上述差值乘以fraction系数
        // 3. 再加上初始值，就得到当前动画的值
    }
}
```

示例：
实现的动画效果：一个圆从一个点 移动到 另外一个点
https://blog.csdn.net/carson_ho/article/details/72863901
1.onDraw画圆canvas.drawCircle(x, y, RADIUS, mPaint)
2.创建动画对象 & 设置初始值和结束值

```java
ValueAnimator anim = ValueAnimator.ofObject(new PointEvaluator(),startPoint, endPoint);
```
3.自定义PointEvaluator,evaluate根据插值器的速率计算出Point 的x,y 
4.通过值的更新监听器，将改变的对象手动赋值给当前对象
5.每次赋值后就重新绘制，从而实现动画效果

## 12.Bitmap

### 12.1.Bitmap 内存占用的计算

占用的内存大小 = 像素总数量（图片宽x高）x 每个像素的字节大小
每个像素的字节大小与Bitmap的色彩模式有关
public static final Bitmap.Config ALPHA_8 //代表8位Alpha位图 每个像素占用1byte内存
public static final Bitmap.Config ARGB_4444 //代表16位ARGB位图 每个像素占用2byte内存
public static final Bitmap.Config ARGB_8888 //代表32位ARGB位图 每个像素占用4byte内存（A=8，R=8，G=8，B=8）
public static final Bitmap.Config RGB_565 //代表8位RGB位图 每个像素占用2byte内存（没有透明度，R=5，G=6，B=5）
假设这张图片是ARGB_8888，那这张图片占的内存就是 width * height * 4个字节或者 width * height * inTargetDensity /inDensity * 4

**加载一张本地Res、Raw资源图片，得到的是图片的原始尺寸 * 缩放系数(inDensity)**
inTargetDensity 为当前屏幕像素密度(宽平方+高平方)/尺寸。
inDensity默认为图片所在文件夹对应的密度()
densityDpi 160 240 320 480 640
资源目录dpi mdpi hdpi xhdpi xxhdpi xxxhdpi；
像素密度 5.0英寸的手机的屏幕分辨率为1280x720，那么像素密度为192dpi
占用的内存 = width * height * targetDensity/inDensity * 一个像素所占的内存

**读取SD卡上的图,得到的是图片的原始尺寸**

### 12.2.getByteCount() & getAllocationByteCount()的区别

如果被复用的Bitmap的内存比待分配内存的Bitmap大
getByteCount()获取到的是当前图片应当所占内存大小
getAllocationByteCount()获取到的是被复用Bitmap真实占用内存大小
在复用Bitmap的情况下，getAllocationByteCount()可能会比getByteCount()大。

### 12.3.Bitmap的压缩方式

质量压缩，不会对内存产生影响；
采样率压缩，比例压缩，会对内存产生影响；

**质量压缩**
不会减少图片的像素，它是在保持像素的前提下改变图片的位深及透明度等
图片的长，宽，像素都不变，那么bitmap所占内存大小是不会变的

```java
ByteArrayOutputStream baos = new ByteArrayOutputStream();
src.compress(Bitmap.CompressFormat.JPEG, quality, baos);
byte[] bytes = baos.toByteArray();
Bitmap mBitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.length);
```

**RGB_565法**
改变一个像素所占的内存

```java
BitmapFactory.Options options2 = new BitmapFactory.Options();
options2.inPreferredConfig = Bitmap.Config.RGB_565;
bm = BitmapFactory.decodeFile(Environment .getExternalStorageDirectory().getAbsolutePath()
+ "/DCIM/Camera/test.jpg", options2);
```

**采样率压缩**
设置inSampleSize的值(int类型)后，假如设为n，则宽和高都为原来的1/n，宽高都减少，内存降低

```java
BitmapFactory.Options options = new BitmapFactory.Options();
options.inSampleSize = 2;
bm = BitmapFactory.decodeFile(Environment.getExternalStorageDirectory().getAbsolutePath()+
"/DCIM/Camera/test.jpg", options);
```

**比例压缩**
根据图片的缩放比例进行等比大小的缩小尺寸，从而达到压缩的效果
压缩的图片文件尺寸变小，但是解码成bitmap后占得内存变小
Android中使用Matrix对图像进行缩放、旋转、平移、斜切等变换的。

```java
Matrix matrix = new Matrix();
matrix.setScale(0.5f, 0.5f);
bm = Bitmap.createBitmap(bit, 0, 0, bit.getWidth(),bit.getHeight(), matrix, true); 
```

### 12.4.LruCache & DiskLruCache原理

LRU（Least Recently Used）
https://blog.csdn.net/u010983881/article/details/79050209
**LruCache的核心思想就是维护一个缓存对象列表，从表尾访问数据，在表头删除数据。对象列表的排列方式是按照访问顺序实现，就是当访问的数据项在链表中存在时，则将该数据项移动到表尾，否则在表尾新建一个数据项。当链表容量超过一定阈值，则移除表头的数据。**

利用LinkedHashMap数组+双向链表的数据结构来实现的。其中双向链表的结构可以实现访问顺序和插入顺序，使得LinkedHashMap中的accessOrder设置为true则为访问顺序，为false，则为插入顺序。
写入缓存

1. 插入元素，并相应增加当前缓存的容量。
2. 调用trimToSize()开启一个死循环，不断的从表头删除元素，直到当前缓存的容量小于最大容量为止。

读取缓存
调用LinkedHashMap的get()方法，注意如果该元素存在，这个方法会将该元素移动到表尾.  
**DiskLruCache**
https://juejin.cn/post/6844903556705681421#heading-6
https://nich.work/2017/DiskLruCache/
https://www.jianshu.com/p/400bda3e37ed
利用 LinkedHashMap实现算法LRU
DiskLruCache 有三个内部类，分别为 Entry、Snapshot 和 Editor。
Entry是 DiskLruCache 内 LinkedHashMap Value 的基本结构。
**Journal 文件**
DiskLruCache 通过在磁盘中创建并维护一个简单的Journal文件来记录各种缓存操作，。记录的类型有4种，分别为READ、REMOVE、CLEAN和DIRTY。
写入缓存的时候会向journal文件写入一条以DIRTY开头的数据表示正在进行写操作，当写入完毕时，分两种情况：
1、写入成功，会向journal文件写入一条以CLEAN开头的文件，其中包括该文件的大小。 2、写入失败，会向journal
文件写入一条以REMOVE开头的文件,表示删除了该条缓存。也就是说每次写入缓存总是写入两条操作记录。
读取的时候，会向journal文件写入一条以READ开头的文件,表示进行了读操作
删除的时候，会向journal文件写入一条以REMOVE开头的文件,表示删除了该条缓存
通过journal就记录了所有对缓存的操作。并且按照从上到下的读取顺序记录了对所有缓存的操作频繁度和时间顺序。这样当退出程序再次进来调用缓存时，就可以读取这个文件来知道哪些缓存用的比较频繁了。然后把这些操作记录读取到集合中，操作的时候就可以直接从集合中去对应的数据了。
在缓存记录之外，Journal 文件在初始化创建的时候还有一些固定的头部信息，包括了文件名、版本号和valueCount(决定每一个 key 能匹配的 Entry 数量)。
**读取**
Snapshot是Entry的快照(snapshot)。当调用 diskLruCache.get(key)时，便能获得一个Snapshot对象，该对象可用于获取或更新存于磁盘的缓存

```java
String key = Util.hashKeyForDisk(Util.IMG_URL);
DiskLruCache.Snapshot snapshot = diskLruCache.get(key);
if (snapshot != null) {
    InputStream in = snapshot.getInputStream(0);
    return BitmapFactory.decodeStream(in);
}
```

1. 获取到缓存文件的输入流，等待被读取。
2. 向journal写入一行READ开头的记录，表示执行了一次读取操作。
3. 如果缓存总大小已经超过了设定的最大缓存大小或者操作次数超过了2000次，就开一个线程将集合中的数据删除到小于最大缓存大小为止并重新写journal文件。
4. 返回缓存文件快照，包含缓存文件大小，输入流等信息。

**写入**

```java
DiskLruCache.Editor editor = diskLruCache.edit(key);
if (editor != null) {
    OutputStream outputStream = editor.newOutputStream(0);
    if (downloadUrlToStream(Util.IMG_URL, outputStream)) {
        publishProgress("");
        //写入缓存
        editor.commit();
    } else {
        //写入失败
        editor.abort();
    }
}
diskLruCache.flush();
```

1. 从集合中找到对应的实例（如果没有创建一个放到集合中），然后创建一个editor，将editor和entry关联起来。
2. 向journal中写入一行操作数据（DITTY 空格 和key拼接的文字），表示这个key当前正处于编辑状态。

newOutputStream

1. 向journal文件写入一行CLEAN开头的字符（包括key和文件的大小，文件大小可能存在多个 使用空格分开的）
2. 重新比较当前缓存和最大缓存的大小，如果超过最大缓存或者journal文件的操作大于2000条，就把集合中的缓存删除一部分，直到小于最大缓存，重新建立新的journal文件  

### 12.5.如何设计一个图片加载库

https://juejin.cn/post/6844904099297624077#heading-0

1. 对图片进行内存压缩；
2. 高分辨率的图片放入对应文件夹；
3. 缓存
4. 及时回收

### 12.6.有一张非常大的图片,如何去加载这张大图片
### 12.7.如果把drawable-xxhdpi下的图片移动到drawable-xhdpi下，图片内存是如何变的。
验证 原图：1000宽X447高，位于drawable-xxhdpi（480dpi）文件包，设备Pixel-XL（560dpi）。使用默认
Bitmap.Config=ARGB_8888,设置inSampleSize=2

> 缩放比=主动设置×被动设置=1/2×(560/480)=0.5×1.166=0.5833
> 一个像素所占的内存=ARGB_8888=32bit=4byte
> 原始大小=1000×447
> width * height * *
> 内存占用=(原始宽×缩放比)×(原始高×缩放比)×targetDensity/inDensity×一个像素所占的内存
> =1000×0.5833×447×0.5833×4 =583×260×4 =606320byte ≈0.578MB

### 12.8.如果在hdpi、xxhdpi下放置了图片，加载的优先级。如果是400\*800，1080*1920，加载的优先级。

https://cloud.tencent.com/developer/article/1015960

优先会去更高密度的文件夹下找这张图片，我们当前的场景就是drawable-xxxhdpi文件夹，然后发现这里也没有android_logo这张图，接下来会尝试再找更高密度的文件夹，发现没有更高密度的了，这个时候会去drawablenodpi文件夹找这张图，发现也没有，那么就会去更低密度的文件夹下面找，依次是drawable-xhdpi -> drawablehdpi -> drawable-mdpi -> drawable-ldp

0dpi ~ 120dpi ldpi
120dpi ~ 160dpi mdpi
160dpi ~ 240dpi hdpi
240dpi ~ 320dpi xhdpi
320dpi ~ 480dpi xxhdpi
480dpi ~ 640dpi xxxhdp  

## 13.mvc&mvp&mvvm

### 13.1.MVC及其优缺点

原理
视图层(View)
一般采用XML文件进行界面的描述，这些XML可以理解为AndroidApp的View。
控制层(Controller)
Android的控制层的重任通常落在了众多的Activity的肩上。
模型层(Model)
我们针对业务模型，建立的数据结构和相关的类，就可以理解为AndroidApp的Model，Model是与View无关，而与业务相关的。对数据库的操作、对网络等的操作都应该在Model里面处理，当然对业务计算等操作也是必须放在的该层的。
缺点
随着界面及其逻辑的复杂度不断提升，Activity类的职责不断增加，以致变得庞大臃肿。

### 13.2.MVP及其优缺点

原理
MVP框架由3部分组成：View负责显示，Presenter负责逻辑处理，Model提供数据。
View: 显示数据, 并向Presenter报告用户行为。与用户进行交互(在Android中体现为Activity)。
Presenter: 逻辑处理，从Model拿数据，回显到UI层，响应用户的行为。
Model:负责存储、检索、操纵数据(有时也实现一个Model interface用来降低耦合)。
google todo-mvp加入契约类来统一管理view与presenter的所有的接口，这种方式使得view与presenter中有哪些功能，一目了然
优点
1.分离视图逻辑和业务逻辑，降低了耦合，修改视图而不影响模型，不需要改变Presenter的逻辑 模型与视图完全分离，我们可以修改视图而不影响模型；
2.视图逻辑和业务逻辑分别抽象到了View和Presenter的接口中，Activity只负责显示，代码变得更加简洁，提高代码的阅读性。
3.Presenter被抽象成接口，可以有多种具体的实现，所以方便进行单元测试。
Presenter是通过interface与View(Activity)进行交互的，这说明我们可以通过自定义类实现这个interface来模拟Activity的行为对Presenter进行单元测试，省去了大量的部署及测试的时间（不需要将应用部署到Android模拟器或真机上，然后通过模拟用 户操作进行测试）
缺点
1.那就是对 UI 的操作必须在 Activity 与 Fragment 的生命周期之内，更细致一点，最好在 onStart() 之后 onPause()之前，否则极其容易出现各种异常，内存泄漏。
2.Presenter与View之间的耦合度高，app中很多界面都使用了同一个Presenter 。一旦需要变更，那么视图需要变更了。

**MVP如何设计避免内存泄漏?**
Mvp模式在封装的时候会造成内存泄漏，因为presenter层，需要做网络请求，所以就需要考虑到网络请求的取消操作，如果不处理，activity销毁了，presenter层还在请求网络，就会造成内存泄漏。 如何解决Mvp模式造成的内存泄漏？ 只要presenter层能感知activity生命周期的变化，在activity销毁的时候，取消网络请求，就能解决这个问题。 下面开始封装activity和presenter。
定义IPresenter 声明activity（Fragment）生命周期中的各个回调方法

```java
<U extends IUI> void init(BaseActivity activity, U ui);
/**
* onUICreate:UI被创建的时候应该invoke这个method.
* 
* 比如Activity的onCreate()、Fragment的onCreateView()的方法应该调用Presenter的这个方法
* @param savedInstanceState 保存了的状态
*/
void onUICreate(Bundle savedInstanceState);
/**
* onUIStart:在UI被创建和被显示到屏幕之间应该回调这个方法.
* 
* 比如Activity的onStart()方法应该调用Presenter的这个方法
*/
void onUIStart();
/**
* onUIResume:在UI被显示到屏幕的时候应该回调这个方法. 
* 
* 比如Activity的onResume()方法应该调用Presenter的这个方法
*/
void onUIResume();
/**
* onUIPause:在UI从屏幕上消失的时候应该回调这个方法. 
* 
* 比如Activity的onPause()方法应该调用Presenter的这个方法
*/
void onUIPause();
/**
* onUIStop:在UI从屏幕完全隐藏应该回调这个方法. 
* 
* 比如Activity的onStop()方法应该调用Presenter的这个方法
*/
void onUIStop();
/**
* onUIDestroy:当UI被Destory的时候应该回调这个方法. 
*/
void onUIDestroy();
/**
* onSaveInstanceState:保存数据.
* 
* 一般是因为内存不足UI的状态被回收的时候调用
* @param outState 待保存的状态
*/
void onSaveInstanceState(Bundle outState);
/**
* onRestoreInstanceState:当UI被恢复的时候被调用. 
*
* @param savedInstanceState 保存了的状态
*/
void onRestoreInstanceState(Bundle savedInstanceState);
```

封装BaseActivity 拥有一个 protected P mPresenter实例，类型写成泛型，protected修饰，子类实现 构造方法
中，对mPresenter进行实例化：采用反射的形式（避免让子类进行实例化，繁琐）

```java
public abstract class BaseMVPActivity<P extends IPresenter> extends BaseActivity {
    protected P mPresenter;
    public BaseMVPActivity(){
    	this.mPresenter = createPresenter();
    }
    protected P createPresenter(){
    	ParameterizedType type = (ParameterizedType)(getClass().getGenericSuperclass());
    	if(type == null){
    		return null;
        }
        Type[] typeArray = type.getActualTypeArguments();
        if(typeArray.length == 0){
            return null;
        } 
        Class<P> clazz = (Class<P>) typeArray[0];
        try {
            return clazz.newInstance();
        } catch (IllegalAccessException e) {
            e.printStackTrace();
        } catch (InstantiationException e) {
            e.printStackTrace();
        } 
    	return null;
    }
    
	@Override
    protected void onDestroy() {
    	mPresenter.onUIDestroy();
    	super.onDestroy();
    }
}
```

**封装BasePresenter** 定义BasePresenter，页面销毁的回调里面。处理网络请求定义一个集合，把每次网络请求装载到集合里面，在页面销毁的时候，取消所有的网络请求。防止内存泄漏。

```java
public abstract class BasePresenter<U extends IUI> implements IPresenter {
    @Override
    public void onUIDestroy() {
        // 清空Call列表，并放弃Call请求
        clearAndCancelCallList();
    }
}
```

### 13.3.MVVM及其优缺点

View层包含布局,以及布局生命周期控制器(Activity/Fragment)
ViewModel与Presenter大致相同,都是负责处理数据和实现业务逻辑,但 ViewModel层不应该直接或者间接地持有View层的任何引用
model层是数据层
Model，模型层，即数据模型，用于获取和存储数据。
View，视图，即Activity/Fragment
ViewModel，视图模型，负责业务逻辑。
MVVM 的本质是数据驱动，把解耦做的更彻底，viewModel不持有view 。
View产生事件，使用 ViewModel进行逻辑处理后，通知Model更新数据，Model把更新的数据给ViewModel，ViewModel自动通知View更新界面，而不是主动调用View的方法
LiveData是具有生命周期的可观察的数据持有类。理解它需要注意这几个关键字，生命周期，可观察，数据持有类。
DataBinding用来实现View层与ViewModel数据的双向绑定，Data Binding 减轻原本 MVP 中 Presenter要与View 互动的职责

MVVM的优点
核心思想是观察者模式,它通过事件和转移View层数据持有权来实现View层与ViewModel层的解耦.
1.耦合度更低，复用性更强，没有内存泄漏
2.结合jetpack，写出更优雅的代码
缺点
ViewModel与View层的通信变得更加困难了,所以在一些极其简单的页面中请酌情使用,否则就会有一种脱裤子放屁的感觉,在使用MVP这个道理也依然适用。

### 13.4.MVC与MVP区别

View与Model并不直接交互，而是通过与Presenter交互来与Model间接交互。而在MVC中View可以与Model直接交互。MVP 隔离了MVC中的 M 与 V 的直接联系后，靠 Presenter 来中转，所以使用 MVP 时 P 是直接调用 View 的接口来实现对视图的操作的

### 13.5.MVP如何管理Presenter的生命周期，何时取消网络请求

https://blog.csdn.net/mq2553299/article/details/78927617
https://www.jianshu.com/p/0d07fba84cb8

使用RxLifecycle，通过监听Activity、Fragment的生命周期，来自动断开subscription以防止内存泄漏。
RxLifecycle原理
**操作符**

1.  takeUntil 发射来自原始Observable的数据，如果第二个Observable发射了一项数据或者发射了一个终止通知，原始Observable会停止发射并终止。
2. CombineLatest 当两个Observables中的任何一个发射了数据时，使用一个函数结合每个Observable发射的最近数据项，并且基于这个函数的结果发射数据。

**流程**

1. BehaviorSubject 在ActivityActivity不同的生命周期，BehaviorSubject对象会发射对应的ActivityEvent，比如在onCreate()生命周期发射ActivityEvent.CREATE，在onStop()发射ActivityEvent.STOP。
BehaviorSubject，实际上也还是一个Observable
BehaviorSubject （释放订阅前最后一个数据和订阅后接收到的所有数据）
2. LifecycleTransformer 在自己的请求中bindActivity返回的是LifecycleTransformer
LifecycleTransformer中使用upstream.takeUntil(observable)，
upstream就是原始的Observable
observable是Activity中的BehaviorSubject
**指定生命周期断开**
原始的Observable通过takeUntil和BehaviorSubject绑定，当BehaviorSubject发出数据即Activity的生命周期走到和你指定销毁的事件一样时,BehaviorSubject才会把事件传递出去,原始的Observable就终止发射数据了
**不指定生命周期断开**
combineLatest() 当两个Observables中的任何一个发射了数据时，使用一个函数结合每个Observable发射的最近数据项，并且基于这个函数的结果发射数据。不指定生命周期时bindToLifecycle中通过combineLatest组合

比如说我们在onCreate()中执行了bindToLifecycle，那么lifecycle.take(1)指的就是ActivityEvent.CREATE，经过map(correspondingEvents)，这个map中传的函数就是 1中的ACTIVITY_LIFECYCLE

lifecycle.skip(1)就简单了，除去第一个保留剩下的，以ActivityEvent.Create为例，这里就剩下：
ActivityEvent.START ActivityEvent.RESUME ActivityEvent.PAUSE ActivityEvent.STOP ActivityEvent.DESTROY
三个参数 意味着，lifecycle.take(1).map(correspondingEvents)的序列和 lifecycle.skip(1)进行combine，形成一个新的序列：
false,false,fasle,false,true
这意味着，当Activity走到onStart生命周期时，为false,这次订阅不会取消，直到onDestroy，为true，订阅取消。
最终还是和lifecycle（BehaviorSubject）发射的数据比较，如果两个一样说明Activity走到了该断开的生命周期了，upstream.takeUntil(observable)中的observable就要发通知告诉upstream（原始的Observable）该断开了。

## 14.Binder

https://juejin.im/post/6844903589635162126#heading-1
https://blog.csdn.net/carson_ho/article/details/73560642
https://www.colabug.com/2019/0421/6041679/
https://juejin.im/post/6844903469971685390#heading-0

### 14.1.Android中进程、线程、协程的区别

#### 14.1.1线程、协程的区别

1）一个线程可以多个协程，一个进程也可以单独拥有多个协程。

2）线程和进程都是同步机制（内核态实现的mutex同步），而协程则是异步（用户态）

3）协程能保留上一次调用时的状态，每次过程重入时，就相当于进入上一次调用的状态。

4）线程是抢占式，而协程是非抢占式的，所以需要用户自己释放使用权来切换到其他协程，因此同一时间其实只有一个协程拥有运行权，相当于单线程的能力。

5）协程并不是取代线程， 而且抽象于线程之上， 线程是被分割的CPU资源， 协程是组织好的代码流程， 协程需要线程来承载运行， 线程是协程的资源， 但协程不会直接使用线程， **协程直接利用的是执行器(Interceptor)， 执行器可以关联任意线程或线程池， 可以使当前线程， UI线程， 或新建新程.**。

6）线程是协程的资源。协程通过Interceptor来间接使用线程这个资源。

#### 14.1.2进程、线程、协程的区别

1）先有进程，然后进程可以创建线程，线程是依附在进程里面的， 线程里面可以包含多个协程

2）进程之间不共享全局变量，线程之间共享全局变量，但是要注意资源竞争的问题

3）多进程开发比单进程多线程开发稳定性要强，但是多进程开发比多线程开发资源开销要大

4）多线程开发线程之间执行是无序的，协程之间执行按照一定顺序交替执行

5）协程以后主要用在网络爬虫和网络请求，开辟一个协程大概需要5k空间，开辟一个线程需要512k空间， 开辟一个进程占用资源最多

https://blog.mimvp.com/article/47264.html

### 14.2.为何需要进行IPC,多进程通信可能会出现什么问题

为了保证进程空间不被其他进程破坏或干扰，Linux中的进程是相互独立或相互隔离的。在Android系统中一个应用默认只有一个进程，每个进程都有自己独立的资源和内存空间，其它进程不能任意访问当前进程的内存和资源。这样导致在不同进程的四大组件没法进行通信，线程间没法做同步，静态变量和单例也会失效。所以需要有一套IPC机制来解决进程间通信、数据传输的问题。
开启多进程虽简单，但会引发如下问题，必须引起注意。
1.静态成员和单例模式失效
2.线程同步机制失效
3.SharedPreferences 可靠性降低
4.Application 被多次创建
对于前两个问题，可以这么理解，在Android中，系统会为每个应用或进程分配独立的虚拟机，不同的虚拟机自然占有不同的内存地址空间，所以同一个类的对象会产生不同的副本，导致共享数据失败，必然也不能实现线程的同步。
由于SharedPreferences底层采用读写XML的文件的方式实现，多进程并发的的读写很可能导致数据异常。
Application被多次创建和前两个问题类似，系统在分配多个虚拟机时相当于把同一个应用重新启动多次，必然会导致 Application 多次被创建，为了防止在 Application 中出现无用的重复初始化，可使用进程名来做过滤，只让指定进程的才进行全局初始：
```java
public class MyApplication extends Application{
    @Override
    public void onCreate() {
        super.onCreate();
        String processName = "com.shh.ipctest";
        if (getPackageName().equals(processName)){
            // do some init
        }
    }
}
```

### 14.3.Android中IPC方式有几种、各种方式优缺点  

https://zhuanlan.zhihu.com/p/371139832

![v2-e69ecaa1a9d6d608add26617e8e73fd8_r](https://raw.githubusercontent.com/treech/PicRemote/master/common/v2-e69ecaa1a9d6d608add26617e8e73fd8_r.jpg)

### 14.4.为何新增Binder来作为主要的IPC方式

Android也是基于Linux内核，Linux现有的进程通信手段有以下几种：

- 管道：在创建时分配一个page大小的内存，缓存区大小比较有限；
- 消息队列：信息复制两次，额外的CPU消耗；不合适频繁或信息量大的通信；
- 共享内存：无须复制，共享缓冲区直接附加到进程虚拟地址空间，速度快；但进程间的同步问题操作系统无法实现，必须各进程利用同步工具解决；
- 套接字（Socket）：作为更通用的接口，传输效率低，主要用于不同机器或跨网络的通信；
- 信号量：常作为一种锁机制，防止某进程正在访问共享资源时，其他进程也访问该资源。因此，主要作为进程间以及同一进程内不同线程之间的同步手段。 不适用于信息交换，更适用于进程中断控制，比如非法内存访问，杀死某个进程等；

既然有现有的IPC方式，为什么重新设计一套Binder机制呢
主要是出于以上三个方面的考量：
1、效率：传输效率主要影响因素是内存拷贝的次数，拷贝次数越少，传输速率越高。从Android进程架构角度分析：对于消息队列、Socket和管道来说，数据先从发送方的缓存区拷贝到内核开辟的缓存区中，再从内核缓存区拷贝到接收方的缓存区，一共两次拷贝。
一次数据传递需要经历：用户空间 –> 内核缓存区 –> 用户空间，需要2次数据拷贝，这样效率不高。
而对于Binder来说，数据从发送方的缓存区拷贝到内核的缓存区，而接收方的缓存区与内核的缓存区是映射到同一块物理地址的，节省了一次数据拷贝的过程 ： 共享内存不需要拷贝，Binder的性能仅次于共享内存。
2、稳定性：上面说到共享内存的性能优于Binder，那为什么不采用共享内存呢，因为共享内存需要处理并发同步问题，容易出现死锁和资源竞争，稳定性较差。 Binder基于C/S架构 ，Server端与Client端相对独立，稳定性较好。
3、安全性：传统Linux IPC的接收方无法获得对方进程可靠的UID/PID，从而无法鉴别对方身份；而Binder机制为每个进程分配了UID/PID，且在Binder通信时会根据UID/PID进行有效性检测。

### 14.5.什么是Binder

从进程间通信的角度看，Binder 是一种进程间通信的机制；
从 Server 进程的角度看，Binder 指的是 Server 中的 Binder 实体对象(Binder类 IBinder)；
从 Client 进程的角度看，Binder 指的是对 Binder 代理对象，是 Binder 实体对象的一个远程代理
从传输过程的角度看，Binder 是一个可以跨进程传输的对象；Binder 驱动会自动完成代理对象和本地对象之间的转换。

从Android Framework角度来说，Binder是ServiceManager连接各种Manager和相应ManagerService的桥梁
Binder跨进程通信机制：基于C/S架构，由Client、Server、ServerManager和Binder驱动组成。
进程空间分为用户空间和内核空间。用户空间不可以进行数据交互；内核空间可以进行数据交互，所有进程共用一个内核空间
Client、Server、ServiceManager均在用户空间中实现，而Binder驱动程序则是在内核空间中实现的；

### 14.6.Binder的原理

https://jxiaow.gitee.io/posts/7425384b/

Binder Driver 如何在内核空间中做到一次拷贝的
进程空间分为用户空间和内核空间。用户空间不可以进行数据交互；内核空间可以进行数据交互，所有进程共用一个内核空间。
应用程序不能直接操作设备硬件地址,如果用户空间需要读取磁盘的文件， 如果不采用内存映射， 需要两次拷贝（磁盘-->内核空间-->用户空间）；
内存映射将用户空间的一块内存区域映射到内核空间。映射关系建立后，内核空间对这段区域的修改也能直接反应到用户空间,少了一次拷贝。
Binder 驱动使用 mmap() 在内核空间创建数据接收的缓存空间。 mmap(NULL, MAP_SIZE, PROT_READ,MAP_PRIVATE, fd, 0)的返回值是内核空间映射在用户空间的地址
1.Binder驱动在内核空间创建一个数据接收缓存区。
2.在内核空间开辟一块内核缓存区，建立内核缓存区和内核空间的数据接收缓存区之间的映射关系，以及内核中数据接收缓存区和接收进程用户空间地址的映射关系。
3.发送方进程通过系统调用 copyfromuser() 将数据 copy 到内核空间的内核缓存区，由于内核缓存区和接收进程的用户空间存在内存映射，因此也就相当于把数据发送到了接收进程的用户空间，这样便完成了一次进程间的通信。

跨进程通信的核心原理如下图：

![12](https://raw.githubusercontent.com/treech/PicRemote/master/common/12.svg)

Binder通信的核心原理如下图：

![123](https://raw.githubusercontent.com/treech/PicRemote/master/common/123.png)

### 14.7.使用Binder进行数据传输的具体过程

系统层面:
**注册服务**
服务进程向Binder进程发起服务注册
Binder驱动将注册请求转发给ServiceManager进程
ServiceManager进程添加这个服务进程
**获取服务**
用户进程向Binder驱动发起获取服务的请求，传递要获取的服务名称Binder驱动
将该请求转发给ServiceManager进程
ServiceManager进程查到到用户进程需要的服务进程信息最后
通过Binder驱动将上述服务信息返回个用户进程
**使用服务**
1.Binder通过内存映射建立数据缓存区
2.根据ServiceManager查到的服务的进程和数据缓存区 , 数据缓存区和client进程的内存缓存区建立映射
3.client掉用copy_from_user数据到内存缓存区
4.收到binder启动后服务进程根据用户进程要求调用目标方法
5.服务进程将目标方法的结果返回给用户进程

![23](https://raw.githubusercontent.com/treech/PicRemote/master/common/23.png)

具体代码层面:
1、服务端中的Service给客户端提供Binder对象
2、客户端通过AIDL接口中的asInterface()将这个Binder对象转换为代理Proxy并通过它发起RPC请求
3、client进程的请求数据data通过代理binder对象的transact方法，发送到内核空间，当前线程被挂起 
4、server进程收到binder驱动通知， onTransact(在线程池中进行数据反序列化&调用目标方法)处理客户端请求，并将结果写入reply
5、Binder驱动将server进程的目标方法执行结果，拷贝到client进程的内核空间
6、Binder驱动通知client进程，之前挂起的线程被唤醒，并收到返回结果  

![20190411182347425](https://raw.githubusercontent.com/treech/PicRemote/master/common/20190411182347425.png)

https://blog.csdn.net/final__static/article/details/89217142

### 14.8.Binder框架中ServiceManager的作用

ServiceManager使得客户端可以获取服务端binder实例对象的引用

### 14.9.什么是AIDL

AIDL是android提供的接口定义语言，简化Binder的使用 ， 轻松地实现IPC进程间通信机制。 AIDL会生成一个服务
端对象的代理类，通过它客户端可以实现间接调用服务端对象的方法。

### 14.10.AIDL使用的步骤

书写 AIDL
创建要操作的实体类，实现 Parcelable 接口，以便序列化/反序列化
新建 aidl 文件夹，在其中创建接口 aidl 文件以及实体类的映射 aidl 文件
Make project ，生成 Binder 的 Java 文件

编写服务端
创建 Service，在Service中创建生成的Stub实例，实现接口定义的方法
在 onBind() 中返回Binder实例

编写客户端
实现 ServiceConnection 接口，在其中通过asInterface拿到 AIDL 类
bindService()
调用 AIDL 类中定义好的操作请求

### 14.11.AIDL支持哪些数据类型  

Java八种基本数据类型(int、char、boolean、double、float、byte、long、string) 但不支持short
String、CharSequence
List和Map，List接收方必须是ArrayList，Map接收方必须是HashMap
实现Parcelable的类

### 14.12.AIDL的关键类，方法和工作流程

Client和Server都使用同一个AIDL文件，在AIDL 编译后会生成java文件 ,其中有Stub服务实体和Proxy服务代理两个类
AIDL接口：编译完生成的接口继承IInterface。
Stub类： 服务实体，Binder的实现类，服务端一般会实例化一个Binder对象，在服务端onBind中绑定，
客户端asInterface获取到Stub。
这个类在编译aidl文件后自动生成，它继承自Binder，表示它是一个Binder本地对象；它是一个抽象类，实现了IInterface接口，表明它的子类需要实现Server将要提供的具体能力（即aidl文件中声明的方法）。
Stub.Proxy类： 服务的代理，客户端asInterface获取到Stub.Proxy。
它实现了IInterface接口，说明它是Binder通信过程的一部分；它实现了aidl中声明的方法，但最终还是交由其中的mRemote成员来处理，说明它是一个代理对象，mRemote成员实际上就是BinderProxy。
asInterface()：客户端在ServiceConnection通过Person.Stub.asInterface(IBinder)， 会根据是同一进行通信，还是不同进程通信，返回Stub()实体，或者Stub.Proxy()代理对象
transact()：运行在客户端，当客户端发起远程请求时，内部会把信息包 装好，通过transact()向服务端发送。并将当前线程挂起， Binder驱动完成一系列的操作唤醒 Server 进程 ，调用 Server 进程本地对象的 onTransact()来调用相关函数 。 到远程请求返回，当前线程继续执行。
onTransact()：运行在服务端的Binder线程池中，当客户端发起跨进程请求时， onTransact()根据 Client传来的code 调用相关函数 。调用完成后把数据写入Parcel，通过reply发送给Client。驱动唤醒 Client 进程里刚刚挂起的线程并将结果返回。

![20190411182347425](https://raw.githubusercontent.com/treech/PicRemote/master/common/20190411182347425.png)

### 14.13.如何优化多模块都使用AIDL的情况

每个业务模块创建自己的AIDL接口并创建Stub的实现类，向服务端提供自己的唯一标识和实现类。
服务端只需要一个Service，创建Binder连接池接口,跟据业务模块的特征来返回相应的Binder对象.
客户端调用时通过Binder连接池， 即将每个业务模块的Binder请求统一转发到一个远程Service中去执行， 从而避免重复创建Service。

https://blog.csdn.net/it_yangkun/article/details/79888900

### 14.14.使用 Binder 传输数据的最大限制是多少，被占满后会导致什么问题

因为Binder本身就是为了进程间频繁而灵活的通信所设计的，并不是为了拷贝大数据而使用的。比如在Activity之间传输BitMap的时候，如果Bitmap过大，就会引起问题，比如崩溃等，这其实就跟Binder传输数据大小的限制有关系
mmap函数会为Binder数据传递映射一块连续的虚拟地址，这块虚拟内存空间其实是有大小限制。
普通的由Zygote孵化而来的用户进程，所映射的Binder内存大小是不到1M的，准确说是 110241024) - (4096 *2)
```c
#define BINDER_VM_SIZE ((1*1024*1024) - (4096 *2))
```
特殊的进程ServiceManager进程，它为自己申请的Binder内核空间是128K，这个同ServiceManager的用途是分不开的，ServcieManager主要面向系统Service，只是简单的提供一些addServcie，getService的功能，不涉及多大的数据传输，因此不需要申请多大的内存：
```c
bs = binder_open(128*1024);
```
当服务端的内存缓冲区被Binder进程占用满后，Binder驱动不会再处理binder调用并在c++层抛出
DeadObjectException到binder客户端

### 14.15.Binder 驱动加载过程中有哪些重要的步骤

从 Java 层来看就像访问本地接口一样，客户端基于 BinderProxy 服务端基于 IBinder 对象 。
在Native层有一套完整的binder通信的C/S架构，Bpinder作为客户端，BBinder作为服务端。基于naive层的Binder框架，Java也有一套镜像功能的binder C/S架构，通过JNI技术，与native层的binder对应，Java层的binder功能最终都是交给native的binder来完成。
从内核看跨进程通信的原理最终是要基于内核的，所以最会会涉及到 binder_open 、binder_mmap 和 binder_ioctl这三种系统调用。

http://gityuan.com/2015/11/01/binder-driver/
https://developer.aliyun.com/article/919116

### 14.16.系统服务与bindService启动的服务的区别

服务可分为系统服务与普通服务，系统服务一般是在系统启动的时候，由SystemServer进程创建并注册到ServiceManager中 例如AMS，WMS，PMS。而普通服务一般是通过ActivityManagerService启动的服务，或者说通过四大组件中的Service组件启动的服务。不同主要从以下几个方面：

服务的启动方式 系统服务这些服务本身其实实现了Binder接口，作为Binder实体注册到ServiceManager中，被ServiceManager管理。这些系统服务是位于SystemServer进程中

普通服务一般是通过Activity的startService或者其他context的startService启动的，这里的Service组件只是个封装，主要的是里面Binder服务实体类，这个启动过程不是ServcieManager管理的，而是通过ActivityManagerService进行管理的，同Activity管理类似

服务的注册与管理
系统服务一般都是通过ServiceManager的addService进行注册的，这些服务一般都是需要拥有特定的权限才能注册到ServiceManager，而bindService启动的服务可以算是注册到ActivityManagerService，只不过ActivityManagerService管理服务的方式同ServiceManager不一样，而是采用了Activity的管理模型

服务的请求使用方式
使用系统服务一般都是通过ServiceManager的getService得到服务的句柄，这个过程其实就是去ServiceManager中查询注册系统服务。而bindService启动的服务，主要是去ActivityManagerService中去查找相应的Service组件，最终会将Service内部Binder的句柄传给Client

### 14.17.Activity的bindService流程

1、Activity调用bindService：通过Binder通知ActivityManagerService，要启动哪个Service
2、ActivityManagerService创建ServiceRecord，并利用ApplicationThreadProxy回调，通知APP新建并启动Service启动起来
3、ActivityManagerService把Service启动起来后，继续通过ApplicationThreadProxy，通知APP，bindService，其实就是让Service返回一个Binder对象给ActivityManagerService，以便AMS传递给Client
4、ActivityManagerService把从Service处得到这个Binder对象传给Activity，这里是通过IServiceConnection binder实现。
5、Activity被唤醒后通过Binder Stub的asInterface函数将Binder转换为代理Proxy，完成业务代理的转换，之后就能利用Proxy进行通信了。

### 14.18.怎么跨进程传递大图片？

https://www.jianshu.com/p/fec93e54076f

**1、普通的传递bitmap API**

```kotlin
val btnClick: Button = findViewById(R.id.btnClick)
btnClick.setOnClickListener {
	val photoBitmap = BitmapFactory.decodeResource(resources, R.mipmap.big_photo)
	startActivity(Intent(this, SecondActivity::class.java).apply {
		this.putExtra("photo", photoBitmap)
	})
}
```

![intent传大图报异常](https://raw.githubusercontent.com/treech/PicRemote/master/common/intent%E4%BC%A0%E5%A4%A7%E5%9B%BE%E6%8A%A5%E5%BC%82%E5%B8%B8.webp)

传递大图直接报错，提示data过大

**2、为什么intent需要限制数据大小？**
应用进程在启动 Binder 机制时会映射一块 1M 大小的内存，所有正在进行的 Binder 事务共享这 1M 的缓冲区 。当使用 Intent 进行 IPC 时申请的缓存超过 1M - 其他事务占用的内存时，就会申请失败抛 TransactionTooLargeException 异常了。

**3、怎么办？**

发送代码：

```kotlin
val btnAidlClick: Button = findViewById(R.id.btnAidlClick)
btnAidlClick.setOnClickListener {
    startActivity(Intent(this, SecondActivity::class.java).apply {
        val bundle: Bundle = Bundle()
        bundle.putBinder("bitmap", BitmapBinder(photoBitmap))
        this.putExtras(bundle)
    })
}
```

接收代码：

```kotlin
val image:ImageView = findViewById(R.id.ivPhoto)
val bundle:Bundle = intent.extras?: Bundle()
val bitmapBinder:BitmapBinder = bundle.getBinder("bitmap") as BitmapBinder
val bitmap = bitmapBinder.getBitmap()
image.setImageBitmap(bitmap)
```

可以看到，不同的地方就是这一次使用了putBinder方法，将图片的bitmap放在了bundle中，就可以传过去了。那就先来看看putBinder方法：

```kotlin
public void putBinder(@Nullable String key, @Nullable IBinder value) {
    unparcel();
    mMap.put(key, value);
}
```

需要的是一个key和一个IBinder类型的value，key很好理解，就是map的key，而IBinder是一个接口，Binder类是实现了IBinder接口的，所以我上面的BitmapBinder继承了Binder，自然就能使用putBinder方法了。

**4、那为什么利用AIDL来传又可以呢？原理是什么？**

要回答这个问题，就需要看些比较底层的东西了。
先看看，底层在 IPC 时是怎么把 Bitmap 写进 Parcel 的。

```cpp
Android - 28 Bitmap.cpp
static jboolean Bitmap_writeToParcel(JNIEnv* env, jobject, ...) {
    // 拿到 Native 的 Bitmap                               
    auto bitmapWrapper = reinterpret_cast<BitmapWrapper*>(bitmapHandle);
    // 拿到其对应的 SkBitmap, 用于获取 Bitmap 的像素信息
    bitmapWrapper->getSkBitmap(&bitmap);
 
    int fd = bitmapWrapper->bitmap().getAshmemFd();
    if (fd >= 0 && !isMutable && p->allowFds()) {
            // Bitmap 带了 ashmemFd && Bitmap 不可修改 && Parcel 允许带 fd
            // 就直接把 FD 写到 Parcel 里，结束。
        status = p->writeDupImmutableBlobFileDescriptor(fd);
        return JNI_TRUE;
    }
 
    // 不满足上面的条件就要把 Bitmap 拷贝到一块新的缓冲区
    android::Parcel::WritableBlob blob;
    // 通过 writeBlob 拿到一块缓冲区 blob
    status = p->writeBlob(size, mutableCopy, &blob);
 
    // 获取像素信息并写到缓冲区
    const void* pSrc =  bitmap.getPixels();
    if (pSrc == NULL) {
        memset(blob.data(), 0, size);
    } else {
        memcpy(blob.data(), pSrc, size);
    }
}
```

然后看看 writeBlob 是怎么获取缓冲区的（注意虽然方法名写着 write , 但是实际往缓冲区写数据是在这个方法执行之后）

```cpp
Android - 28 Parcel.cpp
// Maximum size of a blob to transfer in-place.
static const size_t BLOB_INPLACE_LIMIT = 16 * 1024;
 
status_t Parcel::writeBlob(size_t len, bool mutableCopy, WritableBlob* outBlob)
{
    if (!mAllowFds || len <= BLOB_INPLACE_LIMIT) {
    // 如果不允许带 fd ，或者这个数据小于 16K
    // 就直接在 Parcel 的缓冲区里分配一块空间来保存这个数据
        status = writeInt32(BLOB_INPLACE);
        void* ptr = writeInplace(len);
        outBlob->init(-1, ptr, len, false);
        return NO_ERROR;
    }
 
        // 另外开辟一个 ashmem，映射出一块内存，后续数据将保存在 ashmem 的内存里
    int fd = ashmem_create_region("Parcel Blob", len);
    void* ptr = ::mmap(NULL, len, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    ...
    // parcel 里只写个 fd 就好了，这样就算数据量很大，parcel 自己的缓冲区也不用很大
    status = writeFileDescriptor(fd, true /*takeOwnership*/);
        outBlob->init(fd, ptr, len, mutableCopy);
    return status;
}
```

通过上面的分析，我们可以看出，同一个 Bitmap 写入到 Parcel 所占的缓冲区大小和 Pacel 的 allowFds 有关。

直接通过 Intent 传 Bitmap 容易抛 TransactionTooLargeException 异常，就是因为 Parcel 的 allowFds = false，直接把 Bitmap 写入缓冲区占用了较大的内存。

接下来，我们来看一下，allowFds 是什么时候被设置成 false 的呢：

```java
// 启动 Activity 执行到 Instrumentation.java 的这个方法
public ActivityResult execStartActivity(..., Intent intent, ...){
  ...
  intent.prepareToLeaveProcess(who);
    ActivityManager.getService().startActivity(...,intent,...)
}
 
// Intent.java
public void prepareToLeaveProcess(boolean leavingPackage) {
 // 这边一层层传递到最后设置 Parcel 的 allowfds
  setAllowFds(false);
  ....
}
```

总结一下：较大的 bitmap 直接通过 Intent 传递容易抛异常是因为 Intent 启动组件时，系统禁掉了文件描述符 fd 机制 , bitmap 无法利用共享内存，只能拷贝到 Binder 映射的缓冲区，导致缓冲区超限, 触发异常; 而通过 putBinder 的方式，避免了 Intent 禁用描述符的影响，bitmap 写 parcel 时的 allowFds 默认是 true , 可以利用共享内存，所以能高效传输图片。

**5、还有没有其他的方法可以实现？**

①先将图片保存到文件，然后intent传递图片的文件路径，再在目标界面重新读取图片文件显示，但是缺点是效率太低了，还耗性能。

### 14.19.不通过AIDL，手动编码来实现Binder的通信

## 15.内存泄漏&内存溢出

### 15.1.什么是OOM & 什么是内存泄漏以及原因

**内存泄漏**
没有用的对象资源任与GC-Root保持可达路径，导致系统无法进行回收。

**原因**
1 非静态内部类默示持有外部类的引用，如非静态handler持有activity的引用
2.接收器、监听器注册没取消造成的内存泄漏，如广播，eventsbus
3.Activity 的 Context 造成的泄漏，可以使用 ApplicationContext
4.单例中的static成员间接或直接持有了activity的引用
5.资源对象没关闭造成的内存泄漏（如： Cursor、File等）
6.全局集合类强引用没清理造成的内存泄漏（特别是 static 修饰的集合）

**内存溢出**
根据java的内存模型会出现内存溢出的内存有堆内存、 方法区内存、虚拟机栈内存、native方法区内存， 一般说的OOM基本都是针对堆内存；
1、对于堆内存溢出主的根本原因有两种
（1）app进程内存达到上限
（2）手机可用内存不足，这种情况并不是我们app消耗了很多内存， 而是整个手机内存不足
2、对于app内存达到上限只有两种情况
（1）申请内存的速度超出gc释放内存的速度.往内存中加载超大文件，加载的文件或者图片过大造成或者循环创建大量对象
（2）内存出现泄漏，gc无法回收泄漏的内存，导致可用内存越来越少

### 15.2.Thread是如何造成内存泄露的，如何解决？

垃圾回收器不会回收GC Roots以及那些被它们间接引用的对象
非静态内部类会持有外部类的引用。Thread 会长久地持有 Activity 的引用，使得系统无法回收 Activity 和它所关联的资源和视图。
使用静态内部类/匿名类，不要使用非静态内部类/匿名类。
该养成thread设置退出逻辑条件的习惯。

### 15.3. Handler导致的内存泄露的原因以及如何解决

原因:
1.Java中非静态内部类和匿名内部类都会隐式持有当前类的外部引用
2.我们在Activity中使用非静态内部类初始化了一个Handler, 此Handler就会持有当前Activity的引用。
3.我们想要一个对象被回收，那么前提它不被任何其它对象持有引用， 所以当我们Activity页面关闭之后,存在引用关系： "未被处理 / 正处理的消息 -> Handler实例 -> 外部类", 如果在Handler消息队列 还有未处理的消息 / 正在处理消息时 导致Activity不会被回收，从而造成内存泄漏

解决方案: 
1.将Handler的子类设置成静态内部类,使用WeakReference弱引用持有Activity实例
2.当外部类结束生命周期时，清空Handler内消息队列

### 15.4.如何加载Bitmap防止内存溢出

1.对图片进行内存压缩；
2.高分辨率的图片放入对应文件夹；
3.内存复用
4.及时回收

### 15.5.MVP中如何处理Presenter层以防止内存泄漏的

首先 MVP 会出现内存泄漏是因为 Presenter 层持有 View 对象，一般我们会把 Activity 作为View 传递到Presenter，Presenter 持有 View对象，Activity 退出了但是没有回收出现内存泄漏。
解决办法： 
1.Activity onDestroy() 方法中调用 Presenter 中的方法，把 View 置为 null
2.使用 Lifecycle

## 16.性能优化

https://www.jianshu.com/u/7f26e9b13731 https://github.com/liuyangbajin
https://www.jianshu.com/p/8bd39de7323f

### 16.1.内存优化

https://juejin.cn/post/6844903618642968590#heading-0

> 首先你要确保你的应用里没有存在内存泄漏，然后再去做其他的内存优化。内存泄漏和图片优化相对来说比较容易定位问题，且优化后效果也非常明显，性价比非常高

事实上很多优化都是这样，比如减包大小的优化，也是要先分析出主要大头，比如可能你的包里包含了一张3M大小的无用图片，如果你没找到这种祸首，可能你做了大量的工作去想办法减少无用代码等，最终可能只有几百K的收益。

**1、内存泄漏和图片优化**
**1.1 避免内存泄漏**
**1.1.1 注意代码中常见内存泄漏场景**

Handler内存泄漏
在Activity中使用非静态内部类初始化了一个Handler,此Handler就会持有当前Activity的引用。Activity页面关闭之后,存在引用关系。非静态内部类和匿名内部类都会隐式持有当前类的外部引用。

单例造成的内存泄漏
单例持有 Context 对象，如果 Activity 中调用 getInstance 方法并传入 this 时，singleTon 就持有了此 Activity 的引用，当退出 Activity 时，Activity 就无法回收，造成内存泄漏

资源性对象未关闭，注册对象未注销
例如Bitmap等资源未关闭会造成内存泄漏，例如BraodcastReceiver、EventBus未注销造成的内存泄漏，我们应该在Activity销毁时及时注销。

MVP中的内存泄漏
Presenter 层持有 View 对象，一般我们会把 Activity 做为 View 传递到 Presenter，Presenter 持有 View对象，Activity 退出了但是没有回收出现内存泄漏。

ViewPager+fragment内存泄露

List里一直有Fragment的引用，Fragment无法回收造成内存泄漏 在重写的PagerAdapter的getItem()方法中，return new yourFragment()解决此问题

在 MVP 的架构中，通常 Presenter 要同时持有 View 和 Model 的引用，如果在 Activity 退出的时候，Presenter 正在进行一个耗时操作，那么 Presenter 的生命周期会比 Activity 长，导致 Activity 无法回收，造成内存泄漏

避免在循环里创建对象，建立合适的缓存复用对象，避免在onDraw里创建对象

**1.1.2 使用工具查找内存泄漏具体位置**

LeakCanary

在Activity执行完onDestroy()之后，将它放入WeakReference中，然后将这个WeakReference类型的Activity对象与ReferenceQueque关联。这时再从ReferenceQueque中查看是否有没有该对象，如果没有，执行gc，再次查看，还是没有的话则判断发生内存泄露了。最后用HAHA这个开源库去分析dump之后的heap内存

Profiler

使用App后，Android Profiler中先触发GC，然后dump内存快照，之后点击按package分类，就可以迅速查看到你的App目前在内存中残留的class,点击class即可在右边查看到对应的实例以及引用对象。

**1.2 图片优化**
Bitmap 内存占用的计算
1.对图片进行内存压缩；
包括图片质量的压缩， RGB_565法，采样率压缩，Matrix比例压缩
2.高分辨率的图片放入对应文件夹；
不同dpi占用内存不一样,假设这张图片是ARGB_8888的，那这张图片占的内存就是 width * height * 4个字节或者width * height * inTargetDensity /inDensity * 4
3.缓存
LruCache & DiskLruCache
4.及时回收
5.ARTHook非侵入式之图片检查
ARTHook 监控加载的图片是否过大的ImageView，可以在debug阶段发出警告，方便及早发现过大的图片。
1 使用Epic来进行Hook
2 DexposedBridge.hookAllConstructors(ImageView.class, new XC_MethodHook()
3 ImageHook中，图标宽高都大于view的2倍以上，则警告，当宽高度等于0时，说明ImageView还没有进行绘制，使用ViewTreeObserver进行大图检测的处理

**2、内存占用分析优化**
**2.1静态内存分析优化**
确保打开每一个主要页面的主要功能，然后回到首页，进开发者选项去打开"不保留后台活动"。然后，将我们的app退到后台，GC，dump出内存快照。最后，我们就可以将对dump出的内存快照进行分析，看看有哪些地方是可以优化的，比如加载的图片、应用中全局的单例数据配置、静态内存与缓存、埋点数据、内存泄漏等等。

问题1： 
App首页的主图有两张(一张是保底图，一张是动态加载的图)，都比较大，而且动态加载的图回来后，保底图并没有及时被释放
优化：首先是对首页的主图进行颜色通道的改变以及压缩，可以大大降低这两张图所占的内存，然后在动态加载图回来后及时释放掉保底图 -5M

问题2： 首页底部的轮播背景图占用内存1.6M，且在图片加载回来后，背景图一直没有置空 
优化：首先一般来说对背景图的质量并没有很高的要求，所以这张背景图是可以被成倍压缩的，并且在图片加载回来后，背景图要及时的释放掉。同时首页的多张轮播图以及其他图片都可以进行颜色模式的改变以及质量压缩。 -1.6M -4M

3时间选择库

4： SharePreference在内存里占用了700K的内存 
优化：由于SP中的东西是会一次性加载到内存里并且保存为静态的，直到App进程结束才会被销毁，所以SP中千万别放大的对象，别图一时方便把对象序列化成json后保存到SP里，优化点就是把已经保存在SP中的一些较大的json字符串或者对象迁移到文件或者数据库缓存。 -400K

**2.2 动态内存分析优化**
利用Android Profiler实时观察进入每个页面后的内存变化情况，对产生的内存较大波峰做分析, dump出2个页面的内存快照文件，然后利用MAT的对比功能，找出每个页面相对于上个页面内存里主要增加了哪些东西，做针对性优化。

问题1：在内存里发现两个极少概率出现的empty view，占用了接近2M的内存 
优化：用ViewStub对empty view做了懒加载，对于这些没有马上用到的资源要做延迟加载，还有很多大概率不会出现的View更加要做懒加载。 -2M
问题2：发现详情页的轮播大图的Viewpager用的Adapter是FragmentPagerAdapter，导致了所有的page都会被保存，当图片页数多的时候，往后翻内存会不断上升。 
优化：这种页数多的ViewPager使用FragmentStatePagerAdapter来替代，它只会保留前后pager,在页数多的时候可以 节省大量内存。

内存抖动：
每创建一个对象就会分配一个内存,可用内存就少用了一块,当程序占用的内存达到一定的临界值
就会出发GC 内存频繁分配和回收导致内存不稳定
瞬间产生大量的对象会严重占用Young Generation的内存区域，当达到阀值，剩余空间不够的时候，也会触发GC

解决：
减少不合理的对象创建
ondraw、getView中对象的创建尽量进行复用。
避免在循环中不断创建局部变量。

实时监控
LeakCanary
hprof 文件裁剪
LeakCanary 用 shark 组件来实现裁剪 hprof 文件功能，在 shark-cli 工具中，我们可以通过添加 strip-hprof 选项来裁剪 hprof 文件，它的实现思路是：通过将所有基本类型数组替换为空数组（大小不变）。

实时监控
LeakCanary 主要是为测试环境开发，它会在 Activity 或者 Fragment 的 destory 生命周期后，可以检测 Activity 和Fragment 是否被回收，来判断它们是否存在泄露的情况。

Matrix-ResourceCanary
Matrix 主要也是在 hprof 文件裁剪 和 实时监控 这两方面做了一些优化。
hprof 文件裁剪
Matrix 的裁剪思路主要是将除了部分字符串和 Bitmap 以外实例对象中的 buffer 数组。 之所以保留 Bitmap 是因为Matirx 有个检测重复 Bitmap 的功能，会对 Bitmap 的 buffer 数组做一次 MD5 操作来判断是否重复。

监控原理
Matrix 是基于 LeakCanary 上进行二次开发，所以基本是一致的，主要增加了一些误报的优化，比如：
多次检测到相同的可疑对象，才认定为泄露对象，参数可配置。
增加一个哨兵对象，用于判断是否有 GC 操作，因为调用 Runtime.getRuntime().gc() 只是建议虚拟机进行 GC 操作，并不一定会进行。

避免重复检测相同的对象
Matrix 虽然是基于 LeakCnary，但额外增加了一些配置选项，可以用于生产环境，比如 dump 模式，支持手动触发
dump，自动 dump，和不进行 dump，可以根据不同的环境，使用不同的模式。
除此之前，还有检测时间间隔等等。

https://github.com/Tencent/matrix

### 16.2.启动优化

https://github.com/aiceking/AppStartFaster
https://note.youdao.com/ynoteshare/index.html?id=2e7418ead7993d20c6dcd5d2e565844f&type=note&_time=1662355051438

https://github.com/liuyangbajin/Performance
https://my.oschina.net/u/660720/blog/3188893
统计启动时间的方式
https://www.jianshu.com/p/59a2ca7df681
adb shell am start -S -R 10 -W
com.ctg.and.mob.cuservice/com.ctg.and.mob.cuservice.mvp.ui.activity.MainActivity
TotalTime代表当前Activity启动时间，将多次TotalTime加起来求平均即可得到启动这个Activity的时间

缺点：
应用的启动过程往往不只一个Activity，有可能是先进入一个启动页，然后再从启动页打开真正的首页。某些情况下还有可能中间经过更多的Activity，这个时候需要将多个Activity的时间加起来。
将多个Activity启动时间加起来并不完全等于用户感知的启动时间。例如在启动页可能是先等待某些初始化完成或者某些动画播放完毕后再进入首页。使用命令行统计的方式只是计算了Activity的启动以及初始化时间，并不能体现这种等待任务的时间。

解决：
AMS会通过Zygote创建应用程序的进程后,执行Application构造方法 –> attachBaseContext() –> onCreate() –>
Activity onCreate() –>–> onStart() –> onResume() –> 测量布局绘制显示在界面上–>onWindowFocusChanged()绘制完毕 在Application的attachBaseContext()方法中开始计算冷启动计时，然后在真正首页Activity的onWindowFocusChanged()中停止冷启动计时。

代码
设置一个Util类专门做计时,Application的attachBaseContext()开始,首页Activity的 onWindowFocusChanged()结束

**具体代码方法耗时分析工具**
1.手动记录
每个方法前记录System.currentTimeMillis(),之后System.currentTimeMillis()进行相减
2.AOP
Aspect统计 Application 中所有方法的耗时，AspectJ 其实就是一种 AOP 框架
2.1、连接点（JoinPoint）
JPoint 是一个程序的关键执行点，也是我们关注的重点。它就是指被拦截到的点（如方法、字段、构造器等等）。
2.2、切入点（PointCut）
对 JoinPoint 进行拦截的定义。PointCut 的目的就是提供一种方法使得开发者能够选择自己感兴趣的 JoinPoint。
2.3、通知（Advice）
1）、Before：PointCut 之前执行。 2）、After：PointCut 之后执行。 3）、Around：PointCut 之前、之后分别执行。
3.Android Profiler得到启动过程的CPU过程，看到线程的具体代码耗时
https://www.jianshu.com/p/e0d2b6347414
Run -> Edit Configurations-> Sample Java Methods，可以定位到Java代码大致定位到启动CPU耗时的原因

**启动优化方案**

https://juejin.cn/post/6844903919580086280

https://www.jianshu.com/p/bef74a4b6d5e

https://juejin.cn/post/6844903459951476744#heading-6

https://blog.csdn.net/qian520ao/article/details/81908505?utm_medium=distribute.pc_relevant_t0.none-task-blog-BlogCommendFromBaidu-1.control&depth_1-utm_source=distribute.pc_relevant_t0.none-task-blog-BlogCommendFromBaidu-1.control

https://zhuanlan.zhihu.com/p/158683369

**1.启动闪屏主题设置**
https://www.jianshu.com/p/436b91175826

**冷启动与热启动**

> 冷启动：当启动某个应用程序时，如果Android手机系统发现后台没有该应用程序的进程，则会先创建一个该应用程序进程，这种方式叫冷启动。
>
> 热启动：当启动某个应用程序时，系统后台已经有一个该应用程序的进程了，则不会再创建一个新的进程，这种方式叫热启动。通常，我们按返回键退出应用，按home键回到桌面，该应用进程还一直存活，再次启动应用都叫热启动。

冷启动3个步骤：

1.从zygote进程fork出一个新进程 
2.创建Application类并初始化，主要是执行Application.onCreate()方法； 
3.创建并初始化入口Activity类，并在窗口上绘制UI；

白屏原因：

> Application.onCreate()执行比较耗时，才出现了白屏现象

设置android:windowBackground属性

> windowBackground属性可以配置任意drawable， 与你启动页一样的图片。做到视觉上的无缝过渡

application初始化内存,异步改造。

> 子线程来分担主线程的任务，并减少运行时间

**2.线程池和启动器**
线程缺乏统一管理，可能无限制新建线程，相互之间竞争，及可能占用过多系统资源导致死机或oom，所以我们使用线程池的方式去执行异步。
使用FixedThreadPool：创建一个定长的线程池，可控制线程最大的并发数，超出的部分任务，会在队列中等待。
利用CPU设置线程池数量

```java
// 获得当前CPU的核心数 
private static final int CPU_COUNT = Runtime.getRuntime().availableProcessors();
// 设置线程池的核心线程数2-4之间,但是取决于CPU核数 
private static final int CORE_POOL_SIZE = Math.max(2,Math.min(CPU_COUNT - 1, 4));
// 创建线程池 
ExecutorService executorService = Executors.newFixedThreadPool(CORE_POOL_SIZE);
```

**1、线程池**
通过线程池处理初始化任务的方式存在三个问题。

1. 代码不够优雅
   假如我们有 100 个初始化任务，那像上面这样的代码就要写 100 遍，提交 100 次任务。
2. 无法限制在 onCreate 中完成
   有的第三方库的初始化任务需要在 Application 的 onCreate 方法中执行完成，虽然可以用 CountDownLatch 实现等待，但是还是有点繁琐。
3. 无法实现存在依赖关系
   有的初始化任务之间存在依赖关系，比如极光推送需要设备 ID，而 initDeviceId() 这个方法也是一个初始化任务  

**2、启动器**

启动器可以考虑使用jetpack的startup框架亦或

第一步是我们要对代码进行任务化，任务化是一个简称，比如把启动逻辑抽象成一个任务。
第二步是根据所有任务的依赖关系排序生成一个有向无环图，这个图是自动生成的，也就是对所有任务进行排序。
比如我们有个任务 A 和任务 B，任务 B 执行前需要任务 A 执行完，这样才能拿到特定的数据，比如上面提到的initDeviceId。 假如任务 B 依赖于任务 A，这时候生成的有向无环图就是 ACB，A 和 C 可以提前执行，B 一定要排在A 之后执行。
第三步是多线程根据排序后的优先级依次执行。

**3、延迟执行任务**
延迟启动器利用了 IdleHandler 实现主线程空闲时才执行任务，IdleHandler 是 Android 提供的一个类，IdleHandler 会在当前消息队列空闲时才执行任务，这样就不会影响用户的操作了。 假如现在 MessageQueue 中有两条消息，在这两条消息处理完成后，MessageQueue 会通知 IdleHandler 现在是空闲状态，然后 IdleHandler 就会开始处理它接收到的任务。

**4、首页**
首页部分接口合并为一，减少网络请求次数，降低频率；
首页布局优化

**5、包体积优化也可以优化启动速度**

### 16.3.布局优化

布局加载流程（原理）
https://jsonchao.github.io/2020/01/13/%E6%B7%B1%E5%85%A5%E6%8E%A2%E7%B4%A2Android%E5%B8%83%E5%B1%80%E4%BC%98%E5%8C%96%EF%BC%88%E4%B8%8A%EF%BC%89/

1、在setContentView方法中，会通过LayoutInflater的inflate方法去加载对应的布局到android.R.id.content中。
2、inflate方法中首先会调用Resources的getLayout方法去通过IO的方式去加载对应的Xml布局解析器到内存中。调用链最终调用的是 AssetManager的openXmlAssetNative,一个Native方法，通过IO流的方式进行。方法返回XmlResourceParser,XmlResourceParser继承XmlPullParser, 根据提供的布局资源文件id可读取布局文件中view相关属性。
3、inflate，createViewFromTag来创建View的实例，在每次递归完成的时候将这个View添加到父布局中。
内部首先会判断mFactory2是否存在，存在就会使用mFactory2的onCreateView方法区创建视图，否则就会调用mFactory的onCreateView方法，接下来，如果此时的tag是一个Fragment，则会调用mPrivateFactory的onCreateView方法
createViewFromTag 将一些 控件变成兼容性控件 （例如将 TextView 变成 AppCompatTextView）以便于向下兼容新版本中的效果 ，创建View，使用类加载器创建了对应的Class实例， 根据Class实例获取到了对应的构造器实例，通过构造器实例constructor的newInstance方法创建了对应的View对象
https://segmentfault.com/a/1190000019101554

LayoutInflater.Factory的意义：
通过 LayoutInflater 创建 View 时候的一个回调，可以通过 LayoutInflater.Factory 来改造或定制创建 View 的过程。
AppCompatActivity 为什么 setFactory向下兼容新版本中的效果。

Factory与Factory2的区别：

1、Factory2继承与Factory。 
2、Factory2比Factory的onCreateView方法多一个parent的参数，即当前创建View的父View。

优化
性能瓶颈在于LayoutInflater.inflater过程，主要包括如下两点：
1 xmlPullParser IO操作，布局越复杂，IO耗时越长。
2 createView 反射，View越多，反射调用次数越多，耗时越长

AsyncLayoutInflater
https://www.jianshu.com/p/d61b513e6814

1将构造好的 InflateRequest 请求放入到队列ArrayBlockingQueue中。
2.异步线程死循环轮训这个队列，当队列中有数据，取出一个 InflateRequest。
3.通过获取 InflateRequest.LayoutInflater 真正地加载 resid 对应的布局文件，最终得到一个 View 对象，并赋值给InflateRequest.view。
4.通过 UIHandler 将 InflateRequest 回调到主线程中 (ps:这时加载完成的 View 就传到了主线程了)
5.UIHanlder 处理消息，通过 InflateRequest#callback 将加载得到的 View 对象回调给调用层。
因为是异步加载，所以需要注意在布局加载过程中不能有依赖于主线程的操作,AsyncLayoutInflater仅仅只能通过侧面缓解的方式去缓解布局加载的卡顿.

X2C
X2C，它原理是采用APT（Annotation Processor Tool）+ JavaPoet技术来完成编译期间视图xml布局生成java代码，这样布局依然是用xml来写，编译期X2C会将xml转化为动态加载视图的java代码。
https://github.com/iReaderAndroid/X2C
https://www.jianshu.com/p/c1b9ce20ceb3

**工具**
局整体耗时监控 ：AspectJ做面向aop的非侵入性的布局整体耗时监控 。
单个视图创建耗时监控： Factory2、Factory本质上他俩就是创建View的一个hook，可以通过这个回调来监控单个View创建耗时情况。
布局绘制流程


Layout Inspector 和 GPU rendering
原理
绘制的过程 CPU准备数据，通过Driver层把数据交给GPU渲染,Display负责消费显示内容
1.CPU主要负责Measure、Layout、Record、Execute的数据计算工作
2.GPU负责Rasterization（栅格化(向量图形的格式表示的图像转换成位图用于显示器)）、渲染,渲染好后放到buffer(图像缓冲区)里存起来.
3.Display（屏幕或显示器）屏幕会以一定的帧率刷新，每次刷新的时候，就会从缓存区将图像数据读取显示出来,如果缓存区没有新的数据，就一直用旧的数据，这样屏幕看起来就没有变

1.在 App 进程中创建PhoneWindow 后会创建ViewRoot。ViewRoot 的创建会创建一个 Surface壳子，请求WMS填充Surface，WMS copyFrom() 一个 NativeSurface。
2.响应客户端事件，创建Layer(FrameBuffer)与客户端的Surface建立连接。
3.copyFrom()的同时创建匿名共享内存SharedClient（每一个应用和SurfaceFlinger之间都会创建一个SharedClient）
4.当客户端 addView() 或者需要更新 View 时，App 进程的SharedBufferClient 写入数据到共享内存ShareClient中,SurfaceFlinger中的 SharedBufferServer 接收到通知会将 FrameBuffer 中的数据传输到屏幕上。

startActivity->ActivityThread.handleLaunchActivity->onCreate ->完成DecorView和Activity的创建->handleResumeActivity->onResume()->DecorView添加到WindowManager->ViewRootImpl.performTraversals()
方法，测量（measure）,布局（layout）,绘制（draw）, 从DecorView自上而下遍历整个View树。
https://www.jianshu.com/p/779b5ad22316

优化
1.优化布局层级及其复杂度 measure、layout、draw这三个过程都包含的自顶向下的tree遍历耗时，它是由视图层级太深会造成耗时，另外也要避免类似RealtiveLayout嵌套造成的多次触发measure、layout的问题。最后onDraw在频繁刷新时可能多次被触发，因此onDraw不能做耗时操作，同时不能有内存抖动隐患等。
**优化思路： 减少View树层级**
布局尽量宽而浅，避免窄而深 ConstraintLayout 实现几乎完全扁平化布局，同时具备RelativeLayout和
LinearLayout特性，在构建复杂布局时性能更高。
不嵌套使用RelativeLayout
不在嵌套LinearLayout中使用weight
merge标签使用：减少一个根ViewGroup层级
ViewStub 延迟化加载标签，当布局整体被inflater，ViewStub也会被解析但是其内存占用非常低，它在使用前是作为占位符存在，对ViewStub的inflater操作只能进行一次，也就是只能被替换1次。

2. 避免过度绘制 一个像素最好只被绘制一次。
**优化思路： 去掉多余的background，减少复杂shape的使用**
避免层级叠加
自定义View使用clipRect屏蔽被遮盖View绘制

3. 视图与数据绑定耗时
由于网络请求或者复杂数据处理逻辑耗时导致与视图绑定不及时。这里可以从优化数据处理的维度来解决
监控
布局加载监控
使用AspectJ做面向aop的非侵入性的监控。
针对Activity.setContentView监控简单示例：
```java
@Aspect 
public class PerformanceAop {
    public static final String TAG = "aop"; 
    @Around("execution(*android.app.Activity.setContentView(..))") 
    public void getSetContentViewTime(ProceedingJoinPoint joinPoint) {
		Signature signature = joinPoint.getSignature(); 
        String name = signature.toShortString(); 
        long time = System.currentTimeMillis(); 
        try { 
            	joinPoint.proceed(); 
            } catch (Throwable throwable) {
				throwable.printStackTrace(); 
        	} 
        Log.i(TAG, name + " cost " + (System.currentTimeMillis() - time)); 
    } 
}
```

**布局绘制监控**
fpsviewer 利用Choreographer.FrameCallback来监控卡顿和Fps的计算，异步线程进行周期采样，当前的帧耗时超过自定义的阈值时，将帧进行分析保存，不影响正常流程的进行，待需要的时候进行展示，定位Choreographer
1.只有当 App 注册监听下一个 Vsync 信号后才能接收到 Vsync 到来的回调。如果界面一直保持不变，那么 App 不会去接收每隔 16.6ms 一次的 Vsync 事件，但底层依旧会以这个频率来切换每一帧的画面 。即当界面不变时屏幕也会固定每 16.6ms 刷新，但 CPU/GPU 不走绘制流程。
2.当 View 请求刷新时，这个任务并不会马上开始，而是需要等到下一个 Vsync 信号到来时才开始
measure/layout/draw 流程；measure/layout/draw 流程运行完后，界面也不会立刻刷新，而会等到下一个 VSync信号到来时才进行缓存交换和显示。
3.造成丢帧主要原因：一是遍历绘制 View 树以及计算屏幕数据超过了16.6ms 第2帧的CPU/GPU计算没能在VSync信号到来前完成，屏幕平白无故地多显示了一次第1帧。 VSync信号还没绘制完毕
Choreographer，意为 舞蹈编导、编舞者。在这里就是指 对CPU/GPU绘制的指导—— 收到VSync信号才开始绘制，保证绘制拥有完整的16.6ms，避免绘制的随机性。 

1.创建mChoreographer，是在ViewRootImpl的构造方法内使用Choreographer.getInstance()创建
//使用当前线程looper创建 mHandler
// 创建一个链表类型CallbackQueue的数组，大小为5，
//创建了一个mHandler、VSync事件接收器mDisplayEventReceiver、任务链表数mCallbackQueues
2.当有绘制请求时通过 postCallback 方法请求下一次 Vsync 信号
首先取对应类型的CallbackQueue添加任务，action就是mTraversalRunnable
ViewRootImpl.scheduleTraversals中
//添加同步屏障，屏蔽同步消息，保证VSync到来立即执行绘制 mTraversalBarrier =
mHandler.getLooper().getQueue().postSyncBarrier(); mChoreographer.postCallback(
Choreographer.CALLBACK_TRAVERSAL, mTraversalRunnable, null); mTraversalRunnable 移除同步屏障，开始三大绘制流程
postCallback
Android 4.1 之后系统默认开启 VSYNC，在 Choreographer 的构造方法会创建一个 FrameDisplayEventReceiver，scheduleVsyncLocked 方法将会通过它申请 VSYNC 信号。在 DisplayEventReceiver 的构造方法会通过 JNI 创建一个 IDisplayEventConnection 的 VSYNC 的监听者。
VSYNC信号的接受回调是onVsync()，使用mHandler发送消息到MessageQueue中 执行本次的doFrame(),这个message的Runnable就是队列中的所有任务。
3.申请VSync信号接收到后是走 doFrame()方 执行任务是 CallbackRecord的 run 方法：
Choregrapher 注册一个 FrameCallback 回调，那么系统在每一帧开始绘制的时候，会通过
FrameCallback#doFrame(...) 回调出来。我们一般画面的 fps 一般是 60fps，在这个回调中计算对应的 fps 即可。
如果绘制时间超过16.6ms，计算丢掉的帧数
https://juejin.cn/post/6863756420380196877#heading-17
https://ljd1996.github.io/2020/09/07/Android-Choreographer%E5%8E%9F%E7%90%86/

### 16.4.卡顿优化

https://www.jianshu.com/p/03dd61816051
https://juejin.cn/post/6844904066259091469#heading-31
https://blog.yorek.xyz/android/paid/master/stuck_1/#systrace
https://www.jianshu.com/p/75aa88d1b575
https://blog.csdn.net/JArchie520/article/details/106710663#1.1%E3%80%81%E5%8D%A1%E9%A1%BF%E9%97%AE%E9%A2%98%E4%BB%8B%E7%BB%8D
https://www.jianshu.com/p/03dd61816051

**卡顿原因**

FPS（帧率）：每秒显示帧数（Frames per Second）。表示图形处理器每秒钟能够更新的次数。高的帧率可以得到更流畅、更逼真的动画。一般来说12fps大概类似手动快速翻动书籍的帧率，这明显是可以感知到不够顺滑的。 提升至60fps则可以明显提升交互感和逼真感

开发app的性能目标就是保持60fps，这意味着每一帧你只有16ms≈1000/60的时间来处理所有的任务。Android系统每隔16ms发出VSYNC信号，触发对UI进行渲染，如果每次渲染都成功，这样就能够达到流畅的画面所需要的60fps。

android中某个操作花费时间是24ms，系统在得到VSYNC信号的时候就无法进行正常渲染，这样就发生了丢帧现象。那么用户在32ms内看到的会是同一帧画面。就会感觉到界面不流畅了（卡了一下）。丢帧导致卡顿产生。
卡顿优化就是监控和分析由于哪些因素的影响导致绘制渲染任务没有在一个vsync的时间内完成。尤其关注连续丢帧点。
卡顿产生的原因是错综复杂的，它涉及到代码、内存、绘制、IO、CPU等等

**卡顿监控**

1.BlockCanary: 动态检测消息执行耗时。 基于消息机制，向Looper中设置Printer，监控dispatcher到finish之间的操作，满足耗时阀值dump堆栈、设备信息，以通知形式弹出卡顿信息以供分析 非侵入式的性能监控组件，通知形式弹出卡顿信息 
AndroidPerformanceMonitor 

```groovy
implementation 'com.github.markzhai:blockcanary-android:1.5.0'
```

https://github.com/markzhai/AndroidPerformanceMonitor

2.ANR
ANR-WatchDog

3.单点问题监控
打开页面从onCreate到onWindowFocusChanged耗时统计 Activity/Fragement 生命周期耗时统计 我们也需要去监控生命周期的一个耗时，如onCreate、onStart、onResume等 我们也需要去做生命周期间隔的耗时监 用AOP方式进行非侵入式打点通过这三个方面的监控纬度，我们就能够非常细粒度地去检测页面秒开各个方面的情况。 
自己代码：https://github.com/eleme/lancet 非one way的binder IPC调用耗时统计 （hook BinderProxy.transact）,
这类统计可以采用AOP方式进行非侵入式打点。 hook art：Epic hook

**卡顿分析**
卡顿工具 AndroidPerformanceMonitor ANR-WatchDog
原因 https://blog.csdn.net/axi295309066/article/details/72675365
解决 https://juejin.cn/post/6844904066259091469

### 16.5.网络优化

http://www.odev.top/2020/06/29/Top%E5%9B%A2%E9%98%9F%E5%A4%A7%E7%89%9B%E5%B8%A6%E4%BD%A0%E7%8E%A9%E8%BD%ACAndroid%E6%80%A7%E8%83%BD%E5%88%86%E6%9E%90%E4%B8%8E%E4%BC%98%E5%8C%96/#Java%E5%86%85%E5%AD%98%E5%9B%9E%E6%94%B6%E7%AE%97%E6%B3%95
https://juejin.cn/post/6861856444032466952#heading-0

1.流量维度
流量消耗过多

自定义事件监听器
请求次数
1. 数据缓存 
2.  数据压缩 
3.  图片压缩

2.质量维度
模拟数据
弱网模拟

## 17.Window&WindowManager

https://blog.csdn.net/my_csdnboke/article/details/106685736

### 17.1.什么是Window

视图承载器，是一个视图的顶层窗口， 包含了View并对View进行管理, 是一个抽象类，具体的实现类为PhoneWindow,内部持有DecorView。 通过WindowManager创建，并通过WindowManger将DecorView添加进来。

### 17.2.什么是WindowManager

WindowManager是一个接口，继承自只有添加、删除、更新三个方法的ViewManager接口。 它的实现类为WindowManagerImpl，WindowManagerImpl通过WindowManagerGlobal代理实现addView， 最后调用到ViewRootImpl的setView 使ViewRoot和Decorview相关联。如果要对Window进行添加和删除就需要使用WindowManager， 具体的工作则由WMS来处理，WindowManager和WMS通过Binder来进行跨进程通信。

### 17.3.什么是ViewRootImpl

ViewRoot是View和WindowManager的桥梁，View通过WindowManager来转接调用ViewRootImpl View的三大流程(测量（measure），布局（layout），绘制（draw）)均通过ViewRoot来完成。 Android的所有触屏事件、按键事件、界面刷新等事件都是通过ViewRoot进行分发的。

### 17.4.什么是DecorView

DecorView是FrameLayout的子类，它可以被认为是Android视图树的根节点视图, 一般情况下它内部包含一个竖直方向的LinearLayout，在这个LinearLayout里面有上下三个部分， 上面是个ViewStub,延迟加载的视图（应该是设置ActionBar,根据Theme设置）， 中间的是标题栏(根据Theme设置，有的布局没有)，下面的是内容栏。
setContentView就是把需要添加的View的结构添加保存在DecorView中。

### 17.5.Activity、View、Window三者之间的关系

Activity并不负责视图控制，它只是控制生命周期和处理事件，Activity中持有的是Window，Window是视图的承载器，内部持有一个 DecorView，而这个DecorView才是 view 的根布局
View就是视图,在setContentView中将R.layout.activity_main添加到DecorView。

### 17.6.DecorView什么时候被WindowManager添加到Window中

即使Activity的布局已经成功添加到DecorView中，DecorView此时还没有添加到Window中
ActivityThread的handleResumeActivity方法中，首先会调用Activity的onResume方法，接着调用Activity的makeVisible()方法
makeVisible()中完成了DecorView的添加和显示两个过程

## 18.AMS

### 18.1.ActivityManagerService是什么？什么时候初始化的？有什么作用？

ActivityManagerService 主要负责系统中四大组件的启动、切换、调度及应用进程的管理和调度等工作，其职责与操作系统中的进程管理和调度模块类似。

ActivityManagerService进行初始化的时机很明确，就是在SystemServer进程开启的时候，就会初始化

ActivityManagerService。（系统启动流程）
如果打开一个App的话，需要AMS去通知zygote进程， 所有的Activity的生命周期AMS来控制

### 18.2.ActivityThread是什么?ApplicationThread是什么?他们的区别

ActivityThread
在Android中它就代表了Android的主线程,它是创建完新进程之后,main函数被加载，然后执行一个loop的循环使当前线程进入消息循环，并且作为主线程。

ApplicationThread
ApplicationThread是ActivityThread的内部类， 是一个Binder对象。在此处它是作为IApplicationThread对象的server端等待client端的请求然后进行处理，最大的client就是AMS。

### 18.3.Instrumentation是什么？和ActivityThread是什么关系？

AMS与ActivityThread之间诸如Activity的创建、暂停等的交互工作实际上是由Instrumentation具体操作的。每个Activity都持有一个Instrumentation对象的一个引用， 整个进程中是只有一个Instrumentation。
mInstrumentation的初始化在ActivityThread::handleBindApplication函数。
可以用来独立地控制某个组件的生命周期。

Activity的`startActivity`方法会调用`mInstrumentation.execStartActivity();
mInstrumentation 调用 AMS , AMS 通过 socket 通信告知 Zygote 进程 fork 子进程。

### 18.4.ActivityManagerService和zygote进程通信是如何实现的。

应用启动时,Launcher进程请求AMS。 AMS发送创建应用进程请求，Zygote进程接受请求并fork应用进程
客户端发送请求
调用 Process.start() 方法新建进程
连接调用的是 ZygoteState.connect() 方法，ZygoteState 是 ZygoteProcess 的内部类。ZygoteState里用的LocalSocket
```java
public static ZygoteState connect(LocalSocketAddress address) throws IOException {
    DataInputStream zygoteInputStream = null;
    BufferedWriter zygoteWriter = null;
    final LocalSocket zygoteSocket = new LocalSocket();
    try {
        zygoteSocket.connect(address);
        zygoteInputStream = new DataInputStream(zygoteSocket.getInputStream());
        zygoteWriter = new BufferedWriter(new OutputStreamWriter(zygoteSocket.getOutputStream()), 256);
    } catch (IOException ex) {
        try {
            zygoteSocket.close();
        } catch (IOException ignore) {
        }
    	throw ex;
    }
    return new ZygoteState(zygoteSocket, zygoteInputStream, zygoteWriter,Arrays.asList(abiListString.split(",")));
}
```

Zygote 处理客户端请求
Zygote 服务端接收到参数之后调用 ZygoteConnection.processOneCommand() 处理参数，并 fork 进程
最后通过 findStaticMain() 找到 ActivityThread 类的 main() 方法并执行，子进程就启动了  

### 18.5.ActivityRecord、TaskRecord、ActivityStack，ActivityStackSupervisor，ProcessRecord

https://duanqz.github.io/2016-02-01-Activity-Maintenance#activityrecord
https://www.jianshu.com/p/94816e52cd77
https://juejin.im/post/6856298463119409165#heading-10

![6163786-fb1b25d71b900a59](https://raw.githubusercontent.com/treech/PicRemote/master/common/6163786-fb1b25d71b900a59.webp)

![1-activity-maintenace-structure](https://raw.githubusercontent.com/treech/PicRemote/master/common/1-activity-maintenace-structure.png)

**ActivityRecord**
Activity管理的最小单位，它对应着一个用户界面
ActivityRecord是应用层Activity组件在AMS中的代表，每一个在应用中启动的Activity，在AMS中都有一个ActivityRecord实例来与之对应，这个ActivityRecord伴随着Activity的启动而创建，也伴随着Activity的终止而销毁。

**TaskRecord**
TaskRecord即任务栈， 每一个TaskRecord都可能存在一个或多个ActivityRecord，栈顶的ActivityRecord表示当前可见的界面。
一个App是可能有多个TaskRecord存在的
一般情况下,启动App的第一个activity时，AMS为其创建一个TaskRecord任务栈
特殊情况,启动singleTask的Activity，而且为该Activity指定了和包名不同的taskAffinity， 也会为该activity创建一个新的TaskRecord

**ActivityStack**
ActivityStack,ActivityStack是系统中用于管理TaskRecord的,内部维护了一个ArrayList。
ActivityStackSupervisor内部有两个不同的ActivityStack对象：mHomeStack、mFocusedStack，用来管理不同的任务。
我们启动的App对应的TaskRecord由非Launcher ActivityStack管理，它是在系统启动第一个app时创建的。

**ActivityStackSupervisor**
ActivityStackSupervisor管理着多个ActivityStack，但当前只会有一个获取焦点(Focused)的ActivityStack;
AMS对象只会存在一个，在初始化的时候，会创建一个唯一的ActivityStackSupervisor对象

**ProcessRecord**
ProcessRecord记录着属于一个进程的所有ActivityRecord，运行在不同TaskRecord中的ActivityRecord可能是属于同一个 ProcessRecord。

**关系**

![2-activity-maintenace-relationship](https://raw.githubusercontent.com/treech/PicRemote/master/common/2-activity-maintenace-relationship.png)

AMS运行在SystemServer进程中。SystemServer进程启动时，会通过SystemServer.startBootstrapServices()来创建一个AMS的对象;

AMS通过ActivityStackSupervisor来管理Activity。AMS对象只会存在一个，在初始化的时候，会创建一个唯一的ActivityStackSupervisor对象;

ActivityStackSupervisor中维护了显示设备的信息。当有新的显示设备添加时，会创建一个新的ActivityDisplay对象;

ActivityStack与显示设备的绑定。ActivityStack的创建是在Launcher启动时候进行的， AMS还未有非Launcher的ActivityStack。后面的App启动时就会创建Launcher的ActivityStack，
通过ActivityStackSupervisor来创建ActivityRecord
在ActivityStack上创建TaskRecord
每一个ActivityRecord都需要找到自己的宿主TaskRecord

从桌面启动

![6163786-c2f135eb9140fe95](https://raw.githubusercontent.com/treech/PicRemote/master/common/6163786-c2f135eb9140fe95.webp)

从桌面点击图标启动一个Activity， 会启动ActivityStackSupervisor中的mFocusedStack，mFocusedStack负责管理的是非Launcher相关的任务。同时也会创建一个新的ActivityRecord和TaskRecord，ActivityRecord放到TaskRecord中，TaskRecord则放进mFocusedStack中。  

**四种启动模式**

https://blog.csdn.net/u011810352/article/details/79378632

**standerd**

> 默认模式，每次启动Activity都会创建一个新的Activity实例

![1](https://raw.githubusercontent.com/treech/PicRemote/master/common/1.png)

**singleTop**

> 如果要启动的Activity已经在栈顶，则不会重新创建Activity，只会调用该该Activity的onNewIntent()方法。
如果要启动的Activity不在栈顶，则会重新创建该Activity的实例。  

![2](https://raw.githubusercontent.com/treech/PicRemote/master/common/2.png)

![3](https://raw.githubusercontent.com/treech/PicRemote/master/common/3.png)

**singleTask**

> 如果要启动的Activity已经存在于它想要归属的栈中，那么不会创建该Activity实例，将栈中位于该Activity上的所有的Activity出栈，同时该Activity的onNewIntent()方法会被调用。  

![4](https://raw.githubusercontent.com/treech/PicRemote/master/common/4.png)

**singleInstance**
> 要创建在一个新栈，然后创建该Activity实例并压入新栈中，新栈中只会存在这一个Activity实例  

![5](https://raw.githubusercontent.com/treech/PicRemote/master/common/5.png)

### 18.6.ActivityManager、ActivityManagerService、

ActivityManagerNative、ActivityManagerProxy的关系
https://www.cnblogs.com/mingfeng002/p/10650364.html

Activity 的 startActivity 方法。 startActivity 会调用 mInstrumentation.execStartActivity();
execStartActivity 通过 ActivityManager 的 getService 。  

代码层面:

ActivityManager.getRunningServices里通过ActivityManagerNative.getDefault得到此代理对象
ActivityManagerProxy，ActivityManagerProxy代理类是ActivityManagerNative的内部类。ActivityManagerNative
是个抽象类，真正发挥作用的是它的子类ActivityManagerService。

介绍:

ActivityManager

ActivityManager官方介绍：是与系统所有正在运行着的Acitivity进行交互，对系统所有运行中的Activity相关信息（Task，Memory，Service，App）进行管理和维护。

ActivityManagerNative、ActivityManagerProxy

IActivityManager继承了Interface接口。而ActivityManagerNative和ActivityManagerPorxy实现了这个IActivityManager接口

ActivityManagerProxy代理类是ActivityManagerNative的内部类；

ActivityManagerNative是个抽象类，真正发挥作用的是它的子类ActivityManagerService

ActivityManager持有的是这个ActivityManagerPorxy代理对象，这样，只需要操作这个代理对象就能操作其业务实现的方法。那么真正实现其也业务的则是ActivityManagerService。

ActivityManagerNative这个类，他继承了Binder而Binder实现了IBinder接口。其子类则是
ActivityManagerService。

![363274-20190403173612401-1955391130](https://raw.githubusercontent.com/treech/PicRemote/master/common/363274-20190403173612401-1955391130.jpg)

### 18.7.手写实现简化版AMS

AMS与Binder相关，其中要明白下面几个类的职责:
IBinder：跨进程通信的Base接口，它声明了跨进程通信需要实现的一系列抽象方法，实现了这个接口就说明可以进行跨进程通信，所有的Binder实体都必须实现IBinder接口。
IInterface：这也是一个Base接口，用来表示Server提供了哪些能力，是Client和Server通信的协议，Client和Server都要实现此接口。
Binder：IBinder的子类，Java层提供服务的Server进程持有一个Binder对象从而完成跨进程间通信。
BinderProxy：在Binder.java这个文件中还定义了一个BinderProxy类，这个类表示Binder代理对象它同样实现了IBinder接口。Client中拿到的实际上是这个代理对象。
1、首先定义IActivityManager接口(继承IInterface)

```java
public interface IActivityManager extends IInterface {
    //binder描述符
    String DESCRIPTOR = "android.app.IActivityManager";
    //方法编号
    int TRANSACTION_startActivity = IBinder.FIRST_CALL_TRANSACTION + 0;
    //声明一个启动activity的方法，为了简化，这里只传入intent参数
    int startActivity(Intent intent) throws RemoteException;
}
```

2、实现ActivityManagerService侧的本地Binder对象基类

```java
public abstract class ActivityManagerNative extends Binder implements IActivityManager {
    public static IActivityManager asInterface(IBinder obj) {
        if (obj == null) {
        	return null;
        } 
        IActivityManager in = (IActivityManager)
        obj.queryLocalInterface(IActivityManager.DESCRIPTOR);
        if (in != null) {
        	return in;
        } 
        //代理对象，见下面的代码
        return new ActivityManagerProxy(obj);
    } 
    
    @Override
    public IBinder asBinder() {
        return this;
    } 
    
    @Override
    protected boolean onTransact(int code, Parcel data, Parcel reply, int flags) throws RemoteException {
        switch (code) {
                // 获取binder描述符
            case INTERFACE_TRANSACTION:
                reply.writeString(IActivityManager.DESCRIPTOR);
                return true;
                // 启动activity，从data中反序列化出intent参数后，直接调用子类startActivity方法启动activity。
            case IActivityManager.TRANSACTION_startActivity:
                data.enforceInterface(IActivityManager.DESCRIPTOR);
                Intent intent = Intent.CREATOR.createFromParcel(data);
                int result = this.startActivity(intent);
                reply.writeNoException();
                reply.writeInt(result);
                return true;
        } 
        return super.onTransact(code, data, reply, flags);
    }
}
```

3、实现Client侧的代理对象

```java
public class ActivityManagerProxy implements IActivityManager {
    private IBinder mRemote;
    @Override
    public int startActivity(Intent intent) throws RemoteException {
        Parcel data = Parcel.obtain();
        Parcel reply = Parcel.obtain();
        int result;
        try {
            // 将intent参数序列化，写入data中
            intent.writeToParcel(data, 0);
            // 调用BinderProxy对象的transact方法，交由Binder驱动处理。
            mRemote.transact(IActivityManager.TRANSACTION_startActivity, data, reply, 0);
            reply.readException();
            // 等待server执行结束后，读取执行结果
            result = reply.readInt();
        } finally {
            data.recycle();
            reply.recycle();
    	} 
        return result;
    }
}
```

4、实现Binder本地对象（IActivityManager接口）

```java
public class ActivityManagerService extends ActivityManagerNative {
    @Override
    public int startActivity(Intent intent) throws RemoteException {
        // 启动activity
        return 0;
    }
}
```

## 19.系统启动

### 19.1.Android系统启动流程

Android系统框架分为应用层，framework层，系统运行库层（Native)，Linux内核层 启动按照一个流程：Loader->kernel->framework->Application来进行的
**1.Bootloader引导**

- 当电源按下时，引导芯片代码 从 ROM (4G)开始执行。Bootloader引导程序把操作系统镜像文件拷贝到RAM中去，然后跳转到它的入口处去执行，启动Linux内核。
- Linux kernel 内核启动,会做设置缓存,加载驱动等一些列操作
- 当内核启动完成之后,启动 init 进程,作为第一个系统进程, init 进程从内核态转换成用户态。

**2.init进程启动**

- fork 出 ServerManager 子进程。 ServerManager主要用于管理我们的系统服务，他内部存在一个server服务列表，这个列表中存储的就是那些已经注册的系统服务。
- 解析 init.rc 配置文件并启动 Zygote 进程

**3.Zygote进程启动**

- 孵化其他应用程序进程，所有的应用的进程都是由zygote进程fork出来的。 通过创建服务端Socket,等待AMS的请求来创建新的应用程序进程。
- 创建SystemServer进程,在Zygote进程启动之后,会通过ZygoteInit的main方法fork出SystemServer进程

**4.SystemServer进程启动**

- 创建SystemServiceManager，它用来对系统服务进行创建、启动和生命周期管理。
- ServerManager.startService启动各种系统服务：WMS/PMS/AMS等，调用ServerManager的addService方法将这些Service服务注册到ServerManager里面
- 启动桌面进程，这样才能让用户见到手机的界面。

**5.Launcher进程启动**
- 开启系统Launcher程序来完成系统界面的加载与显示。

**各个进程的先后顺序**

init进程 --> Zygote进程 --> SystemServer进程 -->各种应用进程

![xitongqidong1](https://raw.githubusercontent.com/treech/PicRemote/master/common/xitongqidong1.png)

### 19.2.SystemServer，ServiceManager，SystemServiceManager的关系

在SystemServer进程中创建SystemServiceManager, ServiceManager是系统服务管理者,SysytemServiceManager启动一些继承自SystemService的服务，并将这些服务的Binder注册到ServiceManager中，对于其他的一些继承于IBinder的服务,通过ServiceMaanager的addService方法添加

SystemServer：

SystemServer是一个由zygote孵化出来的进程， 名字为system_server 。
SystemServer叫做系统服务进程，大部分Android提供的一些系统服务都运行在该进程中,包括AMS、WMS、PMS，这些系统的服务都是以一个线程的方式存在在SysyemServer进程中。

SystemServiceManager：

管理一些系统的服务，在SystemServer中初始化。启动各种系统服务：WMS、PMS、AMS等，调用ServerManager的addService方法将这些Service服务注册到ServerManager里面

ServiceManager：

 ServiceManager像是一个路由，Service把自己注册在ServiceManager中，客户端通过ServiceManager查询服务

 1、维护一个svclist列表来存储service信息。

 2、向客户端提供Service的代理，也就是BinderProxy。

 3、维护一个死循环，不断的查看是否有service的操作请求，如果有就读取相应的内核binder driver。


### 19.3.孵化应用进程这种事为什么不交给SystemServer来做，而专门设计一个Zygote

- Zygote进程是所有Android进程的母体，包括system_server和各个App进程。zygote利用fork()方法生成新进程，对于新进程A复用Zygote进程本身的资源，再加上新进程A相关的资源，构成新的应用进程A。应用在启动的时候需要做很多准备工作，包括启动虚拟机，加载各类系统资源等等，这些都是非常耗时的，如果能在zygote里就给这些必要的初始化工作做好，子进程在fork的时候就能直接共享，那么这样的话效率就会非常高
- SystemServer里跑了一堆系统服务，这些不能继承到应用进程

### 19.4.Zygote的IPC通信机制为什么使用socket而不采用binder
- Zygote是通过fork生成进程的
- 因为fork只能拷贝当前线程，不支持多线程的fork，fork的原理是copy-on-write机制，当父子进程任一方修改内存数据时（这是on-write时机），才发生缺页中断，从而分配新的物理内存（这是copy操作）。zygote进程中已经启动了虚拟机、进行资源和类的预加载以及各种初始化操作，App进程用时拷贝即可。Zygote fork出来的进程A只有一个线程，如果Zygote有多个线程，那么A会丢失其他线程。这时可能造成死锁。
- Binder通信需要使用Binder线程池,binder维护了一个16个线程的线程池，fork()出的App进程的binder通信没法用。

## 20.App启动&打包&安装

### 20.1.应用启动流程

**1.Launcher进程请求AMS**
点击图标发生在 Launcher 应用的进程,实际上执行的是 Launcher 的 onClick 方法，在 onClick 里面会执行到Activity 的 startActivity 方法。 startActivity 会调mInstrumentation.execStartActivity();
execStartActivity 通过 ActivityManager 的 getService 方法来得到 AMS 的代理对象( Launcher 进程作为客户端与服务端 AMS 不在同一个进程, ActivityManager.getService 返回的是 IActivityManager.Stub 的代理对象,此时如果要实现客户端与服务端进程间的通信， 需要 AMS 继承 IActivityManager.Stub 类并实现相应的方法,这样Launcher进程作为客户端就拥有了服务端AMS的代理对象，然后就可以调用AMS的方法来实现具体功能了)

**2. AMS发送创建应用进程请求，Zygote进程接受请求并fork应用进程**
AMS 通过 socket 通信告知 Zygote 进程 fork 子进程。
应用进程启动 ActivityThread ,执行 ActivityThread 的 main 方法。
main 方法中创建 ApplicationThread ， Looper ， Handler 对象，并开启主线程消息循环 Looper.loop() 

**3.App进程通过Binder向AMS(sytem_server)发起attachApplication请求,AMS绑定
ApplicationThread**
在 ActivityThread 的 main 中,通过 ApplicationThread.attach(false, startSeq) ,将 AMS 绑定
ApplicationThread 对象,这样 AMS 就可以通过这个代理对象 来控制应用进程。

**4.AMS发送启动Activity的请求**
system_server 进程在收到请求后，进行一系列准备工作后，再通过 binder 向App进程发送
scheduleLaunchActivity 请求； AMS 将启动 Activity 的请求发送给 ActivityThread 的 Handler

**5.ActivityThread的Handler处理启动Activity的请求**
`App`进程的`binder`线程（`ApplicationThread`）在收到请求后，通过`handler`向主线程发送`LAUNCH_ACTIVITY`消息； 主线程在收到`Message`后，通过发射机制创建目标`Activity`，并回调`Activity.onCreate()`等方法。 到此，`App`便正式启动，开始进入`Activity`生命周期，执行完`onCreate/onStart/onResume`方法，`UI`渲染结束后便可以看到`App`的主界面。

![yingyongqidong1](https://raw.githubusercontent.com/treech/PicRemote/master/common/yingyongqidong1.png)



### 20.2.apk组成和Android的打包流程?  

![image](https://raw.githubusercontent.com/treech/PicRemote/master/common/image.png)


resources.arsc 编译后的二进制资源文件。

classes.dex 是.dex文件。最终生成的Dalvik字节码

AndroidManifest.xml  程序的全局清单配置文件

res是uncompiled resources。存放资源文件的目录。

META-INF是签名文件夹。 存放签名信息

MANIFEST.MF（清单文件）：其中每一个资源文件都有一个SHA-256-Digest签名，MANIFEST.MF文件的SHA256（SHA1）并base64编码的结果即为CERT.SF中的SHA256-Digest-Manifest值。

CERT.SF（待签名文件）：除了开头处定义的SHA256（SHA1）-Digest-Manifest值，后面几项的值是对MANIFEST.MF文件中的每项再次SHA256并base64编码后的值。

CERT.RSA（签名结果文件）：其中包含了公钥、加密算法等信息。首先对前一步生成的MANIFEST.MF使用了SHA256（SHA1）-RSA算法，用开发者私钥签名，然后在安装时使用公钥解密。最后，将其与未加密的摘要信息（MANIFEST.MF文件）进行对比，如果相符，则表明内容没有被修改。


APK编译打包过程

- 1、aapt （Android Asset Packaging Tool）打包资源文件，生成R.java文件（使用工具AAPT）
- 2、处理AIDL文件，生成java代码（没有AIDL则忽略）
- 3、编译 java 文件，生成对应.class文件（java compiler）
- 4、.class 文件转换成dex文件（dex）
- 5、打包成没有签名的apk（使用工具apkbuilder）
- 6、使用签名工具给apk签名（使用工具Jarsigner）
- 7、对签名后的.apk文件进行对齐处理，不进行对齐处理不能发布到Google
    Market（使用工具zipalign）

具体说来：

- 通过AAPT工具进行资源文件（包括AndroidManifest.xml、布局文件、各种xml资源等）的打包，生成R.java文件。
- 通过AIDL工具处理AIDL文件，生成相应的Java文件。
- 通过Java Compiler编译R.java、Java接口文件、Java源文件，生成.class文件。
- 通过dex命令，将.class文件和第三方库中的.class文件处理生成classes.dex，该过程主要完成Java字节码转换成Dalvik字节码，压缩常量池以及清除冗余信息等工作。
- 通过ApkBuilder工具将资源文件、DEX文件打包生成APK文件。
- 通过Jarsigner工具，利用KeyStore对生成的APK文件进行签名。
- 如果是正式版的APK，还会利用ZipAlign工具进行对齐处理，对齐的过程就是将APK文件中所有的资源文件距离文件的起始距位置都偏移4字节的整数倍，这样通过内存映射访问APK文件的速度会更快，并且会减少其在设备上运行时的内存占用。


assets和res/raw这两个文件目录里的文件都会直接在打包apk的时候直接打包到apk中，携带在应用里面供应用访问，而且不会被编译成二进制；

     他们的不同点在于：
     1、assets中的文件资源不会映射到R中，而res中的文件都会映射到R中，所以raw文件夹下的资源都有对应的ID;
     2、assets可以能有更深的目录结构，而res/raw里面只能有一层目录；
     3、资源存取方式不同，assets中利用AssetsManager，而res/raw直接利用getResource()，openRawResource(R.raw.fileName),很  多人认为是R.id.filename,其实正确的是R.raw.filename,就像R.drawable.filename一样，整体表示一个ID值，并非是R.id.filename;

### 20.3.Android的签名机制，签名如何实现的,v2相比于v1签名机制的改变

https://blog.csdn.net/freekiteyu/article/details/84849651


**签名工具**

Android 应用的签名工具有两种：jarsigner 和 signAPK。
它们的签名算法没什么区别，主要是签名使用的文件不同

jarsigner：jdk 自带的签名工具，可以对 jar 进行签名。使用 keystore 文件进行签名。生成的签名文件默认使用 keystore 的别名命名。

signAPK：Android sdk 提供的专门用于 Android 应用的签名工具。
signapk.jar是Android源码包中的一个签名工具。代码位于Android源码目录下，signapk.jar 可以编译build/tools/signapk/ 得到。
使用 pk8、x509.pem 文件进行签名。其中 pk8 是私钥文件，x509.pem 是含有公钥的文件。生成的签名文件统一使用“CERT”命名。

**jarsigner和apksigner的区别**

Android提供了两种对Apk的签名方式，一种是基于JAR的签名方式，另一种是基于Apk的签名方式，它们的主要区别在于使用的签名文件不一样：
jarsigner使用keystore文件进行签名；
apksigner除了支持使用keystore文件进行签名外，还支持直接指定pem证书文件和私钥进行签名。


**签名过程**


APK是先摘要，再签名

要了解如何实现签名，需要了解两个基本概念：数字摘要和数字证书。


**数字摘要**

就是对消息数据，通过一个Hash算法计算后，都可以得到一个固定长度的Hash值，这个值就是消息摘要。

特征：
唯一性
固定长度：比较常用的Hash算法有MD5和SHA1，MD5的长度是128拉，SHA1的长度是160位。
不可逆性

消息摘要只能保证消息的完整性，并不能保证消息的不可篡改性

**数字签名**

 在摘要的基础上再进行一次加密，对摘要加密后的数据就可以当作数字签名。利用非对称加密技术，通过私钥对摘要进行加密，产生一个字符串，如RSA就是常用的非对称加密算法。在没有私钥的前提下，非对称加密算法能确保别人无法伪造签名，因此数字签名也是对发送者信息真实性的一个有效证明。不过由于Android的keystore证书是自签名的，没有第三方权威机构认证，用户可以自行生成keystore，Android签名方案无法保证APK不被二次签名。


**签名和校验的主要过程**

选取一个签名后的 APK（Sample-release.APK）解压,在 META-INF 文件夹下有三个文件：MANIFEST.MF、CERT.SF、CERT.RSA。它们就是签名过程中生成的文件


**MANIFEST.MF**

逐一遍历 APK 中的所有条目，如果是目录就跳过，如果是一个文件，就用 SHA1（或者 SHA256）消息摘要算法提取出该文件的摘要然后进行 BASE64 编码。
分别用Name和SHA1-Digest记录

![app3](https://raw.githubusercontent.com/treech/PicRemote/master/common/app3.png)

**CERT.SF**

SHA1-Digest：对 MANIFEST.MF 的各个条目做 SHA1（或者 SHA256）后再用 Base64 编码

![app4](https://raw.githubusercontent.com/treech/PicRemote/master/common/app4.png)

**CERT.RSA**

之前生成的 CERT.SF 文件，用私钥计算出签名, 然后将签名以及包含公钥信息的数字证书一同写入 CERT.RSA 中保存

**签名过程：**

1、计算摘要：

通过Hash算法提取出原始数据的摘要。

2、计算签名：

再通过基于密钥（私钥）的非对称加密算法对提取出的摘要进行加密，加密后的数据就是签名信息。

3、写入签名：

将签名信息写入原始数据的签名区块内。


**校验过程：**

签名验证是发生在APK的安装过程中


1、计算摘要

首先用同样的Hash算法从接收到的数据中提取出摘要。

2、解密签名：

使用发送方的公钥对数字签名进行解密，解密出原始摘要。

3、比较摘要：

如果解密后的数据和提取的摘要一致，则校验通过；如果数据被第三方篡改过，解密后的数据和摘要将会不一致，则校验不通过。

![app1](https://github.com/treech/PicRemote/blob/master/common/app1.png?raw=true)

**Android Apk V1 签名过程**

![app2](https://github.com/treech/PicRemote/blob/master/common/app2.png?raw=true)

**Android Apk V1 校验过程**

1、解析出 CERT.RSA 文件中的证书、公钥，解密 CERT.RSA 中的加密数据。
2、解密结果和 CERT.SF 的指纹进行对比，保证 CERT.SF 没有被篡改。
3、而 CERT.SF 中的内容再和 MANIFEST.MF 指纹对比，保证 MANIFEST.MF 文件没有被篡改。
4、MANIFEST.MF 中的内容和 APK 所有文件指纹逐一对比，保证 APK 没有被篡改。



**v2相比于v1签名机制的改变**

v1 签名机制的劣势

签名校验速度慢

校验过程中需要对apk中所有文件进行摘要计算，在 APK 资源很多、性能较差的机器上签名校验会花费较长时间，导致安装速度慢。

完整性保障不够

META-INF 目录用来存放签名，自然此目录本身是不计入签名校验过程的，可以随意在这个目录中添加文件


1.V2计算加快签名速度

![app5](https://raw.githubusercontent.com/treech/PicRemote/master/common/app5.png)

就是把 APK 按照 1M 大小分割，分别计算这些分段的摘要，最后把这些分段的摘要在进行计算得到最终的摘要也就是 APK 的摘要。然后将 APK 的摘要 + 数字证书 + 其他属性生成签名数据写入到 APK Signing Block 区块



2.V2保证META-INFO目录不会被篡改

v2 签名模式在原先 APK 块中增加了一个新的块（签名块），新的块存储了签名，摘要，签名算法，证书链，额外属性等信息

为了保护 APK 内容，整个 APK（ZIP文件格式）被分为以下 4 个区块：

头文件区、
V2签名块、
中央目录、
尾部。


 应用签名方案的签名信息会被保存在 区块 2（APK Signing Block）中，而区块 1（Contents of ZIP entries）、区块 3（ZIP Central Directory）、区块 4（ZIPEnd of Central Directory）是受保护的，在签名后任何对区块 1、3、4 的修改都逃不过新的应用签名方案的检查。

**数字证书**

如果数字签名和公钥一起被篡改，接收方无法得知，还是会校验通过。

如何保证公钥的可靠性呢？

 证书授权机构——CA，小明去CA机构申请证书，将小明的个人信息、公钥生成一个证书，然后把这个证书发送给jack，jack拿这个证书去证书授权机构查询，如果能匹配上小明的信息，就说明这个证书是小明的，就可以使用证书中的公钥来解密小明的消息。

接收方收到消息后，先向CA验证证书的合法性，再进行签名校验。

注意：Apk的证书通常是自签名的，也就是由开发者自己制作，没有向CA机构申请。Android在安装Apk时并没有校验证书本身的合法性，只是从证书中提取公钥和加密算法，这也正是对第三方Apk重新签名后，还能够继续在没有安装这个Apk的系统中继续安装的原因。

**keystore**

keystore文件中包含了私钥、公钥和数字证书。


**除了要指定keystore文件和密码外，也要指定alias和key的密码，这是为什么呢？**

keystore是一个密钥库，也就是说它可以存储多对密钥和证书，keystore的密码是用于保护keystore本身的，一对密钥和证书是通过alias来区分的

### 20.4.APK的安装流程


复制APK到/data/app目录下，解压并扫描安装包。

资源管理器解析APK里的资源文件。

解析AndroidManifest文件，并在/data/data/目录下创建对应的应用数据目录。

然后对dex文件进行优化，并保存在dalvik-cache目录下。

将AndroidManifest文件解析出的四大组件信息注册到PackageManagerService中。

安装完成后，发送广播。

![app6](https://raw.githubusercontent.com/treech/PicRemote/master/common/app6.png)

## 21.序列化  

### 21.1.什么是序列化

Java序列化是指把Java对象转换为字节序列的过程

Java反序列化是指把字节序列恢复为Java对象的过程；

### 21.2.为什么需要使用序列化和反序列化

   不同进程/程序间进行远程通信时，可以相互发送各种类型的数据，包括文本、图片、音频、视频等，而这些数据都会以二进制序列的形式在网络上传送。

   当两个Java进程进行通信时，对于进程间的对象传送需要使用Java序列化与反序列化了。发送方需要把这个Java对象转换为字节序列，接收方则需要将字节序列中恢复出Java对象。

### 21.3.序列化的有哪些好处

实现了数据的持久化，通过序列化可以把数据永久地保存到硬盘上（如：存储在文件里），实现永久保存对象。

利用序列化实现远程通信，即：能够在网络上传输对象。

### 21.4.Serializable 和 Parcelable 的区别

 Serializable原理(https://juejin.im/post/6844904049997774856)

 Serializable接口没有方法和属性，只是一个识别类可被序列化的标志。

Serializable是通过I/O读写存储在磁盘上的, 通过反射解析出对象描述、属性的描述
以HandleTable来缓存解析信息,之后解析成二进制，存储、传输。


Parcel原理(https://www.wanandroid.com/wenda/show/9002)

 Parcel翻译过来是打包的意思,其实就是包装了我们需要传输的数据,然后在Binder中传输,也就是用于跨进程传输数据 ,将序列化之后的数据写入到一个共享内存中，其他进程通过Parcel可以从这块共享内存中读出字节流，并反序列化成对象,

它的各种writeXXX方法，在native层都是会调用Parcel.cpp的write方法

**Serializable 和 Parcelable 的区别**

存储媒介的不同(https://www.jianshu.com/p/1b362e374354)

      Serializable 使用 I/O 读写存储在硬盘上，而 Parcelable 是直接 在内存中读写。很明显，内存的读写速度通常大于 IO 读写，所以在 Android 中传递数据优先选择 Parcelable。

效率不同

Serializable 会使用反射，序列化和反序列化过程需要大量 I/O 操作，

Parcelable 自已实现封送和解封（marshalled &unmarshalled）操作不需要用反射，数据也存放在 Native 内存中，效率要快很多。

### 21.5.什么是serialVersionUID

https://cloud.tencent.com/developer/article/1524781

序列化是将对象的状态信息转换为可存储或传输的形式的过程。我们都知道，Java对象是保存在JVM的堆内存中的，也就是说，如果JVM堆不存在了，那么对象也就跟着消失了。

而序列化提供了一种方案，可以让你在即使JVM停机的情况下也能把对象保存下来的方案。就像我们平时用的U盘一样。把Java对象序列化成可存储或传输的形式（如二进制流），比如保存在文件中。这样，当再次需要这个对象的时候，从文件中读取出二进制流，再从二进制流中反序列化出对象。

虚拟机是否允许反序列化，不仅取决于类路径和功能代码是否一致，一个非常重要的一点是两个类的序列化 ID 是否一致，这个所谓的序列化ID，就是我们在代码中定义的serialVersionUID。


### 21.6.为什么还要显示指定serialVersionUID的值?

如果不显示指定serialVersionUID, JVM在序列化时会根据属性自动生成一个serialVersionUID, 然后与属性一起序列化, 再进行持久化或网络传输. 在反序列化时, JVM会再根据属性自动生成一个新版serialVersionUID, 然后将这个新版serialVersionUID与序列化时生成的旧版serialVersionUID进行比较, 如果相同则反序列化成功, 否则报错.

如果显示指定了serialVersionUID, JVM在序列化和反序列化时仍然都会生成一个serialVersionUID, 但值为我们显示指定的值, 这样在反序列化时新旧版本的serialVersionUID就一致了.

在实际开发中, 不显示指定serialVersionUID的情况会导致什么问题? 如果我们的类写完后不再修改, 那当然不会有问题, 但这在实际开发中是不可能的, 我们的类会不断迭代, 一旦类被修改了, 那旧对象反序列化就会报错. 所以在实际开发中, 我们都会显示指定一个serialVersionUID, 值是多少无所谓, 只要不变就行.

## 22.Art & Dalvik 及其区别

https://www.jianshu.com/p/8bb770ec4c48

Android4.4版本以前是Dalvik虚拟机，4.4版本开始引入ART虚拟机（Android Runtime）。在4.4版本上，两种运行时环境共存，可以相互切换，但是在5.0版本以后，Dalvik虚拟机则被彻底的丢弃，全部采用ART。

### 22.1.ART

ART 是一种执行效率更高且更省电的运行机制，执行的是本地机器码，这些本地机器码是从dex字节码转换而来。ART采用的是AOT（Ahead-Of-Time）编译，应用在第一次安装的时候，字节码就会预先编译成机器码存储在本地。在App运行时，ART模式就较Dalvik模式少了解释字节码的过程，所以App的运行效率会有所提高，占用内存也会相应减少。谷哥在5.0以后的Android版本中默认了ART模式启动，就是希望Android能摆脱卡顿这个毛病。

### 22.2.Dalvik

Dalvik 虚拟机采用的是JIT（Just-In-Time）编译模式，意思为即时编译，我们知道apk被安装到手机中时，对应目录会有dex或odex和apk文件，apk文件存储的是资源文件，而dex或odex（经过优化后的dex文件内部存储class文件）内部存储class文件，每次运行app时虚拟机会将dex文件解释翻译成机器码，这样才算是本地可执行代码，之后被系统运行。

Dalvik虚拟机可以看做是一个Java VM，他负责解释dex文件为机器码，如果我们不做处理的话，每次执行代码，都需要Dalvik将dex代码翻译为微处理器指令，然后交给系统处理，这样效率不高。为了解决这个问题，Google在2.2版本添加了JIT编译器，当App运行时，每当遇到一个新类，JIT编译器就会对这个类进行编译，经过编译后的代码，会被优化成相当精简的原生型指令码（即native code），这样在下次执行到相同逻辑的时候，速度就会更快。

**两者的区别**

- Dalvik每次都要编译再运行，Art只会安装时启动编译
- Art占用空间比Dalvik大（原生代码占用的存储空间更大），就是用“空间换时间”
- Art减少编译，减少了CPU使用频率，使用明显改善电池续航
- Art应用启动更快、运行更快、体验更流畅、触感反馈更及时

**总结**

ART、Dalvik、AOT、JIT四个名称的关系：

- JIT代表运行时编译策略，也可以理解成一种运行时编译器，是为了加快Dalvik虚拟机解释dex速度提出的一种技术方案，来缓存频繁使用的本地机器码
- ART和Dalvik都算是一种Android运行时环境，或者叫做虚拟机，用来解释dex类型文件。但是ART是安装时解释，Dalvik是运行时解释
- AOT可以理解为一种编译策略，即运行前编译，ART虚拟机的主要特征就是AOT

## 23.模块化&组件化

###  23.1.什么是模块化

原本一个 App模块 承载了所有的功能，而模块化就是拆分成多个模块放在不同的Module里面，每个功能的代码都在自己所属的 module 中添加

 通常还会有一个通用基础模块module_common，提供BaseActivity/BaseFragment、图片加载、网络请求等基础能力，然后每个业务模块都会依赖这个基础模块。  业务模块之间有有依赖

 但多个模块中肯定会有页面跳转、数据传递、方法调用 等情况，所以必然存在以上这种依赖关系，即模块间有着高耦合度。 高耦合度 加上 代码量大，就极易出现上面提到的那些问题了，严重影响了团队的开发效率及质量。

###  23.2.什么是组件化

组件化，去除模块间的耦合，使得每个业务模块可以独立当做App存在，对于其他模块没有直接的依赖关系。 此时业务模块就成为了业务组件。


###  23.3.组件化优点和方案

加快编译速度：每个业务功能都是一个单独的工程，可独立编译运行，拆分后代码量较少，编译自然变快。

提高协作效率：解耦 使得组件之间 彼此互不打扰，组件内部代码相关性极高。 团队中每个人有自己的责任组件，不会影响其他组件；降低团队成员熟悉项目的成本，只需熟悉责任组件即可；对测试来说，只需重点测试改动的组件，而不是全盘回归测试。

**组件化方案**

https://juejin.cn/post/6844904147641171981

宿主app
在组件化中，app可以认为是一个入口，一个宿主空壳，负责生成app和加载初始化操作。

业务层
每个模块代表了一个业务，模块之间相互隔离解耦，方便维护和复用。

公共层

既然是base，顾名思义，这里面包含了公共的类库。如Basexxx 、 toast,logutil，glide工具类，资源文件等

网络层

提供网络加载

三方库层

提供网络加载

**组件化开发的问题点**

https://juejin.cn/post/6881116198889586701#heading-26

https://www.jianshu.com/p/8b6e6a50e21e

https://juejin.cn/post/6844904147641171981#heading-5

###  23.4.组件独立调试

1.1 gradle.properties中定义一个常量值 isModule
1.2 apply plugin根据boolean值判断

```groovy
if (isModule.toBoolean()){
    apply plugin: 'com.android.application'
}else {
    apply plugin: 'com.android.library'
}
```
1.3 配置 applicationId 和mainfest

###  23.5.组件间通信

跳转

ARouter   

```groovy
1.@Route
2.ARouter.getInstance().build("/xx/xx").navigation()
```

为彼此提供服务

既然首页组件可以访问购物车组件接口了，那就需要依赖购物车组件啊，这俩组件还是耦合

1.首先在commonlib模块里创建一个暴露方法的接口，并定义接口签名，同时继承 Iprovider

2.然后在home模块中继承commonlib里定义的接口，并实现签名方法。

3.Arouter的 @Router注解调用接口

4.然后在home模块中继承commonlib里定义的接口，并实现签名方法。

5.Arouter的 @Router注解调用

###  23.6.Aplication动态加载

组件有时候也需要获取应用的Application，也需要在应用启动时进行初始化。这就涉及到组件的生命周期管理问题。

假设我们有组件ModuleA、ModuleB、ModuleC，这3个组件内分别有ModuleAAppLike、ModuleBAppLike、ModuleCAppLike，那么我们在壳工程集成时，怎么去组装他们呢。最简单的办法是，在壳工程的Application.onCreate()方法里执行

 问题1： 组件初始化的先后顺序，上层业务组件是依赖下层业务组件的， 那么我们在加载组件时，必然要先加载下层组件，否则加载上层组件时可能会出现问题。

 问题2： 新增加一个组件，去修改壳工程代码，不利于代码维护。

解决

1.定义一个注解来标识实现了BaseAppLike的类。

2.通过APT技术，在组件编译时扫描和处理前面定义的注解，生成一个BaseAppLike的代理类

3.组件集成后在应用的Application.onCreate()方法里，调用组件生命周期管理类的初始化方法。

4.组件生命周期管理类的内部，扫描到所有的BaseAppLikeProxy类名之后，通过反射进行类实例化。

难点

需要了解APT技术，怎么在编译时动态生成java代码；

1创建一个注解类
2定义baseapplication接口,设置优先级
3继承AbstractProcessor process中 ，生成代理类，并写入到文件里（StringBuilder 。append）

应用在运行时，怎么能扫描到某个包名下有多少个class，以及他们的名称呢；

 如果有十多个组件里都有实现IAppLike接口的类，最终我们也会生成10多个代理类，这些代理类都是在同一个包下面运行时读取手机里的dex文件，从中读取出所有的class文件名，根据我们前面定义的代理类包名，来判断是不是我们的目标类，这样扫描一遍之后，就得到了固定包名下面所有类的类名了通常一个安装包里，加上第三方库，class文件可能数以千计、数以万计，这让人有点杀鸡用牛刀的感觉。每次应用冷启动时，都要读取一次dex文件并扫描全部class，这个性能损耗是很大的，我们可以做点优化，在扫描成功后将结果缓存下来，下次进来时直接读取缓存文件

 在应用编译成apk时，就已经全量扫描过一次所有的class，并提取出所有实现了IAppLike接口的代理类呢，这样在应用运行时，效率就大大提升了。答案是肯定的，这就是gradle插件、动态插入java字节码技术。


采用gradle插件技术，在应用打包编译时，动态插入字节码来实现

https://www.jianshu.com/p/3ec8e9574aaf
https://github.com/houjinyun/Android-AppLifecycleMgr
https://github.com/hufeiyang/Android-AppLifecycleMgr

1.Gradle Transform在打包前去扫描所有的class文件

Gradle Transform技术，简单来说就是能够让开发者在项目构建阶段即由class到dex转换期间修改class文件

 inputs就是所有扫描到的class文件或者是jar包，一共2种类型
 遍历查找所有的jar包

2.通过ASM动态修改字节码

init方法里找到 AppLifeCycleManager里的addClassFile()方法，我们在这个方法里插入字节码
通过反射创建的实例

###  23.7.ARouter原理

https://juejin.cn/post/6885932290615509000#heading-1

https://juejin.cn/post/6844903648690962446#heading-0

**1.ARouter 路由表生成原理**

@Route注解，会在编译时期通过apt生成一些存储path和activityClass映射关系的类文件

APT是Annotation Processing Tool的简称,即注解处理工具。它是在编译期对代码中指定的注解进行解析，然后做一些其他处理（如通过javapoet生成新的Java文件）

第一步：定义注解处理器，用来在编译期扫描加入@Route注解的类，然后做处理。
这也是apt最核心的一步，新建RouterProcessor 继承自 AbstractProcessor,然后实现process方法。在项目编译期会执行RouterProcessor的process()方法，我们便可以在这个方法里处理Route注解了

第二步：在process()方法里开始生成EaseRouter_Route_moduleName类文件和EaseRouter_Group_moduleName文件。这里在process()里生成文件用javapoet生成java文件，就会用 JavaPoet 生成 Group、Provider 和 Root 路由文件，路由表就是由这些文件组成的，内容loadInto方法通过传入一个特定类型的map就能把分组信息放入map里为，一个map(其实是两个map，一个保存group列表，一个保存group下的路由地址和activityClass关系)保存了路由地址和ActivityClass的映射关系，然后通过map.get("router address") 拿到AcivityClass，通过startActivity()调用就好了


**2.ARouter 路由表加载原理**

https://github.com/Xiasm/EasyRouter/wiki/%E6%A1%86%E6%9E%B6%E7%9A%84%E5%88%9D%E5%A7%8B%E5%8C%96

app进程启动的时候会拿到这些类文件，把保存这些映射关系的数据读到内存里(保存在map里)到这些类文件便可以得到所有的routerAddress---activityClass映射关系

去扫描apk中所有的dex，遍历找到所有包名为packageName的类名，然后将类名再保存到classNames集合里

1. 读取apk中所有的dex文件
2. 然后判断类的包名是否为 “com.alibaba.android.arouter.routes”，获取到注解处理器生成的类名时，就会把这些类名保存 SharedPreferences 中，下次就根据 App 版本判断，如果不是新版本，就从本地中加载类名，否则就用 ClassUtils 读取类名。
3. 就会根据类名的后缀判断类是 IRouteRoot 、IInterceptorGroup 还是 IProviderGroup ，然后根据不同的类把类文件的内容加载到索引中。获取到映射关系

**3.ARouter 跳转原理**

路由跳转的时候，通过build()方法传入要到达页面的路由地址，ARouter会通过它自己存储的路由表找到路由地址对应的Activity.class(activity.class = map.get(path))，然后new Intent()

1.在build的时候，传入要跳转的路由地址，build()方法会返回一个Postcard对象，我们称之为跳卡。然后调用Postcard的navigation()方法完成跳转

2.ARouter会通过它自己存储的路由表找到路由地址对应的Activity.class(activity.class = map.get(path))，然后new Intent()

面试：ARouter是怎么完成组件与组件之间通信的？

https://www.bilibili.com/read/cv13360784/

第一步：注册子模块信息到路由表里面去，具体是采用编译器APT（Annotation Processing Tool 即注解处理器）技术，在编译的时候，扫描自定义注解，通过注解获取子模块信息，并注册到路由表里面去。
第二步：寻址操作，寻找到在编译器注册进来的子模块信息，完成交互即可。

## 24.热修复&插件化

https://zhuanlan.zhihu.com/p/33017826
https://juejin.cn/post/6844903613865672718#heading-1
https://fashare2015.github.io/2018/01/24/dynamic-load-learning-load-activity/  

### 24.1.插件化的定义

**注意：GooglePlay禁止热更新技术**

所谓插件化，就是让我们的应用不必再像原来一样把所有的内容都放在一个apk中，可以把一些功能和逻辑单独抽出来放在插件apk中，然后主apk做到［按需调用］。

### 24.2.插件化的优势

1.减少主apk的体积、65535 问题。让应用更轻便

2.让用户不用重新安装 APK 就能升级应用功能，减少发版本频率，增加用户体验。

3.模块化、解耦合

应用程序的工程和功能模块数量会越来越多，如果功能模块间的耦合度较高，修改一个模块会影响其它功能模块，势必会极大地增加成本。

### 24.3.插件化框架对比

1.最早的插件化框架：2012年大众点评的屠毅敏就推出了AndroidDynamicLoader框架。

(1) 首先通过 DLPluginManager 的 loadApk 函数加载插件，这每个插件只需调用一次。

(2) 通过 DLPluginManager 的 startPluginActivity 函数启动代理 Activity。

(3) 代理 Activity 启动过程中构建、启动插件 Activity

2.目前主流的插件化方案有滴滴任玉刚的VirtualApk、 Wequick的Smali框架。

Hook IActivityManager和Hook Instrumentation。主要方案就是先用一个在AndroidManifest.xml中注册的Activity来进行占坑，用来通过AMS的校验，接着在合适的时机用插件Activity替换占坑的Activity。

### 24.4.插件化流程

在Android中应用插件化技术，其实也就是动态加载的过程，分为以下几步：

把可执行文件（ .so/dex/jar/apk 等）拷贝到应用 APP 内部。

加载可执行文件，更换静态资源

调用具体的方法执行业务逻辑


### 24.5.插件化原理


**一.类加载原理**

1.1 apk被安装之后，APK文件的代码以及资源会被系统存放在固定的目录（比如/data/app/package_name/base-1.apk )系统在进行类加载的时候，会自动去这一个或者几个特定的路径来寻找这个类；

系统无法加载我们插件中的类。需要我们自己处理 这个类加载的过程。

1.2 这里用的DexClassLoader  Android中的类加载器中主要包括三类BootClassLoader（继承ClassLoader），PathClassLoader和DexClassLoader,后两个继承于BaseDexClassLoader。

 BootClassLoader:主要用于加载系统的类，包括java和android系统的类库。（比如TextView,Context，只要是系统的类都是由BootClassLoader加载完成）。

 PathClassLoader:主要用于加载我们应用程序内的类。路径是固定的，只能加载
/data/app，无法指定解压释放dex的路径，无法动态加载。对于我们的应用默认为PathClassLoader

 DexClassLoader：可以用来加载任意路径的zip,jar或者apk文件。

DexClassLoader重载findClass方法，在加载类时会调用其内部的DexPathList去加载。
而DexPathList的loadClass会去遍历DexFile直到找到需要加载的类。

1.3 插件化中 有单DexClassLoader和多DexClassLoader两种结构。

插件化要解决的是

**主工程调用插件**

有单DexClassLoader

对于每个插件都会生成一个DexClassLoader，

当加载该插件中的类时需要通过对应DexClassLoader加载
需要先通过插件的ClassLoader加载该类再通过反射调用其方法

多DexClassLoader

将插件的DexClassLoader中的pathList合并到主工程的DexClassLoader中。
主工程则可以直接通过类名去访问插件中的类

**插件调用主工程**

在构造插件的ClassLoader时会传入主工程的ClassLoader作为父加载器，
所以插件是可以直接可以通过类名引用主工程的类。

双亲委派机制:
ClassLoader在加载一个字节码时，首先会询问当前的ClassLoader是否已经加载过此类，如果已经加载过就直接返回，不再重复的去加载，如果没有的话，会查询它的parent是否已经加载过此类，如果加载过那么就直接返回parent加载过的字节码文件，如果整个继承线路上都没有加载过此类，最后由子ClassLoader执行真正的加载。

**二.资源加载原理**

2.1 Android系统通过Resource对象加载资源,Resource对象的生成只要将插件apk的路径加入到AssetManager中，便能够实现对插件资源的访问。

和代码加载相似，插件和主工程的资源关系也有两种处理方式：

2.2 合并式：addAssetPath时加入所有插件和主工程的路径；

独立式：各个插件只添加自己apk路径

**三.Activity加载原理**

代理：dynamic-load-apk采用。
Hook：主流。

Hook实现方式有两种：Hook IActivityManager和Hook Instrumentation。

主要方案就是先用一个在AndroidManifest.xml中注册的Activity来进行占坑，用来通过AMS的校验，接着在合适的时机用插件Activity替换占坑的Activity。

3.1 Hook IActivityManager：

3.1.1 占坑、通过校验：

hook点

IActivityManager

Activity启动过程

startActivity-Instrumentation.execStartActivity()->ActivityManager.getService().startActivity()-> IActivityManager.Stub.asInterface->AMS.startActivity()

ActivityManager中getService()借助Singleton类实现单例,而且该单例是静态的,IActivityManager是一个比较好的Hook点。由于Hook点IActivityManager是一个接口(源码中IActivityManager.aidl文件)，建议这里采用动态代理。


过程

1.1 AndroidManifest.xml中注册SubActivity

1.2 拦截startActivity方法，获取参数args中保存的Intent对象，它是原本要启动插件TargetActivity的Intent。

1.3 新建一个subIntent用来启动StubActivity，并将前面得到的TargetActivity的Intent保存到subIntent中，便于以后还原TargetActivity。

Handler中的mCallback

activity启动过程中,AMS会远程调用applicationThread的scheduleLaunchActivity。

ActivityThread中的Handler->h的handleLaunchActivity处理LAUNCH_ACTIVITY类型的消息->ActivityThread#handleLaunchActivity->Instrumentation启动activity->Activity的onCreate方法。

在Handler的dispatchMessage处理消息的这个方法中，看到如果Handler的Callback类型的mCallBack不为null，就会执行mCallback的handleMessage方法，因此mCallback可以作为Hook点。我们可以用自定义的Callback来替换mCallback。

过程

重写callback，当收到消息的类型为LAUNCH_ACTIVITY时，将启动SubActivity的Intent替换为启动TargetActivity的Intent。

反射获取ActivityThread，反射获取mH

替换callback

使用时则在application的attachBaseContext方法中进行hook即可。


3.2 Hook Instrumentation：

与Hook IActivity实现不同的是，用占坑Activity替换插件Activity以及还原插件Activity的地方不同。

分析：

在Activity通过AMS校验前，会调用Activity的startActivityForResult方法

并会调用了Instrumentation的execStartActivity方法来激活Activity的生命周期。并且在ActivityThread的performLaunchActivity中使用了mInstrumentation的newActivity方法，其内部会用类加载器来创建Activity的实例。

方案：

1.在Instrumentation的execStartActivity方法中用占坑SubActivity来通过AMS的验证

首先检查TargetActivity是否已经注册，如果没有则将TargetActivity的ClassName保存起来用于后面还原。接着把要启动的TargetActivity替换为StubActivity，最后通过反射调用execStartActivity方法，这样就可以用StubActivity通过AMS的验证。


2.在Instrumentation的newActivity方法中还原TargetActivity

在newActivity方法中创建了此前保存的TargetActivity，完成了还原TargetActivity。

用InstrumentationProxy替换mInstrumentation。

3、插件Activity的生命周期：

AMS和ActivityThread之间的通信采用了token来对Activity进行标识，并且此后的Activity的生命周期处理也是根据token来对Activity进行标识的，因为我们在Activity启动时用插件TargetActivity替换占坑SubActivity，这一过程在performLaunchActivity之前，因此performLaunchActivity的r.token就是TargetActivity。所以TargetActivity具有生命周期。

### 24.6.热修复和插件化区别

插件化和热修复的原理，都是动态加载 dex／apk 中的类／资源，让宿主正常的加载和运行插件（补丁）中的内容。 两者的目的不同。

插件化目标是想把需要实现的模块或功能当做一个独立的提取出来，减少宿主的规模。所以插件化重在解决组件的生命周期，以及资源的问题

热修复目标在修复已有的问题。重在解决替换已有的有问题的类／方法／资源等。

### 24.7.热修复原理

代码修复主要有三个方案，分别是底层替换方案、类加载方案和Instant Run方案。

**类加载方案**

Android中要加载某一个类，最终都是调动DexPathList中的findClass()方法

加载一个类的时候，都会去循环dexElements数组取出里面的dex文件，然后从dex文件中找目标类，只要目标类找到，则直接退出循环，也就是后面的dex文件就没有被取到的机会。
那我们就可以根据这样的一个原理，将修改后的类编译后统一放在patch.dex补丁文件中，通过反射将patch.dex放在dexElemets这个数组的第一个元素，这样，当加载出现bug的类时，首先会先从patch.dex这个文件中去找，因为我们将修改后的类放在了patch.dex文件中，所以肯定会被找到(此时加载到的是已经修复的类)，一旦被找到，后面dex中的bug类就没办法被加载到。

QZone修复的步骤:

1. 通过获取到当前应用的Classloader，即为BaseDexClassloader

2. 通过反射获取到他的DexPathList属性对象pathList

3. 通过反射调用pathList的dexElements方法把patch.dex转化为Element[]

4. 两个Element[]进行合并，把patch.dex放到最前面去

5. 加载Element[]，达到修复目的


Tinker修复的流程:

微信的Tinker将新旧APK做了diff，得到patch.dex，再将patch.dex与手机中APK的classes.dex做合并，生成新的classes.dex，然后在运行时通过反射将classes.dex放在Elements数组的第一个元素。

**底层替换方案**

在native层将传入的javaMethod在ART虚拟机中对应一个ArtMethod指针，ArtMethod结构体中包含了Java方法的所有信息，包括执行入口、访问权限、所属类和代码执行地址等。

替换ArtMethod结构体中的字段或者替换整个ArtMethod结构体，这就是底层替换方案。

AndFix采用的是替换ArtMethod结构体中的字段，这样会有兼容性问题，因为厂商可能会修改ArtMethod结构体，导致方法替换失败。

Sophix采用的是替换整个ArtMethod结构体，这样不会存在兼容问题。

## 25.AOP

https://blog.csdn.net/u010289802?t=1
https://blog.csdn.net/u010289802/article/details/80183142
https://juejin.cn/user/4318537403878167/posts

### 25.1.AOP是什么

AOP:  即面向切面编程。 和OOP一样，是一种程序设计思想.实现是通过预编译方式和运行期动态代理实现程序功能的统一维护。

OOP（Object Oriented Programming）面向对象设计就是一种典型的纵向编程方式。
OOP更多关注的是对象Object本身的功能，对象之间的功能的联系往往不会考虑的那么详细。

1、继承模式比如之类和父类之间的这种关系就是一个很好的展示。

2、分层架构如MVP，每一层之间也是纵向关联在一起的。

切面，也叫横向，横切关注点是一个抽象的概念，它是指那些在项目中贯穿多个模块的业务。AOP在将横切关注点与业务主体进行分类，从而提高程序代码的模块化程度,则是将涉及到众多模块的某一类功能进行统一管理。

1 我们要为方法添加调用日志，那就必须为所有类的所有方法添加日志调用，尽管它们都是相同的。

### 25.2.AOP的好处

使用切面的好处：

1.核心代码中不在包含记录日志的代码， 类更专注于它的职责。
2.如果想修改日志的记录方式， 不需要修改Account类，只需要修改相应的配置文件和日志的实现，修改工作量小。
3.解耦。为什么说解耦呢？用打印Log举例，app中可能存在不同的Log框架来实现。如果同一使用Log标签切入，那么在处理Log标签的地方可以统一Log框架。实现AOP的同时需要依赖注入， 这又会减少模块间的依赖。

### 25.3.AOP的实现方式

https://juejin.cn/post/6844903741808705544#heading-0

 ![aop1](https://raw.githubusercontent.com/treech/PicRemote/master/common/aop1.png)

https://juejin.cn/post/6844903728525361165#heading-30


Android中AOP的实现方式分两类：

**运行时切入**

(android hook机制)

集成Dexposed， epic框架（运行时hook某些关键方法）

Java API实现动态代理机制（基于反射，性能不佳）

**编译时切入**

生成代理类(APT)

集成AspectJ框架(特殊的插件或编译器来生成特殊的class文件)

使用ASM,Javassit等字节码工具类来修改字节码(编译打包APK文件前修改class文件)

1.APT

 APT （Annotation Processing Tool ）即注解处理器，是一种处理注解的工具， 在编译时扫描和处理注解。注解处理器 在编译期，通过注解生成 .java 文件。使用的 Annotation 类型是 SOURCE。

 它在编译时扫描、解析、处理注解。它会对源代码文件进行检测，找出用户自定义的注解，根据注解、注解处理器和相应的apt工具自动生成代码。这段代码是根据用户编写的注解处理逻辑去生成的。最终将生成的新的源文件与原来的源文件共同编译（注意：APT并不能对源文件进行修改操作，只能生成新的文件，例如往原来的类中添加方法）


 代表框架：DataBinding、Dagger2、ButterKnife、EventBus3、DBFlow、AndroidAnnotation

为什么这些框架注解实现 AOP 要使用 APT？

目前 Android 注解解析框架主要有两种实现方法，

一种是运行期通过反射去解析当前类，注入相应要运行的方法。

另一种是在编译期生成类的代理类，在运行期直接调用代理类的代理方法，APT 指的是后者。

如果不使用APT基于注解动态生成 java 代码，那么就需要在运行时使用反射或者动态代理，比如大名鼎鼎的 butterknife 之前就是在运行时反射处理注解，为我们实例化控件并添加事件，然而这种方法很大的一个缺点就是用了反射，导致 app 性能下降。所以后面 butterknife 改为 apt 的方式，可以留意到，butterknife 会在编译期间生成一个 XXX_ViewBinding.java。虽然 APT 增加了代码量，但是不再需要用反射，也就无损性能。

2.AspectJ

（AspectJ）是编译期插入字节码，所以对性能也没什么影响。

通过Gradle Transform API，在class文件生成后至dex文件生成前，遍历并匹配所有符合AspectJ文件中声明的切点，然后将Aspect的代码织入到目标.class。织入代码后的新.class会加入多个JoinPoint,这个JoinPoint会建立目标.class与Aspect代码的连接，比如获得执行的对象、方法、参数等。

整个过程发生在编译期，是一种静态织入方式，所以会增加一定的编译时长，但几乎不会影响程序的运行时效率。

AspectJ 就是一个代码生成工具；
编写一段通用的代码，然后根据 AspectJ 语法定义一套代码生成规则，AspectJ 就会帮你把这段代码插入到对应的位置去。

AspectJ 语法就是用来定义代码生成规则的语法。
扩展编译器，引入特定的语法来创建 Advise，从而在编译期间就织入了Advise 的代码。
如果使用过 Java Compiler Compiler (JavaCC)，你会发现两者的代码生成规则的理念惊人相似。

3.ASM

ASM提供的API完全是面向Java字节码编程

ASM 是一个 Java 字节码层面的代码分析及修改工具，它有一套非常易用的 API，通过它可以实现对现有 class 文件的操纵，从而实现动态生成类，或者基于现有的类进行功能扩展。

 Android 的编译过程中，首先会将 java 文件编译为 class 文件，之后会将编译后的 class 文件打包为 dex 文件，我们可以利用 class 被打包为 dex 前的间隙，插入 ASM 相关的逻辑对 class 文件进行操纵
 ASM 是一个 Java 字节码层面的代码分析及修改工具，它有一套非常易用的 API，通过它可以实现对现有 class 文件的操纵，从而实现动态生成类，或者基于现有的类进行功能扩展。

4.epic

ART中的函数的调用约定,去修改函数的内容，将函数的前两条指令修改为跳转到自己自定义的逻辑，从而实现对任意方法的 Hook。

5.hook

https://zhuanlan.zhihu.com/p/109157321

反射/动态代理
如图中A点，作用于Java层。反射/动态代理是虚拟机提供的标准编程接口，可靠性较高。反射API可以帮助我们们访问到private属性并修改，动态代理可以直接从Interface中动态的构造出代理对象，并去监控这个对象。

常见的用法是，用动态代理构造出一个代理对象，然后用反射API去替换进程中的对象，从而达到hook的目的。如：对Java Framework API的修改常用这种方法，修改ActivityThread、修当前进程的系统调用等。

缺点：只在java层，只能通过替换对象达到目的，适用范围较小

优点：稳定性好，调用反射和动态代理并不存在适配问题，技术门槛低

JNI Hook
如图中B点，java代码和native之间的调用是通过JNI接口调用的，所有JNI接口的函数指针都会被保存在虚拟机的一张表中。所以，java和native之间调用可以通过修改函数指针达到。

优点：稳定性高

缺点：只能hook Java和Native之间的native接口函数

ClassLoader
如图中C点，java代码的执行都是靠虚拟机的类加载器ClassLoader去加载，ClassLoader默认的双亲委派机制保证了ClassLoader总是从父类优先去加载java class。所以一类hook方案就是通过修改ClassLoader加载java class的Path路径达到目的。常见的应用场景有一些热修复技术。

优点：稳定性高

缺点：需要提前编译好修改后的class去替换，灵活性降低了

Xposed相关
如图中D点，这类hook技术的原理都是去修改ART/Dalvik虚拟机，虚拟机为java提供运行时环境，所有的java method都保存在虚拟机一张Map维护，每个Java Method都有个是否是JNI函数的标志位，如果是JNI函数则去查找对应的native函数。所以，一个hook方案是通过把要hook的函数修改为JNI函数，然后实现一个对应的native函数从而达到hook。

大量的一些自动化测试、动态调试都采用这个方法

优点：java层所有的class都可以修改，Activity等都可以注入。灵活性极高。

缺点：ART/Dalvik每次Android系统发布大版本都会被大改，导致每个Android版本都要去适配配。稳定性变差。

前面hook技术都是去修改虚拟机中的java层，如果一个应用还包含Native code话，则得使用不同hook技术

## 26.jectpack

###  26.1.Navigation

https://mp.weixin.qq.com/s/1URoDU0zgoYlSQM8zYqx9w

**what**

https://juejin.cn/post/6844904131577004039#heading-0

https://www.jianshu.com/p/5c1763b0c9eb

https://zhuanlan.zhihu.com/p/69562454

对于单个Activity嵌套多个Fragment的UI架构方式， 对Fragment的管理一直是一个比较麻烦的事情。

需要通过FragmentManager和FragmentTransaction来管理Fragment之间的切换
对应用程序的App bar的管理，
Fragment间的切换动画
Fragment间的参数传递
总之，使用起来不是特别友好。

Navigation是用来管理Fragment的切换，并且可以通过可视化的方式，看见App的交互流程

**why**

https://www.jianshu.com/p/66b93df4b7a6
https://zhuanlan.zhihu.com/p/69562454

可以可视化的编辑各个组件之间的跳转关系

优雅的支持fragment之间的转场动画

 通过第三方的插件支持fragment之间安全的参数传递

通过NavigationUI类，对菜单，底部导航，抽屉菜单导航进行方便统一的管理

支持通过deeplink直接定位到fragment

**how**

https://juejin.cn/post/6844904068897308679#heading-0

1 创建导航图

在 res 目录内创建一个 navigation 资源目录

根标签是navigation，它需要有一个属性startDestination，表示默认第一个显示的界面

每个fragment标签代表一个fragment类

每个action标签就相当于上图中的每条线，代表了执行切换的时候的目的地，切换动画等信息。

```xml
 <fragment
        android:id="@+id/firstFragment"
        android:name="com.chs.androiddailytext.jetpack.navigation.FirstFragment"
        android:label="fragment_frist"
        tools:layout="@layout/fragment_frist">
        <action
            android:id="@+id/action_firstFragment_to_secondFragment"
            app:destination="@id/secondFragment"
            app:enterAnim="@anim/slide_in_right"
            app:exitAnim="@anim/slide_out_left"
            app:popEnterAnim="@anim/slide_in_left"
            app:popExitAnim="@anim/slide_out_right" />
</fragment>
```


2  添加NavHostFragment

标签为fragment，android:name就是NavHost的实现类，这里是NavHostFragment
app:navGraph 属性就是我们前面在res文件夹下创建的文件

Activity的布局中

 ```xml
 <fragment
        android:id="@+id/fragment"
        android:name="androidx.navigation.fragment.NavHostFragment"
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        app:defaultNavHost="true"
        app:navGraph="@navigation/nav_graph" />
 ```



3. 开启导航

通过Navigation#findNavController方法找到NavController，调用它的navigate方法开始导航。

```java
view.findViewById(R.id.button).setOnClickListener(v -> {
    Bundle bundle = new Bundle();
    bundle.putString("title","我是前面传过来的");
    Navigation.findNavController(v).navigate(R.id.action_firstFragment_to_secondFragment,bundle);
});
```

https://mp.weixin.qq.com/s/1URoDU0zgoYlSQM8zYqx9w

注意点:

1.页面跳转和参数传递

页面间的跳转是通过action来实现

1、Bundle方式

第一种方式是通过Bundle的方式。NavController 的navigate方法提供了传入参数是Bundle的方法

2.安全参数(SafeArg)
build.gradle添加n:navigation-safe-args引用
添加

```xml
<argument
	android:name="price"
    app:argType="float"
    android:defaultValue="0" />
<argument
	android:name="productName"
	app:argType="string"
	android:defaultValue="unknow" />
```

编译

```java
Bundle bundle = new DetailFragmentArgs.Builder().setProductName("苹果").setPrice(10.5f).build().toBundle();
NavController contorller = Navigation.findNavController(view);
contorller.navigate(R.id.action_homeFragment_to_detailFragment, bundle);
```

接收

```java
Bundle bundle = getArguments();
if(bundle != null){
    mProductName = DetailFragmentArgs.fromBundle(bundle).getProductName();
    mPrice = DetailFragmentArgs.fromBundle(bundle).getPrice();
}
```

2 动画
action中 
enterAnim: 配置进场时目标页面动画 
exitAnim: 配置进场时原页面动画 
popEnterAnim: 配置回退时目标页面动画 
popExitAnim: 配置回退时原页面动画 配置完后

3.导航堆栈管理

Navigation 有自己的任务栈，每次调用navigate()函数，都是一个入栈操作，出栈操作有以下几种方式，下面详细介绍几种出栈方式和使用场景。
1、系统返回键

首先需要在xml中配置app:defaultNavHost="true"，才能让导航容器拦截系统返回键，点击系统返回键，是默认的出栈操作，回退到上一个导航页面。如果当栈中只剩一个页面的时候，系统返回键将由当前Activity处理。

2.popBackStack()或者navigateUp()
如果页面上有返回按钮，那么我们可以调用popBackStack()或者navigateUp()返回到上一个页面。

3.popUpTo 和 popUpToInclusive

我们看下面这个例子。假设有A,B,C 3个页面，跳转顺序是 A to B，B to C，C to A。依次执行几次跳转后，栈中的顺序是A>B>C>A>B>C>A。此时如果用户按返回键，会发现反复出现重复的页面，此时用户的预期应该是在A页面点击返回，应该退出应用。此时就需要在C到A的action中设置popUpTo="@id/a". 这样在C跳转A的过程中会把B,C出栈。但是还会保留上一个A的实例，加上新创建的这个A的实例，就会出现2个A的实例. 此时就需要设置 popUpToInclusive=true. 这个配置会把上一个页面的实例也弹出栈，只保留新建的实例。下面再分析一下设置成false的场景。还是上面3个页面，跳转顺序A to B，B to C. 此时在B跳C的action中设置 popUpTo=“@id/a”, popUpToInclusive=false. 跳到C后，此时栈中的顺序是AC。B被出栈了。如果设置popUpToInclusive=true. 此时栈中的保留的就是C。AB都被出栈了。

4 DeepLink

Navigation组件提供了对深层链接（DeepLink）的支持。通过该特性，我们可以利用PendingIntent或者一个真实的URL链接，直接跳转到应用程序的某个destination

1、PendingIntent

```java
private PendingIntent getPendingIntent() {
    Bundle bundle = new Bundle();
    bundle.putString("productName", "香蕉");
    bundle.putFloat("price",6.66f);
    return Navigation
            .findNavController(this,R.id.fragment)
            .createDeepLink()
            .setGraph(R.navigation.nav_graph)
            .setDestination(R.id.detailFragment)
            .setArguments(bundle)
            .createPendingIntent();
}
```

2、URL连接

```xml
<deepLink
    android:autoVerify="true"
    app:uri="www.mywebsite.com/detail?productName={productName}price={price}" />
    
<nav-graph android:value="@navigation/nav_graph"/>
```

源码理解

https://mp.weixin.qq.com/s/1URoDU0zgoYlSQM8zYqx9w


NavHostFragment

这是一个特殊的布局文件，Navigation Graph中的页面通过该Fragment展示


**NavHostFragment**

1.onInflate解析在xml配置的两个参数defaultNavHost， 和navGraph

2、onCreate 创建NavController

3、onCreateView 创建一个FrameLayout

4、onViewCreated 在这个函数中，把NavController设置给了父布局的view的中的ViewTag中 Navigation.findNavController(View)中 递归遍历view的父布局，查找是否有view含有id为R.id.nav_controller_view_tag的tag, tag有值就找到了NavController。如果tag没有值.说明当前父容器没有NavController

**NavController**

导航的主要工作都在NavController中，涉及xml解析，导航堆栈管理，导航跳转等方面

1.NavHostFragment把导航文件的资源id传给了NavController

2.NavController把导航xml文件传递给了NavInflater解析导航xml文件

3.生成NavGraph保存着xml中配置的导航目标NavDestination

NavController的navigate函

把所有Navigator的实例保存在了NavigatorProvider

 navigator.navigate

Fragment实例是通过instantiateFragment创建的，这个函数中是通过反射的方式创建的Fragment实例，Fragment还是通过FragmentManager进行管理，是用replace方法替换新的Fragment, 这就是说每次导航产生的Fragment都是一个新的实例，不会保存之前Fragment的状态

**NavGraph**

里面包含了一组NavDestination，每个NavDestination就是一个一个的页面，也就是导航目的地

**NavigatorProvider**

内部有个HashMap，用来存放Navigator，Navigator它是个抽象类，有三个比较重要的子类FragmentNavigator，ActivityNavigator，DialogFragmentNavigator

使用
https://juejin.cn/post/6844904131577004039

1.注解处理器的目标是，扫描出所有带FragmentDestination或者ActivityDestination的类，拿到注解中的参数和类的全类名，封装成对象放到map中，使用fastjson将map生成json字符串，保存在src/main/assets目录下面

https://blog.csdn.net/weixin_42575043/article/details/108709467

2.可以自定义FragmentNavigator解决Fragment重复创建的问题


###  26.2.DataBinding

https://blog.csdn.net/LucasXu01/article/details/103807451
https://juejin.cn/post/6844903494831308814#heading-6
https://www.jianshu.com/p/c56a987347ff

原理

1.APT预编译方式生成ActivityMainBinding和ActivityMainBindingImpl

2.处理布局的时候生成了两个xml文件

activity_main-layout.xml（DataBinding需要的布局控件信息）

activity_main.xml（Android OS 渲染的布局文件）

Model是如何刷新View

1.DataBindingUtil.setContentView方法将xml中的各个View赋值给ViewDataBinding，完成findviewbyid的任务

2.当VM层调用notifyPropertyChanged方法时，最终在ViewDataBindingImpl的executeBindings方法中处理逻辑


View是如何刷新Model

ViewDataBindingImpl的executeBindings方法中在设置了双向绑定的控件上，为其添加对应的监听器，监听其变动，如：EditText上设置TextWatcher，具体的设置逻辑放置到了TextViewBindingAdapter.setTextWatcher里

当数据发生变化的时候，TextWatcher在回调onTextChanged()的最后，会通过textAttrChanged.onChange()回调到传入的mboundView2androidTextAttrChanged的onChange()。

使用

https://juejin.cn/post/6844903872520011784#heading-0

###  26.3.ViewModel

https://blog.csdn.net/c10wtiybq1ye3/article/details/89934891
https://www.jianshu.com/p/41c56570a266?utm_campaign=haruki&utm_content=note&utm_medium=seo_notes&utm_source=recommendation
https://www.jianshu.com/p/ebdf656b6dd4
https://blog.csdn.net/qq_15988951/article/details/105106867

how

```java
viewmodel =  ViewModelProvider(this).get(MyViewModel::class.java)
```

what

ViewModel 类旨在以注重生命周期的方式存储和管理界面相关的数据

why

**Activity配置更改重建时(比如屏幕旋转)保留数据**

问题

https://blog.csdn.net/u014093134/article/details/104082453

例如你的 APP 某个 Activity 中包含一个 列表，因为配置更改而重新创建 Activity 后（例如众所周知的屏幕旋转发生后需手动保存数据在旋转后进行恢复），新 Activity 必须重新提取列表数据，对于简单数据，Activity 可以使用 onSaveInstanceState() 方法从 onCreate() 中的捆绑包恢复数据，但这种方法仅适合可以序列化再反序列化但少量数据，不适合数量可能较大但数据，如用户列表或位图


因为ViewModel的生命周期是比Activity还要长，所以ViewModel可以持久保存UI数据。

通常在系统首次调用 Activity 对象的 onCreate() 方法时请求 ViewModel。系统可能会在 Activity 的整个生命周期内多次调用 onCreate()，如在旋转设备屏幕时。
所以当前Activity的生命周期不断变化，经历了被销毁重新创建，而ViewModel的生命周期没有发生变化，Activity因为配置更改或者被系统意外回收的时候，会自动保存数 据。在Activity重建的时候就可以继续使用销毁之前保存的数据。

源码
https://www.jianshu.com/p/ebdf656b6dd4

ComponentActivity 中

 onRetainNonConfigurationInstance是在onStop() 和 onDestroy()之间被调用，它内部会保存ViewModel数据;

它会被ActivityThread中performDestroyActivity方法调用，它执行在onDestroy生命周期之前

Activity的attach时会调用getLastNonConfigurationInstance来恢复数据


ViewModel将一直留在内存中，直到限定其存在时间范围的Lifecycle(activity dstroy掉用clear) 永久消失：

**UI组件(Activity与Fragment、Fragment与Fragment)间实现数据共享**

当这两个 Fragment 各自获取 ViewModelProvider 时，它们会收到相同的  ViewModel 实例
ViewModelProvider通过ViewModelStore获取ViewModel，FragmentActivity自身是持有ViewModelStore


**避免内存泄漏的发生。**

https://www.jianshu.com/p/41c56570a266

引入了ViewModel和LiveData之后，可以实现vm和view的解耦，只是view引用vm，而vm是不持有view的引用的。在activity退出之后即是还有网络在继续也不会引发内存泄漏和空指针异常


**源码解析**

https://blog.csdn.net/c10wtiybq1ye3/article/details/89934891

1.Factory是ViewModelProvider的一个内部接口，它的实现类是拿来构建ViewModel实例


3.get mViewModelStore.get(key)  create通过newInstance(application)去实例化


ViewModelStore：和名字一样，就是存储ViewModel的，它里面定义了一个HashMap来存储ViewModel，key值是ViewModel全路径+一个默认的前缀

### 26.4.ViewModel+LiveData

**ViewModel**

https://juejin.cn/post/6844904079265644551#heading-0

https://www.jianshu.com/p/35d143e84d42

https://www.jianshu.com/p/109644858928

**1.how**

1.通过ViewModelProviders.of()方法创建ViewModel对象

2.在Activity或者Fragment中，是由Activity和Fragment来提ViewModelStore类对象， 每个Activity或者Fragment都有一个，目的是用于保存该页面的ViewModel对象


**2.why**


**1.管理UI界面数据,数据持久化(将加载数据与数据恢复从 Activity or Fragment中解耦)**

在 Android 系统中，需要数据恢复有如下两种场景：

场景1：资源相关的配置发生改变导致 Activity 被杀死并重新创建。
场景2：资源内存不足导致低优先级的 Activity 被杀死。


使用 onSaveInstanceState 与 onRestoreInstanceState

onSaveInstanceState只适合保存少量的可以被序列化、反序列化的数据

onRetainNonConfigurationInstance 方法，用于处理配置发生改变时数据的保存。随后在重新创建的 Activity 中调用 getLastNonConfigurationInstance 获取上次保存的数据


官方最终采用了 onRetainNonConfigurationInstance 的方式来恢复 ViewModel 。

其实就是在屏幕旋转的时候，AMS通过Binder回调Activity的retainNonConfigurationInstances()方法，数据保存就是通过retainNonConfigurationInstances()方法保存在NonConfigurationInstances对象，而再一次使用取出ViewModel的数据的时候，就是从nc对象中取出ViewModelStore对象，而ViewModelStore对象保存有ViewModel集合
，官方重写了 onRetainNonConfigurationInstance 方法，在该方法中保存了 ViewModelStor

监听 Activity 声明周期，在 onDestory 方法被调用时，判断配置是否改变。如果没有发送改变，则调用 Activity 中的 ViewModelStore 的 clear() 方法，清除所有的 ViewModel

**2.Fragments 间共享数据**

获取到了Activity的ViewModelStore对象，从而实现了Fragment之间共享ViewModel

为什么不同的Fragment使用相同的Activity对象来获取ViewModel，可以轻易的实现ViewModel共享？

讲道理，如果同学们仔细看了ViewModel的创建流程，这个问题自然迎刃而解。

因为不同的Fragment使用相同的Activity对象来获取ViewModel，在创建ViewModel之前都会先从Activity提供的ViewModelStore中先查询一遍是否已经存在该ViewModel对象。
所以我们只需要先在Activity中同样调用一遍ViewModel的获取代码，即可让ViewModel存在于ViewModelStore中，从而不同的Fragment可以共享一份ViewModel了。

https://juejin.cn/post/6844903919064186888#heading-2（vm总结）

**Livedata**

https://zhuanlan.zhihu.com/p/76747541

**what**
LiveData是一个可被观察的数据容器类

它将数据包装起来，使得数据成为“被观察者”，页面成为“观察者”。这样，当该数据发生变化时，页面能够获得通知，进而更新UI。

可以看到它接收的第一个参数是一个LifecycleOwner对象，在我们的示例中即Activity对象。第二个参数是一个Observer对象。通过最后一行代码将Observer与Activity的生命周期关联在一起。

只有在页面处于激活状态（Lifecycle.State.ON_STARTED或Lifecycle.State.ON_RESUME）时，页面才会收到来自LiveData的通知，如果页面被销毁（Lifecycle.State.ON_DESTROY）

**how**

在页面中，我们通过LiveData.observe()方法对LiveData包装的数据进行观察，反过来，当我们想要修改LiveData包装的数据时，可通过LiveData.postValue()/LiveData.setValue()来完成。postValue()是在非UI线程中使用，如果在UI线程中，则使用setValue()方法。

**why**

不会发生内存泄漏

观察者会绑定到 Lifecycle 对象，并在其关联的生命周期遭到销毁后进行自我清理。


不再需要手动处理生命周期

如果观察者的生命周期处于非活跃状态（如返回栈中的 Activity ），则它不会接收任何 LiveData 事件。

---------
getLifecycle().addObserver进行观察

activity实现LifecycleOwner，reprotfrgament注册

livedata继承LifecycleObserver，detsroy销毁 其他


### 26.5.LifeCycle

https://liuwangshu.cn/application/jetpack/3-lifecycle-theory.html
https://juejin.cn/post/6844903784166998023

Lifecycle使用

LifecycleObserver:是一个空方法接口，用于标识观察者，对这个 Lifecycle 对象进行监听

LifecycleOwner: 是一个接口，持有方法Lifecycle getLifecycle()。

LifecycleRegistry 类用于注册和反注册需要观察当前组件生命周期的 LifecycleObserver

1.实现LifecycleOwner重写getLifecycle 返回mLifecycleRegistry，mLifecycleRegistry不同生命周期markState

2.继承LifecycleObserver

3.getLifecycle.addObserver注册LifecycleObserver

## 27.JNI

### 27.1.Java中 long、float 字节数

```java
short s; 2字节
int i; 4字节 float f; 4字节
long l; 8字节 double d; 8字节
char c; 2字节（C语⾔中是1字节）
byte b; 1字节
boolean bool; false/true 1字节
```


### 27.2.Java调用C++

- 在Java中声明Native方法（即需要调用的本地方法）
- 编译上述 Java源文件javac（得到 .class文件） 3。 通过 javah 命令导出JNI的头文件（.h文件）
- 使用 Java需要交互的本地代码 实现在 Java中声明的Native方法
- 编译.so库文件
- 通过Java命令执行 Java程序，最终实现Java调用本地代码

### 27.3.C++调用Java

- 从classpath路径下搜索ClassMethod这个类，并返回该类的Class对象。

- 获取类的默认构造方法ID。

- 查找实例方法的ID。

- 创建该类的实例。

- 调用对象的实例方法。

        JNIEXPORT void JNICALL Java_com_study_jnilearn_AccessMethod_callJavaInstaceMethod  
        (JNIEnv *env, jclass cls)  
        {  
          jclass clazz = NULL;  
          jobject jobj = NULL;  
          jmethodID mid_construct = NULL;  
          jmethodID mid_instance = NULL;  
          jstring str_arg = NULL;  
          // 1、从classpath路径下搜索ClassMethod这个类，并返回该类的Class对象  
          clazz = (*env)->FindClass(env, "com/study/jnilearn/ClassMethod");  
          if (clazz == NULL) {  
              printf("找不到'com.study.jnilearn.ClassMethod'这个类");  
              return;  
          }  
          
          // 2、获取类的默认构造方法ID  
          mid_construct = (*env)->GetMethodID(env,clazz, "<init>","()V");  
          if (mid_construct == NULL) {  
              printf("找不到默认的构造方法");  
              return;  
          }  
          
          // 3、查找实例方法的ID  
          mid_instance = (*env)->GetMethodID(env, clazz, "callInstanceMethod", "(Ljava/lang/String;I)V");  
          if (mid_instance == NULL) {  
          
              return;  
          }  
          
          // 4、创建该类的实例  
          jobj = (*env)->NewObject(env,clazz,mid_construct);  
          if (jobj == NULL) {  
              printf("在com.study.jnilearn.ClassMethod类中找不到callInstanceMethod方法");  
              return;  
          }  
          
          // 5、调用对象的实例方法  
          str_arg = (*env)->NewStringUTF(env,"我是实例方法");  
          (*env)->CallVoidMethod(env,jobj,mid_instance,str_arg,200);  
          
          // 删除局部引用  
          (*env)->DeleteLocalRef(env,clazz);  
          (*env)->DeleteLocalRef(env,jobj);  
          (*env)->DeleteLocalRef(env,str_arg);  
        }  

### 27.4.如何在jni中注册native函数，有几种注册方式？

https://www.jianshu.com/p/6ebec201d502

#### 27.4.1.静态方法

这种方法我们比较常见，但比较麻烦，大致流程如下：

- 先创建Java类，声明Native方法，编译成.class文件。
- 使用Javah命令生成C/C++的头文件，例如：javah -jni com.devilwwj.jnidemo.TestJNI，则会生成一个以.h为后缀的文件**com_devilwwj_jnidemo_TestJNI.h**。
- 创建.h对应的源文件，然后实现对应的native方法，如下图所示：

![jni头文件对应的cpp文件](https://raw.githubusercontent.com/treech/PicRemote/master/common/jni%E5%A4%B4%E6%96%87%E4%BB%B6%E5%AF%B9%E5%BA%94%E7%9A%84cpp%E6%96%87%E4%BB%B6.webp)

说一下这种方法的弊端：

> 需要编译所有声明了native函数的Java类，每个所生成的class文件都得用javah命令生成一个头文件。

- javah生成的JNI层函数名特别长，书写起来很不方便
- 初次调用native函数时要根据函数名字搜索对应的JNI层函数来建立关联关系，这样会影响运行效率

既然有这么多弊端，我们自然要考虑一下有没有其他更好的方法下一节就是我要讲的替代方法，Android用的也是这种方法。

#### 27.4.1.动态注册

我们知道Java Native函数和JNI函数时一一对应的，JNI中就有一个叫JNINativeMethod的结构体来保存这个对应关系，实现动态注册方就需要用到这个结构体。举个例子，你就一下子明白了：

声明native方法还是一样的：

```java
public class JavaHello {
    public static native String hello();
}
```

创建jni目录，然后在该目录创建hello.c文件，如下：

```cpp
//
// Created by DevilWwj on 16/8/28.
//
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <jni.h>
#include <assert.h>

/**
 * 定义native方法
 */
JNIEXPORT jstring JNICALL native_hello(JNIEnv *env, jclass clazz)
{
    printf("hello in c native code./n");
    return (*env)->NewStringUTF(env, "hello world returned.");
}

// 指定要注册的类
#define JNIREG_CLASS "com/devilwwj/library/JavaHello"

// 定义一个JNINativeMethod数组，其中的成员就是Java代码中对应的native方法
static JNINativeMethod gMethods[] = {
    { "hello", "()Ljava/lang/String;", (void*)native_hello},
};


static int registerNativeMethods(JNIEnv* env, const char* className,
JNINativeMethod* gMethods, int numMethods) {
    jclass clazz;
    clazz = (*env)->FindClass(env, className);
    if (clazz == NULL) {
        return JNI_FALSE;
    }
    if ((*env)->RegisterNatives(env, clazz, gMethods, numMethods) < 0) {
        return JNI_FALSE;
    }
    return JNI_TRUE;
}

/***
 * 注册native方法
 */
static int registerNatives(JNIEnv* env) {
    if (!registerNativeMethods(env, JNIREG_CLASS, gMethods, sizeof(gMethods) / sizeof(gMethods[0]))) {
        return JNI_FALSE;
    }
    return JNI_TRUE;
}

/**
 * 如果要实现动态注册，这个方法一定要实现
 * 动态注册工作在这里进行
 */
JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void* reserved) {
    JNIEnv* env = NULL;
    jint result = -1;

    if ((*vm)-> GetEnv(vm, (void**) &env, JNI_VERSION_1_4) != JNI_OK) {
        return -1;
    }
    assert(env != NULL);

    if (!registerNatives(env)) { //注册
        return -1;
    }
    result = JNI_VERSION_1_4;

    return result;

}
```

先仔细看一下上面的代码，看起来好像多了一些代码，稍微解释下，如果要实现动态注册就必须实现**JNI_OnLoad**方法，这个是JNI的一个入口函数，我们在Java层通过System.loadLibrary加载完动态库后，紧接着就会去查找一个叫JNI_OnLoad的方法。如果有，就会调用它，而动态注册的工作就是在这里完成的。在这里我们会去拿到JNI中一个很重要的**结构体JNIEnv**，env指向的就是这个结构体，通过env指针可以找到指定类名的类，并且调用JNIEnv的RegisterNatives方法来完成注册native方法和JNI函数的对应关系。

我们在上面看到声明了一个**JNINativeMethod数组**，这个数组就是用来定义我们在Java代码中声明的native方法，我们可以在jni.h文件中查看这个结构体的声明：

```cpp
typedef struct {
    const char* name;
    const char* signature;
    void*       fnPtr;
} JNINativeMethod;
```

结构体成员变量分别对应的是Java中的native方法的名字，如本文的hello；Java函数的签名信息、JNI层对应函数的函数指针。

以上就是动态注册JNI函数的方法，上面只是一个简单的例子，如果你还想再实现一个native方法，只需要在JNINativeMethod数组中添加一个元素，然后实现对应的JNI层函数即可，下次我们加载动态库时就会动态的将你声明的方法注册到JNI环境中，而不需要你做其他任何操作。

### 27.5.so 的加载流程是怎样的，生命周期是怎样的？

这个要从 java 层去看源码分析，是从 ClassLoader 的 PathList 中去找到目标路径加载的，同时 so 是通过 mmap 加载映射到虚拟空间的。生命周期加载库和卸载库时分别调用 **JNI_OnLoad** 和 **JNI_OnUnload** 方法。

### 27.6.jni中有几种引用类型？

https://blog.csdn.net/taohongtaohuyiwei/article/details/104992139

在java中有强引用，软引用，弱引用，虚引用四种引用类型。
在jni中有全局引用，全局弱引用，本地引用三种引用类型。
在C中有全局变量，局部变量，全局变量两种变量类型。

初学者经常将这几者弄混。
我们知道在java中强引用引用的对象是不会被垃圾回收的。软引用引用的对象在内存不足时会被回收。弱引用引用的对象只要垃圾回收发生就会被回收。
从java的角度来看，jni中的全局引用和本地引用都是java中的强引用，jni中的全局弱引用是java中的弱引用。
在jni中，本地引用一般是自动创建和自动释放的。
而全局引用和全局弱引用则需要我们手动创建和手动释放。

#### 27.6.1.本地引用为什么能够自动创建和释放，又为什么需要DeleteLocalRef手动释放本地引用？

当我们调用java的native函数的时候，虚拟机首先会创建一个本地引用表，然后再调用C层相应的入口函数，在C层函数执行期间，所有C层创建的类型对象的引用都会被加入本地引用表。当C层函数执行完毕，返回到java层时，本地引用表中的所有引用会被一次性释放。
注意，本地引用表的大小是有限制的，在Android上,本地引用表的大小是512，所以在一次jni函数的调用过程中，C层最多可以创建512个本地引用，当超过这个数量时，会报下面这个错误：

```
JNI ERROR (app bug): local reference table overflow (max=512)
```

所以，从编程的角度来看，本地引用表其实就是就是一个大小固定的数组，当遇到以上问题时，我们便不能再依赖于本地引用的自动创建释放机制了，应该调用`DeleteLocalRef`手动释放本地引用。

## 28.开源框架

### 28.1.Okhttp

https://cloud.tencent.com/developer/article/1930733

**1.exectute执行**

1.1.真正的请求交给了 RealCall 类

 exectute()方法执行RealCall的execute方法

 client.dispatcher().enqueue(new AsyncCall(responseCallback));

 利用dispatcher调度器enqueueAsyncCall，并通过回调（Callback）获取服务器返回的结果

1.2 Dispatcher

Dispatcher将call 加入到队列中，然后通过线程池来执行call

Dispatcher是一个任务调度器，它内部维护了三个双端队列：

    readyAsyncCalls：准备运行的异步请求
    runningAsyncCalls：正在运行的异步请求
    runningSyncCalls：正在运行的同步请求

新来的请求放队尾，执行请求从对头部取。

1.3 线程池

这不是一个newCachedThreadPool吗？没错，除了最后一个threadFactory参数之外与newCachedThreadPool一毛一样，只不过是设置了线程名字而已，用于排查问题。

阻塞队列用的SynchronousQueue，它的特点是不存储数据，当添加一个元素时，必须等待一个消费线程取出它，否则一直阻塞。

通常用于需要快速响应任务的场景，在网络请求要求低延迟的大背景下比较合适，

采用责任链的模式来使每个功能分开，每个Interceptor自行完成自己的任务

**2.拦截器**

利用Builder模式配置各种参数，例如：超时时间、拦截器等

| 拦截器                            | 作用                                                         |
| :-------------------------------- | :----------------------------------------------------------- |
| 应用拦截器                        | 拿到的是原始请求，可以添加一些自定义header、通用参数、参数加密、网关接入等等。 |
| RetryAndFollowUpInterceptor       | 处理错误重试和重定向                                         |
| BridgeInterceptor                 | 应用层和网络层的桥接拦截器，主要工作是为请求添加cookie、添加固定的header，比如Host、Content-Length、Content-Type、User-Agent等等，然后保存响应结果的cookie，如果响应使用gzip压缩过，则还需要进行解压。 |
| CacheInterceptor                  | 缓存拦截器，如果命中缓存则不会发起网络请求。                 |
| ConnectInterceptor                | 连接拦截器，内部会维护一个连接池，负责连接复用、创建连接（三次握手等等）、释放连接以及创建连接上的socket流。 |
| networkInterceptors（网络拦截器） | 用户自定义拦截器，通常用于监控网络层的数据传输。             |
| CallServerInterceptor             | 请求拦截器，在前置准备工作完成后，真正发起了网络请求。       |

**3.addInterceptor 和 addNetworkdInterceptor区别**

在OkHttpClient.Builder的构造方法有两个参数，使用者可以通过addInterceptor 和 addNetworkdInterceptor 添加自定义的拦截器

加拦截器的顺序可以知道 Interceptors 和 networkInterceptors 刚好一个在 RetryAndFollowUpInterceptor 的前面，一个在后面

责任链调用图可以分析出来，假如一个请求在 RetryAndFollowUpInterceptor 这个拦截器内部重试或者重定向了 N 次，那么其内部嵌套的所有拦截器也会被调用N次，同样 networkInterceptors 自定义的拦截器也会被调用 N 次。而相对的 Interceptors 则一个请求只会调用一次，所以在OkHttp的内部也将其称之为 Application Interceptor。

**4.责任链模式**

https://juejin.cn/post/6844903792073261063#heading-12

将处理者和请求者进行解耦

多个对象都有机会处理请求，将这些对象连成一个链，将请求沿着这条链传递。

在请求到达时，拦截器会做一些处理（比如添加参数等），然后传递给下一个拦截器进行处理。


**5.缓存怎么处理**

https://juejin.cn/post/6844903552339410958#heading-4


**使用OkHttp的缓存**

定义一个网络拦截器

Http协议  缓存的控制是通过首部的Cache-Control来控制

only-if-cache: 表示直接获取缓存数据，若没有数据返回，则返回504

有网络时访问服务器

无网络时返回缓存数据

1.自定义Interceptor,重写intercept设置header
2.OkHttpClient .cache// 设置缓存路径和缓存容量
3.addNetworkInterceptor设置自定义缓存


**不使用OkHttp的缓存**

```java
if (NetworkUtil.isConnected(mContext)) {
    response = chain.proceed(newRequest);
    saveCacheData(response); // 保存缓存数据
} else { // 不执行chain.proceed会打断责任链，即后面的拦截器不会被执行
    response = getCacheData(chain.request().url()); // 获取缓存数据
}
```
**6.Okhttp连接池**


连接池是为了解决频繁的进行建立Sokcet连接（TCP三次握手）和断开Socket（TCP四次分手）


socket复用有何标准

get

1.http协议

1.在http 1.x协议下，所有的请求的都是顺序的，正在写入数据的socket无法被另一个请求复用
2.http2.0协议使用了多路复用技术，允许同一个socket在同一个时候写入多个流数据

http1.x协议下当前socket没有其他流正在读写时可以复用，否则不行，http2.0对流数量没有限制。

2.域名和http和ssl协议配置需要匹配

put

在连接池中找连接的时候会对比连接池中相同host的连接。

如果在连接池中找不到连接的话，会创建连接，创建完后会存储到连接池中。

###  28.2.Glide

####  28.2.1.Glide怎么绑定生命周期

https://juejin.cn/post/6844903647877267463#heading-1

Glide.with(Activity activity)的方式传入页面引用

基于当前Activity创建无UI的Fragment，这个特殊的Fragment持有一个Lifecycle。通过Lifecycle在Fragment关键生命周期通知RequestManger进行相关的操作。在生命周期onStart时继续加载，onStop时暂停加载，onDestory是停止加载任务和清除操作。

####  28.2.2.Glide缓存机制内存缓存，磁盘缓存

https://juejin.cn/post/6844904002551808013#comment

**Glide的缓存机制，主要分为2种缓存，一种是内存缓存，一种是磁盘缓存。**

之所以使用内存缓存的原因是：防止应用重复将图片读入到内存，造成内存资源浪费。

之所以使用磁盘缓存的原因是：防止应用重复的从网络或者其他地方下载和读取数据

具体来讲，缓存分为加载和存储：

内存缓存分为弱引用和lru缓存

弱引用是缓存正在使用的图片，避免内存泄漏

将缓存图片的时候，写入顺序

 弱引用缓存-》Lru算法缓存-》磁盘缓存中

当加载一张图片的时候，获取顺序

 弱引用缓存-》Lru算法缓存-》磁盘缓存

####  28.2.3.关于LruCache

LruCache 内部用LinkedHashMap存取数据

LinkedHashMap继承于HashMap，它使用了一个双向链表来存储Map中的Entry顺序关系，这种顺序有两种，一种是LRU顺序，一种是插入顺序

LruCache中将LinkedHashMap的顺序设置为LRU顺序来实现LRU缓存

每次调用get(也就是从内存缓存中取图片)，则将该对象移到链表的尾端。

调用put插入新的对象也是存储在链表尾端，这样当内存缓存达到设定的最大值时，将链表头部的对象（近期最少用到的）移除。

####  28.2.4.Glide与Picasso的区别

https://blog.csdn.net/github_34402358/article/details/105955743

Glide与Picasso的区别： 内存 Image质量的细节 磁盘缓存 Gif动图

内存：

    加载同一张图片Picasso，Picasso的内存开销仍然远大于Glide。

Image质量的细节：

    Glide默认的是Bitmap格式是RGB-565
    
    Picasso默认ARGB_8888格式
    
    Glide加载的图片没有Picasso那么平滑，但是很难察觉

磁盘缓存：

    Picasso缓存的是全尺寸的。而Glide缓存的跟ImageView尺寸相同， 将ImageView调整成不同大小不管大小如何设置。Picasso只缓存一个全尺寸的。
    Glide则不同，它会为每种大小的ImageView缓存一次Glide的这种方式优点是加载显示非常快。而Picasso的方式则因为需要在显示之前重新调整大小而导致一些延迟，Glide比Picasso快，虽然需要更大的空间来缓存。

Gif动图

    Glide可以加载Gif动图，Picasso不可以加载动图
    
    Glide动画会消耗太多的内存，因此使用时谨慎使用

区别：

    Glide比Picasso需要更大的空间来缓存，但Glide比Picasso加载速度快
    
    Glide加载图像及磁盘缓存的方式都优于Picasso，且Glide更有利于减少OutOfMemoryError的发生；
    
    Glide可以加载Gif动图，Picasso不可以加载动图

### 28.3.LruCache的原理是什么？
    LruCache的实现需要两个数据结构：双向链表和哈希表。
    双向链表用于记录元素被塞进cache的顺序，然后淘汰最久未使用的元素。
    哈希表用于直接记录元素的位置，即用O(1)的时间复杂度拿到链表的元素。
    
    get的操作逻辑：根据传入的key(图片url的MD5值)去哈希表里拿到对应的元素，如果元素存在，就把元素挪到链表的尾部。
    put的操作逻辑：首先判断key是否在哈希表里面，如果在的话就去更新值，并把元素挪到链表的尾部。
                 如果不在哈希表里，说明是一个新的元素。这时候需要去判断此时cache的容量了，
                 如果超过了最大的容量，就淘汰链表头部的元素，再将新的元素插入链表的尾部，如果没有超过最大容量，
                 直接在链表尾部追加新的元素。

**为啥要用LinkedHashMap的数据结构？？**
HashMap是无序的，当我们希望有顺序地去存储key-value时，就需要使用LinkedHashMap了.

### 28.4.Arouter

**见23.7**

###  28.5.Retrofit

1.通过建造者模式（builder模式）构建一个Retrofit实例

2.通过Retrofit对象的create方法返回一个Service的动态代理对象

3.调用service的方法的时候解析接口注解

4 .调用Okhttp的网络请求方法,通过 回调执行器 切换线程（子线程 ->>主线程）


动态代理

运行时创建的代理类，在委托类的方法前后去做一些事情

在运行过程中，会在虚拟机内部创建一个Proxy的类。通过实现InvocationHandler的接口，来代理委托类的函数。

使用动态代理来对接口中的注释进行解析，解析后完成OkHttp的参数构建。

优点

代理类原始类脱离联系，在原始类和接口未知的时候就确定代理类的行为

###  28.6.LeakCanary

**1.四种引用**

JVM通过垃圾回收器对这四种引用做不同的处理

1.强引用

指向的对象任何时候都不会被回收,垃圾回收器宁愿抛出OOM也不会对该对象进行回收

2.软引用

但是如果内存空间不足 ，才回去回收软引用中的对象.

3.弱引用

当发生垃圾回收时，不管当前内存是否足够，都会将弱引用关联的对象进行回收。

4.虚引用

虚引用必须和引用队列一同使用

ReferenceQueue

如果软/弱/虚引用中的对象被回收，那么软/弱/虚引用就会被 JVM加入关联的引用队列ReferenceQueue中

是说我们可以通过监控引用队列来判断Reference引用的对象是否被回收，从而执行相应的方法。

1.Application类提供的registerActivityLifecycleCallback(ActivityLifecycleCallbacks callback)方法来注册 ActivityLifecycleCallbacks回调，这样就能对当前应用程序中所有的Activity的生命周期事件进行集中处理，当监听到 Activity 或 Fragment onDestroy() 时，把他们放到一个弱引用WeakReference 中。

2.把弱引用WeakReference 关联到一个引用队列ReferenceQueue。（如果弱引用关联的对象被回收，则会把这个弱引用加入到ReferenceQueue中）。

3.延时5秒检测ReferenceQueue中是否存在当前弱引用对象。

4.如果检测不到说明可能发生泄露，通过gcTrigger.runGc()手动掉用GC。
遍历ReferenceQueue中所有的记录，当未回收对象个数大于5个时,dump heap获取内存快照hprof文件。

5.使用Shark解析hprof文件,Hprof.open()把heapDumpFile转换成Hprof对象，

6.根据heap中的对象关系图HprofHeapGraph获取泄露对象的objectIds

7.找出内存泄漏对象到GC roots的最短路径

8.输出分析结果展示到页面。

### 28.7.EventBus和广播的区别

1. 广播是四大组件之一，EventBus是开源框架。
1. 广播不能执行耗时操作，如果超过10s，会导致ANR。
1. 广播非常耗资源，而EventBus非常轻量。
1. 广播容易获取Context和Intent。
1. EventBus切换线程非常方便，只需要修改注释既可。
1. 广播可以跨进程，EventBus不可以。

# Java

## 1.HashMap

https://zhuanlan.zhihu.com/p/76735726

https://juejin.im/post/6844903921190699022#heading-0

https://tech.meituan.com/2016/06/24/java-hashmap.html

### 1.1.HashMap原理

https://segmentfault.com/a/1190000038989327

https://cloud.tencent.com/developer/article/1491634

jdk8后采用`数组`+`链表`+`红黑树`的数据结构，利用元素的key的hash值对数组长度取模得到在数组上的位置。当出现hash值一样的情形，就在数组上的对应位置形成一条链表。据碰撞越来越多大于8（也即链表长度大于8）的时候,就会把链表转换成红黑树。

![HashMap原理](https://raw.githubusercontent.com/treech/PicRemote/master/common/HashMap%E5%8E%9F%E7%90%86.png)

### 1.2.HashMap中put()如何实现的

理解一：

https://segmentfault.com/a/1190000038989327

![HashMap数据插入原理](https://raw.githubusercontent.com/treech/PicRemote/master/common/HashMap%E6%95%B0%E6%8D%AE%E6%8F%92%E5%85%A5%E5%8E%9F%E7%90%86.png)

1. 判断数组是否为空，为空进行初始化;
2. 不为空，计算 key 的 hash 值，通过(n - 1) & hash计算应当存放在数组中的下标 index;
3. 查看 table[index] 是否存在数据，没有数据就构造一个 Node 节点存放在 table[index] 中；
4. 存在数据，说明发生了 hash 冲突(存在二个节点 key 的 hash 值一样), 继续判断 key 是否相等，相等，用新的 value 替换原数据(onlyIfAbsent 为 false)；
5. 如果不相等，判断当前节点类型是不是树型节点，如果是树型节点，创造树型节点插入红黑树中；
6. 如果不是树型节点，创建普通 Node 加入链表中；判断链表长度是否大于 8， 大于的话链表转换为红黑树；
7. 插入完成之后判断当前节点数是否大于阈值，如果大于开始扩容为原数组的二倍。

理解二：

https://blog.csdn.net/qq_38182963/article/details/78942764

1.Key.hashCode和无符号右移16位做异或运算得到hash值,取模运算计算下标index

对key的hashCode 和右移16位做异或运算,之后hash(key) & (capacity - 1)做按位与运算得到下标。

2.下标的位置没有元素说明没有发生碰撞，直接添加元素到散列表中去

3.如果发生了碰撞(hash值相同)，进行三种判断

   3.1:若key地址相同或equals相同，则替换旧值

   3.2:key不相等，如果是红黑树结构，就调用树的插入方法

   3.3:key不相等，也不是红黑树，循环遍历直到链表中某个节点为空，用尾插法（1.8）/头插法（1.7）创建新结点插入到链表中，遍历到有节点哈希值相同则覆盖，如果，链表的长度大于等于8了，则将链表改为红黑树。

4.如果桶满了大于阀值，则resize进行扩容

### 1.3.HashMap中get()如何实现的

1.Key.hashCode的高16位做异或运算得到hash值,取模运算计算下标index

2.找到所在的链表的头结点,遍历链表，如果key值相等，返回对应的value值,否则返回null

### 1.4.HashMap的初始容量怎么设定？

 一般如果new HashMap() 不传值，默认大小是 16，负载因子是 0.75， 如果自己传入初始大小 k，初始化大小为 大于 k 的 2 的整数次方，例如如果传 10，大小为 16。（补充说明:实现代码如下）

```java
static final int tableSizeFor(int cap) {
  int n = cap - 1;
  n |= n >>> 1;
  n |= n >>> 2;
  n |= n >>> 4;
  n |= n >>> 8;
  n |= n >>> 16;
  return (n < 0) ? 1 : (n >= MAXIMUM_CAPACITY) ? MAXIMUM_CAPACITY : n + 1;
}
```

> 补充说明：下图是详细过程，算法就是让初始二进制右移 1，2，4，8，16 位，分别与自己异或，把高位第一个为 1 的数通过不断右移，把高位为1 的后面全变为 1，111111 + 1 = 1000000 = 2的6次方（符合大于 50 并且是 2 的整数次幂 ）

![HashMap初始容量计算](https://raw.githubusercontent.com/treech/PicRemote/master/common/HashMap%E5%88%9D%E5%A7%8B%E5%AE%B9%E9%87%8F%E8%AE%A1%E7%AE%97.png)

### 1.5.HashMap的哈希函数怎么设计的？

hash 函数是先拿到通过 key 的 hashcode，是 32 位的 int 值，然后让 hashcode 的高 16 位和低 16 位进行异或操作。

![hash函数设计](https://raw.githubusercontent.com/treech/PicRemote/master/common/hash%E5%87%BD%E6%95%B0%E8%AE%BE%E8%AE%A1.png)

### 1.6.HashMap和HashTable的区别是什么？

**HashMap不是线程安全的**

HashMap是map接口的子类，是将键映射到值的对象，其中键和值都是对象，并且不能包含重复键，但可以包含重复值。HashMap允许null key和null value，而HashTable不允许。

**HashTable是线程安全。**

HashMap是HashTable的轻量级实现（非线程安全的实现），他们都完成了Map接口，主要区别在于HashMap允许空（null）键值（key）,由于非线程安全，效率上可能高于HashTable。

HashMap允许将null作为一个entry的key或者value，而HashTable不允许。 HashMap把HashTable的contains方法去掉了，改成containsValue和containsKey。因为contains方法容易让人引起误解。 Hashtable继承自Dictionary类，而HashMap是Java1.2引进的Map interface的一个实现。 最大的不同是，Hashtable的方法是Synchronize的，而HashMap不是，在多个线程访问Hashtable时，不需要自己为它的方法实现同步，而HashMap 就必须为之提供外同步。 Hashtable和HashMap采用的hash/rehash算法都大概一样，所以性能不会有很大的差。

### 1.7.为什么ConcurrentHashMap，HashTable不支持key，value为null？

因为HashMap是非线程安全的，默认单线程环境中使用，如果get(key)为null，可以通过containsKey(key)方法来判断这个key的value为null，还是不存在这个key，而ConcurrentHashMap，HashTable是线程安全的，在多线程操作时，因为get(key)和containsKey(key)两个操作和在一起不是一个原子性操作，可能在执行中间，有其他线程修改了数据，所以无法区分value为null还是不存在key。至于ConcurrentHashMap，HashTable的key不能为null，主要是设计者的设计意图。

### 1.8.ConcurrentHashMap的由来？

虽然jdk提供了HashMap和HashTable但是如何同时满足线程安全和效率高呢，显然这两个都无法满足，所以就诞生了ConcurrentHashMap神器，让我们应用于高并发场景。

该神器采用了分段锁策略，通过把整个Map分成N个Segment（类似HashTable），可以提供相同的线程安全，效率提升N倍，默认提升16倍。

ConcurrentHashMap的优点就是HashMap和HashTable的缺点，当然该神器也是不支持键值为null的

ConcurrentHashMap的出现也意味着HashTable的落幕，所以在以后的项目中，尽量少用HashTable。

### 1.9.ConcurrentHashMap原理

https://juejin.cn/post/6961288808742518798

ConcurrentHashMap 是 HashMap 的线程安全版本，其内部和 HashMap 一样，也是采用了数组 + 链表 + 红黑树的方式来实现。

如何实现线程的安全性？加锁。但是这个锁应该怎么加呢？在 HashTable 中，是直接在 put 和 get 方法上加上了 synchronized，理论上来说 ConcurrentHashMap 也可以这么做，但是这么做锁的粒度太大，会非常影响并发性能，所以在 ConcurrentHashMap 中并没有采用这么直接简单粗暴的方法，其内部采用了非常精妙的设计，大大减少了锁的竞争，提升了并发性能。

ConcurrentHashMap 中的初始化和 HashMap 中一样，而且容量也会调整为 2 的 N 次幂。

#### 1.9.1.JDK1.8 版本 ConcurrentHashMap 做了什么改进？

在 JDK1.7 版本中，ConcurrentHashMap 由数组 + Segment + 分段锁实现，其内部分为一个个段（Segment）数组，Segment 通过继承 ReentrantLock 来进行加锁，通过每次锁住一个 segment 来降低锁的粒度而且保证了每个 segment 内地操作的线程安全性，从而实现全局线程安全。下图就是 JDK1.7 版本中 ConcurrentHashMap 的结构示意图：

![ConcurrentHashMap分段锁机制](https://raw.githubusercontent.com/treech/PicRemote/master/common/ConcurrentHashMap%E5%88%86%E6%AE%B5%E9%94%81%E6%9C%BA%E5%88%B6.webp)

但是这么做的缺陷就是每次通过 hash 确认位置时需要 2 次才能定位到当前 key 应该落在哪个槽：

1. 通过 hash 值和 段数组长度-1 进行位运算确认当前 key 属于哪个段，即确认其在 segments 数组的位置。
2. 再次通过 hash 值和 table 数组（即 ConcurrentHashMap 底层存储数据的数组）长度 - 1进行位运算确认其所在桶。

为了进一步优化性能，在 jdk1.8 版本中，对 ConcurrentHashMap 做了优化，取消了分段锁的设计，取而代之的是通过 cas 操作和 synchronized 关键字来实现优化，而扩容的时候也利用了一种分而治之的思想来提升扩容效率，在 JDK1.8 中 ConcurrentHashMap 的存储结构和 HashMap 基本一致，如下图所示：

![ConcurrentHashMap新机制](https://raw.githubusercontent.com/treech/PicRemote/master/common/ConcurrentHashMap%E6%96%B0%E6%9C%BA%E5%88%B6.webp)

#### 1.9.2.为什么 key 和 value 不允许为 null？

在 HashMap 中，key 和 value 都是可以为 null 的，但是在 ConcurrentHashMap 中却不允许，这是为什么呢？

作者 Doug Lea 本身对这个问题有过回答，在并发编程中，null 值容易引来歧义， 假如先调用 get(key) 返回的结果是 null，那么我们无法确认是因为当时这个 key 对应的 value 本身放的就是 null，还是说这个 key 值根本不存在，这会引起歧义，如果在非并发编程中，可以进一步通过调用 containsKey 方法来进行判断，但是并发编程中无法保证两个方法之间没有其他线程来修改 key 值，所以就直接禁止了 null 值的存在。

而且作者 Doug Lea 本身也认为，假如允许在集合，如 map 和 set 等存在 null 值的话，即使在非并发集合中也有一种公开允许程序中存在错误的意思，这也是 Doug Lea 和 Josh Bloch（HashMap作者之一） 在设计问题上少数不同意见之一，而 ConcurrentHashMap 是 Doug Lea 一个人开发的，所以就直接禁止了 null 值的存在。

### 1.10.为什么HashMap线程不安全

1.多线程put的时候可能导致元素丢失

2.put非null元素后get出来的却是null

3.多线程扩容,引起的死循环问题

1.put的时候会根据tab[index]是否为空执行直接插入还是走链表红黑树逻辑, 并发时,如果两个put 的key发生了碰撞,同时执行判断tab[index]是否为空,两个都是空,会同时插入,就会导致其中一个线程的 put 的数据被覆盖。

2.元素个数超出threshold扩容会创建一个新hash表，最后将旧hash表中元素rehash到新的hash表中， 将旧数组中的元素置null。线程1执行put时，线程2执行去访问原table,get为null。

3.在扩容的时候可能会让链表形成环路。原因是会重新计算元素在新的table里面桶的位置，而且还会将链表翻转过来。
多线程并发resize扩容,头插造成了逆序A-B 变成了C-B  ,t1执行e为A，next为B挂起，
t2执行完毕导致B指向A，继续执行t1，他继续先头插eA，再头插nextB，
由于t2线程导致B后面有A，所以继续头插， A插到B前面,出现环状链表。
get一个在这个链表中不存在的key时，就会出现死循环了。

 https://juejin.im/post/6844903796225605640#heading-5

 https://coolshell.cn/articles/9606.html/comment-page-3#comments

 https://www.iteye.com/blog/firezhfox-2241043

### 1.11.HashMap1.7和1.8有哪些区别

参考: https://blog.csdn.net/qq_36520235/article/details/82417949

（1）由数组+链表的结构改为数组+链表+红黑树。

    拉链过长会严重影响hashmap的性能。
    在链表元素数量超过8时改为红黑树，少于6时改为链表，中间7不改是避免频繁转换降低性能。

（2）优化了高位运算的hash算法：h^(h>>>16)

     h^(h>>>16)将hashcode无符号右移16位，让高16位和低16位进行异或。

（3）扩容——扩容后，元素要么是在原位置，要么是在原位置再移动2次幂的位置，且链表顺序不变。

    扩容后数据存储位置的计算方式也不一样
    
    1.7是直接用hash值和需要扩容的二进制数进行与操作,1.8(n-1)&hash，位运算省去了重新计算hash，只需要判断hash值新增的位是0还是1，0的话索引没变，1的话索引变为原索引加原来的数组长度 ，且链表顺序不变。

（4）头插改为尾插——JDK1.7用的是头插法，而JDK1.8及之后使用的都是尾插法。  

    因为JDK1.7是用单链表进行的纵向延伸，当采用头插法时会容易出现逆序链表形成环路导致死循环问题。
    但是在JDK1.8之后是因为加入了红黑树,使用尾插法，能够避免出现逆序且链表死循环的问题。  

### 1.12.解决hash冲突的时候，为什么用红黑树

链表取元素是从头结点一直遍历到对应的结点，这个过程的复杂度是O(N) ，
而红黑树基于二叉树的结构，查找元素的复杂度为O(logN) ，
所以，当元素个数过多时，用红黑树存储可以提高搜索的效率。

### 1.13.红黑树的效率高，为什么不一开始就用红黑树存储呢？

红黑树虽然查询效率比链表高，但是结点占用的空间大，treenodes的大小大约是常规节点的两倍
只有达到一定的数目才有树化的意义，这是基于时间和空间的平衡考虑。
如果一开始就用红黑树结构，元素太少，新增效率又比较慢，无疑这是浪费性能的。

### 1.14.不用红黑树，用二叉查找树可以不


https://blog.csdn.net/T_yoo_csdn/article/details/87163439

但是二叉查找树在特殊情况下会变成一条线性结构

如果构建根节点以后插入的数据是有序的，那么构造出来的二叉搜索树就不是平衡树，而是一个链表，它的时间复杂度就是 O(n)，遍历查找会非常慢。

红黑树，每次更新数据以后再进行平衡，以此来保证其查找效率，它的时间复杂度就是 O(logN)。

### 1.15.为什么阀值是8才转为红黑树
 容器中节点分布在hash桶中的频率遵循泊松分布

 各个长度的命中概率依次递减，源码注释中给我们展示了1-8长度的具体命中概率。

 当长度为8的时候，概率概率仅为0.00000006，这么小的概率，大于上千万个数据时HashMap的红黑树转换几乎不会发生。

### 1.16.为什么退化为链表的阈值是6
主要是一个过渡，避免链表和红黑树之间频繁的转换。
如果一个HashMap不停的插入、删除元素，链表个数在8左右徘徊，
就会频繁的发生树转链表、链表转树，效率会很低。

### 1.17.Hash冲突你还知道哪些解决办法？
 (1)开放定址法
 (2)链地址法
 (3)再哈希法
 (4)公共溢出区域法


### 1.18.HashMap在什么条件下扩容
如果bucket满了(超过load factor*current capacity)，就要resize。

为什么负载因子是0.75
小于0.5，空着一半就扩容了， 如果是0.5 ， 那么每次达到容量的一半就进行扩容，默认容量是16， 达到8就扩容成32，达到16就扩容成64， 最终使用空间和未使用空间的差值会逐渐增加，空间利用率低下。

当负载因子是1.0的时候， 出现大量的Hash的冲突时，底层的红黑树变得异常复杂。对于查询效率极其不利。这种情况就是牺牲了时间来保证空间的利用率。

是0.75的时候

空间利用率比较高，而且避免了相当多的Hash冲突，使得底层的链表或者是红黑树的高度比较低，提升了空间效率。


### 1.19.HashMap中hash函数怎么实现的？还有哪些hash函数的实现方式？

对key的hashCode 和右移16位做异或运算,之后hash(key) & (capacity - 1)做按位与运算得到下标。

Hash函数是指把一个大范围映射到一个小范围。把大范围映射到一个小范围的目的往往是为了节省空间，使得数据容易保存。

如果不同的输入得到了同一个哈希值，就发生了"哈希碰撞"（collision）。

比较出名的有MurmurHash、MD4、MD5等等。


### 1.20.为什么不直接将hashcode作为哈希值去做取模,而是要先高16位异或低16位?

均匀散列表的下标，降低hash冲突的几率。
不融合高低位，hashcode返回的值都是高位的变动的话,造成散列的值都是同一个。
融合后，高位的数据会影响到 index 的变换，依然可以保持散列的随机性。
打个比方，当我们的length为16的时候，哈希码(字符串“abcabcabcabcabc”的key对应的哈希码)对(16-1)与操作，对于多个key生成的hashCode，只要哈希码的后4位为0，不论不论高位怎么变化，最终的结果均为0。
扰动函数优化后：减少了碰撞的几率。

### 1.21.为什么扩容是2的次幂?

**%运算不如位移运算快**

在 B 是 2 的幂情况下：A % B = A & (B - 1)

和这个(n - 1) & hash的计算方法有着千丝万缕的关系
按位与&的计算方法是，只有当对应位置的数据都为1时，运算结果也为1，当HashMap的容量是2的n次幂时，(n-1)的2进制也就是1111111***111这样形式的，这样与添加元素的hash值进行位运算时，能够充分的散列，使得添加的元素均匀分布在HashMap的每个位置上，减少hash碰撞。

例如长度为8时候，3&(8-1)=3 2&(8-1)=2 ，不同位置上，不碰撞。

而长度为5的时候，3&(5-1)=0 2&(5-1)=0，都在0上，出现碰撞了

### 1.22.链表的查找的时间复杂度是多少?

HashMap 如果完全不存在冲突则 通过 key 获取 value 的时间复杂度就是 O(1)， 如果出现哈希碰撞，HashMap 里面每一个数组(桶)里面存的其实是一个链表，这时候再通过 key 获取 value 的时候时间复杂度就变成了 O(n)， HashMap 当一个 key 碰撞次数超过8 的时候就会把链表转换成红黑树，使得查询的时间复杂度变成了O(logN)。
 通过高16位异或低16位运算降低hash冲突几率。

### 1.23.红黑树

## 2.链表

### 2.1.数据结构中数组和链表的区别？

**数组** 和 **链表** 之间的主要区别在于它们的结构。数组是基于索引的数据结构，其中每个元素与索引相关联。另一方面，链表依赖于引用，其中每个节点由数据和对前一个和下一个元素的引用组成。

- 数组是数据结构，包含类似类型数据元素的集合，而链表被视为非基元数据结构，包含称为节点的无序链接元素的集合。
- 在数组中元素属于索引，即，如果要进入第四个元素，则必须在方括号内写入变量名称及其索引或位置。但是，在链接列表中，您必须从头开始并一直工作，直到达到第四个元素。
- 虽然访问元素数组很快，而链接列表需要线性时间，但速度要慢得多。
- 数组中插入和删除等操作会占用大量时间。另一方面，链接列表中这些操作的性能很快。
- 数组具有固定大小。相比之下，链接列表是动态和灵活的，可以扩展和缩小其大小。
- 在数组中，在编译期间分配内存，而在链接列表中，在执行或运行时分配内存。
- 元素连续存储在数组中，而它随机存储在链接列表中。
- 由于实际数据存储在数组中的索引中，因此对内存的要求较少。相反，由于存储了额外的下一个和前一个引用元素，因此链接列表中需要更多内存。
- 此外，阵列中的内存利用效率低下。相反，内存利用率在阵列中是有效的。

图表对比：

![链表和数组的区别](https://raw.githubusercontent.com/treech/PicRemote/master/common/%E9%93%BE%E8%A1%A8%E5%92%8C%E6%95%B0%E7%BB%84%E7%9A%84%E5%8C%BA%E5%88%AB.jpg)

需要额外说明的是: **即便是排好序的数组，你用二分查找，时间复杂度也是 O(logn)。所以，正确的表述应该是，数组支持随机访问，根据下标随机访问的时间复杂度为 O(1)**。

**如果你的代码对内存的使用非常苛刻，那数组就更适合你。因为链表中的每个结点都需要消耗额外的存储空间去存储一份指向下一个结点的指针，所以内存消耗会翻倍。而且，对链表进行频繁的插入、删除操作，还会导致频繁的内存申请和释放，容易造成内存碎片，触发语言本身的垃圾回收操作。**

## 3.JVM

### 3.1.什么是虚拟机

 Java 虚拟机是一个字节码翻译器，它将字节码文件翻译成各个系统对应的机器码，确保字节码文件能在各个系统正确运行。 Java 虚拟机规范去读取 Class 文件，并按照规定去解析、执行字节码指令。

### 3.2.Jvm的内存模型

![jvm3](https://raw.githubusercontent.com/treech/PicRemote/master/common/jvm3.png)

https://www.cnblogs.com/chanshuyi/p/jvm_serial_06_jvm_memory_model.html

https://www.cnblogs.com/yychuyu/p/13275970.html

https://juejin.cn/post/6844903636829487112#heading-22

线程都共享的部分：Java 堆、方法区、常量池

线程的私有数据：PC寄存器、Java 虚拟机栈、本地方法栈

**Java 堆**

Java 堆指的是从 JVM 划分出来的一块区域，这块区域专门用于 Java 实例对象的内存分配，几乎所有实例对象都在会这里进行内存的分配

Java 堆根据对象存活时间的不同，Java 堆还被分为年轻代、老年代两个区域，年轻代还被进一步划分为 Eden 区、From Survivor 0、To Survivor 1 区

![jvm6](https://raw.githubusercontent.com/treech/PicRemote/master/common/jvm6.png)

当有对象需要分配时，一个对象永远优先被分配在年轻代的 Eden 区，等到 Eden 区域内存不够时，Java 虚拟机会启动垃圾回收。此时 Eden 区中没有被引用的对象的内存就会被回收，而一些存活时间较长的对象则会进入到老年代

什么 Java 堆要进行这样一个区域划分

虚拟机中的对象必然有存活时间长的对象，也有存活时间短的对象，这是一个普遍存在的正态分布规律。如果因为存活时间短的对象有很多，那么势必导致较为频繁的垃圾回收。而垃圾回收时不得不对所有内存都进行扫描，但其实有一部分对象，它们存活时间很长，对他们进行扫描完全是浪费时间。因此为了提高垃圾回收效率

**Java虚拟机栈**

 Java 虚拟机栈，线程私有，生命周期和线程一致

每一个运行时的线程，都有一个独立的栈。栈中记录了方法调用的历史，每有一次方法调用，栈中便会多一个栈桢

每个方法在执行时都会创建一个栈帧(Stack Frame)用于存储局部变量表、操作数栈、动态链接、方法出口等信息。每一个方法从调用直至执行结束，就对应着一个栈帧从虚拟机栈中入栈到出栈的过程。

撕开栈帧，一不小心，局部变量表、操作数栈、动态链接、方法出口 哗啦啦地散落一地。

栈桢中通常包含四个信息：

局部变量：方法参数和方法中定义的局部变量,对象引用

操作数栈：存放的就是方法当中的各种操作数的临时空间

动态连接：Class文件的常量池中存在有大量的符号引用，而将部分符号引用在运行期间转化为直接引用,这种转化即为动态链接

返回地址：当前方法的返回地址，一个方法在执行完毕之后，就应该返回到方法外面之后继续执行main()后面的代码（应该返回到下一条指令执行位置）。

**本地方法栈**

与java虚拟机栈类似，不过存放的是native方法执行时的局部变量等数据存放位置。因为native方法一般不是由java语言编写的，常见的就是.dll文件当中的方法（由C/C++编写），比如Thread类中start()方法在运行时就会调用到一个start0()方法，查看源码时就会看到private native void start0();这个方法就是一个本地方法。本地方法的作用就相当于是一个“接口”，用来连接java和其他语言的接口。

**方法区**

![jvm5](https://raw.githubusercontent.com/treech/PicRemote/master/common/jvm5.png)

方法区中，存储了每个

1.类的信息

类的名称

类的访问描述符（public、private、default、abstract、final、static）

2.字段信息（该类声明的所有字段）

字段修饰符（public、protect、private、default）

字段的类型

字段名称

3.方法信息

方法修饰符

方法返回类型

方法名

4.类变量（静态变量）

 就是静态字段( public static String static_str="static_str";)

 虚拟机在使用某个类之前，必须在方法区为这些类变量分配空间。

5.指向类加载器的引用

6.指向Class实例的引用

7.运行时常量池(Runtime Constant Pool)

**永久代和方法区的关系**

《Java虚拟机规范》只是规定了有方法区这么个概念和它的作用，并没有规定如何去实现它。那么，在不同的 JVM 上方法区的实现肯定是不同的了。 同时大多数用的JVM都是Sun公司的HotSpot。在HotSpot上把GC分代收集扩展至方法区，或者说使用永久代来实现方法区。因此，我们得到了结论，永久代是HotSpot的概念，方法区是Java虚拟机规范中的定义，是一种规范，而永久代是一种实现，一个是标准一个是实现。其他的虚拟机实现并没有永久代这一说法。Java7及以前版本的Hotspot中方法区位于永久代中，HotSpot 使用永久代实现方法区，HotSpot 使用 GC分代来实现方法区内存回收。

**元空间**

Java8， HotSpots取消了永久代，那么是不是也就没有方法区了呢？当然不是，方法区是一个规范，规范没变，它就一直在。那么取代永久代的就是元空间。它可永久代有什么不同的？

存储位置不同，永久代物理是是堆的一部分，和新生代，老年代地址是连续的，而元空间属于本地内存；

存储内容不同，元空间存储类的元信息，静态变量和常量池等并入堆中。相当于永久代的数据被分到了堆和元空间中。

**Java8为什么要将永久代替换成Metaspace？**

字符串存在永久代中，容易出现性能问题和内存溢出。

类及方法的信息等比较难确定其大小，因此对于永久代的大小指定比较困 难，太小容易出现永久代溢出，太大则容易导致老年代溢出。

永久代会为 GC 带来不必要的复杂度，并且回收效率偏低。

**常量池**

分为Class常量池和运行时常量池，运行时的常量池是属于方法区的一部分，而Class常量池是Class文件中的。

**Class常量池**

![jvm4](https://raw.githubusercontent.com/treech/PicRemote/master/common/jvm4.png)

Class 文件中除了包含类的版本、字段、方法、接口等描述信息外，还有一项信息就是常量池 ，用于存放编译器生成的各种字面量 和符号引用 。

String str = "str";
int i = 1;
"str"和1都是字面量，有别于变量。

 符号引用：可以是任意类型的字面量。只要能无歧义的定位到目标。在编译期间由于暂时不知道类的直接引用，因此先使用符号引用代替。最终还是会转换为直接引用访问目标。

**运行时常量池**

运行时常量池相对于 Class 文件常量池来说具备动态性，Class 文件常量只是一个静态存储结构，里面的引用都是符号引用。而运行时常量池可以在运行期间将符号引用解析为直接引用

**字符串常量池**

运行时常量池中的字符串字面量若是成员的，则在类的加载初始化阶段就使用到了字符串常量池；若是本地的，则在使用到的时候（执行此代码时）才会使用到字符串常量池

在 jdk1.6（含）之前也是方法区的一部分，并且其中存放的是字符串的实例；

在 jdk1.7（含）之后是在堆内存之中，存储的是字符串对象的引用，字符串实例是在堆中；

jdk1.8 已移除永久代，字符串常量池是在本地内存当中，存储的也只是引用。

**程序计数器**

每个线程启动的时候，都会创建一个PC（Program Counter，程序计数器）寄存器，是保存线程当前正在执行的方法。如果这个方法不是 native 方法，那么 PC 寄存器就保存 Java 虚拟机正在执行的字节码指令地址。如果是 native 方法，那么 PC 寄存器保存的值是 undefined

### 3.3.类加载机制

https://www.cnblogs.com/chanshuyi/p/jvm_serial_07_jvm_class_loader_mechanism.html

https://zhuanlan.zhihu.com/p/33509426

http://www.ityouknow.com/jvm/2017/08/19/class-loading-principle.html

https://juejin.im/post/6876968255597051917#heading-12

Java 虚拟机把源码编译为字节码之后，虚拟机便可以将字节码读取进内存，从而进行解析、运行等整个过程，这个过程叫：Java 虚拟机的类加载机制。

JVM 虚拟机执行 class 字节码的过程可以分为七个阶段：加载、验证、准备、解析、初始化、使用、卸载。

在这五个阶段中，加载、验证、准备和初始化这四个阶段发生的顺序是确定的，而解析阶段则不一定，它在某些情况下可以在初始化阶段之后开始，这是为了支持Java语言的运行时绑定。

另外注意这里的几个阶段是按顺序开始，而不是按顺序进行或完成，因为这些阶段通常都是互相交叉地混合进行的，通常在一个阶段执行的过程中调用或激活另一个阶段。

https://blog.51cto.com/u_15080020/4438456

 ![JVM类加载流程](https://raw.githubusercontent.com/treech/PicRemote/master/common/JVM%E7%B1%BB%E5%8A%A0%E8%BD%BD%E6%B5%81%E7%A8%8B.png)

**加载**

简单来说，加载指的是把class字节码文件从各个来源通过类加载器装载入内存中。

- 通过一个类的全限定名来获取其定义的二进制字节流。
- 将这个字节流所代表的静态存储结构转化为方法区的运行时数据结构。
- 在Java堆中生成一个代表这个类的java.lang.Class对象，作为对方法区中这些数据的访问入口。

**验证**

主要是为了保证加载进来的字节流符合虚拟机规范，不会造成安全错误。

- 文件格式验证:验证字节流是否符合Class文件格式的规范；例如：是否以0xCAFEBABE开头、主次版本号是否在当前虚拟机的处理范围之内
- 元数据验证:对字节码描述的信息进行语义分析,类中的字段，方法是否与父类冲突？是否出现了不合理的重载？
- 字节码验证:保证程序语义的合理性，比如要保证类型转换的合理性。
- 符号引用验证:校验符号引用中的访问性（private，public等）是否可被当前类访问？

**准备**

主要是为类变量（注意，不是实例变量）分配内存，并且赋予初值

1.Java语言支持的变量类型有：

类变量：独立于方法之外的变量，用 static 修饰。

实例变量：独立于方法之外的变量，不过没有 static 修饰。

局部变量：类的方法中的变量。

在准备阶段，JVM 只会为「类变量」分配内存，而不会为「类成员变量」分配内存。「类成员变量」的内存分配需要等到初始化阶段才开始。

例如下面的代码在准备阶段，只会为 factor 属性分配内存，而不会为 website 属性分配内存。

public static int factor = 3;

public String website = "www.cnblogs.com/chanshuyi";

2.初始化的类型。在准备阶段，JVM 会为类变量分配内存，并为其初始化。但是这里的初始化指的是为变量赋予 Java 语言中该数据类型的零值，而不是用户代码里初始化的值。

例如下面的代码在准备阶段之后，sector 的值将是 0，而不是 3。

public static int sector = 3;

**解析**

将常量池内的符号引用替换为直接引用的过程。

在解析阶段，虚拟机会把所有的类名，方法名，字段名这些符号引用替换为具体的内存地址或偏移量，也就是直接引用。

举个例子来说，现在调用方法hello()，这个方法的地址是1234567，那么hello就是符号引用，1234567就是直接引用。

**初始化**

这个阶段主要是对类变量初始化，是执行类构造器的过程。

换句话说，只对static修饰的变量或语句进行初始化。

类初始化时机： 有当对类的主动使用的时候会先进行类的初始化，类的主动使用包括以下4种：

1.创建类的实例，调用类的静态方法,访问某个类或接口的静态变量如果类没有进行过初始化，则需要先触发其初始化

2.使用 java.lang.reflect 包的方法对类进行反射调用的时候，如果类没有进行过初始化，则需要先触发其初始化。

3.当虚拟机启动时，用户需要指定一个要执行的主类（包含main()方法的那个类），虚拟机会先初始化这个主类。

4.当初始化一个类的时候，如果发现其父类还没有进行过初始化，则需要先触发其父类的初始化

如果同时包含多个静态变量和静态代码块，则按照自上而下的顺序依次执行。

**java对象实例化时的顺序为：父类优于子类，静态优于非静态，只有在第一次创建对象的时候才会初始化静态块。**

1，父类的静态成员变量和静态代码块加载

2，子类的静态成员变量和静态代码块加载

3，父类成员变量和方法块加载

4，父类的构造函数加载

5，子类成员变量和方法块加载

6，子类的构造函数加载

### 3.4.类加载器

在 JVM 中有三个非常重要的编译器，它们分别是：前端编译器、JIT 编译器、AOT 编译器。

前端编译器，最常见的就是我们的 javac 编译器，其将 Java 源代码编译为 Java 字节码文件。JIT 即时编译器，其将 Java 字节码编译为本地机器代码。AOT 编译器则能将源代码直接编译为本地机器码。

ClassLoader 代表类加载器，是 java 的核心组件，可以说所有的 class 文件都是由类加载器从外部读入系统，然后交由 jvm 进行后续的连接、初始化等操作。

jvm 会创建三种类加载器，分别为启动类加载器、扩展类加载器和应用类加载器

**启动类加载器**

 主要负责加载系统的核心类，负责加载存放在JDK\jre\lib(JDK代表JDK的安装目录，下同)下

**扩展类加载器**

主要用于加载 lib\ext 中的 java 类，或者由java.ext.dirs系统变量指定的路径中的所有类库（如javax.开头的类

**应用类加载器**

Application ClassLoader 主要加载用户类，即加载用户类路径（ClassPath）上指定的类库，一般都是我们自己写的代码

**类加载有三种方式：**

1、命令行启动应用时候由JVM初始化加载

2、通过Class.forName()方法动态加载

3、通过ClassLoader.loadClass()方法动态加载

**Class.forName()和ClassLoader.loadClass()区别**

Class.forName()：将类的.class文件加载到jvm中之外，还会对类进行解释，执行类中的static块；

ClassLoader.loadClass()：只干一件事情，就是将.class文件加载到jvm中，不会执行static中的内容,只有在newInstance才会去执行static块。

Class.forName(name, initialize, loader)带参函数也可控制是否加载static块。并且只有调用了newInstance()方法采用调用构造函数，创建类的对象 。

Class.forName()方法实际上也是调用的CLassLoader来实现的。

**双亲委派模型**

https://www.cnblogs.com/hollischuang/p/14260801.html

双亲委派模型的工作流程是：如果一个类加载器收到了类加载的请求，它首先不会自己去尝试加载这个类，而是把请求委托给父加载器去完成，依次向上，因此，所有的类加载请求最终都应该被传递到顶层的启动类加载器中，只有当父加载器在它的搜索范围中没有找到所需的类时，即无法完成该加载，子加载器才会尝试自己去加载该类。

![jvm2](https://raw.githubusercontent.com/treech/PicRemote/master/common/jvm2.png)

**双亲委派模式优势**

避免重复加载 + 避免核心类篡改

采用双亲委派模式的是好处是Java类随着它的类加载器一起具备了一种带有优先级的层次关系，通过这种层级关可以避免类的重复加载，当父亲已经加载了该类时，就没有必要子ClassLoader再加载一次。其次是考虑到安全因素，java核心api中定义类型不会被随意替换，假设通过网络传递一个名为java.lang.Integer的类，通过双亲委托模式传递到启动类加载器，而启动类加载器在核心Java
API发现这个名字的类，发现该类已被加载，并不会重新加载网络传递的过来的java.lang.Integer，而直接返回已加载过的Integer.class，这样便可以防止核心API库被随意篡改。

### 3.5.垃圾回收机制

如何判断一个对象是死亡的

如果一个对象不可能再被引用，那么这个对象就是垃圾，应该被回收

https://www.zhihu.com/question/21539353

**引用计数法**

在一个对象被引用时加一，被去除引用时减一，对于计数器为0的对象意味着是垃圾对象，可以被GC回收。

优点：

引用计数收集器执行简单，判定效率高，交织在程序运行中。对程序不被长时间打断的实时环境比较有利。

缺点：

难以检测出对象之间的循环引用。 引用计数器增加了程序执行的开销。

**可达性算法**

从 GC Root 出发，所有可达的对象都是存活的对象，而所有不可达的对象都是垃圾。， 当一个对象到 GC Roots 没有任何引用链相连时, 即该对象不可达。

可以作为GC Roots的对象

虚拟机栈的局部变量引用的对象；

本地方法栈的JNI所引用的对象；

方法区的静态变量和常量所引用的对象；

https://blog.csdn.net/u010798968/article/details/72835255

![jvm7](https://raw.githubusercontent.com/treech/PicRemote/master/common/jvm7.jpg)

对象实例1、2、4、6都具有GC Roots可达性，也就是存活对象，不能被GC回收的对象。 而对于对象实例3、5直接虽然连通，但并没有任何一个GC Roots与之相连，这便是GC Roots不可达的对象，这就是GC需要回收的垃圾对象。

**垃圾回收算法**

**标记清除算法**

 对根集合进行扫描，对存活的对象进行标记。标记完成后，再对整个空间内未被标记的对象扫描，进行回收。

优点：

实现简单，不需要进行对象进行移动。

缺点：

标记、清除过程效率低，产生大量不连续的内存碎片，提高了垃圾回收的频率。

**标记压缩算法**

标记压缩算法可以说是标记清除算法的优化版
在标记阶段，从 GC Root 引用集合触发去标记所有对象。在压缩阶段，其则是将所有存活的对象压缩在内存的一边，之后清理边界外的所有空间。

优点：

解决了标记-清理算法存在的内存碎片问题。

缺点：

仍需要进行局部对象移动，一定程度上降低了效率。

**复制算法**

复制算法的核心思想是将原有的内存空间分为两块，每次只使用一块，在垃圾回收时，将正在使用的内存中的存活对象复制到未使用的内存块中。之后清除正在使用的内存块中的所有对象，之后交换两个内存块的角色，完成垃圾回收。

优点：

按顺序分配内存即可，实现简单、运行高效，不用考虑内存碎片。

缺点：

可用的内存大小缩小为原来的一半，对象存活率高时会频繁进行复制。

**分代收集算法**

JDK8堆内存一般是划分为年轻代和老年代，不同年代 根据自身特性采用不同的垃圾收集算法。

对于老年代，因为对象存活率高，没有额外的内存空间对它进行担保。因而适合采用标记-清理算法和标记-整理算法进行回收。试想一下，如果没有采用分代算法，而在老年代中使用复制算法。在极端情况下，老年代对象的存活率可以达到100%，那么我们就需要复制这么多个对象到另外一个内存区域，这个工作量是非常庞大的。

对于新生代，每次GC时都有大量的对象死亡，只有少量对象存活。比较适合采用复制算法。这样只需要复制少量对象，便可完成垃圾回收，并且还不会有内存碎片。

在实际的 JVM 新生代划分中，却不是采用等分为两块内存的形式。而是分为：Eden 区域、from 区域、to 区域 这三个区域。那么为什么 JVM 最终要采用这种形式，而不用 50% 等分为两个内存块的方式？

要解答这个问题，我们就需要先深入了解新生代对象的特点。根据IBM公司的研究表明，在新生代中的对象 98% 是朝生夕死的，所以并不需要按照1:1的比例来划分内存空间。所以在HotSpot虚拟机中，JVM 将内存划分为一块较大的Eden空间和两块较小的Survivor空间，其大小占比是8:1:1。当回收时，将Eden和Survivor中还存活的对象一次性复制到另外一块Survivor空间上，最后清理掉Eden和刚才用过的Eden空间。

通过这种方式，内存的空间利用率达到了90%，只有10%的空间是浪费掉了。而如果通过均分为两块内存，则其内存利用率只有 50%，两者利用率相差了将近一倍。

**java编译后是什么文件**

https://www.cnblogs.com/chanshuyi/p/jvm_serial_04_from_source_code_to_machine_code.html

https://blog.csdn.net/qq_36791569/article/details/80269482

https://blog.csdn.net/q978090365/article/details/109465148

https://cloud.tencent.com/developer/article/1630650

 javac 先将 Java 编译成class字节码文件 
编译完要执行   通过解释器解释执行和Jit编译器转为本地字节码执行  前者启动快运行慢 后者启动慢运行快 因为JIT会将所有字节码都转化为机器码并保存下来 而解释器边解释边运行

 Java9新特性AOT直接将class转为二进制可编译文件  和JIT区别是  运行前编译好，但缺点是全编译 不用的也编译了 不能动态加载 但避免了JIT运行时的内存消耗

## 4.多线程

### 4.1.Java中创建线程的方式

1.继承Thread类，重写run方法

2.实现Runnable接口，传递给Thread(runnable)构造函数

3.通过FutureTask 传递给Thread()构造函数

CallableTest callableTest = new CallableTest();

FutureTask<Integer> futureTask = new FutureTask<>(callableTest);

new Thread(futureTask).start();

创建FutureTask对象，创建Callable子类对象，复写call(相当于run)方法

创建Thread类对象，将FutureTask对象传递给Thread对象

4.通过ExecutorService 线程池创建多线程

#### 4.1.1.Callable和Runnable的区别

(1) Callable重写的是call()方法，Runnable重写的方法是run()方法

(2) call()方法执行后可以有返回值，run()方法没有返回值.运行Callable任务可以拿到一个Future对象，表示异步计算的结果 。通过Future对象可以了解任务执行情况，可取消任务的执行，还可获取执行结果

(3) call()方法可以抛出异常，run()方法不可以

#### 4.1.2.实现Runnable/Callable接口相比继承Thread类的优势

由于Java“单继承，多实现”的特性，Runnable接口使用起来比Thread更灵活。

如果使用线程时不需要使用Thread类的诸多方法，显然使用Runnable接口更为轻量。

#### 4.1.3.Callable如何使用

Callable一般是配合线程池工具ExecutorService来使用的，通过这个Future的get方法得到结果。

#### 4.1.4.Future和FutureTask

https://zhuanlan.zhihu.com/p/38514871

Future接口只有几个比较简单的方法：

public abstract interface Future<V> {
    public abstract boolean cancel(boolean paramBoolean);
    public abstract boolean isCancelled();
    public abstract boolean isDone();
    public abstract V get() throws InterruptedException, ExecutionException;
    public abstract V get(long paramLong, TimeUnit paramTimeUnit)
            throws InterruptedException, ExecutionException, TimeoutException;
}

　也就是说Future提供了三种功能：

　　1）判断任务是否完成；

　　2）能够中断任务；

　　3）能够获取任务执行结果。

　因为Future只是一个接口，所以是无法直接用来创建对象使用的，因此就有了下面的FutureTask。

Future只是一个接口，而它里面的cancel，get，isDone等方法要自己实现起来都是非常复杂的。所以JDK提供了一个FutureTask类来供我们使用。

可以看出RunnableFuture继承了Runnable接口和Future接口，而FutureTask实现了RunnableFuture接口。所以它既可以作为Runnable被线程执行，又可以作为Future得到Callable的返回值。

### 4.2. 线程的几种状态

https://www.jianshu.com/p/3bdba2ab5b5a

### 4.3. 谈谈线程死锁，如何有效的避免线程死锁？

https://www.cnblogs.com/xiaoxi/p/8311034.html

**什么是死锁**

死锁 :在两个或多个并发进程中，如果每个进程持有某种资源而又都等待别的进程释放它或它们现在保持着的资源，在未改变这种状态之前都不能向前推进，称这一组进程产生了死锁


例如，某计算机系统中只有一台打印机和一台输入 设备，进程P1正占用输入设备，同时又提出使用打印机的请求，但此时打印机正被进程P2 所占用，而P2在未释放打印机之前，又提出请求使用正被P1占用着的输入设备。这样两个进程相互无休止地等待下去，均无法继续执行，此时两个进程陷入死锁状态。

**死锁产生的原因**

1. 系统资源的竞争

通常系统中拥有的不可剥夺资源，其数量不足以满足多个进程运行的需要，使得进程在运行过程中，会因争夺资源而陷入僵局。

2. 进程推进顺序非法

进程在运行过程中，请求和释放资源的顺序不当，也同样会导致死锁。例如，并发进程 P1、P2分别保持了资源R1、R2，而进程P1申请资源R2，进程P2申请资源R1时，两者都会因为所需资源被占用而阻塞。

3. 信号量使用不当也会造成死锁。

进程间彼此相互等待对方发来的消息，结果也会使得这些进程间无法继续向前推进。例如，进程A等待进程B发的消息，进程B又在等待进程A发的消息，可以看出进程A和B不是因为竞争同一资源，而是在等待对方的资源导致死锁。


**如何避免死锁**

1加锁顺序

线程按照一定的顺序加锁当，多个线程需要相同的一些锁，但是按照不同的顺序加锁，死锁就很容易发生。如果能确保所有的线程都是按照相同的顺序获得锁，那么死锁就不会发生

2加锁时限

在尝试获取锁的时候加一个超时时间，超过时限则放弃对该锁的请求，并释放自己占有的锁

3死锁检测

每当一个线程获得了锁，会在线程和锁相关的数据结构中（map、graph等等）将其记下。除此之外，每当有线程请求锁，也需要记录在这个数据结构中。

当一个线程请求锁失败时，这个线程可以遍历锁的关系图看看是否有死锁发生。例如，线程A请求锁7，但是锁7这个时候被线程B持有，这时线程A就可以检查一下线程B是否已经请求了线程A当前所持有的锁。如果线程B确实有这样的请求，那么就是发生了死锁

那么当检测出死锁时，这些线程该做些什么呢？

一个可行的做法是释放所有锁，回退，并且等待一段随机的时间后重试。这个和简单的加锁超时类似，不一样的是只有死锁已经发生了才回退，而不会是因为加锁的请求超时了。

### 4.4. 如何实现多线程中的同步

**synchronized对代码块或方法加锁**

**reentrantLock加锁结合Condition条件设置**

**volatile关键字**

**cas使用原子变量实现线程同步**

**参照UI线程更新UI的思路，使用handler把多线程的数据更新都集中在一个线程上，避免多线程出现脏读**

### 4.5.synchronized 底层实现原理

https://segmentfault.com/a/1190000041268785

![synchronized同步锁](https://raw.githubusercontent.com/treech/PicRemote/master/common/synchronized%E5%90%8C%E6%AD%A5%E9%94%81.png)

主要有3种使用方式:

**1.修饰实例方法：作用于当前实例加锁**

```java
public synchronized void method(){
        // 代码
}
```

**2.修饰静态方法：作用于当前类对象加锁**

```java
public static synchronized void method(){
       // 代码

}
```

**3.修饰代码块：指定加锁对象，对给定对象加锁**

```java
synchronized(this){
 //代码                                  

}
```

**Synchronized的底层实现**

synchronized的底层实现是完全依赖JVM虚拟机的,所以谈synchronized的底层实现，就不得不谈数据在JVM内存的存储：Java对象头，以及Monitor对象监视器。

**1.Java对象头**

在JVM虚拟机中，对象在内存中的存储布局，可以分为三个区域:

- 对象头(Header)
- 实例数据(Instance Data)
- 对齐填充(Padding)

**Java对象头主要包括两部分数据：**

![Synchronized锁对象存储](https://raw.githubusercontent.com/treech/PicRemote/master/common/Synchronized%E9%94%81%E5%AF%B9%E8%B1%A1%E5%AD%98%E5%82%A8.png)

**1)类型指针（Klass Pointer）**

是对象指向它的类元数据的指针，虚拟机通过这个指针来确定这个对象是哪个类的实例;

**2)标记字段(Mark Word)**

用于存储对象自身的运行时数据，如哈希码（HashCode）、GC分代年龄、锁状态标志、线程持有的锁、偏向线程 ID、偏向时间戳等等,它是实现轻量级锁和偏向锁的关键.

所以，很明显synchronized使用的锁对象是存储在Java对象头里的标记字段里。

**2.Monitor**

monitor描述为对象监视器,可以类比为一个特殊的房间，这个房间中有一些被保护的数据，monitor保证每次只能有一个线程能进入这个房间进行访问被保护的数据，进入房间即为持有monitor，退出房间即为释放monitor。

下图是synchronized同步代码块反编译后的截图，可以很清楚的看见monitor的调用。

![synchronized调用的反编译](https://raw.githubusercontent.com/treech/PicRemote/master/common/synchronized%E8%B0%83%E7%94%A8%E7%9A%84%E5%8F%8D%E7%BC%96%E8%AF%91.png)

使用syncrhoized加锁的同步代码块在字节码引擎中执行时，主要就是通过锁对象的monitor的取用(monitorenter)与释放(monitorexit)来实现的。

**3.线程状态流转在Monitor上体现**

当多个线程同时请求某个对象监视器时，对象监视器会设置几种状态用来区分请求的线程：

Contention List：所有请求锁的线程将被首先放置到该竞争队列
Entry List：Contention List中那些有资格成为候选人的线程被移到Entry List
Wait Set：那些调用wait方法被阻塞的线程被放置到Wait Set
OnDeck：任何时刻最多只能有一个线程正在竞争锁，该线程称为OnDeck
Owner：获得锁的线程称为Owner
!Owner：释放锁的线程
下图反映了个状态转换关系:

![monitor对象监控器](https://raw.githubusercontent.com/treech/PicRemote/master/common/monitor%E5%AF%B9%E8%B1%A1%E7%9B%91%E6%8E%A7%E5%99%A8.png)

Synchronized 的锁升级
锁解决了数据的安全性，但是同样带来了性能的下降，hotspot 虚拟机的作者经过调查发现，大部分情况下，加锁的代码不仅仅不存在多线程竞争，而且总是由同一个线程多次获得。

所以基于这样一个概率,synchronized 在JDK1.6 之后做了一些优化，为了减少获得锁和释放锁来的性能开销，引入了偏向锁、轻量级锁，锁的状态根据竞争激烈的程度从低到高不断升级。

![synchronized锁升级](https://raw.githubusercontent.com/treech/PicRemote/master/common/synchronized%E9%94%81%E5%8D%87%E7%BA%A7.png)

**1.无锁**

无锁没有对资源进行锁定，所有的线程都能访问并修改同一个资源，但同时只有一个线程能修改成功。

**2.偏向锁**

偏向锁是JDK6中引入的一项锁优化，大多数情况下，锁不仅不存在多线程竞争，而且总是由同一线程多次获得，为了让线程获得锁的代价更低而引入了偏向锁。

偏向锁会偏向于第一个获得它的线程，如果在接下来的执行过程中，该锁没有被其他的线程获取，则持有偏向锁的线程将永远不需要同步。

**3.轻量级锁**

是指当锁是偏向锁的时候，被另外的线程所访问，偏向锁就会升级为轻量级锁，其他线程会通过自旋的形式尝试获取锁，不会阻塞，从而提高性能。

**4.重量级锁**

指的是原始的Synchronized的实现，重量级锁的特点：其他线程试图获取锁时，都会被阻塞，只有持有锁的线程释放锁之后才会唤醒这些线程。

### 4.6.  synchronized和Lock的使用、区别、原理；

https://juejin.cn/post/6844903542440869896#heading-17

**使用**

synchronized

修饰实例方法

修饰静态方法

修饰代码块

当synchronized作用在实例方法时，监视器锁（monitor）便是对象实例（this）；
当synchronized作用在静态方法时，监视器锁（monitor）便是对象的Class实例，因为Class数据存在于永久代，因此静态方法锁相当于该类的一个全局锁；
当synchronized作用在某一个对象实例时，监视器锁（monitor）便是括号括起来的对象实例；（https://www.cnblogs.com/aspirant/p/11470858.html）

**类锁**：锁是加持在类上的，用synchronized static 或者synchronized(class)方法使用的锁都是类锁，因为class和静态方法在系统中只会产生一份，所以在单系统环境中使用类锁是线程安全的https://zhuanlan.zhihu.com/p/31537595

**对象锁**：synchronized 修饰非静态的方法和synchronized(this)都是使用的对象锁，一个系统可以有多个对象实例，所以使用对象锁不是线程安全的，除非保证一个系统该类型的对象只会创建一个（通常使用单例模式）才能保证线程安全;

lock

Lock和ReadWriteLock是两大锁的根接口,Lock代表实现类是ReentrantLock（可重入锁），ReadWriteLock（读写锁）的代表实现类是ReentrantReadWriteLock

Lock

 lock()、tryLock()、tryLock(long time, TimeUnit unit) 和 lockInterruptibly()都是用来获取锁的

 lock：用来获取锁

unlock：释放锁   如果采用Lock，必须主动去释放锁，并且在发生异常时，不会自动释放锁。

tryLock：tryLock方法是有返回值的，它表示用来尝试获取锁，如果获取成功，则返回true，如果获取失败（即锁已被其他线程获取），则返回false，

lockInterruptibly：通过这个方法去获取锁时，如果线程正在等待获取锁，则这个线程能够响应中断，即中断线程的等待状态。

ReadWriteLock 接口只有两个方法：

//返回用于读取操作的锁
Lock readLock() 
//返回用于写入操作的锁 
Lock writeLock()

ReetrantLock

可重入锁又名递归锁，是指在同一个线程在外层方法获取锁的时候，再进入该线程的内层方法会自动获取锁（前提锁对象得是同一个对象或者class），不会因为之前已经获取过还没释放而阻塞
Java中ReentrantLock和synchronized都是可重入锁，可重入锁的一个优点是可一定程度避免死锁。

原理

首先ReentrantLock和NonReentrantLock都继承父类AQS，其父类AQS中维护了一个同步状态status来计数重入次数，status初始值为0。

当线程尝试获取锁时，可重入锁先尝试获取并更新status值，如果status == 0 则把status置为1，当前线程开始执行。如果status != 0，则判断当前线程是否是获取到这个锁的线程，如果是的话执行status+1，且当前线程可以再次获取锁。而非可重入锁是 如果status != 0的话会导致其获取锁失败，当前线程阻塞。

ReadWriteLock

 https://www.cnblogs.com/myseries/p/10784076.html（使用）

共享锁是指该锁可被多个线程所持有。如果线程T对数据A加上共享锁后， 获得共享锁的线程只能读数据，不能修改数据。

ReadWriteLock 维护了一对相关的锁，一个用于只读操作，另一个用于写入操作

只要没有 writer，读取锁可以由多个 reader 线程同时保持，而写入锁是独占的

**区别：**

synchronized在发生异常时，会自动释放线程占有的锁，因此不会导致死锁现象发生；而Lock在发生异常时，如果没有主动通过unLock()去释放锁，则很可能造成死锁现象，因此使用Lock时需要在finally块中释放锁；

Lock可以让等待锁的线程响应中断，而synchronized却不行

通过Lock可以知道有没有成功获取锁，而synchronized却无法办到。

原理

synchronized（https://juejin.cn/post/6844903670933356551#heading-6，https://juejin.cn/post/6844904181510176775#heading-6）

monitor描述为一种同步机制，它通常被描述为一个对象，当一个 monitor 被某个线程持有后，它便处于锁定状态

每个对象都存在着一个 monitor 与之关联

jvm基于进入和退出Monitor对象来实现方法同步和代码块同步。

对象头和Monitor对象

对象头

synchronized 用的锁是存在Java对象头里的

Hopspot 对象头主要包括两部分数据：Mark Word（标记字段） 和 Klass Pointer（类型指针）

Mark Word：

Java 6 及其以后，一个对象其实有四种锁状态，它们级别由低到高依次是
无锁状态
偏向锁状态
轻量级锁状态
重量级锁状态

当对象状态为偏向锁时，Mark Word存储的是偏向的线程ID；
当状态为轻量级锁时，Mark Word存储的是指向栈中锁记录的指针；
当状态为重量级锁时，Mark Word为指向堆中的monitor对象的指针

在HotSpot JVM实现中，锁有个专门的名字：对象监视器Object Monitor

同步代码块

从字节码中可知同步语句块的实现使用的是monitorenter和monitorexit指令

线程将试图获取对象锁对应的 monitor 的持有权， monitor的进入计数器为 0，那线程可以成功取得monitor，并将计数器值设置为1，取锁成功。

同步方法

方法级的同步是隐式，即无需通过字节码指令来控制的，它实现在方法调用和返回操作之中

当方法调用时，调用指令将会 检查方法的 访问标志是否被设置，如果设置了如果设置了，执行线程将先持有monitor（虚拟机规范中用的是管程一词），然后再执行方法，执行线程持有了monitor，其他任何线程都无法再获得同一个monitor。


### 4.7.synchronized和volatile的区别？为何不用volatile替代synchronized？

1. 线程通信模型（http://concurrent.redspider.group/article/02/6.html）

内存可见控制的是线程执行结果在内存中对其它线程的可见性。根据Java内存模型的实现，线程在具体执行时，会先拷贝主存数据到线程本地（CPU缓存），操作完成后再把结果从线程本地刷到主存

从抽象的角度来说，JMM（Java线程之间的通信由Java内存模型控制，简称JMM）定义了线程和主内存之间的抽象关系。

 一般来说，JMM中的主内存属于共享数据区域，他是包含了堆和方法区；同样，JMM中的本地内存属于私有数据区域，包含了程序计数器、本地方法栈、虚拟机栈。

根据JMM的规定，线程对共享变量的所有操作都必须在自己的本地内存中进行，不能直接从主内存中读取。

 所有的共享变量都存在主内存中。

每个线程都保存了一份该线程使用到的共享变量的副本。

如果线程A与线程B之间要通信的话，必须经历下面2个步骤：
线程A将本地内存A中更新过的共享变量刷新到主内存中去。
线程B到主内存中去读取线程A之前已经更新过的共享变量。

1. volatile修饰的变量具有可见性

volatile关键字解决的是内存可见性的问题，会使得所有对volatile变量的读写都会直接刷到主存，即保证了变量的可见性。这样就能满足一些对变量可见性有要求而对读取顺序没有要求的需求。

2. volatile禁止指令重排

使用volatile关键字仅能实现对原始变量(如boolen、 short 、int 、long等)操作的原子性
是i++，实际上也是由多个原子操作组成：read i; inc; write i，假如多个线程同时执行i++，volatile只能保证他们操作的i是同一块内存，但依然可能出现写入脏数据的情况。

区别

https://blog.csdn.net/suifeng3051/article/details/52611233
https://juejin.cn/post/6844903598644543502#heading-1

1、volatile仅能使用在变量级别；synchronized则可以使用在变量、方法、和类级别的

2、volatile仅能实现变量的修改可见性，不能保证原子性；而synchronized则可以保证变量的修改可见性和原子性

3、volatile不会造成线程的阻塞；synchronized可能会造成线程的阻塞

### 4.8.锁的分类，锁的几种状态，CAS原理

https://juejin.cn/post/6844904181510176775#heading-8
https://tech.meituan.com/2018/11/15/java-lock.html

无锁/偏向锁/轻量级锁/重量级锁

Hotspot的作者经过以往的研究发现大多数情况下锁不仅不存在多线程竞争，而且总是由同一线程多次获得，为了让线程获得锁的代价更低而引入了偏向锁。

四种状态的转换（http://concurrent.redspider.group/article/02/9.html）

1.每一个线程在准备获取共享资源时： 第一步，检查MarkWord里面是不是放的自己的ThreadId ,如果是，表示当前线程是处于 “偏向锁” 。

2.第二步，如果MarkWord不是自己的ThreadId，会尝试使用CAS来替换Mark Word里面的线程ID为新线程的ID，成功，仍然为偏向锁，失败，升级为轻量级锁，会按照轻量级锁的方式进行竞争锁。

3.CAS将锁的Mark Word替换为指向锁记录的指针，成功的获得资源，失败的则进入自旋 。

4.自旋的线程在自旋过程中，成功获得资源(即之前获的资源的线程执行完成并释放了共享资源)，则整个状态依然处于 轻量级锁的状态，如果自旋失败，进入重量级锁的状态，这个时候，自旋的线程进行阻塞，等待之前线程执行完成并唤醒自己。

乐观锁/悲观锁

 对于同一个数据的并发操作，悲观锁认为自己在使用数据的时候一定有别的线程来修改数据，因此在获取数据的时候会先加锁，确保数据不会被别的线程修改

而乐观锁认为自己在使用数据时不会有别的线程修改数据，所以不会添加锁，只是在更新数据的时候去判断之前有没有别的线程更新了这个数据。如果这个数据没有被更新，当前线程将自己修改的数据成功写入。如果数据已经被其他线程更新，则根据不同的实现方式执行不同的操作（例如报错或者自动重试）

悲观锁适合写操作多的场景，先加锁可以保证写操作时数据正确。
synchronized关键字和Lock的实现类都是悲观锁。

乐观锁适合读操作多的场景，不加锁的特点能够使其读操作的性能大幅提升。
java.util.concurrent包中的原子类就是通过CAS来实现了乐观锁。

为何乐观锁能够做到不锁定同步资源也可以正确的实现线程同步呢

**CAS全称 Compare And Swap（比较与交换）**，是一种无锁算法。在不使用锁（没有线程被阻塞）的情况下实现多线程之间的变量同步。java.util.concurrent包中的原子类就是通过CAS来实现了乐观锁。

CAS算法涉及到三个操作数：

进行比较的值 A。
要写入的新值 B。
需要读写的内存值 C。

AtomicInteger的自增函数incrementAndGet()的源码时

去比较寄存器中的 A 和 内存中的值 V。如果相等，就把要写入的新值 B 存入内存中。如果不相等，就将内存值 V 赋值给寄存器中的值 A。然后通过Java代码中的while循环再次调用cmpxchg指令进行重试，直到设置成功为止

可重入锁

可重入锁又名递归锁，是指在同一个线程在外层方法获取锁的时候，再进入该线程的内层方法会自动获取锁（前提锁对象得是同一个对象或者class），不会因为之前已经获取过还没释放而阻塞
Java中ReentrantLock和synchronized都是可重入锁，可重入锁的一个优点是可一定程度避免死锁。

自旋锁

阻塞或唤醒一个Java线程需要操作系统切换CPU状态来完成，这种状态转换需要耗费处理器时间。如果同步代码块中的内容过于简单，状态转换消耗的时间有可能比用户代码执行的时间还要长。

需让当前线程进行自旋，如果在自旋完成后前面锁定同步资源的线程已经释放了锁，那么当前线程就可以不必阻塞而是直接获取同步资源，从而避免切换线程的开销。这就是自旋锁。


### 4.9.为什么会有线程安全？如何保证线程安全

https://github.com/Moosphan/Android-Daily-Interview/issues/108


在多个线程访问共同资源时,在某一个线程对资源进行写操作中途(写入已经开始,还没结束),其他线程对这个写了一般资源进行了读操作,或者基于这个写了一半操作进行写操作,导致数据问题

原子性（java.util.concurrent.atomic 包）

即一个操作或者多个操作 要么全部执行并且执行的过程不会被任何因素打断，要么就都不执行

有序性( Synchronized, Lock)

即程序执行的顺序按照代码的先后顺序执行

可见性(Volatile)

指当多个线程访问同一个变量时，一个线程修改了这个变量的值，其他线程能够立即看得到修改的值。

### 4.10.sleep()与wait()区别,run和start的区别,notify和notifyall区别,锁池,等待池

https://blog.csdn.net/u012050154/article/details/50903326
https://github.com/Moosphan/Android-Daily-Interview/issues/117
 sleep()方法正在执行的线程主动让出CPU（然后CPU就可以去执行其他任务）,而并不会释放同步资源锁！！！

 wait()方法则是指当前线程让自己暂时退让出同步资源锁，只有调用了notify()方法，之前调用wait()的线程才会解除wait状态


sleep不需要唤醒，wait需要唤醒

1.run和start的区别

start() 可以启动一个新线程，run()不会

start()中的run代码可以不执行完就继续执行下面的代码
直接调用run方法必须等待其代码全部执行完才能继续执行下面的代码。

2.sleep wait区别

sleep是Thread方法，不会释放锁，wait是Object类的成员方法，会释放锁

sleep不需要Synchronized ，wait需要Synchronized

sleep休眠自动继续执行，wait需要notify来唤醒，得到锁

3.notify和notifyAll区别

notify是只唤醒一个等待的线程，noftifyAll是唤醒所有等待的线程

notify后只要一个线程会由等待池进入锁池，而notifyAll会将该对象等待池内的所有线程移动到锁池中，等待锁竞争

某个对象的wait()方法，线程A就会释放该对象的锁后，进入到了该对象的等待池中

https://www.zhihu.com/question/37601861/answer/145545371

锁池:假设线程A已经拥有了某个对象(注意:不是类)的锁，而其它的线程想要调用这个对象的某个synchronized方法(或者synchronized块)，由于这些线程在进入对象的synchronized方法之前必须先获得该对象的锁的拥有权，但是该对象的锁目前正被线程A拥有，所以这些线程就进入了该对象的锁池中。

等待池:假设一个线程A调用了某个对象的wait()方法，线程A就会释放该对象的锁后，进入到了该对象的等待池中

### 4.11.Java多线程通信

http://concurrent.redspider.group/article/01/2.html

### 4.12.Java多线程

https://blog.csdn.net/weixin_40271838/article/details/79998327

http://concurrent.redspider.group/article/03/12.html

Java中开辟出了一种管理线程的概念，这个概念叫做线程池，多次使用线程，也就意味着，我们需要多次创建并销毁线程。而创建并销毁线程的过程势必会消耗内存。

**好处**

创建/销毁线程需要消耗系统资源，线程池可以复用已创建的线程。

控制并发的数量。并发数量过多，可能会导致资源消耗过多，从而造成服务器崩溃。（主要原因）

可以对线程做统一管理。


**参数**

https://blog.csdn.net/weixin_40271838/article/details/79998327

线程池中的**corePoolSize就是线程池中的核心线程数量，这几个核心线程，只是在没有用的时候，也不会被回收**
maximumPoolSize**就是线程池中可以容纳的最大线程的数量**
keepAliveTime，就是线程池中除了核心线程之外的其他的最长可以保留的时间
TimeUnit unit：keepAliveTime的单位
BlockingQueue workQueue：阻塞队列，任务可以储存在任务队列中等待被执行。

两个非必须的参

ThreadFactory threadFactory

创建线程的工厂 ，用于批量创建线程，统一在创建线程时设置一些参数，如是否守护线程、线程的优先级

RejectedExecutionHandler handler

拒绝处理策略，线程数量大于最大线程数就会采用拒绝处理策略

**Java中的线程池共有几种**

https://www.jianshu.com/p/5936a2242322

**CachedThreadPool**:该线程池中没有核心线程，非核心线程的数量为Integer.max_value，就是无限大，当有需要时创建线程来执行任务，没有需要时回收线程，适用于耗时少，任务量大的情况。SynchronousQueue

**FixedThreadPool**:定长的线程池，有核心线程，核心线程的即为最大的线程数量，没有非核心线程LinkedBlockingQueue

**ScheduledThreadPool**:创建一个定长线程池，支持定时及周期性任务执行。

**SingleThreadPool**:只有一条线程来执行任务，使用了LinkedBlockingQueue（容量很大），所以，不会创建非核心线程。所有任务按照先来先执行的顺序执行LinkedBlockingQueue

**何为阻塞队列？**

http://concurrent.redspider.group/article/03/13.html

生产者-消费者模式   生产者一直生产资源，消费者一直消费资源，资源存储在一个缓冲池中，生产者将生产的资源存进缓冲池中，消费者从缓冲池中拿到资源进行消费。

我们自己coding实现这个模式的时候，因为需要让多个线程操作共享变量（即资源），所以很容易引发线程安全问题，造成重复消费和死锁。另外，当缓冲池空了，我们需要阻塞消费者，唤醒生产者；当缓冲池满了，我们需要阻塞生产者，唤醒消费者，这些个等待-唤醒逻辑都需要自己实现。

阻塞队列(BlockingQueue)，你只管往里面存、取就行，而不用担心多线程环境下存、取共享变量的线程安全问题。

阻塞队列的原理很简单，利用了Lock锁的多条件（Condition）阻塞控制

put和take操作都需要先获取锁，没有获取到锁的线程会被挡在第一道大门之外自旋拿锁，直到获取到锁。

就算拿到锁了之后，也不一定会顺利进行put/take操作，需要判断队列是否可用（是否满/空），如果不可用，则会被阻塞，并释放锁。

**有哪几种工作队列**

1、LinkedBlockingQueue

一个基于链表结构的阻塞队列，此队列按FIFO （先进先出） 排序元素，吞吐量通常要高于ArrayBlockingQueue。静态工厂方法Executors.newFixedThreadPool()和Executors.newSingleThreadExecutor使用了这个队列。

2、SynchronousQueue

一个不存储元素的阻塞队列。每个插入操作必须等到另一个线程调用移除操作，否则插入操作一直处于阻塞状态，吞吐量通常要高于LinkedBlockingQueue，静态工厂方法Executors.newCachedThreadPool使用了这个队列。

**线程池原理**

从数据结构的角度来看，线程池主要使用了阻塞队列（BlockingQueue）

1、如果正在运行的线程数 < coreSize，马上创建核心线程执行该task，不排队等待；
2、如果正在运行的线程数 >= coreSize，把该task放入阻塞队列；
3、如果队列已满 && 正在运行的线程数 < maximumPoolSize，创建新的非核心线程执行该task；
4、如果队列已满 && 正在运行的线程数 >= maximumPoolSize，线程池调用handler的reject方法拒绝本次提交。

理解记忆：1-2-3-4对应（核心线程->阻塞队列->非核心线程->handler拒绝提交）。

## 5.反射

### 5.1.什么是反射

JAVA反射机制是在运行状态中

对于任意一个类，都能够知道这个类的所有属性和方法；

对于任意一个对象，都能够调用它的任意方法和属性；

这种动态获取信息以及动态调用对象方法的功能称为java语言的反射机制。

###  5.2.反射机制的相关类

| 类名          | 用途                                             |
| ------------- | ------------------------------------------------ |
| Class类       | 代表类的实体，在运行的Java应用程序中表示类和接口 |
| Field类       | 代表类的成员变量（成员变量也称为类的属性）       |
| Constructor类 | 代表类的构造方法                                 |
| Method类      | 代表类的方法                                     |

### 5.3.反射中如何获取Class类的实例
（1）通过.class

   Class class1 = Person.class;

（2）通过创建实例对象来获取类对象

 Person person =new Person();

 Class class2 = person.getClass();

（3） 通过包名，调用class的forName方法

Class class3 =  Class.forName("day07.Person");

###  5.4.如何获取一个类的属性对象 & 构造器对象 & 方法对象 。

**通过class对象创建一个实例对象**

Cls.newInstance();


**通过class对象获得一个属性对象**

 Field c=cls.getFields()：

 获得某个类的所有的公共（public）的字段，包括父类中的字段。

Field c=cls.getDeclaredFields()：

获得某个类的所有声明的字段，即包括public、private和proteced，但是不包括父类的声明字段

**获取构造器对象**

Clazz.getConstructor();

**通过class对象获得一个方法对象**

Cls.getMethod(“方法名”,class……parameaType);（只能获取公共的）

Cls.getDeclareMethod(“方法名”);（获取任意修饰的方法，不能执行私有）

###  5.5.Class.getField和getDeclaredField的区别，getDeclaredMethod和getMethod的区别

getField

获取一个类的 ==public成员变量，包括基类== 。

getDeclaredField

获取一个类的 ==所有成员变量，不包括基类== 。

 getDeclaredMethod*()

获取的是类自身声明的所有方法，包含public、protected和private方法。

getMethod*()

获取的是类的所有共有方法，这就包括自身的所有public方法，和从基类继承的、从接口实现的所有public方法 现的所有public方法。

###  5.6.反射机制的优缺点

优点：

1）能够运行时动态获取类的实例，提高灵活性；

缺点：

1）使用反射性能较低，需要解析字节码，将内存中的对象进行解析。

2）相对不安全，破坏了封装性（因为通过反射可以获得私有方法和属性）

## 6.静态代理和动态代理

https://segmentfault.com/a/1190000011291179

https://segmentfault.com/a/1190000022699975

示例：

**目标接口类**

```java
public interface UserManager {
    void addUser(String username, String password);
    void delUser(String username);
}
```
**接口实现类**

```java
/**
 * 动态代理：
 *      1. 特点：字节码随用随创建，随用随加载
 *      2. 作用：不修改源码的基础上对方法增强
 *      3. 分类：
 *              1）基于接口的动态代理
 *                      1. 基于接口的动态代理：
 *                              1）涉及的类：Proxy
 *                              2）提供者：JDK官方
 *                              3）如何创建代理对象：
 *                                      使用Proxy类中的newProxyInstance方法
 *                              4）创建代理对象的要求
 *                                      被代理类最少实现一个接口，如果没有则不能使用
 *                              5）newProxyInstance方法的参数：
 *                                      ClassLoader：类加载器，它是用于加载代理对象字节码的。和被代理对象使用相同的类加载器。固定写法。
 *                                      Class[]：字节码数组，它是用于让代理对象和被代理对象有相同方法。固定写法。
 *                                      InvocationHandler：用于提供增强的代码，它是让我们写如何代理。我们一般都是些一个该接口的实现类，通常情况下都是匿名内部类
 *              2）基于子类的动态代理
 */
public class JDKProxy implements InvocationHandler {
    // 用于指向被代理对象
    private Object targetObject;
    public Object newProxy(Object targetObject) {
        // 将被代理对象传入进行代理
        this.targetObject = targetObject;
        // 返回代理对象
        return Proxy.newProxyInstance(this.targetObject.getClass().getClassLoader(),this.targetObject.getClass().getInterfaces(),this);
    }

    /**
     * 被代理对象的任何方法执行时，都会被invoke方法替换，即：代理对象执行被代理对象中的任何方法时，实际上执行的时当前的invoke方法
     * @param proxy（代理对象的引用）
     * @param method（当前执行的方法）
     * @param args（当前执行方法所需的参数）
     * @return（和被代理对象方法有相同的返回值）
     * @throws Throwable
     */
    @Override
    public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
        // 在原来的方法上增加了日志打印功能，增强代码
        printLog();
        Object ret = null;
        // 调用invoke方法（即执行了代理对象调用被调用对象中的某个方法）
        ret = method.invoke(targetObject, args);
        return ret;
    }

    /**
     * 模拟日志打印
     */
    private void printLog() {
        System.out.println("日志打印：printLog()");
    }
}
```

**测试类**

```java
public class TestJDKProxy {
    public static void main(String[] args) {
        UserManager userManager = new UserManagerImpl();
        JDKProxy jdkProxy = new JDKProxy();
        UserManager userManagerProxy = (UserManager)jdkProxy.newProxy(userManager);
        System.out.println("--------------------没有使用增强过的方法--------------------");
        userManager.addUser("root","root");
        userManager.delUser("root");
        System.out.println("--------------------使用代理对象增强过的方法--------------------");
        userManagerProxy.addUser("scott","tiger");
        userManagerProxy.delUser("scott");
    }
}
```

**测试结果**

```
--------------------没有使用增强过的方法--------------------
调用了UserManagerImpl.addUser()方法！
调用了UserManagerImpl.delUser()方法！
--------------------使用代理对象增强过的方法--------------------
日志打印：printLog()
调用了UserManagerImpl.addUser()方法！
日志打印：printLog()
调用了UserManagerImpl.delUser()方法！
```

总结：

1. 静态代理实现较简单，只要代理对象对目标对象进行包装，即可实现增强功能，但静态代理只能为一个目标对象服务，如果目标对象过多，则会产生很多代理类。
2. JDK动态代理需要目标对象实现业务接口，代理类只需实现InvocationHandler接口。
3. 动态代理生成的类为 lass com.sun.proxy.\$Proxy4，cglib代理生成的类为class com.cglib.UserDao\$\$EnhancerByCGLIB\$\$552188b6。
4. 静态代理在编译时产生class字节码文件，可以直接使用，效率高。
5. 动态代理必须实现InvocationHandler接口，通过反射代理方法，比较消耗系统性能，但可以减少代理类的数量，使用更灵活。
6. cglib代理无需实现接口，通过生成类字节码实现代理，比反射稍快，不存在性能问题，但cglib会继承目标对象，需要重写方法，所以目标对象不能为final类。（Android不常用）

- 静态代理使用场景：四大组件同AIDL与AMS进行跨进程通信
- 动态代理使用场景：Retrofit使用了动态代理极大地提升了扩展性和可维护性。

## 7.设计模式

### 7.1.单例模式

​	https://zhuanlan.zhihu.com/p/43883488

**1.懒汉模式：**

```java
public class Singleton{
	private static Singleton instance=null;
	private Singleton(){}
	public synchronized static Singleton getInstance(){
		if(instance==null)
			instance=new Singleton();
		return instance;
	}
}
```

上面的代码中，synchronized是为了保证多线程安全的。之所以叫懒汉模式，是因为该方案只有在调用getInstance()方法的时候才会创建单例对象，显得有点儿懒惰。

**面试点：此方案可以考察应聘者对synchronized关键字的理解**

**2. 饿汉模式**

```java
public class Singleton{
	private static Singleton instance=new Singleton();
	private Singleton(){}
	public static Singleton getInstance(){
		return instance;
	}
}
```

和懒汉模式相比，饿汉模式是在装载Singleton类的时候便初始化对象。提前做好准备，所以叫做饿汉。读者一定注意到饿汉模式中getInstance()方法没有使用synchronized关键字。的确，饿汉模式的线程安全不是依靠synchronized来保证的，而是依靠JVM。对，就是Java Virtual Machine。

Java文件在编译的时候，对于包含静态初始化语句或者静态变量初始化语句的类，其生成的.class文件中会包含一个*<clinit>*方法。*<clinit>*方法专门负责执行“类变量初始化语句”和“静态初始化语句”，而且*<clinit>*方法能够保证初始化类变量这一过程的线程安全。为此，我们说，*<clinit>*机制是饿汉模式能够实现线程安全的基础。

**面试点：此方案可以考察应聘者对JVM中类加载机制和对象加载机制的理解。**

**3. 枚举模式（推荐）**

枚举本身就是一种对单例模式友好的结构，也是我本人推崇的实现单例的方式，简单高效。

```java
public enum Singleton{
	INSTANCE;
	public static Singleton getInstance(){
		return INSTANCE;
	}
}
```

**面试点：此方案可以考察应聘者对枚举的理解和掌握，包括枚举的初始化、构造函数、values方法等。**

**4. 内部静态类（推荐）**

```java
public class Singleton{
	private static class SingletonHolder{
		private static final Singleton INSTANCE=new Singleton(); 
	}
	private Singleton(){}
	public static Singleton getInstance(){
		return SingletonHolder.INSTANCE;
	}
}
```

在内部静态类方案中，单例对象的加载方式和饿汉模式一样，也是利用类加载时的*<clinit>*机制来保证线程安全性。

**面试点：此方案可以考察应聘者对Java四种嵌套类的理解和掌握。**

对synchronized关键字“玩的活”（理解的透彻）的小伙伴一定能看出来，下面的代码是懒汉模式的另一种等价写法（请自行对比）：

```java
public class Singleton {
	private static Singleton instance=null;
	private Singleton(){}
	public static Singleton getInstance(){
		synchronized (Singleton.class) {
			if(instance==null)
				instance=new Singleton();				
		}
		return instance;
	}	
}
```

**5. 双重校验锁（DCL）**

DCL的全称是Double Check Lock。DCL实现单例模式在volatile关键字出现之前一直是被错误使用的，直到volatile关键字的出现。下面是DCL正确的代码。

```java
public class Singleton{
	private volatile static Singleton instance=null;//一定要加volatile
	private Singleton(){}
	public static Singleton getInstance(){
		if(instance==null){
		  synchronized (Singleton.class) {
				if(instance==null)
					instance=new Singleton();				
			}
		}
		return instance;
	}
}
```

双重检验锁非常容易写错，请看下面的错误代码：

```java
//错误的代码  
public class Singleton {  
    private static Singleton instance=null;  
    private Singleton(){}  
    public static Singleton getInstance(){  
        if(instance==null){  
            synchronized (Singleton.class) {  
                if(instance==null)  
                    instance=new Singleton();            
            }             
        }  
        return instance;  
    }  
}  
```

不仔细的同学一定找不出其中的问题！提醒一下，一定要用volatile关键字修饰单例对象。DCL的线程安全性基于synchronized、以及volatile对于可见性的保证。

**面试点：此方案可以考察应聘者对volatile关键字的理解和掌握。**

kotlin版本是这样

```kotlin
class SingletonDemo private constructor() {//这里可以根据实际需求发生改变
  
    companion object {
        @Volatile private var instance: SingletonDemo? = null
        fun get() = instance ?: synchronized(this) {instance ?: SingletonDemo().also { instance = it }}
    }
}
```

### 7.2.工厂模式

https://zhuanlan.zhihu.com/p/356221658

https://github.com/Omooo/Android-Notes/blob/master/blogs/DesignMode/%E5%B7%A5%E5%8E%82%E6%A8%A1%E5%BC%8F.md

工厂模式，也是创建型设计模式之一，它提供了一种创建对象的最佳方式。

在任何需要生成复杂对象的地方，都可以使用工厂模式。复杂对象适用工厂模式，用 new 就可以完成创建的对象无需使用工厂模式。

### 7.3.代理模式

静态代理使用场景：四大组件同AIDL与AMS进行跨进程通信

动态代理使用场景：Retrofit使用了动态代理极大地提升了扩展性和可维护性。

### 7.4.装饰者模式

https://blog.51cto.com/u_11440114/3005597

一般有两种方式可以给一个类或对象增加行为：

继承
通过继承一个现有类，可以使得子类在拥有自身方法同时还拥有父类方法。但这种方法是静态的，用户无法控制增加行为的方式和时机。
关联
将一个类的对象嵌入另一个对象中，由另一个对象决定是否调用嵌入对象的行为以便扩展自己的行为，这个嵌入的对象就叫做装饰器(Decorator)

示例：

```
// 窗口 接口
public interface Window {
 	// 绘制窗口
	public void draw();
	 // 返回窗口的描述
	public String getDescription();
}


// 无滚动条功能的简单窗口实现
public class SimpleWindow implements Window {
	public void draw() {
		// 绘制窗口
	}

	public String getDescription() {
		return "simple window";
	}
}
```

以下类包含所有Window类的decorator，以及修饰类本身。

```
//  抽象装饰类 注意实现Window接口
public abstract class WindowDecorator implements Window {
	// 被装饰的Window
    protected Window decoratedWindow;

    public WindowDecorator (Window decoratedWindow) {
        this.decoratedWindow = decoratedWindow;
    }
    
    @Override
    public void draw() {
        decoratedWindow.draw();
    }

    @Override
    public String getDescription() {
        return decoratedWindow.getDescription();
    }
}


// 第一个具体装饰器 添加垂直滚动条功能
public class VerticalScrollBar extends WindowDecorator {
	public VerticalScrollBar(Window windowToBeDecorated) {
		super(windowToBeDecorated);
	}

	@Override
	public void draw() {
		super.draw();
		drawVerticalScrollBar();
	}

	private void drawVerticalScrollBar() {
		// Draw the vertical scrollbar
	}

	@Override
	public String getDescription() {
		return super.getDescription() + ", including vertical scrollbars";
	}
}


// 第二个具体装饰器 添加水平滚动条功能
public class HorizontalScrollBar extends WindowDecorator {
	public HorizontalScrollBar (Window windowToBeDecorated) {
		super(windowToBeDecorated);
	}

	@Override
	public void draw() {
		super.draw();
		drawHorizontalScrollBar();
	}

	private void drawHorizontalScrollBar() {
		// Draw the horizontal scrollbar
	}

	@Override
	public String getDescription() {
		return super.getDescription() + ", including horizontal scrollbars";
	}
}
```

### 7.5.适配器模式

GridView、ListView的Adapter

### 7.6.建造者模式

AlertDialog.Builder

OkHttpClient.Builder参数构造

### 7.7.观察者模式

ListView的adapter.notifyDataSetChanged

面试：回调函数和观察者模式的区别

观察者模式定义了一种一对多的依赖关系，让多个观察者对象同时监听某一个主题对象。观察者模式完美的将观察者和被观察的对象分离开，一个对象的状态发生变化时，所有依赖于它的对象都得到通知并自动刷新。
回调函数其实也算是一种观察者模式的实现方式，回调函数实现的观察者和被观察者往往是一对一的依赖关系。所以最明显的区别是**观察者模式是一种设计思路，而回调函数式一种具体的实现方式；另一明显区别是一对多还是多对多的依赖关系方面。**

### 7.8.责任链模式

Okhttp的拦截器

View的事件分发

## 8.注解

https://juejin.cn/post/6844903511809851400
1.注解的分类

Java的注解分为元注解和标准注解。

**标准注解**
SDO

**元注解**

**@Documented**

是一个标记注解，没有成员变量。
会被JavaDoc 工具提取成文档

**@Target**(METHOD,TYPE类,FIELD用于成员变量,PACKAGE用于包)
表示被描述的注解用于什么地方

**@Retention**

描述注解的生命周期

SOURCE：在源文件中有效（即源文件保留）
CLASS：在 class 文件中有效（即 class 保留）
RUNTIME：在运行时有效（即运行时保留）

这3个生命周期分别对应于：Java源文件(.java文件) ---> .class文件 ---> 内存中的字节码。

1、RetentionPolicy.SOURCE：注解只保留在源文件，当Java文件编译成class文件的时候，注解被遗弃；
2、RetentionPolicy.CLASS：注解被保留到class文件，但jvm加载class文件时候被遗弃，这是默认的生命周期；
3、RetentionPolicy.RUNTIME：注解不仅被保存到class文件中，jvm加载class文件之后，仍然存在；

@Documented – 注解是否将包含在JavaDoc中
@Retention – 什么时候使用该注解
@Target – 注解用于什么地方
@Inherited – 是否允许子类继承该注解

**注解的底层实现原理**

注解的原理：

注解本质是一个继承了Annotation 的特殊接口，其具体实现类是Java 运行时生成的动态代理类。

而我们通过反射获取注解时，返回的是Java 运行时生成的动态代理对象$Proxy1。

通过代理对象调用自定义注解（接口）的方法，会最终调用AnnotationInvocationHandler 的invoke方法。

## 9.String,Stringbuffer,StringBuilder的区别

https://juejin.cn/post/6993304644634181646

![字符串拼接原理](https://raw.githubusercontent.com/treech/PicRemote/master/common/%E5%AD%97%E7%AC%A6%E4%B8%B2%E6%8B%BC%E6%8E%A5%E5%8E%9F%E7%90%86.webp)

上图是执行下方代码的一个过程：

```java
String string ="abc";
string+="def";
```

1、首先执行String string ="abc"在堆内存中开辟一块空间存储abc；

2、执行string+="def"的时候需要先在堆内存中开辟一块空间存储def，然后再在堆内存中开辟一块空间存储最终的abcdef，然后将string的引用指向该堆内存空间。可以发现执行这样的短短两行代码需要在堆内存中开辟三次内存空间，造成了对内存空间资源的极大浪费。

但是在编程的过程中需要经常对字符串进行操作，所以java就引入了两个可以对此种变化字符串进行处理的类：StringBuffer类和StringBuild类。

**具体区别：**

String是final修饰符修饰的字符数组，所以是不可变的，如果操作的是少量的数据，则可以使用String；

StringBuilder和StringBuffer是可变的字符串数组；

StringBuilder是线程不安全的，因为Stringbuilder继承了父类abstractStringBuilder的append方法，该方法中有一个count+=len的操作不是原子操作，所以在多线程中采用StringBuilder会丢失数据的准确性并且会抛ArrayIndexOutOfBoundsException的异常。

StringBuffer是线程安全的因为他的append方法被synchronized关键字修饰了，所以它能够保证线程同步和数据的准确性。

因为StringBuffer是被synchronized修饰的，所以在单线程的情况下StringBuilder的执行效率是要比StringBuffer高的。所以一般在单线程下执行大量的数据使用StringBuilder，多线程的情况下则使用StringBuffer。

## 10.==与equals区别

https://segmentfault.com/a/1190000039132885

**关于==**
基本类型：比较的是值是否相同；
引用类型：比较的是引用是否相同；

**关于equals**
equals 本质上就是 ==，只不过 String 和 Integer 等重写了 equals 方法，把它变成了值比较。

**关于Integer/Long类型的自动拆装箱**

1 直接声明的不管是Long 还是long  -128 -127 之间使用 == 和 equlas 都是true 因为 Long包对常用的做了缓存。如果在这个区间直接从cache 中取。所以 == 地址值也是一样的 为true。

![image-20220910072819019](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20220910072819019.png)

![image-20220910072724553](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20220910072724553.png)

2 new 出来的 必须使用equals .虽然做了-128 -127 做了缓存，但是new出来的是新分配的内存，地址值不一样 使用==  数值即使一样也为false。

3 使用 == 不管是直接声明的，还是new出来的 ，只要一边有基本数据类型 都可以正常对比，会自动拆箱。

示例：
```java
// 直接声明的Long 验证
Long a = 5L; Long b = 5L;
System.out.println("Long与Long 5L 使用 == 结果: " + (a == b)); //true 因为Long 对-128-127 的对象进行了缓存，所以为true
Long c = 300L; Long d = 300L;
System.out.println("Long与Long 300L 使用 == 结果: " + (c == d)); // false
System.out.println("Long与Long 300L 使用 equals 结果:" + (c.equals(d)));// true
// new 出来的Long 验证结果
Long newA = new Long(5L);
Long newB = new Long(5L);
System.out.println("Long与Long new 5L 使用 == 结果: " + (newA == (newB)));// false 虽然Long 对127 做了缓存，但是自己new的是新对象 所以==  地址值不一样结果是fasle
System.out.println("Long与Long new 5L 使用 equals 结果: " + (newA.equals(newB)));// true
// 如果和int 或long  只要== 中包含基本数据类型，就会自动解包,（不管是直接声明的Long  还是new 的Long）
Long e = 300L; int f = 300;
Long g = 300L; long h = 300L;
Long i = new Long(300);
System.out.println("Long与int 300 == 结果" + (e == f));//true 会自动转换
System.out.println("Long与long 300L == 结果" + (g == h));//true 会自动转换
System.out.println("Long与int 300 equals 结果" + (e == f));//true
System.out.println("Long与long 300L equals 结果" + (g == h));//true

System.out.println(" new Long与int 300 == 结果" + (i == f));//true 会自动转换
System.out.println("new Long与long 300L == 结果" + (i == h));//true 会自动转换
```

# Kotlin

## 1.Kotlin优缺点

**优点：**

1、null安全

2、代码更简洁

使用`Lambda`表达式，大量节省模板代码，特别是重复多余的findViewById。

3、函数式支持
使用高阶函数，可以将其作为返回值或参数值使用，特别方便。
什么是高阶函数呢？就是以函数作为参数，又以函数作为返回值就是高阶函数，而每个函数又对应着Lambda表达式。
常见的高阶函数map()、forEach()、flatMap()、reduce()、fold()、filter()、takeWhile()、let()、apply()

4、扩展函数

Kotlin同C#类似，能够扩展一个类的新功能而无需继承该类或使用像装饰者这样的任何类型的设计模式。Kotlin支持扩展函数和扩展属性。
1） 表达式可以直接作为函数返回值
2）扩展函数： fun 类名.扩展方法名(参数列表){方法体} 或者 fun 类名.扩展方法名(参数列表) = 表达式

```
fun MyClass.add(a:Int,b:Int) = a+b
```

3）扩展属性：var 类名.扩展属性 / 对应其他方法

```
var MyClass.d: String
    get() = "sdasda"
    set(value){d = value}//MyClass的扩展成员变量d
```

5、Kotlin中没有静态成员

对应的解决方案是伴生类,调用方式和Java的静态成员调用方式一样

6、协程

协程是Kotlin、go等语言中特有的概念，在Java中不存在协程的概念

协程的本质是在同一线程的运行中，并发运行不同的任务代码，不同的任务由kotlin自身来决定运行谁，该方案减少了多线程的任务切换时间消耗。

一个线程中有多个协程，协程和协程之间可以嵌套。其特性为：

可控性：协程能做到可控，其启动和停止都是代码控制
轻量级：协程非常小，占用资源比线程还少

7、Kotlin支持多平台和Jetpack Compose UI，而Java不支持

```
class Test {
    companion object{
        val Name="Name"
    }
}
```

**缺点：**

1、Kotlin是一种编程语言，它需要额外的运行时间，其标准库增强了.apk的大小

2、相对来说，Kotlin的可读性比Java差

## 2.Kotlin 扩展函数是怎么理解的

kotlin中的扩展函数，实际上就是通过给类添加public static final函数的做法来实现，这样做可以减少utils类的使用。

Java对函数进行扩展时通过封装utils类

# 日志

## 1.Java层Crash、Native层Crash、ANR三个异常信息捕获

https://mp.weixin.qq.com/s/g-WzYF3wWAljok1XjPoo7w

https://toutiao.io/posts/euc9um/preview

**1、Java 层的Crash捕获**

1. 创建一个自定义UncaughtExceptionHandler类

    ```
    public class CrashHandler implements Thread.UncaughtExceptionHandler {
        @Override
        public void uncaughtException(Thread thread, Throwable ex) {
            //回调函数，处理异常
            //在这里将崩溃日志读取出来，然后保存到SD卡，或者直接上传到日志服务器
            //如果我们也想继续调用系统的默认处理，可以先把系统UncaughtExceptionHandler存下来，然后在这里调用。
        }
    }
    ```

2. 设置全局监控

    ```
    CrashHandler crashHandler = new CrashHandler();
    Thread.setDefaultUncaughtExceptionHandler(crashHandler);
    ```

**2、Native层的Crash捕获**

https://www.dalvik.work/2021/06/22/xcrash/

捕获 Native Crash 靠的是信号处理器（`sigaction`），比如说访问非法地址时，APP 进程会收到 `SIGSEGV`，应用进程可以通过自定义信号的处理过程来实现 native crash 的收集堆栈信息。

- 崩溃过程：native crash 时操作系统会向进程发送信号，崩溃信息会写入到 data/tombstones 下，并在 logcat 输出崩溃日志
- 定位：so 库剥离调试信息的话，只有相对位置没有具体行号，可以使用 NDK 提供的 addr2line 或 ndk-stack 来定位
- addr2line：根据有调试信息的 so 和相对位置定位实际的代码处
- ndk-stack：可以分析 tombstone 文件，得到实际的代码调用栈


需要更全面更深入的理解请查看[深入探索Android稳定性优化](

**3、ANR捕获**

给主线程注册 `SIGQUIT` 的信号处理器 `xc_trace_handler`，当主线程收到 SIGQUIT 信号时，恢复 `xc_trace_dumper`（dumper 线程），也就是说发生 ANR 时主线程是被 SIGQUIT 中断的而不是 SIGKILL。

## 2.mmap & native 日志优化

# 项目架构

目前的主流框架试：组件化+MVVM

路由：Arouter

组件的Application动态加载：自定义asm，ApplicationLike，参考：https://github.com/hufeiyang/Android-AppLifecycleMgr

UI框架：ViewModel+LiveData

网络请求：OkHttp+Retrofit

数据库：Room

sp替代框架：MMKV

图片加载：Glide

# 隐私合规问题

https://github.com/allenymt/PrivacySentry

android隐私合规检测，不仅仅是是检测，碰到第三方SDK不好解决的或者修复周期很长的，我们等不了那么长时间，可以通过这个库去动态拦截
例如游客模式，这种通过xposed\epic只能做检测，毕竟xposed\epic不能带到线上，但是asm可以

# 计算机网络

## 1、Http与Https的区别

**Http** (HTTP-Hypertext transfer protocol) 是一个简单的请求-响应协议，它通常运行在[TCP](https://link.zhihu.com/?target=https%3A//baike.baidu.com/item/TCP/33012%3Ffr%3Daladdin)之上。它指定了客户端可能发送给服务器什么样的消息以及得到什么样的响应。请求和响应消息的头以ASCII码形式给出；而消息内容则具有一个类似MIME的格式。这个简单模型是早期Web成功的有功之臣，因为它使开发和部署非常地直截了当。

**Https**（全称：Hyper Text Transfer Protocol over SecureSocket Layer），是以安全为目标的 HTTP 通道，在HTTP的基础上通过传输加密和身份认证保证了传输过程的安全性 。HTTPS 在HTTP 的基础下加入[SSL](https://link.zhihu.com/?target=https%3A//baike.baidu.com/item/SSL/320778) 层，HTTPS 的安全基础是 SSL，因此加密的详细内容就需要 SSL。 HTTPS 存在不同于 HTTP 的默认端口及一个加密/身份验证层（在 HTTP与 TCP 之间）。这个系统提供了身份验证与加密通讯方法。它被广泛用于万维网上安全敏感的通讯，例如交易支付等方面 。

**区别**：

1、https协议需要到ca申请证书，一般免费证书较少，因而需要一定费用。 2、http是超文本传输协议，信息是明文传输，https则是具有安全性的ssl加密传输协议。 3、http和https使用的是完全不同的连接方式，用的端口也不一样，前者是80，后者是443。 4、http的连接很简单，是无状态的；HTTPS协议是由SSL+HTTP协议构建的可进行加密传输、身份认证的网络协议，比http协议安全。

## 2、Http与Tcp的区别

https://cloud.tencent.com/developer/article/1813252

TCP 协议对应于传输层，而 HTTP 协议对应于应用层，从本质上来说，二者没有可比性。Http 协议是建立在 TCP 协议基础之上的。

| TCP                                          | HTTP                                  |
| -------------------------------------------- | ------------------------------------- |
| 传输层协议，定义的是数据传输和连接方式的规范 | 应用层协议，定义的是传输内容的规范    |
| 需要经过三次握手：请求、确认，建立连接       | TCP建立连接后，需要HTTP进行传输数据了 |

TCP的三次握手（还有四次挥手）：
![TCP三次握手](https://raw.githubusercontent.com/treech/PicRemote/master/common/TCP%E4%B8%89%E6%AC%A1%E6%8F%A1%E6%89%8B.png)

HTTP协议中的数据是利用TCP协议进行传输的，所以支持HTTP，一定支持TCP；
HTTP常用的请求方法有四种，put，delete，post 和 get ，增删改查，区别如下：
post和get最本质上没有区别，都是属于传输层的HTTP的请求方法；

| post                                                         | get                         |
| ------------------------------------------------------------ | --------------------------- |
| 浏览器回退或者刷新按钮，数据会被重新提交                     | 无害                        |
| 支持多种编码                                                 | 只支持url编码               |
| 传参长度有限                                                 | 传参长度无限                |
| 更安全                                                       | 参数直接暴露在URL上，不安全 |
| 参数在Request body                                           | 参数通过URL传递             |
| 某些浏览器header 和body分开发送，产生两个数据包（不是一定的，依据浏览器，例如：Firefox） | 产生一个数据包              |

## 3、Tcp与Udp的区别

https://juejin.cn/post/6844904150363275278

**1. 基于连接vs无连接**

- TCP是面向连接的协议。
- UDP是无连接的协议。UDP更加适合消息的多播发布，从单个点向多个点传输消息。

**2.可靠性**

- TCP提供交付保证，传输过程中丢失，将会重发。
- UDP是不可靠的，不提供任何交付保证。（网游和视频的丢包情况）

**3. 有序性**

- TCP保证了消息的有序性，即使到达客户端顺序不同，TCP也会排序。
- UDP不提供有序性保证。

**4. 数据边界**

- TCP不保存数据边界。
    - 虽然TCP也将在收集所有字节之后生成一个完整的消息，但是这些信息在传给传输给接受端之前将储存在TCP缓冲区，以确保更好的使用网络带宽。
- UDP保证。
    - 在UDP中，数据包单独发送的，只有当他们到达时，才会再次集成。包有明确的界限来哪些包已经收到，这意味着在消息发送后，在接收器接口将会有一个读操作，来生成一个完整的消息。

**5. 速度**

- TCP速度慢
- UDP速度快。应用在在线视频媒体，电视广播和多人在线游戏。

**6. 发送消耗**

- TCP是重量级。
- UDP是轻量级。
    - 因为UDP传输的信息中不承担任何间接创造连接，保证交货或秩序的的信息。
    - 这也反映在用于报头大小。

**7. 报头大小**

- TCP头大。
    - 一个TCP数据包报头的大小是20字节。
    - TCP报头中包含序列号，ACK号，数据偏移量，保留，控制位，窗口，紧急指针，可选项，填充项，校验位，源端口和目的端口。
- UDP头小。
    - UDP数据报报头是8个字节。
    - 而UDP报头只包含长度，源端口号，目的端口，和校验和。

**8. 拥塞或流控制**

- TCP有流量控制。
    - 在任何用户数据可以被发送之前，TCP需要三数据包来设置一个套接字连接。TCP处理的可靠性和拥塞控制。
- UDP不能进行流量控制。

**9. 应用**

- 由于TCP提供可靠交付和有序性的保证，它是最适合需要高可靠并且对传输时间要求不高的应用。
- UDP是更适合的应用程序需要快速，高效的传输的应用，如游戏。
- UDP是无状态的性质，在服务器端需要对大量客户端产生的少量请求进行应答的应用中是非常有用的。
- 在实践中，TCP被用于金融领域，如FIX协议是一种基于TCP的协议，而UDP是大量使用在游戏和娱乐场所。

**10.上层使用的协议**

- 基于TCP协议的：Telnet，FTP以及SMTP协议。
- 基于UDP协议的：DHCP、DNS、SNMP、TFTP、BOOTP。

## 4、Http常用状态码的解释

服务器返回的 **响应报文** 中第一行为状态行，包含了状态码以及原因短语，用来告知客户端请求的结果。  

| 状态码 | 类别                             | 原因短语                   |
| ------ | -------------------------------- | -------------------------- |
| 1XX    | Informational（信息性状态码）    | 接收的请求正在处理         |
| 2XX    | Success（成功状态码）            | 请求正常处理完毕           |
| 3XX    | Redirection（重定向状态码）      | 需要进行附加操作以完成请求 |
| 4XX    | Client Error（客户端错误状态码） | 服务器无法处理请求         |
| 5XX    | Server Error（服务器错误状态码） | 服务器处理请求出错         |

**1XX 信息**
100 Continue ：表明到目前为止都很正常，客户端可以继续发送请求或者忽略这个响应。
**2XX 成功**
200 OK
204 No Content ：请求已经成功处理，但是返回的响应报文不包含实体的主体部分。一般在只需要从客户端
往服务器发送信息，而不需要返回数据时使用。
206 Partial Content ：表示客户端进行了范围请求，响应报文包含由 Content-Range 指定范围的实体内
容。  

**3XX 重定向**
301 Moved Permanently ：永久性重定向
302 Found ：临时性重定向
303 See Other ：和 302 有着相同的功能，但是 303 明确要求客户端应该采用 GET 方法获取资源。
注：虽然 HTTP 协议规定 301、302 状态下重定向时不允许把 POST 方法改成 GET 方法，但是大多数浏览器
都会在 301、302 和 303 状态下的重定向把 POST 方法改成 GET 方法。
304 Not Modified ：如果请求报文首部包含一些条件，例如：If-Match，If-Modified-Since，If-NoneMatch，If-Range，If-Unmodified-Since，如果不满足条件，则服务器会返回 304 状态码。
307 Temporary Redirect ：临时重定向，与 302 的含义类似，但是 307 要求浏览器不会把重定向请求的
POST 方法改成 GET 方法。
**4XX 客户端错误**
400 Bad Request ：请求报文中存在语法错误。
401 Unauthorized ：该状态码表示发送的请求需要有认证信息（BASIC 认证、DIGEST 认证）。如果之前已
进行过一次请求，则表示用户认证失败。
403 Forbidden ：请求被拒绝。
404 Not Found
**5XX 服务器错误**
500 Internal Server Error ：服务器正在执行请求时发生错误。
503 Service Unavailable ：服务器暂时处于超负载或正在进行停机维护，现在无法处理请求。  

# 数据结构和算法

## 1.数据结构

### 1.1.什么是数据结构？

![数据结构的理解](https://raw.githubusercontent.com/treech/PicRemote/master/common/%E6%95%B0%E6%8D%AE%E7%BB%93%E6%9E%84%E7%9A%84%E7%90%86%E8%A7%A3.png)

**一、是什么**

数据结构是计算机存储、组织数据的方式，是指相互之间存在一种或多种特定关系的数据元素的集合

前面讲到，一个程序 = 算法 + 数据结构，数据结构是实现算法的基础，选择合适的数据结构可以带来更高的运行或者存储效率

数据元素相互之间的关系称为结构，根据数据元素之间关系的不同特性，通常有如下四类基本的结构：

- 集合结构：该结构的数据元素间的关系是“属于同一个集合”
- 线性结构：该结构的数据元素之间存在着一对一的关系
- 树型结构：该结构的数据元素之间存在着一对多的关系
- 图形结构：该结构的数据元素之间存在着多对多的关系，也称网状结构

由于数据结构种类太多，逻辑结构可以再分成为：

- 线性结构：有序数据元素的集合，其中数据元素之间的关系是一对一的关系，除了第一个和最后一个数据元素之外，其它数据元素都是首尾相接的
- 非线性结构：各个数据元素不再保持在一个线性序列中，每个数据元素可能与零个或者多个其他数据元素发生关联

![数据的逻辑结构](https://raw.githubusercontent.com/treech/PicRemote/master/common/%E6%95%B0%E6%8D%AE%E7%9A%84%E9%80%BB%E8%BE%91%E7%BB%93%E6%9E%84.png)

**二、有哪些**

常见的数据结构有如下：

- 数组
- 栈
- 队列
- 链表
- 树
- 图
- 堆
- 散列表

**数组**

在程序设计中，为了处理方便， 一般情况把具有相同类型的若干变量按有序的形式组织起来，这些按序排列的同类数据元素的集合称为数组

**栈**

一种特殊的线性表，只能在某一端插入和删除的特殊线性表，按照先进后出的特性存储数据

先进入的数据被压入栈底，最后的数据在栈顶，需要读数据的时候从栈顶开始弹出数据

**队列**

跟栈基本一致，也是一种特殊的线性表，其特性是先进先出，只允许在表的前端进行删除操作，而在表的后端进行插入操作

**链表**

是一种物理存储单元上非连续、非顺序的存储结构，数据元素的逻辑顺序是通过链表中的指针链接次序实现的

链表由一系列结点（链表中每一个元素称为结点）组成，结点可以在运行时动态生成

一般情况，每个结点包括两个部分：一个是存储数据元素的数据域，另一个是存储下一个结点地址的指针域

**树**

树是典型的非线性结构，在树的结构中，有且仅有一个根结点，该结点没有前驱结点。在树结构中的其他结点都有且仅有一个前驱结点，而且可以有两个以上的后继结点

**图**

一种非线性结构。在图结结构中，数据结点一般称为顶点，而边是顶点的有序偶对。如果两个顶点之间存在一条边，那么就表示这两个顶点具有相邻关系

**堆**

堆是一种特殊的树形数据结构，每个结点都有一个值，特点是根结点的值最小（或最大），且根结点的两个子树也是一个堆

**散列表**

若结构中存在关键字和`K`相等的记录，则必定在`f(K)`的存储位置上，不需比较便可直接取得所查记录

**三、区别**

上述的数据结构，之前的区别可以分成线性结构和非线性结构：

- 线性结构有：数组、栈、队列、链表等
- 非线性结构有：树、图、堆等

## 2.算法

https://programmercarl.com/

建议不懂题解的话先看下代码随想录的B站视频

https://juejin.cn/post/6844903889003642887#heading-18

腾讯算法面试题：

### 2.1.IPV4地址校验（如果题目中有IPV6地址校验，另加）

https://leetcode.cn/problems/validate-ip-address/

有效的IPv4地址 是 “x1.x2.x3.x4” 形式的IP地址。 其中 0 <= xi <= 255 且 xi 不能包含 前导零。例如: “192.168.1.1” 、 “192.168.1.0” 为有效IPv4地址， “192.168.01.1” 为无效IPv4地址; “192.168.1.00” 、 “192.168@1.1” 为无效IPv4地址。

思路：

1. 以"."做分割，长度为四个
2. 每个数校验数字范围是否在0-255之间
3. 排除前导零
4. try catch包裹函数，如果函数有@等无效字符直接返回false

```java
    public static boolean checkIPV4(String ipAddress) {
        try {
            String[] strArray = ipAddress.split("\\.");
            if (strArray.length != 4) {
                return false;
            }
            for (int i = 0; i < strArray.length; i++) {
                int number = Integer.parseInt(strArray[i]);
                if (number < 0 || number > 255 || (strArray[i].length() > 1 && strArray[i].startsWith("0"))) {
                    return false;
                }
            }
        } catch (Exception e) {
            return false;
        }
        return true;
    }
```

### 2.2.千位分隔符


给你一个整数 `n`，请你每隔三位添加点（即 "." 符号）作为千位分隔符，并将结果以字符串格式返回。

示例 1：

输入：n = 987
输出："987"
示例 2：

输入：n = 1234
输出："1.234"
示例 3：

输入：n = 123456789
输出："123.456.789"
示例 4：

输入：n = 0
输出："0"

思路一：依次获取最高位的数，动态的获取低位的索引，当判断索引为3的整数倍时，加"."分隔

思路二：依次获取最低位的数，动态的获取低位的索引，当判断索引为3的整数倍时，加"."分隔，但是这种做法会使低位数拼在前面高位数拼在后面，需要做字符串翻转，可以用StringBuffer的reverse方法进行翻转，也可以用for循环进行翻转。

解法一：

```java
public static String translateNumber(int number) {
    StringBuilder result = new StringBuilder();
    int numberLength = 1;//数据长度
    int n = number;
    while (n / 10 != 0) {
        n = n / 10;
        numberLength++;
    }
    int p = 1;//10的倍数
    for (int i = 1; i < numberLength; i++) {
        p = p * 10;
    }

    int j = numberLength - 1;
    int m, t;
    t = number;
    while (j >= 0) {//索引
        m = t / p;//依次获取最高位的数
        result.append(m);
        t = t - m * p;
        if (j % 3 == 0 && j != 0) {
            result.append(".");
        }
        p = p / 10;
        j--;
    }
    return result.toString();
}
```

解法二：

```java
public static String translateNumber2(int number) {
    StringBuffer sb = new StringBuffer();
    int index = 0;
    int tempNumber = number;
    do {
        int n = tempNumber % 10;
        tempNumber /= 10;
        sb.append(n);
        ++index;
        if (index % 3 == 0 && index != 0) {
            sb.append(".");
        }
    } while (tempNumber != 0);
    return sb.reverse().toString();
}
```

### 2.3.链表翻转

https://www.bilibili.com/video/BV1nB4y1i7eL?spm_id_from=333.337.search-card.all.click&vd_source=12cbfb4e44348c59a800e75db34b6c37

核心原理是双指针，原理图如下：

![链表翻转](https://raw.githubusercontent.com/treech/PicRemote/master/common/202209191651633.png)

1、while循环什么时候结束？

​	当cur节点为null，pre节点即为最后一个节点

**双指针**实现代码如下：

```cpp
#include <stdio.h>

struct ListNode {
    int val;
    struct ListNode *next;

    ListNode(int x) : val(x), next(NULL) {}
};

ListNode *reverse(ListNode *cur) {
    ListNode *pre = NULL;
    while (cur) {
        //先保存下一个节点，不然指针翻转后连接不到下一个节点
        ListNode *temp = cur->next;
        //cur->next代表下一个节点 pre代表上一个节点,这一步代表指向翻转
        cur->next = pre;
        //节点替换
        pre = cur;
        cur = temp;
    }
    return pre;
}

int main() {
    ListNode *listNode1 = new ListNode(1);
    ListNode *listNode2 = new ListNode(2);
    ListNode *listNode3 = new ListNode(3);
    listNode1->next = listNode2;
    listNode2->next = listNode3;
    printf("before listNode1:%d,listNode2:%d,listNode3:%d\n", listNode1->val, listNode1->next->val,
           listNode2->next->val);

    reverse(listNode1);

    printf("after listNode3:%d,listNode2:%d,listNode1:%d\n", listNode3->val, listNode3->next->val, listNode2->next->val);
    return 0;
}
```

**递归**的解法是在双指针解法的基础上衍生出来的，实现代码如下：

```cpp
ListNode *reverse(ListNode *cur, ListNode *pre) {
    if (cur == NULL) return pre;
    //先保存下一个节点，不然指针翻转后连接不到下一个节点
    ListNode *temp = cur->next;
    //cur->next代表下一个节点 pre代表上一个节点,这一步代表指向翻转
    cur->next = pre;
    reverse(temp,cur);
}
```

# 参考资料

https://github.com/huangruiLearn/hrl_android_notes

https://juejin.cn/post/6870447920911646734

https://github.com/JackyAndroid/AndroidInterview-Q-A/tree/master/source/Android

https://github.com/BlackZhangJX/Android-Notes

https://github.com/chiclaim/AndroidAll

https://github.com/yipianfengye/androidSource

https://github.com/Launcher3-dev/Launcher3

[最全的BAT大厂面试题整理](https://www.jianshu.com/p/c70989bd5f29)

# 面试自检

[还原一场 35K—55K 的腾讯 Android 高工面试](https://zhuanlan.zhihu.com/p/467880971)

http://www.blog2019.net/post/170