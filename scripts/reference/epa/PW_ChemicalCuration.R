#This is code to clean up the FracFocus chemical list and run it through the ChemExpo chemical 
#preprocessing script to generate a list to send to DSSTOX team for curation 
#Kristin Isaacs 7/2024

library(dplyr)
library(stringr)
library(tidyr)
library(readxl)
library(reticulate)

#functions-------------------------------------------------------------------------------------*
#Custom version of chemical_equal function from ctxR that maintains the 400 status responses to get suggestions
#This functionality has since been added to ctxR by maintainer Paul Kruse

prepare_word <- function(word){
  # Handle question marks
  split_words <- stringr::str_split(string = word,
                                    pattern = '\\?',
                                    n = 2)[[1]]
  if (length(split_words) == 1){
    temp_word <- urltools::url_encode(split_words[[1]])
  } else {
    if (nchar(split_words[[2]]) == 0){
      temp_word <- urltools::url_encode(split_words[[1]])
    } else {
      temp_word <- paste0(urltools::url_encode(split_words[[1]]),
                          '?',
                          urltools::url_encode(split_words[[2]]),
                          '=')
    }
  }
  
  # Handle other non-alpha-numeric characters
  temp_word <- gsub("%26", "&", temp_word)
  temp_word <- gsub("%23", "#", temp_word)
  return(temp_word)
}

chemical_equal_all = function(word = NULL, API_key = NULL, Server = chemical_api_server) {
  if (is.null(word) || !is.character(word)) {
    stop("Please input a character value for word!")
  }
  else if (is.null(API_key)) {
    if (has_ccte_key()) {
      API_key <- ccte_key()
    }
    else {
      stop("Please input an API_key!")
    }
  }
  word <- prepare_word(word)
  response <- httr::GET(url = paste0(Server, "/search/equal/", 
                                     word), httr::add_headers(.headers = c(`Content-Type` = "application/json", 
                                                                           `x-api-key` = API_key)))
    return(jsonlite::fromJSON(httr::content(response, as = "text")))

  return()
}

get_all_chemdata = function(word_list = NULL, API_key = NULL, rate_limit = 0L) 
{
  if (is.null(API_key) || !is.character(API_key)) {
    stop("Please input a character string containing a valid API key!")
  }
  if (!is.numeric(rate_limit) | (rate_limit < 0)) {
    warning("Setting rate limit to 0 seconds between requests!")
    rate_limit <- 0L
  }
  if (!is.null(word_list)) {
    if (!is.character(word_list) & !all(sapply(word_list, 
                                               is.character))) {
      stop("Please input a character list for word_list!")
    }
    word_list <- unique(word_list)
    results <- lapply(word_list, function(t) {
      Sys.sleep(rate_limit)
      attempt <- tryCatch({
        chemical_equal_all(word = t, API_key = API_key)
      }, error = function(cond) {
        message(t)
        message(cond$message)
        return(NA)
      })
      return(attempt)
    })
    names(results) <- word_list
    return(results)
  }
  else {
    stop("Please input a list of chemical names!")
  }
}


#Read in unique chemical names

chems<-read.csv("Output/uniqueingredients.csv")

#standardize names
chems$StandardIngredientName<-trimws(tolower(chems$IngredientName))
chems$CASRN<-trimws(tolower(chems$CASNumber))

#Some custom cleaning before sending to DSSTox Python cleaning script

#Standardize spacing and punctuation
chems$StandardIngredientName<-gsub(")  ",")", chems$StandardIngredientName) 
chems$StandardIngredientName<-gsub(") ",")", chems$StandardIngredientName)  
chems$StandardIngredientName<-gsub(" ) ",")", chems$StandardIngredientName) 
chems$StandardIngredientName<-gsub(")",") ", chems$StandardIngredientName) 

chems$StandardIngredientName<-gsub(" \\(","(", chems$StandardIngredientName) 
chems$StandardIngredientName<-gsub("\\( ","(", chems$StandardIngredientName)  
chems$StandardIngredientName<-gsub(" \\( ","(", chems$StandardIngredientName)  
chems$StandardIngredientName<-gsub("\\("," (", chems$StandardIngredientName) 

chems$StandardIngredientName<-gsub(" , ",",", chems$StandardIngredientName)  
chems$StandardIngredientName<-gsub(" ,",",", chems$StandardIngredientName)  
chems$StandardIngredientName<-gsub(",  ",",", chems$StandardIngredientName)  
chems$StandardIngredientName<-gsub(", ",",", chems$StandardIngredientName)  
chems$StandardIngredientName<-gsub(",",", ", chems$StandardIngredientName) 

