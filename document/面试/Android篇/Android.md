**更新时间：2022/08/23**

# Android

## 1.Activity

### 1.1.Activity启动流程

[面试必备：Android（9.0）Activity启动流程(一)](https://juejin.cn/post/6844903959581163528#heading-1)

> <font color=red>这里还不熟悉，需要再看一遍</font>

面试知识点：我们知道Android中所有的进程都是直接通过zygote进程fork出来的（fork可以理解为孵化出来的当前进程的一个副本），为什么所有进程都必须用`zygote`进程fork呢？（https://cloud.tencent.com/developer/article/1803177）

- 这是因为`fork`的行为是复制整个用户的空间数据以及所有的系统对象，并且只复制当前所在的线程到新的进程中。也就是说，父进程中的`其他线程`在子进程中都消失了，为了防止出现各种问题（比如死锁，状态不一致）呢，就只让`zygote`进程，这个单线程的进程，来fork新进程。
- 而且在`zygote`进程中会做好一些初始化工作，比如启动虚拟机，加载系统资源。这样子进程fork的时候也就能直接共享，提高效率，这也是这种机制的优点。

### 1.2.onSaveInstanceState(),onRestoreInstanceState的调用时机 

onSaveInstanceState()主要是屏幕发生旋转的时候调用。

onRestoreInstanceState(Bundle savedInstanceState)只有在activity确实是被系统回收，重新创建activity的情况下才会被调用。

#### 1.2.1.源码

系统会调用ActivityThread的performStopActivity方法中掉用onSaveInstanceState， 将状态保存在mActivities中，
mActivities维护了一个Activity的信息表，当Activity重启时候，会从mActivities中查询到对应的
ActivityClientRecord。
如果有信息，则调用Activity的onResoreInstanceState方法，
在ActivityThread的performLaunchActivity方法中，统会判断ActivityClientRecord对象的state是否为空，不为空则通过Activity的onSaveInstanceState获取其UI状态信息，通过这些信息传递给Activity的onCreate方法。

### 1.3.Activity启动模式和使用场景

#### 1.3.1.启动模式
1. standard：标准模式：如果在mainfest中不设置就默认standard；standard就是新建一个Activity就在栈中新建一个activity实例；

2. singleTop：栈顶复用模式：与standard相比栈顶复用可以有效减少activity重复创建对资源的消耗，但是这要根据具体情况而定，不能一概而论；

3. singleTask：栈内单例模式，栈内只有一个activity实例，栈内已存activity实例，在其他activity中start这个activity，Android直接把这个实例上面其他activity实例踢出栈GC掉；

4. singleInstance :堆内单例：整个手机操作系统里面只有一个实例存在就是内存单例；

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
当A跳转到B的时候，A先执行onPause，然后居然是B再执行onCreate -> onStart -> onResume，最后才执行A的
onStop!!!
当B按下返回键，B先执行onPause，然后居然是A再执行onRestart -> onStart -> onResume，最后才是B执行
onStop -> onDestroy!!!
当 B Activity 的 launchMode 为 singleInstance，singleTask 且对应的 B Activity 有可复用的实例时，生命周期回调
是这样的:
A.onPause -> B.onNewIntent -> B.onRestart -> B.onStart -> B.onResume -> A.onStop -> ( 如果 A 被移出栈的话还
有一个 A.onDestory)
当 B Activity 的 launchMode 为 singleTop且 B Activity 已经在栈顶时（一些特殊情况如通知栏点击、连点），此时
只有 B 页面自己有生命周期变化:
B.onPause -> B.onNewIntent -> B.onResume

### 1.5.横竖屏切换,按home键,按返回键,锁屏与解锁屏幕,跳转透明Activity界面,启动一个 Theme 为 Dialog 的 Activity，弹出Dialog时Activity的生命周期
横竖屏切换：
从 Android 3.2 (API级别 13)开始
https://www.jianshu.com/p/dbc7e81aead2
1、不设置Activity的androidconfigChanges，或设置Activity的androidconfigChanges="orientation"，或设置
Activity的android:configChanges="orientation|keyboardHidden"，切屏会重新调用各个生命周期，切横屏时会执
行一次，切竖屏时会执行一次。
2、配置 android:configChanges="orientation|keyboardHidden|screenSize"，才不会销毁 activity，且只调用
onConfigurationChanged方法。
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

> <font color=red>这里还不熟悉，需要再看一遍</font>

1.Process A进程采用Binder IPC向system_server进程发起startService请求；
2.system_server进程接收到请求后，向zygote进程发送创建进程的请求；
3.zygote进程fork出新的子进程Remote Service进程；
4.Remote Service进程，通过Binder IPC向sytem_server进程发起attachApplication请求；
5.system_server进程在收到请求后，进行一系列准备工作后，再通过binder IPC向remote Service进程发送
scheduleCreateService请求；
6.Remote Service进程的binder线程在收到请求后，通过handler向主线程发送CREATE_SERVICE消息；
7.主线程在收到Message后，通过发射机制创建目标Service，并回调Service.onCreate()方法。
到此，服务便正式启动完成。当创建的是本地服务或者服务所属进程已创建时，则无需经过上述步骤2、3，直接创建
服务即可。

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

ContentProvider的作用是为不同的应用之间数据共享，提供统一的接口，我们知道安卓系统中应用内部的数据是对
外隔离的，要想让其它应用能使用自己的数据（例如通讯录）这个时候就用到了ContentProvider。
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
1。通过ContentResolver调用acquireProvider
2.ActivityThread首先通过一个map查找是否已经install过这个Provider，如果install过就直接将之返回给调用者，如
果没有install过就调用AMS的getContentProvider,AMS首先查找这个Provider是否被publish过，如果publish过就直
接返回，否则通过PMS找到Provider所在的App。
3.如果发现目标App进程未启动,就创建一个ContentProviderRecord对象然后调用其wait方法阻塞当前执行流程,启动
目标App进程,AMS找到App的所有运行于当前进程的Provider,保存在map中,将要启动的所有Provider传给目标App
进程,解除前面对获取Provider执行流程的阻塞。
4.如果目标App进程已启动，AMS在getContentProvider里会查找到要获取的Provider，就直接返回了，调用端App收
到AMS的返回结果后(acquireProvider返回)，调用ActivityThread的installProvider将Provider记录到本地的一个
map中，下次再调用acquireProvider就直接返回。
ContentProvider所提供的接口中只有query是基于共享内存的，其他都是直接使用binder的入参出参进行数据传
递。
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

Handler发送消息时调用MessageQueue的enqueueMessage插入一条信息到MessageQueue,Looper不断轮询调用
MeaasgaQueue的next方法 如果发现message就调用handler的dispatchMessage，dispatchMessage被成功调
用，接着调用handlerMessage()  

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

上述可以看出for(;;)是一个无限循环，不停地轮询消息队列并取出消息，然后将消息分发出去（简单的描述）。Android应用程序就是通过这个方法来达到及时响应用户操作。这个过程并不会导致ANR，ANR指应用程序在一定时间内没有得到响应或者响应时间太长。在主线程的MessageQueue没有消息时，便阻塞在loop的queue.next()中的nativePollOnce()方法里，此时主线程会释放CPU资源进入休眠状态。因为没有消息，即不需要响应程序，便不会出现程序无响应（ANR）现象。

总结：loop无限循环用于取出消息并将消息分发出去，没有消息时会阻塞在queue.next()里的nativePollOnce()方法里，并释放CPU资源进入休眠。Android的绝大部分操作都是通过Handler机制来完成的，如果没有消息，则不需要程序去响应，就不会有ANR。ANR一般是消息的处理过程中耗时太长导致没有及时响应用户操作。

### 5.3.子线程中能不能直接new一个Handler,为什么主线程可以

主线程的Looper第一次调用loop方法,什么时候,哪个类
不能，因为Handler的构造方法中，会通过Looper.myLooper()获取looper对象，如果为空，则抛出异常，
主线程则因为已在入口处ActivityThread的main方法中通过 Looper.prepareMainLooper()获取到这个对象，
并通过 Looper.loop()开启循环，在子线程中若要使用handler，可先通过Loop.prepare获取到looper对象，并使用
Looper.loop()开启循环

### 5.4.Handler导致的内存泄露原因及其解决方案

原因:
1.Java中非静态内部类和匿名内部类都会隐式持有当前类的外部引用
2.我们在Activity中使用非静态内部类初始化了一个Handler,此Handler就会持有当前Activity的引用。
3.我们想要一个对象被回收，那么前提它不被任何其它对象持有引用，所以当我们Activity页面关闭之后,存在引用关系："未被处理 / 正处理的消息 -> Handler实例 -> 外部类"，如果在Handler消息队列还有未处理的消息 / 正在处理消息时，导致Activity不会被回收，从而造成内存泄漏 

解决方案: 
1.将Handler的子类设置成 静态内部类,使用WeakReference弱引用持有Activity实例 
2.当外部类结束生命周期时，清空Handler内消息队列

### 5.5.一个线程可以有几个Handler,几个Looper,几个MessageQueue对象 

一个线程可以有多个Handler,只有一个Looper对象,只有一个MessageQueue对象。Looper.prepare()函数中知
道。在Looper的prepare方法中创建了Looper对象，并放入到ThreadLocal中，并通过ThreadLocal来获取looper
的对象, ThreadLocal的内部维护了一个ThreadLocalMap类,ThreadLocalMap是以当前thread做为key的,因此可以得
知，一个线程最多只能有一个Looper对象， 在Looper的构造方法中创建了MessageQueue对象，并赋值给mQueue
字段。因为Looper对象只有一个，那么Messagequeue对象肯定只有一个。 

### 5.6.Message对象创建的方式有哪些 & 区别 

Message.obtain()怎么维护消息池的
1.Message msg = new Message();
每次需要Message对象的时候都创建一个新的对象，每次都要去堆内存开辟对象存储空间
2.Message msg =
Message.obtain();
obtainMessage能避免重复Message创建对象。它先判断消息池是不是为空，如果非空的话就从消息池表头的
Message取走,再把表头指向 next。
如果消息池为空的话说明还没有Message被放进去，那么就new出来一个Message对象。消息池使用 Message 链表
结构实现，消息池默认最大值 50。消息在loop中被handler分发消费之后会执行回收的操作，将该消息内部数据清空
并添加到消息链表的表头。
3.Message msg = handler.obtainMessage(); 其内部也是调用的obtain()方法   

### 5.7.Handler 有哪些发送消息的方法

sendMessage(Message msg)
sendMessageDelayed(Message msg, long uptimeMillis)
post(Runnable r)
postDelayed(Runnable r, long uptimeMillis)
sendMessageAtTime(Message msg,long when)

### 5.8.Handler的post与sendMessage的区别和应用场景

1.源码
sendMessage
sendMessage-sendMessageAtTime-enqueueMessage。
post
sendMessage-getPostMessage-sendMessageAtTime-enqueueMessage getPostMessage会先生成一个
Messgae，并且把runnable赋值给message的callback
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
而sendMessage中如果mCallback不为null就会调用mCallback.handleMessage(msg)方法，如果handler内的
callback不为空，执行mCallback.handleMessage(msg)这个处理消息并判断返回是否为true，如果返回true，消息
处理结束，如果返回false,handleMessage(msg)处理。否则会直接调用handleMessage方法。
post方法和handleMessage方法的不同在于，区别就是调用post方法的消息是在post传递的Runnable对象的run方
法中处理，而调用sendMessage方法需要重写handleMessage方法或者给handler设置callback，在callback的
handleMessage中处理并返回true
应用场景
post一般用于单个场景 比如单一的倒计时弹框功能 sendMessage的回调需要去实现handleMessage Message则做
为参数 用于多判断条件的场景

### 5.9.handler postDelay后消息队列有什么变化，假设先 postDelay 10s, 再postDelay 1s, 怎么处理这2条消息sendMessageDelayedsendMessageAtTime-sendMessage

ostDelayed传入的时间，会和当前的时间SystemClock.uptimeMillis()做加和,而不是单纯的只是用延时时间。延时
消息会和当前消息队列里的消息头的执行时间做对比，如果比头的时间靠前，则会做为新的消息头，不然则会从消息
头开始向后遍历，找到合适的位置插入延时消息。
postDelay()一个10秒钟的Runnable A、消息进队，MessageQueue调用nativePollOnce()阻塞，Looper阻塞；
紧接着post()一个Runnable B、消息进队，判断现在A时间还没到、正在阻塞，把B插入消息队列的头部（A的前
面），然后调用nativeWake()方法唤醒线程；
MessageQueue.next()方法被唤醒后，重新开始读取消息链表，第一个消息B无延时，直接返回给Looper；
Looper处理完这个消息再次调用next()方法，MessageQueue继续读取消息链表，第二个消息A还没到时间，计算一下剩余时间（假如还剩9秒）继续调用nativePollOnce()阻塞； 直到阻塞时间到或者下一次有Message进队；

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
IdleHandler 被定义在 MessageQueue 中，它是一个接口. 定义时需要实现其 queueIdle() 方法。返回值为 true 表
示是一个持久的 IdleHandler 会重复使用，返回 false 表示是一个一次性的 IdleHandler。
IdleHandler 被 MessageQueue 管理，对应的提供了 addIdleHandler() 和 removeIdleHandler() 方法。将其存入
mIdleHandle addIdleHandler() 和 removeIdleHandler() 方法。将其存入 mIdleHandlers 这个 ArrayList 中。
**什么时候调用**
就在MessageQueue的next方法里面。 MessageQueue 为空，没有 Message； MessageQueue 中最近待处理的
Message，是一个延迟消息（when>currentTime），需要滞后执行；  
**使用场景**
1.Activity启动优化：onCreate，onStart，onResume中耗时较短但非必要的代码可以放到IdleHandler中执行，减
少启动时间
2.想要在一个View绘制完成之后添加其他依赖于这个View的View，当然这个用View#post()也能实现，区别就是前者
会在消息队列空闲时执行
优化页面的启动,较复杂的view填充 填充里面的数据界面view绘制之前的话，就会出现以上的效果了，view先是白
的，再出现. app的进程其实是ActivityThread,performResumeActivity先回调onResume ， 之后执行view绘制的
measure, layout, draw,也就是说onResume的方法是在绘制之前，在onResume中做一些耗时操作都会影响启动时
间，把在onResume以及其之前的调用的但非必须的事件（如某些界面View的绘制）挪出来找一个时机（即绘制完成
以后）去调用即可。  

### 5.14.消息屏障，同步屏障机制what

同步屏障只在Looper死循环获取待处理消息时才会起作用，也就是说同步屏障在MessageQueue.next函数中发挥着
作用。
在next()方法中，有一个屏障的概念(message.target ==null为屏障消息), 遇到target为null的Message，说明是同步
屏障，循环遍历找出一条异步消息，然后处理。 在同步屏障没移除前，只会处理异步消息，处理完所有的异步消息
后，就会处于堵塞 当出现屏障的时候，会滤过同步消息，而是直接获取其中的异步消息并返回, 就是这样来实现「异
步消息优先执行」的功能
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

https://www.jianshu.com/p/58d22426e79e
https://www.jianshu.com/p/887336850177

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

View的绘制从ActivityThread类中Handler的处理RESUME_ACTIVITY事件开始，在执行performResumeActivity之后，创建Window以及DecorView并调用WindowManager的addView方法添加到屏幕上，addView又调用ViewRootImpl的setView方法，最终执行performTraversals方法，依次执行performMeasure，performLayout，performDraw。也就是view绘制的三大过程。

performMeasure会调用measure，measure又会调用onMeasure(),最终测量出view视图的大小，还需要调用setMeasuredDimension方法设置测量的结果，如果是ViewGroup需要调用measureChildren或者measureChild方法测量子view的大小从而计算自己的大小。

performLayout会调用layout，layout又会调用onLayout(),从而计算出view摆放的位置，View不需要实现，通常由ViewGroup实现，在实现onLayout时可以通过getMeasuredWidth等方法获取measure过程测量的结果进行摆放。

performDraw会调用draw，draw又会调用onDraw(),这个过程先是绘制背景，其次在onDraw()方法绘制view的内容，再然后调用dispatchDraw()调用子view的draw方法，最后绘制滚动条。ViewGroup默认不会执行onDraw方法，如果复写了onDraw(Canvas)方法，需要调用 setWillNotDraw(false);清除不需要绘制的标记。

requestLayout()、invalidate()与postInvalidate()有什么区别？
requestLayout()：该方法会递归调用父窗口的requestLayout()方法，直到触发ViewRootImpl的performTraversals()方法，此时mLayoutRequestede为true，会触发onMesaure()与onLayout()方法，不一定会触发onDraw()方法。
invalidate()：该方法递归调用父View的invalidateChildInParent()方法，直到调用ViewRootImpl的invalidateChildInParent()方法，最终触发ViewRootImpl的performTraversals()方法，此时mLayoutRequestede为false，不会触发onMesaure()与onLayout()方法，但是会触发onDraw()方法。
postInvalidate()：该方法功能和invalidate()一样，只是它可以在非UI线程中调用。
一般说来需要重新布局就调用requestLayout()方法，需要重新绘制就调用invalidate()方法。

### 6.2.MeasureSpec是什么

MeasureSpec表示的是一个32位的整形值，它的高2位表示测量模式SpecMode，低30位表示某种测量模式下的规格大小SpecSize。MeasureSpec是View类的一个静态内部类，用来说明应该如何测量这个View。它由三种测量模式，
如下：
EXACTLY：精确测量模式，视图宽高指定为match_parent或具体数值时生效，表示父视图已经决定了子视图的精确大小，这种模式下View的测量值就是SpecSize的值。
AT_MOST：最大值测量模式，当视图的宽高指定为wrap_content时生效，此时子视图的尺寸可以是不超过父视图允许的最大尺寸的任何尺寸。
UNSPECIFIED：不指定测量模式, 父视图没有限制子视图的大小，子视图可以是想要的任何尺寸，通常用于系统内部，应用开发中很少用到。
MeasureSpec通过将SpecMode和SpecSize打包成一个int值来避免过多的对象内存分配，为了方便操作，其提供了打包和解包的方法，打包方法为makeMeasureSpec，解包方法为getMode和getSize。

### 6.3.子View创建MeasureSpec创建规则是什么

https://www.helloworld.net/p/7576286967

根据父容器的MeasureSpec和子View的LayoutParams等信息计算子View的MeasureSpec

![25c4705583497db347c014312def6ad4](https://raw.githubusercontent.com/treech/PicRemote/master/common/25c4705583497db347c014312def6ad4.png)

### 6.4.自定义View wrap_content不起作用的原因
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

### 6.5.在Activity中获取某个View的宽高有几种方法

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

### 6.6.为什么onCreate获取不到View的宽高  

Activity在执行完oncreate，onResume之后才创建ViewRootImpl,ViewRootImpl进行View的绘制工作
**调用链**
startActivity->ActivityThread.handleLaunchActivity->onCreate ->完成DecorView和Activity的创建-
\>handleResumeActivity->onResume()->DecorView添加到WindowManager->ViewRootImpl.performTraversals()方法，测量（measure）,布局（layout）,绘制（draw）, 从DecorView自上而下遍历整个View树。

### 6.7.View#post与Handler#post的区别

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

### 6.8.Android绘制和屏幕刷新机制原理

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
Choreographer， 编舞者。指对CPU/GPU绘制的指导，收到VSync信号 才开始绘制，保证绘制拥有完整的16.6ms，避免绘制的随机性。控制只在vsync信号来时触发重绘呢
比如说绘制可能随时发起，封装一个Runnable丢给Choreography，下一个vsync信号来的时候，开始处理消息，然后真正的开始界面的重绘了。相当于UI绘制的节奏完全由Choreography来控制。
应用程序调用requestLayout发起重绘，通过Choreographer发送异步消息，请求同步vsync信号，即下一次vsync信号过来时，系统服务SurfaceFlinger在第一时间通知我们，触发UI绘制。虽然可以手动多次调用，但是在一个vsync周期内，requestLayout只会执行一次。

### 6.9.Choreography原理

绘制是由应用端(任何时候都有可能)发起的，如果屏幕收到vsync信号，但是这一帧的还没有绘制完，就会显示上一帧的数据，这并不是因为绘制这一帧的时间过长(超过了信号发送周期)，只是信号快来的时候才开始绘制，如果频繁的出现的这种情况。一般调用requestLayout触发，这个函数随时都能调用，为了只控制在vsync信号来时触发重绘引入Choreography。 ViewRoot.doTravle()->mChoreographer.postCallback
Choreographer对外提供了postCallback等方法，最终他们内部都是通过调用postCallbackDelayedInternal（）实现这个方法主要会做两件事情 1存储Action 请求垂直同步，垂直同步 2垂直同步回调立马执行Action（CallBack/Runnable）。

### 6.10.什么是双缓冲

通俗来讲就是有两个缓冲区，一个后台缓冲区和一个前台缓冲区，每次后台缓冲区接受数据，当填充完整后交换给前台缓冲，这样就保证了前台缓冲里的数据都是完整的。 Surface对应了一块屏幕缓冲区，是要显示到屏幕的内容的载体。每一个Window都对应了一个自己的Surface。这里说的 window 包括 Dialog, Activity, Status Bar等。
SurfaceFlinger 最终会把这些 Surface 在 z 轴方向上以正确的方式绘制出来（比如 Dialog 在 Activity 之上）。
SurfaceView 的每个 Surface 都包含两个缓冲区，而其他普通 Window 的对应的 Surface 则不是。

### 6.11.为什么使用SurfaceView

我们知道View是通过刷新来重绘视图，系统通过发出VSSYNC信号来进行屏幕的重绘，刷新的时间间隔是16ms,如果我们可以在16ms以内将绘制工作完成，则没有任何问题，如果我们绘制过程逻辑很复杂，并且我们的界面更新还非常频繁，这时候就会造成界面的卡顿，影响用户体验，为此Android提供了SurfaceView来解决这一问题。他们的UI不适合在主线程中绘制。对一些游戏画面，或者摄像头，视频播放等，UI都比较复杂，要求能够进行高效的绘制，因此，他们的UI不适合在主线程中绘制。这时候就必须要给那些需要复杂而高效的UI视图生成一个独立的绘制表面
Surface,并且使用独立的线程来绘制这些视图UI。

### 6.12.什么是SurfaceView

SurfaceView是View的子类，且实现了Parcelable接口，其中内嵌了一个专门用于绘制的Surface，SurfaceView可以控制这个Surface的格式和尺寸，以及Surface的绘制位置。可以理解为Surface就是管理数据的地方，SurfaceView就是展示数据的地方。使用双缓冲机制，有自己的surface，在一个独立的线程里绘制。
SurfaceView虽然具有独立的绘图表面，不过它仍然是宿主窗口的视图结构中的一个结点，因此，它仍然是可以参与到宿主窗口的绘制流程中去的。从SurfaceView类的成员函数draw和dispatchDraw的实现就可以看出，SurfaceView在其宿主窗口的绘图表面上面所做的操作就是将自己所占据的区域绘为黑色，除此之外，就没有其它更多的操作了，这是因为SurfaceView的UI是要展现在它自己的绘图表面上面的。 
优点：使用双缓冲机制，可以在一个独立的线程中进行绘制，不会影响主线程，播放视频时画面更流畅 
缺点：Surface不在View hierachy中，它的显示也不受View的属性控制，SurfaceView不能嵌套使用。在7.0版本之前不能进行平移，缩放等变换，也不能放在其它ViewGroup中，在7.0版本之后可以进行平移，缩放等变换。

### 6.13.View和SurfaceView的区别

1. View适用于主动更新的情况，而SurfaceView则适用于被动更新的情况，比如频繁刷新界面。 
1. View在主线程中对页面进行刷新，而SurfaceView则开启一个子线程来对页面进行刷新。 3. 3. View在绘图时没有实现双缓冲机制，SurfaceView在底层机制中就实现了双缓冲机制。

















# 临时存的内容

https://github.com/JackyAndroid/AndroidInterview-Q-A/tree/master/source/Android

https://github.com/BlackZhangJX/Android-Notes

https://github.com/chiclaim/AndroidAll

https://github.com/yipianfengye/androidSource

https://github.com/Launcher3-dev/Launcher3

> android 12源码分析

[最全的BAT大厂面试题整理](https://www.jianshu.com/p/c70989bd5f29)

[还原一场 35K—55K 的腾讯 Android 高工面试](https://zhuanlan.zhihu.com/p/467880971)

# 源码阅读利器-SourceInsight

[Android 8.0 : 如何下载和阅读Android源码](https://www.jianshu.com/p/14ade986d3a8)
