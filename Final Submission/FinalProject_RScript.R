#----------------------------------- ALY6015_FinalProject ------------------------------------#

location_harshit <- "~/Documents/Northeastern University/MPS Analytics/ALY 6015/Final Project/Presidential_Election_2016_Classification/"
location_akash <- "C:/Users/rajak/OneDrive/Desktop/Study/University/ALY6015 - Intermediate Analytics/Final Project/Presidential_Election_2016_Classification/"
location <- ifelse(!dir.exists(paths = location_harshit), location_akash, location_harshit)

source(paste0(location, "Final Submission/Helper.R"))

# Import the Packages
declareAndImportPackages()

# Import/Load the data set
ElectionData <- loadData(location)

# Get a Glimpse/View of the data set
glimpse(ElectionData)

threeLineTable(ElectionData[1:5, 4:11], "Table 1: Snapshot of Data", "Snapshot of Election Data Sample", "Data Snapshot")

# ------------------------------------- Merging External Data sets ----------------------------------- #
# Reading new external data set
population <- read.csv(paste0(location, "Data/USPopulationByCounty.csv"))
election2020 <- read.csv(paste0(location, "Data/2020ElectionResults.csv"))
region <- read.csv(paste0(location, "Data/Regions.csv"))

# Reading Multiple Sheets from Excel Workbook
raceAgeGender2011And2015_Path <- paste0(location, "Data/Additional Data.xlsx")
raceAgeGender2011And2015_SheetNames <- excel_sheets(raceAgeGender2011And2015_Path)
raceAgeGender2011And2015_List <- lapply(raceAgeGender2011And2015_SheetNames, read_excel, path = raceAgeGender2011And2015_Path)
names(raceAgeGender2011And2015_List) <- raceAgeGender2011And2015_SheetNames
list2env(raceAgeGender2011And2015_List, .GlobalEnv)


# Combining the external data sets with the original election data sets
ElectionData <- ElectionData %>% inner_join(population, by = c("county", "state"))
# --------------------------------------------#
election2020$county_fips <- as.factor(election2020$county_fips)
ElectionData$c_fips <- as.factor(ElectionData$c_fips)
ElectionData <- ElectionData %>% inner_join(election2020, by = c("c_fips" = "county_fips"))
# --------------------------------------------#
ElectionData <- ElectionData %>% inner_join(region, by = c("state" = "state.code"))
# --------------------------------------------#
ElectionData_GenderAgeRace <- ElectionData %>% inner_join(
  `Gender 2011` %>% mutate(`County Code` = factor(`County Code`)) %>% dplyr::select(Female, Male, `County Code`) %>% 
                    rename(population.female.2011 = Female, population.male.2011 = Male), 
  by = c("c_fips" = "County Code"))
# --------------------------------------------#
ElectionData_GenderAgeRace <- ElectionData_GenderAgeRace %>% inner_join(
  `Gender 2015` %>% mutate(`County Code` = factor(`County Code`)) %>% dplyr::select(Female, Male, `County Code`) %>% 
                    rename(population.female.2015 = Female, population.male.2015 = Male), 
  by = c("c_fips" = "County Code"))
# --------------------------------------------#
ElectionData_GenderAgeRace <- ElectionData_GenderAgeRace %>% inner_join(
  `Race 2011` %>% mutate(`County Code` = factor(`County Code`)) %>% dplyr::select(`American Indian or Alaska Native`, `Asian or Pacific Islander`, `Black or African American`, `White`, `County Code`) %>% 
                  rename(`American Indian or Alaska Native.2011` = `American Indian or Alaska Native`, `Asian or Pacific Islander.2011` = `Asian or Pacific Islander`, `Black or African American.2011` = `Black or African American`, `White.2011` = `White`), 
  by = c("c_fips" = "County Code"))
# --------------------------------------------#
ElectionData_GenderAgeRace <- ElectionData_GenderAgeRace %>% inner_join(
  `Race 2015` %>% mutate(`County Code` = factor(`County Code`)) %>% dplyr::select(`American Indian or Alaska Native`, `Asian or Pacific Islander`, `Black or African American`, `White`, `County Code`) %>% 
    rename(`American Indian or Alaska Native.2015` = `American Indian or Alaska Native`, `Asian or Pacific Islander.2015` = `Asian or Pacific Islander`, `Black or African American.2015` = `Black or African American`, `White.2015` = `White`), 
  by = c("c_fips" = "County Code"))