chems$StandardIngredientName<-gsub("//.  ",".", chems$StandardIngredientName)  
chems$StandardIngredientName<-gsub("//. ",".", chems$StandardIngredientName)  
chems$StandardIngredientName<-gsub("//.",". ", chems$StandardIngredientName) 

chems$StandardIngredientName<-gsub("- ","-", chems$StandardIngredientName) 
chems$StandardIngredientName<-gsub(" - ","-", chems$StandardIngredientName) 
chems$StandardIngredientName<-gsub(" -","-", chems$StandardIngredientName) 
#chems$StandardIngredientName<-gsub("-"," ", chems$StandardIngredientName)

chems$StandardIngredientName<-gsub("&#39", "'", chems$StandardIngredientName) 

chems$StandardIngredientName<-gsub("\"","", chems$StandardIngredientName)
chems$StandardIngredientName<-gsub("//*","", chems$StandardIngredientName)


#At this point, run chems through chemical Python cleaning script.
#This script was developed by Katherine Phillips, EPA, in collaboration with
#the DSStox team to identify errors, reporting of chemical names as generic functions,
#specific 

#make into format expected by python cleaning script
newchemstocurate1<-chems[,c("X","StandardIngredientName","CASRN" )]
colnames(newchemstocurate1)<-c("id","raw_chem_name","raw_cas")
#save as the expected filename
write.csv(newchemstocurate1,"uncurated_chemicals_fracfocus_07092024.csv")

#run the cleaning script

#this runs the most recent "uncurated_chemicals" file
py_run_file("clean_chems_FF.py") #this requires reticulate as well as installation of a Python instance

#read in cleaning script result MANUALLY CLEANED TWO INSTANCES OF "[[" or "]]" (messes up API call and couldn't quickly ID a regex soln)
newchemstocurate<-read.csv("Input/cleaned_chemicals_for_curation-Jul-10-2024.csv") #intermediate file provided at Zenodo (with Input)

#we can now remove id and duplicates that arose from case harmonization
newchemstocurate<-newchemstocurate[,c("raw_chem_name","raw_cas","chemical_name","casrn","casrn_comment","name_comment","cas_in_name")]
newchemstocurate<-unique(newchemstocurate)

library(stringr)
newchemstocurate$chemical_name <- str_replace_all(newchemstocurate$chemical_name,"\\[\\[", "") #fixes two names that include double brackets (messes up API calls)
newchemstocurate$chemical_name <-  str_replace_all(newchemstocurate$chemical_name, "\\]\\]", "") #fixes two names that include double brackets (messes up API calls)

#Now generate unique lists of initial cleaned names and valid CASRN to send to chemistry APIs for curation to DTXSID

#Generate unique list of names; do some more cleaning

uniquenames<-data.frame(unique(newchemstocurate$chemical_name[which(newchemstocurate$chemical_name!="")]))
colnames(uniquenames)<-"chemical_name"
uniquenames$nameid<-1:length(1:length(uniquenames$chemical_name))

#Additional blocklist words for the FF database specifically
#remove anything with "proprietary" or "confidential", etc in name or CASRN
uniquenames<-uniquenames[!grepl("proprietary",uniquenames$chemical_name),]
uniquenames<-uniquenames[!grepl("confid",uniquenames$chemical_name),]
uniquenames<-uniquenames[!grepl("trade ",uniquenames$chemical_name),]
uniquenames<-uniquenames[!grepl("tradesecret",uniquenames$chemical_name),]
uniquenames<-uniquenames[!grepl("supplied by o",uniquenames$chemical_name),]
uniquenames<-uniquenames[!grepl("haz",uniquenames$chemical_name),]
uniquenames<-uniquenames[!grepl("unknown",uniquenames$chemical_name),]
uniquenames<-uniquenames[!grepl("unavailable",uniquenames$chemical_name),]
uniquenames<-uniquenames[!grepl("undisclosed",uniquenames$chemical_name),]
uniquenames<-uniquenames[!grepl("%",uniquenames$chemical_name),] #mixtures or other strings that can't be curated to single chemical

uniquenames<-uniquenames[order(uniquenames$chemical_name),]

#Call CCTE Chemistry APIs to curate chems, including identifying chemical suggestions
library(ccdR) #this is an R package wrapper for the CCTE chemistry, exposure, and hazard APIs as of 5/2025 the package is called ctxR

# This calls the CCTE API key from the environment;  other users must please request their own if this code is implemented external to EPA
#see https://www.epa.gov/comptox-tools/computational-toxicology-and-exposure-apis

key<-Sys.getenv("APIKEY")

do_name_call<-0 #Flag for actually calling the API. Can be re-run upon new data being added to DSSTox

