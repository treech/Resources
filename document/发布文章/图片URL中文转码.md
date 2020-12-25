# 背景

最近碰到客户将图片存储在内网服务器里，需要在内网将图片down下来存储成Base64字符串，再调用平台接口将图片传输出来的情况，然而客户给的图片url却是中文路径，格式如下：

```java
http://122.16.92.122/中台/图片/鄂A88888.jpg
```

直接调用以下代码会报`MalformedURLException`异常

```java
URL url = new URL(imageUrl);
```

# 解决方案

需要将图片url中的中文转码才能解析

+ 注：具体转码效果可以直接将图片粘贴到浏览器中看

```java
http://122.16.92.122/中台/图片/鄂A88888.jpg

放到浏览器中转码以后的效果

http://122.16.92.122/%E4%B8%AD%E5%8F%B0/%E5%9B%BE%E7%89%87/%E9%84%82A88888.jpg
```

```java
/**
 * 判断汉字的方法,只要编码在\u4e00到\u9fa5之间的都是汉字
 *
 * @param c
 * @return
 */
public static boolean isChineseChar(char c) {
    return String.valueOf(c).matches("[\u4e00-\u9fa5]");
}
```

```java
/**
 * 处理url中的中文
 *
 * @param from
 * @return
 * @throws UnsupportedEncodingException
 */
public static String encodeUrl(String from) throws UnsupportedEncodingException {
    StringBuilder to = new StringBuilder();
    for (int i = 0; i < from.length(); i++) {
        char charAt = from.charAt(i);
        if (isChineseChar(charAt)) {
            to.append(URLEncoder.encode(String.valueOf(charAt), "UTF-8"));
        } else {
            to.append(charAt);
        }
    }
    return to.toString();
}
```