`kotlin`关于`by lazy`声明与`var`空变量，这两个都是延迟初始化，那到底有什么区别呢？

```
private var mProcessingDialog: LoadingDialog? = null

private val mProcessingDialog: LoadingDialog by lazy { LoadingDialog(this) }
```

下面写了两段伪代码方便理解

```java
//Java写法
private LoadingDialog mProcessingDialog;

public funA(){
    if(mProcessingDialog == null){
        mProcessingDialog = new LoadingDialog();
    }
    mProcessingDialog.setCancelable(false);
    ...
}

```

```kotlin
//kotlin写法
private val mProcessingDialog: LoadingDialog by lazy { LoadingDialog(this) }

public funA(){
    mProcessingDialog.setCancelable(false)
}
```

`kotlin`写法打log显示确实是调用的时候才完成初始化

![image-20210923192401693](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20210923192401693.png)

可以看到使用了`by lazy`后不用再做非空判断了，`let`、`run`、`also`、`with`、`apply`这几个函数使用起来也更丝滑。

在`kotlin`中如果不用`by lazy`而使用`var`空变量该怎么初始化呢，办法还是有的，依然用伪代码表示

```kotlin
mProcessingDialog?.let{
    mProcessingDialog.setCancelable(false)
}?:let{
    mProcessingDialog = mProcessingDialog()
}
```

可以看到这段kotlin代码很Java，用起来也是很别扭。
