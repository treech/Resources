# 工具准备

在 Windows上搭建 Android 反编译环境主要就是三个东西：`apktool` 、`dex2jar` 、`jd-gui` 。

apktool 工具主要是将 apk 文件进行反编译，反编译之后的代码为 `smali` 代码。 dex2jar 工具主要是将 apk 文件文件转成 `jar` 文件，最后再使用 jd-gui 工具查看刚刚转成的 `jar` 文件。

apktool、dex2jar、jd-gui 这三个工具是跨平台的，不仅能在 Windows 上使用，也可以在 MAC 上使用。

它们的相应的网站地址为：

- apktool 官网和下载地址：https://ibotpeaches.github.io/Apktool/install/
- dex2jar Github 主页：https://github.com/pxb1988/dex2jar 官网和下载地址：https://bitbucket.org/pxb1988/dex2jar/downloads
- jd-guit Github 主页：https://github.com/java-decompiler/jd-gui 官网和下载地址：http://jd.benow.ca/

# 二次打包

**第一步**，通过`apktool`直接解析apk文件

```bat
apktool d source.apk
```

**第二步**，修改`smali`文件。在第一步中，会将dex转成`smali`格式的代码。对于`smali`语言不太熟悉的话，可以先反编译，找到对应的类以及方法后，再去`smali`文件夹中直接定位并修改。

**第三步**，重新打包

```bat
apktool b old -o repack_new.apk
```

**第四部**，签名。因为第三步中生成的apk包是没有签名的，无法安装到手机中，需要手动对它进行签名。`JRE`自带签名工具，地址`%jre_path%/bin`下。

```bat
jarsigner -verbose -keystore dev.keystore -storepass android -signedjar test_signed.apk -digestalg SHA1 -sigalg MD5withRSA repack_new.apk dev
```

>-verbose 参数表示：显示出签名详细信息
>-keystore 表示使用当前目录中的dev.keystore签名证书文件
>-storepass 密码：“android”，此密码是对应的dev.keystore的密码
>-signedjar test_signed.apk表示签名后生成的apk名称(二次签名后生成的apk)，repack_new.apk 表示未签名的apk Android软件(需要二次签名的apk
>-digestalg SHA1 
>-sigalg MD5withRSA：这就是必须加上的参数，如果你是jdk 1.6也不受影响
>dev表示Key别名，你的签名文件里面的alias里面的值(签名文件的别名)

# 参考:

https://glumes.com/post/android/setup-android-crack-environment/

https://ejin66.github.io/2019/01/02/android-rebuild-apk.html
