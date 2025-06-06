## Pull together file for model 
# Dec 2021 


options(stringsAsFactors=FALSE)
library(tidyverse)
library(ggplot2)
library(openxlsx)
library(compareDF)

surveyyear <- 2024  #This is the last survey year for which you want to include  - note should match year of cruise below 
cruise <- "SFA292024"  #note should match year for surveyyear set above 
assessmentyear <- 2025 #year in which you are conducting the survey 
path.directory <- "Y:/Inshore/SFA29/"
years <- c(2001:surveyyear)

Catch <- read.csv(paste0(path.directory, assessmentyear, "/Assessment/Data/CommercialData/SFA29_totalLandings_YearSubarea.csv"))

clappers.obs.phi <- read.csv(paste0(path.directory, assessmentyear, "/Assessment/Data/SurveyIndices/clappers.obs.phi.2001to",surveyyear,".csv"))

Ih.obs.tau <- read.csv(paste0(path.directory, assessmentyear, "/Assessment/Data/SurveyIndices/Ih.obs.tau.2001to",surveyyear,".csv"))

L <- read.csv(paste0(path.directory, assessmentyear, "/Assessment/Data/SurveyIndices/L.2001to",surveyyear,".csv"))

rh.obs.nu <- read.csv(paste0(path.directory, assessmentyear, "/Assessment/Data/SurveyIndices/rh.obs.nu.2001to",surveyyear,".csv")) 

wk <- read.csv(paste0(path.directory, assessmentyear, "/Assessment/Data/Growth/Condition.105mmSH.wk.",surveyyear,".csv")) 

growth <- read.csv(paste0(path.directory, assessmentyear, "/Assessment/Data/Growth/growth.actual.2001to",surveyyear,".csv")) 

vms <- read.csv(paste0(path.directory, assessmentyear, "/Assessment/Data/CommercialData/VMS/effort.strata.",surveyyear,".csv") ) 
unique(vms$subarea)
vms$subarea.name <- paste0("SFA29",vms$subarea)
vms$YearAlignedforModel <- vms$year-1


head(Catch)                
head(clappers.obs.phi)
head(Ih.obs.tau)
head(L)
head(rh.obs.nu)
head(wk)
head(growth)
head(vms)

# --- Subarea A ---- 
area <- "SFA29A"

Ih.obs.tau.Subarea <- Ih.obs.tau %>% filter(SUBAREA == area ) %>% select(SUBAREA, Strata, YEAR, Ih, obs.tau = CV)
Ih.obs.tau.Subarea 
Ih.2001to2013 <- data.frame(SUBAREA = rep(area, 13*2), Strata = c(rep("low",13),rep("med",13)), YEAR = rep(2001:2013,2), Ih = rep(NA,13*2), obs.tau = rep(NA,13*2)) 
Ih.Subarea <- rbind(Ih.2001to2013, Ih.obs.tau.Subarea)
Ih.Subarea <- Ih.Subarea %>% arrange(SUBAREA, Strata, YEAR)
Ih.Subarea


rh.obs.nu.Subarea <- rh.obs.nu %>% filter(SUBAREA == area ) %>% select(SUBAREA, Strata, YEAR, rh, obs.nu = CV)
model.data.Subarea <- merge(Ih.Subarea, rh.obs.nu.Subarea, by = c("YEAR", "SUBAREA", "Strata"))
model.data.Subarea <- model.data.Subarea %>% arrange(SUBAREA, Strata, YEAR)
model.data.Subarea


clappers.obs.phi.Subarea <- clappers.obs.phi %>% filter(SUBAREA == area ) %>% select(SUBAREA, Strata, YEAR, clappers, obs.phi = CV)
model.data.Subarea <- merge(model.data.Subarea, clappers.obs.phi.Subarea, by = c("YEAR", "SUBAREA", "Strata"))
model.data.Subarea <- model.data.Subarea %>% arrange(SUBAREA, Strata, YEAR)
model.data.Subarea

      
L.Subarea <- L %>% filter(SUBAREA == area ) %>% select(SUBAREA, Strata, YEAR, L)
model.data.Subarea <- merge(model.data.Subarea, L.Subarea, by = c("YEAR", "SUBAREA", "Strata"))
model.data.Subarea <- model.data.Subarea %>% arrange(SUBAREA, Strata, YEAR)
model.data.Subarea

##!! Missing 2001 growth - or how it's lined up ? In growth file looks like 2013 value is missing and data actually start from 2001 not 2002 -- if want to line up with model files -- check other areas 
gh.Subarea <- growth %>% select(SUBAREA = strata, Strata = sdm, YEAR = Year, gh = rate, Age) %>% filter(Age == "Commercial" & SUBAREA == area & Strata %in% c("low","medium") ) ## Change GR script to this is cleaner 
gh.Subarea$Strata[gh.Subarea$Strata == "medium"] <- "med"

model.data.Subarea <- merge(model.data.Subarea, gh.Subarea, by = c("YEAR", "SUBAREA", "Strata"))
model.data.Subarea <- model.data.Subarea %>% arrange(SUBAREA, Strata, YEAR)
model.data.Subarea <- model.data.Subarea %>% select(!Age)
model.data.Subarea

