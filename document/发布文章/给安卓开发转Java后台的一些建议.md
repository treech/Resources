

# 前言

   如果你看到了这篇文章，说明你也跟我一样迷茫、焦虑，是的，从19年到20年安卓开发的行情是每况愈下，现在听到最多的就是培训机构都不教Android了、招聘网站上挂出来的Android岗都翻不到下一页了、Android开发的面试要求更高了...,这些还都是外部环境的变化，再看看我司最近的情况，APP开发迭代完第二个版本以后公司就再也没有新的产品开发需求，于是我这个落魄的Android开发仔只能被晾在一边，虽然每天还是按时打卡上班，但内心慌的一匹，生怕哪天被领导叫去喝茶，然后就被公司微信群移出群聊了。果不其然，4月底的时候领导找我谈话，大意就是公司没什么APP业务了，问我愿不愿意往Java方向转，这个时候我还能咋办，当然是“愿意”啦。。。

![](C:\Users\Admin\Pictures\cejg2SxVZp3MPgTeo9wpSRVTnrv6NWUs.jpg)

   年近30的我提前感受到了中年危机，万一哪天安卓开发真的没人要了咋办，想想就觉得可怕...

![](C:\Users\Admin\Pictures\G5Kew.jpg)

   现如今公司愿意在不降薪的前提下给机会我去学习Java，而且可以直接参与项目开发，不是天天去写HelloWorld,何不借此机会横向发展呢，说干就干，于是我的Android开发兼后台开发之路就此开始了。相信大家刚开始也跟我一样，转型Java不知如何上手，网上也有很多类似的转型文章，但大多人人亦云，整篇看完就如鸡汤文一样毫无营养。作为一名正统的Java选手学习路线可能是这样的（如图）

![](C:\Users\Admin\Pictures\v2-8a934d1f0b30b2290ea80931b7de5676_1440w.jpg)

**注：图片选自知乎问答 [Java 学习线路图是怎样的？]: https://www.zhihu.com/question/56110328 **

   如果你真的按照上图的学习路线去学，恐怕只能从入门到放弃了，而且公司也不可能给那么多时间你去学却没有任何产出。后台开发和Android开发都用的Java，所以在语言上，Android转后台有天然的优势，但也仅仅是语言，Android更多的是UI开发，关注点都在view上，与后台交互也是通过接口拉数据，然后进行展示，正因为如此，公司不懂APP开发的领导会经常说“APP开发不就是拉取后台数据进行展示吗，应该挺简单的啊”，每每听到这样的话我们只能一阵苦笑。

![](C:\Users\Admin\Pictures\20171122051254767.jpg)

# 学习路线

说了这么多，那么正确的学习姿势应该是什么，先说结论吧：**先学习SpringBoot、MyBatis**

可能很多人会问为什么是这两个，因为Android开发调的都是Controller层的接口(不管是GET请求还是POST请求)，而Controller层的接口用Springboot全家桶的一套就能完成，前端调后台接口请求数据，这个时候后台去请求自己的数据库或者第三方去拿数据(这是最常见的场景)，那么持久化框架Mybatis就要出场了，搞Android开发很少去写sql语句，因为GreenDao、Realm这些开源框架都已经封装好了，免去了手写sql语句的麻烦，但Java开发就需要很多单表、多表、联表的查询操作，所以JDBC这一步也必须要先学会，学会了这2个框架，就算简单的入门了(核心思想就是自上而下去学，而不是自下而上)，接下来我就详细的说这个入门的代码流程。

# 开发你的第一个SpringBoot应用程序

官方指导文档：

https://spring.io/quickstart

## 1.0 IDE新建Maven工程

![1598254263658](C:\Users\Admin\AppData\Roaming\Typora\typora-user-images\1598254263658.png)

## 2.0 手动添加SpringBoot依赖

在pom.xml中添加以下依赖