# --------------------------------------------#

icol <- which(names(`Age 2011`) %in% c("County Code", "County", "State"))
colnames(`Age 2011`)[-icol] <- paste0(colnames(`Age 2011`)[-icol], ".2011")

ElectionData_GenderAgeRace <- ElectionData_GenderAgeRace %>% inner_join(
  `Age 2011` %>% mutate(`County Code` = factor(`County Code`)), 
  by = c("c_fips" = "County Code"))
# --------------------------------------------#

icol <- which(names(`Age 2015`) %in% c("County Code", "County", "State"))
colnames(`Age 2015`)[-icol] <- paste0(colnames(`Age 2015`)[-icol], ".2015")

ElectionData_GenderAgeRace <- ElectionData_GenderAgeRace %>% inner_join(
  `Age 2015` %>% mutate(`County Code` = factor(`County Code`)), 
  by = c("c_fips" = "County Code"))
  

# Generate Three Line Tables for External Data
threeLineTableForExternalData()


# Remove Unnecessary Resources
rm(list = c("population", "election2020", "region", "icol",
    "raceAgeGender2011And2015_Path", "raceAgeGender2011And2015_SheetNames", "raceAgeGender2011And2015_List",
    "Gender 2011", "Gender 2015", "Race 2011", "Race 2015", "Age 2011", "Age 2015")
)

###########################################################################################
#                                   Data Cleaning                                         #
###########################################################################################

# Since, libertarian feature has almost all the data points as NA. We're removing it for now to check other NA cases
# Also, Dropping unnecessary/duplicate features
ElectionData <- ElectionData %>% dplyr::select(-libertarian)
ElectionData_GenderAgeRace <- ElectionData_GenderAgeRace %>% dplyr::select(-libertarian, -State, -County.x, -County.y)

ElectionData$ruc03 <- sapply(ElectionData$ruc03, as.factor)
ElectionData$ruc13 <- sapply(ElectionData$ruc13, as.factor)
ElectionData_GenderAgeRace$ruc03 <- sapply(ElectionData_GenderAgeRace$ruc03, as.factor)
ElectionData_GenderAgeRace$ruc13 <- sapply(ElectionData_GenderAgeRace$ruc13, as.factor)


# Checking the records with missing/NA values
missingRecords <- ElectionData %>% filter(!complete.cases(ElectionData))
threeLineTable(missingRecords[, 4:11], "Table 5: Records with missing data", "", "Missing Data")

# Retrieving the names of features with missing values.
missingValuesCols <- names(which(colSums(is.na(ElectionData)) > 0))

# Imputing missing values with their respective features' mean value
for(i in 1:ncol(ElectionData)) {
  ifelse(is.numeric(ElectionData[,i]), 
    ElectionData[is.na(ElectionData[,i]), i] <- mean(ElectionData[,i], na.rm = TRUE),
    ifelse(is.character(ElectionData[,i]), "NULL", 0)
  )
}

for(i in 1:ncol(ElectionData_GenderAgeRace)) {
  ifelse(is.numeric(ElectionData_GenderAgeRace[,i]), 
         ElectionData_GenderAgeRace[is.na(ElectionData_GenderAgeRace[,i]), i] <- mean(ElectionData_GenderAgeRace[,i], na.rm = TRUE),
         ifelse(is.character(ElectionData_GenderAgeRace[,i]), "NULL", 0)
  )
}

# Factorize these 'Quality Assessment Texts' in the data set
ElectionData[sapply(ElectionData, is.character)] <- lapply(ElectionData[sapply(ElectionData, is.character)], as.factor)
ElectionData_GenderAgeRace[sapply(ElectionData_GenderAgeRace, is.character)] <- lapply(ElectionData_GenderAgeRace[sapply(ElectionData_GenderAgeRace, is.character)], as.factor)



