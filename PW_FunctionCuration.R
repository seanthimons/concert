# Script to curate FracFocus purpose data
#Kristin  Isaacs, EPA/ORD/CCTE 2025

library("tidyr")
library("dplyr")

#If doing this for the first time, load in FracFocus CSV data and store key data as RDS files for ease of access
#load<-1 #flag for loading
load<-0

if (load==1) {

#this is not code-efficient, but easy  
file1<-read.csv("FracFocusCSV/FracFocusRegistry_1.csv")
file2<-read.csv("FracFocusCSV/FracFocusRegistry_2.csv")
file3<-read.csv("FracFocusCSV/FracFocusRegistry_3.csv")
file4<-read.csv("FracFocusCSV/FracFocusRegistry_4.csv")
file5<-read.csv("FracFocusCSV/FracFocusRegistry_5.csv")
file6<-read.csv("FracFocusCSV/FracFocusRegistry_6.csv")
file7<-read.csv("FracFocusCSV/FracFocusRegistry_7.csv")
file8<-read.csv("FracFocusCSV/FracFocusRegistry_8.csv")
file9<-read.csv("FracFocusCSV/FracFocusRegistry_9.csv")
file10<-read.csv("FracFocusCSV/FracFocusRegistry_10.csv")
file11<-read.csv("FracFocusCSV/FracFocusRegistry_11.csv")
file12<-read.csv("FracFocusCSV/FracFocusRegistry_12.csv")
file13<-read.csv("FracFocusCSV/FracFocusRegistry_13.csv")
 
ingredients1<-file1[which(file1$IngredientsId!=""),c("DisclosureId","WellName","Latitude","Longitude","IngredientsId","IngredientCommonName","CASNumber","IngredientName","Purpose","PurposeId","Supplier","TradeName")]
ingredients2<-file2[which(file2$IngredientsId!=""),c("DisclosureId","WellName","Latitude","Longitude","IngredientsId","IngredientCommonName","CASNumber","IngredientName","Purpose","PurposeId","Supplier","TradeName")]
ingredients3<-file3[which(file3$IngredientsId!=""),c("DisclosureId","WellName","Latitude","Longitude","IngredientsId","IngredientCommonName","CASNumber","IngredientName","Purpose","PurposeId","Supplier","TradeName")]
ingredients4<-file4[which(file4$IngredientsId!=""),c("DisclosureId","WellName","Latitude","Longitude","IngredientsId","IngredientCommonName","CASNumber","IngredientName","Purpose","PurposeId","Supplier","TradeName")]
ingredients5<-file5[which(file5$IngredientsId!=""),c("DisclosureId","WellName","Latitude","Longitude","IngredientsId","IngredientCommonName","CASNumber","IngredientName","Purpose","PurposeId","Supplier","TradeName")]
ingredients6<-file6[which(file6$IngredientsId!=""),c("DisclosureId","WellName","Latitude","Longitude","IngredientsId","IngredientCommonName","CASNumber","IngredientName","Purpose","PurposeId","Supplier","TradeName")]
ingredients7<-file7[which(file7$IngredientsId!=""),c("DisclosureId","WellName","Latitude","Longitude","IngredientsId","IngredientCommonName","CASNumber","IngredientName","Purpose","PurposeId","Supplier","TradeName")]
ingredients8<-file8[which(file8$IngredientsId!=""),c("DisclosureId","WellName","Latitude","Longitude","IngredientsId","IngredientCommonName","CASNumber","IngredientName","Purpose","PurposeId","Supplier","TradeName")]
ingredients9<-file9[which(file9$IngredientsId!=""),c("DisclosureId","WellName","Latitude","Longitude","IngredientsId","IngredientCommonName","CASNumber","IngredientName","Purpose","PurposeId","Supplier","TradeName")]
ingredients10<-file10[which(file10$IngredientsId!=""),c("DisclosureId","WellName","Latitude","Longitude","IngredientsId","IngredientCommonName","CASNumber","IngredientName","Purpose","PurposeId","Supplier","TradeName")]
ingredients11<-file11[which(file11$IngredientsId!=""),c("DisclosureId","WellName","Latitude","Longitude","IngredientsId","IngredientCommonName","CASNumber","IngredientName","Purpose","PurposeId","Supplier","TradeName")]
ingredients12<-file12[which(file12$IngredientsId!=""),c("DisclosureId","WellName","Latitude","Longitude","IngredientsId","IngredientCommonName","CASNumber","IngredientName","Purpose","PurposeId","Supplier","TradeName")]
ingredients13<-file13[which(file13$IngredientsId!=""),c("DisclosureId","WellName","Latitude","Longitude","IngredientsId","IngredientCommonName","CASNumber","IngredientName","Purpose","PurposeId","Supplier","TradeName")]

ingredients<-rbind(ingredients1,
                   ingredients2,
                   ingredients3,
                   ingredients4,
                   ingredients5,
                   ingredients6,
                   ingredients7,
                   ingredients8,
                   ingredients9,
                   ingredients10,
                   ingredients11,
                   ingredients12,
                   ingredients13)

 #setwd("/Output/")
 saveRDS(ingredients,"Output/ingredients.rds") #for later chemical curation
 
 
 uniqueingredients<-unique(ingredients[,c("IngredientName","CASNumber")])

 uniqueingredientspurposepairs<-unique(ingredients[,c("IngredientName","CASNumber","Purpose")])
 saveRDS(uniqueingredientspurposepairs,"Output/uniqueingredientspurposepairs.rds")

 uniquepurposes<-data.frame(unique(ingredients[,c("Purpose")]))
 write.csv(uniqueingredients,"Output/uniqueingredients.csv")
 write.csv(uniquepurposes,"Output/uniquepurposes.csv")

}


#load in existing function mappings and make list of unique curations

uniquepurposes<-read.csv("Output/uniquepurposes.csv")

#First deal with unique purposes
uniquepurposes<-data.frame(uniquepurposes[,2])
colnames(uniquepurposes)<-"Reported.Functional.Use"

uniquepurposes$index<-1:length(uniquepurposes$Reported.Functional.Use)

uniquepurposes2<-uniquepurposes %>% 
  mutate(individualpurposes = strsplit(as.character(Reported.Functional.Use), ",")) %>% 
  unnest(individualpurposes)

uniquepurposes2$Reported.Functional.Use<-uniquepurposes2$individualpurposes
uniquepurposes2<-uniquepurposes2[,!colnames(uniquepurposes2)=="individualpurposes"]
uniquepurposes_indexed<-uniquepurposes2 #maps back to reported purposes

#unique individual purposes

uniqueindividualpurposes<-data.frame(unique(uniquepurposes_indexed$Reported.Functional.Use))
colnames(uniqueindividualpurposes)<-"IndividualPurpose"

