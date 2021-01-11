# 前言

关于海量数据用ES做搜索引擎的优点(主要与Mysql做对比)网上一搜一大把，本文不再赘述，因为我讲的全是入门版的干货，并非云云亦云的原理，下面直接进入主题，推荐三篇入门文章

1. [Elasticsearch 入门学习](https://zhuanlan.zhihu.com/p/104215274)
2. [Elasticsearch入门，这一篇就够了](https://www.cnblogs.com/sunsky303/p/9438737.html)
3. [elastic search2.3.1(3) 查询语句拼接实战termQuery ,matchQuery, boolQuery, rangeQuery, wildcardQuery](https://www.cnblogs.com/yanyuechao/p/8467602.html)

因公司项目是以Kibana可视化工具管理ES的，因此本文CRUD的操作都是以Kibana为例

# 实际使用

ES的索引类似于Mysql的数据库，每个数据库可以建立多张表

1. 每个索引有自己的 Mapping 用于定义文档的字段名和字段类型
2. 每个索引有自己的 Settings 用于定义不同的数据分布，也就是索引使用分片的情况

代码演示建立索引的步骤

## 读取配置json内容第一步

```java
@Override
public String getLocalSetting() {
    String filePath = String.format("essetting/%s-Setting.json", getIndexPrefix());
    String json = getFileContext(filePath);
    Assert.hasText(json, String.format("本地%s为空", filePath));
    return json;
}

@Override
public String getLocalMapping() {
    String filePath = String.format("essetting/%s-Mapping.json", getIndexPrefix());
    String json = getFileContext(filePath);
    Assert.hasText(json, String.format("本地%s为空", filePath));
    return json;
}
```
## 读取配置json内容第二步

```java
protected String getFileContext(String filePath) {
        try {
            ClassPathResource resource = new ClassPathResource(filePath);
            if (!resource.exists()) {
                resource = new ClassPathResource(String.format("config/%s", filePath));
                log.info("配置文件路径:{}", resource.getPath());
                if (!resource.exists()) {
                    resource = new ClassPathResource(String.format("../config/%s", filePath));
                    log.info("配置文件路径:{}", resource.getPath());
                }
            }
            log.info("配置文件路径:{}", resource.getPath());
            InputStream inputStream = resource.getInputStream();
            if (inputStream.available() > 0) {
                byte[] b = new byte[inputStream.available()];
                inputStream.read(b, 0, inputStream.available());
                inputStream.close();
                return new String(b);
            }
            return null;
        } catch (IOException e) {
            log.error("读取配置文件异常{}：", filePath, e);
        }
        return null;
    }
```

## 创建索引

```java
@Override
    public boolean createIndex(String index) {
        Assert.hasText(index, String.format("%s不能为空", index));
        CreateIndexRequest request = new CreateIndexRequest(index);//创建索引
        //创建的每个索引都可以有与之关联的特定设置。
        String setting = getLocalSetting();
        request.settings(setting, XContentType.JSON);
        String mapping = getLocalMapping();
        //创建索引时创建文档类型映射
        request.mapping(mapping, XContentType.JSON);

        //为索引设置一个别名
        request.alias(
                new Alias(String.format("%s-alias", index))
        );
        //可选参数
        request.setTimeout(TimeValue.timeValueMinutes(2));//超时,等待所有节点被确认(使用TimeValue方式)
        request.setMasterTimeout(TimeValue.timeValueMinutes(1));//连接master节点的超时时间(使用TimeValue方式)
        //request.waitForActiveShards(ActiveShardCount.DEFAULT);
        request.waitForActiveShards(ActiveShardCount.DEFAULT);//在创建索引API返回响应之前等待的活动分片副本的数量，以ActiveShardCount形式表示。
        try {
            //同步执行
            CreateIndexResponse createIndexResponse = esRestUtils.getClient().indices().create(request, RequestOptions.DEFAULT);
            return true;
        } catch (IOException e) {
            log.error("创建index异常{}：", index, e);
        }
        return false;
    }
```


![image-20210111115656191](https://raw.githubusercontent.com/yeguoqiang/PicRemote/master/%E7%BD%91%E5%8A%9B/%E6%99%BA%E6%85%A7%E7%A4%BE%E5%8C%BA-%E5%8D%97%E6%B9%96image-20210111115656191.png)

其中Setting和Mapping的json内容格式如下：

+ perimeteralarm-Setting.json

    ```json
    {
      "index": {
        "number_of_shards": "3",
        "blocks": {
          "read_only_allow_delete": "false"
        },
        "number_of_replicas": "1",
        "max_result_window": "2147483647"
      }
    }
    ```

+ perimeteralarm-Mapping.json

    ```json
    {
    	"properties": {
    		"placeCode": {
    			"type": "text",
    			"fields": {
    				"keyword": {
    					"type": "keyword",
    					"ignore_above": 256
    				}
    			}
    		},
    		"alarmType": {
    			"type": "text",
    			"index": false
    		},
    		"alarmTime": {
    			"type": "long"
    		},
    		"mrowTime": {
    			"type": "long",
    			"index": false
    		}
    	}
    }
    ```

## 索引创建成功后登录Kibana管理界面查看索引模板

![image-20210111114404627](https://raw.githubusercontent.com/yeguoqiang/PicRemote/master/%E7%BD%91%E5%8A%9B/%E6%99%BA%E6%85%A7%E7%A4%BE%E5%8C%BA-%E5%8D%97%E6%B9%96image-20210111114404627.png)

## 利用Kibana进行Restful增删改查

### 添加数据

![image-20210111121236944](https://raw.githubusercontent.com/yeguoqiang/PicRemote/master/%E7%BD%91%E5%8A%9B/%E6%99%BA%E6%85%A7%E7%A4%BE%E5%8C%BA-%E5%8D%97%E6%B9%96image-20210111121236944.png)

### 查询数据

![image-20210111122318339](https://raw.githubusercontent.com/yeguoqiang/PicRemote/master/%E7%BD%91%E5%8A%9B/%E6%99%BA%E6%85%A7%E7%A4%BE%E5%8C%BA-%E5%8D%97%E6%B9%96image-20210111122318339.png)

### 查询所有

![image-20210111122413348](https://raw.githubusercontent.com/yeguoqiang/PicRemote/master/%E7%BD%91%E5%8A%9B/%E6%99%BA%E6%85%A7%E7%A4%BE%E5%8C%BA-%E5%8D%97%E6%B9%96image-20210111122413348.png)

### 删除数据

![image-20210111122522135](https://raw.githubusercontent.com/yeguoqiang/PicRemote/master/%E7%BD%91%E5%8A%9B/%E6%99%BA%E6%85%A7%E7%A4%BE%E5%8C%BA-%E5%8D%97%E6%B9%96image-20210111122522135.png)

## 实际项目代码

```java
private BoolQueryBuilder buildQueryBuilder(PerimeterAlarmDataSearchModel paSearchModel) {
        BoolQueryBuilder boolQueryBuilder = QueryBuilders.boolQuery();
        BoolQueryBuilder mustQueryBuilder = QueryBuilders.boolQuery();
        if (StringUtils.isNotBlank(paSearchModel.getVillageCode())) {
            mustQueryBuilder.must(QueryBuilders.termsQuery("placeCode.keyword", paSearchModel.getVillageCode().split(",")));
        }
        if (StringUtils.isNotBlank(paSearchModel.getCameraId())) {
            mustQueryBuilder.must(QueryBuilders.termsQuery("deviceId.keyword", paSearchModel.getCameraId().split(",")));
        }
        if (paSearchModel.getStartTime() != null) {
            mustQueryBuilder.must(QueryBuilders.rangeQuery("alarmTime").gte(paSearchModel.getStartTime()));
        }
        if (paSearchModel.getEndTime() != null) {
            mustQueryBuilder.must(QueryBuilders.rangeQuery("alarmTime").lte(paSearchModel.getEndTime()));
        }
        if (StringUtils.isNotBlank(paSearchModel.getText())) {
            boolQueryBuilder
                    .should(QueryBuilders.boolQuery()
                            .must(QueryBuilders.wildcardQuery("deviceName.keyword", "*" + paSearchModel.getText() + "*"))
                            .must(mustQueryBuilder))
                    .should(QueryBuilders.boolQuery()
                            .must(QueryBuilders.wildcardQuery("villageName.keyword", "*" + paSearchModel.getText() + "*"))
                            .must(mustQueryBuilder));
        } else {
            boolQueryBuilder.must(mustQueryBuilder);
        }
        return boolQueryBuilder;
    }
```

# 总结

既然ES的定位是万亿级数据量，肯定是值得去学习的，暂且写一篇入门文章，应该还有后续，哈哈。