#vms 
vms.subarea <- vms %>% select(SUBAREA = subarea.name, Strata = sdmstrata, YEAR = YearAlignedforModel, VMSEffort = corr.effort.hr) %>% filter(SUBAREA == area & Strata %in% c("med","low")) 
#model.data.Subarea$VMSEffort <- NA 
model.data.Subarea <- merge(model.data.Subarea, vms.subarea, by = c("YEAR", "SUBAREA","Strata"), all.x = TRUE)
model.data.Subarea <- model.data.Subarea %>% arrange(SUBAREA, Strata, YEAR)
model.data.Subarea

#Catch
Catch.Subarea <-  Catch %>% filter(Area == substr(area, 4, 6)) %>% mutate(Strata = "low") 
Catch.Subarea <- Catch.Subarea %>% mutate(Catch.actual = Landingsmt) %>% select(YEAR, Strata, Catch.actual) 
Catch.Subarea <- rbind(data.frame(YEAR = 2001, Strata = "low", Catch.actual = NA), Catch.Subarea)
model.data.Subarea <- merge(model.data.Subarea, Catch.Subarea, by = c("YEAR", "Strata"), all.x = TRUE)
model.data.Subarea <- model.data.Subarea %>% arrange(SUBAREA, Strata, YEAR)
model.data.Subarea

#wk 
wk.Subarea <- wk %>% select(YEAR, SUBAREA = AREA, wk = Condition_105mmSH) %>% filter(SUBAREA == area ) 
wk.other.years <- data.frame(YEAR = 2001:surveyyear-1, SUBAREA = rep(area,length(2001:surveyyear-1)), wk = rep(NA, length(2001:surveyyear-1)))
wk.Subarea <- rbind(wk.other.years, wk.Subarea) 
wk.Subarea <- wk.Subarea %>% arrange(YEAR, SUBAREA)
wk.Subarea$Strata <- "low"
wk.Subarea

model.data.Subarea <- merge(model.data.Subarea, wk.Subarea, by = c("YEAR", "Strata", "SUBAREA"), all.x = TRUE)
model.data.Subarea <- model.data.Subarea %>% arrange(SUBAREA, Strata, YEAR)
model.data.Subarea

#Reorder 
model.data.for.subarea <- model.data.Subarea %>%  select(SUBAREA, Year = YEAR, Catch.actual, wk, Strata, Ih, obs.tau, rh, obs.nu, clappers,  obs.phi, L, VMSEffort, gh)  
#write.csv(model.data.for.subarea, paste0(path.directory, assessmentyear,"/Assessment/Data/Model/SFA29A_ModelData.",surveyyear,".csv"), row.names = FALSE ) 


## Compare to last years data and create final model file 
old <- read.csv(paste0(path.directory,assessmentyear-1,"/Assessment/Data/Model/",area,"/",area,"_ModelData.",surveyyear-1,".csv"))

# do the comparisons and save out the table
output <- compare_df(df_new = model.data.for.subarea, df_old=old, group_col =  c("Year", "Strata"))
create_output_table(output, output_type = "xlsx", file_name=paste0(path.directory,assessmentyear,"/Assessment/Data/Model/",area,".ModelData.Compare.",surveyyear,".xlsx"))

#join so have right number of rows for years - keeps all old data but adds the row for the current year 
revised <- left_join(dplyr::select(model.data.for.subarea, SUBAREA, Strata, Year), old)
#add current year data 
#For low strata - note only low strata have "Catch.actual", "wk"
revised[revised$Year==surveyyear & revised$Strata == "low", c("Catch.actual", "wk", "Ih", "obs.tau", "rh", "obs.nu", "clappers", "obs.phi", "L", "VMSEffort", "gh")] <- 
  model.data.for.subarea[model.data.for.subarea$Year==surveyyear & revised$Strata == "low", c("Catch.actual", "wk", "Ih", "obs.tau", "rh", "obs.nu", "clappers", "obs.phi", "L", "VMSEffort", "gh")]
#For med strata 
revised[revised$Year==surveyyear & revised$Strata == "med", c( "Ih", "obs.tau", "rh", "obs.nu", "clappers", "obs.phi", "L", "VMSEffort", "gh")] <- 
  model.data.for.subarea[model.data.for.subarea$Year==surveyyear & revised$Strata == "med", c( "Ih", "obs.tau", "rh", "obs.nu", "clappers", "obs.phi", "L", "VMSEffort", "gh")]
#For high strata - no high for A 

#for vms effort - it's offset a year so want to keep previous years values - and for 2022 assessment - put in 2 year worth of values 
revised$VMSEffort[revised$Year == surveyyear-1 & revised$Strata == "low"] <- model.data.for.subarea$VMSEffort[model.data.for.subarea$Year == surveyyear-1 & model.data.for.subarea$Strata == "low"] 
revised$VMSEffort[revised$Year == surveyyear-1 & revised$Strata == "med"] <- model.data.for.subarea$VMSEffort[model.data.for.subarea$Year == surveyyear-1 & model.data.for.subarea$Strata == "med"] 

#write out data for model 
revised <- revised %>%  select(SUBAREA, Year , Catch.actual, wk, Strata, Ih, obs.tau, rh, obs.nu, clappers,  obs.phi, L, VMSEffort, gh)  
write.csv(revised, paste0(path.directory, assessmentyear,"/Assessment/Data/Model/",area,"_ModelData.",surveyyear,".csv"), row.names = FALSE ) 

##
# --- Subarea B ---- 
area <- "SFA29B"

