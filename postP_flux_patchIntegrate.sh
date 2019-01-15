#!/bin/bash

if [ -d ../0 ]; then
    mv ../0 ../0.bak
fi

if [ ! -d ./flux_patchIntegrate ]; then
	mkdir flux_patchIntegrate
fi

echo -e ""
echo "postprocessing for phiWater evaluation"
read -p "-> Enter name of patch: " patchName
echo "processing and writing to file: phiWater_${patchName}"
echo "..."
cd ..
## OF 2.3.1:
patchIntegrate alphaPhi10 "$patchName" > postProcessing/flux_patchIntegrate/phiWater_"$patchName"
## OF 5.0:
#postProcess -func 'patchIntegrate(name="$patchName",alphaPhi10)' > postProcessing/flux_patchIntegrate/phiWater_"$patchName"
cd postProcessing

echo "processing data"
sed -e s/'Time = 0'//g flux_patchIntegrate/phiWater_"${patchName}" | grep -F 'Time = ' | grep -o '[^=^ ]\+$' > flux_patchIntegrate/time
grep -F 'Integral of alphaPhi10' flux_patchIntegrate/phiWater_"$patchName" | grep -o '[^=^ ]\+$' | awk '{ print ($1 < 0) ? ($1 * -1) : $1 }' > flux_patchIntegrate/flux
echo "writing data to file: table_phiWater_${patchName}"
paste flux_patchIntegrate/time flux_patchIntegrate/flux > flux_patchIntegrate/table_phiWater_"$patchName"
rm flux_patchIntegrate/time flux_patchIntegrate/flux

echo "plotting diagram"
# list all patches that already have a flux vs time file
ls flux_patchIntegrate | grep -F "table_phiWater_" | sed 's/table_phiWater_//g' > flux_patchIntegrate/existingPatches
gnuplot <<- EOF
    set terminal pngcairo size 1200,600 enhanced font 'Verdana,10'
    set title 'flux of phase fraction 1 (phi water) over time at patch'
    set xlabel 'time [s]'
    set ylabel 'flux of water phase [m³/s]'
    set grid
    outfile = 'flux_patchIntegrate/flux_patchIntegrate_diagram.png'
    set output outfile
    patches = system('cat flux_patchIntegrate/existingPatches')
    set print "flux_patchIntegrate/StatDat.dat"
    do for [patch in patches] {
        stats  'flux_patchIntegrate/table_phiWater_'.patch u 2 nooutput ;
        print STATS_mean
    }
    set print
    meanVArr = system('cat flux_patchIntegrate/StatDat.dat')
    system('paste flux_patchIntegrate/existingPatches flux_patchIntegrate/StatDat.dat > flux_patchIntegrate/meanValues.txt')
    print 'Mean values printed in file: flux_patchIntegrate/meanValues.txt'
    set key noenhanced
    set key outside
    plot for [patch in patches] 'flux_patchIntegrate/table_phiWater_'.patch using 1:2 with linespoints title patch, \
        for [m in meanVArr] m+0 title m
    print 'plot image to: '.outfile
EOF

rm flux_patchIntegrate/existingPatches flux_patchIntegrate/StatDat.dat

echo "done"
echo -e ""
