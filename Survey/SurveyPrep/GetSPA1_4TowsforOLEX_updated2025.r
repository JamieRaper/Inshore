#### SCRIPT TO GENERATE STATIONS FOR INSHORE SURVEY SPA 1 and 4

require(ROracle)
require(PBSmapping)
require(tidyverse)


#### DEFINE ####

year <- 2025
prev.yr <- 2024
un.ID=Sys.getenv("un.raperj") #ptran username
pwd.ID=Sys.getenv("pw.raperj") #ptran password


#### LOAD ####

#Load functions
source("Y:/Inshore/Survey/survey design R scripts/amyalloc.poly.r")
source("Y:/Inshore/BoF/Assessment_fns/convert.dd.dddd.r")

funcs <- c("https://raw.githubusercontent.com/Mar-scal/Assessment_fns/master/Maps/convert_coords.R",
           "https://raw.githubusercontent.com/Mar-scal/Assessment_fns/master/Maps/add_alpha_function.R",
           "https://raw.githubusercontent.com/Mar-scal/Assessment_fns/master/Maps/pectinid_projector_sf.R")
dir <- getwd()
for(fun in funcs) 
{
  temp <- dir
  download.file(fun,destfile = basename(fun))
  source(paste0(dir,"/",basename(fun)))
  file.remove(paste0(dir,"/",basename(fun)))
}

#Load poly data
newAreaPolys<-read.csv("Y:/Inshore/Survey/2010/r//NewAreaDefsforISAREADEFS.csv") #?may not be required
HSI.poly<-read.csv("Y:/Inshore/Survey/2010/r/BOFsurveyBoundingPoly.csv")

#Load station allocation file
BFalloc<-read.csv(paste0("Y:/Inshore/Survey/SurveyPrep/", year," Survey Prep/SPA1&4/BOFalloc", year, ".csv"))


#### Import inshore survey data from oracle ####

qu.hf <- paste(
  "select * ",
  "from SCALLSUR.SCLIVERES ",
  "left join SCALLSUR.SCTOWS ",
  "on SCALLSUR.SCLIVERES.CRUISE = SCALLSUR.SCTOWS.CRUISE ",
  "and SCALLSUR.SCLIVERES.TOW_NO = SCALLSUR.SCTOWS.TOW_NO ",
  sep="")

qu.strata <- "select * from SCALLSUR.SCSTRATAINFO"

chan <- dbConnect(drv = dbDriver("Oracle"), username=un.ID,  password = pwd.ID,  dbname = "ptran", believeNRows=FALSE)

surv.dat <- dbGetQuery(chan, qu.hf)
str.polys <- dbGetQuery(chan, qu.strata)

#Convert tow location from DDM to DD
surv.dat$lat<-convert.dd.dddd(surv.dat$START_LAT)
surv.dat$lon<-convert.dd.dddd(surv.dat$START_LONG)
surv.dat$year<-as.numeric(format(surv.dat$TOW_DATE, "%Y"))

#Shows structure of survey data and unique management areas in the survey dataset
str(surv.dat)
unique(surv.dat$MGT_AREA_ID)


#### Bay of Fundy  SPA 1 and 4 ####

#select previous year's tows
surv.dat.prevyr<-subset(surv.dat,year==prev.yr & MGT_AREA_ID%in%c("4","1")) 
BOFtows.prevyr<-subset(surv.dat.prevyr,year==prev.yr,c("TOW_NO","lon","lat","STRATA_ID"))

#organize strata polys, select survey strata
names(str.polys)<-c("PID","POS","X","Y","PName","Area")
str.polys<-str.polys[order(str.polys$PID),]
str.data<-subset(str.polys,POS==1,c("PID","PName","Area"))
str.polys<-subset(str.polys,!(PID%in%c(37,38,47,48,53)&POS==1))

#select survey strata in SPAs 1 & 4
BOFstr.data<-subset(str.data,PID%in%c(1:20,35:39,47:53))
BOFstr.data$PName<-as.character(BOFstr.data$PName)

#sum commercial scallops from previous year's tows
surv.dat.prevyr$totcomm<-rowSums(surv.dat.prevyr[,27:50]) # this is 80mm and above

#the next line is to remove strata 12 and 18 from the random generated stations proportion to variance in area 1
#because a portion of the area is in the shipping area and the variance is always high here so a large portion
#of unnecessary tow get allocated to this area and then have to be moved.
SPA1str.data<-subset(BOFstr.data,PID%in%c(13:17,19:20))

#Calculate sd by stratum for SPA 1A
S_h<-with(subset(surv.dat.prevyr,STRATA_ID%in%SPA1str.data$PID&year==prev.yr),tapply(totcomm,STRATA_ID,sd))

#Allocate SPA 1A stations - min 3 per stratum, remove 3 stations for each stratum (3X7=21) and add back after allocation
N.SPA1<-58-21
alc1<-round(N.SPA1*((SPA1str.data$Area*S_h)/sum(SPA1str.data$Area*S_h)))
alc1[which(alc1==min(alc1))]<-alc1[which(alc1==min(alc1))]+N.SPA1-sum(alc1)
SPA1str.data$allocation<-alc1 +3
SPA1str.data$repeats<-NA

#Calculate sd by stratum for SPA4
SPA4str.data<-subset(BOFstr.data,PID%in%c(1:5,8:10))
S_h<-with(subset(surv.dat.prevyr,STRATA_ID%in%SPA4str.data$PID&year==prev.yr),tapply(totcomm,STRATA_ID,sd))