Ih.obs.tau.Subarea <- Ih.obs.tau %>% filter(SUBAREA == area ) %>% select(SUBAREA, Strata, YEAR, Ih, obs.tau = CV)
Ih.obs.tau.Subarea 
Ih.2001to2013 <- data.frame(SUBAREA = rep(area, 13*3), Strata = c(rep("low",13),rep("med",13),rep("high",13)), YEAR = rep(2001:2013,3), Ih = rep(NA,13*3), obs.tau = rep(NA,13*3)) 
Ih.Subarea <- rbind(Ih.2001to2013, Ih.obs.tau.Subarea)
Ih.Subarea <- Ih.Subarea %>% arrange(SUBAREA, Strata, YEAR)
Ih.Subarea

rh.obs.nu.Subarea <- rh.obs.nu %>% filter(SUBAREA == area ) %>% select(SUBAREA, Strata, YEAR, rh, obs.nu = CV)
model.data.Subarea <- merge(Ih.Subarea, rh.obs.nu.Subarea, by = c("YEAR", "SUBAREA", "Strata"))
model.data.Subarea <- model.data.Subarea %>% arrange(SUBAREA, Strata, YEAR)
model.data.Subarea

clappers.obs.phi.Subarea <- clappers.obs.phi %>% filter(SUBAREA == area ) %>% select(SUBAREA, Strata, YEAR, clappers, obs.phi = CV)
model.data.Subarea <- merge(model.data.Subarea, clappers.obs.phi.Subarea, by = c("YEAR", "SUBAREA", "Strata"))
model.data.Subarea <- model.data.Subarea %>% arrange(SUBAREA, Strata, YEAR)
model.data.Subarea


L.Subarea <- L %>% filter(SUBAREA == area ) %>% select(SUBAREA, Strata, YEAR, L)
model.data.Subarea <- merge(model.data.Subarea, L.Subarea, by = c("YEAR", "SUBAREA", "Strata"))
model.data.Subarea <- model.data.Subarea %>% arrange(SUBAREA, Strata, YEAR)
model.data.Subarea


gh.Subarea <- growth %>% select(SUBAREA = strata, Strata = sdm, YEAR = Year, gh = rate, Age) %>% filter(Age == "Commercial" & SUBAREA == area & Strata %in% c("low","medium","high") ) ## Change GR script to this is cleaner 
gh.Subarea$Strata[gh.Subarea$Strata == "medium"] <- "med"

model.data.Subarea <- merge(model.data.Subarea, gh.Subarea, by = c("YEAR", "SUBAREA", "Strata"))
model.data.Subarea <- model.data.Subarea %>% arrange(SUBAREA, Strata, YEAR)
model.data.Subarea <- model.data.Subarea %>% select(!Age)
model.data.Subarea

#vms 
vms.subarea <- vms %>% select(SUBAREA = subarea.name, Strata = sdmstrata, YEAR = YearAlignedforModel, VMSEffort = corr.effort.hr) %>% filter(SUBAREA == area & Strata %in% c("med","low","high")) 
#model.data.Subarea$VMSEffort <- NA 
model.data.Subarea <- merge(model.data.Subarea, vms.subarea, by = c("YEAR", "SUBAREA","Strata"), all.x = TRUE)
model.data.Subarea <- model.data.Subarea %>% arrange(SUBAREA, Strata, YEAR)
model.data.Subarea

#Catch
Catch.Subarea <-  Catch %>% filter(Area == substr(area, 4, 6)) %>% mutate(Strata = "high") 
Catch.Subarea <- Catch.Subarea %>% mutate(Catch.actual = Landingsmt) %>% select(YEAR, Strata, Catch.actual) 
Catch.Subarea <- rbind(data.frame(YEAR = 2001, Strata = "low", Catch.actual = NA), Catch.Subarea)
model.data.Subarea <- merge(model.data.Subarea, Catch.Subarea, by = c("YEAR", "Strata"), all.x = TRUE)
model.data.Subarea <- model.data.Subarea %>% arrange(SUBAREA, Strata, YEAR)
model.data.Subarea

#wk
wk.Subarea <- wk %>% select(YEAR, SUBAREA = AREA, wk = Condition_105mmSH) %>% filter(SUBAREA == area ) 
wk.other.years <- data.frame(YEAR = 2001:surveyyear-1, SUBAREA = rep(area,length(2001:surveyyear-1)), wk = rep(NA, length(2001:surveyyear-1)))
wk.Subarea <- rbind(wk.other.years, wk.Subarea) 
wk.Subarea <- wk.Subarea %>% arrange(YEAR, SUBAREA)
wk.Subarea$Strata <- "high"
wk.Subarea

model.data.Subarea <- merge(model.data.Subarea, wk.Subarea, by = c("YEAR", "Strata", "SUBAREA"), all.x = TRUE)
model.data.Subarea <- model.data.Subarea %>% arrange(SUBAREA, Strata, YEAR)
#model.data.Subarea <- model.data.Subarea %>% arrange(match(Strata, c("low", "med", "high"))) 
model.data.Subarea

#Reorder 
model.data.for.subarea <- model.data.Subarea %>%  select(SUBAREA, Year = YEAR, Catch.actual, wk, Strata, Ih, obs.tau, rh, obs.nu, clappers,  obs.phi, L, VMSEffort, gh)  
#write.csv(model.data.for.subarea, paste0(path.directory, assessmentyear,"/Assessment/Data/Model/SFA29A_ModelData.",surveyyear,".csv"), row.names = FALSE ) 
model.data.for.subarea


