source("Y:/Inshore/BoF/Assessment_fns/convert.dd.dddd.r")

year <- 2025

SFA29tows.dat = read.csv(file.path(paste0("Y:/Inshore/Survey/SurveyPrep/", year, " Survey Prep/SFA29W/SFA29",year,"_olex.csv" )))

SFA29tows.dat$Lat<-convert.dd.dddd(SFA29tows.dat$Y,format='deg.min')
SFA29tows.dat$Lon<-convert.dd.dddd(SFA29tows.dat$X,format='deg.min')*-1  

write.csv(SFA29tows.dat, paste0("Y:/Inshore/Survey/SurveyPrep/", year, " Survey Prep/SFA29W/SFA29",year,"_olex.csv"), quote = F, row.names = F)

data <-SFA29tows.dat
data$X.1 = data$X * -1


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

write.table(xyzgri, file = file.path(paste0("Y:/Inshore/Survey/SurveyPrep/", year, " Survey Prep/SFA29W/SFA29",year,"_Stations.gps")), quote = F, sep = " ", row.names = F, col.names = F)


#Archive
# setwd("Y:/Inshore/Survey Prep/2023 Survey Prep/SFA29W/")
# 
# # Make column names for import
# colnames <- c ("FID", "ET_ID", "Classification", "Long", "Lat")
# #colnames <- c ("FID", "ET_ID","STRATA", "ET_X", "ET_Y")
# # Object of all file nimes in the specified location
# filenames <- list.files ("txt_tows/")
# 
# # Import all data to list (from the location specified in filenames)
# All <- lapply (filenames, function (i) {
#   i <- paste ("txt_tows/", i, sep="")
#   read.csv (i, header=TRUE, col.names = colnames)
# })
# 
# library (reshape2)
# # Use melt to turn list (containing all data) into data frame
# Alldata <- melt (All, id.vars = colnames)
# 
# 
# Alldata$F <- "W"
# Alldata$"ID----" <- 1:nrow(Alldata)
# Alldata$ID <- 1:nrow(Alldata)
# Alldata$Latitude <- paste ("N", Alldata$Lat, sep = "")
# Alldata$Longitude <- paste ("W", abs (Alldata$Long), sep = "")
# Alldata$"Symbol-------" <- "33"
# Alldata$T <- "Brunsirkel   "
# Alldata$Comment <- "C"
# Alldata$" " <- 1:nrow (Alldata)
# 
# 
# ## REQUIRES the correct number of spacing in ID
# OLEXdata <- Alldata[, c ("F", "ID----", "Latitude", "Longitude", "Symbol-------", "T", "Comment", " ")]
# 
# write.table (OLEXdata, file = file.path("Y:/Inshore/Survey Prep/2023 Survey Prep/SFA29W/SFA29W_2023.gps"), row.names = F, quote = F)
# 
# ## Add subarea for printing
# ## Order must be same as upload from folder/station numbers the same (double check)
# Alldata$SubArea <- "E"
# Alldata$SubArea <- ifelse (Alldata$`ID----` <= 112, "D", Alldata$SubArea)
# Alldata$SubArea <- ifelse (Alldata$`ID----` <= 79, "C", Alldata$SubArea)
# Alldata$SubArea <- ifelse (Alldata$`ID----` <= 47, "B", Alldata$SubArea)
# Alldata$SubArea <- ifelse (Alldata$`ID----` <= 14, "A", Alldata$SubArea)
# 
# PrintData <- Alldata [, c ("SubArea", "Classification", "ID----", "Lat", "Long")]
# 
# write.table (PrintData, file = file.path("Y:/INSHORE SCALLOP/Survey Prep/2021 Survey Prep/SFA29W/SFA29W_2021_stations.csv"), row.names = F, quote = F)
# 
# 
