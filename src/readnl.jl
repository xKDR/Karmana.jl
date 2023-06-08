using Dates

# Define a function to extract the date from the file name
function extract_date(filename)
    # Extract the date range using regex
    m = match(r"_(\d{8})-\d{8}_", filename)
    return m == nothing ? nothing : Date(m[1], "yyyymmdd")
end

# Get the list of file names in the directory
files = readdir("/mnt/giant-disk/nighttimelights/monthly/cf")

# Filter out files that we couldn't extract a date from
files = filter(x -> extract_date(x) != nothing, files)

# Sort files based on the date they contain
sort!(files, by=extract_date)

# Now files are sorted in increasing order of the date
println(files)
