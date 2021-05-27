[TOC]

# JDK环境变量配置

## 1.0 CLASSPATH配置

```java
.;%JAVA_HOME%\lib;%JAVA_HOME%\lib\dt.jar;%JAVA_HOME%\lib\tools.jar
```
<font color=#ff4d4d>**注意:不要遗漏前面的`.;`**</font>

![image-20210508154803081](https://raw.githubusercontent.com/yeguoqiang/PicRemote/master/commonimage-20210508154803081.png)

## 2.0 JAVA_HOME配置

![image-20210508160105858](https://raw.githubusercontent.com/yeguoqiang/PicRemote/master/common/image-20210508160105858.png)

## 3.0 JDK脚本配置

编辑Path新建并配置

```java
%JAVA_HOME%\bin
```

## 4.0 验证JRE环境是否配置成功

![image-20210524153243511](https://raw.githubusercontent.com/yeguoqiang/PicRemote/master/common/image-20210524153243511.png)

# Flutter环境变量配置

## 1.0 sdk配置

![image-20210524150540849](https://raw.githubusercontent.com/yeguoqiang/PicRemote/master/common/image-20210524150540849.png)

## 2.0 离线Gradle配置(防止后期C盘爆炸)

![image-20210524151049855](https://raw.githubusercontent.com/yeguoqiang/PicRemote/master/common/image-20210524151049855.png)

## 3.0 dart sdk配置

在Path环境中添加以下配置

```java
D:\programs\flutter\bin\cache\dart-sdk\bin
```

## 4.0 flutter脚本配置

在Path环境中添加以下配置

```java
D:\programs\flutter\bin
```

## 5.0 验证环境是否配置ok

![image-20210524152704907](https://raw.githubusercontent.com/yeguoqiang/PicRemote/master/common/image-20210524152704907.png)

# Git多用户配置

参考文档：https://www.cnblogs.com/cangqinglang/p/12462272.html

注:执行ssh-add时添加私钥到git中报错Could not open a connection to your authentication agent

​	参考:https://blog.csdn.net/Dior_wjy/article/details/79035214

# MD文档配置

Typora搭配PicGo解决MD文档中的离线图片问题

PicGo下载地址:https://github.com/Molunerfinn/PicGo

github图床配置:https://picgo.github.io/PicGo-Doc/zh/guide/config.html#github%E5%9B%BE%E5%BA%8A

