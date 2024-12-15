import csv
import sys
import statistics

int_rate = [
    "500.perlbench_r",
    "502.gcc_r",
    "505.mcf_r",
    "520.omnetpp_r",
    "523.xalancbmk_r",
    "525.x264_r",
    "531.deepsjeng_r",
    "541.leela_r",
    "548.exchange2_r",
    "557.xz_r",
]

reftime = {
    "500.perlbench_r": 1592,
    "502.gcc_r": 1416,
    "505.mcf_r": 1616,
    "520.omnetpp_r": 1312,
    "523.xalancbmk_r": 1056,
    "525.x264_r": 1751,
    "531.deepsjeng_r": 1146,
    "541.leela_r": 1656,
    "548.exchange2_r": 2620,
    "557.xz_r": 1080,
}

with open(sys.argv[1], newline="") as csvfile:
    reader = csv.DictReader(csvfile)
    scores = {}
    for row in reader:
        if row["benchmark"] in int_rate:
            scores[row["benchmark"]] = {
                "time": float(row["time"]),
                "ratio": reftime[row["benchmark"]] / float(row["time"]),
            }

with open(sys.argv[1], "w", newline="") as csvfile:
    fieldnames = ["benchmark", "time", "ratio"]
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)

    writer.writeheader()
    for benchmark in int_rate:
        writer.writerow(
            {
                "benchmark": benchmark,
                "time": round(scores[benchmark]["time"]),
                "ratio": "{:.2f}".format(scores[benchmark]["ratio"]),
            }
        )

    int_rate_ratios = []
    for benchmark in int_rate:
        int_rate_ratios.append(scores[benchmark]["ratio"])
    writer.writerow(
        {
            "benchmark": "int_rate",
            "time": "0",
            "ratio": "{:.2f}".format(statistics.geometric_mean(int_rate_ratios)),
        }
    )
