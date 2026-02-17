###.....................................###
###  Commercial Catch Rates and Plots   ###
###              SFA 29W                ###
###       J. Raper Jan 2021             ###
###.....................................###




#BEFORE RUNNING THIS SCRIPT:

# compare SCALLOP db landings with area cap monitoring report and address any issues (differences > 2 mt for each fleet/area should be investigated)
# update SFA29_totalLandings_YearFleetFSC.csv,  SFA29_TACbyYr.csv, and SFA29_totalLandings_YearSubarea.csv with TAC and landings area cap monitoring reports and save in the current assessment folder: Y:\Inshore\29W\YYYY\Assessment\Data\CommercialData
# ensure date format in your SQL Developer profile is set to YYYY-MM-DD

require(ROracle)
require(ggplot2)
require(RColorBrewer)
require(plyr)
require(dplyr)
require(tidyr)
require(openxlsx)
require(sf)


source("Y:/Inshore/BoF/Assessment_fns/convert.dd.dddd.r")


#### DEFINE ####

direct <- "Y:/Inshore/SFA29"
fishingyear <- 2025 #most recent year of commercial fishing data to be used (e.g. if fishing season is 2019/2020, use 2020)
assessmentyear <- 2026 #year in which you are conducting the assessment
un.ID=Sys.getenv("un.raperj") #ptran username
pwd.ID=Sys.getenv("pw.raperj") #ptran password
ess <- "Y" #identify ess drive

#### Import Mar-scal functions for Pectinid Projector

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

#### Read files ####

# TAC and Landings time series flat files
landings.year <- read.csv(paste0(direct, "/", assessmentyear, "/Assessment/Data/CommercialData/SFA29_totalLandings_YearFleetFSC.csv"))
landings.area <- read.csv(paste0(direct, "/", assessmentyear, "/Assessment/Data/CommercialData/SFA29_totalLandings_YearSubarea.csv"))
Tac <- read.csv(paste0(direct, "/", assessmentyear, "/Assessment/Data/CommercialData/SFA29_TACbyYr.csv"))

#CPUE_byYrAreaFleet and CPUE_bySubarea files from previous year
CPUE_byYrAreaFleet <- read.csv(paste0(direct,"/", (assessmentyear-1), "/Assessment/Data/CommercialData/SFA29_CPUE_byYrAreaFleet_", (fishingyear-1), ".csv")) 
CPUE_bySubarea <- read.csv(paste0(direct, "/", (assessmentyear-1), "/Assessment/Data/CommercialData/SFA29_CPUE_bySubarea_", (fishingyear-1), ".csv"))

#Polygons for spatial plots
poly.sf <- st_read(paste0(ess,":/Inshore/Databases/Scallsur/SFA29BottomTypes/SFA29_shp"),layer = "SFA29_BoundariesFollowing12nmDD_NoSubareas_WGS84")
poly.subareas <- st_read(paste0(ess,":/Inshore/Databases/Scallsur/SFA29BottomTypes/SFA29_shp"),layer = "SFA29_subareas_utm19N")

#### Select data #### 

quer2 <- paste(
  "SELECT * 			                             ",
  "FROM scallop.scallop_log_marfis s		         ",
  "WHERE s.assigned_area in ('29A', '29B', '29C', '29D', '29E')       ",
  " 	AND  s.date_fished >= to_date('",fishingyear-1,"-10-01','YYYY-MM-DD') and s.date_fished < to_date('",fishingyear,"-10-01','YYYY-MM-DD') ",
  "AND licence_id NOT IN ('356089', '356090', '356091', '356092', '368730', '369132', '369133', '371484','375539', '376508')  ",
  "	AND (s.data_class = 1                        ",
  "OR (s.data_class = 2 AND s.quality_flag =',4' ) ",
  "OR (s.data_class = 2 AND s.quality_flag =',1,4') ",
  "OR (s.data_class = 2 AND s.quality_flag =',2,4')) ",
  sep=""
)

chan <- dbConnect(drv = dbDriver("Oracle"), username=un.ID,  password = pwd.ID,  dbname = "ptran", believeNRows=FALSE)

logs <- dbGetQuery(chan, quer2)
dim(logs)

