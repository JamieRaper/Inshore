##########  This is the main script for running the models, getting the catch/exploitation estimates, making the decision table and running the 
##########  most recent prediction evaluation year.
###    DK 2018 overhaul to align with BoF script format and minimizes manual entry...
###........................................###

# The Feb 2018 revision did the following to this file........................
# 1:  Removed the previous years model runs, the results of model runs from 2014-2017 are now stored in the folder ... \SPA29\Model_results_2014_2016\.  This was
#     done because there was no consistent file structure before this time for how the model results were stored (if they were even retained).  Now all model results for these
#     years should be easily located.  From 2017 onwards the model results from the previous year are loaded from where they were saved last year
# 2:  Defined a set number of iterations for all the model MCMC runs stored above, niter was 300,000, nburnin was 50,000, nchains = 3, and nthin = 5.  
# 3:  While niter and other MCMC parameters can be changed, unless the model structure changes I don't see any reason to use anything other than these values as the 
#     model appears to converge, we do need to look more closely at convergence and our posteriors v.s. priors (but I haven't done much here)
# 4:  Made a SFA29.inits function below, this is helpful  useful when running a bunch of different years,
# 5:  Using variable NY rather than entering the number of years in all places required.
# 6:  Created/organized some very basic file structure for the results from this based on what we had in place.  
#     Note that due to historical strangeness model output with a 2017 tag are used in the 2018 assessment, so you'll see all the correct model
#     ouput will be tagged with a 2017 but placed in the 2018 folder (and so on and so forth...)
# 7:  Prediction evaluations have been overhauled, you should now only need to run these for the current year, all previous years PE model results are stored
#     there is a little loop to grab all of these and stitch them together at the end of the function.
# 8:  The model input data are stored in the files.../SFA29/year/model/SFA29X_ModelData.xlsx, these still need to be updated manually each year, which is clearly
#      less than ideal, next big step in cleaning up SFA29 scripts would be to automate the creation of this file.

# JS Updated in Jan 2022 to write out files automatically and in line with new assessment folder structure; input diagnostics for model runs 

options(stringsAsFactors = FALSE)
#required packages
library(ggplot2)
library(lattice)
library(R2WinBUGS)
library(SSModeltest) #v 1.0-5;  this is the SSModel package used in BoF, modified to accomodate the SFA29 models.
library(lubridate)
library(readxl)
library(tidyverse)
#library(SSModel) #v 1.0-5
source("Y:/Inshore/SFA29/2017/model/SFA29model9-2015.R") #contains the SFA29model model (BUGS) 


#DEFINE:
path.directory <- "Y:/Inshore/SFA29/"
assessmentyear <- 2025 #year in which you are conducting the assessment 
surveyyear <- 2024  #last year of survey data you are using, e.g. if max year of survey is survey from summer 2019, this would be 2019 
area <- "SFA29B"  

#last year survey in model 
yrs <- 2001:surveyyear  
#yrs <- 2001:2020  

# Let's be consistent with our MCMC!
niter = 300000
nchains = 3
nburnin= 50000
nthin = 10 #note increased to try and reduce autocorrelation - may not be the same for other subareas 

years <- 2001:surveyyear# The years for the model.
NY <- length(years)
# A function to autmatically generate the initial values, this still sucks as nchains needs to be 3 here...

# A function to autmatically generate the initial values, this still sucks as nchains needs to be 3 here...
SFA29.inits <- function(N)
{
  list(list(q = 0.1, log.Kh = c(1.1, 6.1, 1.1), sigma = c(1,0.1, 0.1), Ph = cbind(runif(N,0.01,0.99),runif(N,0.01,0.99),runif(N,0.01,0.99))),
       list( q = 0.4, log.Kh = c(4.3, 1.3,7.3), sigma = c(0.5, 1, 0.1), Ph = cbind(runif(N,0.01,0.99),runif(N,0.01,0.99),runif(N,0.01,0.99))),
       list( q = 0.2, log.Kh = c(2.2, 1.8,4), sigma = c(0.1,0.1, 0.4), Ph = cbind(runif(N,0.01,0.99),runif(N,0.01,0.99),runif(N,0.01,0.99))))
}
# Here is a little function to extract the data from the "model data file" and get is set up for model...
dat.wrap <- function(dat,col="Ih",yrs,strata)
{
  num.strata <- length(strata)
  res <- matrix(nrow=length(yrs),ncol=num.strata)
  for(i in 1:num.strata) res[,i] <- unlist(dat[dat$Strata==strata[i] & dat$Year %in% yrs,col])
  res[which(res == 0)] <- 0.0001 # For these data any 0's need to be positive...
  return(res)
}

#priors (same values used for all subareas)
SFA29.priors<-list(r.a=0,r.b=0.1,m.a=-1.9,m.b=0.5,S.a=0.1,S.b=0.99,logKh.a=1,logKh.b=10,q.a=10.64,q.b=9.36,sigma.a=0,sigma.b=10)