## Compare to last years data and create final model file 
old <- read.csv(paste0(path.directory,assessmentyear-1,"/Assessment/Data/Model/",area,"/",area,"_ModelData.",surveyyear-1,".csv"))

# do the comparisons and save out the table
output <- compare_df(df_new = model.data.for.subarea, df_old=old, group_col = c("Year", "Strata")) 
create_output_table(output, output_type = "xlsx", file_name=paste0(path.directory,assessmentyear,"/Assessment/Data/Model/",area,".ModelData.Compare.",surveyyear,".xlsx"))


#join so have right number of rows for years - keeps all old data but adds the row for the current year 
revised <- left_join(dplyr::select(model.data.for.subarea, SUBAREA, Strata, Year), old)


#add current year data 
#For high strata - note only high strata have "Catch.actual", "wk"
revised[revised$Year==surveyyear & revised$Strata == "high", c("Catch.actual", "wk", "Ih", "obs.tau", "rh", "obs.nu", "clappers", "obs.phi", "L", "VMSEffort", "gh")] <- 
  model.data.for.subarea[model.data.for.subarea$Year==surveyyear & revised$Strata == "high", c("Catch.actual", "wk", "Ih", "obs.tau", "rh", "obs.nu", "clappers", "obs.phi", "L", "VMSEffort", "gh")]

revised[revised$Year==surveyyear & revised$Strata == "med", c("Catch.actual", "wk", "Ih", "obs.tau", "rh", "obs.nu", "clappers", "obs.phi", "L", "VMSEffort", "gh")] <- 
  model.data.for.subarea[model.data.for.subarea$Year==surveyyear & revised$Strata == "med", c("Catch.actual", "wk", "Ih", "obs.tau", "rh", "obs.nu", "clappers", "obs.phi", "L", "VMSEffort", "gh")]

#For low strata - no high for A 
revised[revised$Year==surveyyear & revised$Strata == "low", c("Catch.actual", "wk", "Ih", "obs.tau", "rh", "obs.nu", "clappers", "obs.phi", "L", "VMSEffort", "gh")] <- 
  model.data.for.subarea[model.data.for.subarea$Year==surveyyear & revised$Strata == "low", c("Catch.actual", "wk", "Ih", "obs.tau", "rh", "obs.nu", "clappers", "obs.phi", "L", "VMSEffort", "gh")]


#for vms effort - it's offset a year so want to keep previous years values - and for 2022 assessment - put in 2 year worth of values 
revised$VMSEffort[revised$Year == surveyyear-1 & revised$Strata == "low"] <- model.data.for.subarea$VMSEffort[model.data.for.subarea$Year == surveyyear-1 & model.data.for.subarea$Strata == "low"]
revised$VMSEffort[revised$Year == surveyyear-1 & revised$Strata == "med"] <- model.data.for.subarea$VMSEffort[model.data.for.subarea$Year == surveyyear-1 & model.data.for.subarea$Strata == "med"]
revised$VMSEffort[revised$Year == surveyyear-1 & revised$Strata == "high"] <- model.data.for.subarea$VMSEffort[model.data.for.subarea$Year == surveyyear-1 & model.data.for.subarea$Strata == "high"]


#Note: For 2022 - 0 recruits for low in B -- as per process for this situation (since can't have 0 in model or NA for obs.nu) set rh = 0.001	obs.nu = 0.009950331 (note this often happens in subarea A). Rh gets set to 0.001 in model_final.R script.
#revised$obs.nu[revised$Year == 2022 & revised$Strata == "low"] <- 0.009950331

#write out data for model 
revised <- revised %>%  select(SUBAREA, Year , Catch.actual, wk, Strata, Ih, obs.tau, rh, obs.nu, clappers,  obs.phi, L, VMSEffort, gh)  
write.csv(revised, paste0(path.directory, assessmentyear,"/Assessment/Data/Model/",area,"_ModelData.",surveyyear,".csv"), row.names = FALSE ) 

##
# --- Subarea C ---- 
area <- "SFA29C"

Ih.obs.tau.Subarea <- Ih.obs.tau %>% filter(SUBAREA == area ) %>% select(SUBAREA, Strata, YEAR, Ih, obs.tau = CV)
Ih.obs.tau.Subarea 
Ih.2001to2013 <- data.frame(SUBAREA = rep(area, 13*3), Strata = c(rep("low",13),rep("med",13),rep("high",13)), YEAR = rep(2001:2013,3), Ih = rep(NA,13*3), obs.tau = rep(NA,13*3)) 
Ih.Subarea <- rbind(Ih.2001to2013, Ih.obs.tau.Subarea)
Ih.Subarea <- Ih.Subarea %>% arrange(SUBAREA, Strata, YEAR)
Ih.Subarea

rh.obs.nu.Subarea <- rh.obs.nu %>% filter(SUBAREA == area ) %>% select(SUBAREA, Strata, YEAR, rh, obs.nu = CV)
model.data.Subarea <- merge(Ih.Subarea, rh.obs.nu.Subarea, by = c("YEAR", "SUBAREA", "Strata"))
model.data.Subarea <- model.data.Subarea %>% arrange(SUBAREA, Strata, YEAR)
model.data.Subarea