if (do_name_call==1){

#Call the API to curate names
#I broke these out into groups of 200 w/2 sec pause per discussion with API team
curateddata<-list()
start<-1
batchsize<-200
for (i in 1:length(uniquenames$chemical_name)){
 #cat("/n",i)
 if (i %% batchsize == 0) {
  end<-start+batchsize-1
  chembatch<-uniquenames$chemical_name[start:end]
  nextdata <- get_all_chemdata(API_key=key, word_list = chembatch)
  cat("\n",start)
  start<-i+1  
  curateddata <- c(curateddata, nextdata)
  Sys.sleep(2) #pause for 2 sec
 }
#trailing batch
  if (i  == length(uniquenames$chemical_name) & i %% batchsize != 0) {
    end<-i
    chembatch<-uniquenames$chemical_name[start:end]
    nextdata <- get_all_chemdata(API_key=key, word_list = chembatch)
    curateddata <- c(curateddata, nextdata)
  }
}

#save the curated results
saveRDS(curateddata,"Output/APIchemicalnameresults.rds")
}

curateddata<-readRDS("Output/APIchemicalnameresults.rds") #intermediate file provided with code. In "Output".

#parse the API results for names 

checkit = function(list){
  return("dtxsid" %in% names(list))   #check if a chemical was curated
}

k<-unlist(lapply(curateddata, checkit))
k1<-curateddata[k]

for (i in seq_along(k1)){ #could be updated with lapply
  k1[[i]]["cleanname"]<-names(k1)[i]  #this is because the API does update the name formatting a bit; this retains orig name on data frame
  
}

curated_names<-bind_rows(k1)
#if there are two suggested DTSXIDs, take the one with highest curation rank 
#order by cleanname then rank, remove any duplicates (this ensures best curation only retained)
curated_names<-curated_names[order(curated_names$cleanname,curated_names$rank),]
curated_names<-curated_names[!duplicated(curated_names$cleanname),]

#remove some final records that aren't chemicals (this could be done in earlier name cleaning steps but removed here since API calls complete)
blocks<-c("Carrier","Ceramic","Clay","Corn meal","Corn starch","formal")

curated_names<-curated_names[which(!curated_names$searchValue %in% blocks),]
 

k2<-curateddata[!k]

#remove polu\\ydimethyl diallyl ammonium chloride -  the slash impacted API response
k2<-k2[!names(k2)=="polu\\ydimethyl diallyl ammonium chloride"]
names<-names(k2)

suggested_names<-data.frame(matrix(nrow=length(k2),ncol=2))
names(suggested_names)<-c("chemical","suggestions")
suggested_names$chemical<-names
for (i in 1:length(k2)) {
  suggested_names$suggestions[i]<-paste(k2[[i]]$suggestions, collapse = "|")
}

#Ignore multiple suggestions (must be manually curated later) or suggestions that are ICHI keys 
suggested_names<-suggested_names[which(suggested_names$suggestions!="NA"),]
suggested_names<-suggested_names[!grepl("\\|",suggested_names$suggestions),] #remove chemicals with more than 1 recommendation
suggested_names<-suggested_names[!grepl("\\|",suggested_names$suggestions),] #remove chemicals with more than 1 recommendation
suggested_names<-suggested_names[!str_detect(suggested_names$suggestions,"[[:upper:]]"),] #remove INCHI key recs - these seem to be strange to me


#Get the curations associated with the recommendations
#write for hand curation of suggestions
#write.csv(suggested_names,"../output/suggested_names.csv") #Uncomment if running code from beginning

#Acceptance of suggested names were hand curated (could always be updated)

suggested_names_curated<-read.csv("Output/suggested_names_curated.csv") # Intermediate file provided at Zenodo. In "Output".

suggested_names_curated<-suggested_names_curated[which(suggested_names_curated$acceptsuggestion==1),]

unique_suggested_names<-unique(suggested_names$suggestions)
k<-grepl("/",unique_suggested_names)
#remove the 3 with problematic /s. These don't return anything from DSSTox anyway
unique_suggested_names<-unique_suggested_names[!k]

do_suggestions_call<-0 # Flag for calling API for suggestions. Can be re-run when new data added to DSSTox.

if (do_suggestions_call==1){
  
curatedsuggestions<-list()
start<-1
batchsize<-200
for (i in 1:length(unique_suggested_names)){
  #cat("/n",i)
  if (i %% batchsize == 0) {
    end<-start+batchsize-1
    chembatch<-unique_suggested_names[start:end]
    nextdata <- get_all_chemdata(API_key=key, word_list = chembatch)
    cat("\n",start)
    start<-i+1  
    curatedsuggestions <- c(curatedsuggestions, nextdata)
    Sys.sleep(2) #pause for 2 sec
  }
  #trailing batch
  if (i  == length(unique_suggested_names) & i %% batchsize != 0) {
    end<-i
    chembatch<-unique_suggested_names[start:end]
    nextdata <- get_all_chemdata(API_key=key, word_list = chembatch)
    curatedsuggestions <- c(curatedsuggestions, nextdata)
  }
}
saveRDS(curatedsuggestions,"Output/APIchemicalsuggestionresults.rds")
}