#model parameters (same values used for all subareas)
#SFA29.parms <- c("Bh","BBh","Ph","Rh" ,"Kh" , "m" , "sigma","q" , "S" , "log.Kh","Catch.t","CPUE.sub")
SFA29.parms <- c("Bh","BBh","Ph","Rh" ,"Kh" , "m" , "sigma","q" , "S" , "log.Kh","Catch.t","CPUE.sub", "resid.p", "sresid.p")


# the relationship between fishing intensity and density; unique to subarea
e.parms.29B <- c(4.431782e-04, 1.740606e-03, 4.411668e-03, 2.332540e-01, 8.747000e+01 )

# The area of each strata in B, I think...
B.areas <- c(248.8925, 244.3425, 52.3925)
num.areas <- length(B.areas) # The number of strata in the area...

# Now bring in the model data...
mod.dat <- read.csv(paste0(path.directory,assessmentyear,"/Assessment/Data/Model/SFA29B/SFA29B_ModelData.",surveyyear,".csv"))  
#mod.dat <- read.csv(paste0(path.directory,assessmentyear,"/Assessment/Data/Model/SFA29B/SFA29B_ModelData.2021.csv"))  
#mod.dat <- read.csv(paste0(path.directory,assessmentyear,"/Assessment/Data/Model/SFA29B/test_min_gh_for2020/SFA29B_ModelData.2021.csv"))  
#mod.dat <- read.csv(paste0(path.directory,assessmentyear,"/Assessment/Data/Model/SFA29B/test_max_gh_for2020/SFA29B_ModelData.2021.csv"))  
#mod.dat <- read.csv(paste0(path.directory,assessmentyear,"/Assessment/Data/Model/SFA29B/ModelRun_to2020/SFA29B_ModelData.2020.csv"))  

View(mod.dat)

#define strata for area 
strata <- c("low","med","high")

# Get the growth data, this will be in the order for the "strata" is above, needs to be ordered low,  medium,  high 
growth.paras <- mod.dat %>% filter(Year == max(yrs) & Strata %in% strata) %>% select(Strata, gh) %>% arrange(match(Strata, c("low", "med", "high"))) %>% select(gh)
growth.paras 

###
#  ---- Current year update -----
###
yrs <- 2001:surveyyear
NY <- length(yrs)
# Get the initial values
inits.29B <- SFA29.inits(NY)

SFA29Bdata <- list(
  N = NY,
  H = num.areas,
  Area = B.areas,
  N1 = 1,
  Catch.actual = mod.dat$Catch.actual[!is.na(mod.dat$Catch.actual)], # First year won't have information
  Ih = dat.wrap(mod.dat,"Ih",yrs,strata),  ##error with dat.wrap on this line 
  rh = dat.wrap(mod.dat,"rh",yrs,strata),
  clappers = dat.wrap(mod.dat,"clappers",yrs,strata),
  L = dat.wrap(mod.dat,"L",yrs,strata),
  gh = dat.wrap(mod.dat,"gh",yrs,strata),
  wk = mod.dat$wk[mod.dat$Year %in% yrs & !is.na(mod.dat$wk)], # Just removing trailing NA's that are in the data
  obs.nu = dat.wrap(mod.dat,"obs.nu",yrs,strata),
  obs.tau = dat.wrap(mod.dat,"obs.tau",yrs,strata),
  obs.phi = dat.wrap(mod.dat,"obs.phi",yrs,strata),
  VMS.Effort = dat.wrap(mod.dat,"VMSEffort",yrs[-length(yrs)],strata))


### run model
B.mod.res <- SSModel(SFA29Bdata,SFA29.priors,inits.29B,parms=SFA29.parms,model.file=SFA29model,Years=yrs,
                    nchains=nchains,niter=niter,nburnin=nburnin,nthin=nthin,Area="SFA29W",e.parms=e.parms.29B,debug=F)
#load(paste0(path.directory,assessmentyear,"/Assessment/Data/Model/SFA29B/SFA29B.",surveyyear,".RData"))
mod.res <- B.mod.res
# You want this to be a minimum of 400, if less than this you should increase your chain length
min.neff <- min(mod.res$summary[,9])
if(min.neff < 400) print(paste("Hold up sport!! Minimum n.eff is",min.neff," You should re-run the model and increase nchains until this is at least 400")) 
if(min.neff >= 400) print(paste("Good modelling friend, your minimum n.eff is",min.neff)) 
# same idea for Rhat, here we want to make sure Rhat is < 1.05 which suggests the chains are well mixed.
Rhat <- signif(max(mod.res$summary[,8]),digits=4)
if(Rhat > 1.05) print(paste("Hold up mes amis!! You have an Rhat of ",Rhat," You should re-run the model and increase nchains until this is below 1.05")) 
if(Rhat <= 1.05) print(paste("Good modelling friend, your max Rhat is",Rhat)) 