# !!! In 2025, variance too high in stratum 8 for station allocation, adjust to 0.6*sd !!!
#S_h[6] <- 0.6*S_h[6]

#Allocate SPA 4 stations - min 3 per stratum, remove 3 stations for each stratum (3x8=46) and add back after allocation
N.SPA4<-70-24
alc4<-round(N.SPA4*((SPA4str.data$Area*S_h)/sum(SPA4str.data$Area*S_h)))
alc4[which(alc4==min(alc4))]<-alc4[which(alc4==min(alc4))]+N.SPA4-sum(alc4)
SPA4str.data$allocation<-alc4 +3
SPA4str.data$repeats<-NA

#Other strata stations are allocated according to BFalloc
BFstr.data<-subset(BOFstr.data,PID%in%c(6:7,35:39,49,51:53,12,18))
BFstr.data<-merge(BFstr.data,BFalloc,all=T)

BOFstr.data<-rbind(SPA4str.data,SPA1str.data,BFstr.data)

#Select candidate tows from previous year for repeats
rep.dat.prevyr <- surv.dat.prevyr %>%
  filter(STRATA_ID%in%BFstr.data$PID[!is.na(BFstr.data$repeats)], totcomm != 0) %>% #chooses tows with nonzero commercial scallops in strata with allocated repeats
  dplyr::select(TOW_NO, lon, lat, STRATA_ID)

#Use allocation function to select survey tows for new year
BFtows.newyr<-alloc.poly(poly.lst = list(str.polys,BOFstr.data),bounding.poly=HSI.poly,repeated.tows=rep.dat.prevyr)
head(BFtows.newyr$Tows$new.tows)


#### Plot Stations ####

p <- pecjector(obj = NULL, area = "bof",plot = T, 
          add_layer = list(land = 'grey',eez = 'eez', bathy = 50, survey = c('inshore','outline'),scale.bar = 'bl',scale.bar = c('bl',0.5)))

p <- pecjector(obj = NULL, area = "bof",plot = T, 
               add_layer = list(land = 'grey',eez = 'eez', survey = c('inshore','outline'),scale.bar = 'bl',scale.bar = c('bl',0.5)))

p +
  geom_point(BFtows.newyr$Tows$new.tows, mapping = aes(X, Y)) +
  geom_point(BFtows.newyr$Tows$repeated.tows, mapping = aes(X, Y, colour = "red"))


#### Save ####
write.csv(BFtows.newyr$Tows$new.tows,paste0("Y:/Inshore/Survey/SurveyPrep/", year," Survey Prep/SPA1&4/BF", year, "newtows.csv"),row.names=F)
write.csv(BFtows.newyr$Tows$repeated.tows, paste0("Y:/Inshore/Survey/SurveyPrep/", year," Survey Prep/SPA1&4/BF", year, "repeatedtows.csv"),row.names=F)



#****************************************************************************************
#Check and make any adjustments to tow location in ArcMap, update coordinates, merge all tows, then save as BFYYYY_olex.csv

#Note: NEW IN 2022. Because of consistently high variance, we often end up with too many tows in stratum #1. 
#Randomly select 2-3 tows from stratum #1 and reallocate to stratum #11 (instead of previous procedure of putting exploratory tows in #11)
#Add at least 5 exploratory tows to 1A below 4 along Digby neck, and 4 tows inside 2 mi spa4 

#the following lines are to convert the files for deg.min
#********************************************************************************************
BFtows.newyr<-read.csv(paste0("Y:/Inshore/Survey/SurveyPrep/", year, " Survey Prep/SPA1&4/BF", year, "_olex.csv"))


source("Y:/Inshore/Survey/2010/r/fn/convert.dd.dddd.r")

BFtows.newyr$Lat<-convert.dd.dddd(BFtows.newyr$Y,format='deg.min')
BFtows.newyr$Lon<-convert.dd.dddd(BFtows.newyr$X,format='deg.min')*-1

write.csv(BFtows.newyr,paste0("Y:/Inshore/Survey/SurveyPrep/", year, " Survey Prep/SPA1&4/BF", year, "_olex.csv"))



#Use the following lines to convert the tow list from above into an OLEX import file
#********************************************************************************************
BFtows.newyr<-read.csv(paste0("Y:/Inshore/Survey/SurveyPrep/", year, " Survey Prep/SPA1&4/BF", year, "_olex.csv"))
  data <-BFtows.newyr
  data$X = data$X * -1
  

  xyzgri = NULL
  tow = 0
  for(i in 1:nrow(data)){
    sym = "Brunsirkel   "
    comm = data$EID[i]
    sta = comm
    stab = paste(sta, ".1", sep = "")

    while(nchar(sta) < 6) sta = paste(sta, " ", sep = "")

    while(nchar(stab) < 6) stab = paste(stab, " ", sep = "")
    xyzgri = rbind(xyzgri, cbind("W", sta, paste("N",data$Y[i], sep = ""), paste("W",data$X[i], sep = ""), 33, sym, "C", comm))
   # xyzgri = rbind(xyzgri, cbind("W", stab, paste("N",data$Y[i], sep = ""), paste("W",data$X[i], sep = ""), 33, sym, "C", ""))
  }
  #xyzgri$lat = round(as.numeric(as.character(xyzgri$lat))/celldim)*celldim
  #xyzgri$lon = round(as.numeric(as.character(xyzgri$lon))/celldim)*celldim

write.table(xyzgri, file = file.path(paste0("Y:/Inshore/Survey/SurveyPrep/", year, " Survey Prep/SPA1&4/BF", year, "_olex.gps")), quote = F, sep = " ", row.names = F, col.names = F)


