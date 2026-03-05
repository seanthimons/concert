#Bring together the final curated FracFocus chemicals and purposes and merge with original chemical and purpose data
library(dplyr)
library(stringr)

#load in the original ingredient data, remove CASE 3 data (lists of additives mapped to all ingredients) most of these are halliburton and schlumberger 

ingredients<-readRDS("output/ingredients.rds")


#ingredients<-ingredients[which(ingredients$DisclosureId=="a516582c-b10c-4af4-8dbc-28cda0f55fe4"),]

#remove purpose data for case1 and case1a disclosures. These were identified by the case of all ingredients on a disclosure being mapped to a single purpose (unique purposeID)

#create tables of the number of ingredients and purposes for each disclosureID
library(data.table)
ing<-data.table(ingredients)
counting<-ing[,.(count_ing=length(unique(IngredientsId))),by=c("DisclosureId","TradeName")] 

countpurp<-ing[,.(count_purp=length(unique(PurposeId))),by=c("DisclosureId","TradeName")]
countpurpact<-ing[,.(count_purpact=length(unique(Purpose))),by=c("DisclosureId","TradeName")]
countnalltpurpact<-ing[,.(count_purpactall=length(unique(PurposeId))),by=c("DisclosureId")] #all unique purpose IDs across all tradenames
countnalling<-ing[,.(count_ingall=length(unique(IngredientsId))),by=c("DisclosureId")]


#count trade names for determining case 1

counttrade<-ing[,.(count_trade=length(unique(TradeName))),by=c("DisclosureId")] 
singletrade<-counttrade$DisclosureId[which(counttrade$count_trade==1)]

#join the tables and then compare.

ing_counts<-left_join(counting,countpurp)
ing_counts<-left_join(ing_counts,countpurpact)
ing_counts<-left_join(ing_counts,counttrade)
ing_counts<-left_join(ing_counts,countnalltpurpact)
ing_counts<-left_join(ing_counts,countnalling)
ing_counts$DisclosureIdTradeName<-paste0(ing_counts$DisclosureId,ing_counts$TradeName)

ingredients$DisclosureIdTradeName<-paste0(ingredients$DisclosureId,ingredients$TradeName)

#Assign reporting cases to disclosures based on the counts above

#Case2<-ing_counts
Case1<-ing_counts[which(ing_counts$count_trade==1),]
Case3<-ing_counts[which(ing_counts$count_ing==1),]   #number of functions greater than # additives
#Case2<-ing_counts[which(ing_counts$count_ing>ing_counts$count_purp),] # If any of the purpose ids are mapped to more than 1 ingredient

ingredients$ReportingCase<-"Case2" #Case 2 by default
ingredients$ReportingCase[which(ingredients$DisclosureIdTradeName %in% Case3$DisclosureIdTradeName)]<-"Case3"  #this order ensures that Case 2 are identified distinct from Case 3
ingredients$ReportingCase[which(ingredients$DisclosureId %in% Case1$DisclosureId)]<-"Case1" #case1 #this captures disclosures that are ALL Case1

library(stringr)
k<-str_count(ingredients$TradeName,",")
j<-str_count(ingredients$Purpose,",")
ingredients$ReportingCase[(k>0 & j>0) | j>1 | k >1]<-"Case1" #this captures individual records where a list of tradenames and purposes are provided within a disclosure with better data


#Assign function data to ingredient records according to reported case.

#load the curated purposes

final_curated_purposes<-readRDS("Output/final_curated_purposes.rds")


#break out cases for merging
case1<-ingredients[which(ingredients$ReportingCase=="Case1"),]
case2<-ingredients[which(ingredients$ReportingCase=="Case2"),]
case3<-ingredients[which(ingredients$ReportingCase=="Case3"),]

#Now assign additive purpose to Case2 data
purposes<-final_curated_purposes[,c("Purpose","index","Harmonized.Functional.Use")]