#Convert coordinates:
logs$lat <- convert.dd.dddd(logs$LATITUDE/100) #coordinates in SCALLOP db are stored without the decimal point, have to divide by 100 to get degrees decimal minutes for convert.dd.dddd
logs$lon <- (-1)*convert.dd.dddd(logs$LONGITUDE/100)

#Add year column:
logs$DATE_FISHED <- as.Date(logs$DATE_FISHED, format="%Y-%m-%d")  
logs$YEAR <- as.numeric(format(logs$DATE_FISHED, "%Y")) 

#Check data
table(logs$YEAR) #check years, the 29W fishing season occurs in a single calendar year, but FSC landings can occur outside that season
table(logs$FLEET) #check fleets, 29W is fished by Full Bay and Inshore
table(logs$FLEET, logs$ASSIGNED_AREA) #check no of records for rule of <5


#If any issues here, STOP and address with log scan and/or VMS checks. Make any corrections in the SCALLOP db (and send to CDD), then restart this script


#Replace calendar year with fishing year
logs$YEAR <- as.numeric(fishingyear) 

#Calculate effort
logs$effort_h <- (logs$AVG_TOW_TIME*logs$NUM_OF_TOWS)/60


#### Calculate CPUE by fleet and subarea ####

effort.dat.subarea <- aggregate(logs$effort_h, by=list(logs$FLEET, logs$ASSIGNED_AREA), FUN=sum)
names(effort.dat.subarea) <- c("fleet","area","effort.hr")

catch.dat.subarea <-  aggregate(logs$DAY_CATCH_KG, by=list(logs$FLEET, logs$ASSIGNED_AREA), FUN=sum)
names(catch.dat.subarea) <- c("fleet", "area", "catch.kg")

nlogs.subarea <- aggregate(logs$LOG_SEQ, by=list(logs$FLEET, logs$ASSIGNED_AREA), FUN=length)
names(nlogs.subarea) <- c("fleet", "area", "n")

cpue.subarea <- merge(merge(effort.dat.subarea, catch.dat.subarea, by.x=c("fleet","area"), by.y=c("fleet","area")), 
                      nlogs.subarea, by.x=c("fleet","area"), by.y=c("fleet","area"))

#CPUE is reported as long as rule of 5 is met for Privacy Act considerations, otherwise returns NA.
cpue.subarea$cpue.kgh <- ifelse(cpue.subarea$n > 5, cpue.subarea$catch.kg/cpue.subarea$effort.hr, NA)
print(cpue.subarea)


#### Update CPUE_byYrAreaFleet csv file ####

### Run this if not all areas were fished in given year	
fleet <- c ("Full Bay", "Full Bay","Full Bay", "Full Bay","Full Bay", "Inshore", "Inshore", "Inshore", "Inshore", "Inshore")
area <- c ("29A", "29B", "29C", "29D", "29E", "29A", "29B", "29C", "29D", "29E")
allcombos <- data.frame (fleet, area)
cpue.subarea <- merge (cpue.subarea, allcombos, all = T)
print(cpue.subarea)

#Add fishing year
cpue.subarea$year <- fishingyear

#Append current year data to CPUE_byYrAreaFleet
comm.dat.subarea <- rbind(CPUE_byYrAreaFleet, cpue.subarea[,c("fleet", "area", "year", "cpue.kgh", "catch.kg", "effort.hr")])

#Save to current assessment folder
write.csv(comm.dat.subarea, paste0(direct,"/",assessmentyear,"/Assessment/Data/CommercialData/SFA29_CPUE_byYrAreaFleet_", fishingyear, ".csv"), row.names = FALSE)


#### Calculate combined fleet effort by Subarea ####

effort.dat.combined <- aggregate(logs$effort_h, by=list(logs$ASSIGNED_AREA), FUN=sum)
names(effort.dat.combined) <- c("area","effort.dat.hr")

catch.dat.combined <-  aggregate(logs$DAY_CATCH_KG, by=list(logs$ASSIGNED_AREA), FUN=sum)
names(catch.dat.combined) <- c("area", "catch.dat.kg")

nlogs.combined <- aggregate(logs$LOG_SEQ, by=list(logs$ASSIGNED_AREA), FUN=length)
names(nlogs.combined) <- c("area", "n")

