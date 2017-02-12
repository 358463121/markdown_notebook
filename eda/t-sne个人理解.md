我觉得在这里有必要提一下t-sne这个技术。想象一下你有一个包含数百个特征（变量）的数据集，对数据所属的域几乎没有什么了解。 您需要识别数据中的隐藏模式，探索和分析数据集。 

这是否让你不舒服？ 它让我的手汗水，当我第一次遇到这种情况。 你想知道如何探索一个多维数据集吗？ 这是许多数据科学家经常问的问题之一。 而t-sne可以做到这一点。目前有很多t-sne介绍的文章，比如：[从SNE到t-SNE再到LargeVis](http://bindog.github.io/blog/2016/06/04/from-sne-to-tsne-to-largevis)

和[Comprehensive Guide on t-SNE algorithm with implementation in R & Python](https://www.analyticsvidhya.com/blog/2017/01/t-sne-implementation-r-python/)。

简单地说它是一种非线性降维的算法。通过将数据降到2维或3维，然后就可以用一个散点图或3d图来表示我们这些高维的数据，而且它的效果也非常的好。

这个算法的核心思想就是，高维数据下数据间的距离，与映射到低维后数据间的距离应该是非常相似的。通过优化这个目标就可以得到非常好的效果。

那么这里就有两个要解决的问题，如何度量数据间的距离？如何度量高维和低维数据间距离的相似度？

高维数据间的距离可以这样定义：
$$
p_{j|i}=\frac{\exp (-\left \| x_i-x_j \right \|^2/2 \sigma_{i}^2)}{\sum_{k \neq i}\exp (-\left \| x_i-x_k \right \|^2/2 \sigma_{i}^2)}
$$
直观地讲，这个式子可以理解为，当给定点$x_i$后，它到其他节点$x_j$的概率。

接来下将高维数据从$x_i$映射低维的到$y_i$，低维数据间的距离是这样：
$$
q_{j|i}=\frac{\exp (-\left \| y_i-y_j \right \|^2)}{\sum_{k \neq i}\exp (-\left \| y_i-y_k \right \|^2)}
$$
然后我们的目标就是使得$p_{j|i}$与$q_{j|i}$尽可能接近，那么就可以用KL距离来表示：
$$
C=\sum_{i}KL(P_i||Q_i)=\sum_i \sum_j p_{j|i} \log \frac{p_{j|i}}{q_{j|i}}
$$


这里对距离的度量使用了一种消除了非对称性的KL距离来度量。而为了更好的区分数据的差异（因为在高维的数据，它们映射到低维后的差异不明显）那么就可以，通过假设低维空间服从t分布，高维空间服从高斯分布就可以使得高维中距离较近的点更近，高维中距离较远的点更远。具体原因可以看这里[从SNE到t-SNE再到LargeVis](http://bindog.github.io/blog/2016/06/04/from-sne-to-tsne-to-largevis)