#save model 
save(B.mod.res,file=paste0(file = paste0(path.directory,assessmentyear,"/Assessment/Data/Model/SFA29B/SFA29B.",surveyyear,".RData"))) 
#save(B.mod.res,file=paste0(file = paste0(path.directory,assessmentyear,"/Assessment/Data/Model/SFA29B/test_min_gh_for2020/SFA29B.",surveyyear,".RData")))
#save(B.mod.res,file=paste0(file = paste0(path.directory,assessmentyear,"/Assessment/Data/Model/SFA29B/test_max_gh_for2020/SFA29B.",surveyyear,".RData"))) 
#save(B.mod.res,file=paste0(file = paste0(path.directory,assessmentyear,"/Assessment/Data/Model/SFA29B/ModelRun_to2020/SFA29B.2020.RData"))) 


write.csv(B.mod.res$summary,file=paste0(file = paste0(path.directory,assessmentyear,"/Assessment/Data/Model/SFA29B/SFA29.B.mod.res.summary.",surveyyear,".csv"))) 
#write.csv(B.mod.res$summary,file=paste0(file = paste0(path.directory,assessmentyear,"/Assessment/Data/Model/SFA29B/test_min_gh_for2020/SFA29.B.mod.res.summary.",surveyyear,".csv"))) 
#write.csv(B.mod.res$summary,file=paste0(file = paste0(path.directory,assessmentyear,"/Assessment/Data/Model/SFA29B/test_max_gh_for2020/SFA29.B.mod.res.summary.",surveyyear,".csv"))) 
#write.csv(B.mod.res$summary,file=paste0(file = paste0(path.directory,assessmentyear,"/Assessment/Data/Model/SFA29B/ModelRun_to2020/SFA29.B.mod.res.summary.2020.csv"))) 


# Get the catch and biomass so that we can figure out the explotation rate from the model for each habitat
# The catch and CPUE data needs to fill in the years for which there was no catch....
# The dataframe with the results.  Note this is set up as Catch(2015) / (Catch2015 + Biomass2015)
# This isn't entirely correct since we pull catch from an intermediate biomass, but it's pretty good!
# Get the catch and biomass so that we can figure out the explotation rate from the model for each habitat

##
## High Strata 
##
#Catch 
high.cat <- apply(B.mod.res$sims.matrix[,grep("Catch.t",colnames(B.mod.res$sims.matrix))],2,median)
high.cat <- high.cat[grep(",3]",names(high.cat))]
high.cat <- c(0,high.cat[1:16],0,high.cat[17:length(high.cat)]) 
length(high.cat)
high.cat

#Biomass  
high.bm <-  apply(B.mod.res$sims.matrix[,grep("^Bh",colnames(B.mod.res$sims.matrix))],2,median)
high.bm <- high.bm[grep(",3]",names(high.bm))]
length(high.bm)
high.bm

#mortality 
high.nat.m <-  apply(B.mod.res$sims.matrix[,grep("^m",colnames(B.mod.res$sims.matrix))],2,median) 
high.nat.m <- high.nat.m[grep(",3]",names(high.nat.m))]
length(high.nat.m)
high.nat.m

#modelled CPUE 
high.CPUE <- apply(B.mod.res$sims.matrix[,grep("CPUE.sub",colnames(B.mod.res$sims.matrix))],2,median)
high.CPUE <- high.CPUE[grep(",3]",names(high.CPUE))]
high.CPUE <- c(0,high.CPUE[1:16],0,high.CPUE[17:length(high.CPUE)])
length(high.CPUE)
high.CPUE

##
## Medium Strata 
##
#Catch 
med.cat <- apply(B.mod.res$sims.matrix[,grep("Catch.t",colnames(B.mod.res$sims.matrix))],2,median)
med.cat <- med.cat[grep(",2]",names(med.cat))]
med.cat <-  c(0,med.cat[1:16],0,med.cat[17:length(med.cat)])
length(med.cat)

#Biomass  
med.bm <-  apply(B.mod.res$sims.matrix[,grep("^Bh",colnames(B.mod.res$sims.matrix))],2,median)
med.bm <- med.bm[grep(",2]",names(med.bm))]
length(med.bm)

#mortality 
med.nat.m <-  apply(B.mod.res$sims.matrix[,grep("^m",colnames(B.mod.res$sims.matrix))],2,median) 
med.nat.m <- med.nat.m[grep(",2]",names(med.nat.m))]
length(med.nat.m)

#modelled CPUE 
med.CPUE <- apply(B.mod.res$sims.matrix[,grep("CPUE.sub",colnames(B.mod.res$sims.matrix))],2,median)
med.CPUE <- med.CPUE[grep(",2]",names(med.CPUE))]
med.CPUE <-  c(0,med.CPUE[1:16],0,med.CPUE[17:length(med.CPUE)])
length(med.CPUE)

##
## Low strata
##
#Catch  
low.cat <- apply(B.mod.res$sims.matrix[,grep("Catch.t",colnames(B.mod.res$sims.matrix))],2,median)
low.cat <- low.cat[grep(",1]",names(low.cat))]
low.cat <- c(0,low.cat[1:16],0,low.cat[17:length(low.cat)])
length(low.cat)

