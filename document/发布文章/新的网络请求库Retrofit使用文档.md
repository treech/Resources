# 前言
   为什么要用这个库？首先我们得认识到现有网络请求库存在的问题或者需要改进的地方：
   1. 日志不好看（每次想看项目流程中使用了哪些接口的时候只能通过抓包。）

   2. 接口无法统一管理（当梳理项目中用到了哪些接口时，只能通过全局搜索）

   3. 不能使用Retrofit注解简化代码流程

   4. 无法进行全局统一拦截

# 原理

既然有这些痛点，我们肯定希望有框架能解决，现在框架有了，肯定我们也得了解它的原理是不是，哈哈。。。

**step 1 利用`ManifestParser`类解析`AndroidManifest.xml`中的`ConfigModule`节点并利用反射获取对应的类** 

```java
// 用反射, 将 AndroidManifest.xml 中带有 ConfigModule 标签的 class 转成对象集合（List<ConfigModule>）
this.mModules = new ManifestParser(context).parse();
```

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.backgrounderaser.baselib">

    <application>
        <meta-data
            android:name="com.backgrounderaser.baselib.http.GlobalConfiguration"
            android:value="ConfigModule" />
    </application>
</manifest>
```

**step 2 填充自定义配置**

```java
private GlobalConfigModule getGlobalConfigModule(Context context, List<ConfigModule> modules) {
    GlobalConfigModule.Builder builder = GlobalConfigModule.builder();

    // 遍历 ConfigModule 集合, 给全局配置 GlobalConfigModule 添加参数
    for (ConfigModule module : modules) {
        module.applyOptions(context, builder);
    }

    return builder.build();
}
```

**step3 使用`LruCache`**缓存使用过的service提高性能 

```java
public <T> T create(@NonNull Class<T> serviceClass) {
    T retrofitService = (T) mRetrofitServiceCache.get(serviceClass.getCanonicalName());
    if (retrofitService == null) {
        retrofitService = retrofit.create(serviceClass);
        mRetrofitServiceCache.put(serviceClass.getCanonicalName(), retrofitService);
    }
    return retrofitService;
}
```

# 使用

**step 1 自定义配置内容（需要在自己的项目内手动实现接口并定制参数）**

```kotlin
class GlobalConfiguration : ConfigModule {
    override fun applyOptions(context: Context, builder: GlobalConfigModule.Builder) {
        //一般项目里会有两个baseUrl，用户中心的baseUrl，业务的baseUrl
        //此处建议配置业务的baseUrl如https://w.aoscdn.com/app/aimage/
        builder.baseurl(ApiConstant.BASE_URL_BUSINESS)
        //请求头统一添加token
        builder.addInterceptor(RequestHeaderInterceptor())
        //如服务器返回内容需要做翻译并在客户端显示或者服务器返回401等code码需要统一拦截跳转
        builder.globalHttpHandler(GlobalHttpHandlerImpl())
        //网络请求日志打印级别控制
        val logLevel =
            if (BuildConfig.DEBUG) RequestInterceptor.Level.ALL else RequestInterceptor.Level.NONE
        builder.logLevel(logLevel)
    }
}
```
`RequestHeaderInterceptor`示例

```kotlin
class RequestHeaderInterceptor : Interceptor {

    override fun intercept(chain: Interceptor.Chain): Response {
        val request: Request = chain.request()
        val newBuilder: Request.Builder = request.newBuilder()
        if (request.url.toString().contains(CloudConfig.MATTING_URL)) {
            val apiToken = LoginManager.getInstance().apiToken
            if (!TextUtils.isEmpty(apiToken)) {
                newBuilder.header("Authorization", "Bearer $apiToken")
            }
        }
        val internetIp = PreferenceUtil.getInstance().getString("config", "internetIp", "")
        val userAgent = PreferenceUtil.getInstance().getString("config", "userAgent", "")
        if (!TextUtils.isEmpty(internetIp)) {
            newBuilder.header("wx-real-ip", internetIp)
        }
        if (!TextUtils.isEmpty(userAgent)) {
            newBuilder.header("User-Agent", userAgent)
        }
        return chain.proceed(newBuilder.build())
    }
}
```

`GlobalHttpHandlerImpl`示例

```kotlin
class GlobalHttpHandlerImpl : GlobalHttpHandler {

    override fun onHttpResultResponse(
        httpResult: String?,
        chain: Interceptor.Chain,
        response: Response
    ): Response {
        if (response.isSuccessful) {
            // 判断token是否失效, token失效则退出登录，以匿名用户登录方式获取匿名用户登录信息
            httpResult?.apply {
                val json = JSONObject(this)
                val status = json.optString("status")
                if ("401" == status) {
                    RxBus.getDefault().post(TokenExpiredEvent())
                }
            }
        }
        return response
    }

