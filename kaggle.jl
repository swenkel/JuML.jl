#push!(LOAD_PATH, "C:\\Users\\adamm\\Dropbox\\Development\\JuML\\src")
push!(LOAD_PATH, "C:\\Users\\statfactory\\Documents\\JuML.jl\\src")
using JuML

@time importcsv("C:\\Users\\statfactory\\Documents\\Julia\\kaggle\\train.csv";
                 isnumeric = (colname, levelfreq) -> colname in ["is_attributed"],
                 isdatetime = (colname, levelfreq) -> colname in ["click_time", "attributed_time"] ? (true, "y-m-d H:M:S") : (false, ""))

@time importcsv("C:\\Users\\statfactory\\Documents\\Julia\\kaggle\\test.csv";
                 isnumeric = (colname, levelfreq) -> false,
                 isdatetime = (colname, levelfreq) -> colname in ["click_time"] ? (true, "y-m-d H:M:S") : (false, ""))

train_df = DataFrame("C:\\Users\\statfactory\\Documents\\Julia\\kaggle\\train", preload = true)
test_df = DataFrame("C:\\Users\\statfactory\\Documents\\Julia\\kaggle\\test", preload = true)

factors = train_df.factors
label = train_df["is_attributed"]
click_time = train_df["click_time"]

day = JuML.TransDateTimeCovariate("ClickDay", click_time, Dates.dayofweek)
summary(day)
#f = JuML.factor(h, 0:24)

# r = rand(Float32, length(label))
# trainset = r .<= 0.9
# testset = r .> 0.9

trainset = (day .< 4) |> JuML.cache
testset = (day .== 4) |> JuML.cache

ip = train_df["ip"]

labelstats = getstats(label)

_, ipstats = getstats(ip, label);
iplevels = JuML.getlevels(ip)
d = Dict{String, String}()
for (i, level) in enumerate(iplevels)
    d[level] = string(ipstats[i].mean)
end

mapiplevel = (level::String) -> begin
    get(d, level, string(labelstats.mean))
end

iprate = JuML.MapLevelFactor("iprate", ip, mapiplevel) 


@time model = xgblogit(label, [filter((f -> JuML.getname(f) != "ip"), factors); iprate]; selector = trainset, η = 0.1, λ = 1.0, γ = 0.0, minchildweight = 200.0, nrounds = 200, maxdepth = 6, ordstumps = false, pruning = true, caching = true, usefloat64 = false, singlethread = false, slicelength = 0);

@time trainauc = getauc(model.pred, label; selector = convert(BitArray, trainset))
@time testauc = getauc(model.pred, label; selector = convert(BitArray, testset))

mean(model.pred)
pred = predict(model, test_df)
mean(pred)
is_attr = Covariate("is_attributed", pred)
click_id = test_df["click_id"]
sub_df = DataFrame(length(pred), [click_id], [is_attr], JuML.AbstractBoolVariate[], JuML.AbstractDateTimeVariate[])
JuML.tocsv("C:\\Users\\statfactory\\Documents\\Julia\\kaggle\\submission.csv", sub_df)










