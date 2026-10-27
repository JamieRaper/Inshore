#### This script pulls the individual bycatch data from the scallsur data base - normalized on individuals 
## J.Sameoto nov 2024 

library(dplyr)
library(lubridate)
library(sf)
library(tidyr)
library(flextable)
library(data.table)
library(ggplot2)
library(gt)
library(ftExtra)
library(janitor)
#library(rgdal)
library(terra)
library(patchwork)
library(viridis)
#library(RStoolbox)
library(ROracle)
library(knitr)
library(tinytex)
library(kableExtra)
library(haven)
library(gridExtra)
library(collapse)
library("rnaturalearth")
library("rnaturalearthdata")
library(ggspatial)


## SETUP 
setwd("Y:/Inshore/Bycatch/SurveyBycatch/bycatch_report")

## Define Species information
spec_code <- "43"
spec_name <- "winterfounder" #for file name
year <- 2026 # year of data pull/report generation

#### Import Mar-scal functions
funcs <- c("https://raw.githubusercontent.com/Mar-scal/Assessment_fns/master/Survey_and_OSAC/convert.dd.dddd.r")
dir <- getwd()
for(fun in funcs) 
{
  temp <- dir
  download.file(fun,destfile = basename(fun))
  source(paste0(dir,"/",basename(fun)))
  file.remove(paste0(dir,"/",basename(fun)))
}

##Data pull
#con= dbConnect(DBI::dbDriver("Oracle"), un.sameotoj, pw.sameotoj, 'ptran') 

#un.ID <- keyring::key_list("Oracle")[1,2]
#pw.ID <- keyring::key_get("Oracle", un.ID)
un.ID <- un.sameotoj
pw.ID <- pw.sameotoj


#specify species code in sql query 
con <- dbConnect(DBI::dbDriver("Oracle"), un.ID, pw.ID, 'ptran')
bycatch.ind <- dbGetQuery(con, paste(" SELECT * from SCALLSUR.SCBYCATCH_BY_TOW_RAW WHERE SPECCD_ID = '", spec_code, "'"))

dim(bycatch.ind)
head(bycatch.ind)

table(bycatch.ind$MEAS_ID)
table(bycatch.ind$SEX_ID)


bycatch.ind <- bycatch.ind %>% select(CRUISE, TOW_NO, TOW_DATE, STRATA_ID, START_LAT, START_LONG, END_LAT, END_LONG, BYCATCH_SEQ, SPECCD_ID, COMMON, SCIENTIFIC, MEAS_VAL)


write.csv(bycatch.ind, paste0("Y:/Inshore/Bycatch/SurveyBycatch/WinterFlounder_GF_PESD_",year,"/",spec_name,".csv"))