#Now try to curate uniqueindividualpurposes using the thousands of records already in Factotum
#Factotum is EPA's internal tool for curating information in the Chemicals and Products Database
#The most recent version of these data are available on the Download Data page of EPA's Chemical Exposure 
#Knowledgebase (https://comptox.epa.gov/chemexpo/)

factotumfunction<-read.csv("Input/Factotum_bulk_functional_uses_20240615.csv")
uniquefunctioncurations<-unique(factotumfunction[,c("Harmonized.Functional.Use","Reported.Functional.Use")])

#remove incorrect mappings in factotum
uniquefunctioncurations<-uniquefunctioncurations[which(uniquefunctioncurations$Reported.Functional.Use!="Friction Reducer"),]


#now create case-insensitive versions of both that we want to match
uniquefunctioncurations$Reported.Functional.Useorig<-uniquefunctioncurations$Reported.Functional.Use
uniquefunctioncurations$Reported.Functional.Use<-trimws(tolower(uniquefunctioncurations$Reported.Functional.Use))
uniquefunctioncurations<-uniquefunctioncurations[which(uniquefunctioncurations$Harmonized.Functional.Use!=""),]
uniqueindividualpurposes$Reported.Functional.Use<-trimws(tolower(uniqueindividualpurposes$IndividualPurpose))

uniquestandardizedpurposes<-data.frame(unique(uniqueindividualpurposes$Reported.Functional.Use))
colnames(uniquestandardizedpurposes)<-"Reported.Functional.Use"

#merge
curatedpurposes<-left_join(uniquestandardizedpurposes,uniquefunctioncurations)

#make a dataframe of anything not curated using Factotum mappings
tocurate<-curatedpurposes[which(is.na(curatedpurposes$Harmonized.Functional.Use)),]

#Script-based curations: many of these are based on FracFocus functions described here:https://fracfocus.org/learn/what-is-fracturing-fluid-made-of

#acid: pH regulating agent
#biocide: Biocide
#carrier: Diluent
#breaker: Breaker_EPA
#stabilizer :Stabilizing agent 
#cross-linker: Chemical reaction regulator
#friction reducer: Lubricating agent
#gel: Viscosity modifier
#iron control: Chelating agent
#no emulsifier: Demulsifier
#propping agent: Proppant (HF)
#scale inhibitor: Anti-scaling agent
#Surfactant: Surfactant
#hydrogen sulfide scavenger: H2S Scavenger (HF) 
#oxygen scavenger: O2 Scavenger (HF) 
#Paraffin inhibitor: Paraffin inhibitor (HF)
#diverter: Diverting agent (HF)
#tracer: Tracer (HF)
#blocking agent: Blocking agent (HF) #per research
#bridging agent: Bridging agent (HF) #per research
#flushing agent: Flushing agent (HF) #per research
#flowback agent: Flowback agent (HF) #per research
#emission control: Emission controlling agent #per research
#silt suspenders: Silt supending agent #per research Surfactant?


#Try to assign all visc mods (these are superceded by breakers and crosslinker assignments:
tocurate$Harmonized.Functional.Use[grepl("gel",tocurate$Reported.Functional.Use)]<-"Viscosity modifier"
tocurate$Harmonized.Functional.Use[grepl("guar",tocurate$Reported.Functional.Use)]<-"Viscosity modifier"
tocurate$Harmonized.Functional.Use[grepl("visco",tocurate$Reported.Functional.Use)]<-"Viscosity modifier"
tocurate$Harmonized.Functional.Use[grepl("rheolog",tocurate$Reported.Functional.Use)]<-"Viscosity modifier"
tocurate$Harmonized.Functional.Use[grepl("polymer",tocurate$Reported.Functional.Use)]<-"Viscosity modifier"
tocurate$Harmonized.Functional.Use[grepl("anionic polymer in emulsion form",tocurate$Reported.Functional.Use)]<-"Viscosity modifier"
tocurate$Harmonized.Functional.Use[grepl("flocc",tocurate$Reported.Functional.Use)]<-"Viscosity modifier"
tocurate$Harmonized.Functional.Use[grepl("vicosifier",tocurate$Reported.Functional.Use)]<-"Viscosity modifier"
tocurate$Harmonized.Functional.Use[grepl("visosifier",tocurate$Reported.Functional.Use)]<-"Viscosity modifier"
tocurate$Harmonized.Functional.Use[grepl("vixcosifier",tocurate$Reported.Functional.Use)]<-"Viscosity modifier"
tocurate$Harmonized.Functional.Use[grepl("geiling",tocurate$Reported.Functional.Use)]<-"Viscosity modifier"
tocurate$Harmonized.Functional.Use[grepl("xanthan",tocurate$Reported.Functional.Use)]<-"Viscosity modifier"
tocurate$Harmonized.Functional.Use[grepl("emulsion reducer/increases viscosity",tocurate$Reported.Functional.Use)]<-"Viscosity modifier"

tocurate$Harmonized.Functional.Use[grepl("viscosifier and fluid loss additive",tocurate$Reported.Functional.Use)]<-"Viscosity modifier"

tocurate$Harmonized.Functional.Use[grepl("transport",tocurate$Reported.Functional.Use) & grepl("additive",tocurate$Reported.Functional.Use) ]<-"Viscosity modifier" #per research

#dispersants
tocurate$Harmonized.Functional.Use[grepl("dispersant",tocurate$Reported.Functional.Use)]<-"Dispersing agent"


#carriers etc. (superceded by modifiers)
tocurate$Harmonized.Functional.Use[grepl("carrier",tocurate$Reported.Functional.Use)]<-"Diluent"
tocurate$Harmonized.Functional.Use[grepl("carry",tocurate$Reported.Functional.Use)]<-"Diluent"
tocurate$Harmonized.Functional.Use[grepl("base",tocurate$Reported.Functional.Use)]<-"Diluent"
tocurate$Harmonized.Functional.Use[grepl("fluid",tocurate$Reported.Functional.Use)]<-"Diluent"
tocurate$Harmonized.Functional.Use[grepl("career",tocurate$Reported.Functional.Use)]<-"Diluent"
tocurate$Harmonized.Functional.Use[grepl("water",tocurate$Reported.Functional.Use)]<-"Diluent"
tocurate$Harmonized.Functional.Use[grepl("carrer",tocurate$Reported.Functional.Use)]<-"Diluent"


tocurate$Harmonized.Functional.Use[grepl("div",tocurate$Reported.Functional.Use)]<-"Diverting agent (HF)"
tocurate$Harmonized.Functional.Use[grepl("penetrating",tocurate$Reported.Functional.Use)]<-"Diverting agent (HF)"

