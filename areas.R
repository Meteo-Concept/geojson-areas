library(sp)
library(rgdal)
library(rgeos)
library(jsonlite)

args <- commandArgs(trailingOnly=T)
if (length(args) != 3) {
	stop("Usage: <program.R> input_file.json output_file layer_name\n The first argument must be a path, the second one a path without the extension (because two files will be produced, a .shp with accompanying files and a .json) and the third one a simple string (which will be used as a file name)")
}

zones <- fromJSON(args[1])
citiesByZones <- as.data.frame(Reduce(rbind, lapply(zones, FUN=function (z) { cbind(z$cities,z$id) })[-1]))
zones <- as.data.frame(Reduce(rbind, lapply(zones, FUN=function (z) { c(z$id,z$name,z$color) })[-1]))
names(zones) <- c('id','name','color')
row.names(zones) <- as.character(zones$id)
names(citiesByZones) <- c('insee','zone_id')

communes <- readOGR(dsn="./bretagne.json")
communes <- merge(communes,citiesByZones,by.x='INSEE_COM',by.y='insee')

allpolygons <- sapply(X=zones$id, FUN=function (z) {
			      relevant <- communes[communes$zone_id==z,]
			      gUnionCascaded(relevant, id=rep(as.character(z), length(relevant)))
		})
allpolygons <- SpatialPolygonsDataFrame(bind(allpolygons, keepnames=T), zones)

writeOGR(allpolygons, args[2], layer=args[3], driver="ESRI Shapefile", layer_options="ENCODING=UTF8")
allpolygons <- spTransform(allpolygons, "+proj=longlat")
writeOGR(allpolygons, paste0(args[2], ".json"), layer="", driver="GeoJSON")
