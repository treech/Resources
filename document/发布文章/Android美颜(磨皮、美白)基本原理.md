Android美颜(磨皮、美白)基本原理

# **前言**

​    前期调研过程比较顺利，在github上找到了一个开源项目，大致可以满足目前的需求（后面找到的开源的美白、磨皮算法都是基于这个），话不多说，先贴上参考的开源项目地址：

> https://github.com/siwangqishiq/ImageEditor-Android.git

​    下图为Demo演示效果（开源Demo中bug已修复）

![img](https://cz7occ727w.feishu.cn/space/api/box/stream/download/asynccode/?code=NGJjYmY3NDMxNTBjM2EwNmQ2MTkwZmZlMTY0YmQxYTRfVHFBTWtEdzg3Q3F5dDNsQXVHNnQ5aE9JR2VvV09pTlhfVG9rZW46Ym94Y25sRkk4ZlBESkx6WmI0TEhRZnNMTXZsXzE2MzE3MDM3ODM6MTYzMTcwNzM4M19WNA)

​    美中不足的是这个项目的JNI部分还是用的`ndkBuild`，现在的Native代码都是用`CMakeList`，于是改造的第一步就是把它改造成`CMakelist`编译，改造完成后上传到了`mavenCentral()`,`gradle`方式如下：

> implementation 'io.github.treech:ui:0.0.3'

美颜关键的就是以下三个算法，掌握这三个算法的原理，后面的工作就是搬砖了。

- 肤色检测算法

- 磨皮算法

- 美白算法

## 肤色检测算法

核心代码逻辑

```
void initBeautyMatrix(uint32_t *pix, int width, int height) {
    if (mImageData_rgb == NULL)
        mImageData_rgb = (uint32_t *)malloc(sizeof(uint32_t)*width * height);

    memcpy(mImageData_rgb, pix, sizeof(uint32_t) * width * height);

    if (mImageData_yuv == NULL)
        mImageData_yuv = (uint8_t *)malloc(sizeof(uint8_t) * width * height * 4);

    //rgb转YCbCr
    //参考https://www.cnblogs.com/Imageshop/archive/2013/02/14/2911309.html
    RGBToYCbCr((uint8_t *) mImageData_rgb, mImageData_yuv, width * height);

    //肤色检测
    //参考肤色检测算法_Gavinmiaoc的博客-CSDN博客_肤色检测算法
    initSkinMatrix(pix, width, height);
    
    //参考https://blog.csdn.net/oshunz/article/details/50372968
    initIntegralMatrix(width, height);
}
void initSkinMatrix(uint32_t *pix, int w, int h) {
    LOGE("start - initSkinMatrix");
    if (mSkinMatrix == NULL)
        mSkinMatrix = (uint8_t *)malloc(sizeof(uint8_t) *w *h);
    //mSkinMatrix = new uint8_t[w * h];

    for (int i = 0; i < h; i++) {
        for (int j = 0; j < w; j++) {
            int offset = i * w + j;
            ARGB RGB;
            convertIntToArgb(pix[offset], &RGB);
            if ((RGB.blue > 95 && RGB.green > 40 && RGB.red > 20 &&
                 RGB.blue - RGB.red > 15 && RGB.blue - RGB.green > 15) ||//uniform illumination
                (RGB.blue > 200 && RGB.green > 210 && RGB.red > 170 &&
                 abs(RGB.blue - RGB.red) <= 15 && RGB.blue > RGB.red &&
                 RGB.green > RGB.red))//lateral illumination
                mSkinMatrix[offset] = 255;
            else
                mSkinMatrix[offset] = 0;
        }
    }
    LOGE("end - initSkinMatrix");
}
```

## 磨皮算法

1.确定人脸的皮肤区域

2.定位人脸的杂质（痘痘，斑点，痣，肤色不均等）

3.根据定位到杂质进行填补修复或滤除

简单的总结图像处理经典三部曲

1.定位 2.检测 3.处理

核心代码逻辑

```
//根据公式对RGB通道或者将RGB通道转化为YCbCr格式单独对Y通道进行滤波
void setSmooth(uint32_t *pix, float smoothValue, int width, int height) {//磨皮操作
    if (mIntegralMatrix == NULL || mIntegralMatrixSqr == NULL || mSkinMatrix == NULL) {//预操作辅助未准备好
        LOGE("not init correctly");
        return;
    }

    LOGE("AndroidBitmap_smooth setSmooth start---- smoothValue = %f", smoothValue);
    //RGB转换到YCbCr空间
    RGBToYCbCr((uint8_t *) mImageData_rgb, mImageData_yuv, width * height);

    //对Y分量进行加性噪音的去除
    int radius = width > height ? width * 0.02 : height * 0.02;

    for (int i = 1; i < height; i++) {
        for (int j = 1; j < width; j++) {
            int offset = i * width + j;
            if (mSkinMatrix[offset] == 255) {
                int iMax = i + radius >= height - 1 ? height - 1 : i + radius;
                int jMax = j + radius >= width - 1 ? width - 1 : j + radius;
                int iMin = i - radius <= 1 ? 1 : i - radius;
                int jMin = j - radius <= 1 ? 1 : j - radius;

                int squar = (iMax - iMin + 1) * (jMax - jMin + 1);
                int i4 = iMax * width + jMax;
                int i3 = (iMin - 1) * width + (jMin - 1);
                int i2 = iMax * width + (jMin - 1);
                int i1 = (iMin - 1) * width + jMax;

                float m = (mIntegralMatrix[i4]
                           + mIntegralMatrix[i3]
                           - mIntegralMatrix[i2]
                           - mIntegralMatrix[i1]) / squar;

                float v = (mIntegralMatrixSqr[i4]
                           + mIntegralMatrixSqr[i3]
                           - mIntegralMatrixSqr[i2]
                           - mIntegralMatrixSqr[i1]) / squar - m * m;
                float k = v / (v + smoothValue);

                mImageData_yuv[offset * 3] = ceil(m - k * m + k * mImageData_yuv[offset * 3]);
            }
        }
    }
    //YCbCr空间转换回RGB空间
    YCbCrToRGB(mImageData_yuv, (uint8_t *) pix, width * height);

    LOGI("AndroidBitmap_smooth setSmooth END!----");
}
```

## 美白算法

参考博文

[对皮肤美白算法的一些研究。 - Imageshop - 博客园](https://www.cnblogs.com/imageshop/p/3843635.html)

https://xie.infoq.cn/article/2bd6ac8b2e2c23a27ae85c316

使用`logarithmic Curve`算法

![img](https://cz7occ727w.feishu.cn/space/api/box/stream/download/asynccode/?code=Y2MxNmMxZDczNjc1ZjY4ZWE0NTBlZjZlNWZiZTU2NGRfdkQ2NkpHUzJWOGNjeXVDbDExRGlIdkxJRnFnajhWbDlfVG9rZW46Ym94Y25yTnpXSWxvRjI4Wm5MZjB6MlFxNXZzXzE2MzE3MDM3ODM6MTYzMTcwNzM4M19WNA)

核心代码逻辑

```
void setWhiteSkin(uint32_t *pix, float whiteVal, int width, int height) {
    if (whiteVal >= 1.0 && whiteVal <= 10.0) { //1.0~10.0
        float a = log(whiteVal);

        for (int i = 0; i < height; i++) {
            for (int j = 0; j < width; j++) {
                int offset = i * width + j;
                ARGB RGB;
                convertIntToArgb(mImageData_rgb[offset], &RGB);
                if (a != 0) {
                    RGB.red = 255 * (log(div255(RGB.red) * (whiteVal - 1) + 1) / a);
                    RGB.green = 255 * (log(div255(RGB.green) * (whiteVal - 1) + 1) / a);
                    RGB.blue = 255 * (log(div255(RGB.blue) * (whiteVal - 1) + 1) / a);
                    if (RGB.alpha != 255) RGB.alpha = 255 * (log(div255(RGB.alpha) * (whiteVal - 1) + 1) / a);
                }
                pix[offset] = convertArgbToInt(RGB);
            }
        }
    }//end if
}
```

# 写在最后

感兴趣的可以去看下这篇文章

[Android平台Camera实时滤镜实现方法探讨(九)--磨皮算法探讨(一)_程序员扛把子的博客-CSDN博客_camera算法](https://blog.csdn.net/oshunz/article/details/50372968)