#Biomass
low.bm <- apply(B.mod.res$sims.matrix[,grep("^Bh",colnames(B.mod.res$sims.matrix))],2,median)
low.bm <- low.bm[grep(",1]",names(low.bm))]
length(low.bm)

#mortality  
low.nat.m <-  apply(B.mod.res$sims.matrix[,grep("^m",colnames(B.mod.res$sims.matrix))],2,median)
low.nat.m <- low.nat.m[grep(",1]",names(low.nat.m))]
length(low.nat.m)

#modelled CPUE 
low.CPUE <- apply(B.mod.res$sims.matrix[,grep("CPUE.sub",colnames(B.mod.res$sims.matrix))],2,median)
low.CPUE <- low.CPUE[grep(",1]",names(low.CPUE))]
low.CPUE <- c(0,low.CPUE[1:16],0,low.CPUE[17:length(low.CPUE)])
length(low.CPUE)


dat <- data.frame(Year = rep(yrs,3),Catch = c(high.cat,med.cat,low.cat),Biomass = c(high.bm,med.bm,low.bm),
                  nat.m = c(high.nat.m,med.nat.m,low.nat.m),
                  CPUE = c(high.CPUE,med.CPUE,low.CPUE),
                  mu = c(high.cat/(high.cat+high.bm),
                         med.cat/(med.cat+med.bm),
                         low.cat/(low.cat+low.bm)),
                  Habitat = c(rep("High",length(yrs)),rep("Med",length(yrs)),rep("Low",length(yrs))),
                  size.area = c(rep(B.areas[3],length(yrs)),rep(B.areas[2],length(yrs)),rep(B.areas[1],length(yrs))),
                  area = rep("SFA29B",3*length(yrs)),
                  row.names= NULL)
dat$BM.dens <- dat$Biomass/dat$size.area

# This data all gets combined so we can make the figures later... 
write.csv(dat, file=paste0(file = paste0(path.directory,assessmentyear,"/Assessment/Data/Model/SFA29B/SFA29.B.model.results.summary.",surveyyear,".csv")), row.names = FALSE) 
#write.csv(dat, file=paste0(file = paste0(path.directory,assessmentyear,"/Assessment/Data/Model/SFA29B/test_min_gh_for2020/SFA29.B.model.results.summary.",surveyyear,".csv")), row.names = FALSE) 
#write.csv(dat, file=paste0(file = paste0(path.directory,assessmentyear,"/Assessment/Data/Model/SFA29B/test_max_gh_for2020/SFA29.B.model.results.summary.",surveyyear,".csv")), row.names = FALSE) 
#write.csv(dat, file=paste0(file = paste0(path.directory,assessmentyear,"/Assessment/Data/Model/SFA29B/ModelRun_to2020/SFA29.B.model.results.summary.2020.csv")), row.names = FALSE) 


#prior/posterior plot
png(paste0(path.directory,assessmentyear,"/Assessment/Figures/Model/SFA29B/SFA29.B.prior.post.",surveyyear,".png"),width=11,height=8,units = "in",res=920)
plot(B.mod.res)
dev.off()


#plot catch to ensure everything makes sense and that you've put the 0's in the right years (compare back to previous year figures)
plot.Catch <- ggplot(dat, aes(x=Year, y=Catch, color=Habitat, group=Habitat)) + geom_point() + geom_line() + 
  theme_bw() 
plot.Catch

#plot biomass Density to ensure everything makes sense - compare back to previous year figures 
plot.Biomass.Density <- ggplot(dat, aes(x=Year, y=BM.dens, color=Habitat, group=Habitat)) + geom_point() + geom_line() + 
  theme_bw() 
plot.Biomass.Density

#process residuals 
B.mod.res.df <- as.data.frame(B.mod.res$summary)
resids <- B.mod.res.df[grep("^resid.p",row.names.data.frame(B.mod.res.df)),]
resids.low <- resids[grep(",1]",row.names.data.frame(resids)),]
resids.low$STRATA <- "low"
resids.low$Year <- 2001:surveyyear 
resids.med <- resids[grep(",2]",row.names.data.frame(resids)),]
resids.med$STRATA <- "med"
resids.med$Year <- 2001:surveyyear 
resids.high <- resids[grep(",3]",row.names.data.frame(resids)),]
resids.high$STRATA <- "high"
resids.high$Year <- 2001:surveyyear 

resids <- rbind(resids.low,resids.med,resids.high)

plot.residuals <- ggplot(resids) + geom_point(aes(x=Year, y= mean)) + 
  geom_errorbar(aes(x = Year,ymin = `2.5%`,ymax=`97.5%`),width=0) + 
  theme_bw() + geom_hline(yintercept = 0) + facet_wrap(~STRATA)
plot.residuals

png(paste0(path.directory,assessmentyear,"/Assessment/Figures/Model/SFA29B/SFA29.B.plot.resid.p.",surveyyear,".png"),width=11,height=8,units = "in",res=920)
plot.residuals
dev.off()