#Put the list of harmonized values on a single line if reported function contained multiple functions
k<-data.table(purposes)
concat_unique <- function(x){paste0(unique(x),  collapse=', ')}
purpose_all<-k[, lapply(.SD, concat_unique), by = index] #collapse

purpose_all$Harmonized.Functional.Use[which(purpose_all$Harmonized.Functional.Use=="NA")]<-""

purpose_all<-purpose_all[,c("Purpose","Harmonized.Functional.Use")]

case2<-left_join(case2,purpose_all)
colnames(case2)[which(colnames(case2)=="Harmonized.Functional.Use")]<- "Additive.Function"

#There are some individual additives that follow Case 3 reporting; these cant be assigned


case3<-left_join(case3,purpose_all)
colnames(case3)[which(colnames(case3)=="Harmonized.Functional.Use")]<- "Chemical.Function"

#These are ambiguous for the given case
case1$Additive.Function<-""
case1$Chemical.Function<-""
case2$Chemical.Function<-""
case3$Additive.Function<-""

ingredients_withfunction<-rbind(case1,case2,case3)

ingredients_withfunction<-ingredients_withfunction[order(ingredients_withfunction$DisclosureId,ingredients_withfunction$IngredientsId),]


#Now add the curated chemical data

#load the final curated chemicals
final_curated_chemicals<-readRDS("Output/curated_chemicals.rds")


#just in case amy lingering case or whitespace issues
final_curated_chemicals$raw_chem_name<-tolower(trimws(final_curated_chemicals$raw_chem_name))
final_curated_chemicals$raw_cas<-tolower(trimws(final_curated_chemicals$raw_cas))


#keep useful variables for merging
final_curated_chemicals<-final_curated_chemicals[,c("raw_chem_name","raw_cas","clean_name","name_comment","clean_casrn","casrn_comment","DTXSID","PREFERRED_NAME","CASRN")] #there were about a dozen duplicates that may had had to do wtih spaces in casrn

final_curated_chemicals<-unique(final_curated_chemicals) #there were about a dozen duplicates that may had had to do with spaces in casrn
#final_curated_chemicals$DTXSID[which(is.na(final_curated_chemicals$DTXSID))]<-"unknown" #this is so w can QA which pairs have no match

ingredients_withfunction$raw_cas<-ingredients_withfunction$CASNumber

#standardize the names and cas in the same way as in the chemical data
ingredients_withfunction$raw_chem_name<-trimws(tolower(ingredients_withfunction$IngredientName))
ingredients_withfunction$raw_cas<-trimws(tolower(ingredients_withfunction$raw_cas))

#Standardize spacing and punctuation
ingredients_withfunction$raw_chem_name<-gsub(")  ",")", ingredients_withfunction$raw_chem_name) 
ingredients_withfunction$raw_chem_name<-gsub(") ",")", ingredients_withfunction$raw_chem_name)  
ingredients_withfunction$raw_chem_name<-gsub(" ) ",")", ingredients_withfunction$raw_chem_name) 
ingredients_withfunction$raw_chem_name<-gsub(")",") ", ingredients_withfunction$raw_chem_name) 

ingredients_withfunction$raw_chem_name<-gsub(" \\(","(", ingredients_withfunction$raw_chem_name) 
ingredients_withfunction$raw_chem_name<-gsub("\\( ","(", ingredients_withfunction$raw_chem_name)  
ingredients_withfunction$raw_chem_name<-gsub(" \\( ","(", ingredients_withfunction$raw_chem_name)  
ingredients_withfunction$raw_chem_name<-gsub("\\("," (", ingredients_withfunction$raw_chem_name) 