tocurate$Harmonized.Functional.Use[grepl("flush",tocurate$Reported.Functional.Use)]<-"Flushing agent (HF)"
tocurate$Harmonized.Functional.Use[grepl("line wash",tocurate$Reported.Functional.Use)]<-"Flushing agent (HF)"


tocurate$Harmonized.Functional.Use[grepl("foam",tocurate$Reported.Functional.Use)]<-"Foamant"
tocurate$Harmonized.Functional.Use[grepl("amphoteric foamer for water/acid",tocurate$Reported.Functional.Use)]<-"Foamant"
tocurate$Harmonized.Functional.Use[grepl("foam",tocurate$Reported.Functional.Use) & grepl("anti",tocurate$Reported.Functional.Use) ]<-"Defoamer"


tocurate$Harmonized.Functional.Use[grepl("freez",tocurate$Reported.Functional.Use)]<-"Anti-freeze agent"
tocurate$Harmonized.Functional.Use[grepl("deicing agent",tocurate$Reported.Functional.Use)]<-"Anti-freeze agent"
tocurate$Harmonized.Functional.Use[grepl("freez",tocurate$Reported.Functional.Use)]<-"Anti-freeze agent"
tocurate$Harmonized.Functional.Use[grepl("winter",tocurate$Reported.Functional.Use)]<-"Anti-freeze agent"


tocurate$Harmonized.Functional.Use[grepl("flow-back",tocurate$Reported.Functional.Use)]<-"Flowback agent (HF)"
tocurate$Harmonized.Functional.Use[grepl("flow back",tocurate$Reported.Functional.Use)]<-"Flowback agent (HF)"
tocurate$Harmonized.Functional.Use[grepl("flowback",tocurate$Reported.Functional.Use)]<-"Flowback agent (HF)"


tocurate$Harmonized.Functional.Use[grepl("flow assurance additive",tocurate$Reported.Functional.Use)]<-"Flow promoter"
tocurate$Harmonized.Functional.Use[grepl("flow enhancer",tocurate$Reported.Functional.Use)]<-"Flow promoter"


tocurate$Harmonized.Functional.Use[grepl("bridging",tocurate$Reported.Functional.Use)]<-"Diverting agent (HF)"

tocurate$Harmonized.Functional.Use[grepl("block",tocurate$Reported.Functional.Use)]<-"Blocking agent (HF)"

tocurate$Harmonized.Functional.Use[grepl("flush",tocurate$Reported.Functional.Use)]<-"Flushing agent (HF)"


tocurate$Harmonized.Functional.Use[grepl("solv",tocurate$Reported.Functional.Use)]<-"Solvent"
tocurate$Harmonized.Functional.Use[grepl("slovent",tocurate$Reported.Functional.Use)]<-"Solvent"
tocurate$Harmonized.Functional.Use[grepl("sovent",tocurate$Reported.Functional.Use)]<-"Solvent"


tocurate$Harmonized.Functional.Use[grepl("break",tocurate$Reported.Functional.Use)]<-"Breaker (HF)"
tocurate$Harmonized.Functional.Use[grepl("braker",tocurate$Reported.Functional.Use)]<-"Breaker (HF)"
tocurate$Harmonized.Functional.Use[grepl("beaker",tocurate$Reported.Functional.Use)]<-"Breaker (HF)"

tocurate$Harmonized.Functional.Use[grepl("trace",tocurate$Reported.Functional.Use)]<-"Tracer"

tocurate$Harmonized.Functional.Use[grepl("cross",tocurate$Reported.Functional.Use)]<-"Chemical reaction regulator"
tocurate$Harmonized.Functional.Use[grepl("xlink",tocurate$Reported.Functional.Use)]<-"Chemical reaction regulator"
tocurate$Harmonized.Functional.Use[grepl("x-li",tocurate$Reported.Functional.Use)]<-"Chemical reaction regulator"
tocurate$Harmonized.Functional.Use[grepl("activ",tocurate$Reported.Functional.Use)]<-"Chemical reaction regulator"
tocurate$Harmonized.Functional.Use[grepl("activ",tocurate$Reported.Functional.Use)]<-"Chemical reaction regulator"
tocurate$Harmonized.Functional.Use[grepl("corsslinker",tocurate$Reported.Functional.Use)]<-"Chemical reaction regulator"
tocurate$Harmonized.Functional.Use[grepl("accel",tocurate$Reported.Functional.Use)]<-"Chemical reaction regulator"
tocurate$Harmonized.Functional.Use[grepl("croslinking",tocurate$Reported.Functional.Use)]<-"Chemical reaction regulator"
tocurate$Harmonized.Functional.Use[grepl("enzyme",tocurate$Reported.Functional.Use)]<-"Chemical reaction regulator"
tocurate$Harmonized.Functional.Use[grepl("acitivator",tocurate$Reported.Functional.Use)]<-"Chemical reaction regulator"
tocurate$Harmonized.Functional.Use[grepl("resin acitvator",tocurate$Reported.Functional.Use)]<-"Chemical reaction regulator"
tocurate$Harmonized.Functional.Use[grepl("resin actavator",tocurate$Reported.Functional.Use)]<-"Chemical reaction regulator"
tocurate$Harmonized.Functional.Use[grepl("resin actiivator",tocurate$Reported.Functional.Use)]<-"Chemical reaction regulator"
tocurate$Harmonized.Functional.Use[grepl("resin hardener",tocurate$Reported.Functional.Use)]<-"Chemical reaction regulator"
tocurate$Harmonized.Functional.Use[grepl("croslinking",tocurate$Reported.Functional.Use)]<-"Chemical reaction regulator"
tocurate$Harmonized.Functional.Use[grepl("acticator",tocurate$Reported.Functional.Use)]<-"Chemical reaction regulator"

#Catalysts are a specific subclass of Chemical reaction regulator in the OECD dictionary
tocurate$Harmonized.Functional.Use[grepl("catylst",tocurate$Reported.Functional.Use)]<-"Catalyst"
tocurate$Harmonized.Functional.Use[grepl("catalyst",tocurate$Reported.Functional.Use)]<-"Catalyst"


tocurate$Harmonized.Functional.Use[grepl("conductivity endhancer",tocurate$Reported.Functional.Use)]<-"Conductive agent"
tocurate$Harmonized.Functional.Use[grepl("conductivity enhancer",tocurate$Reported.Functional.Use)]<-"Conductive agent"
tocurate$Harmonized.Functional.Use[grepl("polyelectrolyte",tocurate$Reported.Functional.Use)]<-"Conductive agent"

tocurate$Harmonized.Functional.Use[grepl("dust suppression",tocurate$Reported.Functional.Use)]<-"Dust suppressant"