curatedsuggestions<-readRDS("Output/APIchemicalsuggestionresults.rds") # Intermediate file provided at Zenodo. In "Output".

#pull out successfully curated suggestions

k<-unlist(lapply(curatedsuggestions, checkit))

k1<-curatedsuggestions[k]

for (i in seq_along(k1)){ #could be updated with lapply
  k1[[i]]["suggname"]<-names(k1)[i]  #this is because the API does update the name formatting a bit; this retains original name on data frame

}


final_curated_suggestions<-bind_rows(k1)

#if there are two suggested names, take the one with highest curation rank 
#order by suggname then rank, remove any duplicates (this ensures best suggestion only retained)
final_curated_suggestions<-final_curated_suggestions[order(final_curated_suggestions$suggname,final_curated_suggestions$rank),]
final_curated_suggestions<-final_curated_suggestions[!duplicated(final_curated_suggestions$suggname),]

#merge back in with "pre-suggestion" names
colnames(suggested_names_curated)[colnames(suggested_names_curated)=="suggestions"]<-"suggname" #rename for merging
suggested_names_curated<-left_join(suggested_names_curated,final_curated_suggestions)

#Curate CASRN

#Generate unique list of CASRN; do some more cleaning

uniqueCAS<-data.frame(unique(newchemstocurate$casrn[which(newchemstocurate$casrn!="")]))
colnames(uniqueCAS)<-"CASRN"
uniqueCAS$casid<-1:length(1:length(uniqueCAS$CASRN))

#remove anything with "proprietary" or "confidential", etc in name or CASRN
uniqueCAS<-uniqueCAS[!grepl("proprietary",uniqueCAS$CASRN),]

uniqueCAS<-uniqueCAS[order(uniqueCAS$CASRN),]

#Call the API to curate CASRN

do_CASRN_call<-0 #flag for calling API. Could be re-run when DSSTox updated.

if (do_CASRN_call==1){
#I broke these out into groups of 200 w/2 sec pause per discussion with Asif
curatedCAS<-list()
start<-1
batchsize<-200
for (i in 1:length(uniqueCAS$CASRN)){
  #cat("/n",i)
  if (i %% batchsize == 0) {
    end<-start+batchsize-1
    chembatch<-uniqueCAS$CASRN[start:end]
    nextdata <- get_all_chemdata(API_key=key, word_list = chembatch)
    cat("\n",start)
    start<-i+1  
    curatedCAS <- c(curatedCAS, nextdata)
    Sys.sleep(2) #pause for 2 sec
  }
  #trailing batch
  if (i  == length(uniqueCAS$CASRN) & i %% batchsize != 0) {
    end<-i
    chembatch<-uniqueCAS$CASRN[start:end]
    nextdata <- get_all_chemdata(API_key=key, word_list = chembatch)
    curatedCAS <- c(curatedCAS, nextdata)
  }
}

saveRDS(curatedCAS,"Output/APICASresults.rds")
}

curatedCAS<-readRDS("Output/APICASresults.rds") # Intermediate file provided at Zenodo. In "Output".

#pull out successfully curated suggestions

k<-unlist(lapply(curatedCAS, checkit))

k1<-curatedCAS[k]

for (i in seq_along(k1)){ #could be updated with lapply
  k1[[i]]["cleancas"]<-names(k1)[i]  #this is because the API might update the CAS formatting a bit; this retains orig CAS on data frame
}

final_curated_CAS<-bind_rows(k1)
#if there are two suggested DTSXIDs, take the one with highest curation rank 
#order by cleanname then rank, remove any duplicates (this ensures best curation only retained)
final_curated_CAS<-final_curated_CAS[order(final_curated_CAS$cleancas,final_curated_CAS$rank),]
final_curated_CAS<-final_curated_CAS[!duplicated(final_curated_CAS$cleancas),]


#Combine the curated names and curated suggestions, retaining the link between the suggestion and the reported name.
#reported_name is cleaned reported name from frac focus
#suggested_name is name suggested by chemical API for clean reported name.If a suggested name exists, the DTXSID is associated with it.
curated_names$suggested_name<-"" #these are names that were curated successfully by original cleaned name