###########################################################################################
#                               Creating Variables for 2020                               #
###########################################################################################
# Creating variables for 2020 Predictions
ElectionData$pd2020 <- round(ElectionData$democrats / (ElectionData$democrats + ElectionData$green + ElectionData$other + ElectionData$republican), 2)
ElectionData$pg2020 <- round(ElectionData$republican / (ElectionData$democrats + ElectionData$green + ElectionData$other + ElectionData$republican), 2)


###########################################################################################
#                                     Exploratory Data Analysis                           #
###########################################################################################

ElectionDataEDA <- ElectionData %>% 
  dplyr::select(v2016, pd2016, pg2016, ppd2016, v2012, pd2012, pg2012, ppd2012, v2008, pd2008, pg2008, ppd2012, population.2016, geograhic.region)


describeTable <- ElectionDataEDA %>% dplyr::select(pd2016, pg2016, ppd2016, pd2012, pg2012, ppd2012, pd2008, pg2008, ppd2012, population.2016)

overallStats <- describeTable %>%   describe(quant = c(.25, .75), IQR = TRUE)
overallStats <- round(overallStats, 2)
overallStats$vars <- rownames(overallStats)

options(scipen = 22)
threeLineTable(overallStats, "Table : Descriptive statistics of overall data", "", "Descriptive stats")

percDemocraticVotesStats <- ElectionDataEDA %>% dplyr::select(pd2008, pd2012, pd2016) %>%   describe(quant = c(.25, .75), IQR = TRUE) %>% 
  mutate(year = c(2008, 2012, 2016)) %>% relocate(year)

threeLineTable(percDemocraticVotesStats, "Table 6: Descriptive statistics of Democratic party %votes by year", "", "Democratic votes")

percRepublicanVotesStats <- ElectionDataEDA %>% dplyr::select(pg2008, pg2012, pg2016) %>% describe(quant = c(.25, .75), IQR = TRUE) %>% 
  mutate(year = c(2008, 2012, 2016)) %>% relocate(year)

threeLineTable(percRepublicanVotesStats, "Table 7: Descriptive statistics of Republican party %votes by year", "", "Republican votes")

percRepublicanVotesStatsSouth <- ElectionDataEDA %>% 
  dplyr::select(geograhic.region, pg2016) %>% filter(geograhic.region == "South") %>% 
  dplyr::select(-geograhic.region) %>% describe(quant = c(.25, .75), IQR = TRUE) %>% mutate(vars = "South")

percRepublicanVotesStatsWest <- ElectionDataEDA %>% 
  dplyr::select(geograhic.region, pg2016) %>% filter(geograhic.region == "West") %>% 
  dplyr::select(-geograhic.region) %>% describe(quant = c(.25, .75), IQR = TRUE) %>% mutate(vars = "West")

percRepublicanVotesStatsNE <- ElectionDataEDA %>% 
  dplyr::select(geograhic.region, pg2016) %>% filter(geograhic.region == "Northeast") %>% 
  dplyr::select(-geograhic.region) %>% describe(quant = c(.25, .75), IQR = TRUE) %>% mutate(vars = "Northeast")

percRepublicanVotesStatsMid <- ElectionDataEDA %>% 
  dplyr::select(geograhic.region, pg2016) %>% filter(geograhic.region == "Midwest") %>% 
  dplyr::select(-geograhic.region) %>% describe(quant = c(.25, .75), IQR = TRUE) %>% mutate(vars = "Midwest")


percRepublicanVotesStatReg <- rbind(percRepublicanVotesStatsSouth, percRepublicanVotesStatsWest, percRepublicanVotesStatsNE,
                                    percRepublicanVotesStatsMid)

threeLineTable(percRepublicanVotesStatReg, "Table 7: Descriptive statistics of Republican party %votes by region", "", "Republican votes region")

# Plot of outcome variable '% Democratic Votes' by region and year
percDVotesL <- ElectionDataEDA %>% 
  dplyr::select(geograhic.region, pd2008, pd2012, pd2016) %>% group_by(geograhic.region) %>% summarise('2008' = mean(pd2008, na.rm = TRUE),
                                                                          '2012' = mean(pd2012, na.rm = TRUE),
                                                                          '2016' = mean(pd2016, na.rm = TRUE)) %>%
  gather(year, pdVotes, c('2008', '2012', '2016'))

