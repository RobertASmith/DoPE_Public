# generate and merge data 

#===
# SET-UP
#===
rm(list=ls())
#install.packages("geosphere")
#install.packages("rgdal")
library(sp)
library(geosphere)
library(dplyr)
library(raster)
library(rgdal)

# LSOA centroids
#RC note: LSOA centroids from Paul's file rather than from code
lsoa_cntrds <- read.csv("lsoa_cntrds.csv")

# English parkrun event locations 2018
parkrun_events = read.csv("./raw_data/parkrun_data/event_info_scraped_10.12.18.csv", stringsAsFactors = F)[,-1]

# LSOA distance to nearest parkrun event
dist_M_full <- geosphere::distm(lsoa_cntrds[,2:3],parkrun_events[,2:3])
lsoa_distance <- apply(dist_M_full,1,FUN= function(x){round(min(x),0)} )
lsoa_distance <- data.frame(code = lsoa_cntrds$code,
                            mn_dstn = lsoa_distance / 1000) # in km
rm("dist_M_full","parkrun_events","lsoa_cntrds")

# LSOA parkrun participation: (RC change: copied code from attachment3 project)
df_finishers = readRDS(file = "cleaned_data/runs_per_lsoa_2010to2020.Rds")
df_england = df_finishers[grep(pattern = "E",df_finishers$lsoa),] # restrict to England

# aggregate up by year (RC: copied code from attachment3 project)
df_england$date = as.Date(df_england$date)   
df_england$year = df_england$date %>% format("%Y")
df_aggregate = df_england %>% group_by(year,lsoa) %>% summarise(finishers = sum(finishers)) %>% ungroup()
colnames(df_aggregate) = c("year","code","run_count")

# LSOA total population
lsoa_pop = read.csv("./raw_data/IoD2019_Population_Denominators.csv",stringsAsFactors = F)
lsoa_pop[,-c(1:4)] = data.frame(apply(lsoa_pop[,-c(1:4)],2,function(x){as.numeric(as.character(gsub(",","",x)))}),stringsAsFactors = F)
lsoa_pop = lsoa_pop[,c(1,5,7)]
names(lsoa_pop) = c("code","total_pop","perc_non_working_age")
lsoa_pop$perc_non_working_age = 1-(lsoa_pop$perc_non_working_age / lsoa_pop$total_pop)

# density
lsoa_density = read.csv("./raw_data/Mid-2017 Population Density.csv",stringsAsFactors = F)[,c(1,4)]
lsoa_density = rename(lsoa_density, code = Code)
lsoa_density = merge(lsoa_density,lsoa_pop[,1:2],by="code")
lsoa_density$pop_density = round(lsoa_density$total_pop / lsoa_density$Area.Sq.Km,2)
lsoa_density = lsoa_density[,c(1,4)]

# LSOA IMD score
lsoa_imd = read.csv("./raw_data/IoD2019_Scores.csv", stringsAsFactors = F)
lsoa_imd = lsoa_imd[,-c(2:4,13:20)]
names(lsoa_imd) = c("code","imd","d_income","d_employment","d_education","d_health","d_crime","d_housing","d_enviroment")


# ethnicity
lsoa_ethnicity = read.csv("raw_data/LSOA_Ethnicity.csv",stringsAsFactors = F)
lsoa_ethnicity = lsoa_ethnicity[,3:5]
lsoa_ethnicity = data.frame(code = lsoa_ethnicity$geography.code,
                            perc_bme = 1-lsoa_ethnicity$Sex..All.persons..Age..All.categories..Age..Ethnic.Group..White..Total..measures..Value/lsoa_ethnicity$Sex..All.persons..Age..All.categories..Age..Ethnic.Group..All.categories..Ethnic.group..measures..Value)
lsoa_ethnicity = lsoa_ethnicity[!(grepl("W",lsoa_ethnicity$code)),]                            

# rural urban classification
lsoa_ruralurban <- read.csv("./raw_data/LSOA_Rural_Urban_Classification_2011.csv",stringsAsFactors = F) %>% 
  mutate(urban = RUC11CD %in% c("A1","B1", "C1","C2"))


# merge everything
#RC change: I replaced lsoa_participation with df_aggregate
lsoa_df = Reduce(function(x, y) merge(x, y,by="code", all=TRUE), list(df_aggregate,lsoa_distance, lsoa_imd, lsoa_pop,lsoa_density,lsoa_ethnicity,lsoa_ruralurban))
lsoa_df$run_count[is.na(lsoa_df$run_count)] = 0

write.csv(lsoa_df,"./output/lsoa_df_08oct2010_28dec2019.csv",row.names = F)