#process residuals standardized 
B.mod.res.df <- as.data.frame(B.mod.res$summary)
s.resids <- B.mod.res.df[grep("^sresid.p",row.names.data.frame(B.mod.res.df)),]
s.resids.low <- s.resids[grep(",1]",row.names.data.frame(s.resids)),]
s.resids.low$STRATA <- "low"
s.resids.low$Year <- 2001:surveyyear 
s.resids.med <- s.resids[grep(",2]",row.names.data.frame(s.resids)),]
s.resids.med$STRATA <- "med"
s.resids.med$Year <- 2001:surveyyear 
s.resids.high <- s.resids[grep(",3]",row.names.data.frame(s.resids)),]
s.resids.high$STRATA <- "high"
s.resids.high$Year <- 2001:surveyyear 

s.resids <- rbind(s.resids.low,s.resids.med,s.resids.high)

plot.std.residuals <- ggplot(s.resids) + geom_point(aes(x=Year, y= mean)) + 
  geom_errorbar(aes(x = Year,ymin = `2.5%`,ymax=`97.5%`),width=0) + 
  theme_bw() + geom_hline(yintercept = 0) + facet_wrap(~STRATA)
plot.std.residuals

png(paste0(path.directory,assessmentyear,"/Assessment/Figures/Model/SFA29B/SFA29.B.plot.s.resids.",surveyyear,".png"),width=11,height=8,units = "in",res=920)
plot.std.residuals
dev.off()


#Predict for next year, using the growth parameters from the model data...
# FOR predictions to 2025 -- not g V V V LOW!!! Majorly negative 
growth.parameter.decision.table <- growth.paras$gh
growth.parameter.decision.table

## test if growth was different than current year growth for decision table 
#growth.parameter.decision.table <- c(1, 1,1) ## if use write out decision table as ... growth_1.csv 

# First get the growth data, this will be in the order for the "strata" is above, as long as this is low then medium, then high this should be fine...
#growth.paras <- mod.dat$gh[mod.dat$Year ==max(yrs) & mod.dat$Strata %in% strata]
#B.next.predict <- predict(B.mod.res, exploit=0.1, g.parm=c(growth.paras$gh))
B.next.predict <- predict(B.mod.res, exploit=0.1, g.parm=c(growth.parameter.decision.table))
summary(B.next.predict)


#Method only does one exploitation at a time, note that I have changed the probabilites to be like those for BoF
#Workaround
set.seed(10) # set the random number generator if you want to make your results reproducable.
Decision.table <- matrix(NA,10,7)
dimnames(Decision.table)[[2]] <- names(summary(B.next.predict)$Next.year)
Decision.table

#Decision table work around from D.Keith to get prob biomass>LRP after fishing occurs'
#LRP for B=: 1.12 t/km^2
#set.seed(16) # 12 is o.k.
Decision.table <- NULL
for(i in 1:10){
  temp<-predict(B.mod.res,exploit=0.02*(i-1), g.parm=c(growth.parameter.decision.table))
  # Get the Probability of being above the LRP, for Area B is this 1.12, for area C this is 1.41, and D is 1.30
  lrp <- signif(length(which(temp$Bh.next$High/temp$Area[3] >= 1.12))/length(temp$Bh.next$High),digits=2)
  usr <- signif(length(which(temp$Bh.next$High/temp$Area[3] >= 2.24))/length(temp$Bh.next$High),digits=2)
  #temp<-predict(B.2015,exploit=0.02*(i-1), g.parm=c(1.1612, 1.1578, 1.1796))
  Decision.table[[i]]<-as.vector(c(unlist(summary(temp)$Next.year),lrp, usr))
}
Dec.tab <- do.call("rbind",Decision.table)
colnames(Dec.tab) <- c(names(summary(temp)$Next.year),"Prob_above_LRP", "Prob_above_USR")

Dec.tab

write.csv(Dec.tab, paste0(path.directory,assessmentyear,"/Assessment/Data/Model/SFA29B/SFA29.B.mod.Decision.table.",surveyyear,".csv"), row.names = FALSE) 
#write.csv(Dec.tab, paste0(path.directory,assessmentyear,"/Assessment/Data/Model/SFA29B/SFA29.B.mod.Decision.table.",surveyyear,"growth_1.csv"), row.names = FALSE) 

# ---- EXTRA - Decision table to predict max level exploitation risk ----
#Decision.table <- NULL
#for(i in 1:20){
#  temp<-predict(B.mod.res,exploit=0.05*(i-1), g.parm=growth.paras)
  # Get the Probability of being above the LRP, for Area B is this 1.12, for area C this is 1.41, and D is 1.30
#  lrp <- signif(length(which(temp$Bh.next$High/temp$Area[3] >= 1.12))/length(temp$Bh.next$High),digits=2)
#  usr <- signif(length(which(temp$Bh.next$High/temp$Area[3] >= 2.24))/length(temp$Bh.next$High),digits=2)
  #temp<-predict(C.2015,exploit=0.02*(i-1), g.parm=c(1.1612, 1.1578, 1.1796))
