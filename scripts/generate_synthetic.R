if (!file.exists("app.R")) stop("Run this script from the repository root.")
source("R/load.R"); load_engine()
for (disease in c("DLBCL", "SCLC")) {
  d <- generate_synthetic(disease = disease)
  dir.create("data/synthetic", recursive=TRUE, showWarnings=FALSE)
  name <- tolower(disease)
  write.csv(d, file.path("data/synthetic",paste0(name,"_demo.csv")),row.names=FALSE)
  jsonlite::write_json(attr(d,"provenance"),file.path("data/synthetic",paste0(name,"_provenance.json")),
                       auto_unbox=TRUE,pretty=TRUE,na="null")
}
message("Two completely synthetic demonstration datasets generated.")
