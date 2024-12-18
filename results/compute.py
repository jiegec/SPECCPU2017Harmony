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

fp_rate = [
    "503.bwaves_r",
    "507.cactuBSSN_r",
    "508.namd_r",
    "510.parest_r",
    "511.povray_r",
    "519.lbm_r",
    "521.wrf_r",
    "526.blender_r",
    "527.cam4_r",
    "538.imagick_r",
    "544.nab_r",
    "549.fotonik3d_r",
    "554.roms_r",
]

reftime = {
    # int rate
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
    # fp rate
    "503.bwaves_r": 10028,
    "507.cactuBSSN_r": 1266,
    "508.namd_r": 950,
    "510.parest_r": 2616,
    "511.povray_r": 2335,
    "519.lbm_r": 1054,
    "521.wrf_r": 2240,
    "526.blender_r": 1523,
    "527.cam4_r": 1749,
    "538.imagick_r": 2487,
    "544.nab_r": 1683,
    "549.fotonik3d_r": 3897,
    "554.roms_r": 1589,
}

with open(sys.argv[1], newline="") as csvfile:
    reader = csv.DictReader(csvfile)
    scores = {}
    for row in reader:
        if row["benchmark"] in int_rate or row["benchmark"] in fp_rate:
            scores[row["benchmark"]] = {
                "time": float(row["time"]),
                "ratio": reftime[row["benchmark"]] / float(row["time"]),
            }

with open(sys.argv[1], "w", newline="") as csvfile:
    fieldnames = ["benchmark", "time", "ratio"]
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)

    writer.writeheader()

    for name, rate in [("int_rate", int_rate), ("fp_rate", fp_rate)]:
        sum_time = 0
        for benchmark in rate:
            if benchmark in scores:
                sum_time += scores[benchmark]["time"]
                writer.writerow(
                    {
                        "benchmark": benchmark,
                        "time": round(scores[benchmark]["time"]),
                        "ratio": "{:.2f}".format(scores[benchmark]["ratio"]),
                    }
                )

        ratios = []
        for benchmark in rate:
            if benchmark in scores:
                ratios.append(scores[benchmark]["ratio"])

        writer.writerow(
            {
                "benchmark": name,
                "time": round(sum_time),
                "ratio": "{:.2f}".format(statistics.geometric_mean(ratios)),
            }
        )
