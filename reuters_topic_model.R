########################################################################
#           Topic modeling for Thomson Reuters newsletters             #
#                       Latent Dirichlet Allocation (LDA)              #
#                             Gibbs Sampling                           #
#                       Visialization with LDAvis                      # 
#                                                                      #
#                       Author: Nethika Suraweera                      #
#                               09/28/2016                             #
########################################################################

#load libraries
library(tm)
library(LDAvis)
library(servr)
library(topicmodels)
library(dplyr)
library(stringi)


######################################################################
#     Load files into corpus and Create document-term matrix         #
######################################################################

#read json data into a data_frame
json_file <- "deals.json"
json_data <- fromJSON(json_file)


#create corpus from vector
docs <- Corpus(VectorSource(json_data$text))

docs <- tm_map(docs,
               content_transformer(function(x) iconv(x, to='UTF-8-MAC', sub='byte')),
               mc.cores=1)

#start preprocessing
#Transform to lower case
docs <-tm_map(docs,content_transformer(tolower))


#remove potentially problematic symbols
toSpace <- content_transformer(function(x, pattern) { return (gsub(pattern, " ", x))})
docs <- tm_map(docs, toSpace, "-")
docs <- tm_map(docs, toSpace, "'")
docs <- tm_map(docs, toSpace, "'")
docs <- tm_map(docs, toSpace, "”")
docs <- tm_map(docs, toSpace, "“")


#remove punctuation
docs <- tm_map(docs, removePunctuation)
#Strip digits
docs <- tm_map(docs, removeNumbers)
#docs <- tm_map(docs, PlainTextDocument)
#remove stopwords
docs <- tm_map(docs, removeWords, stopwords("english"))
#remove whitespace
docs <- tm_map(docs, stripWhitespace)
#Stem document
docs <- tm_map(docs,stemDocument)


#fix up 1) differences between us and aussie english 2) general errors
docs <- tm_map(docs, content_transformer(gsub),
               pattern = "organiz", replacement = "organ")
docs <- tm_map(docs, content_transformer(gsub),
               pattern = "organis", replacement = "organ")
docs <- tm_map(docs, content_transformer(gsub),
               pattern = "andgovern", replacement = "govern")
docs <- tm_map(docs, content_transformer(gsub),
               pattern = "inenterpris", replacement = "enterpris")
docs <- tm_map(docs, content_transformer(gsub),
               pattern = "team-", replacement = "team")
#define and eliminate all custom stopwords
myStopwords <- c("can", "say","one","way","use",
                 "also","howev","tell","will",
                 "much","need","take","tend","even",
                 "like","particular","rather","said",
                 "get","well","make","ask","come","end",
                 "first","two","help","often","may",
                 "might","see","someth","thing","point",
                 "post","look","right","now","think","‘ve ",
                 "‘re ","anoth","put","set","new","good",
                 "want","sure","kind","larg","yes,","day","etc",
                 "quit","sinc","attempt","lack","seen","awar",
                 "littl","ever","moreov","though","found","abl",
                 "enough","far","earli","away","achiev","draw",
                 "last","never","brief","bit","entir","brief",
                 "great","lot")
docs <- tm_map(docs, removeWords, myStopwords)
#inspect a document as a check
#writeLines(as.character(docs[[3]]))

#Create document-term matrix
dtm <- DocumentTermMatrix(docs)

######################################################################
#     LDA Gibbs Sampling Model                                                #
######################################################################

text <- dtm2ldaformat(dtm, omit_empty = FALSE) 

K<-10
alpha = 50/K
eta = 200/ncol(dtm)

fitted_result <- lda.collapsed.gibbs.sampler(text$documents,
                                             K,
                                             text$vocab,
                                             1000,
                                             alpha = alpha,
                                             eta = eta
)

######################################################################
#     LDAvis Visualization                                           #
######################################################################
theta <- t(apply(fitted_result$document_sums + alpha,2,function(x) x/sum(x)))
phi <- t(apply(t(fitted_result$topics) + eta,2,function(x) x/sum(x)))
doc.length <- rowSums(as.matrix(dtm))
vocab<-colnames(dtm)
term.frequency<-colSums(as.matrix(dtm))

json <-createJSON(phi = phi, theta = theta, vocab = vocab,
                  doc.length = doc.length, term.frequency = term.frequency)

serVis(json, out.dir = "vis_new", open.browser = FALSE)

######################################################################
#     Analysis                                                       #
######################################################################


