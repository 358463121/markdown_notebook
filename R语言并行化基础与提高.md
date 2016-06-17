本文将介绍R中的并行计算，并给出了一些常见的陷进以及避免它们的小技巧。
使用并行计算的原因就是因为程序运行时间太长。大部分程序都是可以并行化的，它们大部分都是[Embarrassingly parallel](https://en.wikipedia.org/wiki/Embarrassingly_parallel)。这里介绍几种可以并行化的方法：

 - Bootstrapping
 - 交叉验证(Cross-validation)
 - (Multivariate Imputation by Chained Equations ,MICE)相关介绍:[R语言中的缺失值处理](http://www.ituring.com.cn/article/214504)
 - 拟合多元回归方程

#学习`lapply`是关键
没有早点学习`lapply`是我的遗憾之一。这函数即优美又简单：它只需要一个参数（一个vector或list），和一个以该参数为输入的函数，最后返回一个列表。
```r
> lapply(1:3, function(x) c(x, x^2, x^3))
[[1]]
 [1] 1 1 1

[[2]]
 [1] 2 4 8

[[3]]
 [1] 3 9 27
```

你还可以添加额外的参数：
```r
> lapply(1:3/3, round, digits=3)
[[1]]
[1] 0.333

[[2]]
[1] 0.667

[[3]]
[1] 1
```

当每个元素都是独立地计算时，这个任务就是 [Embarrassingly parallel](https://en.wikipedia.org/wiki/Embarrassingly_parallel)的。当你学习完使用`lapply`之后，你会发现并行化你的代码就像喝水一样简单。

#`parallel`包

使用 `parallel`包，首先要初始化一个集群，这个集群的数量最好是你CPU核数-1。如果一台8核的电脑建立了数量为8的集群，那你的CPU就干不了其他事情了。所以可以这样启动一个集群：
```r
library(parallel)
 
# Calculate the number of cores
no_cores <- detectCores() - 1
 
# Initiate cluster
cl <- makeCluster(no_cores)
```
现在只需要使用并行化版本的`lapply`,`parLapply`就可以了
```r
parLapply(cl, 2:4,
          function(exponent)
            2^exponent)
[[1]]
[1] 4

[[2]]
[1] 8

[[3]]
[1] 16
```

当我们结束后，要记得关闭集群，否则你电脑的内存会始终被R占用
```r
stopCluster(cl)
```

##变量作用域

在Mac/Linux中你可以使用 `makeCluster(no_core, type="FORK")`这一选项从而当你并行运行的时候可以包含所有环境变量。
在Windows中由于使用的是Parallel Socket Cluster (PSOCK)，所以每个集群只会加载base包，所以你运行时要指定加载特定的包或变量：
```r
cl<-makeCluster(no_cores)
 
base <- 2
clusterExport(cl, "base")
parLapply(cl, 
          2:4, 
          function(exponent) 
            base^exponent)
 
stopCluster(cl)

[[1]]
[1] 4

[[2]]
[1] 8

[[3]]
[1] 16
```
注意到你需要用`clusterExport(cl, "base")`把base这一个变量加载到集群当中。如果你在函数中使用了一些其他的包就要使用`clusterEvalQ`加载进去，比如说，使用rms包，那么就用`clusterEvalQ(cl, library(rms))`。要注意的是，在clusterExport 加载某些变量后，这些变量的任何变化都会被忽略：
```r
cl<-makeCluster(no_cores)
clusterExport(cl, "base")
base <- 4
# Run
parLapply(cl, 
          2:4, 
          function(exponent) 
            base^exponent)
 
# Finish
stopCluster(cl)
[[1]]
[1] 4

[[2]]
[1] 8

[[3]]
[1] 16
```
#使用`parSapply`

如果你想程序返回一个向量或者矩阵。而不是一个列表，那么就应该使用`sapply`,他同样也有并行版本`parSapply`:
```r
> parSapply(cl, 2:4, 
          function(exponent) 
            base^exponent)
[1]  4  8 16
```
输出矩阵并显示行名和列名（因此才需要使用`as.character`）
```r
> parSapply(cl, as.character(2:4), 
          function(exponent){
            x <- as.numeric(exponent)
            c(base = base^x, self = x^x)
          })
2  3   4
base 4  8  16
self 4 27 256
```

#`foreach`包
设计`foreach`包的思想可能想要创建一个lapply和for循环的标准，初始化的过程有些不同，你需要`register`注册集群:
```r
library(foreach)
library(doParallel)

cl<-makeCluster(no_cores)
registerDoParallel(cl)
```
要记得最后要结束集群（不是用`stopCluster()`）：
```r
stopImplicitCluster()
```

foreach函数可以使用参数`.combine`控制你汇总结果的方法：

```r
> foreach(exponent = 2:4, 
        .combine = c)  %dopar%  
  base^exponent
  [1]  4  8 16
```
```r
> foreach(exponent = 2:4, 
        .combine = rbind)  %dopar%  
  base^exponent
    [,1]
result.1    4
result.2    8
result.3   16
```
```r
foreach(exponent = 2:4, 
        .combine = list,
        .multicombine = TRUE)  %dopar%  
  base^exponent
[[1]]
[1] 4

[[2]]
[1] 8

[[3]]
[1] 16
```
注意到最后list的combine方法是默认的。在这个例子中用到一个`.multicombine`参数，他可以帮助你避免嵌套列表。比如说`list(list(result.1, result.2), result.3)` :
```r
> foreach(exponent = 2:4, 
        .combine = list)  %dopar%  
  base^exponent
[[1]]
[[1]][[1]]
[1] 4

[[1]][[2]]
[1] 8


[[2]]
[1] 16
```

##变量作用域
在foreach中，变量作用域有些不同，它会自动加载本地的环境到函数中：
```r
> base <- 2
> cl<-makeCluster(2)
> registerDoParallel(cl)
> foreach(exponent = 2:4, 
        .combine = c)  %dopar%  
  base^exponent
stopCluster(cl)
 [1]  4  8 16
```
但是，对于父环境的变量则不会加载，以下这个例子就会抛出错误：
```r
test <- function (exponent) {
  foreach(exponent = 2:4, 
          .combine = c)  %dopar%  
    base^exponent
}
test()

 Error in base^exponent : task 1 failed - "object 'base' not found" 
```

为解决这个问题你可以使用`.export`这个参数而不需要使用`clusterExport`。注意的是，他可以加载最终版本的变量，在函数运行前，变量都是可以改变的：
```r
base <- 2
cl<-makeCluster(2)
registerDoParallel(cl)
 
base <- 4
test <- function (exponent) {
  foreach(exponent = 2:4, 
          .combine = c,
          .export = "base")  %dopar%  
    base^exponent
}
test()
 
stopCluster(cl)

 [1]  4  8 16

```
相似的你可以使用`.packages`参数来加载包,比如说：`.packages = c("rms", "mice")`

#使用Fork还是sock?
我在windows上做了很多分析，也习惯了使用PSOCK系统。对于使用其他系统的人要意识到这两个的区别：

 - **FORK**:"to divide in branches and go separate ways"
系统：Unix/Mac (not Windows)
环境: 所有
 - **PSOCK**:并行socket集群
系统: All (including Windows)
环境: 空

#内存控制
如果你不打算使用windows的话，建议你尝试FORK模式，它可以实现内存共享，节省你的内存。
PSOCK:
```r
library(pryr) # Used for memory analyses
cl<-makeCluster(no_cores)
clusterExport(cl, "a")
clusterEvalQ(cl, library(pryr))
parSapply(cl, X = 1:10, function(x) {address(a)}) == address(a)
[1] FALSE FALSE FALSE FALSE FALSE FALSE FALSE FALSE FALSE FALSE
```
FORK :
```r
cl<-makeCluster(no_cores, type="FORK")
parSapply(cl, X = 1:10, function(x) address(a)) == address(a)
 [1] TRUE TRUE TRUE TRUE TRUE TRUE TRUE TRUE TRUE TRUE
```
你不需要花费太多时间去配置你的环境，有趣的是，你不需要担心变量冲突:
```r
b <- 0
parSapply(cl, X = 1:10, function(x) {b <- b + 1; b})
# [1] 1 1 1 1 1 1 1 1 1 1
parSapply(cl, X = 1:10, function(x) {b <<- b + 1; b})
# [1] 1 2 3 4 5 1 2 3 4 5
b
# [1] 0
```
#调试
当你在并行环境中工作是，debug是很困难的，你不能使用`browser`/`cat`/`print`等参数来发现你的问题。
##`tryCatch`-`list`方法
使用`stop()`函数这不是一个好方法，因为当你收到一个错误信息时，很可能这个错误信息你在很久之前写的，都快忘掉了，但是当你的程序跑了1，2天后，突然弹出这个错误，就只因为这一个错误，你的程序终止了，并把你之前的做的计算全部扔掉了，这是很讨厌的。为此，你可以尝试使用`tryCatch`去捕捉那些错误，从而使得出现错误后程序还能继续执行:
```r
foreach(x=list(1, 2, "a"))  %dopar%  
{
  tryCatch({
    c(1/x, x, 2^x)
  }, error = function(e) return(paste0("The variable '", x, "'", 
                                      " caused the error: '", e, "'")))
}
[[1]]
[1] 1 1 2

[[2]]
[1] 0.5 2.0 4.0

[[3]]
[1] "The variable 'a' caused the error: 'Error in 1/x: non-numeric argument to binary operator\n'"
```
这也正是我喜欢list的原因，它可以方便的将所有相关的数据输出，而不是只输出一个错误信息。这里有一个使用`rbind`在`lapply`进行conbine的例子：
```r
`out <- lapply(1:3, function(x) c(x, 2^x, x^x))
do.call(rbind, out)
 [,1] [,2] [,3]
[1,]    1    2    1
[2,]    2    4    4
[3,]    3    8   27
```

##创建一个文件输出
当我们无法在控制台观测每个工作时，我们可以设置一个共享文件，让结果输出到文件当中，这是一个想当舒服的解决方案：
```r
cl<-makeCluster(no_cores, outfile = "debug.txt")
registerDoParallel(cl)
foreach(x=list(1, 2, "a"))  %dopar%  
{
  print(x)
}
stopCluster(cl)
starting worker pid=7392 on localhost:11411 at 00:11:21.077
starting worker pid=7276 on localhost:11411 at 00:11:21.319
starting worker pid=7576 on localhost:11411 at 00:11:21.762
[1] 2]

[1] "a"
```

##创建一个结点专用文件
一个或许更为有用的选择是创建一个结点专用的文件，如果你的数据集存在一些问题的时候，可以方便观测：
```r
cl<-makeCluster(no_cores, outfile = "debug.txt")
registerDoParallel(cl)
foreach(x=list(1, 2, "a"))  %dopar%  
{
  cat(dput(x), file = paste0("debug_file_", x, ".txt"))
} 
stopCluster(cl)
```

#`partools`包
`partools`这个包有一个[dbs()](https://matloff.wordpress.com/2015/01/03/debugging-parallel-code-with-dbs/)函数或许值得一看（使用非windows系统值得一看），他允许你联合多个终端给每个进程进行debug。

#Caching
当做一个大型计算时，我强烈推荐使用一些缓存。这或许有多个原因你想要结束计算，但是要遗憾地浪费了计算的宝贵的时间。这里有一个包可以做缓存，[R.cache](http://cran.r-project.org/web/packages/R.cache/index.html)，但是我发现自己写个函数来实现更加简单。你只需要嵌入`digest`包就可以。`digest()`函数是一个散列函数，把一个R对象输入进去可以输出一个md5值或sha1等从而得到一个唯一的key值，当你key匹配到你保存的cache中的key时，你就可以继续你的计算了，而不需要将算法重新运行，以下是一个使用例子：

```r
cacheParallel <- function(){
  vars <- 1:2
  tmp <- clusterEvalQ(cl, 
                      library(digest))
 
  parSapply(cl, vars, function(var){
    fn <- function(a) a^2
    dg <- digest(list(fn, var))
    cache_fn <- 
      sprintf("Cache_%s.Rdata", 
              dg)
    if (file.exists(cache_fn)){
      load(cache_fn)
    }else{
      var <- fn(var); 
      Sys.sleep(5)
      save(var, file = cache_fn)
    }
    return(var)
  })
}
```
这个例子很显然在第二次运行的时候并没有启动Sys.sleep，而是检测到了你的cache文件，加载了上一次计算后的cache，你就不必再计算Sys.sleep了，因为在上一次已经计算过了。

```r
system.time(out <- cacheParallel())
# user system elapsed
# 0.003 0.001 5.079
out
# [1] 1 4
system.time(out <- cacheParallel())
# user system elapsed
# 0.001 0.004 0.046
out
# [1] 1 4
 
# To clean up the files just do:
file.remove(list.files(pattern = "Cache.+\.Rdata"))
```

#载入平衡

##任务载入
需要注意的是，无论parLapply还是foreach都是一个包装(wrapper)的函数。这意味着他们不是直接执行并行计算的代码，而是依赖于其他函数实现的。在parLapply中的定义如下：
```r
parLapply <- function (cl = NULL, X, fun, ...) 
{
    cl <- defaultCluster(cl)
    do.call(c, clusterApply(cl, x = splitList(X, length(cl)), 
        fun = lapply, fun, ...), quote = TRUE)
}
```
注意到`splitList(X, length(cl))` ，他会将任务分割成多个部分，然后将他们发送到不同的集群中。如果你有很多cache或者存在一个任务比其他worker中的任务都大，那么在这个任务结束之前，其他提前结束的worker都会处于空闲状态。为了避免这一情况，你需要将你的任务尽量平均分配给每个worker。举个例子，你要计算优化神经网络的参数，这一过程你可以并行地以不同参数来训练神经网络，你应该将如下代码：
```r
# From the nnet example
parLapply(cl, c(10, 20, 30, 40, 50), function(neurons) 
  nnet(ir[samp,], targets[samp,],
       size = neurons))
```
改为：
```r
# From the nnet example
parLapply(cl, c(10, 50, 30, 40, 20), function(neurons) 
  nnet(ir[samp,], targets[samp,],
       size = neurons))
```
##内存载入
在大数据的情况下使用并行计算会很快的出现问题。因为使用并行计算会极大的消耗内存，你必须要注意不要让你的R运行内存到达内存的上限，否则这将会导致崩溃或非常缓慢。使用Forks是一个控制内存上限的一个重要方法。Fork是通过内存共享来实现，而不需要额外的内存空间，这对性能的影响是很显著的(我的系统时16G内存，8核心)：
```r
> rm(list=ls())
> library(pryr)
> library(magrittr)
> a <- matrix(1, ncol=10^4*2, nrow=10^4)
> object_size(a)
1.6 GB
> system.time(mean(a))
   user  system elapsed 
  0.338   0.000   0.337 
> system.time(mean(a + 1))
   user  system elapsed 
  0.490   0.084   0.574 
> library(parallel)
> cl <- makeCluster(4, type = "PSOCK")
> system.time(clusterExport(cl, "a"))
   user  system elapsed 
  5.253   0.544   7.289 
> system.time(parSapply(cl, 1:8, 
                        function(x) mean(a + 1)))
   user  system elapsed 
  0.008   0.008   3.365 
> stopCluster(cl); gc();
> cl <- makeCluster(4, type = "FORK")
> system.time(parSapply(cl, 1:8, 
                        function(x) mean(a + 1)))
   user  system elapsed 
  0.009   0.008   3.123 
> stopCluster(cl)
```

FORKs可以让你并行化从而不用崩溃：
```r
> cl <- makeCluster(8, type = "PSOCK")
> system.time(clusterExport(cl, "a"))
   user  system elapsed 
 10.576   1.263  15.877 
> system.time(parSapply(cl, 1:8, function(x) mean(a + 1)))
Error in checkForRemoteErrors(val) : 
  8 nodes produced errors; first error: cannot allocate vector of size 1.5 Gb
Timing stopped at: 0.004 0 0.389 
> stopCluster(cl)
> cl <- makeCluster(8, type = "FORK")
> system.time(parSapply(cl, 1:8, function(x) mean(a + 1)))
   user  system elapsed 
  0.014   0.016   3.735 
> stopCluster(cl)
```
当然，他并不能让你完全解放，如你所见，当我们创建一个中间变量时也是需要消耗内存的：
```r
> a <- matrix(1, ncol=10^4*2.1, nrow=10^4)
> cl <- makeCluster(8, type = "FORK")
> parSapply(cl, 1:8, function(x) {
+   b <- a + 1
+   mean(b)
+   })
Error in unserialize(node$con) : error reading from connection
```
#内存建议

 - 尽量使用rm()避免无用的变量
 - 尽量使用gc()释放内存。即使这在R中是自动执行的，但是当它没有及时执行，在一个并行计算的情况下，如果没有及时释放内存，那么它将不会将内存返回给操作系统，从而影响了其他worker的执行。
 - 通常并行化在大规模运算下很有用，但是，考虑到R中的并行化存在内存的初始化成本，所以考虑到内存的情况下，显然小规模的并行化可能会更有用。
 - 有时候在并行计算时，不断做缓存，当达到上限时，换回串行计算。
 - 你也可以手动的控制每个核所使用的内存数量，一个简单的方法就是：memory.limit()/memory.size() = max cores

#其他建议

 - 一个常用的CPU核数检测函数：
```r
max(1, detectCores() - 1)
```

 - 永远不要使用`set.seed()`，使用clusterSetRNGStream()来代替设置种子，如果你想重现结果。
 - 如果你有Nvidia 显卡，你可以尝试使用gputools 包进行GPU加速（警告：安装可能会很困难）
 - 当使用[mice并行化](http://stackoverflow.com/questions/24040280/parallel-computation-of-multiple-imputation-by-using-mice-r-package/27087791#27087791)时记得使用`ibind()`来合并项。


原文：[How-to go parallel in R – basics + tips](http://www.r-bloggers.com/how-to-go-parallel-in-r-basics-tips/)

>作为分享主义者(sharism)，本人所有互联网发布的图文均遵从CC版权，转载请保留作者信息并注明作者a358463121专栏:http://blog.csdn.net/a358463121，如果涉及源代码请注明GitHub地址：https://github.com/358463121/。商业使用请联系作者。