clappers.obs.phi.Subarea <- clappers.obs.phi %>% filter(SUBAREA == area ) %>% select(SUBAREA, Strata, YEAR, clappers, obs.phi = CV)
model.data.Subarea <- merge(model.data.Subarea, clappers.obs.phi.Subarea, by = c("YEAR", "SUBAREA", "Strata"))
model.data.Subarea <- model.data.Subarea %>% arrange(SUBAREA, Strata, YEAR)
model.data.Subarea


L.Subarea <- L %>% filter(SUBAREA == area ) %>% select(SUBAREA, Strata, YEAR, L)
model.data.Subarea <- merge(model.data.Subarea, L.Subarea, by = c("YEAR", "SUBAREA", "Strata"))
model.data.Subarea <- model.data.Subarea %>% arrange(SUBAREA, Strata, YEAR)
model.data.Subarea


gh.Subarea <- growth %>% select(SUBAREA = strata, Strata = sdm, YEAR = Year, gh = rate, Age) %>% filter(Age == "Commercial" & SUBAREA == area & Strata %in% c("low","medium","high") ) ## Change GR script to this is cleaner 
gh.Subarea$Strata[gh.Subarea$Strata == "medium"] <- "med"

model.data.Subarea <- merge(model.data.Subarea, gh.Subarea, by = c("YEAR", "SUBAREA", "Strata"))
model.data.Subarea <- model.data.Subarea %>% arrange(SUBAREA, Strata, YEAR)
model.data.Subarea <- model.data.Subarea %>% select(!Age)
model.data.Subarea

#vms 
vms.subarea <- vms %>% select(SUBAREA = subarea.name, Strata = sdmstrata, YEAR = YearAlignedforModel, VMSEffort = corr.effort.hr) %>% filter(SUBAREA == area & Strata %in% c("med","low","high")) 
#model.data.Subarea$VMSEffort <- NA 
model.data.Subarea <- merge(model.data.Subarea, vms.subarea, by = c("YEAR", "SUBAREA","Strata"), all.x = TRUE)
model.data.Subarea <- model.data.Subarea %>% arrange(SUBAREA, Strata, YEAR)
model.data.Subarea

#Catch
Catch.Subarea <-  Catch %>% filter(Area == substr(area, 4, 6)) %>% mutate(Strata = "high") 
Catch.Subarea <- Catch.Subarea %>% mutate(Catch.actual = Landingsmt) %>% select(YEAR, Strata, Catch.actual) 
Catch.Subarea <- rbind(data.frame(YEAR = 2001, Strata = "low", Catch.actual = NA), Catch.Subarea)
model.data.Subarea <- merge(model.data.Subarea, Catch.Subarea, by = c("YEAR", "Strata"), all.x = TRUE)
model.data.Subarea <- model.data.Subarea %>% arrange(SUBAREA, Strata, YEAR)
model.data.Subarea

#Wk
wk.Subarea <- wk %>% select(YEAR, SUBAREA = AREA, wk = Condition_105mmSH) %>% filter(SUBAREA == area ) 
wk.other.years <- data.frame(YEAR = 2001:surveyyear-1, SUBAREA = rep(area,length(2001:surveyyear-1)), wk = rep(NA, length(2001:surveyyear-1)))
wk.Subarea <- rbind(wk.other.years, wk.Subarea) 
wk.Subarea <- wk.Subarea %>% arrange(YEAR, SUBAREA)
wk.Subarea$Strata <- "high"
wk.Subarea


model.data.Subarea <- merge(model.data.Subarea, wk.Subarea, by = c("YEAR", "Strata", "SUBAREA"), all.x = TRUE)
model.data.Subarea <- model.data.Subarea %>% arrange(SUBAREA, Strata, YEAR)
#model.data.Subarea <- model.data.Subarea %>% arrange(match(Strata, c("low", "med", "high"))) 
model.data.Subarea

#Reorder 
model.data.for.subarea <- model.data.Subarea %>%  select(SUBAREA, Year = YEAR, Catch.actual, wk, Strata, Ih, obs.tau, rh, obs.nu, clappers,  obs.phi, L, VMSEffort, gh)  
#write.csv(model.data.for.subarea, paste0(path.directory, assessmentyear,"/Assessment/Data/Model/SFA29A_ModelData.",surveyyear,".csv"), row.names = FALSE ) 
model.data.for.subarea

## Compare to last years data and create final model file 
old <- read.csv(paste0(path.directory,assessmentyear-1,"/Assessment/Data/Model/",area,"/",area,"_ModelData.",surveyyear-1,".csv"))

# do the comparisons and save out the table
output <- compare_df(df_new = model.data.for.subarea, df_old=old, group_col = c("Year", "Strata")) 
create_output_table(output, output_type = "xlsx", file_name=paste0(path.directory,assessmentyear,"/Assessment/Data/Model/",area,".ModelData.Compare.",surveyyear,".xlsx"))

#join so have right number of rows for years - keeps all old data but adds the row for the current year 
revised <- left_join(dplyr::select(model.data.for.subarea, SUBAREA, Strata, Year), old)

