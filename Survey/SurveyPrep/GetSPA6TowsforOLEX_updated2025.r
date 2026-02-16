#### SCRIPT TO GENERATE STATIONS FOR INSHORE SCALLOP SURVEY SPA 6 ####


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
source("Y:/Inshore/BoF/Assessment_fns/convert.dd.dddd.r")
source("Y:/Inshore/Survey/survey design R scripts/amyalloc.poly.r")
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
VMS.poly<-read.csv("Y:/Inshore/BoF/2015/SPA6/Survey/SPA6_VMS_IN_R_final_MOD.csv")
OUT.poly<-read.csv("Y:/Inshore/BoF/2015/SPA6/Survey/SPA6_VMS_OUT_R_final_MOD.csv")
surv.poly <-rbind(VMS.poly,OUT.poly)
surv.poly <- as.PolySet(surv.poly, projection="LL")
poly.VMSIN <- st_read("Y:/Inshore/Databases/Scallsur/SPA6_SurveyStrata/2015", layer = "SPA6_VMSStrata_IN_2015")


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


###### SPA 6 #####

#select previous year's tows
SPA6surv.dat<-subset(surv.dat,MGT_AREA_ID%in%c("6C","6B","6A"))
SPA6tows.yrprev<-subset(SPA6surv.dat,year==prev.yr)

#sum commercial scallops from previous year's tows
SPA6tows.yrprev$totcomm<-rowSums(SPA6tows.yrprev[,27:50]) # this is 80mm and above

#Select candidate tows from previous year for repeats
rep.dat.prevyr <- SPA6tows.yrprev %>%
  filter(totcomm != 0) %>% #chooses tows with commercial scallop
  dplyr::select(TOW_NO, lon, lat, STRATA_ID)
names(rep.dat.prevyr)<-c("EID","X","Y","Poly.ID")

#set the random allocation for the two survey polygons and set the number of repeats in each
poly.info <- data.frame(PID=1:2,PName=c("VMS","OUT"),allocation=c(56,33),repeats=c(19,12))

ref<-findPolys(rep.dat.prevyr,surv.poly)
rep.dat.prevyr$Poly.ID[rep.dat.prevyr$EID%in%ref$EID[ref$PID==1]]<-1
rep.dat.prevyr$Poly.ID[rep.dat.prevyr$EID%in%ref$EID[ref$PID==2]]<-2

#Use allocation function to select survey tows for new year
SPA6tows.newyr<-alloc.poly(list(surv.poly,poly.info),ntows=120,mindist=1.5,repeated.tows=rep.dat.prevyr)


#### Plot Stations ####

p <- pecjector(obj = NULL, area =list(x=c(-67.4,-66.3), y=c(44.2,45.2), crs=4326), plot = T, 
               add_layer = list(land = 'grey',eez = 'eez', bathy = 50, survey = c('inshore','outline'),scale.bar = 'bl',scale.bar = c('bl',0.5)))

p +
  geom_point(SPA6tows.newyr$Tows$new.tows, mapping = aes(X, Y)) +
  geom_point(SPA6tows.newyr$Tows$repeated.tows, mapping = aes(X, Y, colour = "red")) +
  geom_sf(data = poly.VMSIN, fill=NA, colour="red")


#### SAVE ####
write.csv(SPA6tows.newyr$Tows$new.tows, paste0("Y:/Inshore/Survey/SurveyPrep/", year, " Survey Prep/SPA6/GM", year, "newtows.csv"))
write.csv(SPA6tows.newyr$Tows$repeated.tows, paste0("Y:/Inshore/Survey/SurveyPrep/", year, " Survey Prep/SPA6/GM", year, "repeatedtows.csv"))


#****************************************************************************************
# Check tow locations in ArcMap and make any adjustments, save out to GMyyyy_olex.csv
# Use the following lines to convert the tow list from above into a GPSU OLEX import file
  
SPA6tows.dat<-read.csv(paste0("Y:/Inshore/Survey/SurveyPrep/", year, " Survey Prep/SPA6/GM", year, "_olex.csv"))

SPA6tows.dat$Lat<-convert.dd.dddd(SPA6tows.dat$Y,format='deg.min')
SPA6tows.dat$Lon<-convert.dd.dddd(SPA6tows.dat$X,format='deg.min')*-1

write.csv(SPA6tows.dat,paste0("Y:/Inshore/Survey/SurveyPrep/", year, " Survey Prep/SPA6/GM", year, "_olex.csv"))

data <-SPA6tows.dat
  data$X.1 = data$X * -1
  #data$Long.End = data$Long.End * -1

  xyzgri = NULL
  tow = 0
  for(i in 1:nrow(data)){
     sym = "Brunsirkel   "
    comm = data$EID[i]
    sta = comm
    stab = paste(sta, ".1", sep = "")


    while(nchar(sta) < 6) sta = paste(sta, " ", sep = "")

    while(nchar(stab) < 6) stab = paste(stab, " ", sep = "")
    xyzgri = rbind(xyzgri, cbind("W", sta, paste("N",data$Y[i], sep = ""), paste("W",data$X.1[i], sep = ""), 33, sym, "C", comm))
  }
  
 write.table(xyzgri, file = file.path(paste0("Y:/Inshore/Survey/SurveyPrep/", year, " Survey Prep/SPA6/GM", year, "_Stations.gps")), quote = F, sep = " ", row.names = F, col.names = F)