tocurate$Harmonized.Functional.Use[grepl("polymer emulsifier",tocurate$Reported.Functional.Use)]<-"Emulsifier"
tocurate$Harmonized.Functional.Use[grepl("micro emulsion",tocurate$Reported.Functional.Use)]<-"Emulsifier"
tocurate$Harmonized.Functional.Use[grepl("microemulsifier",tocurate$Reported.Functional.Use)]<-"Emulsifier"
tocurate$Harmonized.Functional.Use[grepl("microemulsion",tocurate$Reported.Functional.Use)]<-"Emulsifier"
tocurate$Harmonized.Functional.Use[grepl("emulfifier",tocurate$Reported.Functional.Use)]<-"Emulsifier"
tocurate$Harmonized.Functional.Use[grepl("emuls",tocurate$Reported.Functional.Use)]<-"Emulsifier"
tocurate$Harmonized.Functional.Use[grepl("emulfifier",tocurate$Reported.Functional.Use)]<-"Emulsifier"
tocurate$Harmonized.Functional.Use[grepl("emulsi",tocurate$Reported.Functional.Use)]<-"Emulsifier"
tocurate$Harmonized.Functional.Use[grepl("emulsifier/dispersing agent",tocurate$Reported.Functional.Use)]<-"Emulsifier"
tocurate$Harmonized.Functional.Use[grepl("emulsio",tocurate$Reported.Functional.Use)]<-"Emulsifier"
tocurate$Harmonized.Functional.Use[grepl("emulsion",tocurate$Reported.Functional.Use)]<-"Emulsifier"


tocurate$Harmonized.Functional.Use[grepl("etching",tocurate$Reported.Functional.Use)]<-"Etching agent"


tocurate$Harmonized.Functional.Use[grepl("clean",tocurate$Reported.Functional.Use)]<-"Cleaning agent"

tocurate$Harmonized.Functional.Use[grepl("oxidiz",tocurate$Reported.Functional.Use)]<-"Oxidizing agent"


tocurate$Harmonized.Functional.Use[grepl("stabil",tocurate$Reported.Functional.Use)]<-"Stabilizing agent"
tocurate$Harmonized.Functional.Use[grepl("clay",tocurate$Reported.Functional.Use)]<-"Stabilizing agent"
tocurate$Harmonized.Functional.Use[grepl("stab",tocurate$Reported.Functional.Use)]<-"Stabilizing agent"
tocurate$Harmonized.Functional.Use[grepl("kcl",tocurate$Reported.Functional.Use)]<-"Stabilizing agent" #assume kcl etc is stabilizer per research
tocurate$Harmonized.Functional.Use[grepl("oilfield shale control",tocurate$Reported.Functional.Use)]<-"Stabilizing agent" # per research
tocurate$Harmonized.Functional.Use[grepl("shale inhibitor",tocurate$Reported.Functional.Use)]<-"Stabilizing agent" # per research
tocurate$Harmonized.Functional.Use[grepl("shale control",tocurate$Reported.Functional.Use)]<-"Stabilizing agent" # per research
tocurate$Harmonized.Functional.Use[grepl("shale swelling control",tocurate$Reported.Functional.Use)]<-"Stabilizing agent" # per research

tocurate$Harmonized.Functional.Use[grepl("kci substitute",tocurate$Reported.Functional.Use)]<-"Stabilizing agent" # per research



tocurate$Harmonized.Functional.Use[grepl("acid",tocurate$Reported.Functional.Use)]<-"pH regulating agent"
tocurate$Harmonized.Functional.Use[grepl("accid",tocurate$Reported.Functional.Use)]<-"pH regulating agent"
tocurate$Harmonized.Functional.Use[grepl("acic",tocurate$Reported.Functional.Use)]<-"pH regulating agent"
tocurate$Harmonized.Functional.Use[grepl("adiz",tocurate$Reported.Functional.Use)]<-"pH regulating agent"
tocurate$Harmonized.Functional.Use[grepl("buff",tocurate$Reported.Functional.Use)]<-"pH regulating agent"
tocurate$Harmonized.Functional.Use[grepl("phh adjusting agents",tocurate$Reported.Functional.Use)]<-"pH regulating agent"
tocurate$Harmonized.Functional.Use[grepl("biuffer",tocurate$Reported.Functional.Use)]<-"pH regulating agent"
tocurate$Harmonized.Functional.Use[grepl("hydrochloric",tocurate$Reported.Functional.Use)]<-"pH regulating agent"
tocurate$Harmonized.Functional.Use[grepl("hydrochloride",tocurate$Reported.Functional.Use)]<-"pH regulating agent"


tocurate$Harmonized.Functional.Use[grepl("ph ",tocurate$Reported.Functional.Use)]<-"pH regulating agent"
tocurate$Harmonized.Functional.Use[grepl("ph-",tocurate$Reported.Functional.Use)]<-"pH regulating agent"
tocurate$Harmonized.Functional.Use[grepl("hcl",tocurate$Reported.Functional.Use)]<-"pH regulating agent" #assume hcl is pH regulating agent per research

tocurate$Harmonized.Functional.Use[grepl("frict",tocurate$Reported.Functional.Use)]<-"Lubricating agent"
tocurate$Harmonized.Functional.Use[grepl("reducer",tocurate$Reported.Functional.Use)]<-"Lubricating agent"
tocurate$Harmonized.Functional.Use[grepl("lub",tocurate$Reported.Functional.Use)]<-"Lubricating agent"
tocurate$Harmonized.Functional.Use[grepl("friciton",tocurate$Reported.Functional.Use)]<-"Lubricating agent"
tocurate$Harmonized.Functional.Use[grepl("lub",tocurate$Reported.Functional.Use)]<-"Lubricating agent"
tocurate$Harmonized.Functional.Use[grepl("hvfr",tocurate$Reported.Functional.Use)]<-"Lubricating agent"




