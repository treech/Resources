核心内容请参考https://github.com/15915763299/HttpsCertDemo，讲的比较详细，但是不能用JDK1.8的环境去Run，否则就入坑了。

开发环境

![image-20221027210642268](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20221027210642268.png)

![image-20221027211011212](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20221027211011212.png)

**JDK1.8有bug，openssl生成的证书用keytool校验无法通过，重要的事情say三遍！！！**

**JDK1.8有bug，openssl生成的证书用keytool校验无法通过，重要的事情say三遍！！！**

**JDK1.8有bug，openssl生成的证书用keytool校验无法通过，重要的事情say三遍！！！**

根证书

```shell
openssl genrsa -out rootCA.key 2048

openssl req -new -key rootCA.key -out rootCA.csr

openssl x509 -req -in rootCA.csr -signkey rootCA.key -out rootCA.crt
	输出：subject=C = cn, ST = hubei, L = wuhan, O = Lotus, OU = IT, CN = Root, emailAddress = guoqiang.ye@lotuscars.com.cn

keytool -import -file rootCA.crt -alias rootCA -keystore rootCA.keystore -storepass 123456
```

服务端证书

```shell
openssl genrsa -out serverCA.key 2048

openssl req -new -key serverCA.key -out serverCA.csr

openssl x509 -req -CA rootCA.crt -CAkey rootCA.key -CAcreateserial -in serverCA.csr -out serverCA.crt
	输出：subject=C = cn, ST = hubei, L = wuhan, O = Lotus, OU = IT, CN = 主机IP地址, emailAddress = guoqiang.ye@lotuscars.com.cn

openssl pkcs12 -export -clcerts -in serverCA.crt -inkey serverCA.key -out serverCA.p12

keytool -list -keystore serverCA.p12
```

客户端证书

```shell
openssl genrsa -out clientCA.key 2048

openssl req -new -key clientCA.key -out clientCA.csr

openssl x509 -req -CA rootCA.crt -CAkey rootCA.key -CAcreateserial -in clientCA.csr -out clientCA.crt
	输出：subject=C = cn, ST = hubei, L = wuhan, O = Lotus, OU = IT, CN = Android, emailAddress = guoqiang.ye@lotuscars.com.cn
	
openssl pkcs12 -export -clcerts -in clientCA.crt -inkey clientCA.key -out clientCA.p12

keytool -list -keystore clientCA.p12	

keytool -importkeystore -srckeystore clientCA.p12 -srcstoretype pkcs12 -destkeystore clientCA.bks -deststoretype bks -provider org.bouncycastle.jce.provider.BouncyCastleProvider -providerpath bcprov-jdk16-1.46.jar
```

最终生成的证书

![image-20221027212414891](https://raw.githubusercontent.com/treech/PicRemote/master/common/image-20221027212414891.png)

PS：如果用电脑浏览器请求本地服务端，需要导入到电脑浏览器中的证书为serverCA.p12
