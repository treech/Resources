# 介绍

- 怎么通过报错信息大致定位到native代码大概哪里出现问题

- 如何利用vs(visual studio)调试

如果 JVM 在执行 native c++ 代码（JNI）的时候崩溃了，一般来说 JVM 会将错误报告写到一个文件中，在 Linux 平台上这个文件形如 `/tmp/jvm-8666/hs_error.log`, 而在 Mac 平台上，它的文件名类似于`hs_err_pid76448.log`，一般存放在 Java 进程的工作目录。

# 解读error日志文件

`hs_err_pid` 文件的核心内容可能如下所示：

```java
Stack: [0x00000000026f0000,0x00000000027f0000],  sp=0x00000000027ef040,  free space=1020k
Native frames: (J=compiled Java code, j=interpreted, Vv=VM code, C=native code)
V  [jvm.dll+0x15f044]
V  [jvm.dll+0x15f3e7]
C  [Project1.dll+0x119ea]  Java_com_netposa_jni_AndroidTest_accessStaticMethod+0x9a
C  0x0000000002a11df0

Java frames: (J=compiled Java code, j=interpreted, Vv=VM code)
j  com.netposa.jni.AndroidTest.accessStaticMethod()V+0
j  com.netposa.jni.AndroidTest.main([Ljava/lang/String;)V+174
v  ~StubRoutines::call_stub

---------------  P R O C E S S  ---------------

Java Threads: ( => current thread )
  0x000000001e35d000 JavaThread "Service Thread" daemon [_thread_blocked, id=10404, stack(0x000000001f090000,0x000000001f190000)]
  0x000000001e2c5800 JavaThread "C1 CompilerThread3" daemon [_thread_blocked, id=11296, stack(0x000000001ef90000,0x000000001f090000)]
  0x000000001e2c5000 JavaThread "C2 CompilerThread2" daemon [_thread_blocked, id=8160, stack(0x000000001ee90000,0x000000001ef90000)]
  0x000000001e2bc800 JavaThread "C2 CompilerThread1" daemon [_thread_blocked, id=8956, stack(0x000000001ed90000,0x000000001ee90000)]
  0x000000001e2ba000 JavaThread "C2 CompilerThread0" daemon [_thread_blocked, id=12208, stack(0x000000001ec90000,0x000000001ed90000)]
  0x000000001e236800 JavaThread "JDWP Command Reader" daemon [_thread_in_native, id=1272, stack(0x000000001eb90000,0x000000001ec90000)]
  0x000000001e233800 JavaThread "JDWP Event Helper Thread" daemon [_thread_blocked, id=3572, stack(0x000000001ea90000,0x000000001eb90000)]
  0x000000001e228000 JavaThread "JDWP Transport Listener: dt_socket" daemon [_thread_blocked, id=8332, stack(0x000000001e990000,0x000000001ea90000)]
  0x000000001e1c9000 JavaThread "Attach Listener" daemon [_thread_blocked, id=13996, stack(0x000000001e890000,0x000000001e990000)]
  0x000000001e223800 JavaThread "Signal Dispatcher" daemon [_thread_blocked, id=8284, stack(0x000000001e790000,0x000000001e890000)]
  0x000000001e1b0800 JavaThread "Finalizer" daemon [_thread_blocked, id=11360, stack(0x000000001e690000,0x000000001e790000)]
  0x000000001c3bc800 JavaThread "Reference Handler" daemon [_thread_blocked, id=12956, stack(0x000000001e590000,0x000000001e690000)]
=>0x00000000022be800 JavaThread "main" [_thread_in_vm, id=3068, stack(0x00000000026f0000,0x00000000027f0000)]

Other Threads:
  0x000000001c3b8800 VMThread [stack: 0x000000001e090000,0x000000001e190000] [id=11796]
  0x000000001e373800 WatcherThread [stack: 0x000000001f190000,0x000000001f290000] [id=3324]

VM state:not at safepoint (normal execution)

VM Mutex/Monitor currently owned by a thread: None

heap address: 0x00000006c2200000, size: 4062 MB, Compressed Oops mode: Zero based, Oop shift amount: 3
Narrow klass base: 0x0000000000000000, Narrow klass shift: 3
Compressed class space size: 1073741824 Address: 0x00000007c0000000

Heap:
 PSYoungGen      total 75776K, used 5202K [0x000000076b600000, 0x0000000770a80000, 0x00000007c0000000)
  eden space 65024K, 8% used [0x000000076b600000,0x000000076bb14838,0x000000076f580000)
  from space 10752K, 0% used [0x0000000770000000,0x0000000770000000,0x0000000770a80000)
  to   space 10752K, 0% used [0x000000076f580000,0x000000076f580000,0x0000000770000000)
 ParOldGen       total 173568K, used 0K [0x00000006c2200000, 0x00000006ccb80000, 0x000000076b600000)
  object space 173568K, 0% used [0x00000006c2200000,0x00000006c2200000,0x00000006ccb80000)
 Metaspace       used 3087K, capacity 4556K, committed 4864K, reserved 1056768K
  class space    used 324K, capacity 392K, committed 512K, reserved 1048576K

Card table byte_map: [0x0000000011db0000,0x00000000125a0000] byte_map_base: 0x000000000e79f000

Marking Bits: (ParMarkBitMap*) 0x00000000755baf90
 Begin Bits: [0x00000000132f0000, 0x0000000017268000)
 End Bits:   [0x0000000017268000, 0x000000001b1e0000)

Polling page: 0x00000000005f0000

CodeCache: size=245760Kb used=1146Kb max_used=1146Kb free=244613Kb
 bounds [0x00000000029f0000, 0x0000000002c60000, 0x00000000119f0000]
 total_blobs=281 nmethods=39 adapters=164
 compilation: enabled

Compilation events (10 events):
Event: 0.208 Thread 0x000000001e2c5800   34       3       java.lang.String::<init> (82 bytes)
Event: 0.208 Thread 0x000000001e2c5800 nmethod 34 0x0000000002b0bf10 code [0x0000000002b0c0e0, 0x0000000002b0c618]
Event: 0.208 Thread 0x000000001e2c5800   35       3       java.util.Arrays::copyOfRange (63 bytes)
Event: 0.209 Thread 0x000000001e2c5800 nmethod 35 0x0000000002b0abd0 code [0x0000000002b0ade0, 0x0000000002b0b958]
Event: 0.209 Thread 0x000000001e2c5800   36       3       java.lang.StringBuilder::append (8 bytes)
Event: 0.209 Thread 0x000000001e2c5800 nmethod 36 0x0000000002b0dc90 code [0x0000000002b0de00, 0x0000000002b0dfa8]
Event: 0.212 Thread 0x000000001e2c5800   37       3       java.util.concurrent.ConcurrentHashMap::tabAt (21 bytes)
Event: 0.212 Thread 0x000000001e2c5800 nmethod 37 0x0000000002b0e410 code [0x0000000002b0e560, 0x0000000002b0e790]
Event: 0.212 Thread 0x000000001e2c5800   39       3       java.util.concurrent.ConcurrentHashMap::setTabAt (19 bytes)
Event: 0.212 Thread 0x000000001e2c5800 nmethod 39 0x0000000002b0e850 code [0x0000000002b0e9a0, 0x0000000002b0eb10]

GC Heap History (0 events):
No events

Deoptimization events (0 events):
No events

Classes redefined (0 events):
No events

Internal exceptions (2 events):
Event: 0.034 Thread 0x00000000022be800 Exception <a 'java/lang/NoSuchMethodError': Method sun.misc.Unsafe.defineClass(Ljava/lang/String;[BII)Ljava/lang/Class; name or signature does not match> (0x000000076b607cc0) thrown at [C:\jenkins\workspace\8-2-build-windows-amd64-cygwin\jdk8u251\737\hots
Event: 0.034 Thread 0x00000000022be800 Exception <a 'java/lang/NoSuchMethodError': Method sun.misc.Unsafe.prefetchRead(Ljava/lang/Object;J)V name or signature does not match> (0x000000076b607fa8) thrown at [C:\jenkins\workspace\8-2-build-windows-amd64-cygwin\jdk8u251\737\hotspot\src\share\vm\p

Events (10 events):
Event: 0.202 loading class sun/launcher/LauncherHelper$FXHelper
Event: 0.202 loading class sun/launcher/LauncherHelper$FXHelper done
Event: 0.202 loading class java/lang/Class$MethodArray
Event: 0.202 loading class java/lang/Class$MethodArray done
Event: 0.202 loading class java/lang/Void
Event: 0.202 loading class java/lang/Void done
Event: 0.203 loading class java/lang/ClassLoaderHelper
Event: 0.203 loading class java/lang/ClassLoaderHelper done
Event: 0.212 loading class java/util/Random
Event: 0.212 loading class java/util/Random done
```