#now rename the DTXSID and preferred name columns so we can ulimately merge with the cleaned CAS data
#dropped the preferred casrn for now; we can always add metadata for the final DTXSID back in at the end
colnames(curated_names)[colnames(curated_names)=="cleanname"]<-"clean_name" #just clean up labeling for consistency
colnames(curated_names)[colnames(curated_names)=="dtxsid"]<-"dtxsid_by_name"
colnames(curated_names)[colnames(curated_names)=="preferredName"]<-"preferredName_by_name"
curated_names<-curated_names[,c("clean_name","suggested_name","dtxsid_by_name","preferredName_by_name")]

suggested_names_curated$suggested_name<-suggested_names_curated$suggname #these are curated chemicals that had to use suggestions
suggested_names_curated$clean_name<-suggested_names_curated$chemical
colnames(suggested_names_curated)[colnames(suggested_names_curated)=="dtxsid"]<-"dtxsid_by_name"
colnames(suggested_names_curated)[colnames(suggested_names_curated)=="preferredName"]<-"preferredName_by_name"
suggested_names_curated<-suggested_names_curated[,c("clean_name","suggested_name","dtxsid_by_name","preferredName_by_name")]

all_curated_chemicals_by_name<-bind_rows(curated_names,suggested_names_curated)

##Rename the rows for the "by CAS" curations
colnames(final_curated_CAS)[colnames(final_curated_CAS)=="cleancas"]<-"clean_casrn" #just clean up labeling for consistency
colnames(final_curated_CAS)[colnames(final_curated_CAS)=="dtxsid"]<-"dtxsid_by_casrn"
colnames(final_curated_CAS)[colnames(final_curated_CAS)=="preferredName"]<-"preferredName_by_casrn"
final_curated_CAS<-final_curated_CAS[,c("clean_casrn","dtxsid_by_casrn","preferredName_by_casrn")]

#now merge in the curations by name and CAS with the original output of the python cleaning
#change some names to match final curated data
colnames(newchemstocurate)[colnames(newchemstocurate)=="chemical_name"]<-"clean_name"
colnames(newchemstocurate)[colnames(newchemstocurate)=="casrn"]<-"clean_casrn"

#merge the curations by name
cleaned_curated_data<-left_join(newchemstocurate,all_curated_chemicals_by_name)

#merge the curations by CAS
cleaned_curated_data<-left_join(cleaned_curated_data,final_curated_CAS)

#add columns for DTXSID clash
cleaned_curated_data$conflict<-0
k<-is.na(cleaned_curated_data$dtxsid_by_casrn)
j<-is.na(cleaned_curated_data$dtxsid_by_name)
cleaned_curated_data$conflict[which(!j & !k & cleaned_curated_data$dtxsid_by_name!=cleaned_curated_data$dtxsid_by_casrn)]<-1

#remove duplicates (we could map back)

#save final cleaned and curated chemistry data
saveRDS(cleaned_curated_data,"Output/cleaned_curated_chemical_data.RDS")

# Create list of chemicals (including conflicts) to send to Tony for curation
k<-cleaned_curated_data


#Develop data to send to Tony for curation

#Annotate each record
#QCLevels


# Additional blockwords

blockparts<-paste0(
  "propriet","|",
  "confid","|",
  "not provided","|",
  "cbi","|",
  "mixture","|",
  "unknown","|",
  "ingredient","|",
  "blend","|",
  "materials","|",
  "surfactant","|",
#  "polymer","|",
  "not ","|",
  "undiscl","|",
  "miscellaneous","|",
  "propiet","|",
  "discl","|",
  "information","|",
  "no reportable","|",
  "hazardous","|",
  "listed ","|",
  "other ","|",
  "place ","|",
  "inerts","|",
  "miscelanious","|",
  "supplied","|",
  " material","|",
  "coating","|",
  "organisms","|",
  "bacteria","|",
  "supplied","|",
  "party","|",
  "base fluid","|",
  "conf bus info","|",
  "trade secret")


#harmonize mentions of proprietary
k$blockit<-0
k$blockit[grepl(blockparts,k$raw_chem_name)]<-1
k$blockit[grepl(blockparts,k$raw_cas)]<-1
k$blockit[grepl("functional use",k$name_comment)]<-1
k$blockit[grepl("Ambiguous",k$name_comment)]<-1
k$blockit[which(k$raw_chem_name=="none")]<-1 #to avoid removing chemicals with "none" in name
k$blockit[which(k$raw_cas=="none")]<-1 #to avoid removing chemicals with "none" in name

removed<-k[k$blockit==1,]