#  Decision.table[[i]]<-as.vector(c(unlist(summary(temp)$Next.year),lrp,usr))
#}
#Dec.tab.r1 <- do.call("rbind",Decision.table)
#colnames(Dec.tab.r1) <- c(names(summary(temp)$Next.year),"Prob_above_LRP", "Prob_above_USR")

#Dec.tab.r1
#write.csv(Dec.tab.r1, paste0(getwd(),"/SFA29B_results/B_mod",max(yrs),"_Decision_table_risk_assessment.csv"))

## Make plot for exploitation risk analysis
# Include Risk category
#Dec.tab.r1.df <- as.data.frame (Dec.tab.r1)
#library (ggplot2)
#dec.plot <- ggplot (Dec.tab.r1.df, aes (x=Exploit.High, y=Prob_above_USR)) +
#  theme_bw() + theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank()) +
#  annotate(geom="rect",ymin=0.75,ymax=1,xmin=-Inf,xmax=Inf, fill = "lightgreen", alpha=0.5)+
#  annotate(geom="rect",ymin=0.5,ymax=0.75,xmin=-Inf,xmax=Inf, fill="gold1", alpha = 0.5) +
#  annotate(geom="rect",ymin=0.25,ymax=0.5,xmin=-Inf,xmax=Inf, fill="tomato1", alpha = 0.6) +
#  annotate(geom="rect",ymin=0,ymax=0.25,xmin=-Inf,xmax=Inf, fill="red", alpha=0.6) +
#  annotate(geom="text",x=0.7,y=0.88,label="Low")+
#  annotate(geom="text",x=0.7,y=0.62,label="Moderate")+
#  annotate(geom="text",x=0.2,y=0.38,label="Moderate High")+
#  annotate(geom="text",x=0.2,y=0.12,label="High")+
#  geom_point() + geom_line() + scale_y_continuous(limit=c(0,1), expand=c(0.01,0))+
#  xlab ("Exploitation") +ylab("Probability Above USR") + ggtitle("Subarea B Risk Analysis")
#dec.plot

#png(paste0 ("Y:/INSHORE SCALLOP/SFA29/2019/figures/SubareaB_USRprob_RiskAnalysis", ".png"),11,9,res=400,units='in')
#dec.plot
#dev.off()

# ----- THE PREDICTION EVALUATION ----
## Now we can just run this through a loop rather than keep re-running these...
# Set the first year you want to run, note that we will have these saved for all years before the current year
# so there is no reason to run this for anything but the current year

first.pe.year <- max(yrs) # The results for previous years are all saved (see below), so there is no reason to set this to anything but yr-1 and
# just run this for 1 year
pe.years <- first.pe.year:first.pe.year
num.pe.years <- length(pe.years)
pe.res <- NULL
pe.pred <- NULL
# Walk through the model for each year...
for(i in 1:num.pe.years)
{
  
  pe.yrs <- 2001:pe.years[i] # The years for the model.
  pe.NY <- length(pe.yrs)
  
  inits.29B <- SFA29.inits(pe.NY)  
  
  SFA29Bdata <- list(
    N = pe.NY,
    H = num.areas,
    Area =B.areas,
    N1 = 1,
    Catch.actual = mod.dat$Catch.actual[mod.dat$Year %in% pe.yrs & !is.na(mod.dat$Catch.actual)], # First year won't have information
    Ih = dat.wrap(mod.dat,"Ih",pe.yrs,strata),
    rh = dat.wrap(mod.dat,"rh",pe.yrs,strata),
    clappers = dat.wrap(mod.dat,"clappers",pe.yrs,strata),
    L = dat.wrap(mod.dat,"L",pe.yrs,strata),
    gh = dat.wrap(mod.dat,"gh",pe.yrs,strata),
    wk = mod.dat$wk[mod.dat$Year %in% pe.yrs & !is.na(mod.dat$wk)], # Just removing trailing NA's that are in the data
    obs.nu = dat.wrap(mod.dat,"obs.nu",pe.yrs,strata),
    obs.tau = dat.wrap(mod.dat,"obs.tau",pe.yrs,strata),
    obs.phi = dat.wrap(mod.dat,"obs.phi",pe.yrs,strata),
    VMS.Effort = dat.wrap(mod.dat,"VMSEffort",pe.yrs[-length(pe.yrs)],strata)) # There won't be VMS data for the most recent data
  
  
  pe.res[[as.character(pe.years[i])]] <- SSModel(SFA29Bdata,SFA29.priors,inits.29B,parms=SFA29.parms,model.file=SFA29model,
                                                 Years=pe.yrs, nchains=nchains,niter=niter,nburnin=nburnin,nthin=nthin,Area="SFA29W",e.parms=e.parms.29B,debug=F)
  pe.pred[[as.character(pe.years[i]+1)]] <- predict(pe.res[[as.character(pe.years[i])]],Catch=SFA29Bdata$Catch.actual[length(SFA29Bdata$Catch.actual)],
                                                    g.parm=mod.dat$gh[mod.dat$Year ==pe.years[i] & mod.dat$Strata %in% strata])
}

