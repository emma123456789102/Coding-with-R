findata<- read.csv("uni-work/Financial data.csv", header= TRUE)
head(findata)
dim(findata)
summary(findata$mv)
summary(findata)

findata$totexp <- findata$ads + findata$rd
head(findata, n=2)
findata$pperatio <- findata$ppe/findata$assets
hist(x=findata$pperatio, xlab="PPE ratio", main="PPE ratio for all data", col=2,freq = FALSE)