tocurate$Harmonized.Functional.Use[grepl("scale",tocurate$Reported.Functional.Use)]<-"Anti-scaling agent"
tocurate$Harmonized.Functional.Use[grepl("sacle",tocurate$Reported.Functional.Use)]<-"Anti-scaling agent"
tocurate$Harmonized.Functional.Use[grepl("salt",tocurate$Reported.Functional.Use) & grepl("inh",tocurate$Reported.Functional.Use) ]<-"Anti-scaling agent"
tocurate$Harmonized.Functional.Use[grepl("sale",tocurate$Reported.Functional.Use) & grepl("inh",tocurate$Reported.Functional.Use) ]<-"Anti-scaling agent"
tocurate$Harmonized.Functional.Use[grepl("sclae",tocurate$Reported.Functional.Use)]<-"Anti-scaling agent"
tocurate$Harmonized.Functional.Use[grepl("scaling",tocurate$Reported.Functional.Use)]<-"Anti-scaling agent"
tocurate$Harmonized.Functional.Use[grepl("scalant",tocurate$Reported.Functional.Use)]<-"Anti-scaling agent"
tocurate$Harmonized.Functional.Use[grepl("dcale inhibitor",tocurate$Reported.Functional.Use)]<-"Anti-scaling agent"
tocurate$Harmonized.Functional.Use[grepl("scal",tocurate$Reported.Functional.Use)]<-"Anti-scaling agent"
tocurate$Harmonized.Functional.Use[grepl("scal inhibitor",tocurate$Reported.Functional.Use)]<-"Anti-scaling agent"
tocurate$Harmonized.Functional.Use[grepl("svcale",tocurate$Reported.Functional.Use)]<-"Anti-scaling agent"


tocurate$Harmonized.Functional.Use[grepl("sufractant",tocurate$Reported.Functional.Use)]<-"Surfactant (surface active agent)"
tocurate$Harmonized.Functional.Use[grepl("surf",tocurate$Reported.Functional.Use)]<-"Surfactant (surface active agent)"
tocurate$Harmonized.Functional.Use[grepl("sludg",tocurate$Reported.Functional.Use)]<-"Surfactant (surface active agent)"
tocurate$Harmonized.Functional.Use[grepl("sufactant",tocurate$Reported.Functional.Use)]<-"Surfactant (surface active agent)" #per research
tocurate$Harmonized.Functional.Use[grepl("wettability",tocurate$Reported.Functional.Use)]<-"Surfactant (surface active agent)" #per research


tocurate$Harmonized.Functional.Use[grepl("silt suspending agent",tocurate$Reported.Functional.Use)]<-"Silt suspending agent (HF)" #per research
tocurate$Harmonized.Functional.Use[grepl("silt fines suspender",tocurate$Reported.Functional.Use)]<-"Silt suspending agent (HF)" #per research
tocurate$Harmonized.Functional.Use[grepl("silt suspender",tocurate$Reported.Functional.Use)]<-"Silt suspending agent (HF)" #per research
tocurate$Harmonized.Functional.Use[grepl("silt suspenders",tocurate$Reported.Functional.Use)]<-"Silt suspending agent (HF)" #per research
tocurate$Harmonized.Functional.Use[grepl("silt suspending agent",tocurate$Reported.Functional.Use)]<-"Silt suspending agent (HF)" #per research


tocurate$Harmonized.Functional.Use[grepl("prop",tocurate$Reported.Functional.Use)]<-"Proppant (HF)"
tocurate$Harmonized.Functional.Use[grepl("bulk",tocurate$Reported.Functional.Use)]<-"Proppant (HF)"
tocurate$Harmonized.Functional.Use[grepl("sand",tocurate$Reported.Functional.Use)]<-"Proppant (HF)"
tocurate$Harmonized.Functional.Use[grepl("ropp",tocurate$Reported.Functional.Use)]<-"Proppant (HF)"
tocurate$Harmonized.Functional.Use[grepl("peoppant",tocurate$Reported.Functional.Use)]<-"Proppant (HF)"
tocurate$Harmonized.Functional.Use[grepl("poppant",tocurate$Reported.Functional.Use)]<-"Proppant (HF)"
tocurate$Harmonized.Functional.Use[grepl("prppant",tocurate$Reported.Functional.Use)]<-"Proppant (HF)"

tocurate$Harmonized.Functional.Use[grepl("demul",tocurate$Reported.Functional.Use) ]<-"Demulsifier"
tocurate$Harmonized.Functional.Use[grepl("non",tocurate$Reported.Functional.Use) & grepl("emul",tocurate$Reported.Functional.Use) ]<-"Demulsifier"
tocurate$Harmonized.Functional.Use[grepl("non",tocurate$Reported.Functional.Use) & grepl("emus",tocurate$Reported.Functional.Use) ]<-"Demulsifier"
tocurate$Harmonized.Functional.Use[grepl("de-emulsifier",tocurate$Reported.Functional.Use) ]<-"Demulsifier"
tocurate$Harmonized.Functional.Use[grepl("demul",tocurate$Reported.Functional.Use) ]<-"Demulsifier"
tocurate$Harmonized.Functional.Use[grepl("emulsion  preventer",tocurate$Reported.Functional.Use) ]<-"Demulsifier"
tocurate$Harmonized.Functional.Use[grepl("emulsion control",tocurate$Reported.Functional.Use) ]<-"Demulsifier"
tocurate$Harmonized.Functional.Use[grepl("emulsion pr",tocurate$Reported.Functional.Use) ]<-"Demulsifier"
tocurate$Harmonized.Functional.Use[grepl("non-emlusifier",tocurate$Reported.Functional.Use) ]<-"Demulsifier"
tocurate$Harmonized.Functional.Use[grepl("non emuilsifier",tocurate$Reported.Functional.Use) ]<-"Demulsifier"
tocurate$Harmonized.Functional.Use[grepl("non imulsifier",tocurate$Reported.Functional.Use) ]<-"Demulsifier"
tocurate$Harmonized.Functional.Use[grepl("non-ionic noneumulsifier",tocurate$Reported.Functional.Use) ]<-"Demulsifier"
tocurate$Harmonized.Functional.Use[grepl("non emsulifier",tocurate$Reported.Functional.Use) ]<-"Demulsifier"
tocurate$Harmonized.Functional.Use[grepl("emulson breaker",tocurate$Reported.Functional.Use) ]<-"Demulsifier"
tocurate$Harmonized.Functional.Use[grepl("emulsion breake",tocurate$Reported.Functional.Use) ]<-"Demulsifier"






tocurate$Harmonized.Functional.Use[grepl("iron",tocurate$Reported.Functional.Use)]<-"Chelating agent"
tocurate$Harmonized.Functional.Use[grepl("fe ",tocurate$Reported.Functional.Use)]<-"Chelating agent"
tocurate$Harmonized.Functional.Use[grepl("aluminum",tocurate$Reported.Functional.Use)]<-"Chelating agent"
tocurate$Harmonized.Functional.Use[grepl("chel",tocurate$Reported.Functional.Use)]<-"Chelating agent"
tocurate$Harmonized.Functional.Use[grepl("irion control additives",tocurate$Reported.Functional.Use)]<-"Chelating agent"
tocurate$Harmonized.Functional.Use[grepl("sequesterant",tocurate$Reported.Functional.Use)]<-"Chelating agent"
tocurate$Harmonized.Functional.Use[grepl("metal binder",tocurate$Reported.Functional.Use)]<-"Chelating agent"