#save(pe.pred,file="Y:/INSHORE SCALLOP/SFA29/Model_results_2014_2016/SFA29B/prediction_evaluation_results_2011_2016.RData")
#save(pe.pred,file = paste0(getwd(),"/SFA29B_results/prediction_evaluation_results_",pe.years,".RData"))
save(pe.pred,file=paste0(path.directory,assessmentyear,"/Assessment/Data/Model/SFA29B/SFA29B.prediction.evaluation.results.",surveyyear,".RData"))



# Now to make the historic plot below
# Assuming you haven't re-run everything above and wasted several hours of you life
# we need to bring in all the prediction evaluation data we have....
# Now load all the old pe.pred results, first identify where to find the data...

direct <- "Y:/Inshore/SFA29/"
pe.all <- NULL

for(i in 2016:pe.years) {
  if(i == 2016) 
  {
    load(paste0(direct,"Model_results_2015_2017/SFA29B/prediction_evaluation_results_2011_2016.RData"))
    pe.all <- pe.pred
  } 
  # Now load the more recent pe evaluation data
  if(i %in% 2017:2019) 
  {
    load(paste0(direct,(i+1),"/model/SFA29B_results/prediction_evaluation_results_",i,".RData"))
    pe.all <- c(pe.all,pe.pred)
  }  
  if(i == 2020)
  {
    load(paste0(direct,"2022/Assessment/Data/Model/SFA29B/ModelRun_to2020/SFA29B.prediction.evaluation.results.2020.RData"))
    pe.all <- c(pe.all,pe.pred)
  }
  if(i == 2021)
  {
    load(paste0(direct,"2022/Assessment/Data/Model/SFA29B/SFA29B.prediction.evaluation.results.2021.RData"))
    pe.all <- c(pe.all,pe.pred)
  }
  if(i %in% 2022:pe.years)
  {
    load(paste0(direct,(i+1),"/Assessment/Data/Model/SFA29B/SFA29B.prediction.evaluation.results.",i,".RData"))
    pe.all <- c(pe.all,pe.pred)
  }
} 


class(pe.all) <- "SFA29"



# Plot Prediction Evaluation 
# This produces 1 plot for low, 1 for medium, and 1 for high
#View to make sure it's what you expect! 
#windows(11,11)
par(mfrow=c(3,1))
SSModeltest::eval.predict.SFA29(pe.all,Year=2012,pred.lim=0.2)
dev.off()

#Save out plot 
png(paste0(path.directory,assessmentyear,"/Assessment/Figures/Model/SFA29B/SFA29.B.predict.evaluation.",surveyyear,".png"),width=9,height=9,units = "in", res=400)
par(mfrow=c(3,1))
SSModeltest::eval.predict.SFA29(pe.all,Year=2012,pred.lim=0.2)
dev.off()


################
#use 1 year natural mortality to see effect on decision tables 

# First get the growth data, this will be in the order for the "strata" is above, as long as this is low then medium, then high this should be fine...
#growth.paras <- mod.dat$gh[mod.dat$Year ==max(yrs) & mod.dat$Strata %in% strata]
B.next.predict <- predict(B.mod.res, exploit=0.1, g.parm=c(growth.paras$gh), m.avg = 1)
summary(B.next.predict)


#Method only does one exploitation at a time, note that I have changed the probabilities to be like those for BoF
#Workaround
set.seed(10) # set the random number generator if you want to make your results reproducible.
Decision.table <- matrix(NA,10,7)
dimnames(Decision.table)[[2]] <- names(summary(B.next.predict)$Next.year)
Decision.table

#Decision table work around from D.Keith to get prob biomass>LRP after fishing occurs'
#LRP for B=: 1.12 t/km^2
#set.seed(16) # 12 is o.k.
Decision.table <- NULL
for(i in 1:10){
  temp<-predict(B.mod.res,exploit=0.02*(i-1), g.parm=c(growth.paras$gh), m.avg = 1)
  # Get the Probability of being above the LRP, for Area B is this 1.12, for area C this is 1.41, and D is 1.30
  lrp <- signif(length(which(temp$Bh.next$High/temp$Area[3] >= 1.12))/length(temp$Bh.next$High),digits=2)
  usr <- signif(length(which(temp$Bh.next$High/temp$Area[3] >= 2.24))/length(temp$Bh.next$High),digits=2)
  #temp<-predict(B.2015,exploit=0.02*(i-1), g.parm=c(1.1612, 1.1578, 1.1796))
  Decision.table[[i]]<-as.vector(c(unlist(summary(temp)$Next.year),lrp, usr))
}
Dec.tab <- do.call("rbind",Decision.table)
colnames(Dec.tab) <- c(names(summary(temp)$Next.year),"Prob_above_LRP", "Prob_above_USR")

