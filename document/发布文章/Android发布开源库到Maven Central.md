# 前言

网上有很多发布开源库到Maven Central的文章，不过参考了这些文章后我依然踩坑了。。。

# 工程结构

我希望一个AndroidSdk工程管理多个lib库，免得new一个lib库就要起new一个工程，每次都要重复发起审核的流程，太麻烦，还不方便统一管理。

![](https://github.com/treech/PicRemote/blob/master/common/%E5%B7%A5%E7%A8%8B%E7%BB%93%E6%9E%84.png?raw=true)

# Gradle脚本

**子module如`loadX`模块的`build.gradle`脚本**

```gradle
apply plugin: 'com.android.library'

def versionMajor = 0
def versionMinor = 0
def versionPatch = 1

...
...

ext {
    groupId = 'com.treech.sdk'
    description = 'Android library to show most common state templates like loading, empty, error etc.'
    gitUrl = 'https://github.com/treech/AndroidSdk'
    authorEmail = 'yeguoqiang6@outlook.com'
    license = 'MIT'
    version = "${versionMajor}.${versionMinor}.${versionPatch}"
}

apply from: '../publish.gradle'
```

**`publish.gradle`脚本**

```gradle
apply plugin: 'maven-publish'
apply plugin: 'signing'

Properties localProperties = new Properties()
localProperties.load(project.rootProject.file('local.properties').newDataInputStream())
localProperties.each { name, value ->
    project.ext[name] = value
}

def mavenUsername = localProperties.getProperty("sonatype.username")
def mavenPassword = localProperties.getProperty("sonatype.password")
def projectGroupId = project.ext.groupId
def projectArtifactId = project.getName()
def projectVersionName = project.ext.has('version') ? project.ext.getProperty('version') : project.extensions.findByName("android")["defaultConfig"].versionName
def projectDescription = project.ext.has('description') ? project.ext.getProperty('description') : null
def projectGitUrl = project.ext.has('gitUrl') ? project.ext.getProperty('gitUrl') : null
def projectLicense = project.ext.has('license') ? project.ext.getProperty('license') : null
def projectLicenseUrl = projectLicense ? "https://opensource.org/licenses/${projectLicense.toString().replace(" ", "-")} " : null

def developerAuthorId = mavenUsername
def developerAuthorName = mavenUsername
def developerAuthorEmail = project.ext.has('authorEmail') ? project.ext.getProperty('authorEmail') : null

println("${mavenUsername} ${mavenPassword} - ${projectGroupId}:${projectArtifactId}:${projectVersionName}")
println("${projectLicense} - ${projectLicenseUrl}")

if (!mavenUsername || !mavenPassword || !projectGroupId || !projectArtifactId || !projectVersionName) {
    println('错误：缺少参数')
    return
}
if (!projectDescription || !projectGitUrl || !projectLicense || !projectLicenseUrl || !developerAuthorId || !developerAuthorName || !developerAuthorEmail) {
    println('警告：缺少可选信息')
}

def isAndroidProject = project.hasProperty('android')
if (isAndroidProject) {
    println("使用Android工程方式发布")
    // Android 工程
    task androidJavadocs(type: Javadoc) {
        source = android.sourceSets.main.java.srcDirs
        //排除annotation包
        exclude '**/pom.xml'
        exclude '**/proguard_annotations.pro'
        classpath += project.files(android.getBootClasspath().join(File.pathSeparator))
    }
    task javadocsJar(type: Jar, dependsOn: androidJavadocs) {
        archiveClassifier.set("javadoc")
        from androidJavadocs.destinationDir
    }
    task sourcesJar(type: Jar) {
        archiveClassifier.set("sources")
        from android.sourceSets.main.java.srcDirs
    }
} else {
    println("使用Java工程方式发布")
    // Java 工程
    task javadocsJar(type: Jar, dependsOn: javadoc) {
        archiveClassifier.set("javadoc")
        from javadoc.destinationDir
    }
    task sourcesJar(type: Jar) {
        archiveClassifier.set("sources")
        from sourceSets.main.allJava
    }
}

tasks.withType(Javadoc).all {
    options {
        encoding "UTF-8"
        charSet 'UTF-8'
        author true
        version true
        links "http://docs.oracle.com/javase/8/docs/api"
        if (isAndroidProject) {
            linksOffline "http://d.android.com/reference", "${android.sdkDirectory}/docs/reference"
        }
        failOnError = false
    }
    enabled = false
}

artifacts {
    archives javadocsJar, sourcesJar
}

publishing {
    publications {
        aar(MavenPublication) {
            groupId = projectGroupId
            artifactId = projectArtifactId
            version = projectVersionName
            // Tell maven to prepare the generated "*.aar" file for publishing
            if (isAndroidProject){
                artifact("$buildDir/outputs/aar/${project.getName()}-${version}.aar")
            }else{
                artifact("$buildDir/libs/${project.getName()}-${version}.jar")
            }
            artifact javadocsJar
            artifact sourcesJar

            pom {
                name = projectArtifactId
                description = projectDescription
                // If your project has a dedicated site, use its URL here
                url = projectGitUrl
                licenses {
                    license {
                        name = projectLicense
                        url = projectLicenseUrl
                    }
                }
                developers {
                    developer {
                        id = developerAuthorId
                        name = developerAuthorName
                        email = developerAuthorEmail
                    }
                }
                // Version control info, if you're using GitHub, follow the format as seen here
                scm {
                    connection = "scm:git:${projectGitUrl}"
                    developerConnection = "scm:git:${projectGitUrl}"
                    url = projectGitUrl
                }
                withXml {
                    // Define this explicitly if using implementation or api configurations
                    def dependenciesNode = asNode().getAt('dependencies')[0] ?: asNode().appendNode('dependencies')

                    configurations.compile.allDependencies.each {
                        // Ensure dependencies such as fileTree are not included.
                        if (it.name != 'unspecified') {
                            println("compile $it.group:$it.name:$it.version")
                            def dependencyNode = dependenciesNode.appendNode('dependency')
                            dependencyNode.appendNode('groupId', it.group)
                            dependencyNode.appendNode('artifactId', it.name)
                            dependencyNode.appendNode('version', it.version)
                            dependencyNode.appendNode('scope', 'compile')
                        }
                    }

                    configurations.implementation.allDependencies.each {
                        // Ensure dependencies such as fileTree are not included.
                        if (it.name != 'unspecified') {
                            println("implementation $it.group:$it.name:$it.version")
                            def dependencyNode = dependenciesNode.appendNode('dependency')
                            dependencyNode.appendNode('groupId', it.group)
                            dependencyNode.appendNode('artifactId', it.name)
                            dependencyNode.appendNode('version', it.version)
                            dependencyNode.appendNode('scope', 'compile')
                        }
                    }

                    configurations.api.allDependencies.each {
                        // Ensure dependencies such as fileTree are not included.
                        if (it.name != 'unspecified') {
                            println("api $it.group:$it.name:$it.version")
                            def dependencyNode = dependenciesNode.appendNode('dependency')
                            dependencyNode.appendNode('groupId', it.group)
                            dependencyNode.appendNode('artifactId', it.name)
                            dependencyNode.appendNode('version', it.version)
                            dependencyNode.appendNode('scope', 'compile')
                        }
                    }

                    configurations.compileOnly.allDependencies.each {
                        // Ensure dependencies such as fileTree are not included.
                        if (it.name != 'unspecified') {
                            println("compileOnly $it.group:$it.name:$it.version")
                            def dependencyNode = dependenciesNode.appendNode('dependency')
                            dependencyNode.appendNode('groupId', it.group)
                            dependencyNode.appendNode('artifactId', it.name)
                            dependencyNode.appendNode('version', it.version)
                            dependencyNode.appendNode('scope', 'provided')
                        }
                    }

                    configurations.runtimeOnly.allDependencies.each {
                        // Ensure dependencies such as fileTree are not included.
                        if (it.name != 'unspecified') {
                            println("runtimeOnly $it.group:$it.name:$it.version")
                            def dependencyNode = dependenciesNode.appendNode('dependency')
                            dependencyNode.appendNode('groupId', it.group)
                            dependencyNode.appendNode('artifactId', it.name)
                            dependencyNode.appendNode('version', it.version)
                            dependencyNode.appendNode('scope', 'runtime')
                        }
                    }
                }
            }
        }
    }

    repositories {
        maven {
            name = projectArtifactId

            def releasesRepoUrl = "https://s01.oss.sonatype.org/service/local/staging/deploy/maven2/"
            def snapshotsRepoUrl = "https://s01.oss.sonatype.org/content/repositories/snapshots/"
            // You only need this if you want to publish snapshots, otherwise just set the URL
            // to the release repo directly
            url = version.endsWith('SNAPSHOT') ? snapshotsRepoUrl : releasesRepoUrl

            // The username and password we've fetched earlier
            credentials {
                username mavenUsername
                password mavenPassword
            }
        }
    }
}

signing {
    sign publishing.publications
}
```

# 问题

## 问题一：javadoc报错

![](https://github.com/treech/PicRemote/blob/master/common/%E7%94%9F%E6%88%90javadoc%E6%96%87%E6%A1%A3%E6%97%B6annotation%E5%8C%85%E6%8A%A5%E9%94%99.png?raw=true)

**解决方式一：**禁掉Javadoc

```groovy
tasks.withType(Javadoc).all {
      enabled = false //禁掉Javadoc
}
```

**解决方式二：**排除annotation包

```groovy
task androidJavadocs(type: Javadoc) {
    source = android.sourceSets.main.java.srcDirs
    //排除annotation包
    exclude '**/pom.xml'
    exclude '**/proguard_annotations.pro'
    classpath += project.files(android.getBootClasspath().join(File.pathSeparator))
}
```

## 问题二：发布gpg证书报错

![](https://github.com/treech/PicRemote/blob/master/common/%E5%8F%91%E5%B8%83gpg%E8%AF%81%E4%B9%A6%E6%8A%A5%E9%94%99.png?raw=true)

直接使用命令上传（后8位）

```cmd
gpg --keyserver keys.openpgp.org --send-keys xxxxxxxx
```

## 问题三：上传aar报错

严格来说不算问题，因为官方权限还没审批过

![](https://github.com/treech/PicRemote/blob/master/common/%E6%B2%A1%E6%9C%89%E4%B8%8A%E4%BC%A0%E6%9D%83%E9%99%90%E6%8A%A5%E9%94%99.png?raw=true)

参考文章

https://juejin.cn/post/6953598441817636900