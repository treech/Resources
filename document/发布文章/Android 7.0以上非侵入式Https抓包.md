# 前言

  作为一名开发人员，经常会遇到抓`Https`包的场景，我简单举两个栗子：

  1、Debug包接口运行正常，提测以后打的Release包接口出现问题，此时就不太好排查了。
  2、产品给的需求不好实现，又想参考下竞品，无奈都是Https接口，无法抓包分析竞品的接口设计。

  Android 7.0以后安全机制变严格了，限制了抓`Https`包，此时我`Google`了下看看广大网友有什么路子，果不其然，办法还是有的，还很简单，这里记录下来给大家分享下。

# 测试环境

+ 测试时间
  2022.01.25

+ 电脑

  系统版本：Windows 11

+ 手机

  型号：OPPO K1

  ColorOS版本：V7.1

  Android版本：10

+ Charles

  版本：V4.6.2
  

# 准备工作

+ 安装`VirtualXposed`（安装最新版的就行，当前最新版是V0.20.3）

  下载地址：https://github.com/android-hacker/VirtualXposed/releases
  
+ 安装`Charles`（Charles有windows版和Mac版）

  下载地址：https://www.charlesproxy.com/download/
  Tips：Charles下载最好翻墙，否则下载很可能会失败（或者速度很慢）
  

# 开始测试

+ 打开Virtualxposed（相当于沙盒）添加应用并安装到沙盒内，安装完成后直接打开沙盒内的应用

![image-20220125104016606](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20220125104016606.png)

![image-20220125103905873](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20220125103905873.png)

![image-20220125104138191](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20220125104138191.png)

+ 连接Charles代理
  
  - 先配置手机wifi跟Charles保持一致
  
    ![image-20220125104533023](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20220125104533023.png)
    
    ![image-20220125104618378](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20220125104618378.png)
  
  - 下载安装CA证书
  
    手机打开浏览器输入`chls.pro/ssl`下载CA证书并安装（每个Rom厂商安装CA证书方式都不一样请自行百度安装）
  
# 验证结果

  如果你以上的操作都OK，到这一步就可以抓Https包了，下图是我的抓包结果图

![image-20220125105028301](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20220125105028301.png)