#!/usr/bin/env Rscript
options(warn = 1)
root <- normalizePath(getwd(), mustWork = TRUE)
if (!file.exists(file.path(root, "DESCRIPTION"))) stop("Run this script from the rsmFlow package root.")

desc <- read.dcf(file.path(root, "DESCRIPTION"))
suggests <- if ("Suggests" %in% colnames(desc)) trimws(unlist(strsplit(desc[1,"Suggests"], ","))) else character()
suggests <- trimws(sub("\\s*\\(.*\\)$", "", suggests))
suggests <- suggests[nzchar(suggests)]
missing <- suggests[!vapply(suggests, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop("For the full --as-cran validation gate install all Suggested packages first: ", paste(missing, collapse = ", "))

dir.create(file.path(root, "validation"), showWarnings = FALSE)
writeLines(capture.output(sessionInfo()), file.path(root, "validation", "sessionInfo.txt"))

run_cmd <- function(args, log) {
  out <- system2(file.path(R.home("bin"), "R"), args, stdout = TRUE, stderr = TRUE)
  writeLines(out, log)
  status <- attr(out, "status")
  if (is.null(status)) status <- 0L
  if (!identical(as.integer(status), 0L)) stop("Command failed. See ", log)
  invisible(out)
}

old <- getwd(); on.exit(setwd(old), add = TRUE)
setwd(dirname(root))
pkg <- basename(root)
run_cmd(c("CMD", "build", shQuote(pkg)), file.path(root, "validation", "R_CMD_build.log"))
tarballs <- list.files(dirname(root), pattern = paste0("^", pkg, "_.*\\.tar\\.gz$"), full.names = TRUE)
if (!length(tarballs)) stop("R CMD build did not produce a tarball. See validation/R_CMD_build.log")
latest <- tarballs[which.max(file.info(tarballs)$mtime)]
run_cmd(c("CMD", "check", "--as-cran", shQuote(latest)), file.path(root, "validation", "R_CMD_check_console.log"))

check_dirs <- list.dirs(dirname(root), recursive = FALSE, full.names = TRUE)
check_dirs <- check_dirs[grepl("\\.Rcheck$", check_dirs)]
if (length(check_dirs)) {
  check_dir <- check_dirs[which.max(file.info(check_dirs)$mtime)]
  if (file.exists(file.path(check_dir, "00check.log"))) {
    file.copy(file.path(check_dir, "00check.log"), file.path(root, "validation", "00check.log"), overwrite = TRUE)
  }
}

# Install into a clean temporary library and run the package smoke test.
lib <- tempfile("rsmFlow-lib-")
dir.create(lib)
utils::install.packages(latest, repos = NULL, type = "source", lib = lib)
.libPaths(c(lib, .libPaths()))
source(file.path(root, "scripts", "SMOKE_TEST.R"), chdir = TRUE)

cat("Built and checked:", latest, "\n")
cat("Review validation/00check.log and validation/R_CMD_check_console.log before release.\n")
