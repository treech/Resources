# 前言

昨天刚说调用`System.exit(0)`方法就能安全退出，后经测试发现该方式只是终止当前正在运行的 Java 虚拟机，ActivityManager

发现app启动异常会尝试重新拉起app，于是就出现了"死机"或者白屏的现象。`Process.killProcess(Process.myPid())`效果也一样(你们也可以自己尝试下)

# 解决思路

其实之所以ActivityManager会尝试重新拉起app是因为activity任务栈里有activity，但是系统发现启动失败了，于是就无限重启该activity，那我们清空任务栈再调用`System.exit(0)`方法不就可以了，核心方法如下：

```java
@TargetApi(Build.VERSION_CODES.LOLLIPOP)
private void exitAPP() {
    ActivityManager activityManager = (ActivityManager) context.getApplicationContext().getSystemService(Context.ACTIVITY_SERVICE);
    List<ActivityManager.AppTask> appTaskList = activityManager.getAppTasks();
    for (ActivityManager.AppTask appTask : appTaskList) {
        appTask.finishAndRemoveTask();
    }
    System.exit(0);
}
```

这样的代码放在java层安全吗？显然是不安全的，于是我在jni层把他重写了一遍，这样的话就达到了直接在native层安全退出app的目的，废话不多说，直接上代码。

```cpp
jboolean checkValidity(JNIEnv *env, char *sha1, jobject contextObject) {
    //比较签名
    if (strcmp(sha1, app_sha1) == 0) {
        LOGD("signature verify success !!");
        return true;
    }
    LOGD("signature verify failed !!");
    
    jclass context_class = env->GetObjectClass(contextObject);
    jmethodID methodId = env->GetMethodID(context_class, "getSystemService",
                                          "(Ljava/lang/String;)Ljava/lang/Object;");
    env->DeleteLocalRef(context_class);
    jstring activity_jstring = env->NewStringUTF("activity");
    jobject activityManager = env->CallObjectMethod(contextObject, methodId, activity_jstring);

    jclass activity_manager_class = env->GetObjectClass(activityManager);
    methodId = env->GetMethodID(activity_manager_class, "getAppTasks",
                                "()Ljava/util/List;");
    env->DeleteLocalRef(activity_manager_class);
    jobject app_tasks = env->CallObjectMethod(activityManager, methodId);
    if (app_tasks == NULL) {
        LOGD("app tasks is NULL!!!");
        return NULL;
    }

    jclass list_class = env->FindClass("java/util/ArrayList");
    if (list_class == NULL) {
        LOGD("ArrayList class not found !");
        return NULL;
    }

    jmethodID list_get_methodId = env->GetMethodID(list_class, "get", "(I)Ljava/lang/Object;");
    jmethodID list_size_methodId = env->GetMethodID(list_class, "size", "()I");
    env->DeleteLocalRef(list_class);

    int size = env->CallIntMethod(app_tasks, list_size_methodId);
    for (int i = 0; i < size; i++) {
        jobject app_task = env->CallObjectMethod(app_tasks, list_get_methodId, i);
        jclass app_task_class = env->GetObjectClass(app_task);
        methodId = env->GetMethodID(app_task_class, "finishAndRemoveTask",
                                    "()V");
        env->DeleteLocalRef(app_task_class);
        env->CallVoidMethod(app_task, methodId);
    }

    jclass activityManager_class = env->FindClass("android/app/ActivityManager");
    env->DeleteLocalRef(activityManager_class);

    jclass system_class = env->FindClass("java/lang/System");
    methodId = env->GetStaticMethodID(system_class, "exit", "(I)V");
    env->CallStaticVoidMethod(system_class, methodId, 0);
    env->DeleteLocalRef(system_class);
    return false;
}
```

notes：如果你有更好的方案，请留言！