tocurate$Harmonized.Functional.Use[grepl("sealer",tocurate$Reported.Functional.Use)]<-"Sealant (barrier)"


tocurate$Harmonized.Functional.Use[grepl("bioc",tocurate$Reported.Functional.Use)]<-"Biocide"
tocurate$Harmonized.Functional.Use[grepl("bacteri",tocurate$Reported.Functional.Use)]<-"Biocide"
tocurate$Harmonized.Functional.Use[grepl("microb",tocurate$Reported.Functional.Use)]<-"Biocide"
tocurate$Harmonized.Functional.Use[grepl("disinf",tocurate$Reported.Functional.Use)]<-"Biocide"
tocurate$Harmonized.Functional.Use[grepl("bleaching",tocurate$Reported.Functional.Use)]<-"Biocide"
tocurate$Harmonized.Functional.Use[grepl("sanit",tocurate$Reported.Functional.Use)]<-"Biocide"
tocurate$Harmonized.Functional.Use[grepl("antmircrobial",tocurate$Reported.Functional.Use)]<-"Biocide"
tocurate$Harmonized.Functional.Use[grepl("bactercide",tocurate$Reported.Functional.Use)]<-"Biocide"
tocurate$Harmonized.Functional.Use[grepl("biodice",tocurate$Reported.Functional.Use)]<-"Biocide"
tocurate$Harmonized.Functional.Use[grepl("bioicde",tocurate$Reported.Functional.Use)]<-"Biocide"
tocurate$Harmonized.Functional.Use[grepl("bioside",tocurate$Reported.Functional.Use)]<-"Biocide"
tocurate$Harmonized.Functional.Use[grepl("bocide",tocurate$Reported.Functional.Use)]<-"Biocide"
tocurate$Harmonized.Functional.Use[grepl("boicide",tocurate$Reported.Functional.Use)]<-"Biocide"
tocurate$Harmonized.Functional.Use[grepl("cide",tocurate$Reported.Functional.Use)]<-"Biocide"
tocurate$Harmonized.Functional.Use[grepl("disenfectant",tocurate$Reported.Functional.Use)]<-"Biocide"
tocurate$Harmonized.Functional.Use[grepl("bio control",tocurate$Reported.Functional.Use)]<-"Biocide"
tocurate$Harmonized.Functional.Use[grepl("bioide",tocurate$Reported.Functional.Use)]<-"Biocide"
tocurate$Harmonized.Functional.Use[grepl("antimicobial solution",tocurate$Reported.Functional.Use)]<-"Biocide"
tocurate$Harmonized.Functional.Use[grepl("antimicrovial solution",tocurate$Reported.Functional.Use)]<-"Biocide"



tocurate$Harmonized.Functional.Use[grepl("emission control",tocurate$Reported.Functional.Use)]<-"Emission controlling agent (HF)"


tocurate$Harmonized.Functional.Use[grepl("corros",tocurate$Reported.Functional.Use)]<-"Corrosion inhibitor"
tocurate$Harmonized.Functional.Use[grepl("corrison",tocurate$Reported.Functional.Use)]<-"Corrosion inhibitor"
tocurate$Harmonized.Functional.Use[grepl("corr inhib",tocurate$Reported.Functional.Use)]<-"Corrosion inhibitor"
tocurate$Harmonized.Functional.Use[grepl("cossosion",tocurate$Reported.Functional.Use)]<-"Corrosion inhibitor"
tocurate$Harmonized.Functional.Use[grepl("corriosion",tocurate$Reported.Functional.Use)]<-"Corrosion inhibitor"
tocurate$Harmonized.Functional.Use[grepl("corosion",tocurate$Reported.Functional.Use)]<-"Corrosion inhibitor"
tocurate$Harmonized.Functional.Use[grepl("cossosion",tocurate$Reported.Functional.Use)]<-"Corrosion inhibitor"
tocurate$Harmonized.Functional.Use[grepl("corossion",tocurate$Reported.Functional.Use)]<-"Corrosion inhibitor"
tocurate$Harmonized.Functional.Use[grepl("corrsion",tocurate$Reported.Functional.Use)]<-"Corrosion inhibitor"


tocurate$Harmonized.Functional.Use[grepl("block",tocurate$Reported.Functional.Use)]<-"Blocking agent"


tocurate$Harmonized.Functional.Use[grepl("o2",tocurate$Reported.Functional.Use) & grepl("scav",tocurate$Reported.Functional.Use) ]<-"O2 scavenger (HF)"
tocurate$Harmonized.Functional.Use[grepl("ox",tocurate$Reported.Functional.Use) & grepl("scav",tocurate$Reported.Functional.Use) ]<-"O2 scavenger (HF)"
tocurate$Harmonized.Functional.Use[grepl("oxygen savenger",tocurate$Reported.Functional.Use)  ]<-"O2 scavenger (HF)"
tocurate$Harmonized.Functional.Use[grepl("oxygen scvanger",tocurate$Reported.Functional.Use)  ]<-"O2 scavenger (HF)"



tocurate$Harmonized.Functional.Use[grepl("h2",tocurate$Reported.Functional.Use) & grepl("scav",tocurate$Reported.Functional.Use) ]<-"H2S scavenger (HF)"
tocurate$Harmonized.Functional.Use[grepl("sulf",tocurate$Reported.Functional.Use) & grepl("scav",tocurate$Reported.Functional.Use) ]<-"H2S scavenger (HF)"
tocurate$Harmonized.Functional.Use[grepl("h2s inhibitor",tocurate$Reported.Functional.Use)  ]<-"H2S scavenger (HF)"
tocurate$Harmonized.Functional.Use[grepl("h2s neutrializer",tocurate$Reported.Functional.Use)  ]<-"H2S scavenger (HF)"
tocurate$Harmonized.Functional.Use[grepl("h2s prevention",tocurate$Reported.Functional.Use) ]<-"H2S scavenger (HF)"
tocurate$Harmonized.Functional.Use[grepl("h2s treatment",tocurate$Reported.Functional.Use)  ]<-"H2S scavenger (HF)"
tocurate$Harmonized.Functional.Use[grepl("hydrogen sulfide control",tocurate$Reported.Functional.Use)]<-"H2S scavenger (HF)"
tocurate$Harmonized.Functional.Use[grepl("prevent h2s formatio",tocurate$Reported.Functional.Use)]<-"H2S scavenger (HF)"
tocurate$Harmonized.Functional.Use[grepl("h2s inhibitor",tocurate$Reported.Functional.Use)  ]<-"H2S scavenger (HF)"
tocurate$Harmonized.Functional.Use[grepl("prevent h2s formation",tocurate$Reported.Functional.Use)  ]<-"H2S scavenger (HF)"
tocurate$Harmonized.Functional.Use[grepl("h2s neutrializer",tocurate$Reported.Functional.Use)  ]<-"H2S scavenger (HF)"
tocurate$Harmonized.Functional.Use[grepl("h2s prevention",tocurate$Reported.Functional.Use)  ]<-"H2S scavenger (HF)"
tocurate$Harmonized.Functional.Use[grepl("h2s treatment",tocurate$Reported.Functional.Use)  ]<-"H2S scavenger (HF)"
tocurate$Harmonized.Functional.Use[grepl("h2s treatment",tocurate$Reported.Functional.Use)  ]<-"H2S scavenger (HF)"
tocurate$Harmonized.Functional.Use[grepl("hydrogen sulfide control",tocurate$Reported.Functional.Use)  ]<-"H2S scavenger (HF)"
tocurate$Harmonized.Functional.Use[grepl("liquid scavenger",tocurate$Reported.Functional.Use)  ]<-"H2S scavenger (HF)"