cpue.combined <- merge(merge(effort.dat.combined, catch.dat.combined, by.x="area", by.y="area"),
                   nlogs.combined, by.x="area", by.y="area")

#CPUE is reported as long as rule of 5 is met for Privacy Act considerations, otherwise returns NA:
cpue.combined$cpue.kgh <- ifelse(cpue.combined$n > 5, cpue.combined$catch.dat.kg/cpue.combined$effort.dat.hr, NA)

#Combine landings with cpue
catch.fishery.combined <- landings.area[which(landings.area$YEAR == fishingyear),]
names(catch.fishery.combined) <- (c("year", "area", "catch.fleet.mt"))
cpue.combined <- merge(cpue.combined, catch.fishery.combined, by.x = "area", by.y='area')

#Calculate fishery-level (fleet) effort:
cpue.combined$effort.fleet.1000h <- cpue.combined$catch.fleet.mt/cpue.combined$cpue.kgh
print(cpue.combined)


### Update CPUE_bySubarea csv file ####

#Append current year data to CPUE_bySubarea
comm.dat.combined <- rbind(CPUE_bySubarea, cpue.combined[,c("year", "area", "effort.dat.hr","catch.dat.kg", "n", "cpue.kgh","catch.fleet.mt", "effort.fleet.1000h")])
print(comm.dat.combined)

#Save to current asssessment folder
write.csv(comm.dat.combined, paste0(direct,"/",assessmentyear,"/Assessment/Data/CommercialData/SFA29_CPUE_bySubarea_", fishingyear, ".csv"), row.names = FALSE)


#### Time Series Plots ####

#Labels for facet panels
facet_names <- c(
  `29A` = "Subarea A",
  `29B` = "Subarea B",
  `29C` = "Subarea C",
  `29D` = "Subarea D",
  `29E` = "Subarea E"
)

#CPUE by fleet and subarea:

medians <- ddply(comm.dat.subarea[which(comm.dat.subarea$year != fishingyear),], .(fleet, area), summarise, median = median(cpue.kgh, na.rm = TRUE)) #Create df of median cpue by fleet and area

ggplot(filter(comm.dat.subarea), aes(x = year, y = cpue.kgh)) +
  theme_bw(base_size = 16) + theme(panel.grid.minor.x = element_blank()) +  
  geom_point(aes(colour = fleet, shape = fleet)) +
  geom_line(aes(colour = fleet)) +
  geom_hline(data=medians, aes(yintercept=median, colour = fleet), linetype = "dashed") +
  scale_x_continuous("Year", breaks = seq(2002,2026,6), limits = c(2000, 2027)) +
  scale_y_continuous("Catch Rate (kg/h)", limits = c(0,120), breaks = seq(0,120,20)) +
  scale_colour_manual(values = c("black", "red"), labels = c("Full Bay", "East of Baccaro")) +
  scale_linetype_manual(values = c(1,2), labels = c("Full Bay", "East of Baccaro")) +
  scale_shape_manual(values = c(1,4), labels = c("Full Bay", "East of Baccaro")) +
  facet_wrap(~area, labeller = as_labeller(facet_names) ) +
  theme(legend.title = element_blank(), legend.position = c(0.82, 0.25))
#save
ggsave(filename = paste0(direct, "/",assessmentyear,"/Assessment/Figures/CommercialData/SFA29_CPUEbyfleet_",fishingyear, ".png"),width = 24,height = 16,units="cm",dpi=400, device = "png")


#CPUE and Effort combined by area (fishery-level)

#Long term medians by area
median.cpue <- ddply(comm.dat.combined[which(comm.dat.combined$year != fishingyear),], .(area), summarise, median = median(cpue.kgh, na.rm = TRUE)) #Create df of median cpue area
median.effort <- ddply(comm.dat.combined[which(comm.dat.combined$year != fishingyear),], .(area), summarise, median = median(effort.fleet.1000h, na.rm = TRUE)) #Create df of median cpue area
medians.area <- merge(median.cpue, median.effort, by = "area")
names(medians.area)<- c("area", "cpue", "effort")
write.csv(medians.area, paste0(direct,"/",assessmentyear,"/Assessment/Data/CommercialData/SFA29_medians_EffortCPUE", fishingyear, ".csv"), row.names = FALSE)