k$QCLevel<-0
k$QCLevel[k$dtxsid_by_casrn==k$dtxsid_by_name & !is.na(k$dtxsid_by_casrn)]<-1
k$QCLevel[is.na(k$dtxsid_by_casrn) & !is.na(k$dtxsid_by_name)]<-2
k$QCLevel[!is.na(k$dtxsid_by_casrn) & is.na(k$dtxsid_by_name)]<-3
k$QCLevel[k$dtxsid_by_casrn!=k$dtxsid_by_name & !is.na(k$dtxsid_by_casrn) & !is.na(k$dtxsid_by_name)]<-4


k$QCLevel[grepl(blockparts,k$raw_chem_name) & !is.na(k$dtxsid_by_name)]<-5
k$QCLevel[grepl(blockparts,k$raw_chem_name) & !is.na(k$dtxsid_by_cas)]<-5
k$QCLevel[grepl(blockparts,k$raw_cas) & !is.na(k$dtxsid_by_name)]<-6
#k$QCLevel[grepl(blockparts,k$raw_cas) & !is.na(k$dtxsid_by_cas)]<-6
k$QCLevel[is.na(k$dtxsid_by_casrn) & is.na(k$dtxsid_by_name)]<-7

k$QCLevel[(k$blockit == 1) & is.na(k$dtxsid_by_name) & is.na(k$dtxsid_by_cas)]<- -999



removed<-k[k$QCLevel==-999,]

#Clean up the fours and fives for tony

table(k$QCLevel)

#for observation
ones<-k[which(k$QCLevel==1),]
threes<-k[which(k$QCLevel==3),]
twos<-k[which(k$QCLevel==2),]
fours<-k[which(k$QCLevel==4),]
fives<-k[which(k$QCLevel==5),]
sixes<-k[which(k$QCLevel==6),]
sevens<-k[which(k$QCLevel==7),]

#write remaining fives for curation

#write.csv(unique(k$raw_chem_name[k$QCLevel==7]),"Output/for_manual_drop_curation.csv")

#read in hand curated data
manualcurated<-read.csv("Output/for_manual_drop_curation_annotated.csv") # Intermediate file provided at Zenodo. In "Output".

k$QCCategory<-k$QCLevel
forsubmittal<-k[which(k$QCCategory!=1 & k$QCCategory!=3 & k$QCCategory!= -999),]

forsubmittal<-forsubmittal[order(forsubmittal$QCCategory),]

j<-which(trimws(forsubmittal$suggested_name)!="")
forsubmittal$clean_name[j]<-forsubmittal$suggested_name[j]
forsubmittal$name_comment[j]<-paste0(forsubmittal$name_comment[j]," ","clean name is API suggested name")

forsubmittal<-forsubmittal[,!colnames(forsubmittal) %in% c("suggested_name","cas_in_name","blockit","QCLevel"),]

j<-which(forsubmittal$raw_chem_name=="na" & forsubmittal$clean_casrn=="")

forsubmittal1<-forsubmittal[-j,]


#write.csv(forsubmittal,"Output/FF_producedwater_forcuration.csv")


#Read in final dataset of manually curated records from the DSSTox team

curated<-read_excel("Input/FF_producedwater_aftercuration_02062025.xlsx") #hand curated results; intermediate file provided with code. In "Input".
colnames(curated)[1]<-"record"

#Unfortunately we realized that DSSTox did change some of the raw_cas names.
#Here I am fixing them so they can be later merged with raw ingredient data
#We can do this by the record number in the saved version of forsubmittal

temp<-read.csv("Output/FF_producedwater_forcuration.csv") #intermediate file provided with code. In "Output".
colnames(temp)[1]<-"record"
temp$correctrawCAS<-temp$raw_cas
temp2<-temp[,c("record","correctrawCAS")]

curated<-left_join(curated,temp2)
forQA<-curated[,c("raw_cas","correctrawCAS")] #just checking alignment; looks good

curated$raw_cas<-curated$correctrawCAS

#Mistakes caught in manual QA
curated$DTXSID[which(curated$record==10025)]<-"DTXSID6020143"


#Manual check of reported names versus preferred names for obvious errors for QAlevel3 records
write.csv(threes[,c("clean_name","dtxsid_by_casrn","preferredName_by_casrn")],"manualcheck3s.csv")


#handle a few remaining cases where a unambiguously defined mixture could be mapped to two DTXSIDs
#create a duplicate record and map both chemicals to original name for merging back with well data
#Just update DTXSIDs since preferred names will be updated in a bulk manner

#handle "10% hcl, 7.5% acetic acid blend"	"7647-01-0 & 64-19-7"
curated$DTXSID[which(curated$record==9733)]<-curated$dtxsid_by_casrn[which(curated$record==9733)]
curated$DTXSID[which(curated$record==9734)]<-curated$dtxsid_by_casrn[which(curated$record==9734)]