ggplot(data = percDVotesL, mapping = aes(x = reorder(factor(geograhic.region), pdVotes, function(x) -1*sum(x)), y = pdVotes, fill = year)) +
  geom_bar(position = "dodge", stat = "identity") +
  labs(title = "Percentage Democrat Votes by Region & Year") + 
  scale_x_discrete(name ="Region") + 
  scale_y_continuous(name = "Percent Democrat Votes") +
  theme_bw()


# Plot of outcome variable '% Republican Votes' by region and year
percRVotesL <- ElectionDataEDA %>% 
  dplyr::select(geograhic.region, pd2008, pd2012, pd2016) %>% group_by(geograhic.region) %>% summarise('2008' = mean(pd2008, na.rm = TRUE),
                                                                                                       '2012' = mean(pd2012, na.rm = TRUE),
                                                                                                       '2016' = mean(pd2016, na.rm = TRUE)) %>%
  gather(year, pgVotes, c('2008', '2012', '2016'))

ggplot(data = percRVotesL, mapping = aes(x = reorder(factor(geograhic.region), pgVotes, function(x) -1*sum(x)), y = pgVotes, fill = year)) +
  geom_bar(position = "dodge", stat = "identity") + labs(title = "Percent Republican Votes by Region & Year") + 
  scale_x_discrete(name ="Region") +  scale_y_continuous(name = "Percent Republican Votes") + theme_bw()



###########################################################################################
#                          Creating 2012 and 2016 Data Set                                #
###########################################################################################
ElectionData2012 <- ElectionData_GenderAgeRace %>% 
  dplyr::select(c_fips, v2012, vd2012, vg2012, pd2012, pg2012, diff2012, ppd2012, lforce11, emp11, unemp11, unrate11, 
         imig11, dmig11, nmig11, population.2011, population.female.2011, population.male.2011,
         `American Indian or Alaska Native.2011`, `Asian or Pacific Islander.2011`, `Black or African American.2011`, White.2011,
         `< 1 year.2011`, `10-14 years.2011`, `15-19 years.2011`, `20-24 years.2011`, `25-29 years.2011`, `30-34 years.2011`,
         `35-39 years.2011`, `40-44 years.2011`, `45-49 years.2011`, `50-54 years.2011`, `55-59 years.2011`, `60-64 years.2011`,
         `65-69 years.2011`, `70-74 years.2011`, `75-79 years.2011`, `80-84 years.2011`, `85+ years.2011`) %>% 
  add_column(year = "2012", .before = "v2012") %>% 
  rename_with(~ sub("(.2011$|2012$|11$)", "", .x), .cols = everything())


ElectionData2016 <- ElectionData_GenderAgeRace %>% 
  dplyr::select(c_fips, v2016, vd2016, vg2016, pd2016, pg2016, diff2016, ppd2016, lforce15, emp15, unemp15, unrate15, 
         imig15, dmig15, nmig15, population.2015, population.female.2015, population.male.2015,
         `American Indian or Alaska Native.2015`, `Asian or Pacific Islander.2015`, `Black or African American.2015`, White.2015,
         `< 1 year.2015`, `10-14 years.2015`, `15-19 years.2015`, `20-24 years.2015`, `25-29 years.2015`, `30-34 years.2015`,
         `35-39 years.2015`, `40-44 years.2015`, `45-49 years.2015`, `50-54 years.2015`, `55-59 years.2015`, `60-64 years.2015`,
         `65-69 years.2015`, `70-74 years.2015`, `75-79 years.2015`, `80-84 years.2015`, `85+ years.2015`) %>% 
  add_column(year = "2016", .before = "v2016") %>%
  rename_with(~ sub("(.2015$|2016$|15$)", "", .x), .cols = everything())

mergedElectionData2012And2016 <- rbind(ElectionData2012, ElectionData2016)

# Remove Unnecessary Resources
rm(list = c("ElectionData2012", "ElectionData2016")
)