#plot
ggplot(comm.dat.combined) +
  theme_bw(base_size = 16) + theme(panel.grid.minor.x = element_blank()) +  
  theme(axis.line.y.right = element_line(color = "red"), axis.ticks.y.right = element_line(color = "red"), axis.text.y.right = element_text(color = "red"), axis.title.y.right = element_text(color = "red")) +
  geom_point(aes(x = year, y = cpue.kgh)) + 
  geom_line(aes(x = year, y = cpue.kgh)) + 
  geom_point(aes(x = year, y = effort.fleet.1000h*8), color = "red") + 
  geom_line(aes(x = year, y = effort.fleet.1000h*8), color = "red") +
  geom_hline(data=median.cpue, aes(yintercept=median), linetype = "dashed", color = "black") +
  geom_hline(data=median.effort, aes(yintercept=median*8), linetype = "dashed", color = "red") +
  scale_y_continuous("Catch Rate (kg/h)", sec.axis = sec_axis(~./8, name = "Effort (1000h)")) + # 
  scale_x_continuous("Year", breaks=seq(2002,2026,6), limits = c(2000, 2027)) +
  facet_wrap(~area, labeller = as_labeller(facet_names))
#save
ggsave(filename = paste0(direct, "/",assessmentyear,"/Assessment/Figures/CommercialData/SFA29_CPUEandEffort_combined",fishingyear, ".png"), width = 24,height = 16,units='cm', dpi=400, device = "png")


#TAC and Landings

landings.year[is.na(landings.year)] <- 0
landings.year$TAC <- Tac$TAC

#Calculate total landings
landings.year$tot.landings <- landings.year$FB + landings.year$EB + landings.year$Combined + landings.year$FSC

#Melt the dataframe so that it's in long format (TAC and landings in one column, but labelled by type in another column)
landings.year <- reshape2::melt(landings.year, id.vars = "Year")

#Create plot
ggplot() + 
  theme_bw(base_size = 16) + theme(panel.grid=element_blank()) + # white background, no gridlines
  geom_bar(data=landings.year[landings.year$variable%in%c('FB','EB','Combined', 'FSC'),], aes(Year, value, fill=factor(variable, levels = c('FSC','EB', 'FB','Combined'))), colour="black", stat="identity") + # plots the bars
  geom_line(data=landings.year[landings.year$variable == 'TAC',], aes(x = Year, y = value), lwd=0.55) + # adds the overlay line
  scale_y_continuous("Landings (meats, t)", expand = expand_scale(mult = c(0.01,0.1)), breaks=seq(0,800,200)) + # 
  scale_x_continuous("Year", breaks=seq(2001,fishingyear,2)) +
  scale_fill_manual(values=c("grey13","lightskyblue4","white","grey84"), labels=c("Food, Social, and Ceremonial","East of Baccaro", "Full Bay", "Fleets Combined"), name=NULL) +
  annotate(geom="text",label="TAC", x=2004, y= 620) +
  theme(legend.position=c(0.8, 0.8))
#save
ggsave(filename = paste0(direct, "/",assessmentyear,"/Assessment/Figures/CommercialData/SFA29WTACandLandings", fishingyear, ".png"), width = 24,height = 20,units='cm', dpi=400,device = "png")
  
ggplot() + 
  theme_bw(base_size = 16) + theme(panel.grid=element_blank()) + # white background, no gridlines
  geom_bar(data=landings.year[landings.year$variable%in%c('FB','EB','Combined', 'FSC'),], aes(Year, value, fill=factor(variable, levels = c('FSC','EB', 'FB','Combined'))), colour="black", stat="identity") + # plots the bars
  geom_line(data=landings.year[landings.year$variable == 'TAC',], aes(x = Year, y = value), lwd=0.55) + # adds the overlay line
  scale_y_continuous("Débarquements (tonnes de chairs)", expand = expand_scale(mult = c(0.01,0.1)), breaks=seq(0,800,200)) + # 
  scale_x_continuous("Année", breaks=seq(2001,fishingyear,2)) +
  scale_fill_manual(values=c("grey13","lightskyblue4","white","grey84"), labels=c("À des fins alimentaires, sociales et rituelles","Est de Baccaro", "Totalité de la baie", "Total des flottilles"), name=NULL) +
  annotate(geom="text",label="TAC", x=2004, y= 620) +
  theme(legend.position=c(0.75, 0.8))