```xml
<parent>
		<groupId>org.springframework.boot</groupId>
		<artifactId>spring-boot-starter-parent</artifactId>
		<version>2.1.1.RELEASE</version>
</parent>

<dependencies>
	<dependency>
		<groupId>org.springframework.boot</groupId>
		<artifactId>spring-boot-starter-web</artifactId>
	</dependency>
</dependencies>
```

## 3.0 修改Application启动类

```java
@SpringBootApplication
@RestController
public class Application {
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}
```

## 4.0 编写Controller层

```java
@org.springframework.stereotype.Controller
public class Controller {

    @RequestMapping(value = "/hello",method = RequestMethod.GET)
    @ResponseBody
    public String hello() {
        System.out.println("调用hello接口");
        return "调用hello接口";
    }
}
```

## 5.0 启动java程序

2种启动方式见截图

![1598254871798](C:\Users\Admin\AppData\Roaming\Typora\typora-user-images\1598254871798.png)

![1598255224743](C:\Users\Admin\AppData\Roaming\Typora\typora-user-images\1598255224743.png)

**注：log打印`Tomcat started on port(s): 8080 (http) with context path ''`即表示Application成功启动**

## 6.0 测试Controller层接口

![1598255366823](C:\Users\Admin\AppData\Roaming\Typora\typora-user-images\1598255366823.png)

**注：作为一名合格的开发，请用Chrome浏览器**

至此，第一个Java程序就完成了，接下来需要接入Mybatis对数据库进行增删改查操作

## 7.0 手动添加Mybatis依赖

```xml
<dependency>
    <groupId>org.mybatis</groupId>
    <artifactId>mybatis</artifactId>
    <version>3.5.4</version>
</dependency>
<dependency>
    <groupId>org.mybatis.spring.boot</groupId>
    <artifactId>mybatis-spring-boot-starter</artifactId>
    <version>1.3.1</version>
</dependency>
```

## 8.0 添加Mybatis配置信息

```yaml
spring:
  datasource:
    driver-class-name: com.mysql.jdbc.Driver
    url: jdbc:mysql://localhost:3306/test?useUnicode=true&characterEncoding=utf8&serverTimezone=UTC
    username: root
    password: 123456

mybatis:
  type-aliases-package: com.springboot.hellworld.entity
  mapper-locations: classpath:mapper/*Mapper.xml
```

## 9.0 编写bean类

```java
public class User {
    private String name;
    private int age;

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public int getAge() {
        return age;
    }

    public void setAge(int age) {
        this.age = age;
    }

    @Override
    public String toString() {
        return "User{" +
                "name='" + name + '\'' +
                ", age=" + age +
                '}';
    }
}
```

## 10. 设计DB表

```sql
CREATE TABLE `user` (
  `name` varchar(255) DEFAULT NULL,
  `age` int DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
```

注:操作数据库一般用Navicat工具，请自行下载

## 11. 编写Dao类

```java
@Mapper
public interface UserMapper {
    List<User> queryUserList();

    void addUser(User user);
}
```

12. 编写操作数据库的sql配置文件(一般命名*mapper.xml)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE mapper
        PUBLIC "-//mybatis.org//DTD Mapper 3.0//EN"
        "http://mybatis.org/dtd/mybatis-3-mapper.dtd">
<mapper namespace="com.springboot.hellworld.mapper.UserMapper">
    <select id="queryUserList" resultType="com.springboot.hellworld.entity.User">
        select * from user
    </select>
    <insert id="addUser" parameterType="com.springboot.hellworld.entity.User">
        insert into user(name,age) values (#{name},#{age})
    </insert>
</mapper>
```

## 12. 运行Java程序并测试

![1598257569655](C:\Users\Admin\AppData\Roaming\Typora\typora-user-images\1598257569655.png)

至此，一个最简易的从APP端调用后端并获取数据的HelloWorld就完成了，是不是觉得So Easy！文末再贴上我的整个代码链接：

[https://github.com/yeguoqiang/SpringBootMybatisDemo](https://github.com/yeguoqiang/SpringBootMybatisDemo)