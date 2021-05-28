# 场景

使用`ObservableList`时，`addOnListChangedCallback`可以注册回调，但是经常需要以下操作

```java
**list.clear();
**list.addAll(newList);
```

这两步操作会导致数据源变动了两次，观察者接收到了两次数据变化，adapter也会刷新两次。

```java
viewModel.currentImgs.addOnListChangedCallback(new CommonUiObservableList() {
    @Override
    public void dataChanged() {
        adapter.notifyDataSetChanged();
    }
});
```

# 分析

是怎么导致的呢，查看源码才发现端倪

```java
public class ObservableArrayList<T> extends ArrayList<T> implements ObservableList<T> {
    ...
    @Override
    public void clear() {
        int oldSize = size();
        super.clear();
        if (oldSize != 0) {
            notifyRemove(0, oldSize);
        }
    }
    ...
}
```

```java
@Override
public boolean addAll(int index, Collection<? extends T> collection) {
    boolean added = super.addAll(index, collection);
    if (added) {
        notifyAdd(index, collection.size());
    }
    return added;
}
```

可以看到调用`list.clear()`和`addAll`都去通知了观察者刷新UI

此时就有三个思路去解决界面刷新两次的问题

1. 同时维护listA和listB，真正去刷新的时候使用listB，逻辑处理的时候使用listA，也就是数据浅拷贝；

2. 利用`list.addAll(0,newList)`达到先clear再addAll的效果，随后证实该方法不行，`addAll`方法被重写后导致从索引0开始追加数据后，新数据继续追加到旧数据上了，旧的数据并没有删除；

3. 重写`clear`方法，不让它去通知观察者刷新UI；

# 解决方案

最终我采用重写`clear`方法，不让它去通知观察者(本想用kotlin的扩展方法，这样最轻量级还能避免自定义一个类出来，后来反编译apk发现koltin扩展类只是一个静态方法，只能达到新增方法的效果，不能达到覆写方法的效果，故最后只能模仿原类再自定义一个出来。)

```kotlin
/**
 * An [ObservableList] implementation using ArrayList as an implementation.
 * Just add custom method avoid refresh adapter [TObservableArrayList.clear]
 */
class TObservableArrayList<T> : ArrayList<T>(), ObservableList<T> {

    @Transient
    private var mListeners: ListChangeRegistry? = ListChangeRegistry()

    override fun addOnListChangedCallback(callback: OnListChangedCallback<out ObservableList<T>>?) {
        if (mListeners == null) {
            mListeners = ListChangeRegistry()
        }
        mListeners!!.add(callback)
    }

    override fun removeOnListChangedCallback(callback: OnListChangedCallback<out ObservableList<T>>?) {
        mListeners?.let { it.remove(callback) }
    }

    override fun add(element: T): Boolean {
        super.add(element)
        notifyAdd(size - 1, 1)
        return true
    }

    override fun add(index: Int, `object`: T) {
        super.add(index, `object`)
        notifyAdd(index, 1)
    }

    override fun addAll(collection: Collection<T>): Boolean {
        val oldSize = size
        val added = super.addAll(collection)
        if (added) {
            notifyAdd(oldSize, size - oldSize)
        }
        return added
    }

    override fun addAll(index: Int, collection: Collection<T>): Boolean {
        val added = super.addAll(index, collection)
        if (added) {
            notifyAdd(index, collection.size)
        }
        return added
    }

    /**
     * 添加自定义方法避免通知观察者
     */
    fun clear(silent: Boolean) {
        if (silent) {
            super.clear()
        } else {
            clear()
        }
    }

    override fun clear() {
        val oldSize = size
        super.clear()
        if (oldSize != 0) {
            notifyRemove(0, oldSize)
        }
    }

    override fun removeAt(index: Int): T {
        val oldValue = super.removeAt(index)
        notifyRemove(index, 1)
        return oldValue
    }

    override fun remove(element: T): Boolean {
        val index = indexOf(element)
        return if (index >= 0) {
            removeAt(index)
            true
        } else {
            false
        }
    }

    override fun set(index: Int, element: T): T {
        val oldValue = super.set(index, element)
        if (mListeners != null) {
            mListeners!!.notifyChanged(this, index, 1)
        }
        return oldValue
    }

    override fun removeRange(fromIndex: Int, toIndex: Int) {
        super.removeRange(fromIndex, toIndex)
        notifyRemove(fromIndex, toIndex - fromIndex)
    }

    private fun notifyAdd(start: Int, count: Int) {
        if (mListeners != null) {
            mListeners!!.notifyInserted(this, start, count)
        }
    }

    private fun notifyRemove(start: Int, count: Int) {
        if (mListeners != null) {
            mListeners!!.notifyRemoved(this, start, count)
        }
    }
}
```

# 最后

如果你有更好的方案请留言一起讨论。