#save
ggsave(filename = paste0(direct, "/",assessmentyear,"/Assessment/Figures/CommercialData/SFA29WTACandLandings", fishingyear, "_FR.png"), width = 24,height = 20,units='cm', dpi=400,device = "png")


#Landings by SubArea

ggplot() + 
  theme_bw(base_size = 16) + theme(panel.grid=element_blank()) + # white background, no gridlines
  geom_col(data=landings.area, aes(YEAR, Landingsmt)) + # plots the bars
  scale_y_continuous("Landings (meats, t)", expand = expand_scale(mult = c(0.01,0.1)), breaks=seq(0,800,100)) + 
  scale_x_continuous("Year", breaks=seq(2002,fishingyear,4)) +
  facet_wrap(~Area, labeller = as_labeller(facet_names))
ggsave(filename = paste0(direct, "/",assessmentyear,"/Assessment/Figures/CommercialData/SFA29WLandingsbyArea", fishingyear, ".png"), width = 24,height = 20,units='cm', dpi=400,device = "png")

#Landings by SubArea no E
ggplot() + 
  theme_bw(base_size = 16) + theme(panel.grid=element_blank()) + # white background, no gridlines
  geom_col(data=landings.area[landings.area$Area != '29E',], aes(YEAR, Landingsmt)) + # plots the bars
  scale_y_continuous("Landings (meats, t)", expand = expand_scale(mult = c(0.01,0.1)), breaks=seq(0,800,100)) + 
  scale_x_continuous("Year", breaks=seq(2002,fishingyear,4)) +
  facet_wrap(~Area, labeller = as_labeller(facet_names))
ggsave(filename = paste0(direct, "/",assessmentyear,"/Assessment/Figures/CommercialData/SFA29WLandingsbyArea_woE", fishingyear, ".png"), width = 24,height = 20,units='cm', dpi=400,device = "png")


#CPUE by day and subarea
ggplot() +
  geom_point(logs, mapping=aes(x = DATE_FISHED, y = CPUE_KG)) +
  facet_wrap(~ASSIGNED_AREA, labeller = as_labeller(facet_names))

#CPUE boxplot by day and subarea
ggplot(logs, mapping = aes(y = CPUE_KG, x = DATE_FISHED, group = DATE_FISHED)) +
  geom_boxplot() +
  scale_y_continuous("Catch Rate (kg/h)") +
  xlab("Date") +
  facet_wrap(~ASSIGNED_AREA, labeller = as_labeller(facet_names))
#save
ggsave(filename = paste0(direct, "/",assessmentyear,"/Assessment/Figures/CommercialData/SFA29W_CPUEBoxplotbyDate", fishingyear, ".png"), width = 24,height = 20,units='cm', dpi=400,device = "png")
  
#Daily CPUE by subarea

#Calculate daily CPUE
# logs %>%
#   dplyr::select(DATE_FISHED, ASSIGNED_AREA, effort_h, DAY_CATCH_KG) %>%
#   group_by(DATE_FISHED, ASSIGNED_AREA) %>%
#   summarise(Daily_Effort_h = sum(effort_h), Daily_Catch_kg = sum(DAY_CATCH_KG)) 


effort.dat.day <- aggregate(logs$effort_h, by=list(logs$DATE_FISHED, logs$ASSIGNED_AREA), FUN=sum)
names(effort.dat.day) <- c("date","area","effort.hr")

catch.dat.day <-  aggregate(logs$DAY_CATCH_KG, by=list(logs$DATE_FISHED, logs$ASSIGNED_AREA), FUN=sum)
names(catch.dat.day) <- c("date", "area", "catch.kg")

nlogs.day <- aggregate(logs$LOG_SEQ, by=list(logs$DATE_FISHED, logs$ASSIGNED_AREA), FUN=length)
names(nlogs.day) <- c("date", "area", "n")

cpue.date <- merge(merge(effort.dat.day, catch.dat.day, by.x=c("date","area"), by.y=c("date","area")), 
                      nlogs.day, by.x=c("date","area"), by.y=c("date","area"))

