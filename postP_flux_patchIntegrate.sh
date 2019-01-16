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
    numPatches = system('wc -l < flux_patchIntegrate/existingPatches')
    array meanValArr[numPatches]
    array patchesArr[numPatches]
    set print "flux_patchIntegrate/StatDat.dat"
    i = 1
    do for [patch in patches] {
        stats  'flux_patchIntegrate/table_phiWater_'.patch u 2 nooutput ;
        print STATS_mean
        patchesArr[i] = patch
        meanValArr[i] = STATS_mean
        i = i +1
    }
    set print
    system('paste flux_patchIntegrate/existingPatches flux_patchIntegrate/StatDat.dat > flux_patchIntegrate/meanValues.txt')
    print 'Mean values printed in file: flux_patchIntegrate/meanValues.txt'
    set key noenhanced
    set key outside
    set cbrange [0:100]
    unset colorbox
    plot for [i=1:numPatches] 'flux_patchIntegrate/table_phiWater_'.patchesArr[i] using 1:2 with linespoints palette cb (i-1)*(100/numPatches) title patchesArr[i], \
        for [i=1:numPatches] meanValArr[i] palette cb (i-1)*(100/numPatches) title sprintf('%1.3f',meanValArr[i])
    print 'plot image to: '.outfile
EOF

rm flux_patchIntegrate/existingPatches flux_patchIntegrate/StatDat.dat

echo "done"
echo -e ""
