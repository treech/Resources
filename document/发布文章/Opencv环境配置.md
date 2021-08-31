# Ubuntu环境配置

参考文章：

[如何在Ubuntu 18.04上安装OpenCV](https://www.myfreax.com/how-to-install-opencv-on-ubuntu-18-04/)

注：我用的虚拟机VMware+Ubuntu18(不推荐VirtualBox，各种兼容问题)

# Windows环境配置

参考文章：

[Visual Studio2019+Cmake编译配置OpenCV4.1.2+Contrib4.1.2（二）](https://blog.csdn.net/qq_27825451/article/details/103389091)

[Visual Studio 2019 cmake配置opencv开发环境](https://blog.csdn.net/EthanCo/article/details/93458374)

![image-20210831192410757](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20210831192410757.png)

![image-20210831191946651](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20210831191946651.png)

![image-20210831192031419](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20210831192031419.png)

![image-20210831192058465](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20210831192058465.png)

最终`CMakeLists.txt`配置如下：

```tex
cmake_minimum_required (VERSION 3.8)

#opencv库
include_directories("D:\\programs\\opencv\\build\\install\\include")

#Eigen库
include_directories("D:\\programs\\opencv")

link_directories("D:\\programs\\opencv\\build\\install\\x64\\vc16\\lib")

add_executable (Assingments01 "Assingments01.cpp" "Assingments01.h")

target_link_libraries(Assingments01 opencv_world453d)
```