#cpue.date$cpue.kgh <- ifelse(cpue.date$n > 5, cpue.date$catch.kg/cpue.date$effort.hr, NA) #for privacy screened cpue
cpue.date$cpue.kgh <- cpue.date$catch.kg/cpue.date$effort.hr # for all cpue
cpue.date <- complete(cpue.date, date, area) #Add NAs for missing date/area combinations

#plot all areas
ggplot(cpue.date, mapping = aes(x = date, y = cpue.kgh)) +
  geom_point() +
  geom_line() +
  scale_x_date("Date", date_labels = "%b") +
  scale_y_continuous("Catch Rate (kg/h)") +
  #geom_smooth(method = "loess", se = FALSE) +
  facet_wrap(~area, labeller = as_labeller(facet_names))
#save
ggsave(filename = paste0(direct, "/",assessmentyear,"/Assessment/Figures/CommercialData/SFA29W_CPUEbyDate", fishingyear, ".png"), width = 24,height = 20,units='cm', dpi=400,device = "png")


#plot C only
ggplot(cpue.date[cpue.date$area == "29C",], mapping = aes(x = date, y = cpue.kgh)) +
  geom_point() +
  geom_line() +
  #geom_smooth(method = "loess", se = FALSE)
  scale_x_date("Day", labels = NULL) +
  scale_y_continuous("Catch Rate (kg/h)")

#### SPATIAL PLOTS ####

#Pecjector basemap with SFA 29W boundaries
p <- pecjector(area = "sfa29",repo ='github',c_sys="ll", gis.repo = 'github', plot=F,plot_as = 'ggplot', add_layer = list(land = "grey", bathy = "ScallopMap", scale.bar = c('bl',0.5, -1, -1)))


#Create raster of mean cpue
for.raster <- subset(logs, YEAR==fishingyear, c('lon','lat','CPUE_KG'))
coordinates(for.raster) <- c("lon", "lat")

r <- raster(ext = extent(poly.sf), resolution = 1/60, crs = CRS('+init=EPSG:4326'))

raster.cpue <- rasterize(for.raster, r, "CPUE_KG", fun = mean)

##convert raster to sf object
df <- (as.data.frame(raster::rasterToPoints(raster.cpue)))
names(df) <- c("lon", "lat", "mean.cpue")

##add sf objects to basemap outside of pecjector
p +
  geom_tile(df, mapping = aes(lon, lat, fill = mean.cpue), color = "grey55") +
  geom_sf(data = poly.subareas, fill=NA, colour="grey55") +
  scale_fill_binned(type = "viridis", direction = -1, name="CPUE (kg/h)", limits = c(0,200), breaks = c(20, 40, 60, 80, 100, 120, 140, 160, 180)) + #make sure limits include entire data range
  annotate("text", x=-66.42, y=43.62, label="A") +  #labels for management subareas, position may need to be adjusted
  annotate("text", x=-66.15, y=43.58, label="B") +
  annotate("text",x=-65.95, y=43.28, label="C") +
  annotate("text",x=-65.6, y=43.28, label="D") +
  annotate("text",x=-66.26, y=43.35, label="E") +
  coord_sf(xlim = c(-66.50,-65.45), ylim = c(43.1,43.8), expand = FALSE) +
  theme(legend.position=c(0.9, 0.84),
        legend.box.background = element_rect(colour = "white", fill = alpha("white", 0.8)),
        legend.title = element_text(size = 10, face = "bold"),
        legend.key.size = unit(0.75, "cm"),
        legend.text = element_text(size = 10),
        panel.border = element_rect(colour = "black", fill=NA, size=1))
#save
ggsave(filename = paste0(direct, "/",assessmentyear,"/Assessment/Figures/CommercialData/SFA29_CPUEgridplot", fishingyear, ".png"), plot = last_plot(), width =24, height = 20, dpi = 400, units = "cm", limitsize = TRUE)


# Make histogram by area for distribution of cpue
histolog<-subset(logs, YEAR == fishingyear, c('ASSIGNED_AREA','CPUE_KG'))