###########################################################################################
#                                     Correlation                                         #
###########################################################################################
# numIntFeatures_ElectionData <- ElectionData[sapply(ElectionData, is.numeric)]
# corrFeatures_ElectionData <- ElectionData %>% 
#   dplyr::select(v2016, pd2016, pg2016, ppd2016, v2012, pd2012, pg2012, ppd2012, v2008, pd2008, pg2008, ppd2012, population.2016)

corrFeatures_ElectionData <- mergedElectionData2012And2016 %>% dplyr::select(-year)
correlationTable <- round(cor(corrFeatures_ElectionData, use = "pairwise"), 5)

threeLineTable(as.data.frame.matrix(correlationTable), "Table 8: Correlation Table of Numerical Features", "", "Correlation Table")

corrplot(cor(corrFeatures_ElectionData, use = "pairwise"), tl.cex = 0.8, type = "upper",
         col = brewer.pal(n = ncol(corrFeatures_ElectionData), name = "RdYlBu"))



###########################################################################################
#                             LASSO Regularization                                        #
###########################################################################################

## ------- Note: Operations on data set without the merge of Gender,Age,Race data sets. ------- #

################################################################
# Split data into train and test data 
################################################################
lassoFittingFeatures <-  ElectionData[sapply(ElectionData, is.numeric)] %>% 
  dplyr::select(-countya, -statea, -v2016, -vd2016, -vg2016, -pg2016, -diff2016, -ppd2016, 
         -v2012, -vd2012, -vg2012, -pg2012, -pd2012, -diff2012, -ppd2012,
         -v2008, -vd2008, -vg2008, -pg2008, -pd2008, -diff2008, -ppd2008)

set.seed(454)
lasso_x <- model.matrix(pd2016 ~ ., lassoFittingFeatures)[, -which(colnames(lassoFittingFeatures) == "pd2016")]
lasso_y <- lassoFittingFeatures$pd2016


################################################################
# Find best value of Lambda using Cross-Validation
################################################################
set.seed(454)
cv.lasso <- cv.glmnet(lasso_x, lasso_y)
plot(cv.lasso)

################################################################
# Optimal Value of Lambda; Minimizes the Prediction Error
# Lambda Min - Minimizes out of sample loss
# Lambda 1SE - Largest value of Lambda within 1 Standard Error of Lambda Min.
################################################################
log(cv.lasso$lambda.min)
log(cv.lasso$lambda.1se)

# Fit the model on training set using lambda.1se
model.lasso.1se <- glmnet(lasso_x, lasso_y, alpha = 1, lambda = cv.lasso$lambda.1se)

# Display Regression Coefficients
coef(model.lasso.1se)

threeLineTable(cbind(rownames(coef(model.lasso.1se)), as.data.frame.matrix(round(coef(model.lasso.1se), 4))), "Table 9: Lasso Regression on Training Data set using Lambda at 1 Standard Error", "", "Lasso_Regression_Table")


################################################################
# Make Prediction on the Data Set
################################################################
predict.lasso.1se <- predict(model.lasso.1se, newx = lasso_x)
lasso.rmse <- rmse(lasso_y, predict.lasso.1se)
lasso.rmse



################################################################
# Regression Fit - Model the data (Without merging Additional Gender, Race, Age Data Set)
################################################################

# regressionFittingFeatures <- ElectionData[sapply(ElectionData, is.numeric)]

lassoRegressedFeatures <- ElectionData %>% 
  dplyr::select(pd2016, unrate15, unrate12, emp11, inc15, pcpv15, pp51715, phsd, psca, pbdh, dmig13,
                nmig13, adkxe003, adkxe004, adkxe006, adkxe007, adple066, adolm001, green, republican)

fit <- lm(formula = pd2016 ~ ., data = lassoRegressedFeatures)
lm.summary <- summary(fit)
lm.summary

# Check 'Perfect Multi-Collinearity' because of "NA" values in summary of the fit model.
vif(fit)
alias(fit)

threeLineTable(cbind(rownames(lm.summary$coefficients), as.data.frame(round(lm.summary$coefficients, 4))), "Table 10: Linear Regression Model on Training Data set", "", "Linear_Regression_Table")