#add current year data 
#For high strata - note only high strata have "Catch.actual", "wk"
revised[revised$Year==surveyyear & revised$Strata == "high", c("Catch.actual", "wk", "Ih", "obs.tau", "rh", "obs.nu", "clappers", "obs.phi", "L", "VMSEffort", "gh")] <- 
  model.data.for.subarea[model.data.for.subarea$Year==surveyyear & revised$Strata == "high", c("Catch.actual", "wk", "Ih", "obs.tau", "rh", "obs.nu", "clappers", "obs.phi", "L", "VMSEffort", "gh")]

revised[revised$Year==surveyyear & revised$Strata == "med", c("Catch.actual", "wk", "Ih", "obs.tau", "rh", "obs.nu", "clappers", "obs.phi", "L", "VMSEffort", "gh")] <- 
  model.data.for.subarea[model.data.for.subarea$Year==surveyyear & revised$Strata == "med", c("Catch.actual", "wk", "Ih", "obs.tau", "rh", "obs.nu", "clappers", "obs.phi", "L", "VMSEffort", "gh")]
#For low strata - no high for A 
revised[revised$Year==surveyyear & revised$Strata == "low", c("Catch.actual", "wk", "Ih", "obs.tau", "rh", "obs.nu", "clappers", "obs.phi", "L", "VMSEffort", "gh")] <- 
  model.data.for.subarea[model.data.for.subarea$Year==surveyyear & revised$Strata == "low", c("Catch.actual", "wk", "Ih", "obs.tau", "rh", "obs.nu", "clappers", "obs.phi", "L", "VMSEffort", "gh")]



#for vms effort - it's offset a year so want to keep previous years values

revised$VMSEffort[revised$Year == surveyyear-1 & revised$Strata == "low"] <- model.data.for.subarea$VMSEffort[model.data.for.subarea$Year == surveyyear-1 & model.data.for.subarea$Strata == "low"]
revised$VMSEffort[revised$Year == surveyyear-1 & revised$Strata == "med"] <- model.data.for.subarea$VMSEffort[model.data.for.subarea$Year == surveyyear-1 & model.data.for.subarea$Strata == "med"]
revised$VMSEffort[revised$Year == surveyyear-1 & revised$Strata == "high"] <- model.data.for.subarea$VMSEffort[model.data.for.subarea$Year == surveyyear-1 & model.data.for.subarea$Strata == "high"]

revised

#Note: For 2023 - 0 commercial and recruits and clappers for low in C  -- as per process for this situation (since can't have 0 in model or NA for obs.nu) set rh = 0.001	obs.nu = 0.009950331, clappers = 0.001 and obs.phi = 0.009950331 (note this often happens in subarea A). Rh and clappers gets set to 0.001 in model_final.R script.
#revised$obs.nu[revised$Year == 2022 & revised$Strata == "low"] <- 0.009950331
#revised$obs.phi[revised$Year == 2022 & revised$Strata == "low"] <- 0.009950331

revised$obs.tau[revised$Year == 2023 & revised$Strata == "low"] <- 0.009950331
revised$obs.nu[revised$Year == 2023 & revised$Strata == "low"] <- 0.009950331
revised$obs.phi[revised$Year == 2023 & revised$Strata == "low"] <- 0.009950331

#write out data for model 
revised <- revised %>%  select(SUBAREA, Year , Catch.actual, wk, Strata, Ih, obs.tau, rh, obs.nu, clappers,  obs.phi, L, VMSEffort, gh)  
write.csv(revised, paste0(path.directory, assessmentyear,"/Assessment/Data/Model/",area,"_ModelData.",surveyyear,".csv"), row.names = FALSE ) 


##
# --- Subarea D ---- 
area <- "SFA29D"

Ih.obs.tau.Subarea <- Ih.obs.tau %>% filter(SUBAREA == area ) %>% dplyr::select(SUBAREA, Strata, YEAR, Ih, obs.tau = CV)
Ih.obs.tau.Subarea 
Ih.2001to2013 <- data.frame(SUBAREA = rep(area, 13*3), Strata = c(rep("low",13),rep("med",13),rep("high",13)), YEAR = rep(2001:2013,3), Ih = rep(NA,13*3), obs.tau = rep(NA,13*3)) 
Ih.Subarea <- rbind(Ih.2001to2013, Ih.obs.tau.Subarea)
Ih.Subarea <- Ih.Subarea %>% arrange(SUBAREA, Strata, YEAR)
Ih.Subarea

rh.obs.nu.Subarea <- rh.obs.nu %>% filter(SUBAREA == area ) %>% dplyr::select(SUBAREA, Strata, YEAR, rh, obs.nu = CV)
model.data.Subarea <- merge(Ih.Subarea, rh.obs.nu.Subarea, by = c("YEAR", "SUBAREA", "Strata"))
model.data.Subarea <- model.data.Subarea %>% arrange(SUBAREA, Strata, YEAR)
model.data.Subarea

clappers.obs.phi.Subarea <- clappers.obs.phi %>% filter(SUBAREA == area ) %>% dplyr::select(SUBAREA, Strata, YEAR, clappers, obs.phi = CV)
model.data.Subarea <- merge(model.data.Subarea, clappers.obs.phi.Subarea, by = c("YEAR", "SUBAREA", "Strata"))
model.data.Subarea <- model.data.Subarea %>% arrange(SUBAREA, Strata, YEAR)
model.data.Subarea