#handle "diethanolamide, methanol 64-56-1, ethylene glycol monobutyl ether 111-76-2"
n<-"diethanolamide, methanol 64-56-1, ethylene glycol monobutyl ether 111-76-2"
rec<-curated[which(curated$raw_chem_name==n),]
rec$record<-max(curated$record,na.rm = T)+1

# add a second record for the second CASRN
curated2<-rbind(curated,rec)

#assign the two names
curated2$DTXSID[which(curated2$record==20443)]<-"DTXSID1024097"
curated2$DTXSID[which(curated2$record==1851)]<-"DTXSID2021731" #assuming 64-56-1 is a typo of methanol CASRN 

#Drop records that could not be curated
curated2<-curated2[which(!curated2$DTXSID=="-"),]

#Add the manual curations from DSSTox back in with Category 1 and Category 3 assignments
#we will add preferred names and CASRN later
ones$DTXSID<-ones$dtxsid_by_casrn
threes$DTXSID<-threes$dtxsid_by_casrn

keep<-c("raw_chem_name","raw_cas","clean_name","clean_casrn", "name_comment", "casrn_comment","DTXSID")
ones2<-ones[,keep]
threes2<-threes[,keep]
curated2<-curated2[,keep]


final_curated_chemicals1<-rbind(ones2, threes2, curated2)


#write list of DTXSIDs for sending to CompTox Dashboard to obtain preferred names and casrn


#update the preferred names and CASRN  with data directly obtained from the CompTox Dashboard since some were missing in the manual
#curation to DTXSID by the DSSTox team
#read in CompTox Dashboard data for the unique DTXSIDs this includes presence on other dashboard lists of chemicals in produced water
dash<-read.csv("Input/CCD-Batch-Search_2025-02-14_04_17_18.csv") #intermediate file provided with Input at Zenodo

#Calculate the number of chemicals not in existing lists
countnew<-length(which(dash$EPAHFR=="-" & dash$EPAHFRTABLE2=="-" & dash$FRACFOCUS=="-" & dash$PRODWATER=="-"))


#preferred data
preferred<-dash[,c("INPUT", "DTXSID","PREFERRED_NAME","CASRN")]

final_curated_chemicals1<-left_join(final_curated_chemicals1,preferred) # there are a few new DTXSIDs without names and CASRN in EPA's dashboard yet can be obtained from https://comptox.epa.gov/dashboard/
final_curated_chemicals1$raw_chem_name<-trimws(final_curated_chemicals1$raw_chem_name)

#Merge back in with the original list of chemicals (after the initial simple text clean up); this allows us to retain clean names and comments for all records on final file
newchemstocurate$raw_chem_name<-trimws(newchemstocurate$raw_chem_name)
newchemstocurate$raw_cas<-trimws(newchemstocurate$raw_cas)


final_curated_chemicals<-left_join(newchemstocurate,unique(final_curated_chemicals1[,!colnames(final_curated_chemicals1) %in% c("clean_name","clean_casrn","name_comment","casrn_comment")]))

#Final manual review of threes: things curated by CASRN but not by name - manually compared
#curated names with raw names to identify any issues. These would arise when a CASRn typographical
#or other error resulted in a valid CASRN for a chemical that was inconsistent with the reported name
#It could not be confirmed that the reported CASRN was correct for these records
#Therefore, curated DTXSIDs were removed for these records