tocurate$Harmonized.Functional.Use[grepl("paraf",tocurate$Reported.Functional.Use)]<-"Paraffin inhibitor (HF)"
tocurate$Harmonized.Functional.Use[grepl("parraf",tocurate$Reported.Functional.Use)]<-"Paraffin inhibitor (HF)"
tocurate$Harmonized.Functional.Use[grepl("parrifin",tocurate$Reported.Functional.Use)]<-"Paraffin inhibitor (HF)"


test<-tocurate[which(is.na(tocurate$Harmonized.Functional.Use)),]
#write.csv(test,"tocurate.csv")

#Fill in curated functions
k<-match(curatedpurposes$Reported.Functional.Use,tocurate$Reported.Functional.Use)
curatedpurposes$Harmonized.Functional.Use_new<-tocurate$Harmonized.Functional.Use[k]
j<-which(is.na(curatedpurposes$Harmonized.Functional.Use))
curatedpurposes$Harmonized.Functional.Use[j]<-curatedpurposes$Harmonized.Functional.Use_new[j]

curatedpurposes<-curatedpurposes[,c("Reported.Functional.Use","Harmonized.Functional.Use")]

#fix a few curations that may need updating from CPDat curations, or that weren't handled by the above logic
curatedpurposes$Harmonized.Functional.Use[which(curatedpurposes$Reported.Functional.Use=="polymer")]<-"Viscosity modifier"
curatedpurposes$Harmonized.Functional.Use[which(curatedpurposes$Reported.Functional.Use=="resin")]<-NA
curatedpurposes$Harmonized.Functional.Use[which(curatedpurposes$Reported.Functional.Use=="other")]<-NA # we just leave these NA
curatedpurposes$Harmonized.Functional.Use[which(curatedpurposes$Reported.Functional.Use=="miscellaneous")]<-NA # we just leave these NA
curatedpurposes$Harmonized.Functional.Use[which(curatedpurposes$Reported.Functional.Use=="additive")]<-NA # we just leave these NA
curatedpurposes$Harmonized.Functional.Use[which(curatedpurposes$Reported.Functional.Use=="various")]<-NA # we just leave these NA
curatedpurposes$Harmonized.Functional.Use[which(curatedpurposes$Reported.Functional.Use=="processing aid")]<-NA # we just leave these NA
curatedpurposes$Harmonized.Functional.Use[which(curatedpurposes$Reported.Functional.Use=="oil")]<-NA # we just leave these NA
curatedpurposes$Harmonized.Functional.Use[which(curatedpurposes$Reported.Functional.Use=="additives")]<-NA # we just leave these NA
curatedpurposes$Harmonized.Functional.Use[which(curatedpurposes$Reported.Functional.Use=="other additive")]<-NA # we just leave these NA
curatedpurposes$Harmonized.Functional.Use[which(curatedpurposes$Reported.Functional.Use=="unknown")]<-NA # we just leave these NA
curatedpurposes$Harmonized.Functional.Use[which(curatedpurposes$Reported.Functional.Use=="water treatment")]<-NA #this is ambiguous

curatedpurposes$Harmonized.Functional.Use[which(curatedpurposes$Reported.Functional.Use=="bleach")]<-"Biocide"
curatedpurposes$Harmonized.Functional.Use[which(curatedpurposes$Reported.Functional.Use=="bleaching agent")]<-"Biocide"                                                                                    

curatedpurposes$Harmonized.Functional.Use[which(curatedpurposes$Reported.Functional.Use=="paraffin")]<-"Paraffin inhibitor (HF)"                                                                                    


