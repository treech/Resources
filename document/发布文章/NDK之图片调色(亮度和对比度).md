# 核心代码比较

Java代码解析

```java
public class JavaUtil {

    //亮度
    public static float brightnessRatio = 0.2f;

    //对比度
    public static float contrastRatio = 0.2f;

    public static Bitmap beauty(Bitmap bitmap) {
        int width = bitmap.getWidth();
        int height = bitmap.getHeight();
        Bitmap result = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
        int brightness = (int) (255 * brightnessRatio);
        int contrast = (int) (1.0f + contrastRatio);
        int a, r, g, b;
        for (int i = 0; i < width; i++) {
            for (int j = 0; j < height; j++) {
                //获取ARGB值
                int color = bitmap.getPixel(i, j);
                //获取颜色值
                a = Color.alpha(color);
                r = Color.red(color);
                g = Color.green(color);
                b = Color.blue(color);

                //亮度
                int ri = r + brightness;
                int gi = g + brightness;
                int bi = b + brightness;

                //边缘检测
                r = ri > 255 ? 255 : (ri < 0 ? 0 : ri);
                g = gi > 255 ? 255 : (gi < 0 ? 0 : gi);
                b = bi > 255 ? 255 : (bi < 0 ? 0 : bi);

                //对比度
                ri = r + 128;
                gi = g + 128;
                bi = b + 128;

                ri = (int) (ri * contrast);
                gi = (int) (gi * contrast);
                bi = (int) (bi * contrast);

                ri = ri - 128;
                gi = gi - 128;
                bi = bi - 128;

                //边缘检测
                r = ri > 255 ? 255 : (ri < 0 ? 0 : ri);
                g = gi > 255 ? 255 : (gi < 0 ? 0 : gi);
                b = bi > 255 ? 255 : (bi < 0 ? 0 : bi);
                result.setPixel(i, j, Color.argb(a, r, g, b));
            }
        }
        return result;
    }
}
```

C代码解析

```c
#include <jni.h>
#include <string>

extern "C" JNIEXPORT jintArray JNICALL Java_com_treech_imagebeauty_NativeUtil_beauty
        (JNIEnv *env, jclass jcls, jintArray buffer, jint width, jint height) {
    jint *source = (env)->GetIntArrayElements(buffer, NULL);
    float brightnessRatio = 0.2f;
    float contrastRatio = 0.2f;
    int brightness = (int) (255 * brightnessRatio);
    int contrast = (int) (1.0f + contrastRatio);
    int newSize = width * height;
    int a, r, g, b;
    for (int i = 0; i < width; i++) {
        for (int j = 0; j < height; j++) {
            int color = source[i * height + j];
            a = color >> 24;
            r = (color >> 16) & 0xFF;
            g = (color >> 8) & 0xFF;
            b = color & 0xFF;

            //亮度
            int ri = r + brightness;
            int gi = g + brightness;
            int bi = b + brightness;

            //边缘检测
            r = ri > 255 ? 255 : (ri < 0 ? 0 : ri);
            g = gi > 255 ? 255 : (gi < 0 ? 0 : gi);
            b = bi > 255 ? 255 : (bi < 0 ? 0 : bi);

            //对比度
            ri = r + 128;
            gi = g + 128;
            bi = b + 128;

            ri = (int) (ri * contrast);
            gi = (int) (gi * contrast);
            bi = (int) (bi * contrast);

            ri = ri - 128;
            gi = gi - 128;
            bi = bi - 128;

            //边缘检测
            r = ri > 255 ? 255 : (ri < 0 ? 0 : ri);
            g = gi > 255 ? 255 : (gi < 0 ? 0 : gi);
            b = bi > 255 ? 255 : (bi < 0 ? 0 : bi);
            source[j * width + i] = (a << 24) | (r << 16) | (g << 8) | b;
        }
    }
    jintArray result = (env)->NewIntArray(newSize);
    (env)->SetIntArrayRegion(result, 0, newSize, source);
    (env)->ReleaseIntArrayElements(buffer, source, 0);
    return result;
}
```

每个像素index的计算

![image-20210905223258393](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20210905223258393.png)

# 性能比较

相同的算法使用NDK用时300-400ms，Java代码调用耗时2000ms左右，这就可以解释为什么算法较复杂的都需要放在NDK层实现，效率提高了不是一星半点。

# 写在最后

完整代码地址：https://github.com/treech/ImageBeauty

