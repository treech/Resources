# 前言

![image-20210927154513355](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20210927154513355.png)

可以看到UI给的图里这个`TextView`的颜色值为`b3ffffff`或者`B3FFFFFF`，颜色值不区分大小写

上一篇我们讲过颜色值由`ARGB`组成

> 如 #FF00CC99其中FF是透明度，00是红色值，CC是绿色值，99是蓝色值

很明显这里B3就是透明度，那B3是怎么算出来的呢？

（11*16+3）/  255 = 0.7

FF的计算

（15*16+15）/  255 = 1

# 实际使用

既然知道怎么计算，那自定义view里面该怎么用呢，有2种使用方式

资源文件`colors.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    ...
	<color name="colorB3FFFFFF">#B3FFFFFF</color>
    ...
</resources>
```

**方式一：**

```java
Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
paint.setColor(ContextCompat.getColor(getContext(), R.color.colorB3FFFFFF));
```

**方式二：**

```java
Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
paint.setColor(Color.WHITE);
paint.setAlpha((int) (255 * 0.7));
```

可能有的同学会问`paint.setAlpha`设置透明度参数为什么不是70，而是255*0.7，可以看下这个方法的实现

![image-20210927155616765](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20210927155616765.png)