Dec.tab

write.csv(Dec.tab, paste0(path.directory,assessmentyear,"/Assessment/Data/Model/SFA29B/SFA29.B.mod.Decision.table.nat.m.1yr.",surveyyear,".csv"), row.names = FALSE) 

######################################################
#Plot of survey estimates over modelled biomass

summary <- as.data.frame(mod.res$summary)
parameters <- rownames(summary)
summary <- cbind(parameters, data.frame(summary, row.names=NULL))

n <- 3
years <- rep(2001:surveyyear, each=n)
Habitat <- rep(c("Low", "Med", "High"), 24) #Need to fix this so new years are added.

summary.Bh <- summary |>  filter(str_detect(summary$parameters, "^Bh"))
summary.Bh$Year <- years
summary.Bh$Habitat <- Habitat

summary.q <- summary |>  filter(parameters== "q")

summary.Bh$scaled <- summary.Bh$X50.*summary.q$X50.
summary.Bh$scaled.2.5 <- summary.Bh$X2.5.*summary.q$X50.#*summary.q$X2.5.
summary.Bh$scaled.97.5 <- summary.Bh$X97.5.*summary.q$X50.#*summary.q$X97.5.


mod.dat.plot <- mod.dat |> 
  rename(Habitat=Strata) |>
  mutate(Habitat = case_when(Habitat == "high" ~ "High", 
    Habitat == "med" ~ "Med",
    Habitat == "low" ~ "Low"))

mod.dat.plot$Habitat <- factor(mod.dat.plot$Habitat, levels = c("Low", "Med", "High"))
summary.Bh$Habitat <- factor(summary.Bh$Habitat, levels = c("Low", "Med", "High"))

#Plot by Habitat Type
ggplot()+
  geom_point(data = summary.Bh, aes(x=Year, y= scaled))+
  geom_line(data = summary.Bh, aes(x=Year,y=scaled), size = 0.5)+
  geom_ribbon(data = summary.Bh, aes(x=Year, ymin=scaled.2.5, ymax=scaled.97.5),alpha=0.2)+
  facet_wrap(factor(Habitat, levels=c("High","Med","Low")))+
  geom_point(data = (mod.dat.plot |> dplyr::filter(SUBAREA == "SFA29B")), aes(Year,Ih), colour = "red")+
  xlab("Year")+
  ylab("Commercial Biomass")+
  theme_bw()+
  facet_wrap(~Habitat)


#save
ggsave(filename = paste0(path.directory,assessmentyear,"/Assessment/Figures/Model/SFA29B/Survey_est_figure_SFA29B_",surveyyear,".png"), plot = last_plot(), scale = 2.5, width =11, height = 4, dpi = 300, units = "cm", limitsize = TRUE)

#High
#ggplot()+
#  geom_point(data = summary.Bh |> dplyr::filter(Habitat == "High"), aes(x =Years, y= scaled))+
#  geom_line(data = summary.Bh |> dplyr::filter(Habitat == "High"), aes(x =Years,y=scaled), size = 0.5)+
#  geom_ribbon(data = summary.Bh |> dplyr::filter(Habitat == "High"), aes(x = Years, ymin=scaled.2.5, ymax=scaled.97.5),alpha=0.2)+
#  geom_point(data = (mod.dat |> dplyr::filter(Strata == "high", SUBAREA == "SFA29B")), aes(Year,Ih), colour = "red")+
#  xlab("Year")+
#  ylab("Commercial Biomass")

#Medium
#ggplot()+
#  geom_point(data = summary.Bh |> dplyr::filter(Habitat == "Med"), aes(x =Years, y= scaled))+
#  geom_line(data = summary.Bh |> dplyr::filter(Habitat == "Med"), aes(x =Years,y=scaled), size = 0.5)+
#  geom_ribbon(data = summary.Bh |> dplyr::filter(Habitat == "Med"), aes(x = Years, ymin=scaled.2.5, ymax=scaled.97.5),alpha=0.2)+
#  geom_point(data = (mod.dat |> dplyr::filter(Strata == "med", SUBAREA == "SFA29B")), aes(Year,Ih), colour = "red")+
#  xlab("Year")+
#  ylab("Commercial Biomass")

#Low
#ggplot()+
#  geom_point(data = summary.Bh |> dplyr::filter(Habitat == "Low"), aes(x =Years, y= scaled))+
#  geom_line(data = summary.Bh |> dplyr::filter(Habitat == "Low"), aes(x =Years,y=scaled), size = 0.5)+
#  geom_ribbon(data = summary.Bh |> dplyr::filter(Habitat == "Low"), aes(x = Years, ymin=scaled.2.5, ymax=scaled.97.5),alpha=0.2)+
#  geom_point(data = (mod.dat |> dplyr::filter(Strata == "low", SUBAREA == "SFA29B")), aes(Year,Ih), colour = "red")+
#  xlab("Year")+
#  ylab("Commercial Biomass")
