[toc]
# 1、冷启动时间检测
## 通过adb命令来检测应用冷启动时间
```
adb shell am start -W package/Activity路径
```
## 运行结果如下所示
- TotalTime：应用的启动时间，包括创建进程+Application初始化+Activity初始化到界面显示。
- WaitTime：一般比TotalTime大点，是AMS启动Activity的总耗时。
- Android 5.0以下没有WaitTime，所以我们只需要关注TotalTime即可。
```
Starting: Intent { act=android.intent.action.MAIN cat=[android.intent.category.LAUNCHER] cmp=***/***.SplashActivity }
Warning: Activity not started, intent has been delivered to currently running top-most instance.
Status: ok
LaunchState: UNKNOWN (0)
Activity: ***/***.MainActivity
TotalTime: 785
WaitTime: 787
Complete
```
# 2、冷启动时间消耗在哪
## 2.1、MultiDex耗时
### apk的编译过程
- 1、打包资源文件，生成R.java文件（使用工具AAPT）
- 2、处理AIDL文件，生成java代码（没有AIDL则忽略）
- 3、编译 java 文件，生成对应.class文件（java compiler）
- 4、.class 文件转换成dex文件（dex）
- 5、打包成没有签名的apk（使用工具apkbuilder）
- 6、使用签名工具给apk签名（使用工具Jarsigner）
- 7、对签名后的.apk文件进行对齐处理，不进行对齐处理不能发布到Google
Market（使用工具zipalign）