ingredients_withfunction$raw_chem_name<-gsub(" , ",",", ingredients_withfunction$raw_chem_name)  
ingredients_withfunction$raw_chem_name<-gsub(" ,",",", ingredients_withfunction$raw_chem_name)  
ingredients_withfunction$raw_chem_name<-gsub(",  ",",", ingredients_withfunction$raw_chem_name)  
ingredients_withfunction$raw_chem_name<-gsub(", ",",", ingredients_withfunction$raw_chem_name)  
ingredients_withfunction$raw_chem_name<-gsub(",",", ", ingredients_withfunction$raw_chem_name) 

ingredients_withfunction$raw_chem_name<-gsub("//.  ",".", ingredients_withfunction$raw_chem_name)  
ingredients_withfunction$raw_chem_name<-gsub("//. ",".", ingredients_withfunction$raw_chem_name)  
ingredients_withfunction$raw_chem_name<-gsub("//.",". ", ingredients_withfunction$raw_chem_name) 

ingredients_withfunction$raw_chem_name<-gsub("- ","-", ingredients_withfunction$raw_chem_name) 
ingredients_withfunction$raw_chem_name<-gsub(" - ","-", ingredients_withfunction$raw_chem_name) 
ingredients_withfunction$raw_chem_name<-gsub(" -","-", ingredients_withfunction$raw_chem_name) 

ingredients_withfunction$raw_chem_name<-gsub("&#39", "'", ingredients_withfunction$raw_chem_name) 

ingredients_withfunction$raw_chem_name<-gsub("\"","", ingredients_withfunction$raw_chem_name)
ingredients_withfunction$raw_chem_name<-gsub("//*","", ingredients_withfunction$raw_chem_name)

#do again, just to make sure catching any spaces introduced by above
ingredients_withfunction$raw_chem_name<-trimws(tolower(ingredients_withfunction$raw_chem_name))

#remove records missing both name and cas in raw FF data (~9K records)
ingredients_withfunction2<-ingredients_withfunction[which(!is.na(ingredients_withfunction$raw_cas) | !is.na(ingredients_withfunction$raw_chem_name)),]

#tester<-ingredients_withfunction[which(is.na(ingredients_withfunction$raw_cas) & is.na(ingredients_withfunction$raw_chem_name)),]

ingredients_withfunctionandchem<-left_join(ingredients_withfunction2,final_curated_chemicals)

#For QA
notcurated<-unique(ingredients_withfunctionandchem[which(is.na(ingredients_withfunctionandchem$DTXSID)),c("raw_chem_name", "raw_cas")])

#Add temporal data and release information.

#load in temporal data from FF file

metadata<-read.csv("FracFocusCSV/DisclosureList_1.csv")

final_dataset_for_publication<-left_join(ingredients_withfunctionandchem,metadata)

#just harmonize some names so all follow the FF reporting style
colnames(final_dataset_for_publication)[colnames(final_dataset_for_publication)=="Additive.Function"]<-"AdditiveProductFunction"
colnames(final_dataset_for_publication)[colnames(final_dataset_for_publication)=="Chemical.Function"]<-"ChemicalFunction"

#remove a few variables for size 
final_dataset_for_publication<-final_dataset_for_publication[, !colnames(final_dataset_for_publication) %in% c("Projection","TVD", "FederalWell","IndianWell") ]

#order in a more intuitive manner
final_dataset_for_publication<-final_dataset_for_publication[,c(
"DisclosureId","WellName","APINumber","StateName","CountyName","OperatorName","Latitude","Longitude","JobStartDate","JobEndDate","TotalBaseWaterVolume",   
"TotalBaseNonWaterVolume","FFVersion",
"IngredientsId","IngredientName","CASNumber","Supplier","TradeName","raw_cas","raw_chem_name","clean_name","name_comment","clean_casrn","casrn_comment","DTXSID","PREFERRED_NAME","CASRN",
"Purpose","PurposeId","ReportingCase","AdditiveProductFunction","ChemicalFunction")]

final_dataset_for_publication[is.na(final_dataset_for_publication)]<-""

#save final dataset
saveRDS(final_dataset_for_publication,"Output/finalcuratedalldata.rds")


