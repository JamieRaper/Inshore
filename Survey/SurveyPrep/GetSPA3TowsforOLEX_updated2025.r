#### SCRIPT TO GENERATE STATIONS FOR INSHORE SCALLOP SURVEY SPA 3 ####

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
Oldsurv.poly<-read.csv("Y:/Inshore/Survey/2010/r/SPA3surveyPoly_Extended.csv")
VMS.poly<-read.csv("Y:/Inshore/Survey/2011/SPA3/SPA3_VMSpoly.csv")
poly.sf <- st_read("Y:/Inshore/BoFBoundaries/SPABoundaries_Redrawn2014/SPA New Polys/shp polygons", layer = "SPA3_polygon_NAD83")
poly.VMS <- st_read("Y:/Inshore/Databases/Scallsur/SPA3", layer = "SPA3_VMS_StrataBrierLurcher")
poly.SMB <- st_read("Y:/Inshore/Databases/Scallsur/SPA3", layer = "SMB")



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


#### SPA 3 ####

#Organize strata polys
outerPoly<-joinPolys(Oldsurv.poly,VMS.poly,operation="DIFF")
outerPoly$PID=2
surv.poly <-rbind( VMS.poly,  outerPoly)
surv.poly <- as.PolySet(surv.poly, projection="LL")

#select previous year's tows
SPA3surv.dat<-subset(surv.dat,MGT_AREA_ID%in%c("3","7"))
SPA3tows.yrprev<-subset(SPA3surv.dat,year==prev.yr)

#sum commercial scallops from previous year's tows
SPA3tows.yrprev$totcomm<-rowSums(SPA3tows.yrprev[,27:50]) # this is 80mm and above

#Select candidate tows from previous year for repeats
rep.dat.prevyr <- SPA3tows.yrprev %>%
  filter(totcomm != 0) %>% #chooses tows with commercial scallop
  dplyr::select(TOW_NO, lon, lat, STRATA_ID)
names(rep.dat.prevyr)<-c("EID","X","Y","Poly.ID")

#set the random allocation for the two survey polygons and set the number of repeats in each
poly.info <- data.frame(PID=1:2,PName=c("VMS","outer"),allocation=c(56,45),repeats=c(19,15))
  
ref<-findPolys(rep.dat.prevyr,surv.poly)
rep.dat.prevyr$Poly.ID[rep.dat.prevyr$EID%in%ref$EID[ref$PID==1]]<-1
rep.dat.prevyr$Poly.ID[rep.dat.prevyr$EID%in%ref$EID[ref$PID==2]]<-2

#Use allocation function to select survey tows for new year
SPA3tows.newyr<-alloc.poly(list(surv.poly,poly.info),ntows =135,mindist=1,repeated.tows=rep.dat.prevyr)

# When tows are allocated must include:: 15 new, 6 repeats in SMB (CHECK MANUALLY!!!) #


#### Plot Stations ####

p <- pecjector(obj = NULL, area =list(x=c(-66.8,-65.8), y=c(43.6,44.6), crs=4326), plot = T, 
               add_layer = list(land = 'grey',eez = 'eez', bathy = 50, survey = c('inshore','outline'),scale.bar = 'bl',scale.bar = c('bl',0.5)))

p +
  geom_point(SPA3tows.newyr$Tows$new.tows, mapping = aes(X, Y)) +
  geom_point(SPA3tows.newyr$Tows$repeated.tows, mapping = aes(X, Y, colour = "red")) +
  geom_sf(data = poly.sf, fill=NA, colour="grey55") +
  geom_sf(data = poly.VMS, fill=NA, colour="red") +
  geom_sf(data = poly.SMB, fill=NA, colour="red")


## CHECK BEFORE WRITING IF ALLOCATION IS ADEQUATE FOR SMB (~15 new, 6 repeats)!!!!!!!!
write.csv(SPA3tows.newyr$Tows$new.tows,paste0("Y:/Inshore/Survey/SurveyPrep/", year, " Survey Prep/SPA3/SPA3tows", year, "newtows.csv"))
write.csv(SPA3tows.newyr$Tows$repeated.tows,paste0("Y:/Inshore/Survey/SurveyPrep/", year, " Survey Prep/SPA3/SPA3tows", year, "repeatedtows.csv"))


############################################################################################################
#Check and make any adjustments to tow location in ArcMap, update coordinates, merge all tows, then save as BIYYYY_olex.csv
# tows may be allocated in untowable area. Check SPA3 bathy (move to nearest towable bottom if req)
# Use the following lines to convert the tow list from above into a GPSU OLEX import file

#the following lines are to convert the files for deg.min
#********************************************************************************************
  
BItows.newyr<-read.csv(paste0("Y:/Inshore/Survey/SurveyPrep/", year, " Survey Prep/SPA3/BI", year, "_olex.csv"))


source("Y:/Inshore/Survey/2010/r/fn/convert.dd.dddd.r")

BItows.newyr$Lat<-convert.dd.dddd(BItows.newyr$Y,format='deg.min')
BItows.newyr$Lon<-convert.dd.dddd(BItows.newyr$X,format='deg.min')*-1

write.csv(BItows.newyr,paste0("Y:/Inshore/Survey/SurveyPrep/", year, " Survey Prep/SPA3/BI", year, "_olex.csv"))


#Use the following lines to convert the tow list from above into an OLEX import file
#********************************************************************************************
  
SPA3tows.dat = read.csv(file.path(paste0("Y:/Inshore/Survey/SurveyPrep/", year, " Survey Prep/SPA3/BI", year, "_olex.csv")))
  data <-SPA3tows.dat
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
  
 write.table(xyzgri, file = file.path(paste0("Y:/Inshore/Survey/SurveyPrep/", year, " Survey Prep/SPA3/BI", year, "_olex.gps")), quote = F, sep = " ", row.names = F, col.names = F)



