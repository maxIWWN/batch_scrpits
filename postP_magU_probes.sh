#!/bin/bash
## Executes the OF command "probeLocations" for specific definitions in "system/probesDict" to evaluate the velocity (magU) at certain points.
## ! Execute the script from OF_CASE_DIR/postProcessing/ directory !
## ! Adjust "OF_CASE_DIR/system/probesDict" file befor evatuation !

echo -e ""
echo "postprocessing for the evaluation of the velocity (magU) at defined probe locations"
echo "REMINDER: probesDict checked?!"

if [ -d ../0 ]; then
    mv ../0 ../0.bak
fi

if [ ! -d ./magU_probes ]; then
    mkdir magU_probes
else
    rm magU_probes/!(probes_output)
fi

## check whether magU exists (at first timestep directory) - if not magU gets calculated
cd ..
firstTimeDir=$(ls -d */ | tail -n+2 | head -n1)
cd postProcessing
if [ ! -f ../$firstTimeDir/magU ]; then
    cd ..
    echo "calculating magU ..."
    ## OF 2.3.1:
    foamCalc mag U > postProcessing/magU_calc_temp
    ## OF 5.0:
    #postProcess -func 'mag(U)' > postProcessing/magU_calc_temp
    #for i in ../[1-9]*/ ; do
    #    mv $i/mag\(U\) $i/magU
    #done
    cd postProcessing
    rm magU_calc_temp
fi

## execute probeLocations command
if [ -d ./probes ]; then
    read -p "-> The probes directory already exists. Do you want to run probeLocations again and overwrite old data (y/n)? " ans1
    if [ "$ans1" == "y" ]; then
        echo "executing probeLocations command and writing terminal output to file: probes_output"
        echo "..."
        rm -r probes
        cd ..
        probeLocations > postProcessing/magU_probes/probes_output
        cd postProcessing
    fi
else
    echo "executing probeLocations command and writing terminal output to file: probes_output"
    echo "..."
    cd ..
    probeLocations > postProcessing/magU_probes/probes_output
    cd postProcessing
fi

echo "postprocessing of probeLocations data ..."

## get the name of the first directory in postProcessing/probes
timeDir=$(ls probes/ | head -n 1)

echo "plotting diagram"
gnuplot <<- EOF
    set terminal pngcairo size 1600,600 enhanced font 'Verdana,10'
    set title 'velocity probes on selected points'
    set xlabel 'time [s]'
    set ylabel 'velocity [m/s]'
    set grid
    outfile = 'magU_probes/magU_diagram.png'
    set output outfile
    set key outside
    firstTimeDir = system('echo $timeDir')
    #get the first line, merge spaces into one space, put each space in a line, count the lines
    numOfPoints = system('head -n1 probes/'.firstTimeDir.'/magU | tr -s " " | grep -o " " | wc -l')
    numOfPoints = numOfPoints-1
    ###MITTELWERT
    # get the mean for each point and print it to a file StatDat.dat
    #array meanArr[numOfPoints]
    meanArr=''
    set print "StatDat.dat"
    do for [i=2:numOfPoints+1] {
      stats  'probes/'.firstTimeDir.'/magU' u i nooutput ;
      print STATS_mean
      meanArr = sprintf('%s %.3f',meanArr,STATS_mean)
    }
    set print
    # transpose StatDat.dat file and append it to the probed files (slow, but for the moment the only solution :( )
    system('> meanValues; while IFS= read line; do cut -f1 StatDat.dat | paste -s >> meanValues; done < probes/'.firstTimeDir.'/magU')
    system('paste probes/'.firstTimeDir.'/magU meanValues > dataToPlot')
    #get the coordinates from each point and append it to meanValues
    system('sed "s/ \+ /\t/g" probes/'.firstTimeDir.'/magU > magUtabs')
    system('sed "/^#/!d" magUtabs > points')
    system('> trData')
    do for [i=3:numOfPoints+2] {
        system('cut -f'.i.' points | paste -s >> trData')
    }
    system('paste trData StatDat.dat > magU_probes/meanValues.txt')
    print 'Mean values in: magU_probes/meanValues.txt'
    unset colorbox
    set cbrange [0:100]
    plot for [i=2:numOfPoints+1] 'dataToPlot' using 1:i with linespoints palette cb (i-2)*(100/numOfPoints) title 'point '.(i-1),\
        for [i=numOfPoints+2:(numOfPoints*2)+1] 'dataToPlot' using 1:i with lines palette cb (i-numOfPoints-2)*(100/numOfPoints) title word(meanArr,i-numOfPoints-1)
    print 'plot image to: '.outfile
EOF

rm StatDat.dat meanValues magUtabs trData points
mv dataToPlot magU_probes/

echo "done"
echo -e ""