### 为什么需要使用MultiDex
在apk编译流程的第4步，将class文件转换成dex文件，默认只会生成一个dex文件，单个dex文件中的方法数不能超过65536，不然编译会报错：
```
Unable to execute dex: method ID not in [0, 0xffff]: 65536
```
在实际开发中，我们的App一定会集成很多的通用的三方库组件、业务组件等等，并且随着业务的不断迭代，整个App的方法数一般都是超过65536的，解决办法就是：一个dex不够用，那就多来几个dex，gradle增加一行配置即可。
```
multiDexEnabled true
```
这样解决了编译问题，在5.0以上手机运行正常，但是5.0以下手机运行直接crash，报错 Class NotFound xxx。
原因很简单：5.0以下，ClassLoader加载类时只会从class.dex（主dex）里加载，它并不认识其他的class2.dex、class3.dex等等，当访问的类不在主dex中时，就会报错class NotFound，所以为了解决这个问题，google提供了兼容方案==MultiDex==
### MultiDex原来这么耗时！
这是在4.4的模拟器中跑的数据
```
MultiDex.install 耗时：1385
```
### 为什么MultiDex这么耗时！老规矩，上源码！
此处省略N行代码...，直接上图！
![MultDex原理](https://note.youdao.com/yws/res/662/WEBRESOURCE59bf2f7855f0706ac6fffdfc221b1dbb)
简单概括一下，就是：
![mudtdex总结](https://note.youdao.com/yws/res/668/WEBRESOURCE6448add0e1558929b49b42edb70bcf93)

**这里插点别的东西，其实热更新的原理也基本类似，比如Tinker，只不过Tinker把补丁包中的dex添加到了数组的最前面，而不是后面，为啥这样做，下面简单分析一下ClassLoader的原理**

不管是 PathClassLoader还是DexClassLoader，都继承自BaseDexClassLoader，加载类的代码在BaseDexClassLoader中，所以简单概括一下这个流程
![ClassLoader原理](https://note.youdao.com/yws/res/680/WEBRESOURCE9e08e4534fa4b1f42e883a799773662c)
**由上可知，类加载的过程本质上就是数组的遍历过程，所以，为何Tinker会把补丁dex加在数组的最前面就非常好理解了，因为补丁包中的dex不需要把原apk中的dex进行替换，费力又不讨好，还影响原包结构，加在最前面，findlass找到补丁包中的类就不会再往下遍历了，直接就起到了不是替换而形似替换的作用。**
### 总结
**结合MultDex和ClassLoader的加载原理，我们再稍微细化一下两者结合的过程，如下**
![multdex细化原理](https://note.youdao.com/yws/res/739/WEBRESOURCEc7d9e1756a1c57e21dae6c5030bc89bd)
**经过前文中的流程图，不难发现，MultDex Hook的点其实就在DexPathList的dexElements数组上，而dex插入的关键方法是把dex文件转换成Element对象，也就是图中的DexPathList.makeDexElements()方法，为何着重提这个，咱们下面在优化部分再深入了解这个问题！**
## 2.2、Application中初始化应用所需的业务、工具、UI等组件，导致耗时
### 冷启动流程
![冷启动流程](https://note.youdao.com/yws/res/708/WEBRESOURCE8ef2b2c34850158e27445330c8007f42)

**不难看出，ContentProvider的onCreate()是在Application的onCreate()之前调用的，这也就导致市面上出现了很多声明了自动初始化的库，对着这种东西，个人看法很简单，除了确实需要自动初始化且真的提高了开发效率，耗时还较短的东西，别的库用这点雕虫小技就是当纯的炫技，多此一举。**
### Application的onCreate()方法
**通常，我们会在这里做很多的初始化操作，各种库，业务组件等等，如果这里的任务执行过多，且都是在主线程里串行执行的，会大大影响冷启动速度**
# 3、冷启动优化
## 3.1、MultDex优化
### MultDex优化第一式（掩耳盗铃，偷换概念）
**多进程MultDex加载大法！原理如下：**
![多进程multdex加载.png](https://note.youdao.com/yws/res/1347/WEBRESOURCE882e83a34771636aeb6db376f5d12fe9)

为何说这是掩耳盗铃、偷换概念呢，因为冷启动的概念是从应用创建进程到显示第一个Activity为结束，所以我们的方案看似第一个Activity秒开展示，但是真正的耗时问题并没有解决，不急！下面有更好的解决方案！
### MultDex优化第二式（正解）
**前文中，在2.1的结尾部分，着重提了一下DexPathList.makeDexElements()方法，这里贴一段代码，Android 4.4的源码**
```
private static Element[] makeDexElements(ArrayList<File> files, File optimizedDirectory,
                                             ArrayList<IOException> suppressedExceptions) {
        ArrayList<Element> elements = new ArrayList<Element>();
        /*
         * Open all files and load the (direct or contained) dex files
         * up front.
         */
        for (File file : files) {
            File zip = null;
            DexFile dex = null;
            String name = file.getName();
            //加载Dex
            if (name.endsWith(DEX_SUFFIX)) {
                // Raw dex file (not inside a zip/jar).
                try {
                    dex = loadDexFile(file, optimizedDirectory);
                } catch (IOException ex) {
                    System.logE("Unable to load dex file: " + file, ex);
                }
                //加载apk、jar、zip
            } else if (name.endsWith(APK_SUFFIX) || name.endsWith(JAR_SUFFIX)
                    || name.endsWith(ZIP_SUFFIX)) {
                zip = file;

                try {
                    dex = loadDexFile(file, optimizedDirectory);
                } catch (IOException suppressed) {
                    /*
                     * IOException might get thrown "legitimately" by the DexFile constructor if the
                     * zip file turns out to be resource-only (that is, no classes.dex file in it).
                     * Let dex == null and hang on to the exception to add to the tea-leaves for
                     * when findClass returns null.
                     */
                    suppressedExceptions.add(suppressed);
                }
            } else if (file.isDirectory()) {
                // We support directories for looking up resources.
                // This is only useful for running libcore tests.
                elements.add(new Element(file, true, null, null));
            } else {
                System.logW("Unknown file type for: " + file);
            }

            if ((zip != null) || (dex != null)) {
                elements.add(new Element(file, false, zip, dex));
            }
        }

        return elements.toArray(new Element[elements.size()]);
    }
```
**果然！这里发现了神奇的事情！DexPathList.makeDexElements()方法时可以直接使用dex的，而我们之前的流程图中，MultDex是先把dex压缩成zip，再通过zip来生成Element的，这岂不是南辕北辙了吗？个人理解可能的解释是写MultDex代码的人当时脑子抽了**

**既然可以直接使用dex，那这里可能就是我们能真正优化的点了。所以，这里着重推荐一个头条的开源库[BoostMultiDex](https://github.com/bytedance/BoostMultiDex)**

**BoostMultiDex方案的技术实现要点如下：**

- 利用系统隐藏函数，直接加载原始DEX字节码，避免ODEX(从apk文件中提取出classes.dex文件，并通过优化生成一个可运行的文件单独存放)耗时
- 多级加载，在DEX字节码、DEX文件、ODEX文件中选取最合适的产物启动APP
- 单独进程做OPT(就是上一条的过程)，并实现合理的中断及恢复机制
## 3.2、 Application任务调度
### 把主线程的串行任务变成并发任务
**提起并发，在Android我们最常用的基本就是AsyncTask和线程池了，但是，一股脑的把所有任务都放在子线程里去调度是否真的会减少冷启动时间，减少的时间比起我们改造的成本来说，收益大不大，是不是最优解，都是我们需要着重考虑的问题，所以，如何选择合适的线程池是我们最先需要解决的问题。**
### 任务调度线程池的选择
**首先，我们需要达成共识，线程在Android是干嘛的，它是CPU任务调度的基本单位，而并发的本质就是共享CPU的时间片，所以，如果我们在线程池中的任务极大的消耗了CPU的资源，这就会导致一个直观的问题，看似串行任务变成了多线程并发任务，却造成了主线程卡顿，导致我们的所作所为出现了副作用。**

**基于上面的描述，关于线程池的选择，在这种场景下，我们最优的选择无非就是==定容线程池==，==缓存线程池==，但是到底该用哪种，又或者说两者都用的时候，任务该如何决定使用哪个线程池，发现问题就预示着我们已经解决了该问题的一半了。**

**因此，我们需要知道某一个任务是否是==CPU消耗型的任务==（比如运算类的操作），还是说==IO类型的任务==（内存分配型），前者消耗的CPU时间片较多，我们就把它放在==定容线程池==里调度，后者消耗的时间片少，我们就把它放在==缓存线程池==中，这样，技能充分的调用CPU资源，又不容易过度占用CPU，使得任务并发运行，达到时间优化的目的。**

**这里我们借助工具：==SysTrace==，来确定一个任务的耗时：**
1. 代码中插入：
```
private void initAnalyzeAync() {
        TraceCompat.beginSection("initAnalyzeAync");
        PbnAnalyze.setEnableLog(BuildConfig.DEBUG);
        PbnAnalyze.setEnableAnalyzeEvent(true);
        initAnalyze();
        TraceCompat.endSection();
    }
```
2. 找到systrace.py所在目录（sdk/platform-tools/systrace/）
![systrace](https://note.youdao.com/yws/res/901/WEBRESOURCE9608039b1a2495b9dae665ee0d959278)
3. 执行python命令（需安装python环境）：
```
python systrace.py-t 10 -a <package_name> -o xxtrace.html sched gfx view wm am app
```
![systrace运行.png](https://note.youdao.com/yws/res/906/WEBRESOURCEac32f42f6a9b1125401e00a5dbd1f768)
4. 运行App，等待html文件生成：
![systrace运行结果.png](https://note.youdao.com/yws/res/909/WEBRESOURCE73dff31ab84e9a58d270e112586c64ea)
5. 打开html文件，查看耗时==cpu Duration==为消耗cpu的时间，==wall Duration==为总时间

![systrace测试.png](https://note.youdao.com/yws/res/918/WEBRESOURCE6bc35c93429345b5a9ac60bc552ff696)
6. 可以看到，==cpu Duration==几乎占了全部的==wall Duration==，所以这个任务为cpu消耗型任务，所以我们优化的时候要把这个任务放在==定容线程池==中

**可能这里又会有个疑问，现在的移动端设备多是主打多核的，而多线程真正意义的并发，靠的就是CPU的核数，实际的使用过程中，却不会让你的应用把多核跑满，一方面是为了Room的流畅度，另一方面是为了降低耗电量，这里推荐一个腾讯出品的库[Hardcoder](https://note.youdao.com/)，下面做一个简单的介绍：**

**==Hardcoder== 是一套 Android APP 与系统间的通信解决方案，突破了 APP 只能调用系统标准 API，无法直接调用系统底层硬件资源的问题，让 Android APP 和系统能实时通信。APP 能充分调度系统资源如 CPU 频率，大小核，GPU 频率等来提升 APP 性能，系统能够从 APP 侧获取更多信息以便更合理提供各项系统资源。同时，对于 Android 缺乏标准接口实现的功能，APP 和系统也可以通过该框架实现机型适配和功能拓展。**
### 任务调度的先后顺序

**如何为任务选择合适的线程池问题我们已经解决了，但是实际使用中，我们的任务执行是有先后顺序的，可能在主线程串行的时候，任务顺序我们非常容易控制，但是，多线程并发时，并且使用的不同的线程池后，这些任务执行的顺序问题又该如何解决呢。**

**==有向无环图==这个数据结构完美的解决了我们的问题。具体在代码中如何实现，待会细看，其实就是每个任务用countDownLatch来标记入度。**
- 先执行入度为0的任务
- 让依赖于它的任务入度-1（countDownLatch.countDown()），直到入度为0，执行该任务
- 重复以上两个步骤
![有向无环图.png](https://note.youdao.com/yws/res/939/WEBRESOURCEcd09b39624eb16d7f51c50218794eb67)

### 任务执行等待问题
**我们实际开发中，经常会遇到这种场景，splashActivity的启动必须依赖于某个库初始化完成才行，直白一点来说就是在application中阻塞执行这个任务，基于我们的多线程并发任务调度，最简便的方法就是任务管理器使用==CountDownLatch==，在任务开始执行时调用countDownLatch.await()，在我们构造图结构时，把需要在application中阻塞执行的任务标记好，然后每执行完一个任务countDownLatch.countDown()，直到所有阻塞任务都执行完毕后，阻塞结束**

### 首页和主页预加载
**这部分属于小优化了，带来的冷启动时间的减少仅仅有1-3ms左右，就是我们可以在启动任务中加入一个任务，这个任务只做一件事：**
```
SplashActivity spActivity = new SplashActivity();
MainActivity mainActivity = new MainActivity();
```
**原理其实很简单，类加载器加载过一次类后，会缓存起来，再次加载该类时，不会再去findClass，上面的代码作用就是如此，我们真正创建Activity时，是通过反射创建的，findClass不仅仅是find还包含检查的作用(如 not find之类的try catch)，所以这样做也可以节约部分时间**

### 总结
**关于冷启动任务调度优化的关键点，我们都分析过了，所以汇总一下，产出有向无环图启动器[AppStartFaster](https://github.com/NoEndToLF/AppStartFaster)，如何使用，github有详细说明。**