在上述文件中，最重要的信息莫过于以下信息

```java
Internal exceptions (2 events):
Event: 0.034 Thread 0x00000000022be800 Exception <a 'java/lang/NoSuchMethodError': Method sun.misc.Unsafe.defineClass(Ljava/lang/String;[BII)Ljava/lang/Class; name or signature does not match> (0x000000076b607cc0) thrown at [C:\jenkins\workspace\8-2-build-windows-amd64-cygwin\jdk8u251\737\hots
Event: 0.034 Thread 0x00000000022be800 Exception <a 'java/lang/NoSuchMethodError': Method sun.misc.Unsafe.prefetchRead(Ljava/lang/Object;J)V name or signature does not match> (0x000000076b607fa8) thrown at [C:\jenkins\workspace\8-2-build-windows-amd64-cygwin\jdk8u251\737\hotspot\src\share\vm\p
```

c的源码如下

```c
JNIEXPORT void JNICALL Java_com_netposa_jni_AndroidTest_accessStaticMethod
(JNIEnv *env, jobject jobj) {
	jclass jcls = (*env)->GetObjectClass(env, jobj);
	jmethodID jmid=(*env)->GetStaticMethodID(env, jobj, "getUUID", "()Ljava/lang/String;");
	jstring js=(*env)->CallStaticObjectMethod(env, jcls, jmid);
	char *result=(*env)->GetStringUTFChars(env,js,JNI_FALSE);
	printf("result:%s\n",result);
	char fileName[100];
	sprintf(fileName,"D://%s.txt",result);
	FILE *file=fopen(fileName,"w");
	fputs("Tom and Jerry",file);
	fclose(file);
}
```

