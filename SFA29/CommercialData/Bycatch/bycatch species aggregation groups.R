## 29 Bycatch calculations 2023 (for 2020-2021 fishery)

direct <- "Y:/Inshore/SFA29/2026/Assessment/Data/CommercialData/Bycatch/"

discards <- read.csv(paste0(direct, "discard sums from sql_2025.csv"))
names(discards)

groups <- read.csv(paste0(direct, "bycatch species groups.csv"))
names(groups)

require(dplyr)
require(plyr)

joined <- join(discards, groups, type="full")

joined

# check out the unidentified ones
joined[is.na(joined$GROUP),]

# If the SPECCD_ID is NA and it's not in a group, there's a chance the SPECCD_ID was miscoded in the ISDB. 
# Look at the OTIS reports/scans to make sure that the observer actually recorded the species (COMMON) in this list.
# e.g. in 2018, clappers were miscoded as Greenland Cockle.
# discards$COMMON[discards$COMMON=="GREENLAND COCKLE" & discards$TRIP %in% c("J18-0283A", "J18-0283B")] <- "SCALLOP SHELLS"

# But if the observer actually reported the species shown, we need to classify them into the groups manually. Using the code below as a template,
# adjust the COMMON name and GROUP accordingly to assign a GROUP to each record.

# joined[is.na(joined$GROUP) & joined$COMMON == "ABRALIA REDFIELDI",]$GROUP <- "CEPHALOPODA C."
# joined[is.na(joined$GROUP) & joined$COMMON == "LAVAL'S EELPOUT",]$GROUP <- "EELPOUTS (NS)"
# joined[is.na(joined$GROUP) & joined$COMMON == "PAGUROIDEA S.F.",]$GROUP <- "HERMIT CRABS"
# joined[is.na(joined$GROUP) & joined$COMMON == "SHORT LOBSTER",]$GROUP <- "UNIDENT CRUSTACEANS"

# joined[is.na(joined$GROUP) & joined$COMMON == "SCALLOPS",]$GROUP <- "SEA SCALLOP"
# joined[is.na(joined$GROUP) & joined$COMMON == "PURPLE SUNSTAR",]$GROUP <- "STARFISH"
# joined[is.na(joined$GROUP) & joined$COMMON == "CUCUMARIA FRONDOSA",]$GROUP <- "SEA CUCUMBERS"
# joined[is.na(joined$GROUP) & joined$COMMON == "NEW ENGLAND NEPTUNE",]$GROUP <- "WHELKS"
# joined[is.na(joined$GROUP) & joined$COMMON == "GRUBBY OR LITTLE SCULPIN",]$GROUP <- "SCULPINS"

# Now, go back and add these to the bycatch species groups.csv table so that we get these joined properly next time. 


# check out the unidentified ones (should be empty now)
joined[is.na(joined$GROUP),]

# sums for all species
groupedsums <- ddply(.data=joined, .(GROUP, COMAREA_ID),
                     summarize,
                     total=sum(Prorated_discards, na.rm=T))

#incl. NAs for excel
groupedsums_allareas <- ddply(.data=groupedsums, .(GROUP),
                              summarize,
                              total=sum(total, na.rm=T))

write.csv(groupedsums_allareas, paste0(direct, "groupedsums_allareas_2025.csv"))

#The below is not required for basic bycatch analysis
### compare rates over time series

time <- read.csv("Y:/INSHORE SCALLOP/SFA29/2018/Bycatch/Fishery/bycatch time series.csv", stringsAsFactors = F)

head(time)

require(ggplot2)

time$species[time$species %in% c("COMMON MUSSELS", "MUSSELS (NS)")] <- "MUSSELS"

time <- ddply(.data=time, .(species, year),
              summarize,
              rate=sum(rate, na.rm=T))

time2017 <- subset(time, year==2017 & rate >0)

time2 <- time[time$species %in% c(time2017$species),]

png("Y:/INSHORE SCALLOP/SFA29/2018/Bycatch/Fishery/bycatch time series.png", res=100, width=1500, height=750)
ggplot() + geom_point(data=time2[!(time2$rate==0),], aes(year, rate)) + facet_wrap(~species, scales="free_y") + theme_bw() + theme(panel.grid=element_blank())
dev.off()

require(plyr)
maxyear <- ddply(.data=time, .(species),
                 summarize,
                 maxrate=max(rate))
timemax <- join(time, maxyear, type="left")
timemax <- timemax[timemax$rate==timemax$maxrate,]
timemax <- timemax[!is.na(timemax$year),]
timemax <- timemax[!timemax$rate==0,]

timemax <- arrange(timemax, year)