L.Subarea <- L %>% filter(SUBAREA == area ) %>% dplyr::select(SUBAREA, Strata, YEAR, L)
model.data.Subarea <- merge(model.data.Subarea, L.Subarea, by = c("YEAR", "SUBAREA", "Strata"))
model.data.Subarea <- model.data.Subarea %>% arrange(SUBAREA, Strata, YEAR)
model.data.Subarea


gh.Subarea <- growth %>% dplyr::select(SUBAREA = strata, Strata = sdm, YEAR = Year, gh = rate, Age) %>% filter(Age == "Commercial" & SUBAREA == area & Strata %in% c("low","medium","high") ) ## Change GR script to this is cleaner 
gh.Subarea$Strata[gh.Subarea$Strata == "medium"] <- "med"

model.data.Subarea <- merge(model.data.Subarea, gh.Subarea, by = c("YEAR", "SUBAREA", "Strata"))
model.data.Subarea <- model.data.Subarea %>% arrange(SUBAREA, Strata, YEAR)
model.data.Subarea <- model.data.Subarea %>% dplyr::select(!Age)
model.data.Subarea

#vms 
vms.subarea <- vms %>% dplyr::select(SUBAREA = subarea.name, Strata = sdmstrata, YEAR = YearAlignedforModel, VMSEffort = corr.effort.hr) %>% filter(SUBAREA == area & Strata %in% c("med","low","high")) 
#model.data.Subarea$VMSEffort <- NA 
model.data.Subarea <- merge(model.data.Subarea, vms.subarea, by = c("YEAR", "SUBAREA","Strata"), all.x = TRUE)
model.data.Subarea <- model.data.Subarea %>% arrange(SUBAREA, Strata, YEAR)
model.data.Subarea

Catch.Subarea <-  Catch %>% filter(Area == substr(area, 4, 6)) %>% mutate(Strata = "high") 
Catch.Subarea <- Catch.Subarea %>% mutate(Catch.actual = Landingsmt) %>% dplyr::select(YEAR, Strata, Catch.actual) 
Catch.Subarea <- rbind(data.frame(YEAR = 2001, Strata = "low", Catch.actual = NA), Catch.Subarea)
model.data.Subarea <- merge(model.data.Subarea, Catch.Subarea, by = c("YEAR", "Strata"), all.x = TRUE)
model.data.Subarea <- model.data.Subarea %>% arrange(SUBAREA, Strata, YEAR)
model.data.Subarea


wk.Subarea <- wk %>% dplyr::select(YEAR, SUBAREA = AREA, wk = Condition_105mmSH) %>% filter(SUBAREA == area ) 
wk.other.years <- data.frame(YEAR = 2001:surveyyear-1, SUBAREA = rep(area,length(2001:surveyyear-1)), wk = rep(NA, length(2001:surveyyear-1)))
wk.Subarea <- rbind(wk.other.years, wk.Subarea) 
wk.Subarea <- wk.Subarea %>% arrange(YEAR, SUBAREA)
wk.Subarea$Strata <- "high"
wk.Subarea

model.data.Subarea <- merge(model.data.Subarea, wk.Subarea, by = c("YEAR", "Strata", "SUBAREA"), all.x = TRUE)
model.data.Subarea <- model.data.Subarea %>% arrange(SUBAREA, Strata, YEAR)
#model.data.Subarea <- model.data.Subarea %>% arrange(match(Strata, c("low", "med", "high"))) 
model.data.Subarea

#Reorder 
model.data.for.subarea <- model.data.Subarea %>%  dplyr::select(SUBAREA, Year = YEAR, Catch.actual, wk, Strata, Ih, obs.tau, rh, obs.nu, clappers,  obs.phi, L, VMSEffort, gh)  
#write.csv(model.data.for.subarea, paste0(path.directory, assessmentyear,"/Assessment/Data/Model/SFA29A_ModelData.",surveyyear,".csv"), row.names = FALSE ) 
model.data.for.subarea

## Compare to last years data and create final model file 
old <- read.csv(paste0(path.directory,assessmentyear-1,"/Assessment/Data/Model/",area,"/",area,"_ModelData.",surveyyear-1,".csv"))

# do the comparisons and save out the table
output <- compare_df(df_new = model.data.for.subarea, df_old=old, group_col = c("Year", "Strata")) 
create_output_table(output, output_type = "xlsx", file_name=paste0(path.directory,assessmentyear,"/Assessment/Data/Model/",area,".ModelData.Compare.",surveyyear,".xlsx"))

#join so have right number of rows for years - keeps all old data but adds the row for the current year 
revised <- left_join(dplyr::select(model.data.for.subarea, SUBAREA, Strata, Year), old)

#add current year data 
#For high strata - note only high strata have "Catch.actual", "wk"
revised[revised$Year==surveyyear & revised$Strata == "high", c("Catch.actual", "wk", "Ih", "obs.tau", "rh", "obs.nu", "clappers", "obs.phi", "L", "VMSEffort", "gh")] <- 
  model.data.for.subarea[model.data.for.subarea$Year==surveyyear & revised$Strata == "high", c("Catch.actual", "wk", "Ih", "obs.tau", "rh", "obs.nu", "clappers", "obs.phi", "L", "VMSEffort", "gh")]

