# 前言

为什么要搭建本地的Maven环境，搞这个是要解决什么问题，归根结底一句话：如何安全的测试待发布aar。直接发布aar到google的mavenCenter()或公司私服，如果有问题再发布就又要等待审核，严重影响效率，那我有没有办法先发布到本地，等测试OK了再发布到线上。

# 发布aar到本地

## 方式一：指定自定义的maven地址

默认的路径如图所示

![image-20220610143411668](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20220610143411668.png)

如果修改本地maven地址，对应的脚本**publishLocal.gradle**文件

```groovy
apply plugin: 'maven-publish'

// 源代码一起打包
task androidSourcesJar(type: Jar) {
    // 如果有Kotlin那么就需要打入dir : getSrcDirs
    if (project.hasProperty("kotlin")) {
        from android.sourceSets.main.java.getSrcDirs()
    } else if (project.hasProperty("android")) {
        from android.sourceSets.main.java.sourceFiles
    } else {
        from sourceSets.main.allSource
    }
    classifier = 'sources'
}

afterEvaluate {
    publishing {
        publications {
            // Creates a Maven publication called "release".
            release(MavenPublication) {
                from components.release

                groupId project.ext.groupId
                artifactId project.ext.artifactId
                version project.ext.version
                artifact(androidSourcesJar) //如果aar商用，可以注释此行隐藏源码
            }
        }

        repositories {
            maven {
                url "file://D:\\code\\android\\LocalMaven"
            }
        }
    }
}
```

lib库引用方式

```groovy
ext {
    groupId = 'com.apowersoft.common'
    artifactId = 'wxtracker'
    version = "10.0.1"
}
apply from: '../publishLocal.gradle'
```

点击`uploadArchives`发布

![image-20220610154345347](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20220610154345347.png)

别的项目引用该aar方式：

```groovy
//在项目的根build.gradle中引用maven地址
buildscript {
    repositories {
        maven {url 'file://D:\\code\\android\\LocalMaven'}
    }
}
```

## 方式二：建立本地Nexus服务(更接近真实Maven私服环境)

### 环境准备

1、Nexus免费版下载

下载地址：https://www.sonatype.com/thanks/repo-oss

![image-20220610101612983](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20220610101612983.png)

PS：如果要安装为系统服务，以管理员身份执行 `nexus /install` 即可，以我的电脑环境为例

> step1 打开nexus安装路径
>
> D:\programs\Android\nexus-3.39.0-01-win64\nexus-3.39.0-01\bin
>
> step2 运行`nexus /install`安装服务
>
> step3 运行 `nexus /start` 开始服务
>
> step4 运行`nexus /status` 查看服务是否已开启
>
> ps:安装服务是为了让其开机自启和能在后台无界面运行，如果直接运行`nexus.exe /run`会出现Dos窗口，关闭Dos窗口后nexus服务就停了，如果要卸载服务需要运行命令`nexus /uninstall`

2、本地Gradle环境

项目根目录`build.gradle`配置

```groovy
buildscript {
    repositories {
        maven {
            allowInsecureProtocol = true
            url "http://maven.aoscdn.com/repository/maven-snapshots/" //Gradle 7.0以上需要使用https，如果使用http需要加此标记
            credentials {
                username deployUserName
                password deployPassword
            }
        }
		...

    }
    dependencies {
        classpath 'com.android.tools.build:gradle:7.2.1'
        ...
    }
}

allprojects {
    repositories {
        maven {
            allowInsecureProtocol = true 
            url "http://maven.aoscdn.com/repository/maven-snapshots/"
            credentials {
                username deployUserName
                password deployPassword
            }
        }
		...
    }
}

task clean(type: Delete) {
    delete rootProject.buildDir
}
```

对应的`gradle-wrapper.properties`文件配置

```groovy
distributionBase=GRADLE_USER_HOME
distributionUrl=https\://services.gradle.org/distributions/gradle-7.3.3-all.zip
distributionPath=wrapper/dists
zipStorePath=wrapper/dists
zipStoreBase=GRADLE_USER_HOME
```

`publish.gradle`脚本

