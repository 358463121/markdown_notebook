#自相关----
library(dplyr)
require(graphics)
a=acf(lh)
a$acf
#一阶自相关系数计算
n=length(lh)
lh1=lh[-n] #取第1到n-1位置
lh2=lh[-1] #取第2到n位置
sum((lh1-mean(lh))*(lh2-mean(lh)))/(n-1)/var(lh)

#block plot-----

avg<-df%>%
  group_by(lab,batch)%>%
  summarise(x=mean(y))

## Generate the block plot.
boxplot(avg$x ~ avg$lab, medlty="blank",
        ylab="Ceramic Strength",xlab="Laboratory",
        main="Batch Means for Each Laboratory")
## Add labels for the batch means.
text(avg$lab[avg$batch==1], avg$x[avg$batch==1],
     labels=avg$batch[avg$batch==1], pos=1)
text(avg$lab[avg$batch==2], avg$x[avg$batch==2],
     labels=avg$batch[avg$batch==2], pos=3)
#Bootstrap Plot----
library(boot)
## Bootstrap and CI for mean.  d is a vector of integer indexes
set.seed(0)
samplemean <- function(x, d) {
  return(mean(x[d]))                   
}
b1 = boot(y, samplemean, R=500)   
z1 = boot.ci(b1, conf=0.9, type="basic")
meanci = paste("90% CI: ", "(", round(z1$basic[4],4), ", ", 
               round(z1$basic[5],4), ")", sep="" )
## Generate bootstrap plot.
par(mfrow=c(1,2))
plot(b1$t,type="l",ylab="Mean",main=meanci)
hist(b1$t,main="Bootstrap Mean",xlab="Mean")

#boxcox----

library(MASS)
boxcox(Volume ~ log(Height) + log(Girth), data = trees,
       lambda = seq(-0.25, 0.25, length = 10))

#等高线图一个简单的例子----
x <- -6:16
contour(outer(x, x), method = "edge", vfont = c("sans serif", "plain"))

library(rgl)
kl<-function(p,q){
  tmp<-p*log(p/q)
  tmp[is.nan(tmp)]<-0
  tmp[is.infinite(tmp)]<-0
  return(tmp)
}
p=seq(0,1,0.001)
q=seq(0,1,0.001)
df=data.frame(expand.grid(p=p,q=q),z=as.vector(outer(p,q,kl)))
df<-df[df$z!=0,]
plot3d(df$p,df$q,df$z)
#t-sne------
## calling the installed package
train<- read.csv(file.choose()) ## Choose the train.csv file downloaded from the link above  
set.seed(0)
library(Rtsne)
Labels<-train$label
train$label<-as.factor(train$label)

## Executing the algorithm on curated data
tsne <- Rtsne(train[,-1], dims = 2, perplexity=30, verbose=TRUE, max_iter = 500)

## Plotting
library(ggplot2)
df=data.frame(tsne$Y,label=train$label)
ggplot(df,aes(x=X1,y=X2,color=label))+geom_point()