revised[revised$Year==surveyyear & revised$Strata == "med", c("Catch.actual", "wk", "Ih", "obs.tau", "rh", "obs.nu", "clappers", "obs.phi", "L", "VMSEffort", "gh")] <- 
  model.data.for.subarea[model.data.for.subarea$Year==surveyyear & revised$Strata == "med", c("Catch.actual", "wk", "Ih", "obs.tau", "rh", "obs.nu", "clappers", "obs.phi", "L", "VMSEffort", "gh")]
#For low strata - no high for A 
revised[revised$Year==surveyyear & revised$Strata == "low", c("Catch.actual", "wk", "Ih", "obs.tau", "rh", "obs.nu", "clappers", "obs.phi", "L", "VMSEffort", "gh")] <- 
  model.data.for.subarea[model.data.for.subarea$Year==surveyyear & revised$Strata == "low", c("Catch.actual", "wk", "Ih", "obs.tau", "rh", "obs.nu", "clappers", "obs.phi", "L", "VMSEffort", "gh")]


#for vms effort - it's offset a year so want to keep previous years values - and for 2022 assessment - put in 2 year worth of values 
revised$VMSEffort[revised$Year == surveyyear-1 & revised$Strata == "low"] <- model.data.for.subarea$VMSEffort[model.data.for.subarea$Year == surveyyear-1 & model.data.for.subarea$Strata == "low"]
revised$VMSEffort[revised$Year == surveyyear-1 & revised$Strata == "med"] <- model.data.for.subarea$VMSEffort[model.data.for.subarea$Year == surveyyear-1 & model.data.for.subarea$Strata == "med"]
revised$VMSEffort[revised$Year == surveyyear-1 & revised$Strata == "high"] <- model.data.for.subarea$VMSEffort[model.data.for.subarea$Year == surveyyear-1 & model.data.for.subarea$Strata == "high"]


revised

#Note: For 2023 - 0 recruits for low in D -- as per process for this situation (since can't have 0 in model or NA for obs.nu) set rh = 0.001	obs.nu = 0.009950331, (note this often happens in subarea A). Rh get set to 0.001 in model_final.R script.
#revised$obs.nu[revised$Year == 2022 & revised$Strata == "low"] <- 0.009950331
revised$obs.nu[revised$Year == 2023 & revised$Strata == "low"] <- 0.009950331

#write out data for model 
revised <- revised %>%  dplyr::select(SUBAREA, Year , Catch.actual, wk, Strata, Ih, obs.tau, rh, obs.nu, clappers,  obs.phi, L, VMSEffort, gh)  
write.csv(revised, paste0(path.directory, assessmentyear,"/Assessment/Data/Model/",area,"_ModelData.",surveyyear,".csv"), row.names = FALSE) 

#############################################################################

#Won't need after 2023 assessment:
#Run a final comparison on old model data and new (after changes in 2019 NUM_UNLINED_FREQ #s)
#SFA29A
## Compare to last years data and create final model file 
#old <- read.csv("Y:/Inshore/SFA29/2022/Assessment/Data/Model/SFA29A/SFA29A_ModelData.2021.csv")
#new <- read.csv("Y:/Inshore/SFA29/2023/Assessment/Data/Model/SFA29A_ModelData.2022.csv")
# do the comparisons and save out the table
#output <- compare_df(df_new = new, df_old=old, group_col = c("Year", "Strata")) 
#create_output_table(output, output_type = "xlsx", file_name="Y:/Inshore/SFA29/2023/Assessment/Data/Model/archive/SFA29AModelData_FinalComparison.xlsx")


#SFA29B
## Compare to last years data and create final model file 
#old <- read.csv("Y:/Inshore/SFA29/2022/Assessment/Data/Model/SFA29B/SFA29B_ModelData.2021.csv")
#new <- read.csv("Y:/Inshore/SFA29/2023/Assessment/Data/Model/SFA29B_ModelData.2022.csv")
# do the comparisons and save out the table
#output <- compare_df(df_new = new, df_old=old, group_col = c("Year", "Strata")) 
#create_output_table(output, output_type = "xlsx", file_name="Y:/Inshore/SFA29/2023/Assessment/Data/Model/archive/SFA29BModelData_FinalComparison.xlsx")


#SFA29C
## Compare to last years data and create final model file 
#old <- read.csv("Y:/Inshore/SFA29/2022/Assessment/Data/Model/SFA29C/SFA29C_ModelData.2021.csv")
#new <- read.csv("Y:/Inshore/SFA29/2023/Assessment/Data/Model/SFA29C_ModelData.2022.csv")
# do the comparisons and save out the table
#output <- compare_df(df_new = new, df_old=old, group_col = c("Year", "Strata")) 
#create_output_table(output, output_type = "xlsx", file_name="Y:/Inshore/SFA29/2023/Assessment/Data/Model/archive/SFA29CModelData_FinalComparison.xlsx")

#SFA29D
## Compare to last years data and create final model file 
#old <- read.csv("Y:/Inshore/SFA29/2022/Assessment/Data/Model/SFA29D/SFA29D_ModelData.2021.csv")
#new <- read.csv("Y:/Inshore/SFA29/2023/Assessment/Data/Model/SFA29D_ModelData.2022.csv")
# do the comparisons and save out the table
#output <- compare_df(df_new = new, df_old=old, group_col = c("Year", "Strata")) 
#create_output_table(output, output_type = "xlsx", file_name="Y:/Inshore/SFA29/2023/Assessment/Data/Model/archive/SFA29DModelData_FinalComparison.xlsx")