java的源码如下

```java
package com.netposa.jni;

import java.util.Random;
import java.util.UUID;

public class AndroidTest {

    public native void accessStaticMethod();

    public static void main(String[] args) {
        AndroidTest androidTest = new AndroidTest();
        androidTest.accessStaticMethod();
    }
    
    public static String getUUID() {
        return UUID.randomUUID().toString();
    }

    static {
        System.loadLibrary("Project1");
    }
}
```

报错提示NoSuchMethodError，应该是GetStaticMethodID报错(猜的)，可以试试vs+ide断点调试，由于知道是androidTest.accessStaticMethod()报错，断点打在前面，否则ide直接结束java进程，ide附加进程无法链接到java进程

# ide+vs调试

![image-20210416183207181](https://raw.githubusercontent.com/yeguoqiang/PicRemote/master/%E7%BD%91%E5%8A%9B/%E6%99%BA%E6%85%A7%E7%A4%BE%E5%8C%BA-%E5%8D%97%E6%B9%96image-20210416183207181.png)

![image-20210416183448628](https://raw.githubusercontent.com/yeguoqiang/PicRemote/master/%E7%BD%91%E5%8A%9B/%E6%99%BA%E6%85%A7%E7%A4%BE%E5%8C%BA-%E5%8D%97%E6%B9%96image-20210416183448628.png)

ide的java进程放行后，再进入到vs中进行断点调试

![image-20210416183632599](https://raw.githubusercontent.com/yeguoqiang/PicRemote/master/%E7%BD%91%E5%8A%9B/%E6%99%BA%E6%85%A7%E7%A4%BE%E5%8C%BA-%E5%8D%97%E6%B9%96image-20210416183632599.png)

再进行逐语句调试(F11)即可发现错误

![image-20210416183725145](https://raw.githubusercontent.com/yeguoqiang/PicRemote/master/%E7%BD%91%E5%8A%9B/%E6%99%BA%E6%85%A7%E7%A4%BE%E5%8C%BA-%E5%8D%97%E6%B9%96image-20210416183725145.png)

原来是参数jcls我给传成了jobj，将此处的jobj换成jcls再重新打包即可解决问题。