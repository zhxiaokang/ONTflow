# sum the trans to gene

library(tximport)
library(hash)
library(stringr)

# ====================== define some functions ======================

# remove the version in the transcript ID
remove_version <- function(quant.file, quant.file.noVersion) {  # input files (file names with directory) are output from Salmon
  quant.table <- read.table(quant.file, header = TRUE, stringsAsFactors = FALSE)
  trans.id.version <- quant.table$Name
  trans.id <- rep('ID', length(trans.id.version))
  for (j in c(1:length(trans.id.version))) {
    trans.id[j] <- strsplit(trans.id.version[j], ".", fixed = TRUE)[[1]][1]
  }
  quant.table$Name <- trans.id
  write.table(quant.table, quant.file.noVersion, sep = "\t", quote = FALSE, row.names = FALSE)
  
  return(trans.id)
}

# ====================== load parameters in file ======================
args <- commandArgs(trailingOnly = TRUE)
tx2gene.file <- args[1]
id2symbol.file <- args[2]
quant.file <- paste0(args[3], "/quant.sf")
out.path <- args[4]

quant.file.noVersion <- file.path(str_sub(quant.file, 1, -10), "quant_noVersion.sf")

# ====================== remove the version in quant file and save the noVersion file ======================
trans.id <- remove_version(quant.file, quant.file.noVersion)

# read the two tables
tx2gene <- read.csv(tx2gene.file, header = FALSE, sep = "\t", stringsAsFactors = FALSE)
id2symbol <- read.csv(id2symbol.file, header = FALSE, sep = "\t", stringsAsFactors = FALSE)

# ====================== get raw and normalized abundance tables ======================

# trans.matrix <- tximport(quant.file.noVersion, type = "salmon", txOut = TRUE, countsFromAbundance = "no")
# trans.count <- trans.matrix$counts

# trans.matrix.tpm <- tximport(quant.file.noVersion, type = "salmon", txOut = TRUE, countsFromAbundance = "lengthScaledTPM")
# trans.count.tpm <- trans.matrix.tpm$counts

# ====================== convert trans to gene tables ======================
gene.matrix <- tximport(quant.file.noVersion, type = "salmon", tx2gene = tx2gene, countsFromAbundance = "no")
gene.count <- gene.matrix$counts

gene.matrix.tpm <- tximport(quant.file.noVersion, type = "salmon", tx2gene = tx2gene, countsFromAbundance = "lengthScaledTPM")
gene.count.tpm <- gene.matrix.tpm$counts

# ====================== convert gene ID to symbol ======================
hash.table <- hash()
for (i in c(1:nrow(id2symbol))) {
    id <- id2symbol[i, 1]
    symbol <- id2symbol[i, 2]
    hash.table[[id]] <- symbol
}

for (i in c(1:nrow(gene.count))) {
    id <- row.names(gene.count)[i]
    if (has.key(id, hash.table)){
        symbol <- hash.table[[id]]
        row.names(gene.count)[i] <- symbol
    } else{
        # no hit, keep the ID as it is
    }
}

for (i in c(1:nrow(gene.count.tpm))) {
    id <- row.names(gene.count.tpm)[i]
    if (has.key(id, hash.table)){
        symbol <- hash.table[[id]]
        row.names(gene.count.tpm)[i] <- symbol
    } else{
        # no hit, keep the ID as it is
    }
}

# ====================== write to files ======================
barcode <- str_sub(quant.file, -18, -10)
write.table(gene.count, file.path(out.path, paste0("gene_abundance_", barcode, ".tsv")), quote = FALSE, col.names = FALSE)
write.table(gene.count.tpm, file.path(out.path, paste0("gene_tpm_", barcode, ".tsv")), quote = FALSE, col.names = FALSE)