    override fun onHttpRequestBefore(chain: Interceptor.Chain, request: Request): Request {
        return request
    }
}
```

**step 2  以下扩展类根据项目实际情况定义，库中仅提供基本示例，如果刚好满足，可以直接使用，如果不满足请自行扩展。**

```
//基本的response壳
BaseResponse

//返回响应处理
ErrorHandlerSingleObserver

//异常处理类
ExceptionHandler
```

注:`HttpCallBack`类是为了兼容`okHttputils`的旧方案遗留的，如果完全使用该新框架该类是不需要的。

## baseurl的切换

需要在application中存储用户服务的header（因为baseurl已经被业务服务抢注了，前面自定义的时候已经给了）

```java
RetrofitUrlManager.getInstance().putDomain(ApiConstant.KEY_BASE_URL_USER, ApiConstant.BASE_URL_USER);
```

用户服务

```kotlin
interface ApiConstant {

    companion object {
        //account base url
        const val BASE_URL_USER = "https://gw.aoscdn.com/base/passport/v1/"
        //business base url
        const val BASE_URL_BUSINESS = "https://w.aoscdn.com/app/aimage/"
        const val KEY_BASE_URL_USER = "base_url_user"
        const val HEADER_BASE_URL_USER = RetrofitUrlManager.DOMAIN_NAME_HEADER + KEY_BASE_URL_USER
        const val BASE_URL_MATTING_TRIM_SEGMENT = RetrofitUrlManager.IDENTIFICATION_PATH_SIZE + 2
    }
}
```

```kotlin
interface LoginService {

    /**
     * 密码登录
     */
    @Headers(
        HttpConstant.HEADER.ACCEPT_CONTENT,
        ApiConstant.HEADER_BASE_URL_USER //用户服务的header
    )
    @FormUrlEncoded
    @POST("api/login" + ApiConstant.BASE_URL_MATTING_TRIM_SEGMENT)//去掉app/aimage，segments size为2
    fun login(@FieldMap params: Map<String, String>): Single<BaseResponse<LoginResponse>>
}
```

业务服务正常使用

```kotlin
interface MattingService {

    /**
     * 获取用户信息(业务信息)
     */
    @Headers(
        HttpConstant.HEADER.ACCEPT_CONTENT,
    )
    @POST("usersInfo")
    fun getUserInfo(@Body request: MattingUserRequest): Single<BaseResponse<MattingUserInfo>>
}
```

注：如果想要完全搞清楚`RetrofitUrlManager`的使用和原理，请参考以下两篇文章

- [解决Retrofit多BaseUrl及运行时动态改变BaseUrl(一)](https://www.jianshu.com/p/2919bdb8d09a)
- [解决Retrofit多BaseUrl及运行时动态改变BaseUrl(二)](https://www.jianshu.com/p/35a8959c2f86)

## **项目中完整的使用案例：**

```java
RetrofitClient.getInstance().create(LoginService.class)
        .login(paramMap)
        .compose(HttpResponseHandler.<LoginResponse>handleResultSingle())
        .subscribeOn(Schedulers.io())
        .doOnSubscribe(new Consumer<Disposable>() {
            @Override
            public void accept(Disposable disposable) throws Exception {
                showDialog();
            }
        })
        .subscribeOn(AndroidSchedulers.mainThread())
        .observeOn(AndroidSchedulers.mainThread())
        .doFinally(new Action() {
            @Override
            public void run() throws Exception {
                dismissDialog();
            }
        })
        .compose(((RxAppCompatActivity)getLifecycleProvider()).<LoginResponse>bindToLifecycle())//可自行扩展
        .subscribe(new ErrorHandlerSingleObserver<LoginResponse>() {
            @Override
            public void onSubscribe(Disposable d) {
                super.onSubscribe(d);
            }

            @Override
            public void onSuccess(LoginResponse response) {
                super.onSuccess(response);
            }

            @Override
            public void onError(Throwable e) {
                super.onError(e);
            }
        });
```

## 混淆

```java
-keep public class * implements io.github.treech.net.config.ConfigModule
-keep class io.github.treech.net.extend.HttpResponseHandler
-keep class io.github.treech.net.extend.ErrorHandlerSingleObserver
-keep class io.github.treech.net.extend.BaseResponse
-keep class io.github.treech.net.RetrofitClient
```

# 最后

![talk-is-cheap-show-me-the-code • matwrites.com](https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcShmVnb6OU4vaxB3jQ1sI775s5p1exJWdd0QA&usqp=CAU)

Gradle依赖

```gro
project根目录build.gradle

buildscript {
    repositories {
        ...
        mavenCentral()
       ...
    }
}

allprojects {
    repositories {
        ...
        mavenCentral()
        ...
    }
}

app build.gradle

implementation "io.github.treech:net:0.0.4"