```groovy
apply plugin: 'maven-publish'

// debug仓库
def SNAPSHOT_REPOSITORY_URL = 'http://localhost:8081/repository/maven-snapshots/'
// release仓库
def RELEASE_REPOSITORY_URL = 'http://localhost:8081/repository/maven-releases/'
// maven 账户
def REPOSITORY_USER_NAME = deployUserName
def REPOSITORY_USER_PSW = deployPassword

def POM_GROUP_ID = 'com.apowersoft.android.common'
def POM_ARTIFACT_ID = project.projectDir.name.toLowerCase()
if (!POM_ARTIFACT_ID.startsWith("wx")) {
    POM_ARTIFACT_ID = 'wx' + POM_ARTIFACT_ID
}
// 版本信息描述
def VERSION_NAME = project.hasProperty("COMMON_VERSION") ? COMMON_VERSION : '1.0.0-SNAPSHOT'
def POM_NAME = POM_ARTIFACT_ID.toUpperCase() + '_POM'
def POM_DESCRIPTION = POM_ARTIFACT_ID + ' moduel by wangxutech.Ldl using for base services of apowersoft.(todo 后续完善)'
def POM_SCM_URL = 'Software Configuration Management（todo 后续完善）'
def POM_DEVELOPER_NAME = 'apowersoft'
// 源代码一起打包
task androidSourcesJar(type: Jar) {
    // 如果有Kotlin那么就需要打入dir : getSrcDirs
    if (project.hasProperty("kotlin")) {
        from android.sourceSets.main.java.getSrcDirs()
    } else if (project.hasProperty("android")) {
        from android.sourceSets.main.java.sourceFiles
    } else {
        from sourceSets.main.allSource
    }
    classifier = 'sources'
}

afterEvaluate {
    publishing {
        publications {
            // Creates a Maven publication called "release".
            release(MavenPublication) {
                from components.release

                groupId = POM_GROUP_ID
                artifactId = project.hasProperty("isGoogle") && isGoogle == "true" ? POM_ARTIFACT_ID + '-google' :
                        POM_ARTIFACT_ID
                version = VERSION_NAME
                artifact(androidSourcesJar)
                println("POM_ARTIFACT_ID:$POM_ARTIFACT_ID")
                println("repositoriesUrl:${VERSION_NAME.endsWith('SNAPSHOT') ? SNAPSHOT_REPOSITORY_URL : RELEASE_REPOSITORY_URL}")
                pom {
                    name = POM_NAME
                    description = POM_DESCRIPTION
                    url = POM_SCM_URL

                    licenses {
                        license {
                            name = 'The Apache License, Version 2.0'
                            url = 'http://www.apache.org/licenses/LICENSE-2.0.txt'
                        }
                    }
                    developers {
                        developer {
                            id = POM_DEVELOPER_NAME
                            name = POM_DEVELOPER_NAME
                        }
                    }
                    scm {
                        url = POM_SCM_URL
                        connection = ""
                        developerConnection = ""
                    }
                }
            }

        }

        repositories {
            maven {
                allowInsecureProtocol = true
                url = VERSION_NAME.endsWith('SNAPSHOT') ? SNAPSHOT_REPOSITORY_URL : RELEASE_REPOSITORY_URL
                credentials {
                    username = REPOSITORY_USER_NAME
                    password = REPOSITORY_USER_PSW
                }
            }
        }
    }
}
```

lib库引用方式

```groovy
//推送Maven通用版本（release版本）
ext {
    COMMON_VERSION = '1.0.1' //通用版本号
}
apply from: '../push.gradle' //打包+推送脚本
```

点击`publishReleasePublicationToMavenRepository`发布

![](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20220610154508309.png)

别的项目引用该aar方式如下：

```groovy
//在项目的根build.gradle中引用maven地址
buildscript {
    repositories {
        maven {
            url 'http://localhost:8081/repository/maven-snapshots/'
            allowInsecureProtocol true
            credentials {
                username deployUserName
                password deployPassword
            }
        }
    }
    ...
}
```

PS：`deployUserName`和`deployPassword`建议配置在Android Studio的`gradle.properties`中，这样就不需要每个项目都配置这两个属性

![image-20220610153558375](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20220610153558375.png)

实际上也可以在`.gradle`目录下添加`init.gradle`文件，这样就可以避免每个项目都配置这个本地maven仓库，但是我自测发现此方式gradle同步速度比较慢，还是在要用的项目里配置比较好，这里只是提供一种懒人的方式。

```groovy
//build.gradle中使用
allprojects {
    repositories {
        //maven {url 'file://D:\\code\\android\\LocalMaven'}
        maven {
            url 'http://localhost:8081/repository/maven-snapshots/'
            allowInsecureProtocol true
            credentials {
                username deployUserName
                password deployPassword
            }
        }
        maven {
            url 'http://localhost:8081/repository/maven-releases/'
            allowInsecureProtocol true
            credentials {
                username deployUserName
                password deployPassword
            }
        }
        mavenLocal()
        google()
        jcenter()
        mavenCentral()
    }
}

//settings.gradle中使用
settingsEvaluated {
  it.dependencyResolutionManagement {
    repositories {
        maven {url 'http://localhost:8081/repository/maven-snapshots/'}
        mavenLocal()
        google()
        jcenter()
        mavenCentral()
    }
  }
}
```