cpuehisto <- ggplot (histolog, aes (x = CPUE_KG)) +
  geom_histogram (breaks = seq (0, 200, by = 5), col = 'grey60') + labs (x = 'CPUE (kg/h)', y = 'Count') +
  facet_wrap (~ASSIGNED_AREA, ncol = 1) +
  scale_x_continuous(breaks = seq (0, 200, by = 20)) +
  theme_bw() +
  theme(panel.grid=element_blank())
cpuehisto

tapply(histolog$CPUE_KG, histolog$ASSIGNED_AREA, summary)


#Catch Grid Plot

#Create raster of cumulative catch
for.raster <- subset(logs, YEAR==fishingyear, c('lon','lat','DAY_CATCH_KG'))
coordinates(for.raster) <- c("lon", "lat")

r <- raster(ext = extent(poly.sf), resolution = 1/60, crs = CRS('+init=EPSG:4326'))

raster.data <- rasterize(for.raster, r, "DAY_CATCH_KG", fun = sum)

##convert raster to sf object
df <- (as.data.frame(raster::rasterToPoints(raster.data)))
names(df) <- c("lon", "lat", "tot.catch")

##add sf objects to basemap outside of pecjector
p +
  geom_tile(df, mapping = aes(lon, lat, fill = tot.catch), color = "grey55") +
  geom_sf(data = poly.subareas, fill=NA, colour="grey55") +
  scale_fill_binned(type = "viridis", direction = -1, name="Catch (kg)") +
  annotate("text", x=-66.42, y=43.62, label="A") +  #labels for management subareas, position may need to be adjusted, or text colour can be faded
  annotate("text", x=-66.2, y=43.58, label="B") +
  annotate("text",x=-65.95, y=43.28, label="C") +
  annotate("text",x=-65.6, y=43.31, label="D") +
  annotate("text",x=-66.26, y=43.35, label="E") +
  coord_sf(xlim = c(-66.50,-65.45), ylim = c(43.1,43.8), expand = FALSE) +
  theme(legend.position=c(0.85, 0.80),
        legend.box.background = element_rect(colour = "white", fill = alpha("white", 0.8)),
        legend.title = element_text(size = 10, face = "bold"),
        legend.text = element_text(size = 10))
#save
ggsave(filename = paste0(direct, "/",assessmentyear,"/Assessment/Figures/CommercialData/SFA29_Catchgridplot", fishingyear, ".png"), plot = last_plot(), width =24, height = 20, dpi = 400, units = "cm", limitsize = TRUE)



#Effort Grid Plot

#Create raster of cumulative effort
for.raster <- subset(logs, YEAR==fishingyear, c('lon','lat','effort_h'))
coordinates(for.raster) <- c("lon", "lat")

r <- raster(ext = extent(poly.sf), resolution = 1/60, crs = CRS('+init=EPSG:4326'))

raster.data <- rasterize(for.raster, r, "effort_h", fun = sum)

##convert raster to sf object
df <- (as.data.frame(raster::rasterToPoints(raster.data)))
names(df) <- c("lon", "lat", "tot.effort")

p +
  geom_tile(df, mapping = aes(lon, lat, fill = tot.effort), color = "grey55") +
  geom_sf(data = poly.subareas, fill=NA, colour="grey55") +
  scale_fill_binned(type = "viridis", direction = -1, name="Effort (h)", n.breaks = 6) +
  annotate("text", x=-66.42, y=43.62, label="A") +  #labels for management subareas, position may need to be adjusted, or text colour can be faded
  annotate("text", x=-66.2, y=43.58, label="B") +
  annotate("text",x=-65.95, y=43.28, label="C") +
  annotate("text",x=-65.6, y=43.31, label="D") +
  annotate("text",x=-66.26, y=43.35, label="E") +
  coord_sf(xlim = c(-66.50,-65.45), ylim = c(43.1,43.8), expand = FALSE) +
  theme(legend.position=c(0.85, 0.80),
        legend.box.background = element_rect(colour = "white", fill = alpha("white", 0.8)),
        legend.title = element_text(size = 10, face = "bold"),
        legend.text = element_text(size = 10))

#save
ggsave(filename = paste0(direct, "/",assessmentyear,"/Assessment/Figures/CommercialData/SFA29_Effortgridplot", fishingyear, ".png"), plot = last_plot(), width =24, height = 20, dpi = 400, units = "cm", limitsize = TRUE)