final_curated_chemicals$DTXSID[which(final_curated_chemicals$raw_chem_name=="n-olefins" &  final_curated_chemicals$PREFERRED_NAME=="Sulfonic acids, C12-14-2-alkene")]<-""
final_curated_chemicals$DTXSID[which(final_curated_chemicals$raw_chem_name=="1, 3-dixolane-4-methanol, 2, 2-dimethyl-"   &  final_curated_chemicals$PREFERRED_NAME=="2-Methylquinazoline")]<-""
final_curated_chemicals$DTXSID[which(final_curated_chemicals$raw_chem_name=="n-olefins" &  final_curated_chemicals$PREFERRED_NAME=="(2a,3-Dihydrobenz[cd]indol-1(2H)-yl)phenylmethanone")]<-""
final_curated_chemicals$DTXSID[which(final_curated_chemicals$raw_chem_name=="phenol  formaldehyde resin" &  final_curated_chemicals$PREFERRED_NAME=="Ammonium chloride")]<-""
final_curated_chemicals$DTXSID[which(final_curated_chemicals$raw_chem_name=="silica substrate" &  final_curated_chemicals$PREFERRED_NAME=="17beta-Estradiol")]<-""
final_curated_chemicals$DTXSID[which(final_curated_chemicals$raw_chem_name=="phenol formaldehyde resin" &  final_curated_chemicals$PREFERRED_NAME=="Diethylenetriaminepenta(methylenephosphonic acid)")]<-""
final_curated_chemicals$DTXSID[which(final_curated_chemicals$raw_chem_name=="vinylidene c hloridemethylacrylate copolymer" &  final_curated_chemicals$PREFERRED_NAME=="Pyrrolo[2,3-b]pyrrole")]<-""
final_curated_chemicals$DTXSID[which(final_curated_chemicals$raw_chem_name=="tetrakis (hydroxymethyl) phosphonium sulphate (2:1) " &  final_curated_chemicals$PREFERRED_NAME=="DNA (mouse strain C57BL/6J clone K330328H03 EST (expressed sequence tag))")]<-""
final_curated_chemicals$DTXSID[which(final_curated_chemicals$raw_chem_name=="benzene, c-10-16 alkyl derivatives" &  final_curated_chemicals$PREFERRED_NAME=="Titanium alloy, base -")]<-""
final_curated_chemicals$DTXSID[which(final_curated_chemicals$raw_chem_name=="oganophilic clay" &  final_curated_chemicals$PREFERRED_NAME=="2-(BROMOMETHYL)-1,3-DINITROBENZENE")]<-""
final_curated_chemicals$DTXSID[which(final_curated_chemicals$raw_chem_name=="organophilic clay" &  final_curated_chemicals$PREFERRED_NAME=="2-(BROMOMETHYL)-1,3-DINITROBENZENE")]<-""
final_curated_chemicals$DTXSID[which(final_curated_chemicals$raw_chem_name=="phenol-formaldehyde resin" &  final_curated_chemicals$PREFERRED_NAME=="4-Methyl-3,4-dihydro-2H-pyrrole-5-carbonitrile")]<-""
final_curated_chemicals$DTXSID[which(final_curated_chemicals$raw_chem_name=="quaternary ammonium compounds, benzyl-c12-c18-alkyldimethyl, chlorides" &  final_curated_chemicals$PREFERRED_NAME=="Naltrexone methobromide")]<-""
final_curated_chemicals$DTXSID[which(final_curated_chemicals$raw_chem_name=="solvent naptha (petroleum), heavy arom." &  final_curated_chemicals$PREFERRED_NAME=="2-Acetyl-3-[(difluoroboranyl)oxy]-5alpha-androst-2-en-17beta-yl acetate")]<-""
final_curated_chemicals$DTXSID[which(final_curated_chemicals$raw_chem_name=="polyoxyethelenedimethylliminioethylenedimethylliminioethylenedichloride" &  final_curated_chemicals$PREFERRED_NAME=="O-[4-Hydroxy-3-(2-methylpropyl)phenyl]-3,5-diiodotyrosine")]<-""
final_curated_chemicals$DTXSID[which(final_curated_chemicals$raw_chem_name=="d-glucuronic acid, polymer with 6-deoxy-l-mannose and d-glucose, acetate, calcium magnesium potassium sodium salt" &  final_curated_chemicals$PREFERRED_NAME=="Diutan gum")]<-""
final_curated_chemicals$DTXSID[which(final_curated_chemicals$raw_chem_name=="petroleum, oxidized" &  final_curated_chemicals$PREFERRED_NAME=="methyl 4-{[(1,3,7-trimethyl-2,6-dioxo-2,3,6,7-tetrahydro-1h-purin-8-yl)methyl]amino}benzoate")]<-""
final_curated_chemicals$DTXSID[which(final_curated_chemicals$raw_chem_name=="solvent naptha" &  final_curated_chemicals$PREFERRED_NAME=="Carboxymethyl cellulose")]<-""
final_curated_chemicals$DTXSID[which(final_curated_chemicals$raw_chem_name=="petroleum crude oil" &  final_curated_chemicals$PREFERRED_NAME=="Ammonium ligninsulfonate")]<-""
                                              
#clear out the preferred names and CASRN for these
final_curated_chemicals$CASRN[which(final_curated_chemicals$DTXSID=="")]<-""
final_curated_chemicals$PREFERRED_NAME[which(final_curated_chemicals$DTXSID=="")]<-""

final_curated_chemicals<-final_curated_chemicals[,colnames(final_curated_chemicals)!="INPUT"]
final_curated_chemicals<-final_curated_chemicals[,colnames(final_curated_chemicals)!="cas_in_name"]

  
dtxsidcount<-length(unique(final_curated_chemicals$DTXSID))
write.csv(unique(final_curated_chemicals1$DTXSID),"Output/finaldtxsids.csv")

#write final chemicals
saveRDS(final_curated_chemicals,"Output/curated_chemicals.rds")
write.csv(final_curated_chemicals, "Output/curated_chemicals.csv") 







