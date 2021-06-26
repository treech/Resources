# 背景

平时我们经常遇到UI给我们的设计效果图如下：

![image-20210626065524226](https://raw.githubusercontent.com/yeguoqiang/PicRemote/master/common/image-20210626065524226.png)

![image-20210626065652700](https://raw.githubusercontent.com/yeguoqiang/PicRemote/master/common/image-20210626065652700.png)

# 实现Item 的 divider

作为开发第一反应是需要用到`RecyclerView`，可以看到这个`RecyclerView`整体距顶/距底也即`MarginTop/MarginBottom`为24dp，整体距左/距右也即`MarginLeft/MarginRight`为36dp，子item内部`paddingTop/PaddingBottom`为8dp，内部`paddingLeft/PaddingRight`为8dp，于是就有两个思路

**1、**设置`Recyclerview`的`margin`和子item的`padding`就可以了，具体实现就是设置`RecyclerView`的`MarginTop/MarginBottom`为16dp，子item内部`paddingTop/PaddingBottom`为8dp，设置`RecyclerView`的`MarginLeft/MarginRight`为28dp，子item内部`paddingLeft/PaddingRight`为8dp

**注：顶部第一排的子item有个PaddingTop+RecyclerView的MarginTop也即8dp+16dp=24dp可以实现视觉上的`RecyclerView`整体距顶/距底24dp**，左右两边同理，但是这有个问题，如果UI下次设计底部不留这个Margin，这个方案就不行了。

**2、**使用 `RecyclerView.ItemDecoration`，这个item的divider是需要`GridLayoutManager`类去实现的，平时我们自定义`ItemDecoration`也主要实现其中的 `onDraw `和` getItemOffsets `方法

```java
public class SpacesItemDecoration extends RecyclerView.ItemDecoration {
    private int leftRight;
    private int topBottom;

    public SpacesItemDecoration(int leftRight, int topBottom) {
        this.leftRight = leftRight;
        this.topBottom = topBottom;
    }

    @Override
    public void onDraw(Canvas c, RecyclerView parent, RecyclerView.State state) {
      super.onDraw(c, parent, state);
    }

    @Override
    public void getItemOffsets(Rect outRect, View view, RecyclerView parent, RecyclerView.State state) {
    
    }
}
```

`getItemOffsets `主要是确定 divider 的范围，而` onDraw `是对 divider 的具体实现（主要是画分割线）

# 最终方案

**采用重写` getItemOffsets `方法的方式**，核心计算方式如下图所示：

![image-20210626085511903](https://raw.githubusercontent.com/yeguoqiang/PicRemote/master/common/image-20210626085511903.png)

写的很清晰明了，需要自己去理解下，最终用代码实现的效果如下：

```java
public class GridLayoutItemDecoration extends RecyclerView.ItemDecoration {

    /**
     * 每个item与左边以及右边的间距(如果需要设置每排item间距全部一样，需要mLeftRight=mLeftRightPadding)
     */
    private int mLeftRight;
    /**
     * 每个item与顶部以及顶部的间距(如果单独设置了mLeftRightPadding、mTopBottomPadding则此属性仅对item与item之间的间距生效)
     */
    private int mTopBottom;
    /**
     * 整个RecyclerView与左边以及右边的间距
     */
    private int mLeftRightPadding;
    /**
     * 整个RecyclerView与顶部以及底部的间距
     */
    private int mTopBottomPadding;

    /**
     * 如果需要设置水平均分每个item间距，请使用此方法
     *
     * @param leftRight
     * @param topBottom
     */
    public GridLayoutItemDecoration(@Dimension(unit = Dimension.DP) int leftRight,
                                    @Dimension(unit = Dimension.DP) int topBottom) {
        this(leftRight, topBottom, leftRight, topBottom);
    }

    /**
     * 如果整个recyclerview与上下左右的间距跟item与item之间的间距大小不一致请使用此方法
     *
     * @param leftRight
     * @param topBottom
     * @param leftRightPadding
     * @param topBottomPadding
     */
    public GridLayoutItemDecoration(@Dimension(unit = Dimension.DP) int leftRight,
                                    @Dimension(unit = Dimension.DP) int topBottom,
                                    @Dimension(unit = Dimension.DP) int leftRightPadding,
                                    @Dimension(unit = Dimension.DP) int topBottomPadding) {
        this.mLeftRight = leftRight;
        this.mTopBottom = topBottom;
        this.mLeftRightPadding = leftRightPadding;
        this.mTopBottomPadding = topBottomPadding;
    }

    @Override
    public void getItemOffsets(@NonNull @NotNull Rect outRect, @NonNull @NotNull View view, @NonNull @NotNull RecyclerView parent, @NonNull @NotNull RecyclerView.State state) {
        GridLayoutManager layoutManager = (GridLayoutManager) parent.getLayoutManager();
        final GridLayoutManager.LayoutParams lp = (GridLayoutManager.LayoutParams) view.getLayoutParams();
        final int position = parent.getChildAdapterPosition(view);
        final int spanCount = layoutManager.getSpanCount();
        int maxSpanGroupIndex = layoutManager.getSpanSizeLookup()
                .getSpanGroupIndex(parent.getAdapter().getItemCount() - 1, spanCount);//最后一行
        GridLayoutManager.SpanSizeLookup spanSizeLookup = layoutManager.getSpanSizeLookup();
        int spanGroupIndex = spanSizeLookup.getSpanGroupIndex(position, spanCount);//每一排的index(排数)
        int spanSize = lp.getSpanSize();
        if (layoutManager.getOrientation() == RecyclerView.VERTICAL) {
            //判断是否在第一排
            if (spanGroupIndex == 0) {//第一排的需要上面
                outRect.top = mTopBottomPadding;
            } else if (spanGroupIndex == maxSpanGroupIndex) {//最后一排需要下面
                outRect.bottom = mTopBottomPadding;
            }
            outRect.bottom = mTopBottom;
            //这里忽略和合并项的问题，只考虑占满和单一的问题
            if (spanSize == spanCount) {//占满
                outRect.left = mLeftRightPadding;
                outRect.right = mLeftRightPadding;
            } else {
                outRect.left = (mLeftRight * lp.getSpanIndex() + (spanCount - lp.getSpanIndex() * 2) * mLeftRightPadding) / spanCount;
                outRect.right = (mLeftRightPadding * 2 + mLeftRight * (spanCount - 1)) / spanCount - outRect.left;
            }
        } else {
            //判断是否在第一排
            if (spanGroupIndex == 0) {//第一排的需要left
                outRect.left = mLeftRightPadding;
            }else if (spanGroupIndex == maxSpanGroupIndex) {//最后一排需要right
                outRect.right = mLeftRightPadding;
            }
            outRect.right = mLeftRight;
            //这里忽略和合并项的问题，只考虑占满和单一的问题
            if (spanSize == spanCount) {//占满
                outRect.top = mTopBottomPadding;
                outRect.bottom = mTopBottomPadding;
            } else {
                outRect.top = (mTopBottom * lp.getSpanIndex() + (spanCount - lp.getSpanIndex() * 2) * mTopBottomPadding) / spanCount;
                outRect.bottom = (mTopBottomPadding * 2 + mTopBottom * (spanCount - 1)) / spanCount - outRect.top;
            }
        }
    }
}
```

**注意：**此方式需要配合`RecyclerView`的布局为`match_parent`并且子布局宽高为`wrap_content`一起使用，也即无需设置两者的margin和padding

```xml
<androidx.recyclerview.widget.RecyclerView
    android:layout_width="match_parent"
    android:layout_height="match_parent"
    app:layoutManager="androidx.recyclerview.widget.GridLayoutManager"
    android:orientation="vertical"
    app:spanCount="4"/>
```