#these are multiple functions that are likely same product/ingredient, create duplicate with second curation
#These were curated as biocides or others; add scale inhibitors
new<-data.frame(c("scale inhibito & nitrate reducing bacteria","Anti-scaling agent"),
                c("scale inhibitor & anbitbacterial agent","Anti-scaling agent"),
                c("scale inhibitor & antibacterial agent","Anti-scaling agent"),
                c("scale inhibitor & nitrate reducing bacteria","Anti-scaling agent"),
                c("scale inhibitor & nitrate reducting bacteria","Anti-scaling agent"),
                c("paraffin & scale additives","Anti-scaling agent"),
                c("paraffin & scale additive","Anti-scaling agent"),
                c("nitrate reducing bacteria & scale inhibitor","Anti-scaling agent"),
                c("paraffin scale additives","Anti-scaling agent"),                
                c("scale paraffin inhibitor","Anti-scaling agent"),                
                c("paraffin  scale additives","Anti-scaling agent"),          
                c("paraffin and scale additives","Anti-scaling agent"),                
                c("paraffin & scake additive","Anti-scaling agent"),    
                c("parraffin & scale additives","Anti-scaling agent"),   
                c("parrifin & scale additive","Anti-scaling agent"),                   
                c("scale/paraffin inhibitor","Anti-scaling agent"),   
                c("paraffin & scale inhibitor","Anti-scaling agent"),                   
                c("scale inihibitor & nitrate reducing bacteria","Anti-scaling agent"),
                c("proppant/scale inhibitor","Anti-scaling agent"),
                c("fracturing scale inhibitor/bacteria aid","Anti-scaling agent"),
                c("scale/bacteria control","Anti-scaling agent"),
                c("scale inhibitor/iron control","Anti-scaling agent"),
                c("reduce iron/scale","Anti-scaling agent"),
                c("corrosion/scale inhibitor","Anti-scaling agent"),
                c("scale / corrosion inhibitor","Anti-scaling agent"),
                c("scale inhibitor/non-emulsifier","Anti-scaling agent"),
                c("scale/h2s scavenger","Anti-scaling agent"),
                c("scale/paraffin inhibitor","Anti-scaling agent"),
                

#add surfactact 

               c("surfactant and biocide","Surfactant (surface active agent)"),
#add Demuls. 

               c("acid non-emulsifier and iron control","Demulsifier"),
#add foamant 

                c("foam booster/stabilizer","Foamant"),
                c("surfactant &amp; foamer","Foamant"),
                c("surfactants & foamers","Foamant"),
                c("surfacants & foamers","Foamant"),
                c("surfactant & foamer","Foamant"),
                c("surfactants & foamer","Foamant"),
                c("surfactant blend/foamer","Foamant"),
                c("surfactants (foamers)","Foamant"),
                c("surfactants (foamers)","Foamant"),
                c("surfacants & foamers","Foamant"),

#These were curated as Anti-scaling agent or other; add dispersant
                c("scale inhibitor/polymer dispersant","Dispersing agent"),
                c("scale inhibitor/polymer dispersant winterized","Dispersing agent"),
                c("enduro-paraffin and dispersand/solvent","Dispersing agent"),
                c("scale inhibitor/polymer dispersant","Dispersing agent"),
                c("scale inhibitor/polymer dispersant winterized","Dispersing agent"),
                c("emulsifier/dispersing agent","Dispersing agent"),
                c("paraffin inhibitor/dispersant","Dispersing agent"),
        
#Add surfactant
                c("biocide/surfactant","Surfactant (surface active agent)"),
                c("furfactant and foamer","Surfactant (surface active agent)"),
                c("surfactant and biocide","Surfactant (surface active agent)"),
                c("corrosion inhibitor/surfactant","Surfactant (surface active agent)"),
                c("non-emulsifier/surfactant","Surfactant (surface active agent)"),
                c("non-emulsifier/ sufactant","Surfactant (surface active agent)"),
                c("non-emulsifying surfactant","Surfactant (surface active agent)"),
                c("surfactant/non-emulsifier","Surfactant (surface active agent)"),
                c("non-emulsifier/ surfactant","Surfactant (surface active agent)"),
                c("surfactant / non-emulsifier / flow back","Surfactant (surface active agent)"),
                c("non-emulsifier/flowback surfactant","Surfactant (surface active agent)"),
               
#add breaker

                c("breakers and breaker catalysts","Breaker (HF)"),
                c("breakers and breaker catalyst","Breaker (HF)"),
                c("breakers & breaker catalyst","Breaker (HF)"),
                c("breaker and catalyst","Breaker (HF)"),
                c("breaker and breaker catalyst","Breaker (HF)"),
                c("breaker/oxidizer","Breaker (HF)"),
                
                
                
#others
c("bleaching agent/crosslinker","Chemical reaction regulator"),
c("breaker/biocide","Breaker (HF)"),
c("iron control/ ph buffer","pH regulating agent"),
c("acid inhibitor/iron control","pH regulating agent"),
c("acid non-emulsifier and iron control","Demulsifier"),               
c("iron sulfide control/bio","Biocide"),   
c("corrosion inhibitor/biocide","Biocide"),   
c("surfactant / non-emulsifier / flow back","Flowback agent (HF)"),   
c("non-emulsifier/flowback surfactant","Flowback agent (HF)"),   
c("flowback/non-emulsifier","Flowback agent (HF)"), 
c("flow back/non-emulsifier","Flowback agent (HF)"), 
c("emulsifiers / viscosifiers","Viscosity modifier"),                 
c("corrosion inhibitor/iron control","Chelating agent"),               
c("defoamer/binder","Binder"),               
c("friction reducer/viscosifier","Viscosity modifier"), 
c("friction reducer/viscosifer","Viscosity modifier"), 
c("iron reducing agent / oxygen scavenger","Chelating agent"), 
c("crosslinker/oxidizer","Chemical reaction regulator"), 
c("crosslinker/buffer","Chemical reaction regulator"), 
c("buffer/crosslinker","Chemical reaction regulator"), 
c("crossliner/buffer","Chemical reaction regulator"), 
c("paraffin/corrosion inhibitor","Corrosion inhibitor"), 
c("acid / solvent","Solvent"), 
c("citric acid/dilution","Diluent"), 
c("acidizing/dilution","Diluent"), 
c("carrier/acidizing","Diluent"), 
c("acid retarder / viscosifier","Viscosity modifier"), 
c("acid/diverting agent","Diverting agent (HF)"), 
c("clay control/activator","Chemical reaction regulator"), 
c("clay control / stabilizers","Chemical reaction regulator"), 
c("foam booster/stabilizer","Foamant"), 
c("foamer/surfactant","Foamant"), 
c("non-elmulsifier/surfactant","Demulsifier"), 
c("non-elmulsifier/surfactant","Demulsifier"), 
c("surfactant/clay control","Stabilizing agent"), 
c("emulsifier/surfactant","Emulsifier"), 
c("surfactant/ flow back aid","Flowback agent (HF)"), 
c("surfactant/flo back aid","Flowback agent (HF)"), 
c("surfactant blend/foamer","Foamant"), 
c("clay control/surfactant","Stabilizing agent"), 
c("surfactant and clay inhibitor blend","Stabilizing agent"), 

#add two func

c("borate crosslinker - stabilizer - ph buffer","Stabilizing agent"),
c("borate crosslinker - stabilizer - ph buffer","Chemical reaction regulator"))

new<-t(new)
colnames(new)<-c("Reported.Functional.Use","Harmonized.Functional.Use")
curatedpurposes<-rbind(curatedpurposes,new)


#these are multiple function records that are likely overreporting or errors
curatedpurposes$Harmonized.Functional.Use[which(curatedpurposes$Reported.Functional.Use=="propping agent. acid corrosion inhibitor. friction reducer. biocide. microbiocide. microbiocide. blocking agent. clean perforations")]<-NA  
curatedpurposes$Harmonized.Functional.Use[which(curatedpurposes$Reported.Functional.Use=="paraffin/ne/scale inh./bio/h2s scav.")]<-NA  

write.csv(curatedpurposes,"Output/curatedpurposes_forexamination.csv") # for ease of examination for QA
#forQA
test<-data.frame(table(curatedpurposes$Harmonized.Functional.Use))

#Match the data back to the original reported purposes
temp1<-uniquepurposes
colnames(uniquepurposes)[1]<-"Purpose"
temp2<-left_join(uniquepurposes,uniquepurposes_indexed)
temp2$Reported.Functional.Use<-trimws(tolower(temp2$Reported.Functional.Use)) #we standardized these before curating

finalcuratedpurposes<-left_join(temp2,curatedpurposes)

#save final data
saveRDS(finalcuratedpurposes,"output/final_curated_purposes.RDS")