# RMSE of Linear Regression Model
rmse_linear_regression <- sqrt(mean(lm.summary$residuals^2))
rmse_linear_regression



## ------- Note: Operations on data set with the merge of Gender,Age,Race data sets. ------- #

################################################################
# Split data into train and test data 
################################################################
lassoFittingFeatures <-  ElectionData_GenderAgeRace[sapply(ElectionData_GenderAgeRace, is.numeric)] %>% 
  dplyr::select(-countya, -statea, -v2016, -vd2016, -vg2016, -pg2016, -diff2016, -ppd2016, 
                -v2012, -vd2012, -vg2012, -pg2012, -pd2012, -diff2012, -ppd2012,
                -v2008, -vd2008, -vg2008, -pg2008, -pd2008, -diff2008, -ppd2008)

set.seed(454)
lasso_x <- model.matrix(pd2016 ~ ., lassoFittingFeatures)[, -which(colnames(lassoFittingFeatures) == "pd2016")]
lasso_y <- lassoFittingFeatures$pd2016


################################################################
# Find best value of Lambda using Cross-Validation
################################################################
set.seed(454)
cv.lasso <- cv.glmnet(lasso_x, lasso_y)
plot(cv.lasso)

################################################################
# Optimal Value of Lambda; Minimizes the Prediction Error
# Lambda Min - Minimizes out of sample loss
# Lambda 1SE - Largest value of Lambda within 1 Standard Error of Lambda Min.
################################################################
log(cv.lasso$lambda.min)
log(cv.lasso$lambda.1se)

# Fit the model on training set using lambda.1se
model.lasso.1se <- glmnet(lasso_x, lasso_y, alpha = 1, lambda = cv.lasso$lambda.1se)

# Display Regression Coefficients
coef(model.lasso.1se)

threeLineTable(cbind(rownames(coef(model.lasso.1se)), as.data.frame.matrix(round(coef(model.lasso.1se), 4))), "Table 9: Lasso Regression on Training Data set using Lambda at 1 Standard Error", "", "Lasso_Regression_Table")


################################################################
# Make Prediction on the Training Data
################################################################
predict.lasso.1se <- predict(model.lasso.1se, newx = lasso_x)
lasso.rmse <- rmse(lasso_y, predict.lasso.1se)
lasso.rmse



################################################################
# Regression Fit - Model the data (Without merging Additional Gender, Race, Age Data Set)
################################################################

# regressionFittingFeatures <- ElectionData[sapply(ElectionData, is.numeric)]

lassoRegressedFeatures <- ElectionData_GenderAgeRace %>% 
  dplyr::select(pd2016, unrate15, unrate12, emp11, inc15, pcpv15, pp51715, phsd, psca, pbdh, dmig13,
               adkxe004, adkxe006, adkxe007, adolm001, green, republican, `Black or African American.2015`)

fit <- lm(formula = pd2016 ~ ., data = lassoRegressedFeatures)
lm.summary <- summary(fit)
lm.summary

# Check 'Perfect Multi-Collinearity' because of "NA" values in summary of the fit model.
vif(fit)
alias(fit)

threeLineTable(cbind(rownames(lm.summary$coefficients), as.data.frame(round(lm.summary$coefficients, 4))), "Table 10: Linear Regression Model on Training Data set", "", "Linear_Regression_Table")

# RMSE of Linear Regression Model
rmse_linear_regression_gender_age_race <- sqrt(mean(lm.summary$residuals^2))
rmse_linear_regression_gender_age_race



################################################################
# Feature Selection
################################################################

# Stepwise Stepwise Selection
stepAIC(fit, direction = "both")

# Regression Model Fit using Features from Stepwise Stepwise Selection
fit <- lm(formula = pd2016 ~ unrate15 + unrate12 + inc15 + pcpv15 + 
            pp51715 + phsd + psca + pbdh + adkxe004 + adkxe006 + adkxe007 + 
            adolm001 + green + republican + `Black or African American.2015`, 
          data = lassoRegressedFeatures)
summary(fit)


